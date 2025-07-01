#!/bin/bash

############################################
# Set script variables for later use
############################################
OUTPUTDIR=/opt
APIDB=${OUTPUTDIR}/api.db

SQLDIR=/sql
UPDATE_SCRIPT=${SQLDIR}/django-update.sql
GENERATE_SCRIPT=${SQLDIR}/generate-api-tables.sql

APIDB_SCHEMA=${SQLDIR}/api.schema

if [ -d "${OUTPUTDIR}" ]; # Check that the $OUTPUTDIR exists
then
    echo "Update apk database"
    apk update &> /dev/null

    echo "Install nano and sqlite"
    apk add nano sqlite &> /dev/null

    cd ${OUTPUTDIR} # Change into the $OUTPUTDIR
    rm *.csv ${APIDB} &> /dev/null

    psql -U ${POSTGRES_USER} -d ${DB_NAME} <  ${UPDATE_SCRIPT} &> /dev/null
    if [ $? -eq 0 ]; # Check that the $UPDATE_SCRIPT ran successfully
    then
        echo "Updated Django DB"
        psql -U ${POSTGRES_USER} -d ${DB_NAME} <  ${GENERATE_SCRIPT} &> /dev/null
        if [ $? -eq 0 ]; # Check that the $GENERATE_SCRIPT ran successfully
        then
            echo "API Tables Successfully Exported"
            sqlite3 ${APIDB} ".read ${APIDB_SCHEMA}"
            if [ -f "${APIDB}" ]; # # Check that $APIDB was created
            then
                echo "API Database Created"
                for fn in *.csv; do 
                    TABLE=`basename -s .csv  ${fn}`
                    sqlite3 api.db ".import --skip 1 --csv ${fn} ${TABLE}"
                    if [ $? -eq 0 ];
                    then
                        count=`sqlite3 api.db " select count(*) from ${TABLE}"`
                        echo "Imported ${count} records into ${TABLE}"
                        rm ${fn}
                    fi # Chweck that $fh was importted into $TABLE
                done # Finish loop over *.csv files
            fi # Finish checking for $APIDB
        fi # Finish checking that $GENERATE_SCRIPT ran successfully
    fi # Finish checking that $UPDATE_SCRIPT ran successfully
fi # Finish check thatthe $OUTPUTDIR exists
