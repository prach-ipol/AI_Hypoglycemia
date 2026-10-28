from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from bson import ObjectId
from bson.errors import InvalidId
from flask import Blueprint, current_app, request, jsonify, g
from pymongo.errors import DuplicateKeyError
from .security import authenticated, hash_password, verify_password, issue_token
from .services.foods import load_foods, calculate, analyze_intake

api = Blueprint("api", __name__)
@lru_cache(maxsize=1)
def load_trusted_model(artifact_path):
    import json, joblib
    path=Path(artifact_path)
    metadata=json.loads(path.with_name("metadata.json").read_text(encoding="utf-8"))
    return joblib.load(path), metadata
def db(): return current_app.extensions["database"]
def now(): return datetime.now(timezone.utc)

@api.get("")
@api.get("/")
def api_index():
    return jsonify(service="Glucose Companion API", status="available", endpoints={
        "health":"/health",
        "authentication":["POST /api/auth/register", "POST /api/auth/login", "GET /api/auth/me"],
        "foods":["GET /api/foods", "GET /api/foods/{food_id}", "POST /api/intake/analyze", "POST /api/meals/calculate"],
        "glucose":["POST /api/glucose", "GET /api/glucose", "GET/PATCH/DELETE /api/glucose/{reading_id}"],
        "meals":["POST/GET /api/meals", "DELETE /api/meals/{meal_id}"],
        "dashboard":"GET /api/dashboard/summary",
        "predictions":"POST/GET /api/predictions/hypoglycemia and /api/predictions",
    })

def doc(value):
    if isinstance(value, ObjectId): return str(value)
    if isinstance(value, datetime): return value.isoformat()
    if isinstance(value, dict): return {k: doc(v) for k,v in value.items() if k != "password_hash"}
    if isinstance(value, list): return [doc(v) for v in value]
    return value
def owned(collection, record_id):
    try: oid = ObjectId(record_id)
    except (InvalidId, TypeError): return None
    return db()[collection].find_one({"_id": oid, "user_id": g.user_id})

@api.post("/auth/register")
def register():
    data = request.get_json(silent=True) or {}; email = str(data.get("email", "")).strip().lower(); password = data.get("password", ""); name = str(data.get("name", data.get("display_name", ""))).strip()
    contact = "".join(ch for ch in str(data.get("contact", "")) if ch.isdigit())
    if not name or len(name) > 100 or "@" not in email or len(email) > 254 or not 7 <= len(contact) <= 15 or not isinstance(password, str) or len(password) < 10:
        return jsonify(error={"code":"validation_error", "message":"Name, valid email, contact number, and password of at least 10 characters are required"}), 400
    user = {"display_name": name, "email": email, "contact": contact, "password_hash": hash_password(password), "created_at": now(), "preferences": {"unit":"mg/dL"}}
    try:
        db().initialize()
        result = db().users.insert_one(user)
    except DuplicateKeyError: return jsonify(error={"code":"account_exists", "message":"An account with this email or contact number already exists"}), 409
    return jsonify(user={"id":str(result.inserted_id), "name":name, "email":email, "contact":contact}, token=issue_token(result.inserted_id)), 201

@api.post("/auth/login")
def login():
    data = request.get_json(silent=True) or {}; contact = "".join(ch for ch in str(data.get("contact", "")) if ch.isdigit()); password = data.get("password", "")
    db().initialize()
    user = db().users.find_one({"contact":contact})
    if not user: return jsonify(error={"code":"account_not_registered", "message":"This contact number is not registered. Please register first."}), 404
    if not isinstance(password,str) or not verify_password(password, user["password_hash"]): return jsonify(error={"code":"invalid_credentials", "message":"Contact number or password is incorrect"}), 401
    timestamp=now()
    db().users.update_one({"_id":user["_id"]},{"$set":{"last_login_at":timestamp}})
    db().login_events.insert_one({"user_id":str(user["_id"]),"created_at":timestamp,"event":"login_success"})
    return jsonify(user={"id":str(user["_id"]), "name":user["display_name"], "contact":contact}, token=issue_token(user["_id"]))

@api.get("/auth/me")
@authenticated
def me():
    user = db().users.find_one({"_id":ObjectId(g.user_id)})
    if not user: return jsonify(error={"code":"not_found", "message":"Account not found"}), 404
    return jsonify(user=doc(user))

@api.delete("/auth/account")
@authenticated
def delete_account():
    for name in ("glucose_readings","meal_records","activity_records","predictions","user_preferences","intake_analyses","login_events"): db()[name].delete_many({"user_id":g.user_id})
    db().users.delete_one({"_id":ObjectId(g.user_id)})
    return "", 204

@api.get("/foods")
def foods():
    q = request.args.get("q", "").strip().casefold(); items = load_foods()
    if q: items = [x for x in items if q in x["name"].casefold()]
    try: limit = max(1,min(100,int(request.args.get("limit", "50"))))
    except ValueError: return jsonify(error={"code":"validation_error","message":"limit must be an integer"}), 400
    return jsonify(items=items[:limit], count=min(len(items),limit), source="nutrition estimates")

