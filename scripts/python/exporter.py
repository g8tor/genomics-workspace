import os,sys, django, pdb, sqlite3

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "i5k.settings")
django.setup()
import numpy as np
import pandas as pd

from typing import List, Dict
from collections import OrderedDict
from django_pandas.io import read_frame

from app.models import Organism
from blast.models import BlastDb, SequenceType, JbrowseSetting
from hmmer.models import HmmerDB

from loguru import logger as log


import os, django, pdb, sqlite3

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "i5k.settings")
django.setup()
import numpy as np
import pandas as pd

from django_pandas.io import read_frame

from app.models import Organism
from blast.models import BlastDb, SequenceType, JbrowseSetting
from hmmer.models import HmmerDB

from loguru import logger as log

def write_to_sqlite(db:str, table:str, df:pd.DataFrame)->pd.DataFrame:
    """Write Data to SQLite DB"""
    mydf = df.copy()
    with sqlite3.connect(db) as conn:
        mydf.drop(columns=['src','tbl'], inplace=True, errors="ignore")
        if not table.endswith("settings"):
            mydf.drop(columns=['blastdb_id'], inplace=True, errors='ignore')
        log.success(f"Writing {len(mydf)} records to {table.replace('_',' ').title()} table")
        mydf.to_sql(table, conn, if_exists='replace', index=False)
    return mydf

def export_fasta_file_list(file_path:str) -> pd.DataFrame:
    """Export Combined Fasta File List"""

    # Using django orm's raw feature we execute the 
    # following query against the blast and hmmer tables
    query = "SELECT distinct id, concat('/usr/local/i5k/media/blast/db/',regexp_replace(fasta_file,'^.*\/','')) as fasta_file from TABLE_TABLEdb where is_shown = True order by fasta_file asc;"

    # Set the list of fieldnames we want to extract from the tables
    fieldnames = ['fasta_file']
    # Exexutecute the above queries against the django database
    # and create a pandas dataframe.
    blast_results = BlastDb.objects.raw(query.replace("TABLE","blast"))
    hmmer_results = HmmerDB.objects.raw(query.replace("TABLE","hmmer"))

    prod_ff = pd.concat(
        [
            read_frame(blast_results, fieldnames=fieldnames, verbose=False),
            read_frame(hmmer_results, fieldnames=fieldnames, verbose=False),
        ]
    )

    blast_results = BlastDb.objects.using("training").raw(query.replace("TABLE","blast"))
    hmmer_results = HmmerDB.objects.using("training").raw(query.replace("TABLE","hmmer"))
    train_ff = pd.concat(
        [
            read_frame(blast_results, fieldnames=fieldnames, verbose=False),
            read_frame(hmmer_results, fieldnames=fieldnames, verbose=False),
        ]
    )

    # Finally create a single data frame with all the distinct
    # fasta file names and locations so that we can generate the
    # checksums for each from the command line
    df = pd.concat([prod_ff, train_ff])\
        .sort_values(by=fieldnames, ascending=True)\
        .drop_duplicates()

    # Check that the file exists
    df['exists'] = df[fieldnames[0]].apply(lambda a: os.path.exists(a.strip()))

    # Notify the user of the exported file location
    log.debug(f"Exporting {len(df)} fasta file entries to {file_path}")
    df[['fasta_file']].to_csv(file_path,header=False,index=False)

    # Return the data frame
    return df

def generate_fasta_file_list(file_path:str):
    """Generate The List of FAsta Files"""
    log.debug(f"{file_path} not located.")

    # Get the raw list of file locations
    df = export_fasta_file_list(file_path)
    log.debug(f"Located {len(df)} distinct fasta file entries")

    # Check for missing file locations and noptify the user
    missing = df.loc[df.exists == False]
    if missing.empty:
        log.debug(f"All {len(df)} fasta file exist on the file system")
    else:
        log.error(f"Located {len(missing)} missing Fasta Files")
        pdb.set_trace()

    # Notify The User of the next steps and exit
    log.info("Run The following commands to generate the checksum file.")
    print("cd exporter/data")
    print("cat fasta_file.txt | xargs md5sum > production.md5")
    sys.exit(0)

