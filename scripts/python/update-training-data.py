from os import path ,environ as env , getcwd
import sys
import pandas as pd
import numpy as np
import pdb, django
from loguru import logger as log
import pdb

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from pprint import pprint
from django_pandas.io import read_frame
from i5k.settings import DATABASES
import psycopg2

pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)
env['DJANGO_SETTINGS_MODULE'] = 'i5k.settings'
django.setup()

DB_USER = env.get('DB_USER')
DB_PASS = env.get('DB_PASS')
DB_HOST = env.get('DB_HOST')
DB_PORT = env.get('DB_PORT')
DB_HOST = env.get('DB_HOST')

DATABASE_URL = f'postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:5432/django'

pprint(DATABASE_URL)

def read_from_db(tbl:str, url:str=DATABASE_URL)->pd.DataFrame:
    engine = create_engine(url, echo=False)
    try:
        
        with engine.connect() as conn: #sessionmaker(autocommit=False, autoflush=False, bind=engine)() as sess:
            query = f"SELECT * FROM {tbl};"
            return pd.read_sql(query, conn)
            
    except Exception as exp:
        raise exp
    
    
dbs = read_from_db('api.databases')

pdb.set_trace()