@api.get("/foods/<food_id>")
def food(food_id):
    found = next((f for f in load_foods() if f["id"] == food_id), None)
    return (jsonify(item=found),200) if found else (jsonify(error={"code":"not_found","message":"Food not found"}),404)

@api.post("/intake/analyze")
@authenticated
def intake_analyze():
    data=request.get_json(silent=True) or {}
    try:
        result=analyze_intake(data.get("intake_name"),data.get("portion_grams"),data.get("intake_time"),load_foods())
        db().initialize()
        record={"user_id":g.user_id,"timestamp":now(),**result}
        saved=db().intake_analyses.insert_one(record)
        result["analysis_id"]=str(saved.inserted_id)
        return jsonify(result)
    except ValueError as exc:
        return jsonify(error={"code":"validation_error","message":str(exc)}),400

@api.get("/intake/analyses")
@authenticated
def intake_analyses():
    items=list(db().intake_analyses.find({"user_id":g.user_id}).sort("timestamp",-1).limit(100))
    return jsonify(items=doc(items))

@api.post("/feedback")
def feedback():
    data=request.get_json(silent=True) or {}
    name=str(data.get("name", "")).strip(); contact="".join(ch for ch in str(data.get("contact", "")) if ch.isdigit()); message=str(data.get("message", "")).strip()
    if not name or len(name)>100 or not 7<=len(contact)<=15 or not message or len(message)>2000:
        return jsonify(error={"code":"validation_error","message":"Enter your name, valid contact number, and a message (up to 2000 characters)"}),400
    db().initialize()
    result=db().feedback.insert_one({"name":name,"contact":contact,"message":message,"created_at":now()})
    return jsonify(status="received",feedback_id=str(result.inserted_id)),201

@api.post("/meals/calculate")
def meal_calculate():
    data=request.get_json(silent=True) or {}
    try: return jsonify(calculate(data.get("items",[]), load_foods()))
    except (ValueError,TypeError): return jsonify(error={"code":"validation_error","message":"Provide valid food IDs and portion weights in grams"}),400

@api.post("/glucose")
@authenticated
def add_glucose():
    data=request.get_json(silent=True) or {}
    try: value=float(data.get("value"))
    except (ValueError,TypeError): value=0
    if not 20 <= value <= 600 or data.get("unit","mg/dL") != "mg/dL" or data.get("context","other") not in ("fasting","before_meal","after_meal","other"):
        return jsonify(error={"code":"validation_error","message":"Value must be 20-600 mg/dL and context must be supported"}),400
    try: timestamp=datetime.fromisoformat(data.get("timestamp",now().isoformat()).replace("Z","+00:00"))
    except (ValueError,AttributeError): return jsonify(error={"code":"validation_error","message":"timestamp must be ISO 8601"}),400
    item={"user_id":g.user_id,"value":value,"unit":"mg/dL","timestamp":timestamp,"context":data.get("context","other"),"notes":str(data.get("notes",""))[:500]}
    result=db().glucose_readings.insert_one(item); item["_id"]=result.inserted_id
    return jsonify(item=doc(item)),201

@api.get("/glucose")
@authenticated
def glucose_list():
    try: limit=max(1,min(200,int(request.args.get("limit",100))))
    except ValueError:return jsonify(error={"code":"validation_error","message":"limit must be integer"}),400
    items=list(db().glucose_readings.find({"user_id":g.user_id}).sort("timestamp",-1).limit(limit))
    return jsonify(items=doc(items))

@api.get("/glucose/<reading_id>")
@authenticated
def glucose_get(reading_id):
    item=owned("glucose_readings",reading_id)
    return (jsonify(item=doc(item)),200) if item else (jsonify(error={"code":"not_found","message":"Reading not found"}),404)

@api.patch("/glucose/<reading_id>")
@authenticated
def glucose_patch(reading_id):
    item=owned("glucose_readings",reading_id)
    if not item:return jsonify(error={"code":"not_found","message":"Reading not found"}),404
    data=request.get_json(silent=True) or {}; update={}
    if "value" in data:
        try:value=float(data["value"])
        except (ValueError,TypeError):value=0
        if not 20<=value<=600:return jsonify(error={"code":"validation_error","message":"Value must be 20-600 mg/dL"}),400
        update["value"]=value
    if "context" in data:
        if data["context"] not in ("fasting","before_meal","after_meal","other"):return jsonify(error={"code":"validation_error","message":"Invalid context"}),400
        update["context"]=data["context"]
    if "notes" in data:update["notes"]=str(data["notes"])[:500]
    db().glucose_readings.update_one({"_id":item["_id"]},{"$set":update})
    return jsonify(item=doc(db().glucose_readings.find_one({"_id":item["_id"]})))

