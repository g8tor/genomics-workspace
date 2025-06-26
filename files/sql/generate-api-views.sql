-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA IF NOT EXISTS api;

-- Create Fasta File View
CREATE TABLE api.fastafiles AS
    SELECT id, checksum , file_name, True as is_shown
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
        NULL as infraspecies,
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
           b.title,b.description, True as is_shown
    FROM blast_blastdb b
    LEFT OUTER JOIN api.fastafiles f
    ON b.file_name = f.file_name
    ORDER BY b.title, b.description ASC
;

-- Create Prduction BlastDBs
CREATE TABLE api.production_blastdbs AS 
    SELECT b.id as blast_db_id, 0 as id, b.organism_id, f.id as database_id, True as is_shown
    FROM blast_blastdb  b 
    INNER JOIN api.fastafiles f 
    ON f.file_name = b.file_name
;
-- Create Production BlastDBs Sequence Table
CREATE SEQUENCE api.production_blastdbs_seq START 1;

UPDATE api.production_blastdbs
SET id = nextval('api.production_blastdbs_seq');

-- Create Production JBrowse
CREATE TABLE api.production_jbrowsesettings AS 
    SELECT 0 as id, b.id as blastdb_id, j.url
    FROM blast_jbrowsesetting j
    INNER JOIN api.production_blastdbs b
    ON b.blast_db_id = j.blast_db_id
;
-- Create Production JBrowse Seq Table
CREATE SEQUENCE api.production_jbrowsesettings_seq START 1;

UPDATE api.production_jbrowsesettings
SET id = nextval('api.production_jbrowsesettings_seq');

-- Create Prduction HmmerDBs
CREATE TABLE api.production_hmmerdbs AS 
    SELECT 0 as id, h.organism_id, f.id as database_id, True as is_shown
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
    SELECT b.id as blast_db_id,0 as id, COALESCE(ou.prod_id,b.organism_id) as organism_id, f.id as database_id, True as is_shown 
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

-- Create Production JBrowse
CREATE TABLE api.training_jbrowsesettings AS 
    SELECT  0 as id, b.id as blastdb_id, j.url
    FROM training.blast_jbrowsesetting j
    INNER JOIN api.training_blastdbs b
    ON b.blast_db_id = j.blast_db_id
;
-- Create Production JBrowse Seq Table
CREATE SEQUENCE api.training_jbrowsesettings_seq START 1;

UPDATE api.training_jbrowsesettings
SET id = nextval('api.training_jbrowsesettings_seq');

-- Create Training HmmerDBs
CREATE TABLE api.training_hmmerdbs AS 
    SELECT 0 as id, COALESCE(ou.prod_id,h.organism_id) as organism_id, f.id as database_id, True as is_shown 
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


ALTER TABLE api.organisms DROP column organism_id;
ALTER TABLE api.production_blastdbs DROP column blast_db_id;
ALTER TABLE api.training_blastdbs DROP column blast_db_id;

\copy api.sequencetypes to '/sql/csvs/sequencetypes.csv' WITH (FORMAT CSV, HEADER);

\copy api.organisms TO '/sql/csvs/organisms.csv' WITH (FORMAT CSV, HEADER);

\copy api.databases TO '/sql/csvs/databases.csv' WITH (FORMAT CSV, HEADER);

\copy api.fastafiles TO '/sql/csvs/fastafiles.csv' WITH (FORMAT CSV, HEADER);

\copy api.production_blastdbs  TO '/sql/csvs/production_blastdbs.csv' WITH (FORMAT CSV, HEADER);

\copy api.production_jbrowsesettings  TO '/sql/csvs/production_jbrowsesettings.csv' WITH (FORMAT CSV, HEADER);

\copy api.production_hmmerdbs TO '/sql/csvs/production_hmmerdbs.csv' WITH (FORMAT CSV, HEADER);

\copy api.training_blastdbs TO '/sql/csvs/training_blastdbs.csv' WITH (FORMAT CSV, HEADER);

\copy api.training_jbrowsesettings  TO '/sql/csvs/training_jbrowsesettings.csv' WITH (FORMAT CSV, HEADER);

\copy api.training_hmmerdbs TO '/sql/csvs/training_hmmerdbs.csv' WITH (FORMAT CSV, HEADER);
