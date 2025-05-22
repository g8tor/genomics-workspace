"""Combine into sqlite3 database"""
from collections import OrderedDict
from os import path # makedirs, chdir, path,getcwd
import pdb
import sqlite3
import pandas as pd
import numpy as np

#################################################
# Set pandas related options
################################################
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)

#################################################
# Set Column related variables
#################################################
match = ['organism','fastafile_id','title','checksum']
final_cols = ['id','oid','sid', 'ffid','title','tbl','src','description','is_shown']
rename= {'organism':'oid','type':'sid','fastafile_id':'ffid'}
grouped_cols = ['src','tbl']
sortby = match + ['src','tbl']

def write_to_sqlite(frames: OrderedDict[str,pd.DataFrame]):
    """Write Data to SQLite DB"""
    with sqlite3.connect("api.db") as conn:
        for name, frame in frames.items():
            if name.count("_"):
                frame.drop(columns=['src','tbl'], inplace=True)
            if not name.endswith("settings"):
                frame.drop(columns=['blastdb_id'], inplace=True, errors='ignore')
            print(f"Writing {len(frame)} records to {name.replace('_',' ').title()} table")
            frame.to_sql(name, conn, if_exists='replace')
                
                



def update_grouped_dfs(grouped:pd.core.groupby.generic.DataFrameGroupBy, _dfs: OrderedDict):
    """Split Data """
    for group in grouped:
        df = group[1]
        name = "_".join(group[0])
        df = group[1].reset_index(drop=True)
        df['id'] = df.index + 1
        _dfs.update({f'{name}' : df.copy()})
        
                
def get_dbs(prefix:str)->pd.DataFrame:
    """ Generic Function 
    """
    
    dc = ['organism', 'type', 'fasta_file', 'title']
    seqs_info = dfs['sequencetypes'][['id']].rename(columns={'id':'type'})

    src = f'{prefix.lower()}-blastdbs.csv'
    blast = pd.read_csv(src).apply(lambda x: x.str.strip() if x.dtype == "object" else x)
    blastc = len(blast)
    blast.fasta_file = blast.fasta_file.apply(lambda a: path.basename(a.strip()))
    blast = blast.merge(fasta_files,how='left',indicator=True).merge(seqs_info,how="left")
    blast['tbl'] = "blast"
    blast['src'] = prefix.lower()
    assert blast.loc[blast.checksum.isna()].empty
    
    src = f'{prefix.lower()}-hmmerdbs.csv'
    hmmer = pd.read_csv(src).apply(lambda x: x.str.strip() if x.dtype == "object" else x) 
    hmmerc = len(hmmer)
    hmmer.fasta_file = hmmer.fasta_file.apply(lambda a: path.basename(a.strip()))
    hmmer['type'] = 3
    hmmer = hmmer.drop_duplicates(subset=dc)    
    hmmer = hmmer.merge(fasta_files,how='left',indicator=True).merge(seqs_info,how="left")
    hmmer['tbl'] = "hmmer"
    hmmer['src'] = prefix.lower()
    assert hmmer.loc[hmmer.checksum.isna()].empty

    combo = pd.concat([ hmmer,blast]).dropna()
    combo.id = combo.id.astype(np.int64)
    combo.organism = combo.organism.astype(np.int64)
    combo.type = combo.type.astype(np.int64)
    combo.rename(columns={'id':'blastdb_id'}, inplace=True)
    combo.loc[combo.tbl == "hmmer", 'blastdb_id' ] = 0
    #combo.drop(columns=['fasta_file'], inplace=True)

    assert len(blast.loc[blast['_merge'] == "both"]) == blastc
    assert len(hmmer.loc[hmmer['_merge'] == "both"]) == hmmerc
    assert len(combo.loc[combo['_merge'] == "both"]) == (blastc + hmmerc)

    sort_cols = ['organism','title','type','tbl']
    combo = combo.drop(columns=['_merge']).sort_values(by=sort_cols)

    src = f'{prefix.lower()}-jbrowse.csv'
    jbdf = pd.read_csv(src).rename(columns={"blast_db":"blastdb_id"})
    jbdf['tbl'] = "jbrowsesettings"
    jbdf['src'] = prefix.lower()
    jbdf.drop(columns="id",inplace=True)
    jbdf.reset_index(inplace=True)
    jbdf['id'] = jbdf.index + 1
    #jbdf = jbdf[['src','tbl','id','blastdb_id','url']]
    jbdfc = len(jbdf)

    dbinfo = blast[['src','id','checksum']].rename(columns={'id':'blastdb_id'}).copy()
    jbdf = jbdf.merge(dbinfo, on=['src','blastdb_id'],indicator=True) #.groupby('_merge').count()
    assert len(jbdf) == jbdfc
    jbdf = jbdf[['src','tbl','blastdb_id','url']]

    return [combo,jbdf]