def process_fasta_files(checksum:str, dbpath:str)->pd.DataFrame:
    """Process FAsta Files"""
    
    # Read in the fastafile data and notify the user
    df = pd.read_csv(checksum,sep="  ",
                engine="python", names=["checksum", "fasta_file"])
    log.debug("Begin Processing Fasta File Data")

    # Sanity Checks
    assert df.loc[df.checksum.duplicated()].empty
    assert df.loc[df.fasta_file.duplicated()].empty
    assert df.loc[df.duplicated()].empty

    # Reset the index, generate ids for each entry
    # arrange columns and  set deafult
    df.reset_index(drop=True, inplace=True)
    df['id'] = df.index + 1
    df = df[['id','checksum','fasta_file']]
    df.loc[:,'is_shown'] = True
    
    # Write the fastafiles data to the database
    df = write_to_sqlite(dbpath,"fastafiles",df)
    
    # Modify the data frame for further processing
    df = df.rename(columns={'id':'fastafile_id'})
    df.drop(columns=['is_shown'],inplace=True)
    df.fasta_file = df.fasta_file.apply(lambda a: os.path.basename(a.strip()))
    log.debug("Finished Processing Fasta File Data")

    # Return the data frame
    return df

def process_sequence_types(dbpath:str)->pd.DataFrame:
    """Process Sequence Types"""
    log.debug("Begin Processing Sequence Type Data")
    df = read_frame(SequenceType.objects.all().order_by('id'), verbose=False)
    log.info(f"Loaded {len(df)} Sequence Type records")
    df = write_to_sqlite(dbpath,"sequencetypes",df)
    log.debug("Finish Processing Sequence Type Data")
    df.rename(columns={'id':'type'}, inplace=True)
    return df

def process_organisms(dbpath:str)->List[pd.DataFrame]:
    """Process and Consolidate Organism Records"""
    
    # Using django orm's raw feature execute the following
    po = "select lower(trim(short_name)) as short_name, trim(display_name) as display_name, tax_id, id , NULL as train_id  from app_organism order by display_name ASC;"
    to = "select lower(trim(short_name)) as short_name, trim(display_name) as display_name, tax_id, NULL as prod_id ,id from app_organism order by display_name ASC;"

    log.debug("Begin Pre Processing Organism Data")
    # Process the production app_organism results and create a data frame
    por = Organism.objects.raw(po)
    pdf = read_frame(por).rename(columns={'id':'prod_id'}).drop(columns=["description"])
    pdf.prod_id =   pdf.prod_id.astype(int)
    log.debug(f"Located {len(pdf)} Production Organisms.")

    # Process the training app_organism results and create a data frame
    tor = Organism.objects.using('training').raw(to)
    tdf = read_frame(tor).rename(columns={'id':'train_id'}).drop(columns=["description"])
    tdf.train_id =   tdf.train_id.astype(int)
    log.debug(f"Located {len(tdf)} Training Organisms.")
    log.debug("Finished Pre Processing Organism Data")
    
    # Combine the production and training organism dfs
    # and add columns for src and tbl
    raw = pdf.merge(tdf,indicator=True, how="outer",on=['display_name','short_name'])
    raw.loc[raw.prod_id.notna(),'src'] = 'production'
    raw.loc[raw.train_id.notna(),'src'] = 'training'
    
    # Generate the genus and species from the display_name
    raw['genus'] = raw.display_name.apply(lambda a: a.strip().split()[0])
    raw['species'] = raw.display_name.apply(lambda a: " ".join(a.strip().split()[1:]))
    raw.sort_values(by=["genus","species","display_name","short_name","src"],
                    ascending=True,inplace=True)

    # Check for and extract organisms that only exist in 
    # the django database
    nomatch = raw.loc[(raw['_merge'] == "left_only")].copy()
    raw.drop(nomatch.index, inplace=True)
    log.debug(f"Located {len(nomatch)} Producton Only Organisms")

    # Check for and extract organisms that exist in both the django
    # and django databases and have the same id
    matched = raw.loc[(raw['_merge'] == "both") & (raw.prod_id == raw.train_id)].copy()
    raw.drop(matched.index, inplace=True)
    log.debug(f"Located {len(matched)} Matching Organisms")
    log.debug(f"Located {len(raw)} Training Organisms need to be updated")
    
    # Create a df for the training records that need to have their
    # organism_id keys updated
    updates = raw[['train_id','prod_id']].copy()
    pdb.set_trace()
    updates.train_id = updates.train_id.astype(np.int64)
    updates.prod_id = updates.prod_id.astype(np.int64)

    # Combine all dataframes (except updates), arrange columns, create
    # new infraspecies (set default)
    df = pd.concat([nomatch,matched,raw]).drop(columns=['train_id']).rename(
        columns={'prod_id':'id','tax_id_x':'tax_id'})\
            [['id','genus','species','short_name','tax_id']]
    df.loc[:,'infraspecies'] = np.nan
    df.loc[:,'is_shown'] = True
    df.sort_values(by=['genus','species'],ascending=True,inplace=True)

    # Write organism data to the database
    df = write_to_sqlite(dbpath,"organisms",df)

    # Write updae data to the database
    updates = write_to_sqlite(dbpath,"organism_updates",updates)

    # Rename & remove columns for further processing
    updates.rename(columns={"train_id": "organism"}, inplace=True)    
    df.rename(columns={'id':'organism'}, inplace=True)
    df.drop(columns=['infraspecies'], inplace=True)

    # Notify the user
    log.debug("Finish Processing Organism Data")
    log.success(f"Shared Organism count is {len(df)}.")

    # Return data frames
    return [df, updates]

