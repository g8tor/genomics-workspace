#!/bin/bash

OUTPUTDIR=/opt
UPDATE_SCRIPT=/sql/django-update.sql
GENERATE_SCRIPT=/sql/generate-api-views.sql
APIDB=${OUTPUTDIR}/api.db

if [ -d "${OUTPUTDIR}" ];
then
    apk update &> /dev/null
    apk add nano sqlite &> /dev/null

    cd ${OUTPUTDIR}
    rm *.csv ${APIDB} &> /dev/null

    psql -U ${POSTGRES_USER} -d ${DB_NAME} <  ${UPDATE_SCRIPT} &> /dev/null
    if [ $? -eq 0 ];
    then
        echo "Updated Django DB"
        if [ $? -eq 0 ];
        then
            psql -U ${POSTGRES_USER} -d ${DB_NAME} <  ${GENERATE_SCRIPT} &> /dev/null
            if [ $? -eq 0 ];
            then
                echo "API Tables Successfully Generated & Exported"
                sqlite3 ${APIDB} ".read api.schema"
                if [ -f "${APIDB}" ];
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
                        fi
                    done
                fi
            fi
        fi
    fi
fi
