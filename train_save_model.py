from patient_survival_predection_model import PatientPredictionModel

ppm = PatientPredictionModel("dataset/heart_failure_clinical_records_dataset.csv", "trained_model/xgboost_model.pkl")

X, y = ppm.load_data()
ppm.split_data(X, y)
ppm.train_model()
ppm.evaluate_model()
ppm.save_model()