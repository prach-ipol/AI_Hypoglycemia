# Machine learning boundary

The provided CSV contains food nutrition only. It has no glucose time series, participant IDs, prediction timestamps, hypoglycemia event labels, event horizon, or label provenance. It cannot train a hypoglycemia model. Do not infer risk labels from carbohydrate values.

The training script requires a binary outcome and participant ID column and uses a participant-independent 70/30 split. Before training, document label source, event definition, prediction horizon, measurement timing, cohort, and exclusions. Features must be available at prediction time; exclude future readings and post-outcome information. It compares logistic regression, decision tree, random forest, histogram gradient boosting, and KNN. Review sensitivity, specificity, precision, F1, ROC-AUC, PR-AUC, and confusion matrix. Selection prioritizes sensitivity, then PR-AUC and F1; this is not a clinical threshold or proof of safety. External validation and clinical review are needed.

The app returns HTTP 503 while no artifact exists. Never load user-uploaded joblib files.
