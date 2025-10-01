#!/bin/bash
clear
dropdb -U ${POSTGRES_USER} --if-exists ${DB_NAME} &> /dev/null
dropdb -U ${POSTGRES_USER} --if-exists ${DB_NAME}_training &> /dev/null
dropdb -U ${POSTGRES_USER} --if-exists api &> /dev/null
/docker-entrypoint-initdb.d/init-db.sh &> /dev/null
#psql -q -U ${POSTGRES_USER} -d ${DB_NAME}  < /sql/refactor-update.sql
psql -q -U ${POSTGRES_USER} -d ${DB_NAME}  < /sql/generate-api-data.sql