def process_database_data(files:pd.DataFrame,seqs:pd.DataFrame,
                          orgs:pd.DataFrame, updates:pd.DataFrame=None, 
                          using:str="default")->List[pd.DataFrame]:
    """Process Database Info"""
    src = "production" if using.lower() == "default" else using.lower()

    blastids = [db.id for db in BlastDb.objects.using(using).all().filter(is_shown=True) ]
    blast =  BlastDb.objects.using(using).filter(id__in=blastids)
    blast = read_frame(blast, verbose=False).sort_values(by="title",ascending=True)
    blast["tbl"] = "blastdbs"
    blast["src"] = src
    blast.fasta_file = blast.fasta_file.apply(lambda a: os.path.basename(a.path_full.strip()))
    blast = blast.merge(files, how="left")
    assert blast.loc[blast.checksum.isna()].empty
    log.success(f"Matched {len(blast)} {src.title()} Blast DBs to Fasta Files")
    log.debug(f" Loaded {len(blast)} {src.lower().title()} Blast Records.")

    hmmer = [db.id for db in HmmerDB.objects.using(using).all().filter(is_shown=True) ]
    hmmer =  HmmerDB.objects.using(using).filter(id__in=hmmer)
    hmmer = read_frame(hmmer, verbose=False).sort_values(by="title",ascending=True)
    hmmer["type"] = 3
    hmmer["tbl"] = "hmmerdbs"
    hmmer["src"] = src
    hmmer.fasta_file = hmmer.fasta_file.apply(lambda a: os.path.basename(a.path_full.strip()))
    hmmer = hmmer.merge(files, how="left")
    assert hmmer.loc[hmmer.checksum.isna()].empty
    log.success(f"Matched {len(hmmer)} {src.title()} Hmmer DBs to Fasta Files")
    log.debug(f" Loaded {len(hmmer)} {src.lower().title()} Hmmer Records.")
    
    if src == "training" and not updates is None:
        uids = updates.organism.to_list()
        #bu = blast.loc[blast.organism]
        pdb.set_trace()
        
        #ou = df.loc[df.organism.isin(updates.organism.to_list())]
        # if not ou.empty:
        #     df = df.loc[~df.organism.isin(ou.organism.to_list())]
        #     assert len(ou) + len(df) == dfc
        #     ou = ou.merge(updates, on="organism", indicator=True)
        #     ou.loc[:,"organism"] = ou.prod_id
        #     assert ou[ou.organism != ou.prod_id].empty
        #     log.success(f" Updated {len(ou)} Record Organism Field")
        #     ou = ou[df.columns]
        #     df = pd.concat([df, ou])
            
    df = pd.concat([blast, hmmer])
    dfc = len(df)

    # Merge Fasta Files
    # df.fasta_file = df.fasta_file.apply(lambda a: os.path.basename(a.path_full.strip()))
    # df = df.merge(files, how="left")
    #assert df.loc[df.checksum.isna()].empty
   

    # Merge Sequencetypes
    df = df.merge(seqs, how="left")
    assert df.loc[df.molecule_type.isna()].empty
    assert len(df) == dfc 
    log.success("Matched All Sequence Types")

    # Merge Organisms
    df = df.merge(orgs, how="left")
    assert df.loc[df.genus.isna()].empty
    assert df.loc[df.species.isna()].empty
    assert len(df) == dfc
    log.success("Matched All Organisms")

    assert len(blast) == len(df.loc[df.tbl == "blastdbs"])
    assert len(hmmer) == len(df.loc[df.tbl == "hmmerdbs"])
    assert df.loc[:, df.isnull().any()].empty
    assert len(df) == dfc
    log.success("All Counts Match")
    
    # Reset values to correct type
    df.id = df.id.astype(np.int64)
    df.organism = df.organism.astype(np.int64)
    df.type = df.type.astype(np.int64)

    df = df.rename(columns={"id": "blastdb_id"})\
        .sort_values(by=["title", "src","tbl"], ascending=True)

    assert len(df) == (
        len(df.loc[df.tbl == "blastdbs"]) + len(df.loc[df.tbl == "hmmerdbs"])
    )

    blastinfo = df.loc[(df.src == src.lower()) & (df.tbl == "blastdbs")][
        ["blastdb_id"]
    ]

    jbrowse = read_frame(JbrowseSetting.objects.using(using).filter(blast_db_id__in=blastids),
                         verbose=False)\
        .rename(columns={"blast_db": "blastdb_id"})
    log.debug(f"Loaded {len(jbrowse)} Jbrowse Setting Records")
    jbrowse["tbl"] = "blastdbs"
    jbrowse["src"] = src.lower()
    jbrowse = jbrowse.merge(blastinfo, indicator=True)
    assert jbrowse.loc[jbrowse["_merge"] != "both"].empty
    log.success(f"Matched {len(jbrowse)} Blast Database IDs")
    jbrowse.drop(columns=["_merge","id"], inplace=True)
    jbrowse.reset_index(inplace=True, drop=True)
    jbrowse['id'] = jbrowse.index + 1

    drop = orgs.columns.to_list() +seqs.columns.to_list()
    df = df.rename(columns={'organism':'organism_id','type':'sequencetype_id'})\
        .drop(columns=drop, errors="ignore")

    return [df, jbrowse]


