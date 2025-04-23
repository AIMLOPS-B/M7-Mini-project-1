import gradio
import joblib
import numpy as np
import pandas as pd
import warnings
import os
relative_path = './app/model/xgboost_model.pkl'
absolute_path = os.path.abspath(relative_path)
model =  joblib.load(absolute_path)
def predict_death_event(*data_):

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

  pred = int(model.predict(data)[0])
  return "There are chances for DEATH_EVENT" if pred ==1 else "There are no chances for DEATH EVENT"

inputs=[
    gradio.Slider(minimum=1,maximum=100,label='age',value=55),
    gradio.Radio(choices=['Yes','No'],label="anaemia",value='No'),
    gradio.Slider(minimum=0,maximum=1000000,value=7861,label="creatinine_phosphokinase"),
    gradio.Radio(choices=['Yes','No'],label="diabetes",value='No'),
    gradio.Slider(minimum=0,maximum=1000000,value=38,label="ejection_fraction"),
    gradio.Radio(choices=['Yes','No'],label="high_blood_pressure",value='No'),
    gradio.Slider(minimum=0,maximum=100000000,value=38,label="platelets"),
    gradio.Slider(minimum=1,maximum=100,label='serum_creatinine',value=1.1),
    gradio.Slider(minimum=1,maximum=1000,label='serum_sodium',value=136.0),
    gradio.Radio(choices=['Male','Female'],label="sex",value='Male'),
    gradio.Radio(choices=['Yes','No'],label="smoking",value='No'),
    gradio.Slider(minimum=1,maximum=100,label='time',value=6.0)
    ]
outputs=["text"]

# Gradio interface to generate UI link
title = "Patient Survival Prediction"
description = "Predict survival of patient with heart failure, given their clinical record"

iface = gradio.Interface(fn = predict_death_event,
                         inputs = inputs,
                         outputs = outputs,
                         title = title,
                         description = description,
                         allow_flagging='never')

iface.launch(share = True)