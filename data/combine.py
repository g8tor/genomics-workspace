import pandas as pd
import numpy as np
import pdb

from os import makedirs, chdir, path,getcwd
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)

def get_dbs(prefix:str)->pd.DataFrame:
    """ Generic Function 
    """
    dc = ['organism', 'type', 'fasta_file', 'title']
    seqs_info = seqs[['id']].rename(columns={'id':'type'})

    src = f'{prefix.lower()}-blastdbs.csv'
    blast = pd.read_csv(src).drop_duplicates(subset=dc)
    blastc = len(blast)
    blast = blast.merge(ff,how='left',indicator=True).merge(seqs_info,how="left")
    blast['tbl'] = "blast"
    blast['src'] = prefix.lower()
    assert len(blast) == blastc    

    src = f'{prefix.lower()}-hmmerdbs.csv'
    hmmer = pd.read_csv(src) 
    hmmer['type'] = 3
    hmmer = hmmer.drop_duplicates(subset=dc)
    hmmerc = len(hmmer)
    hmmer = hmmer.merge(ff,how='left',indicator=True).merge(seqs_info,how="left")
    hmmer['tbl'] = "hmmer"
    hmmer['src'] = prefix.lower()
    assert len(hmmer) == hmmerc
    

    combo = pd.concat([ hmmer,blast]).dropna()
    combo.id = combo.id.astype(np.int64)
    combo.organism = combo.organism.astype(np.int64)
    combo.type = combo.type.astype(np.int64)
    combo.drop(columns=['fasta_file'], inplace=True)

    assert len(blast.loc[blast['_merge'] == "both"]) == blastc
    assert len(hmmer.loc[hmmer['_merge'] == "both"]) == hmmerc
    assert len(combo.loc[combo['_merge'] == "both"]) == (blastc + hmmerc)
    combo.drop(columns=['_merge'], inplace=True)
    
    src = f'{prefix.lower()}-jbrowse.csv'
    jbrowse = pd.read_csv(src).rename(columns={"blast_db":"blastdb_id"})
    jbrowse['tbl'] = "jbrowsesettings"
    jbrowse['src'] = prefix.lower()
    jbrowse.drop(columns="id",inplace=True)
    jbrowse.reset_index(inplace=True)
    jbrowse['id'] = jbrowse.index + 1
    jbrowse = jbrowse[['src','tbl','id','blastdb_id','url']]

    return [combo,jbrowse]


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

# checksums = pd.read_csv("../production.md5",sep="  ",engine="python",
#                         names=['checksum','fasta_file'])

###########################################
# Handle Simple table data First
###########################################
seqs = pd.read_csv('sequencetypes.csv')
ff = pd.read_csv("fastafiles.csv")
ff = ff.rename(columns={'id':'fastafile_id'})

drop = ['tbl','src','is_shown']
if __name__ == '__main__':

    ##################################################################
    # read in the consolidated( production & training)organism data
    ##################################################################
    organisms = pd.read_csv("organisms.csv")
    organisms['is_shown'] = True
    organisms['infraspecies'] = None
    organisms.drop(columns=['short_name','display_name'],inplace=True)
    organisms.sort_values(by=['genus','species'],inplace=True)
    
    # read production django data
    production, pjbrowse = get_dbs("production")
    production = production.apply(lambda x: x.str.strip() if x.dtype == "object" else x).drop(
        columns=drop+['id']
    )
    pjbrowse = pjbrowse.apply(lambda x: x.str.strip() if x.dtype == "object" else x)

    training, tjbrowse = get_dbs("training")
    training = update_organisms(training).apply(lambda x: x.str.strip() if x.dtype == "object" else x).drop(
        columns=drop+['id']
    ) 
    
    

    # combine the production & training data
    bah = pd.concat([production,training])
    bah = bah.apply(lambda x: x.str.strip() if x.dtype == "object" else x) #.drop_duplicates()
    
    data = bah.copy()
    pdb.set_trace()
    
    #columns = ['src', 'tbl', 'title', 'description', 'organism', 'is_shown', 'type', 'fastafile_id' ]
    #bah.sort_values(by=columns[:4],inplace=True)
    assert len(bah) == (len(production) + len(training))
    drop = ['tbl','src','is_shown']
    
    match = ['organism', 'fastafile_id', 'title', 'description']
    sort = ['organism','title','type','tbl']
    bah.sort_values(by=sort, inplace=True)
    bah = bah.drop_duplicates(subset=match,keep='first').sort_values(by=sort)
    bah.reset_index(drop=True, inplace=True)
    bah['id'] = bah.index + 1
    bah = bah.drop(columns=drop).rename(columns={
        'id':'database_id',        
    })
    
    on = ['organism', 'title', 'description','checksum', 'fastafile_id']
    bahc = bah.checksum.to_list()
    
    production = data.loc[data.src == "production"]
    #production.drop(columns=drop,inplace=True)
    production = production.merge(bah,on=on,how="outer",indicator=True)
    
    training = data.loc[data.src == "training"]
    #training.drop(columns=drop,inplace=True)
    training = training.merge(bah,on=on,how="outer",indicator=True)
    
    assert production.loc[~(production.checksum.isin(bahc))].empty
    assert training.loc[~(training.checksum.isin(bahc))].empty
    
    pdb.set_trace()
    
    
    
    # combine jbrowse records 
    jbrowse = pd.concat([pjbrowse, tjbrowse])
    tbrowse = pjbrowse = None
    
