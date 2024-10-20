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

# Make port 5000 available to the world outside this container
EXPOSE 5000

# Define environment variables
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=5000

# Run Flask development server when the container launches
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
