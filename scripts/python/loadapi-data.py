"""Load API Data Files To SqlLite DB"""

from os import path ,environ
import sqlite3

import pdb
from glob import glob
import django
import pandas as pd

PATH_PREFIX = "/usr/local/i5k/media/blast/db"
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)
environ['DJANGO_SETTINGS_MODULE'] = 'i5k.settings'
django.setup()


if __name__ == "__main__":
    frames = {}
    records = pd.DataFrame()
    
    print("Connecting to sqlite database")
    conn = sqlite3.connect('../data/api/api.db')

    print("Begin writing data to the database")
    for filepath in glob("../data/api/*.json"):
        key = path.basename(filepath).split(".json")[0]
        df = pd.read_json(filepath, orient='records')
        try:
            key.index("-")
            src,tbl = key.split("-")
            header = ['src','tbl'] + df.columns.to_list()
            # df['src'] = src
            # df['tbl'] = tbl
            records = pd.concat([records, df])
            
            df.to_sql(key.replace('-','_'), conn, if_exists='replace', index=False)
            
        except ValueError:
            df.to_sql(key, conn, if_exists='replace', index=False)
        print(f"Writing {len(df)} {key} records to api.db")
        
    print("Finish writing data to the database")
    conn.close()
    print("Disconnecting from sqlite database")
