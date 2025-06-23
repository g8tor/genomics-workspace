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


-- Create FAst File View
CREATE OR REPLACE VIEW api.fastafiles AS
    SELECT id as fastafile_id, file_name, checksum
    FROM public.fastafiles 
    ORDER BY file_name ASC;

-- Create Database View
CREATE OR REPLACE VIEW api.databases AS
    SELECT f.fastafile_id as id, b.organism_id, b.type_id as sequencetype_id, f.fastafile_id, 
           b.title, b.description, f.checksum
    FROM blast_blastdb b
    LEFT OUTER JOIN api.fastafiles f
    ON b.file_name = f.file_name
    ORDER BY title, checksum ASC;

-- Create Blast View

-- SELECT id as database_id, organism_id, True as is_shown
-- FROM api.databases
-- ORDER BY database_id ASC


-- SELECT  h.file_name, f.fastafile_id, f.checksum
-- FROM hmmer_hmmerdb h
-- LEFT OUTER JOIN api.fastafiles f
-- ON h.file_name = f.file_name;



SELECT d.database_id, d.organism_id
FROM api.databases d
RIGHT JOIN blast_blastdb b
ON d.file_name = b.file_name;