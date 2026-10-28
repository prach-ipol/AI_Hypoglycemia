"""Compare classifiers on properly labeled, participant-linked data only."""
import json, os
from datetime import datetime, timezone
from pathlib import Path
import joblib
import pandas as pd
from dotenv import load_dotenv
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.model_selection import GroupShuffleSplit
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, confusion_matrix, roc_auc_score, average_precision_score
from sklearn.ensemble import RandomForestClassifier, HistGradientBoostingClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.neighbors import KNeighborsClassifier

ROOT=Path(__file__).resolve().parents[2]
def main():
    load_dotenv(ROOT/"backend"/".env")
    path=Path(os.getenv("ML_DATASET_PATH",ROOT/"data/raw/labeled_dataset.csv")); target=os.getenv("ML_TARGET_COLUMN","").strip()
    features=[x.strip() for x in os.getenv("ML_FEATURE_COLUMNS","").split(",") if x.strip()]; group=os.getenv("ML_GROUP_COLUMN","").strip()
    if not path.exists(): raise SystemExit(f"Dataset missing: {path}")
    frame=pd.read_csv(path)
    if not target or target not in frame: raise SystemExit("Configure a documented binary hypoglycemia label; no model trained.")
    if not features or any(x not in frame for x in features): raise SystemExit("Configure valid prediction-time ML_FEATURE_COLUMNS.")
    if target in features or not group or group not in frame or group in features: raise SystemExit("A participant/group column is required and cannot be a feature.")
    frame=frame.dropna(subset=[target,group]); y=frame[target]; X=frame[features]
    if set(y.unique())!={0,1}: raise SystemExit("Target must use binary labels 0 and 1, with 1 representing the documented event.")
    train_ix,test_ix=next(GroupShuffleSplit(n_splits=1,test_size=.30,random_state=42).split(X,y,groups=frame[group]))
    Xtr,Xte,ytr,yte=X.iloc[train_ix],X.iloc[test_ix],y.iloc[train_ix],y.iloc[test_ix]
    if set(ytr)!=set(yte): raise SystemExit("Group split lacks a class in train or test; more labeled participants are needed.")
    numeric=X.select_dtypes(include="number").columns.tolist(); categorical=[c for c in features if c not in numeric]
    pre=ColumnTransformer([("num",Pipeline([("impute",SimpleImputer(strategy="median")),("scale",StandardScaler())]),numeric),("cat",Pipeline([("impute",SimpleImputer(strategy="most_frequent")),("encode",OneHotEncoder(handle_unknown="ignore"))]),categorical)])
    candidates={"logistic_regression":LogisticRegression(max_iter=2000,class_weight="balanced"),"decision_tree":DecisionTreeClassifier(class_weight="balanced",random_state=42),"random_forest":RandomForestClassifier(n_estimators=300,class_weight="balanced",random_state=42),"hist_gradient_boosting":HistGradientBoostingClassifier(random_state=42),"knn":KNeighborsClassifier(n_neighbors=5)}
    results=[]
    for name,model in candidates.items():
        pipe=Pipeline([("preprocess",pre),("model",model)])
        try:
            pipe.fit(Xtr,ytr); pred=pipe.predict(Xte); prob=pipe.predict_proba(Xte)[:,1]
            tn,fp,fn,tp=confusion_matrix(yte,pred,labels=[0,1]).ravel() if set(y.unique())=={0,1} else (0,0,0,0)
            metrics={"accuracy":accuracy_score(yte,pred),"precision":precision_score(yte,pred,pos_label=1,zero_division=0),"recall_sensitivity":recall_score(yte,pred,pos_label=1,zero_division=0),"f1":f1_score(yte,pred,pos_label=1,zero_division=0),"specificity":tn/(tn+fp) if tn+fp else None,"roc_auc":roc_auc_score(yte,prob),"pr_auc":average_precision_score(yte,prob,pos_label=1),"confusion_matrix":[[int(tn),int(fp)],[int(fn),int(tp)]]}
            results.append((name,metrics,pipe))
        except Exception as e: print(f"Skipping {name}: {type(e).__name__}: {e}")
    if not results: raise SystemExit("No candidate completed; no artifact saved.")
    best=max(results,key=lambda r:(r[1]["recall_sensitivity"],r[1]["pr_auc"],r[1]["f1"]))
    out=ROOT/"backend/ml/artifacts";out.mkdir(parents=True,exist_ok=True);joblib.dump(best[2],out/"hypoglycemia_pipeline.joblib")
    metadata={"version":"0.1.0","model":best[0],"features":features,"feature_types":{c:("numeric" if c in numeric else "categorical") for c in features},"target_column":target,"target_definition":"Requires documented event definition/horizon review","group_column":group,"dataset":path.name,"trained_at_utc":datetime.now(timezone.utc).isoformat(),"split":"participant group independent 70/30","metrics":{n:m for n,m,_ in results},"selected_model_metrics":best[1],"clinical_validation":False}
    (out/"metadata.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8");print(json.dumps(metadata,indent=2))
if __name__=="__main__":main()
