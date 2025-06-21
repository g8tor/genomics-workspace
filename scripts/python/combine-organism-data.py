import pandas as pd
import numpy as np
import pdb

pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)

#######################
# Consolidate Organisms
#######################
# select lower(trim(short_name)) as short_name, trim(display_name) as display_name, tax_id, id as prod_id, NULL as train_id  from app_organism order by display_name ASC;
# select lower(trim(short_name)) as short_name, trim(display_name) as display_name, tax_id, NULL as prod_id ,id as train_id from app_organism order by display_name ASC;

if __name__ == '__main__':

    names = ['short_name','display_name','tax_id','prod_id','train_id']
    dtypes={'short_name':str,'display_name':str,'tax_id':int}
    
    raw = pd.read_csv('organism-data.txt',sep='|',names=names, dtype=dtypes).apply(
        lambda x: x.str.strip() if x.dtype == "object" else x).replace(r'^\s*$', np.nan, regex=True)
    
    production = raw.loc[raw.prod_id.notna()].copy()
    production.loc[production.prod_id.notna(),'src'] = "prod"
    
    training = raw.loc[raw.prod_id.isna()].copy()
    training.loc[training.prod_id.isna(), 'src'] = "train"
    
    subset = ["short_name","display_name","tax_id"]

    
    odf =  production.merge(training,indicator=True,how="outer",on=subset)
    odf = odf[["prod_id_x",'train_id_y','_merge']+subset].copy().rename(
        columns={'prod_id_x':'id','train_id_y':'train_id'}).drop(columns='_merge')
    
    

    
    training = odf.loc[odf.id.notna() & odf.train_id.notna() & (odf.id != odf.train_id)][['id','train_id']].copy()
    training.rename(columns={"id":"organism_id","train_id":"organism"}).to_csv("training-organism-update.csv",index=False)
    
    
    odf = odf.dropna(axis=1,how="any")
    odf['genus'] = odf.display_name.apply(
        lambda a: a.strip().split()[0]
    )
    odf['species'] = odf.display_name.apply(
        lambda a: " ".join(a.strip().split()[1:])
    )
    
    odf = odf[['id','short_name','genus','species','display_name','tax_id']]
    odf.id = odf.id.astype(int)
    odf.sort_values(by="id",ascending=True,inplace=True)    
    odf.to_csv("organisms44.csv",index=False)