def update_organisms(df:pd.DataFrame)->pd.DataFrame:
    """Update the training database organisms

    Args:
        df (pd.DataFrame): Current Training DataFrame

    Returns:
        pd.DataFrame: Updated training database DataFrame
    """
    ou = pd.read_csv("training-organism-update.csv")

    updates = df.loc[df.organism.isin(
        ou.organism.to_list())].copy()

    df = df.loc[~df.organism.isin(
        ou.organism.to_list())]
    if not updates.empty:
        updates = updates.merge(ou,on="organism").drop(columns=["organism"]).rename(
            columns={'organism_id':'organism'}
        )
        df = pd.concat([df,updates])
        
    return df.copy()

#########################
# Gather Fasta File Data
#########################
# SELECT distinct concat('/usr/local/i5k/media/blast/db/',regexp_replace(fasta_file,'^.*\/','')) as fasta_file from blast_blastdb where is_shown = True order by fasta_file asc;
# SELECT distinct concat('/usr/local/i5k/media/blast/db/',regexp_replace(fasta_file,'^.*\/','')) as fasta_file from hmmer_hmmerdb order by fasta_file asc;

dfs = OrderedDict([
    ('organisms', pd.read_csv("organisms.csv")),
    ('sequencetypes',pd.read_csv('sequencetypes.csv')),
    ('fastafiles',  pd.read_csv("../production.md5",sep="  ", engine="python",names=['checksum','fasta_file']))
])

######################################################
# Organism Data
######################################################
organisms = dfs.get('organisms')
organisms['is_shown'] = True
organisms['infraspecies'] = None
organisms.drop(columns=['short_name','display_name'],inplace=True)
organisms.sort_values(by=['genus'])


######################################################
# Sequence Type Data
######################################################
seqs = dfs.get('sequencetypes')

######################################################
# Generate Fasta File Table Data #pd.read_csv("../production.md5",sep="  ", engine="python",names=['checksum','fasta_file'])
######################################################
fasta_files = dfs.get('fastafiles')
fasta_files.fasta_file = fasta_files.fasta_file.apply(lambda a: path.basename(a.strip()))
fasta_files.drop_duplicates(keep="first",inplace=True)
fasta_files.reset_index(drop=True, inplace=True)
fasta_files['fastafile_id'] = fasta_files. index + 1

######################################################
# Production Blast /Hmmer DBs
######################################################
production, pjbrowse = get_dbs("production")

######################################################
# Training Blast /Hmmer DBs
######################################################
training, tjbrowse = get_dbs("training")
training = update_organisms(training)

######################################################
# Combine Production & Training JBrowse
######################################################
jbrowse = pd.concat([pjbrowse, tjbrowse ])

dbs = pd.concat([production,training]).sort_values(by=sortby).drop(
    columns=["fasta_file",'is_shown']
)

#dfs.update({'databases': dbs.sort_values(by=sortby).drop_duplicates(subset=match).copy()})

shared_dbs =  dbs.sort_values(by=sortby).drop_duplicates(subset=match).copy()
shared_dbs.reset_index(drop=True, inplace=True)
shared_dbs = shared_dbs.sort_values(by=sortby).drop(
    columns=['src','tbl','blastdb_id']).drop_duplicates(subset=match,keep="last")
shared_dbs["database_id"] = shared_dbs.index + 1


dbs = dbs.merge(shared_dbs[match+["database_id"]],on=match,indicator=True)
shared_dbs = shared_dbs.rename(columns={
    'organism':'organism_id', 'type':'sequencetype_id','database_id':'id'
}).drop(columns=['checksum'])[[ 'id','organism_id','sequencetype_id','fastafile_id', 'title', 'description' ]]
dfs.update({'databases':shared_dbs})


dbs = dbs[['tbl', 'src','organism',  'database_id','blastdb_id']].reset_index(drop=True).rename(columns={
    'organism':'organism_id'
})
dbs = dbs.groupby(by=['src','tbl'])
update_grouped_dfs(dbs, dfs)

blastdfs = pd.concat([ df[['src','blastdb_id','id']] 
                   for key,df in dfs.items() if key.endswith('_blast') ])

jbdfc = len(jbrowse)
jbrowse = jbrowse.merge(blastdfs)
jbrowse.blastdb_id = jbrowse.id
jbrowse.id = jbrowse.index + 1
assert len(jbrowse) == jbdfc
update_grouped_dfs(jbrowse.groupby(by=['src','tbl']), dfs)

write_to_sqlite(dfs)

# for df in dfs.values(): df.drop(columns=['src','tbl'], errors='ignore', inplace=True)
# _ = [ df.drop(columns=['blastdb_id'], errors='ignore', inplace=True) 
#  for name, df in dfs.items() if not name.endswith('settings') ]

# for df in dfs.values(): print(df.head())
# pdb.set_trace()


################################
# Rename Columns
################################
# dfs['databases'] = shared_dbs.drop(columns=['blastdb_id','checksum']).rename(columns={
#     'organism':'organism_id', 'type':'sequencetype_id','database_id':'id'
# })
# fasta_files.rename(columns={'fastafile_id':'id','fasta_file':'file_name'},inplace=True)




