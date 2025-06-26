#!/bin/bash -l
# entry-point.sh
set -e

cd /docker-entrypoint-initdb.d/

PUBLIC_COUNT_QUERY="SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount FROM pg_stat_all_tables WHERE schemaname = 'public' AND relname NOT LIKE 'pg%' AND relname NOT LIKE 'sql%' order by schemaname, relname;"

pg_restore -O -U ${POSTGRES_USER}  -C -d postgres /${DB_NAME}.pgc

echo "Production Content Count"
psql -U ${POSTGRES_USER} -c "${PUBLIC_COUNT_QUERY}" ${DB_NAME}

pg_restore -O -U ${POSTGRES_USER}  -C -d postgres /${DB_NAME}_training.pgc

echo "Training Content Count"
psql -U ${POSTGRES_USER} -c "${PUBLIC_COUNT_QUERY}" ${DB_NAME}_training
