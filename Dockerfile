# syntax=docker/dockerfile:1

# pull official base image
FROM python:3.11-slim

# set work directory
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py

# install system dependencies
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends \
#         <package-1> \
#         <package-2> \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/*

# install app dependencies (leverage Docker cache by copying requirements.txt first)
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# install app source code into the build container filesystem
COPY . .

# entrypoint
COPY ./entrypoint.sh .
RUN sed -i 's/\r$//g' /usr/src/app/entrypoint.sh # normalize Windows line endings to Unix line endings
RUN chmod +x /usr/src/app/entrypoint.sh

# final configuration
EXPOSE 8080
ENTRYPOINT ["/usr/src/app/entrypoint.sh"]
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "wsgi:app"]
