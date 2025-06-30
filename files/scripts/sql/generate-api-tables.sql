-- Drop the API schema if it exists
DROP SCHEMA IF EXISTS api CASCADE;

-- Create api schema
CREATE SCHEMA api;

-- Create Fasta File Table
CREATE TABLE api.fastafiles AS
    SELECT id, checksum , trim(file_name) as file_name, True as is_shown
    FROM public.fastafiles 
    ORDER BY file_name ASC;

-- Create Sequence Types Table
CREATE TABLE api.sequencetypes AS
    SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
    FROM public.blast_sequencetype
    ORDER BY dataset_type ASC;

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
        -- po.display_name as pdisplay,
        -- t.display_name as tdisplay

    FROM app_organism po
    LEFT OUTER JOIN training.app_organism t 
    ON po.display_name = t.display_name
    ORDER BY genus, species, organism_id ASC;

-- Create Organism Updates View
CREATE TABLE api.organism_updates AS
    SELECT id as prod_id, organism_id
    FROM api.organisms
    WHERE organism_id is not NULL
    AND id != organism_id
    ORDER BY organism_id, prod_id ASC;

-- Create Temp blastdb_blastdb 
CREATE TABLE api.blast_blastdb AS
    SELECT tb.id, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, tb.title, tb.description, tb.file_name, tb.type_id
    FROM training.blast_blastdb tb
    LEFT OUTER JOIN api.organism_updates ou
    ON tb.organism_id = ou.organism_id
    ORDER BY title ASC;

-- Create Temp blastdb_blastdb 
CREATE TABLE api.hmmer_hmmerdb AS
    SELECT tb.id,ou.prod_id,tb.organism_id as oid, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, 
           tb.title, tb.description, tb.file_name, 3 as type_id
    FROM training.hmmer_hmmerdb tb
    LEFT OUTER JOIN api.organism_updates ou
    ON tb.organism_id = ou.organism_id
    ORDER BY title ASC;

-- Create Database Table
CREATE TABLE api.databases AS
    SELECT 0 as id, f.id as fastafile_id, f.file_name, True as is_Shown,
        COALESCE(COALESCE(COALESCE(COALESCE(b.title,h.title),tb.title)),th.title) as title,
        COALESCE(COALESCE(COALESCE(COALESCE(b.description,h.description),tb.description)),th.description) as description,
        COALESCE(COALESCE(COALESCE(COALESCE(b.organism_id,h.organism_id),tb.organism_id)),th.organism_id) as organism_id,
        COALESCE(COALESCE(COALESCE(COALESCE(b.type_id,3),tb.type_id)),3) as sequencetype_id
    FROM api.fastafiles f
    LEFT OUTER JOIN public.blast_blastdb b
    ON trim(f.file_name) = trim(b.file_name)
    LEFT OUTER JOIN public.hmmer_hmmerdb h
    ON trim(f.file_name) = trim(h.file_name)
    LEFT OUTER JOIN api.blast_blastdb tb
    ON trim(f.file_name) = trim(tb.file_name)
    LEFT OUTER JOIN api.hmmer_hmmerdb th
    ON trim(f.file_name) = trim(th.file_name)
    ORDER BY fastafile_id ASC;

-- Create Databases Sequence Table & Update IDs
CREATE SEQUENCE api.databases_seq START 1;
UPDATE api.databases SET id = nextval('api.databases_seq');

-- Create Prduction BlastDBs
CREATE TABLE api.production_blastdbs AS
    SELECT b.id as blast_db_id, 0 as id, b.organism_id, d.id as database_id, True as is_shown
    FROM blast_blastdb  b 
    INNER JOIN api.databases d 
    ON d.file_name = b.file_name
    ORDER BY database_id ASC;

-- Create Production BlastDBs Sequence Table
CREATE SEQUENCE api.production_blastdbs_seq START 1;

UPDATE api.production_blastdbs
SET id = nextval('api.production_blastdbs_seq');

-- Create Production JBrowse
CREATE TABLE api.production_jbrowsesettings AS 
    SELECT 0 as id, b.blast_db_id, b.url ,pb.id as new_blast_id
    FROM blast_jbrowsesetting b
    -- ORDER BY blast_db_id ASC
    LEFT OUTER JOIN api.production_blastdbs pb
    ON pb.blast_db_id = b.blast_db_id;

UPDATE
    api.production_jbrowsesettings
SET
    blast_db_id = new_blast_id;


    
-- Create Production JBrowse Seq Table
CREATE SEQUENCE api.production_jbrowsesettings_seq START 1;

UPDATE api.production_jbrowsesettings
SET id = nextval('api.production_jbrowsesettings_seq');

-- -- Create Prduction HmmerDBs
-- CREATE TABLE api.production_hmmerdbs AS 
--     SELECT 0 as id, h.organism_id, d.id as database_id, True as is_shown, d.file_name
--     FROM hmmer_hmmerdb  h 
--     LEFT JOIN api.databases d
--     ON trim(d.file_name) = trim(h.file_name);

-- -- Create Production HmmerDBs Sequence Table
-- CREATE SEQUENCE api.production_hmmerdbs_seq START 1;

-- UPDATE api.production_hmmerdbs
-- SET id = nextval('api.production_hmmerdbs_seq');