pdb.set_trace()






print( name)




#assert dbs.loc[dbs['database_id'].isnull()].empty



# shared_dbs[[ 
#      'database_id','organism_id',  'sequencetype_id',
#      'fastafile_id', 'checksum','title', 'description', ]] 

#['fastafile_id','title','checksum']]

pdb.set_trace()
coll_data = dbs.copy()





dbs = dbs.sort_values(by=sortby).drop_duplicates(subset=match)
dbs = dbs.reset_index(drop=True)
dbs['database_id'] = dbs.index + 1

# dbs.drop(columns=['src','tbl','fasta_file']).reset_index(drop=True)

#dbs['database_id'] = dbs.index + 1


#db_columns = match+['database_id']
#db_df = dbs[db_columns]
#db_params = {'on':match,'how':'left','indicator':'True'}

databases = dbs.loc[~dbs.duplicated(subset=match,keep="first")].rename(columns={
     'organism': 'organism_id', "type":"sequencetype_id", 'database_id':'id'})
[['id','sequencetype_id','fastafile_id', 'database_id', 
    'title', 'description', 'is_shown']]


pdb.set_trace()





blast = production[(production.tbl == 'blast') | (production.src == 'hmmer') ]
#= training[(training.tbl == 'blast') | (training.tbl == 'hmmer') ]


#production_blast = production_blast[match].merge(db_df,**db_params)
pdb.set_trace()

# production_hmmer = production.loc[production.tbl == 'hmmer'].copy()
# production_hmmer = production_hmmer[match].merge(db_df,**db_params)

# training_blast = training.loc[training.tbl == 'blast'].copy()
# training_blast = training_blast[match].merge(db_df,**db_params)

# training_hmmer = training.loc[training.tbl == 'hmmer'].copy()
# training_hmmer = training_hmmer[match].merge(db_df,**db_params)

# dbs = dbs.rename(columns={
#     'type':'sequencetype_id',
#     'organism':'organism_id'
# })[[ 
#     'database_id','organism_id',  'sequencetype_id',
#     'fastafile_id', 'checksum','title', 'description', 'is_shown', ]]
columns = ['type','description','is_shown','fasta_file']

production.drop(columns=columns,inplace=True)
training.drop(columns=columns,inplace=True)

#.merge(
#     dbs,on=match,how="outer",indicator=True).groupby('_merge',observed=False).count()
# training = training.drop(columns=columns).merge(
#     dbs,on=match,how="outer",indicator=True).groupby('_merge',observed=False).count()

#.merge(dbs,on=match,how="outer",indicator=True).groupby('_merge').count()


pdb.set_trace()

# ff = pd.read_csv("fastafile-data.txt",names=["fasta_file"]).sort_values(by="fasta_file",ascending=True)
# ff = ff.apply(lambda x: x.str.strip() if x.dtype == "object" else x).drop_duplicates()
# ff = ff.merge(checksums, how="outer",indicator=True).replace(
#     r'^\s*$', np.nan, regex=True).dropna().drop_duplicates().drop(columns=['_merge'])
# ff['id'] = ff.index+1
# ff.to_csv('fastafiles.csv',index=False)

