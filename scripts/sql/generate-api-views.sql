-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA IF NOT EXISTS api;

-- Create Fasta File View
CREATE TABLE api.fastafiles AS
    SELECT id , file_name, checksum
    FROM public.fastafiles 
    ORDER BY file_name ASC
;

-- Create Sequence Types View
CREATE TABLE api.sequencetypes AS
    SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
    FROM public.blast_sequencetype
    ORDER BY dataset_type ASC
;

-- Create the Organisms view
CREATE TABLE api.organisms AS
    SELECT po.id as id, 
        split_part(po.display_name, ' ', 1) genus ,
        split_part(po.display_name, ' ', 2) species,
        lower(po.short_name) as short_name,
        po.tax_id,
        True as is_shown,
        COALESCE(t.id,NULL) as organism_id
    FROM app_organism po
    LEFT JOIN training.app_organism t 
    ON po.display_name = t.display_name
    ORDER BY genus, species, organism_id ASC
;

-- Create Organism Updates View
CREATE TABLE api.organism_updates AS
    SELECT id as prod_id, organism_id
    FROM api.organisms
    WHERE organism_id is not NULL
    AND id != organism_id
    ORDER BY organism_id, prod_id ASC
;

-- Create Database View
CREATE TABLE api.databases AS
    SELECT f.id as id, b.organism_id, b.type_id as sequencetype_id, f.id as fastafile_id ,  
           b.title,b.description --, f.checksum, f.file_name 
    FROM blast_blastdb b
    LEFT OUTER JOIN api.fastafiles f
    ON b.file_name = f.file_name
    ORDER BY b.title, b.description ASC
;

-- Create Prduction BlastDBs
CREATE TABLE api.production_blastdbs AS 
    SELECT 0 as id, b.organism_id, f.id as database_id, True as is_shown --, b.file_name,  f.checksum  
    FROM blast_blastdb  b 
    INNER JOIN api.fastafiles f 
    ON f.file_name = b.file_name
;
-- Create Production BlastDBs Sequence Table
CREATE SEQUENCE api.production_blastdbs_seq START 1;

UPDATE api.production_blastdbs
SET id = nextval('api.production_blastdbs_seq');

-- Create Prduction HmmerDBs
CREATE TABLE api.production_hmmerdbs AS 
    SELECT 0 as id, h.organism_id, f.id as datyabase_id, True as is_shown --, h.file_name,  f.checksum  
    FROM hmmer_hmmerdb  h 
    INNER JOIN api.fastafiles f 
    ON f.file_name = h.file_name
;

-- Create Production HmmerDBs Sequence Table
CREATE SEQUENCE api.production_hmmerdbs_seq START 1;

UPDATE api.production_hmmerdbs
SET id = nextval('api.production_hmmerdbs_seq');

-- Create Training BlastDBs
CREATE TABLE api.training_blastdbs AS
    SELECT 0 as id, COALESCE(ou.prod_id,b.organism_id) as organism_id, f.id as database_id, True as is_shown --, b.file_name,  f.checksum
    FROM training.blast_blastdb  b 
    INNER JOIN api.fastafiles f
    ON f.file_name = b.file_name
    LEFT OUTER JOIN api.organism_updates ou
    ON ou.organism_id = b.organism_id
;

-- Create Training BlastDBs Sequence Table
CREATE SEQUENCE api.training_blastdbs_seq START 1;

UPDATE api.training_blastdbs
SET id = nextval('api.training_blastdbs_seq');

-- Create Training HmmerDBs
CREATE TABLE api.training_hmmerdbs AS 
    SELECT 0 as id, COALESCE(ou.prod_id,h.organism_id) as organism_id, f.id as database_id, True as is_shown --, h.file_name,  f.checksum 
    FROM training.hmmer_hmmerdb  h 
    INNER JOIN api.fastafiles f 
    ON f.file_name = h.file_name
    LEFT OUTER JOIN api.organism_updates ou
    ON ou.organism_id = h.organism_id
;

-- Create Training BlastDBs Sequence Table
CREATE SEQUENCE api.training_hmmerdbs_seq START 1;

UPDATE api.training_hmmerdbs
SET id = nextval('api.training_hmmerdbs_seq');

\d api.*

--DROP VIEW api.organism_updates;
-- -- \dt;
-- -- \dt training.*;
-- \x

-- \dt 
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'api';
\c
\o 
sequencetypes.csv; select * from  sequencetypes;
\o 
organisms.csv; select * from  organisms;
\o 
organism_updates .csv; select * from  organism_updates;
\o 
databases.csv; select * from  databases;
\o 
fastafile.csv; select * from  fastafiles;
\o 
production_blastdbs  .csv; select * from  production_blastdbs;
\o 
production_hmmerdbs  .csv; select * from  production_hmmerdbs;
\o 
training_blastdbs.csv; select * from  training_blastdbs;
\o 
training_hmmerdbs.csv; select * from  training_hmmerdbs;
