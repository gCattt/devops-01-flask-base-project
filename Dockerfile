# syntax=docker/dockerfile:1

###########
# BUILDER #
###########

# pull official base image
FROM python:3.11-slim AS builder

# set work directory
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py

# install system dependencies
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends <packages> \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/*

# install app dependencies (leverage Docker cache by copying requirements.txt first)
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# install app source code into the build container filesystem
COPY . .

#########
# FINAL #
#########

# pull official base image
FROM python:3.11-slim AS final

# set work directory
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py

# copy installed dependencies and application source code from the builder stage
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/src/app /usr/src/app

# entrypoint
RUN sed -i 's/\r$//g' /usr/src/app/entrypoint.sh # normalize Windows line endings to Unix line endings
RUN chmod +x /usr/src/app/entrypoint.sh

# create non-root app user (best practice for security reasons)
RUN addgroup --system app && adduser --system --ingroup app app

# chown all the files to the app user
# otherwise, the app user will not have permission to write to the app directory and will fail to start
RUN chown -R app:app /usr/src/app

# change to the app user
USER app

# final configuration
EXPOSE 8080
ENTRYPOINT ["/usr/src/app/entrypoint.sh"]
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "wsgi:app"]
