-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA api;

-- Create Sequence Types Table
CREATE TABLE api.sequencetypes AS
    SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
    FROM public.blast_sequencetype
    ORDER BY dataset_type ASC;

-- Create Fasta File Table
CREATE TABLE api.fastafiles AS
    SELECT id, checksum , trim(file_name) as file_name, True as is_shown
    FROM public.fastafiles 
    ORDER BY file_name ASC;

-- Create the Organisms view
CREATE TABLE api.organisms AS
    SELECT 
        po.id,po.tax_id,
        split_part(po.display_name, ' ', 1) genus ,
        split_part(po.display_name, ' ', 2) species,
        po.display_name, po.id as prod_id, tor.id as organism_id
    FROM app_organism po
    LEFT OUTER JOIN training.app_organism tor
    ON po.display_name =  tor.display_name
    ORDER BY po.display_name ASC;

-- Create Organism Updates View
CREATE TABLE api.organism_updates AS
    SELECT organism_id as id, display_name,id as prod_id
    FROM api.organisms
    WHERE organism_id is not NULL
    AND id != organism_id
    ORDER BY organism_id, prod_id ASC;



    -- SELECT po.id as id, 
    --     split_part(po.display_name, ' ', 1) genus ,
    --     split_part(po.display_name, ' ', 2) species,
    --     -- lower(po.short_name) as short_name,
    --     -- po.tax_id,
    --     -- NULL as infraspecies,
    --     -- True as is_shown,
    --     COALESCE(t.id,NULL) as organism_id,
    --     po.display_name as pdisplay,
    --     t.display_name as tdisplay

    -- FROM app_organism po
    -- LEFT OUTER JOIN training.app_organism t 
    -- ON po.display_name = t.display_name
    -- ORDER BY genus, species, organism_id ASC;


-- --   CREATE TABLE api.training_blastdbs AS
--     SELECT po.id as id, 
--         split_part(po.display_name, ' ', 1) genus ,
--         split_part(po.display_name, ' ', 2) species,
--         lower(po.short_name) as short_name,
--         po.tax_id,
--         NULL as infraspecies,
--         True as is_shown,
--         COALESCE(t.id,NULL) as organism_id
--     FROM app_organism po
--     LEFT OUTER JOIN api.organisms t 
--     ON po.display_name = t.display_name
--     ORDER BY organism_id ASC
--     ;

-- -- Drop the API schema if it exists
-- DROP SCHEMA IF EXISTS api CASCADE;
-- CREATE SCHEMA api;

-- CREATE TABLE api.databases AS
--     SELECT f.id as fastafile_id, f.checksum , trim(f.file_name) as file_name,
--         COALESCE(COALESCE(COALESCE(COALESCE(b.title,h.title),tb.title)),th.title) as title,
--         COALESCE(COALESCE(COALESCE(COALESCE(b.organism_id,h.organism_id),tb.organism_id)),th.organism_id) as organism_id,
--         COALESCE(COALESCE(COALESCE(COALESCE(b.type_id,3),tb.type_id)),3) as sequencetype_id
--     FROM public.fastafiles f
--     LEFT OUTER JOIN public.blast_blastdb b
--     ON trim(f.file_name) = trim(b.file_name)
--     LEFT OUTER JOIN public.hmmer_hmmerdb h
--     ON trim(f.file_name) = trim(h.file_name)
--     LEFT OUTER JOIN training.blast_blastdb tb
--     ON trim(f.file_name) = trim(tb.file_name)
--     LEFT OUTER JOIN training.hmmer_hmmerdb th
--     ON trim(f.file_name) = trim(th.file_name)
--     ORDER BY file_name ASC;

-- SELECT * FROM api.databases  WHERE title is NULL or organism_id is NULL or sequencetype_id is NULL; --or file_name = 'AROS_new_ids.faa' ;

-- select count(*) from  api.databases;
-- SELECT * from api.databases  where file_name like 'GCF_001937115%';

-- CREATE OR REPLACE VIEW vern AS
--     SELECT 'blast' as tbl, organism_id, trim(file_name) as file_name from blast_blastdb
--     UNION
--     SELECT 'hmmer' as tbl, organism_id, trim(file_name) as file_name from hmmer_hmmerdb
--     UNION
--     SELECT 'tblast' as tbl, organism_id, trim(file_name) as file_name from training.blast_blastdb
--     UNION
--     SELECT 'thmmer' as tbl, organism_id, trim(file_name) as file_name from training.hmmer_hmmerdb
--     ORDER BY file_name ASC;



--  SELECT DISTINCT trim(COALESCE(COALESCE(COALESCE(b.file_name,h.file_name),tb.file_name),th.file_name)) as file_name
--     -- trim(COALESCE(COALESCE(COALESCE(b.title,h.title),tb.title),th.title)) as title,
--     -- --trim(COALESCE(COALESCE(COALESCE(b.description,h.description),tb.description),th.description)) as description,
--     -- COALESCE(COALESCE(COALESCE(b.organism_id,h.organism_id),tb.organism_id),th.organism_id) as organism_id
--  FROM vern v 
--  LEFT OUTER JOIN fastafiles f 
--  ON v.file_name=f.file_name
--  LEFT OUTER JOIN blast_blastdb b
--  ON b.file_name=f.file_name
--  LEFT OUTER JOIN hmmer_hmmerdb h
--  ON h.file_name=f.file_name
--  LEFT OUTER JOIN training.blast_blastdb tb
--  ON tb.file_name=f.file_name
--  LEFT OUTER JOIN training.hmmer_hmmerdb th
--  ON th.file_name=f.file_name
-- --  ORDER BY title ASC
--  ;