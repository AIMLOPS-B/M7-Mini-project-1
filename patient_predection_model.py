import numpy as np
import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score
from xgboost import XGBClassifier

class PatientPredictionModel:
    def __init__(self, data_path, model_path):
        self.data_path = data_path
        self.model_path = model_path
        self.model = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None

    def handle_outliers(self,df, colm):
        '''Change the values of outlier to upper and lower whisker values '''
        q1 = df.describe()[colm].loc["25%"]
        q3 = df.describe()[colm].loc["75%"]
        iqr = q3 - q1
        lower_bound = q1 - (1.5 * iqr)
        upper_bound = q3 + (1.5 * iqr)
        for i in range(len(df)):
            if df.loc[i,colm] > upper_bound:
                df.loc[i,colm]= upper_bound
            if df.loc[i,colm] < lower_bound:
                df.loc[i,colm]= lower_bound
        return df

    def load_data(self):
        # Load the dataset
        data = pd.read_csv(self.data_path)
        # Preprocess the data
        outlier_colms = ['creatinine_phosphokinase', 'ejection_fraction', 'platelets', 'serum_creatinine', 'serum_sodium']
        for colm in outlier_colms:
            data = self.handle_outliers(data, colm)
        
        X = data.iloc[:, :-1].values  # Features
        y = data['DEATH_EVENT'].values  # Target variable
        return X, y

    def split_data(self, X, y):
        # Split the dataset into training and testing sets
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(X, y, test_size = 0.3, stratify = y, random_state= 123)

    def train_model(self):
        # Train the XGBoost classifier
        self.model = XGBClassifier(n_estimators=200, max_depth=4, max_leaves=5, random_state=42)
        self.model.fit(self.X_train, self.y_train)

    def evaluate_model(self):
        # Evaluate the model on the test set
        y_pred = self.model.predict(self.X_test)
        accuracy = accuracy_score(self.y_test, y_pred)
        f1 = f1_score(self.y_test, y_pred)
        print(f"Accuracy: {accuracy:.2f}")
        print(f"F1 Score: {f1:.2f}")

    def save_model(self):
        # Save the trained model to a file
        joblib.dump(self.model, self.model_path)

    def load_model(self):
        # Load the trained model from a file
        self.model = joblib.load(self.model_path)

    def predict(self, new_data):
        # Predict using the trained model
        return self.model.predict(new_data)
    
    def predict_death_event(self,*data_):

        _data = {
           'age':data_[0],
           'anaemia':data_[1],
           'creatinine_phosphokinase':data_[2],
           'diabetes':data_[3],
           'ejection_fraction':data_[4],
           'high_blood_pressure':data_[5],
           'platelets':data_[6],
           'serum_creatinine':data_[7],
           'serum_sodium':data_[8],
           'sex':data_[9],
           'smoking':data_[10],
           'time':data_[11]
           }
        data = pd.DataFrame([_data])
        data['sex'] = 1 if _data['sex'] == 'Male' else 0
        for feature in ['anaemia','diabetes','high_blood_pressure','smoking']:
            data[feature] = 1 if _data[feature] == 'Yes' else 0

        pred = int(self.model.predict(data)[0])
        return "There are chances for DEATH_EVENT" if pred ==1 else "There are no chances for DEATH EVENT"