@api.delete("/glucose/<reading_id>")
@authenticated
def glucose_delete(reading_id):
    item=owned("glucose_readings",reading_id)
    if not item:return jsonify(error={"code":"not_found","message":"Reading not found"}),404
    db().glucose_readings.delete_one({"_id":item["_id"]}); return "",204

@api.post("/meals")
@authenticated
def save_meal():
    data=request.get_json(silent=True) or {}
    try: calc=calculate(data.get("items",[]),load_foods()); when=datetime.fromisoformat(data.get("timestamp",now().isoformat()).replace("Z","+00:00"))
    except (ValueError,TypeError,AttributeError):return jsonify(error={"code":"validation_error","message":"Invalid meal items or timestamp"}),400
    record={"user_id":g.user_id,"timestamp":when,"meal_type":str(data.get("meal_type","other"))[:30],**calc}
    result=db().meal_records.insert_one(record); record["_id"]=result.inserted_id
    return jsonify(item=doc(record)),201

@api.get("/meals")
@authenticated
def meals():return jsonify(items=doc(list(db().meal_records.find({"user_id":g.user_id}).sort("timestamp",-1).limit(100))))

@api.delete("/meals/<meal_id>")
@authenticated
def meal_delete(meal_id):
    item=owned("meal_records",meal_id)
    if not item:return jsonify(error={"code":"not_found","message":"Meal not found"}),404
    db().meal_records.delete_one({"_id":item["_id"]});return "",204

@api.post("/activity")
@authenticated
def activity_add():
    data=request.get_json(silent=True) or {}
    try: duration=int(data.get("duration_minutes"))
    except (ValueError,TypeError):duration=0
    if duration<1 or duration>1440 or not data.get("activity_type"):return jsonify(error={"code":"validation_error","message":"Activity type and duration (1-1440 minutes) required"}),400
    item={"user_id":g.user_id,"activity_type":str(data["activity_type"])[:80],"duration_minutes":duration,"timestamp":now()}; result=db().activity_records.insert_one(item);item["_id"]=result.inserted_id
    return jsonify(item=doc(item)),201

@api.get("/activity")
@authenticated
def activity_list():return jsonify(items=doc(list(db().activity_records.find({"user_id":g.user_id}).sort("timestamp",-1).limit(100))))

@api.post("/predictions/hypoglycemia")
@authenticated
def predict():
    from pathlib import Path
    import pandas as pd
    artifact=Path(__file__).resolve().parents[1]/"ml"/"artifacts"/"hypoglycemia_pipeline.joblib"
    if not artifact.exists():return jsonify(error={"code":"model_unavailable","message":"No validated prediction model is configured. Risk prediction is unavailable until suitable labeled data has been reviewed and a model trained."}),503
    try:
        pipeline,metadata=load_trusted_model(str(artifact))
        features=metadata["features"]
        data=request.get_json(silent=True) or {}
        if not features or any(name not in data for name in features):
            return jsonify(error={"code":"validation_error","message":"All model input features are required: "+", ".join(features)}),400
        values={name:data[name] for name in features}
        for name,value in values.items():
            if value is None or (isinstance(value,str) and not value.strip()):return jsonify(error={"code":"validation_error","message":f"Feature '{name}' is required"}),400
            if metadata.get("feature_types",{}).get(name)=="numeric":
                try: values[name]=float(value)
                except (ValueError,TypeError): return jsonify(error={"code":"validation_error","message":f"Feature '{name}' must be numeric"}),400
        frame=pd.DataFrame([values],columns=features)
        result=int(pipeline.predict(frame)[0])
        probability=float(pipeline.predict_proba(frame)[0][1]) if hasattr(pipeline,"predict_proba") else None
        item={"user_id":g.user_id,"timestamp":now(),"model_version":metadata.get("version","unknown"),"result":result,"probability":probability}
        saved=db().predictions.insert_one(item);item["_id"]=saved.inserted_id
        return jsonify(item=doc(item),clinical_validation=False,disclaimer="Educational support only. Not a diagnosis or substitute for professional care."),201
    except Exception:
        current_app.logger.exception("Trusted model inference failed")
        return jsonify(error={"code":"model_unavailable","message":"The configured model could not process this request."}),503

@api.get("/predictions")
@authenticated
def prediction_list():return jsonify(items=doc(list(db().predictions.find({"user_id":g.user_id}).sort("timestamp",-1).limit(100))))

@api.get("/dashboard/summary")
@authenticated
def dashboard():
    latest=db().glucose_readings.find_one({"user_id":g.user_id},sort=[("timestamp",-1)])
    recent=doc(list(db().glucose_readings.find({"user_id":g.user_id}).sort("timestamp",-1).limit(10)))
    return jsonify(latest_glucose=doc(latest),recent_glucose=recent,recent_meals=doc(list(db().meal_records.find({"user_id":g.user_id}).sort("timestamp",-1).limit(5))),latest_prediction=doc(db().predictions.find_one({"user_id":g.user_id},sort=[("timestamp",-1)])))
