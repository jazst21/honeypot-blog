# Use an official Python runtime as the base image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install the required packages
RUN pip install --no-cache-dir -r requirements.txt

# Define environment variable
ARG APP_FILE=app.py
COPY ${APP_FILE} app.py

# Copy the templates folder
COPY templates/ ./templates/

# Expose port 80
EXPOSE 80

# Define environment variables
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=80

CMD ["python", "app.py"]
