#!/bin/bash

psql -q -U ${POSTGRES_USER} -d ${DB_NAME}  < /sql/generate-api-data.sql 2>/dev/null

pg_dump  -U ${POSTGRES_USER} -d api  -C -c --if-exists -Fc -f /opt/api.pgc 