if __name__ == "__main__":
    # Table Related Constants
    MATCH = ["organism_id", "fastafile_id", "title", "checksum"]    
    GROUPED= ["src", "tbl"]
    SORTBY = MATCH + GROUPED

    # Pathe Related Constants
    EXPORTDIR = os.environ.get('DATADIR')
    EXPORTED_DJANGO = os.path.join(EXPORTDIR,"django_export.db")
    FASTA_FILE_PATH = os.path.join(EXPORTDIR,"fastafiles.txt")
    CHECKSUM_PATH = f"{EXPORTDIR}/fastafiles.md5"

    # Create the directory when datafiles will be exported
    os.makedirs(EXPORTDIR, exist_ok=True)

    # Check if the list of fasta files exists
    if not os.path.exists(FASTA_FILE_PATH):
        # if the list of fasta files does not exist
        # generate the list from the existing django
        # databases
        generate_fasta_file_list(FASTA_FILE_PATH)

    # Check if the checksum file for fastafiles exists
    if not os.path.exists(CHECKSUM_PATH):
        # Notify the user and exit
        log.error(f"{CHECKSUM_PATH} does not exist")
        log.info("Run The following commands to generate the checksum file.")
        print("cd exporter/data")
        print(f"cat fasta_file.txt | xargs md5sum > {os.path.basename(CHECKSUM_PATH)}")
        sys.exit(1)

    # log.info(f"Located {FASTA_FILE_PATH}")
    # log.info(f"Located {CHECKSUM_PATH}")

    # Initialize the shared ordered dictionary for df storage
    shared:Dict[str,pd.DataFrame] = OrderedDict()

    # Process and combine organism lists from the
    # django and django_training dbs
    organisms, updates = process_organisms(EXPORTED_DJANGO)

    shared['organisms'] = organisms
    shared['updates'] = updates

    # Get the mostly static sequence types data
    shared['sequencetypes'] = process_sequence_types(EXPORTED_DJANGO)

    # Create the fastafiles tables from the CHECKSUM_PATH file
    shared['fastafiles'] = process_fasta_files(CHECKSUM_PATH, EXPORTED_DJANGO)

    # Set local variables for so we don't have to ref like shared[*]
    files = shared['fastafiles']
    seqs = shared['sequencetypes']
    orgs = shared['organisms']
    updates = shared['updates']

    # Get Production & Training Database/ Jbrowse Data
    pdbs,pjbrowse = process_database_data(files, seqs, orgs)
    tdbs,tjbrowse = process_database_data(files, seqs, orgs, updates, "training")
    dbmatch = files.columns.to_list()
    files.rename(columns={'fastafile_id':'id'},inplace=True)
    dbs = pd.concat([pdbs,tdbs],ignore_index=True).drop_duplicates(subset=dbmatch)
    #dbs.drop(columns=GROUPED+['fasta_file'], inplace=True)
    dbs.sort_values(by="fastafile_id",ascending=True, inplace=True)
    dbs['database_id'] = dbs.fastafile_id

    assert len(files) == len(dbs)
    assert dbs.loc[dbs.checksum.isna()].empty
    assert dbs.loc[dbs.checksum.duplicated()].empty
    matchdb = dbs[['fasta_file','checksum','fastafile_id','database_id']]
    
    pblast = pdbs.loc[(pdbs.src == "production") & (pdbs.tbl == "blastdbs")]
    pbc = len(pblast)
    pblast = pblast.merge( matchdb ,how="inner",indicator=True)
    assert pbc == len(pblast)
    assert pblast.loc[pblast.database_id.isna()].empty

    phmmer = pdbs.loc[(pdbs.src == "production") & (pdbs.tbl == "hmmerdbs")]
    phc = len(phmmer)
    phmmer = phmmer.merge( matchdb ,how="inner",indicator=True)
    assert phc == len(phmmer)
    assert phmmer.loc[phmmer.database_id.isna()].empty
    
    
    tblast = tdbs.loc[(tdbs.src == "training") & (tdbs.tbl == "blastdbs")]
    tbc = len(tblast)
    tblast = tblast.merge( matchdb ,how="inner",indicator=True)
    assert tbc == len(tblast)
    assert tblast.loc[tblast.database_id.isna()].empty
    
    thmmer = tdbs.loc[(tdbs.src == "training") & (tdbs.tbl == "hmmerdbs")]
    thc = len(thmmer)
    thmmer = thmmer.merge( matchdb ,how="inner",indicator=True)
    assert thc == len(thmmer)
    assert thmmer.loc[thmmer.database_id.isna()].empty
    
    pdb.set_trace()
    
    cols = ['src','tbl','fastafile_id','checksum']
    #pdbs = pdbs.merge(dbs[cols],on=cols,indicator=True).groupby(GROUPED+['_merge'])
    
    
    


    pdb.set_trace()
    
    def check(data:pd.DataFrame, dbdata:pd.DataFrame):
        grouped = data.groupby(GROUPED)
        for group in grouped:
            df = group[1]
            
            pdb.set_trace()
            
    
    
    dbcols = set(files.columns.to_list()+ ["organism_id", "fastafile_id", "title", "checksum"]) 
    databases = pd.concat([pdbs,tdbs],ignore_index=True).drop_duplicates(subset=files.columns)
    
    pdb.set_trace()
    
    
    
    check(pdbs, databases)
    pdb.set_trace()
    databases.reset_index(drop=True, inplace=True)
    databases['database_id'] = databases.index + 1
    dbcols = ['blastdb_id', 'database_id','organism_id','sequencetype_id','fastafile_id', 'title','description','checksum', 'fasta_file']
    databases = databases[dbcols]
    

    

    # Process shared databases
    
    #jbrowse = pd.concat([pjbrowse, tjbrowse])
    
    # for x in [pdbs,pjbrowse,tdbs,tjbrowse]:
    #     log.info(f"{x.groupby(GROUPED).count()} \n\n")
    
    pdb.set_trace()
    
    #jbrowse = pd.concat([pjbrowse, tjbrowse])
    
    

    # Reset the jbrowse setting tble value for matching later
    #jbrowse['tbl'] = "blastdbs"

    # Combine production and traing database df and drop 
    # unrelated columns
    dcolumns = organisms.columns.to_list() +seqs.columns.to_list()
    dbs = pd.concat([pdbs,tdbs],ignore_index=True)
    dbs.rename(columns={'organism':'organism_id','type':'sequencetype_id'},inplace=True)
    dbs.drop(columns=dcolumns,errors="ignore", inplace=True)
    dbs.drop_duplicates(subset=files.columns, inplace=True)
    dbs.reset_index(drop=True, inplace=True)
    dbs['is_shown'] = True
    dbs['database_id'] = dbs.index + 1
    
    pdb.set_trace()

    # Set db column list
    dbc = ['blastdb_id','database_id','organism_id','fastafile_id',
           'sequencetype_id','checksum','fasta_file','title',
           'description','is_shown']
    dbs = dbs[dbc].drop_duplicates(subset=files.columns)

    # Rename columns
    columns = {'organism':'organism_id','type':'sequencetype_id'}
    pdbs.rename(columns=columns,inplace=True, errors="ignore")
    tdbs.rename(columns=columns,inplace=True, errors="ignore")

    # Drop columns
    pdbs.drop(columns=dcolumns,inplace=True, errors="ignore")
    tdbs.drop(columns=dcolumns,inplace=True, errors="ignore")

    dbc = ['blastdb_id','database_id','organism_id']
    pdbs = pdbs.merge(dbs[['database_id','checksum']]).drop(
        columns=files.columns.to_list())[GROUPED + dbc]

    #log.debug(f"\n Producton DBs\n {pdbs.groupby(GROUPED).count()}")
    pbdbs = pdbs.loc[(pdbs.src == "production") & (pdbs.tbl == "blastdbs")]\
        .reset_index(drop=True)
    pbdbs['id'] = pbdbs.index + 1
    pbdbs.loc[:,'is_shown'] = True

    # Get Blastid for matching aginst jbrowse records later
    pblastids = pbdbs[GROUPED+['blastdb_id','id']].copy().rename(
        columns={'id':'new_blast_id'}
    )

    # Handle Production Hmmer Databases
    phdbs = pdbs.loc[(pdbs.src == "production") & (pdbs.tbl == "hmmerdbs")][dbc[1:]]\
        .reset_index(drop=True)
    phdbs['id'] = phdbs.index + 1
    phdbs.loc[:,'is_shown'] = True


    tdbs = tdbs.merge(dbs[['database_id','checksum']]).drop(
        columns=files.columns.to_list())[GROUPED + dbc]
    
    #log.debug(f"\n Training DBs\n {tdbs.groupby(GROUPED).count()}")
    tbdbs = tdbs.loc[(tdbs.src == "training") & (tdbs.tbl == "blastdbs")]\
        .reset_index(drop=True)
    tbdbs['id'] = tbdbs.index + 1
    tbdbs.loc[:,'is_shown'] = True
    
    tblastids = tbdbs[GROUPED+['blastdb_id','id']].copy().rename(
        columns={'id':'new_blast_id'}
    )
    
    # Handle Updating JBrowse Records
    blastids = pd.concat([pblastids,tblastids])
    jbrowsec = len(jbrowse)
    jbrowse = jbrowse.merge(blastids,indicator=True)
    assert len(jbrowse.loc[jbrowse['_merge'] == 'both']) == jbrowsec
    log.success(f"Matched All {jbrowsec} JBrowse Settings to Blast Records")
    jbrowse.loc[:,'blastdb_id'] = jbrowse['new_blast_id']
    jcols = ['id','blastdb_id','url']

    shared['production_jbrowsesettings'] = jbrowse.loc[jbrowse.src == 'production'][jcols]
    shared['training_jbrowsesettings']= jbrowse.loc[jbrowse.src == 'training'][jcols]
    
    thdbs = tdbs.loc[(tdbs.src == "training") & (tdbs.tbl == "hmmerdbs")][dbc[1:]]\
        .reset_index(drop=True)
    thdbs['id'] = thdbs.index + 1
    thdbs.loc[:,'is_shown'] = True

    dbs = dbs.rename(columns={'database_id':'id'}).sort_values(by=[
        'title','description'], ascending=True)
    dbs["title" ] = dbs.title.apply(lambda a: a if a[0] !=  "/" else os.path.basename(a))

    columns = ['id','organism_id','sequencetype_id','fastafile_id','title','description']
    dbcols = ['id','database_id','organism_id','is_shown']
    
    shared['production_blastdbs'] = pbdbs[dbcols]
    shared['production_hmmerdbs'] = phdbs[dbcols]
    shared['training_blastdbs'] = tbdbs[dbcols]
    shared['training_hmmerdbs'] =  thdbs[dbcols]
    shared['databases'] = dbs[columns].copy()
    
    for name, table in shared.items():
        label = name.replace('_',' ').title()
        count = len(table)
        write_to_sqlite(EXPORTED_DJANGO, name, table)
        #log.info(f"{label} contains {count} records")
    log.success(f"The exported data can be found\n{os.path.abspath(EXPORTED_DJANGO)}")
    

