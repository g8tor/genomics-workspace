-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA IF NOT EXISTS api;

-- Create Fasta File View
CREATE OR REPLACE VIEW api.fastafiles AS
    SELECT id as fastafile_id, file_name, checksum
    FROM public.fastafiles 
    ORDER BY file_name ASC
;

-- Create Sequence Types View
CREATE OR REPLACE VIEW api.sequencetypes AS
    SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
    FROM public.blast_sequencetype
    ORDER BY dataset_type ASC
;

-- Create the Organisms view
CREATE OR REPLACE VIEW organisms AS
    SELECT po.id as prod_id, po.tax_id,
        split_part(po.display_name, ' ', 1) genus ,
        split_part(po.display_name, ' ', 2) species,
        lower(po.short_name) as short_name,
        COALESCE(t.id,NULL) as organism_id
    FROM app_organism po
    LEFT JOIN training.app_organism t 
    ON po.display_name = t.display_name
    ORDER BY genus, species ASC
;

-- -- Create Organism Updates View
CREATE OR REPLACE VIEW api.organism_updates AS
    SELECT  organism_id, prod_id
    FROM public.organisms
    WHERE organism_id IS NOT NULL 
    AND organism_id != prod_id
    ORDER BY organism_id, prod_id ASC
;

-- -- Create Database View
CREATE OR REPLACE VIEW api.databases AS
    SELECT f.fastafile_id as id, f.fastafile_id, b.organism_id, b.type_id as sequencetype_id,  
           b.title,b.description --, f.checksum, f.file_name 
    FROM blast_blastdb b
    LEFT OUTER JOIN api.fastafiles f
    ON b.file_name = f.file_name
    ORDER BY b.title, b.description ASC
;

-- Create Prduction BlastDBs
CREATE OR REPLACE VIEW api.production_blastdbs AS 
    SELECT b.organism_id, f.fastafile_id, b.file_name,  f.checksum  
    FROM blast_blastdb  b 
    INNER JOIN api.fastafiles f 
    ON f.file_name = b.file_name
;

-- Create Prduction HmmerDBs
CREATE OR REPLACE VIEW api.production_hmmerdbs AS 
    SELECT h.organism_id, f.fastafile_id, h.file_name,  f.checksum  
    FROM hmmer_hmmerdb  h 
    INNER JOIN api.fastafiles f 
    ON f.file_name = h.file_name
;

-- -- Create Training BlastDBs
CREATE OR REPLACE VIEW api.training_blastdbs AS
    SELECT COALESCE(ou.prod_id,b.organism_id) as organism_id, f.fastafile_id, b.file_name,  f.checksum
    FROM training.blast_blastdb  b 
    INNER JOIN api.fastafiles f
    ON f.file_name = b.file_name
    LEFT OUTER JOIN api.organism_updates ou
    ON ou.organism_id = b.organism_id
;

-- -- Create Training HmmerDBs
CREATE OR REPLACE VIEW api.training_hmmerdbs AS 
    SELECT COALESCE(ou.prod_id,h.organism_id) as organism_id, f.fastafile_id, h.file_name,  f.checksum 
    FROM training.hmmer_hmmerdb  h 
    INNER JOIN api.fastafiles f 
    ON f.file_name = h.file_name
    LEFT OUTER JOIN api.organism_updates ou
    ON ou.organism_id = h.organism_id
-- ;
-- \dt;
-- \dt training.*;
-- \dv api.*;


