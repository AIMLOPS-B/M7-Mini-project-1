from python:3.11-slim
# Set the working directory
WORKDIR /app

#Create model directory
RUN mkdir -p /app/model
# Copy the requirements file into the container at /app
COPY app/requirements.txt .
# Copy trained model into the container at /app/model
COPY trained_model/xgboost_model.pkl /app/model/
# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
# Copy the rest of the application code into the container at /app
COPY app/main.py .
# Expose the port the app runs on
EXPOSE 7860
# Run the application
CMD ["python", "main.py"]