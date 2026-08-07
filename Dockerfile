# syntax=docker/dockerfile:1

# pull official base image
FROM python:3.11-slim

# set work directory
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py

# install app dependencies (leverage Docker cache by copying requirements.txt first)
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# install app source code into the build container filesystem
COPY . .

# final configuration
EXPOSE 8080
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "wsgi:app"]

# development only
# CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]
