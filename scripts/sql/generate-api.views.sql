-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA IF NOT EXISTS api;

CREATE OR REPLACE VIEW api.sequencetypes AS
    SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
    FROM public.blast_sequencetype
    ORDER BY dataset_type ASC;

-- Create the shared organism view
CREATE OR REPLACE VIEW api.organisms AS
    SELECT po.id,
        split_part(po.display_name, ' ', 1) genus ,
        split_part(po.display_name, ' ', 2) species,
        lower(po.short_name) as short_name,
        t.id as train_id
    FROM app_organism po
    LEFT JOIN training.app_organism t 
    ON po.display_name = t.display_name
    ORDER BY genus, species ASC;

-- Create Organism Updates View
CREATE OR REPLACE VIEW api.organism_updates AS
    SELECT o.id AS prod_id, o.train_id
    FROM api.organisms o
    WHERE o.id IS NOT NULL 
    AND o.train_id IS NOT NULL
    AND o.id != o.train_id
    ORDER BY o,id ASC;

-- Create Fasta File View
CREATE OR REPLACE VIEW api.fastafiles AS
    SELECT id as fastafile_id, file_name, checksum
    FROM public.fastafiles 
    ORDER BY file_name ASC;

-- Create Database View
CREATE OR REPLACE VIEW api.databases AS
    SELECT f.fastafile_id as id, b.organism_id, b.type_id as sequencetype_id, f.fastafile_id, 
           b.title, b.description, f.checksum, f.file_name
    FROM blast_blastdb b
    LEFT OUTER JOIN api.fastafiles f
    ON b.file_name = f.file_name
    ORDER BY title, checksum ASC;

-- Create Production BlastDBs View
CREATE OR REPLACE VIEW api.production_blastdbs AS 
    SELECT d.id as database_id, d.organism_id
    FROM blast_blastdb b 
    JOIN fastafiles f ON b.file_name = f.file_name
    JOIN api.databases d ON d.checksum = f.checksum; 

-- Create Production HmmerDBs View
CREATE OR REPLACE VIEW api.production_hmmerdbs AS 
    SELECT d.id as database_id, d.organism_id
    FROM hmmer_hmmerdb h 
    LEFT JOIN fastafiles f ON h.file_name = f.file_name
    LEFT JOIN api.databases d ON d.checksum = f.checksum; 

-- Create Training BlastDBs View
CREATE OR REPLACE VIEW api.training_blastdbs AS 
    SELECT d.id as database_id, d.organism_id
    FROM training.blast_blastdb b 
    JOIN fastafiles f ON b.file_name = f.file_name
    --JOIN api.databases d ON d.checksum = f.checksum
    ; 

-- Create Training HmmerDBs View
CREATE OR REPLACE VIEW api.training_hmmerdbs AS 
    SELECT d.id as database_id, d.organism_id
    FROM training.hmmer_hmmerdb h 
    LEFT JOIN fastafiles f ON h.file_name = f.file_name
    LEFT JOIN api.databases d ON d.checksum = f.checksum; 





