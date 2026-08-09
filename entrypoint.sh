#!/bin/sh

set -e

# database readiness is handled by Docker Compose healthcheck/depends_on
echo "PostgreSQL is ready. Running database migrations..."
flask db upgrade

echo "Starting application..."
exec "$@" # replace entrypoint with the application process (execute the CMD from Dockerfile)
