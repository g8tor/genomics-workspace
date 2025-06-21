from os import path ,environ, getcwd
import sys
import pandas as pd
import numpy as np
import pdb, django


PATH_PREFIX = "/usr/local/i5k/media/blast/db"
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)
environ['DJANGO_SETTINGS_MODULE'] = 'i5k.settings'
django.setup()

from django_pandas.io import read_frame
from blast.models import BlastDb, SequenceType, JbrowseSetting
from hmmer.models import HmmerDB
from app.models import Organism

prefix =  "training"
src_prefix = path.dirname(__file__)

uo = pd.read_csv(path.join(src_prefix,f"{prefix}-organism-update.csv")).rename(
    columns={'train_id':'organism','id':'organism_id'})

blast = pd.read_csv(path.join(src_prefix,f"{prefix}-blastdbs.csv"))
bc = len(blast)
bu =  blast.loc[blast.organism.isin(uo.organism.to_list())]
blast.drop(bu.index,inplace=True)
assert len(blast) + len(bu) == bc
blast = pd.concat([blast,bu.merge(uo).drop(columns="organism").rename(
    columns={"organism_id":"organism"})[blast.columns]])

assert len(blast)  == bc


hmmer = pd.read_csv(path.join(src_prefix,f"{prefix}-hmmerdbs.csv"))
hc = len(hmmer)
hu =  hmmer.loc[hmmer.organism.isin(uo.organism.to_list())]
hmmer.drop(hu.index,inplace=True)
assert len(hmmer) + len(hu) == hc
hmmer = pd.concat([hmmer,hu.merge(uo).drop(columns="organism").rename(
    columns={"organism_id":"organism"})[hmmer.columns]])

assert len(hmmer) == hc



pdb.set_trace()