-- -- Create Training BlastDBs
-- CREATE TABLE api.training_blastdbs AS
--     SELECT b.id as blast_db_id,0 as id, COALESCE(ou.prod_id,b.organism_id) as organism_id, f.id as database_id, True as is_shown
--     FROM training.blast_blastdb  b 
--     INNER JOIN api.databases f
--     ON f.file_name = b.file_name
--     LEFT OUTER JOIN api.organism_updates ou
--     ON ou.organism_id = b.organism_id
-- ;

-- -- Create Training BlastDBs Sequence Table
-- CREATE SEQUENCE api.training_blastdbs_seq START 1;

-- UPDATE api.training_blastdbs
-- SET id = nextval('api.training_blastdbs_seq');

-- -- Create Training JBrowse
-- CREATE TABLE api.training_jbrowsesettings AS 
--     SELECT  0 as id, b.id as blastdb_id, j.url
--     FROM training.blast_jbrowsesetting j
--     INNER JOIN api.training_blastdbs b
--     ON b.blast_db_id = j.blast_db_id
-- ;

-- -- Create Training JBrowse Seq Table
-- CREATE SEQUENCE api.training_jbrowsesettings_seq START 1;

-- UPDATE api.training_jbrowsesettings
-- SET id = nextval('api.training_jbrowsesettings_seq');

-- -- Create Training HmmerDBs
-- CREATE TABLE api.training_hmmerdbs AS 
--     SELECT 0 as id, COALESCE(ou.prod_id,h.organism_id) as organism_id, f.id as database_id, True as is_shown 
--     FROM training.hmmer_hmmerdb  h 
--     INNER JOIN api.fastafiles f 
--     ON f.file_name = h.file_name
--     LEFT OUTER JOIN api.organism_updates ou
--     ON ou.organism_id = h.organism_id
-- ;

-- -- Create Training BlastDBs Sequence Table
-- CREATE SEQUENCE api.training_hmmerdbs_seq START 1;

-- UPDATE api.training_hmmerdbs
-- SET id = nextval('api.training_hmmerdbs_seq');

-- ALTER TABLE api.databases DROP column file_name;
ALTER TABLE api.production_jbrowsesettings DROP column new_blast_id;

-- -- Check Fasta Files table
-- SELECT * FROM api.fastafiles where checksum is NULL;
-- SELECT * FROM api.fastafiles where file_name is NULL;
-- SELECT * FROM api.fastafiles where is_shown = False;

-- -- Check Sequence Types table
-- SELECT * FROM api.sequencetypes where molecule_type is NULL;
-- SELECT * FROM api.sequencetypes where dataset_type is NULL;

-- -- CHeck Organisms Table
-- SELECT * FROM api.organisms where genus is NULL;
-- SELECT * FROM api.organisms where species is NULL;
-- SELECT * FROM api.organisms where short_name is NULL;
-- SELECT * FROM api.organisms where tax_id is NULL;
-- SELECT * FROM api.organisms where is_shown = False;

-- -- Check Shared Database Table Foreihgn Keys
-- SELECT * FROM api.databases where fastafile_id not in (SELECT id FROM api.fastafiles );
-- SELECT * FROM api.databases where sequencetype_id not in (SELECT id FROM api.sequencetypes );
-- SELECT * FROM api.databases where organism_id not in (SELECT id FROM api.organisms);
-- SELECT * FROM api.databases where title is NULL;
-- SELECT * FROM api.databases where description is NULL;
-- SELECT * FROM api.databases where is_shown = False;

-- -- Check Production BlastDBs
-- select * FROM api.production_blastdbs where  organism_id not in (SELECT id FROM api.organisms);
-- select * FROM api.production_blastdbs where  database_id not in (SELECT id FROM api.databases);

-- -- Check Production HmmerDBs
-- select * FROM api.production_hmmerdbs where  organism_id not in (SELECT id FROM api.organisms);
-- select * FROM api.production_hmmerdbs where  database_id not in (SELECT id FROM api.databases);

-- -- Check Training BlastDBs
-- select * FROM api.training_blastdbs where  organism_id not in (SELECT id FROM api.organisms);
-- select * FROM api.training_blastdbs where  database_id not in (SELECT id FROM api.databases);

-- -- Check Training HmmerDBs
-- select * FROM api.training_hmmerdbs where  organism_id not in (SELECT id FROM api.organisms);
-- select * FROM api.training_hmmerdbs where  database_id not in (SELECT id FROM api.databases);




-- -- select * from api.production_jbrowsesettings where blastdb_id not in (select id from );


-- CREATE OR REPLACE VIEW vern AS
--     SELECT trim(file_name) as file_name from blast_blastdb
--     UNION
--     SELECT trim(file_name) as file_name from hmmer_hmmerdb
--     UNION
--     SELECT trim(file_name) as file_name from training.blast_blastdb
--     UNION
--     SELECT trim(file_name) as file_name from training.hmmer_hmmerdb
--     ORDER BY file_name ASC;


--  SELECT v.file_name,COALESCE(b.title,t.title) as title, f.checksum 
--  FROM vern v 
--  LEFT OUTER JOIN fastafiles f 
--  ON v.file_name=f.file_name
--  LEFT OUTER JOIN blast_blastdb b
--  ON b.file_name=f.file_name
-- LEFT OUTER JOIN hmmer_hmmerdb h
--  ON h.file_name=f.file_name WHERE title is NULL;
    
    
    
    
    
    -- HAZT.faa