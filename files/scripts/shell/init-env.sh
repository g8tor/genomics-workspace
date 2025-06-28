#!/bin/bash -l

psql -U ${POSTGRES_USER} -d ${DB_NAME} < /sql/django-update.sql
psql -U ${POSTGRES_USER} -d ${DB_NAME} < /sql/generate-api-views.sql
echo `whoami`
apk update
apk add poetry gcc python3-dev musl-dev linux-headers

mkdir -p /export/.venv
cd /export/lib/
poetry install --no-root
poetry run pip freeze | grep -E "pandas|dantic"
#py3-pip py3-psycopg py3-pandas py3-sqlalchemy
 
