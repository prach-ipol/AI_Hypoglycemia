from bson import ObjectId
from app import create_app
from app.database import Database

class Result:
    def __init__(self, inserted_id=None): self.inserted_id=inserted_id
class Cursor(list):
    def sort(self,*args): return self
    def limit(self,*args): return self
class Collection:
    def __init__(self): self.items=[]
    def find_one(self,q,sort=None): return next((x for x in self.items if all(x.get(k)==v for k,v in q.items())),None)
    def insert_one(self,x): x=dict(x);x["_id"]=ObjectId();self.items.append(x);return Result(x["_id"])
    def find(self,q): return Cursor([x for x in self.items if all(x.get(k)==v for k,v in q.items())])
    def update_one(self,q,u):
        x=self.find_one(q)
        if x:x.update(u.get("$set",{}))
    def delete_one(self,q): self.items=[x for x in self.items if not all(x.get(k)==v for k,v in q.items())]
    def delete_many(self,q): self.delete_one(q)
class MemoryDB:
    def __init__(self): self.cols={}
    def __getattr__(self,k): return self.cols.setdefault(k,Collection())
    def __getitem__(self,k): return self.cols.setdefault(k,Collection())
    def ping(self): pass
    def initialize(self): pass
def client(): return create_app({"TESTING":True,"JWT_SECRET":"test-secret-that-is-long-enough-for-sha256","DATABASE_ADAPTER":MemoryDB()}).test_client()
def test_health(): assert client().get("/health").json["status"]=="ok"
def test_database_wrapper_indexes_into_mongodb_collections():
    class MongoLike:
        def __getitem__(self, name): return name
    assert Database(MongoLike())["users"] == "users"
def test_homepage_explains_backend_and_flutter():
    response=client().get("/")
    assert response.status_code==200 and b"Understand your food" in response.data
    for page in ("/intake", "/login", "/register"):
        page_response=client().get(page)
        assert page_response.status_code==200
        assert b"feedback-form" in page_response.data
def test_browser_assets_call_backend_api():
    c=client()
    script=c.get("/static/site.js")
    assert script.status_code==200
    assert b"/api/auth/register" in script.data
    assert b"/api/auth/login" in script.data
    assert b"/api/intake/analyze" in script.data
    assert b"/api/feedback" in script.data
    assert b"glucose-companion-registered" in script.data
    assert b"login-required-dialog" in script.data
def test_login_gate_and_navigation_labels():
    c=client(); login=c.get("/login").data; intake=c.get("/intake").data
    assert b"disabled>Login" in login
    assert b">Intake Analysis</a>" in intake
    assert b"AI Hypoglycemia /" not in intake
    assert b"<h2>Feedback</h2>" in intake
def test_api_index_lists_routes():
    response=client().get("/api")
    assert response.status_code==200 and "foods" in response.json["endpoints"]
def test_login_requires_auth(): assert client().get("/api/glucose").status_code==401
def test_register_login_and_user_glucose():
    c=client();r=c.post("/api/auth/register",json={"name":"A","email":"a@example.com","contact":"+91 98765 43210","password":"longpassword"});assert r.status_code==201
    login=c.post("/api/auth/login",json={"contact":"919876543210","password":"longpassword"});assert login.status_code==200
    h={"Authorization":"Bearer "+r.json["token"]};assert c.post("/api/glucose",headers=h,json={"value":100,"context":"fasting"}).status_code==201
    assert len(c.get("/api/glucose",headers=h).json["items"])==1
def test_food_search_and_calculation():
    c=client();food=c.get("/api/foods?limit=1").json["items"][0]
    result=c.post("/api/meals/calculate",json={"items":[{"food_id":food["id"],"portion_grams":100}]})
    assert result.status_code==200 and result.json["total_estimated_carbohydrates_g"]>=0
def test_intake_analysis_scales_every_nutrient_and_checks_24h_time():
    c=client(); food=c.get("/api/foods?limit=1").json["items"][0]
    registration=c.post("/api/auth/register",json={"name":"A","email":"intake@example.com","contact":"9876543210","password":"longpassword"})
    headers={"Authorization":"Bearer "+registration.json["token"]}
    response=c.post("/api/intake/analyze",headers=headers,json={"intake_name":food["name"],"portion_grams":50,"intake_time":"14:30"})
    assert response.status_code==200 and response.json["intake_time"]=="14:30"
    assert response.json["nutrition"]["Calories (kcal)"]==round(food["nutrients_per_100g"]["Calories (kcal)"]*.5,2)
    assert "Folate (µg)" in response.json["nutrition"]
    assert c.post("/api/intake/analyze",headers=headers,json={"intake_name":food["name"],"portion_grams":50,"intake_time":"2:30 PM"}).status_code==400
    assert c.post("/api/intake/analyze",json={"intake_name":food["name"],"portion_grams":50,"intake_time":"14:30"}).status_code==401
def test_feedback_submission():
    response=client().post("/api/feedback",json={"name":"A","contact":"9876543210","message":"Useful app"})
    assert response.status_code==201 and response.json["status"]=="received"
def test_prediction_is_explicitly_unavailable():
    c=client();r=c.post("/api/auth/register",json={"name":"A","email":"a@example.com","contact":"9876543210","password":"longpassword"})
    out=c.post("/api/predictions/hypoglycemia",headers={"Authorization":"Bearer "+r.json["token"]},json={})
    assert out.status_code==503 and out.json["error"]["code"]=="model_unavailable"
