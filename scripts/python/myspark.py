from pyspark.sql import SparkSession
from pyspark.sql import DataFrame

import pdb
db_url = f"jdbc:sqlite:data/api.db"

spark = SparkSession.builder.appName("Django Data").getOrCreate()

def read_db_table(table:str,sess:SparkSession=spark, dburl:str=db_url)->DataFrame:
    try:
        return sess.read.format("jdbc").options(driver='org.sqlite.JDBC',
                                            dbtable=f"{table}",
                                            url=f"{dburl}").load()
    except Exception as exp:
        error = exp
        
        pdb.set_trace()

organisms   = read_db_table("organisms").orderBy(['genus','species'])
seqs        = read_db_table("sequencetypes").drop("index")
pbdbs       = read_db_table("production_blast").drop("index")
phdbs       = read_db_table("production_hmmer").drop("index")
tbdbs       = read_db_table("training_blast").drop("index")
thdbs       = read_db_table("training_hmmer").drop("index")
dbs         = read_db_table("databases").drop("index")
query = "Select concat(d.title ) as display_name ,s.dataset_type from databases as d JOIN sequencetypes as s WHERE d.sequencetype_id = s.id;"

dbs.createTempView("databases")
seqs.createTempView("sequencetypes")

spark.sql(query).show()
print("LETS GO")
pdb.set_trace()