# ff = ff.rename(columns={'id':'fastafile_id'})#.drop(columns='checksum')
#seqs = pd.read_csv('sequencetypes.csv')


            
    
if __name__ == '__main__':
    
    ##################################################################
    # read in the consolidated( production & training)organism data
    ##################################################################
    organisms = pd.read_csv("organisms.csv")
    organisms['is_shown'] = True
    organisms['infraspecies'] = None
    organisms.drop(columns=['short_name','display_name'],inplace=True)
    organisms.sort_values(by=['genus'])
    
    
    # read production django data
    production, pjbrowse = get_dbs("production")
    

    
    
    # combine jbrowse records 
    jbrowse = pd.concat([pjbrowse, tjbrowse])
    tbrowse = pjbrowse = None
    
    # combine the production & training data
    dbs = pd.concat([production,training])
    assert len(dbs) == (len(production) + len(training))
    
    # get total db count
    dbc = len(dbs)
    
    # merge organism ids only to doublcheck that each 
    # blast/hmmer record has a a valid organism value
    oids = organisms[['id']].copy().rename(columns={'id':'organism'})
    
    assert len(dbs.merge(oids, indicator=True)) == dbc
    
    # make a copy of dbs just in case
    data = dbs.copy()
    assert data.compare(dbs).empty
    
    dbs.drop_duplicates(subset=match, inplace=True)
    dbs.reset_index(inplace=True)
    dbs['database_id'] = dbs.index + 1
    dbs = dbs[['src','tbl','database_id','organism','type','fastafile_id','title','description','is_shown']]
    
    
    pdb.set_trace()
    
    
    
    # .merge(
    #      organisms[['id','display_name']].rename(columns={'id':'organism'})).rename(
    #         columns=rename)[final_cols].sort_values(
    #                      by=sort_cols, ascending=True)
    
    
    
    
    
    
    
    # get production record counts
    production_counts= dbs.groupby(['src','tbl']).count()
    
    # cleanup database records

    
    
    dbs['dbid'] = dbs.index + 1
    dbs = dbs[['dbid','oid','sid','ffid','title','description']]

    cols = ['oid', 'title', 'description','sid','ffid','id','tbl','src','is_shown']

    data = data.rename(columns=rename)[cols].sort_values(
                         by=['oid','title','sid'], ascending=True)
    
    assert data.groupby(['src','tbl']).count()[production_counts.columns].compare(
        production_counts).empty

    merge_cols = ['oid', 'sid', 'ffid', 'title', 'description']
    display_cols = ['src','tbl','is_shown']+ dbs.columns.to_list()[1:]
    rename = {
        'dbid':'id', 'sid':'sequencetype_id',
        'ffid':'fastafile_id','oid':'organism_id'
    }

    data = data[display_cols].merge(
        dbs,on=merge_cols, indicator=True, how="left")
    data = data[['src','tbl','sid','dbid','is_shown']]
    
    
    
    dbs.rename(columns=rename, inplace=True)
  
    print("Finally Write New Api Data To File System")
    makedirs("../api", exist_ok=True)
    chdir("../api")
    
    ff.fasta_file = ff.fasta_file.apply(lambda a: path.basename(a.strip()))
    ff.rename(columns={'fasta_file':'file_name','fastafile_id':'id'},inplace=True)
    ff['is_shown'] = True
    print(f'Writing {len(ff)} records to fastafiles.json')
    ff.to_json("fastafiles.json", index=False, orient="records")
    
    print(f'Writing {len(organisms)} records to organisms.json')
    organisms['is_shown'] = True
    organisms.to_json("organisms.json", index=False, orient="records")
    
    print(f'Writing {len(seqs)} records to sequencetypes.json')
    seqs.to_json("sequencetypes.json", index=False, orient="records")
    
    print(f'Writing {len(dbs)} records to databases.json')
    dbs.to_json("databases.json",index=False, orient="records")
    
    data['id'] = data.index+1
    data.rename(columns={'dbid':'database_id'}, inplace=True)
    
    #info = data[['src','tbl']].drop_duplicates().to_dict(orient='tight',index=False)['data']
    
    
    

    
    write_collection_data(data.rename(columns={'sid':"sequencetype_id"}))
    write_collection_data(jbrowse)
