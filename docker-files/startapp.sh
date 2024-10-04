#!/bin/bash
export DB_NAME=${1}

LOCATION=`pwd`
source ~/.bashrc
cd ${LOCATION}
env | grep -E "(DB|DIR)_"
APP_HOME/.venv/bin/uwsgi --ini ${LOCATION}/i5k.ini
