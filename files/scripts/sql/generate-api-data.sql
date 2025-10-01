----------------------------------------------------------
-- Modify DJANGO Data
----------------------------------------------------------
\c django
\o /dev/null
\i /sql/setup.sql
\c django_training
\o /dev/null
\i /sql/setup.sql
\o


\echo Create API Database
CREATE DATABASE api;
\c api
CREATE SCHEMA production;
CREATE SCHEMA training;
----------------------------------------------------------
-- End Modify DJANGO Data
----------------------------------------------------------

----------------------------------------------------------
-- FDW Setup
----------------------------------------------------------
\echo Setup PostgreSQL FDW
-- \echo Create the extension that allows us to query across dbs
CREATE EXTENSION postgres_fdw;

-- \echo Create FDW servers
CREATE SERVER django_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5432', dbname 'django');
CREATE SERVER django_training_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5432', dbname 'django_training');

-- \echo Create FDW user mappings
CREATE USER MAPPING FOR i5k SERVER django_server OPTIONS (user 'i5k', password 'i5k');
CREATE USER MAPPING FOR i5k SERVER django_training_server OPTIONS (user 'i5k', password 'i5k');

-- \echo Create FDW local schemas
CREATE SCHEMA django;
CREATE SCHEMA django_training;

-- \echo Import Django Data
IMPORT FOREIGN SCHEMA public FROM SERVER django_server INTO django;
IMPORT FOREIGN SCHEMA public FROM SERVER django_training_server INTO django_training;
----------------------------------------------------------
-- - End FDW Setup
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the collections table
----------------------------------------------------------
\echo Create Collection Table
CREATE TABLE public.collections(
    "id" SERIAL,
    "name" VARCHAR(40) NOT NULL UNIQUE,
    "display_name" VARCHAR(100) NOT NULL UNIQUE,
    "is_shown"  BOOLEAN NOT NULL DEFAULT True);

    ALTER TABLE public.collections

    ADD UNIQUE(name, display_name,is_shown);

    INSERT INTO public.collections (name, display_name, is_shown)
        VALUES
            ('production','Production Collection', TRUE),
            ('training','Training Collection',TRUE),
            ('agpest-100','AgPest 100', FALSE);
----------------------------------------------------------
-- End Create and populate the collections table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the sequencetype table
----------------------------------------------------------
\echo Create Sequence Types Table
CREATE TABLE public.sequencetypes(
    "id" SERIAL,
    "molecule_type" VARCHAR(4) NOT NULL,
    "dataset_type" VARCHAR(50) NOT NULL UNIQUE);

    ALTER TABLE public.sequencetypes
    ADD PRIMARY KEY (id),
    ADD UNIQUE(molecule_type, dataset_type);

    INSERT INTO public.sequencetypes (id, molecule_type, dataset_type)
    VALUES
        (1,'nucl','Genome Assembly'),
        (2,'nucl','Transcript'),
        (3,'prot','Protein');
    
    \o /dev/null
    SELECT setval('public.sequencetypes_id_seq', 
    (SELECT MAX(id) FROM public.sequencetypes));
----------------------------------------------------------
-- End Create and populate the sequencetype table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the fastafiles table
----------------------------------------------------------
\echo Create Fasta Filea Table
CREATE TABLE fastafiles (
  id SERIAL,
  checksum VARCHAR(200) NOT NULL,
  file_name VARCHAR(300) NOT NULL,
  is_shown  BOOLEAN NOT NULL DEFAULT True,
  PRIMARY KEY (id),
  UNIQUE(checksum),
  UNIQUE(file_name),
  UNIQUE(checksum,file_name)
);

-- \echo Import the Fasta File Data
COPY fastafiles(checksum, file_name)
FROM '/fastafiles.md5'
DELIMITER ',';

-- \echo Update fastafiles file_name
UPDATE fastafiles SET file_name = trim(regexp_replace(file_name,'^.*\/',''));
----------------------------------------------------------
-- End Create and populate the fastafiles table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the Organisms table
----------------------------------------------------------
-- \o /dev/null
\echo Create Organisms Table
CREATE TABLE organisms AS
    SELECT id,
        lower(trim(short_name)) as short_name,
        trim(split_part(display_name, ' ', 1)) genus ,
        trim(split_part(display_name, ' ', 2)) species,
        tax_id,
        null as infraspecies,
        0 as organism_id,
        True as is_shown,
        display_name,
        'django.app_organism' as src
    FROM django.app_organism po;
    CREATE SEQUENCE organisms_id_seq ;
    SELECT setval('organisms_id_seq', (SELECT MAX(id) FROM organisms));
  
    ALTER TABLE organisms ALTER COLUMN id SET DEFAULT nextval('organisms_id_seq');

    -- Update Organism Constraints
    ALTER TABLE organisms
    ALTER COLUMN genus SET NOT NULL,
    ALTER COLUMN species SET NOT NULL,
    ALTER COLUMN short_name SET NOT NULL,
    ALTER COLUMN tax_id SET NOT NULL,
    ALTER COLUMN is_shown SET NOT NULL,
    ALTER COLUMN is_shown SET DEFAULT True,
    ADD UNIQUE(short_name),
    ADD UNIQUE(tax_id),
    ADD UNIQUE(genus,species),
    ADD UNIQUE(genus,species,short_name),
    ADD UNIQUE(tax_id,genus,species,short_name),
    ADD PRIMARY KEY (id);

MERGE INTO organisms o
USING django_training.app_organism dt
ON trim(o.short_name) = trim(dt.short_name)
AND trim(o.display_name) = trim(dt.display_name)
AND o.id != dt.id
WHEN MATCHED THEN
    UPDATE SET organism_id = dt.id, src = 'django_training.app_organism';

ALTER TABLE organisms DROP COLUMN display_name;
DROP FOREIGN TABLE django.app_organism;
DROP FOREIGN TABLE django_training.app_organism;

-- \echo
-- \echo Organism counts by source
-- \o
select src, count(*) from  organisms group by src;

-- \echo
-- \echo Organism ids that need to be updates
-- SELECT id,organism_id,src
-- FROM organisms
-- WHERE organism_id > 0;
----------------------------------------------------------
-- Create and populate the Organisms table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the databases table
----------------------------------------------------------
\echo Create Databases Table
CREATE TABLE databases AS
SELECT id, 0 as organism_id, 0 as sequencetype_id, id as fastafile_id, 
       file_name , null as description, null as src, checksum, true as is_shown
FROM fastafiles;

MERGE INTO databases d
USING django.blast_blastdb b
ON d.checksum = b.checksum
AND d.description IS NULL
AND d.src IS NULL
WHEN MATCHED THEN
    UPDATE SET description = b.description,
               organism_id = b.organism_id,
               sequencetype_id = b.sequencetype_id,
               file_name = b.file_name,
               src = 'django.blast_blastdb';

MERGE INTO databases d
USING django.hmmer_hmmerdb b
ON d.checksum = b.checksum
AND d.description IS NULL
AND d.src IS NULL
WHEN MATCHED THEN
    UPDATE SET description = b.description,
               organism_id = b.organism_id,
               sequencetype_id = 3,
               file_name = b.file_name,
               src = 'django.hmmer_hmmerdb';

MERGE INTO databases d
USING django_training.blast_blastdb b
ON d.checksum = b.checksum
AND d.description IS NULL
AND d.src IS NULL
WHEN MATCHED THEN
    UPDATE SET description = b.description,
               organism_id = b.organism_id,
               sequencetype_id = b.sequencetype_id,
               file_name = b.file_name,
               src = 'django_training.blast_blastdb';

MERGE INTO databases d
USING django_training.hmmer_hmmerdb b
ON d.checksum = b.checksum
AND d.description IS NULL
AND d.src IS NULL
WHEN MATCHED THEN
    UPDATE SET description = b.description,
               organism_id = b.organism_id,
               sequencetype_id = 3,
               src = 'django_training.hmmer_hmmerdb';
\o /dev/null

CREATE SEQUENCE databases_id_seq START 1;
SELECT setval('databases_id_seq', (SELECT MAX(id) FROM databases));


MERGE INTO databases d
USING organisms o
ON o.organism_id = d.organism_id
AND d.src LIKE '%training%'
WHEN MATCHED THEN
    UPDATE SET organism_id = o.id;

ALTER TABLE databases RENAME COLUMN file_name to title;
ALTER TABLE databases
ADD PRIMARY KEY (id),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_fastafile FOREIGN KEY (fastafile_id) REFERENCES fastafiles,
ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES sequencetypes,
ALTER COLUMN title SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN fastafile_id SET NOT NULL,
ALTER COLUMN description SET NOT NULL,
ALTER COLUMN is_shown SET NOT NULL,
ALTER COLUMN is_shown SET DEFAULT True,
ALTER COLUMN id SET DEFAULT nextval('databases_id_seq');

----------------------------------------------------------
-- End Create and populate the databases table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the production blastdbs
----------------------------------------------------------
\echo Create Production BlastDBs Table
\o

CREATE TABLE production.blastdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, 
        d.sequencetype_id, true as is_shown, b.url as jbrowse_url, b.checksum
FROM django.blast_blastdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases )
ORDER BY url asc;

ALTER TABLE production.blastdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
ALTER COLUMN is_shown SET NOT NULL,
ALTER COLUMN is_shown SET DEFAULT True,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE production.blast_id_seq START 1;
UPDATE production.blastdbs SET id = nextval('production.blast_id_seq');

ALTER TABLE production.blastdbs 
ADD PRIMARY KEY (id),
ADD UNIQUE(jbrowse_url),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES sequencetypes,
ADD CONSTRAINT fk_database FOREIGN KEY (database_id) REFERENCES databases,
ALTER COLUMN id SET DEFAULT nextval('production.blast_id_seq');
----------------------------------------------------------
-- End Create and populate the production blastdbs table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the production jbrowsesettings
----------------------------------------------------------
-- \echo Create Production JBrowse Settings Table
-- CREATE TABLE production.jbrowsesettings AS 
-- SELECT id, id as blastdb_id, url
-- FROM production.blastdbs
-- WHERE url IS NOT NULL
-- ORDER BY id ASC;

-- \o /dev/null
-- CREATE SEQUENCE production.jbrowsesettings_id_seq START 1;
-- SELECT setval('production.jbrowsesettings_id_seq', (SELECT MAX(id) FROM production.jbrowsesettings));

-- ALTER TABLE production.jbrowsesettings
-- ALTER COLUMN id SET NOT NULL,
-- ALTER COLUMN blastdb_id SET NOT NULL,
-- ALTER COLUMN url SET NOT NULL,
-- ADD PRIMARY KEY (id),
-- ADD UNIQUE(url),
-- ADD UNIQUE(blastdb_id),
-- ADD UNIQUE(blastdb_id,url),
-- ADD CONSTRAINT fk_blastdb FOREIGN KEY (blastdb_id) REFERENCES production.blastdbs,
-- ALTER COLUMN id SET DEFAULT nextval('production.jbrowsesettings_id_seq');
----------------------------------------------------------
-- End Create and populate the production jbrowsesettings
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the production hmmerdbs
----------------------------------------------------------
\echo Create Production HmmerDBs Table

CREATE TABLE production.hmmerdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, b.checksum, true as is_shown
FROM django.hmmer_hmmerdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases );

ALTER TABLE production.hmmerdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
ALTER COLUMN is_shown SET NOT NULL,
ALTER COLUMN is_shown SET DEFAULT True,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE production.hmmer_id_seq START 1;
UPDATE production.hmmerdbs SET id = nextval('production.hmmer_id_seq');

ALTER TABLE production.hmmerdbs
ADD PRIMARY KEY (id),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_database FOREIGN KEY (database_id) REFERENCES databases,
ALTER COLUMN id SET DEFAULT nextval('production.hmmer_id_seq');
----------------------------------------------------------
-- End Create and populate the production hmmerdbs table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the training blastdbs
----------------------------------------------------------
-- \echo Check Training Blast Databases
\echo Create Training BlastDBs Table
CREATE TABLE training.blastdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id,
        d.sequencetype_id, b.url as jbrowse_url, b.checksum, true as is_shown
FROM django_training.blast_blastdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases )
ORDER BY url asc;

ALTER TABLE training.blastdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
ALTER COLUMN is_shown SET NOT NULL,
ALTER COLUMN is_shown SET DEFAULT True,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE training.blast_id_seq START 1;
UPDATE training.blastdbs SET id = nextval('training.blast_id_seq');

ALTER TABLE training.blastdbs 
ADD PRIMARY KEY (id),
ADD UNIQUE(jbrowse_url),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES sequencetypes,
ADD CONSTRAINT fk_database FOREIGN KEY (database_id) REFERENCES databases,
ALTER COLUMN id SET DEFAULT nextval('training.blast_id_seq');
----------------------------------------------------------
-- End Create and populate the training blastdbs table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the training jbrowsesettings
----------------------------------------------------------
-- \echo Create Training JBrowse Settings Table
-- CREATE TABLE training.jbrowsesettings AS 
-- SELECT id, id as blastdb_id, url
-- FROM training.blastdbs
-- WHERE url IS NOT NULL
-- ORDER BY id ASC;

-- CREATE SEQUENCE training.jbrowsesettings_id_seq START 1;
-- SELECT setval('training.jbrowsesettings_id_seq', (SELECT MAX(id) FROM training.jbrowsesettings));
-- ALTER TABLE training.jbrowsesettings
-- ALTER COLUMN id SET NOT NULL,
-- ALTER COLUMN blastdb_id SET NOT NULL,
-- ALTER COLUMN url SET NOT NULL,
-- ADD PRIMARY KEY (id),
-- ADD UNIQUE(url),
-- ADD UNIQUE(blastdb_id),
-- ADD UNIQUE(blastdb_id,url),
-- ADD CONSTRAINT fk_blastdb FOREIGN KEY (blastdb_id) REFERENCES training.blastdbs,
-- ALTER COLUMN id SET DEFAULT nextval('training.jbrowsesettings_id_seq');
----------------------------------------------------------
-- End Create and populate the training jbrowsesettings
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the training hmmerdbs
----------------------------------------------------------
\echo Create Training HmmerDbs Table
CREATE TABLE training.hmmerdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, b.checksum, true as is_shown
FROM django_training.hmmer_hmmerdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases );

ALTER TABLE training.hmmerdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
ALTER COLUMN is_shown SET NOT NULL,
ALTER COLUMN is_shown SET DEFAULT True,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE training.hmmer_id_seq START 1;
UPDATE training.hmmerdbs SET id = nextval('training.hmmer_id_seq');

ALTER TABLE training.hmmerdbs
ADD PRIMARY KEY (id),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_database FOREIGN KEY (database_id) REFERENCES databases,
ALTER COLUMN id SET DEFAULT nextval('training.hmmer_id_seq');
----------------------------------------------------------
-- End Create and populate the training hmmerdbs table
----------------------------------------------------------

----------------------------------------------------------
-- Table Cleanup
----------------------------------------------------------
SET client_min_messages TO ERROR;

ALTER TABLE organisms
DROP COLUMN src,
DROP COLUMN organism_id;

ALTER TABLE databases
DROP COLUMN src,
DROP COLUMN checksum;
\o /dev/null
DROP SCHEMA django  CASCADE;
DROP SCHEMA django_training  CASCADE;
DROP EXTENSION  postgres_fdw CASCADE;

CREATE OR REPLACE FUNCTION get_all_table_row_counts()
RETURNS TABLE(schema_name text, table_name text, row_count bigint) AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT
            n.nspname AS schema_name,
            c.relname AS table_name
        FROM
            pg_class c
        JOIN
            pg_namespace n ON n.oid = c.relnamespace
        WHERE
            c.relkind = 'r' -- 'r' for regular tables
            AND n.nspname NOT IN ('pg_catalog', 'information_schema') -- Exclude system schemas
        ORDER BY
            n.nspname, c.relname
    LOOP
        EXECUTE FORMAT('SELECT %L, %L, COUNT(*) FROM %I.%I', r.schema_name, r.table_name, r.schema_name, r.table_name)
        INTO schema_name, table_name, row_count;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
\o 
\echo
\echo Record Counts
SELECT * FROM get_all_table_row_counts();


\! rm /opt/api.pgc &> /dev/null
\! pg_dump  -U i5k -d api  -C -c --if-exists -Fc -f /opt/api.pgc 

-- 2>/dev/null

-- -- \o /dev/null

-- ALTER DATABASE django SET client_min_messages TO WARNING;
-- \echo Connect to the django database

-- \c django

-- -- \echo Drop API schema 
-- DROP SCHEMA IF EXISTS api CASCADE;
-- \echo Create API schema
-- CREATE SCHEMA api;

-- \echo Create Collection Table

-- CREATE TABLE api.collections(
--   "id" SERIAL,
--   "name" VARCHAR(40) NOT NULL UNIQUE,
--   "display_name" VARCHAR(100) NOT NULL UNIQUE);

--     INSERT INTO api.collections (name, display_name)
--     VALUES
--         ('production','Production Collection'),
--         ('training','Training Collection');

-- -- \echo Create Fasta File table
-- -- CREATE TABLE  api.fastafiles (LIKE  public.fastafiles INCLUDING ALL);
-- -- INSERT INTO api.fastafiles SELECT * FROM public.fastafiles;
-- -- ALTER TABLE api.fastafiles ADD UNIQUE(checksum,file_name);

-- \echo Create Fasta File Table
-- -- \o /dev/null
-- CREATE TABLE IF NOT EXISTS api.fastafiles (
--   id SERIAL,
--   checksum VARCHAR(200) NOT NULL,
--   file_name VARCHAR(300) NOT NULL,
--   is_shown  BOOLEAN NOT NULL DEFAULT True,
--   PRIMARY KEY (id),
--   UNIQUE(checksum),
--   UNIQUE(file_name),
--   UNIQUE(checksum,file_name)
-- );

-- -- Make sure to copy the fastafiles.md5 to the root
-- -- directory if the postgresql server before running
-- -- this script from the django conrainer.

-- -- Import the Fasta File Data
-- COPY api.fastafiles(checksum, file_name)
-- FROM '/fastafiles.md5'
-- DELIMITER ',';

-- UPDATE api.fastafiles SET file_name = trim(regexp_replace(file_name,'^.*\/',''));


-- \echo Create Sequencetype Table
-- CREATE TABLE  api.sequencetypes (LIKE  public.blast_sequencetype INCLUDING ALL);
-- INSERT INTO api.sequencetypes SELECT * FROM public.blast_sequencetype;
-- ALTER TABLE api.sequencetypes ADD UNIQUE(molecule_type,dataset_type);

-- \echo Create Organism Table ( Production & Training )
-- -- Create the Organisms Table

-- CREATE TABLE api.organisms AS
--     SELECT po.id as id, 
--         COALESCE(t.id,null) as organism_id ,
--         trim(po.display_name) as display_name,
--         trim(split_part(po.display_name, ' ', 1)) genus ,
--         trim(split_part(po.display_name, ' ', 2)) species,
--         lower(trim(po.short_name)) as short_name,
--         po.tax_id,
--         null as infraspecies,
--         True as is_shown
--     FROM app_organism po
--     LEFT OUTER JOIN training.app_organism t 
--     ON trim(po.display_name) = trim(t.display_name)
--     ORDER BY genus, species, organism_id ASC;

--     -- Update Organism Constraints
--     ALTER TABLE api.organisms
--     ALTER COLUMN genus SET NOT NULL,
--     ALTER COLUMN species SET NOT NULL,
--     ALTER COLUMN short_name SET NOT NULL,
--     ALTER COLUMN tax_id SET NOT NULL,
--     ALTER COLUMN is_shown SET DEFAULT True,
--     ADD UNIQUE(short_name),
--     ADD UNIQUE(genus,species,short_name),
--     ADD PRIMARY KEY (id);

--     -- Update Organisms Table
--     UPDATE api.organisms
--     SET organism_id = NULL 
--     WHERE id = organism_id;

-- \echo Create Blast Data Table ( Production & Training )

-- CREATE TABLE api.blast AS
--     WITH organism_updates as(
--         SELECT id as prod_id, organism_id
--         FROM api.organisms
--         WHERE organism_id is not NULL
--         AND organism_id != id
--         ORDER BY organism_id, prod_id ASC
--     ),all_jbrowse AS (
--         SELECT 'blast' as source, blast_db_id, url from blast_jbrowsesetting
--         UNION
--         SELECT 'training_blast' as source, blast_db_id, url from training.blast_jbrowsesetting
--     ),all_blast as (
--         SELECT 'blast' as source,bb.id,bb.organism_id as oid, bb.organism_id, bb.type_id,bb.file_name,bb.description, aj.url 
--         FROM blast_blastdb bb
--         LEFT OUTER JOIN all_jbrowse as aj
--         ON aj.source = 'blast' AND bb.id = aj.blast_db_id
--         UNION
--         SELECT 'training_blast' as source,tb.id, tb.organism_id as oid, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, tb.type_id,tb.file_name,tb.description, aj.url 
--         FROM training.blast_blastdb tb
--         LEFT OUTER JOIN all_jbrowse as aj
--         ON aj.source = 'training_blast' AND tb.id = aj.blast_db_id
--         LEFT OUTER JOIN organism_updates ou
--         ON tb.organism_id = ou.organism_id
--     ) 
--     SELECT source,0 as id, 0 as database_id, f.checksum, trim(ab.file_name) as file_name, organism_id,
--         ab.type_id as sequencetype_id, f.id as fastafile_id, trim(ab.description) as description , 
--         url
--     FROM all_blast ab
--     LEFT OUTER JOIN api.fastafiles f
--     ON trim(ab.file_name) = trim(f.file_name)
--     LEFT JOIN api.sequencetypes s 
--     ON s.id = ab.type_id
--     ORDER BY file_name, source ASC;

--     -- Create Blast Sequence
--     CREATE SEQUENCE api.blast_seq START 1;
--     UPDATE api.blast 
--     SET id = nextval('api.blast_seq')
--     WHERE source = 'blast';

--     -- Reset Blast Sequencet For Training 
--     ALTER SEQUENCE api.blast_seq RESTART WITH 1;

--     UPDATE api.blast 
--     SET id = nextval('api.blast_seq')
--     WHERE source = 'training_blast';

--     DROP SEQUENCE api.blast_seq;

-- \echo Create Hmmer Data Table ( Production & Training )

-- CREATE TABLE api.hmmer AS
--     WITH organism_updates as(
--         SELECT id as prod_id, organism_id
--         FROM api.organisms
--         WHERE organism_id is not NULL
--         AND organism_id != id
--         ORDER BY organism_id, prod_id ASC
--     ),all_hmmer as (
--         SELECT 'hmmer' as source, h.organism_id as oid, h.organism_id,  trim(h.file_name) as file_name, trim(h.description) as description, 
--                 trim(h.title) as title FROM hmmer_hmmerdb h
--         LEFT OUTER JOIN organism_updates ou
--         ON h.organism_id = ou.organism_id
--         UNION
--         SELECT 'training_hmmer' as source, th.organism_id as oid,COALESCE(ou.prod_id, th.organism_id ) as organism_id,  trim(th.file_name) as file_name, trim(th.description) as description, 
--                 trim(th.title) as title FROM training.hmmer_hmmerdb th
--         LEFT OUTER JOIN organism_updates ou
--         ON th.organism_id = ou.organism_id
--         ORDER BY file_name, source ASC
--     ) SELECT source,0 as id, 0 as database_id, f.checksum, trim(ah.file_name) as file_name,organism_id, 
--              3 as sequencetype_id, f.id as fastafile_id, trim(ah.description) as description, null as url
--     FROM all_hmmer ah
--     LEFT OUTER JOIN api.fastafiles f
--     ON trim(ah.file_name) = trim(f.file_name)
--     ORDER BY file_name,source ASC;


--     CREATE SEQUENCE api.hmmer_seq START 1;
--     UPDATE api.hmmer 
--     SET id = nextval('api.hmmer_seq')
--     WHERE source = 'hmmer';

--     -- Reset Hmmer  Sequence For Training
--     ALTER SEQUENCE api.hmmer_seq RESTART WITH 1;
--     UPDATE api.hmmer 
--     SET id = nextval('api.hmmer_seq')
--     WHERE source = 'training_hmmer';

--     DROP SEQUENCE api.hmmer_seq;

-- \echo Create Databases Table

-- CREATE TABLE api.databases AS
--     WITH data as (
--             SELECT * FROM api.blast
--             UNION
--             SELECT * FROM api.hmmer
--             ORDER BY file_name,source ASC   
--     )
--     SELECT DISTINCT ON (checksum,file_name) 
--         id, organism_id, sequencetype_id,fastafile_id, description,
--         checksum,file_name,url,True as is_shown
--     FROM data;

--     CREATE SEQUENCE api.databases_seq START 1;
    
--     \echo Update api.databases.id column
--     UPDATE api.databases SET id = nextval('api.databases_seq');

--     DROP SEQUENCE api.databases_seq;

--     \echo Update api.blast.database_id column

--     UPDATE api.blast
--     SET database_id = d.id 
--     FROM api.databases d
--     WHERE
--         trim(api.blast.checksum)  = trim(d.checksum) AND
--         trim(api.blast.file_name) = trim(d.file_name);

--     \echo Update api.hmmer.database_id column

--     UPDATE api.hmmer
--     SET database_id = d.id 
--     FROM api.databases d
--     WHERE
--         trim(api.hmmer.checksum)  = trim(d.checksum) AND
--         trim(api.hmmer.file_name) = trim(d.file_name);

--     ALTER TABLE api.databases RENAME COLUMN file_name TO title;
--     ALTER TABLE api.databases
--     DROP COLUMN checksum,
--     DROP COLUMN url,
--     ADD UNIQUE(title),
--     ADD UNIQUE(title,description),
--     ADD PRIMARY KEY (id),
--     ALTER COLUMN organism_id SET NOT NULL,
--     ALTER COLUMN sequencetype_id SET NOT NULL,
--     ALTER COLUMN fastafile_id SET NOT NULL,
--     ALTER COLUMN description SET NOT NULL,
--     ALTER COLUMN title SET NOT NULL,
--     ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES api.organisms,
--     ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES api.sequencetypes,
--     ADD CONSTRAINT fk_fastafile FOREIGN KEY (fastafile_id) REFERENCES api.fastafiles;
    

-- \echo Create Production Blast DBs Table

-- CREATE TABLE api.production_blastdbs AS
--     SELECT id, organism_id,database_id, True as is_shown 
--     FROM api.blast
--     WHERE source = 'blast'
--     ORDER BY id ASC;

--     ALTER TABLE api.production_blastdbs
--     ADD UNIQUE(organism_id,database_id),
--     ADD PRIMARY KEY (id),
--     ALTER COLUMN organism_id SET NOT NULL,
--     ALTER COLUMN database_id SET NOT NULL;


-- \echo Create Production Hmmer DBs table

-- CREATE TABLE api.production_hmmerdbs AS
--     SELECT id, organism_id,database_id ,True as is_shown
--     FROM api.hmmer
--     WHERE source = 'hmmer';

--     ALTER TABLE api.production_hmmerdbs
--     ADD UNIQUE(organism_id,database_id),
--     ADD PRIMARY KEY (id),
--     ALTER COLUMN organism_id SET NOT NULL,
--     ALTER COLUMN database_id SET NOT NULL;

-- \echo Create Production JBrowse Settings table

-- CREATE TABLE api.production_jbrowsesettings AS
--     SELECT 0 as id, id as blastdb_id, url
--     FROM api.blast 
--     WHERE source = 'blast' and url is not null;

-- \echo Create Training Blast Dbs

-- CREATE TABLE api.training_blastdbs AS
--     SELECT id, organism_id,database_id ,True as is_shown
--     FROM api.blast
--     WHERE source = 'training_blast'
--     ORDER BY id ASC;

--     ALTER TABLE api.training_blastdbs
--     ADD UNIQUE(organism_id,database_id),
--     ADD PRIMARY KEY (id),
--     ALTER COLUMN organism_id SET NOT NULL,
--     ALTER COLUMN database_id SET NOT NULL;

-- \echo Create Training Hmmer DBs table

-- CREATE TABLE api.training_hmmerdbs AS
--     SELECT id, organism_id,database_id ,True as is_shown
--     FROM api.hmmer
--     WHERE source = 'training_hmmer';

-- \echo Create Training JBrowse Settings table

-- CREATE TABLE api.training_jbrowsesettings AS
--     SELECT 0 as id, id as blastdb_id, url
--     FROM api.blast 
--     WHERE source = 'training_blast' and url is not null;

-- CREATE SEQUENCE api.production_jbrowsesettings_seq START 1;
-- \echo Update api.production_jbrowsesettings.id column
-- UPDATE api.production_jbrowsesettings 
-- SET id = nextval('api.production_jbrowsesettings_seq');

-- ALTER TABLE api.production_jbrowsesettings
-- ADD PRIMARY KEY (id),
-- ADD UNIQUE(blastdb_id),
-- ADD UNIQUE(url),
-- ADD UNIQUE(blastdb_id,url),
-- ALTER COLUMN blastdb_id SET NOT NULL,
-- ALTER COLUMN url SET NOT NULL;
-- ALTER SEQUENCE api.production_jbrowsesettings_seq RESTART WITH 1;

-- \echo Update api.training_jbrowsesettings.id column

-- UPDATE api.training_jbrowsesettings 
-- SET id = nextval('api.production_jbrowsesettings_seq');

-- ALTER TABLE api.training_jbrowsesettings
-- ADD PRIMARY KEY (id),
-- ADD UNIQUE(blastdb_id),
-- ADD UNIQUE(url),
-- ADD UNIQUE(blastdb_id,url),
-- ALTER COLUMN blastdb_id SET NOT NULL,
-- ALTER COLUMN url SET NOT NULL;

-- DROP TABLE api.blast;
-- DROP TABLE api.hmmer;

-- DROP SEQUENCE api.production_jbrowsesettings_seq;
-- DROP SEQUENCE api.collections_id_seq CASCADE;
-- DROP SEQUENCE api.fastafiles_id_seq CASCADE;

-- ALTER TABLE api.organisms
-- DROP COLUMN display_name,
-- DROP COLUMN organism_id;
-- DROP EXTENSION  postgres_fdw CASCADE;

-- ALTER TABLE api.collections
-- ADD UNIQUE(name, display_name);
-- -- -----------------------------------
-- -- -- Drop the API schema if it exists
-- -- -----------------------------------
-- -- DROP SCHEMA IF EXISTS api CASCADE;

-- -- -----------------------------------
-- -- -- Create api schema
-- -- ------------------------------- \o /dev/null

-- -- ALTER DATABASE django SET client_min_messages TO WARNING;
-- -- \echo Connect to the django database

-- -- \c django

-- -- -- \echo Drop API schema 
-- -- DROP SCHEMA IF EXISTS api CASCADE;
-- -- \echo Create API schema
-- -- CREATE SCHEMA api;

-- -- \echo Create Collection Table

-- -- CREATE TABLE api.collections(
-- --   "id" SERIAL,
-- --   "name" VARCHAR(40) NOT NULL UNIQUE,
-- --   "display_name" VARCHAR(100) NOT NULL UNIQUE);

-- --     INSERT INTO api.collections (name, display_name)
-- --     VALUES
-- --         ('production','Production Collection'),
-- --         ('training','Training Collection');

-- -- -- \echo Create Fasta File table
-- -- -- CREATE TABLE  api.fastafiles (LIKE  public.fastafiles INCLUDING ALL);
-- -- -- INSERT INTO api.fastafiles SELECT * FROM public.fastafiles;
-- -- -- ALTER TABLE api.fastafiles ADD UNIQUE(checksum,file_name);

-- -- \echo Create Fasta File Table
-- -- -- \o /dev/null
-- -- CREATE TABLE IF NOT EXISTS api.fastafiles (
-- --   id SERIAL,
-- --   checksum VARCHAR(200) NOT NULL,
-- --   file_name VARCHAR(300) NOT NULL,
-- --   is_shown  BOOLEAN NOT NULL DEFAULT True,
-- --   PRIMARY KEY (id),
-- --   UNIQUE(checksum),
-- --   UNIQUE(file_name),
-- --   UNIQUE(checksum,file_name)
-- -- );

-- -- -- Make sure to copy the fastafiles.md5 to the root
-- -- -- directory if the postgresql server before running
-- -- -- this script from the django conrainer.

-- -- -- Import the Fasta File Data
-- -- COPY api.fastafiles(checksum, file_name)
-- -- FROM '/fastafiles.md5'
-- -- DELIMITER ',';

-- -- UPDATE api.fastafiles SET file_name = trim(regexp_replace(file_name,'^.*\/',''));


-- -- \echo Create Sequencetype Table
-- -- CREATE TABLE  api.sequencetypes (LIKE  public.blast_sequencetype INCLUDING ALL);
-- -- INSERT INTO api.sequencetypes SELECT * FROM public.blast_sequencetype;
-- -- ALTER TABLE api.sequencetypes ADD UNIQUE(molecule_type,dataset_type);

-- -- \echo Create Organism Table ( Production & Training )
-- -- -- Create the Organisms Table

-- -- CREATE TABLE api.organisms AS
-- --     SELECT po.id as id, 
-- --         COALESCE(t.id,null) as organism_id ,
-- --         trim(po.display_name) as display_name,
-- --         trim(split_part(po.display_name, ' ', 1)) genus ,
-- --         trim(split_part(po.display_name, ' ', 2)) species,
-- --         lower(trim(po.short_name)) as short_name,
-- --         po.tax_id
-- --     FROM app_organism po
-- --     LEFT OUTER JOIN training.app_organism t 
-- --     ON trim(po.display_name) = trim(t.display_name)
-- --     ORDER BY genus, species, organism_id ASC;

-- --     -- Update Organism Constraints
-- --     ALTER TABLE api.organisms
-- --     ALTER COLUMN genus SET NOT NULL,
-- --     ALTER COLUMN species SET NOT NULL,
-- --     ALTER COLUMN short_name SET NOT NULL,
-- --     ADD UNIQUE(short_name),
-- --     ADD UNIQUE(genus,species,short_name),
-- --     ADD PRIMARY KEY (id);

-- --     -- Update Organisms Table
-- --     UPDATE api.organisms
-- --     SET organism_id = NULL 
-- --     WHERE id = organism_id;

-- -- \echo Create Blast Data Table ( Production & Training )

-- -- CREATE TABLE api.blast AS
-- --     WITH organism_updates as(
-- --         SELECT id as prod_id, organism_id
-- --         FROM api.organisms
-- --         WHERE organism_id is not NULL
-- --         AND organism_id != id
-- --         ORDER BY organism_id, prod_id ASC
-- --     ),all_jbrowse AS (
-- --         SELECT 'blast' as source, blast_db_id, url from blast_jbrowsesetting
-- --         UNION
-- --         SELECT 'training_blast' as source, blast_db_id, url from training.blast_jbrowsesetting
-- --     ),all_blast as (
-- --         SELECT 'blast' as source,bb.id,bb.organism_id as oid, bb.organism_id, bb.type_id,bb.file_name,bb.description, aj.url 
-- --         FROM blast_blastdb bb
-- --         LEFT OUTER JOIN all_jbrowse as aj
-- --         ON aj.source = 'blast' AND bb.id = aj.blast_db_id
-- --         UNION
-- --         SELECT 'training_blast' as source,tb.id, tb.organism_id as oid, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, tb.type_id,tb.file_name,tb.description, aj.url 
-- --         FROM training.blast_blastdb tb
-- --         LEFT OUTER JOIN all_jbrowse as aj
-- --         ON aj.source = 'training_blast' AND tb.id = aj.blast_db_id
-- --         LEFT OUTER JOIN organism_updates ou
-- --         ON tb.organism_id = ou.organism_id
-- --     ) 
-- --     SELECT source,0 as id, 0 as database_id, f.checksum, trim(ab.file_name) as file_name, organism_id,
-- --         ab.type_id as sequencetype_id, f.id as fastafile_id, trim(ab.description) as description , 
-- --         url
-- --     FROM all_blast ab
-- --     LEFT OUTER JOIN api.fastafiles f
-- --     ON trim(ab.file_name) = trim(f.file_name)
-- --     LEFT JOIN api.sequencetypes s 
-- --     ON s.id = ab.type_id
-- --     ORDER BY file_name, source ASC;

-- --     -- Create Blast Sequence
-- --     CREATE SEQUENCE api.blast_seq START 1;
-- --     UPDATE api.blast 
-- --     SET id = nextval('api.blast_seq')
-- --     WHERE source = 'blast';

-- --     -- Reset Blast Sequencet For Training 
-- --     ALTER SEQUENCE api.blast_seq RESTART WITH 1;

-- --     UPDATE api.blast 
-- --     SET id = nextval('api.blast_seq')
-- --     WHERE source = 'training_blast';

-- --     DROP SEQUENCE api.blast_seq;

-- -- \echo Create Hmmer Data Table ( Production & Training )

-- -- CREATE TABLE api.hmmer AS
-- --     WITH organism_updates as(
-- --         SELECT id as prod_id, organism_id
-- --         FROM api.organisms
-- --         WHERE organism_id is not NULL
-- --         AND organism_id != id
-- --         ORDER BY organism_id, prod_id ASC
-- --     ),all_hmmer as (
-- --         SELECT 'hmmer' as source, h.organism_id as oid, h.organism_id,  trim(h.file_name) as file_name, trim(h.description) as description, 
-- --                 trim(h.title) as title FROM hmmer_hmmerdb h
-- --         LEFT OUTER JOIN organism_updates ou
-- --         ON h.organism_id = ou.organism_id
-- --         UNION
-- --         SELECT 'training_hmmer' as source, th.organism_id as oid,COALESCE(ou.prod_id, th.organism_id ) as organism_id,  trim(th.file_name) as file_name, trim(th.description) as description, 
-- --                 trim(th.title) as title FROM training.hmmer_hmmerdb th
-- --         LEFT OUTER JOIN organism_updates ou
-- --         ON th.organism_id = ou.organism_id
-- --         ORDER BY file_name, source ASC
-- --     ) SELECT source,0 as id, 0 as database_id, f.checksum, trim(ah.file_name) as file_name,organism_id, 3 as sequencetype_id, f.id as fastafile_id, trim(ah.description) as description, null as url
-- --     FROM all_hmmer ah
-- --     LEFT OUTER JOIN api.fastafiles f
-- --     ON trim(ah.file_name) = trim(f.file_name)
-- --     ORDER BY file_name,source ASC;


-- --     CREATE SEQUENCE api.hmmer_seq START 1;
-- --     UPDATE api.hmmer 
-- --     SET id = nextval('api.hmmer_seq')
-- --     WHERE source = 'hmmer';

-- --     -- Reset Hmmer  Sequence For Training
-- --     ALTER SEQUENCE api.hmmer_seq RESTART WITH 1;
-- --     UPDATE api.hmmer 
-- --     SET id = nextval('api.hmmer_seq')
-- --     WHERE source = 'training_hmmer';

-- --     DROP SEQUENCE api.hmmer_seq;

-- -- \echo Create Databases Table

-- -- CREATE TABLE api.databases AS
-- --     WITH data as (
-- --             SELECT * FROM api.blast
-- --             UNION
-- --             SELECT * FROM api.hmmer
-- --             ORDER BY file_name,source ASC   
-- --     )
-- --     SELECT DISTINCT ON (checksum,file_name) 
-- --         id, organism_id, sequencetype_id,fastafile_id, description,
-- --         checksum,file_name,url
-- --     FROM data;

-- --     CREATE SEQUENCE api.databases_seq START 1;
    
-- --     \echo Update api.databases.id column
-- --     UPDATE api.databases SET id = nextval('api.databases_seq');

-- --     DROP SEQUENCE api.databases_seq;

-- --     \echo Update api.blast.database_id column

-- --     UPDATE api.blast
-- --     SET database_id = d.id 
-- --     FROM api.databases d
-- --     WHERE
-- --         trim(api.blast.checksum)  = trim(d.checksum) AND
-- --         trim(api.blast.file_name) = trim(d.file_name);

-- --     \echo Update api.hmmer.database_id column

-- --     UPDATE api.hmmer
-- --     SET database_id = d.id 
-- --     FROM api.databases d
-- --     WHERE
-- --         trim(api.hmmer.checksum)  = trim(d.checksum) AND
-- --         trim(api.hmmer.file_name) = trim(d.file_name);

-- --     ALTER TABLE api.databases RENAME COLUMN file_name TO title;
-- --     ALTER TABLE api.databases
-- --     DROP COLUMN checksum,
-- --     DROP COLUMN url,
-- --     ADD UNIQUE(title),
-- --     ADD UNIQUE(title,description),
-- --     ADD PRIMARY KEY (id),
-- --     ALTER COLUMN organism_id SET NOT NULL,
-- --     ALTER COLUMN sequencetype_id SET NOT NULL,
-- --     ALTER COLUMN fastafile_id SET NOT NULL,
-- --     ALTER COLUMN description SET NOT NULL,
-- --     ALTER COLUMN title SET NOT NULL,
-- --     ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES api.organisms,
-- --     ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES api.sequencetypes,
-- --     ADD CONSTRAINT fk_fastafile FOREIGN KEY (fastafile_id) REFERENCES api.fastafiles;
    

-- -- \echo Create Production Blast DBs Table

-- -- CREATE TABLE api.production_blastdbs AS
-- --     SELECT id, organism_id,database_id 
-- --     FROM api.blast
-- --     WHERE source = 'blast'
-- --     ORDER BY id ASC;

-- --     ALTER TABLE api.production_blastdbs
-- --     ADD UNIQUE(organism_id,database_id),
-- --     ADD PRIMARY KEY (id),
-- --     ALTER COLUMN organism_id SET NOT NULL,
-- --     ALTER COLUMN database_id SET NOT NULL;


-- -- \echo Create Production Hmmer DBs table

-- -- CREATE TABLE api.production_hmmerdbs AS
-- --     SELECT id, organism_id,database_id 
-- --     FROM api.hmmer
-- --     WHERE source = 'hmmer';

-- --     ALTER TABLE api.production_hmmerdbs
-- --     ADD UNIQUE(organism_id,database_id),
-- --     ADD PRIMARY KEY (id),
-- --     ALTER COLUMN organism_id SET NOT NULL,
-- --     ALTER COLUMN database_id SET NOT NULL;

-- -- \echo Create Production JBrowse Settings table

-- -- CREATE TABLE api.production_jbrowsesettings AS
-- --     SELECT 0 as id, id as blastdb_id, url
-- --     FROM api.blast 
-- --     WHERE source = 'blast' and url is not null;

-- -- \echo Create Training Blast Dbs

-- -- CREATE TABLE api.training_blastdbs AS
-- --     SELECT id, organism_id,database_id 
-- --     FROM api.blast
-- --     WHERE source = 'training_blast'
-- --     ORDER BY id ASC;

-- --     ALTER TABLE api.training_blastdbs
-- --     ADD UNIQUE(organism_id,database_id),
-- --     ADD PRIMARY KEY (id),
-- --     ALTER COLUMN organism_id SET NOT NULL,
-- --     ALTER COLUMN database_id SET NOT NULL;

-- -- \echo Create Training Hmmer DBs table

-- -- CREATE TABLE api.training_hmmerdbs AS
-- --     SELECT id, organism_id,database_id 
-- --     FROM api.hmmer
-- --     WHERE source = 'training_hmmer';

-- -- \echo Create Training JBrowse Settings table

-- -- CREATE TABLE api.training_jbrowsesettings AS
-- --     SELECT 0 as id, id as blastdb_id, url
-- --     FROM api.blast 
-- --     WHERE source = 'training_blast' and url is not null;

-- -- CREATE SEQUENCE api.production_jbrowsesettings_seq START 1;
-- -- \echo Update api.production_jbrowsesettings.id column
-- -- UPDATE api.production_jbrowsesettings 
-- -- SET id = nextval('api.production_jbrowsesettings_seq');

-- -- ALTER TABLE api.production_jbrowsesettings
-- -- ADD PRIMARY KEY (id),
-- -- ADD UNIQUE(blastdb_id),
-- -- ADD UNIQUE(url),
-- -- ADD UNIQUE(blastdb_id,url),
-- -- ALTER COLUMN blastdb_id SET NOT NULL,
-- -- ALTER COLUMN url SET NOT NULL;
-- -- ALTER SEQUENCE api.production_jbrowsesettings_seq RESTART WITH 1;

-- -- \echo Update api.training_jbrowsesettings.id column

-- -- UPDATE api.training_jbrowsesettings 
-- -- SET id = nextval('api.production_jbrowsesettings_seq');

-- -- ALTER TABLE api.training_jbrowsesettings
-- -- ADD PRIMARY KEY (id),
-- -- ADD UNIQUE(blastdb_id),
-- -- ADD UNIQUE(url),
-- -- ADD UNIQUE(blastdb_id,url),
-- -- ALTER COLUMN blastdb_id SET NOT NULL,
-- -- ALTER COLUMN url SET NOT NULL;

-- -- DROP TABLE api.blast;
-- -- DROP TABLE api.hmmer;

-- -- DROP SEQUENCE api.production_jbrowsesettings_seq;
-- -- DROP SEQUENCE api.collections_id_seq CASCADE;
-- -- DROP SEQUENCE api.fastafiles_id_seq CASCADE;

-- -- ALTER TABLE api.organisms
-- -- DROP COLUMN display_name,
-- -- DROP COLUMN organism_id;
-- -- DROP EXTENSION  postgres_fdw CASCADE;
-- -- ------
-- -- CREATE SCHEMA api;

-- -- CREATE TABLE api.collections(
-- --   "id" SERIAL,
-- --   "name" VARCHAR(40) NOT NULL UNIQUE,
-- --   "display_name" VARCHAR(100) NOT NULL UNIQUE);




-- -- INSERT INTO api.collections (name, display_name) VALUES('production','Production Collection');
-- -- INSERT INTO api.collections (name, display_name) VALUES('training','Training Collection');

-- -- ----------------------------------
-- -- -- Create Fasta File Table
-- -- ----------------------------------
-- -- CREATE TABLE api.fastafiles AS
-- --     SELECT id, checksum , trim(file_name) as file_name, True as is_shown
-- --     FROM public.fastafiles 
-- --     ORDER BY file_name ASC;

-- -- ---------------------------------
-- -- -- Create Sequence Types Table
-- -- ---------------------------------
-- -- CREATE TABLE api.sequencetypes AS
-- --     SELECT id, lower(trim(molecule_type)) AS molecule_type, trim(dataset_type) AS dataset_type
-- --     FROM public.blast_sequencetype
-- --     ORDER BY dataset_type ASC;

-- -- ---------------------------------
-- -- -- Create the Organisms view
-- -- ---------------------------------
-- -- CREATE TABLE api.organisms AS
-- --     SELECT po.id as id, 
-- --         split_part(po.display_name, ' ', 1) genus ,
-- --         split_part(po.display_name, ' ', 2) species,
-- --         lower(po.short_name) as short_name,
-- --         po.tax_id,
-- --         NULL as infraspecies,
-- --         True as is_shown,
-- --         COALESCE(t.id,NULL) as organism_id 

-- --     FROM app_organism po
-- --     LEFT OUTER JOIN training.app_organism t 
-- --     ON po.display_name = t.display_name
-- --     ORDER BY genus, species, organism_id ASC;

-- -- ---------------------------------
-- -- -- Create Organism Updates View
-- -- ---------------------------------
-- -- CREATE TABLE api.organism_updates AS
-- --     SELECT id as prod_id, organism_id
-- --     FROM api.organisms
-- --     WHERE organism_id is not NULL
-- --     AND id != organism_id
-- --     ORDER BY organism_id, prod_id ASC;

-- -- ---------------------------------
-- -- -- Create Temp blastdb_blastdb 
-- -- ---------------------------------
-- -- CREATE VIEW api.blast_blastdb AS
-- --     SELECT tb.id, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, tb.title, tb.description, tb.file_name, tb.type_id
-- --     FROM training.blast_blastdb tb
-- --     LEFT OUTER JOIN api.organism_updates ou
-- --     ON tb.organism_id = ou.organism_id
-- --     ORDER BY title ASC;

-- -- ---------------------------------
-- -- -- Create Temp hmmerdb_hmmerdb 
-- -- ---------------------------------
-- -- CREATE VIEW api.hmmer_hmmerdb AS
-- --     SELECT tb.id,ou.prod_id,tb.organism_id as oid, COALESCE(ou.prod_id, tb.organism_id ) as organism_id, 
-- --            tb.title, tb.description, tb.file_name, 3 as type_id
-- --     FROM training.hmmer_hmmerdb tb
-- --     LEFT OUTER JOIN api.organism_updates ou
-- --     ON tb.organism_id = ou.organism_id
-- --     ORDER BY title ASC;

-- -- ---------------------------------
-- -- -- Create Database Table
-- -- ---------------------------------
-- -- CREATE TABLE api.databases AS
-- --     SELECT 0 as id, f.id as fastafile_id, f.file_name, 1 as is_Shown,
-- --         COALESCE(COALESCE(COALESCE(COALESCE(b.title,h.title),tb.title)),th.title) as title,
-- --         COALESCE(COALESCE(COALESCE(COALESCE(b.description,h.description),tb.description)),th.description) as description,
-- --         COALESCE(COALESCE(COALESCE(COALESCE(b.organism_id,h.organism_id),tb.organism_id)),th.organism_id) as organism_id,
-- --         COALESCE(COALESCE(COALESCE(COALESCE(b.type_id,3),tb.type_id)),3) as sequencetype_id
-- --     FROM api.fastafiles f
-- --     LEFT OUTER JOIN public.blast_blastdb b
-- --     ON trim(f.file_name) = trim(b.file_name)
-- --     LEFT OUTER JOIN public.hmmer_hmmerdb h
-- --     ON trim(f.file_name) = trim(h.file_name)
-- --     LEFT OUTER JOIN api.blast_blastdb tb
-- --     ON trim(f.file_name) = trim(tb.file_name)
-- --     LEFT OUTER JOIN api.hmmer_hmmerdb th
-- --     ON trim(f.file_name) = trim(th.file_name)
-- --     ORDER BY fastafile_id ASC;


-- -- -----------------------------------------------
-- -- -- Create Databases Sequence Table & Update IDs
-- -- -----------------------------------------------
-- -- CREATE SEQUENCE api.databases_seq START 1;
-- -- UPDATE api.databases SET id = nextval('api.databases_seq');

-- -- ---------------------------------
-- -- -- Create Prduction BlastDBs
-- -- ---------------------------------
-- -- CREATE TABLE api.production_blastdbs AS
-- --     SELECT b.id as blast_db_id, 0 as id, b.organism_id, d.id as database_id, True as is_shown
-- --     FROM blast_blastdb  b 
-- --     INNER JOIN api.databases d 
-- --     ON d.file_name = b.file_name
-- --     ORDER BY database_id ASC;

-- -- --------------------------------------------
-- -- -- Create Production BlastDBs Sequence Table
-- -- --------------------------------------------
-- -- CREATE SEQUENCE api.production_blastdbs_seq START 1;

-- -- UPDATE api.production_blastdbs
-- -- SET id = nextval('api.production_blastdbs_seq');

-- -- ---------------------------------
-- -- -- Create Production JBrowse
-- -- ---------------------------------
-- -- CREATE TABLE api.production_jbrowsesettings AS 
-- --     SELECT 0 as id, b.blast_db_id, b.url ,pb.id as new_blast_id
-- --     FROM blast_jbrowsesetting b
-- --     -- ORDER BY blast_db_id ASC
-- --     LEFT OUTER JOIN api.production_blastdbs pb
-- --     ON pb.blast_db_id = b.blast_db_id;

-- -- --------------------------------------------------------------
-- -- -- Update Production JBrowse Settings Tablenblast_db_id column
-- -- --------------------------------------------------------------
-- -- UPDATE
-- --     api.production_jbrowsesettings
-- -- SET
-- --     blast_db_id = new_blast_id;

-- -- --------------------------------------
-- -- -- Create Production JBrowse Seq Table
-- -- --------------------------------------
-- -- CREATE SEQUENCE api.production_jbrowsesettings_seq START 1;

-- -- -----------------------------------------------
-- -- -- Update Production JBrowse Settings id column
-- -- -----------------------------------------------
-- -- UPDATE api.production_jbrowsesettings
-- -- SET id = nextval('api.production_jbrowsesettings_seq');

-- -- ---------------------------------
-- -- -- Create Prduction HmmerDBs
-- -- ---------------------------------
-- -- CREATE TABLE api.production_hmmerdbs AS 
-- --     SELECT 0 as id, h.organism_id, d.id as database_id, True as is_shown, d.file_name
-- --     FROM hmmer_hmmerdb  h 
-- --     LEFT JOIN api.databases d
-- --     ON trim(d.file_name) = trim(h.file_name);

-- -- --------------------------------------------
-- -- -- Create Production HmmerDBs Sequence Table
-- -- --------------------------------------------
-- -- CREATE SEQUENCE api.production_hmmerdbs_seq START 1;

-- -- UPDATE api.production_hmmerdbs
-- -- SET id = nextval('api.production_hmmerdbs_seq');

-- -- ---------------------------------
-- -- -- Create Training BlastDBs
-- -- ---------------------------------
-- -- CREATE TABLE api.training_blastdbs AS
-- --     SELECT b.id as blast_db_id,0 as id, COALESCE(ou.prod_id,b.organism_id) as organism_id, f.id as database_id, True as is_shown
-- --     FROM training.blast_blastdb  b 
-- --     INNER JOIN api.databases f
-- --     ON f.file_name = b.file_name
-- --     LEFT OUTER JOIN api.organism_updates ou
-- --     ON ou.organism_id = b.organism_id;

-- -- ------------------------------------------
-- -- -- Create Training BlastDBs Sequence Table
-- -- ------------------------------------------
-- -- CREATE SEQUENCE api.training_blastdbs_seq START 1;

-- -- UPDATE api.training_blastdbs
-- -- SET id = nextval('api.training_blastdbs_seq');

-- -- ---------------------------------
-- -- -- Create Training JBrowse
-- -- ---------------------------------
-- -- CREATE TABLE api.training_jbrowsesettings AS 
-- --     SELECT  0 as id, b.id as blastdb_id, j.url
-- --     FROM training.blast_jbrowsesetting j
-- --     INNER JOIN api.training_blastdbs b
-- --     ON b.blast_db_id = j.blast_db_id;

-- -- ------------------------------------
-- -- -- Create Training JBrowse Seq Table
-- -- ------------------------------------
-- -- CREATE SEQUENCE api.training_jbrowsesettings_seq START 1;

-- -- UPDATE api.training_jbrowsesettings
-- -- SET id = nextval('api.training_jbrowsesettings_seq');

-- -- ---------------------------------
-- -- -- Create Training HmmerDBs
-- -- ---------------------------------
-- -- CREATE TABLE api.training_hmmerdbs AS 
-- --     SELECT 0 as id, COALESCE(ou.prod_id,h.organism_id) as organism_id, f.id as database_id, True as is_shown 
-- --     FROM training.hmmer_hmmerdb  h 
-- --     INNER JOIN api.fastafiles f 
-- --     ON f.file_name = h.file_name
-- --     LEFT OUTER JOIN api.organism_updates ou
-- --     ON ou.organism_id = h.organism_id;

-- -- ------------------------------------------
-- -- -- Create Training BlastDBs Sequence Table
-- -- ------------------------------------------
-- -- CREATE SEQUENCE api.training_hmmerdbs_seq START 1;

-- -- UPDATE api.training_hmmerdbs
-- -- SET id = nextval('api.training_hmmerdbs_seq');

-- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- -- ALTER TABLE api.databases DROP column file_name;
-- -- ALTER TABLE api.organisms DROP column organism_id;
-- -- ALTER TABLE api.production_hmmerdbs DROP COLUMN file_name;
-- -- ALTER TABLE api.production_blastdbs DROP COLUMN  blast_db_id;
-- -- ALTER TABLE api.production_jbrowsesettings DROP column new_blast_id;
-- -- ALTER TABLE api.production_jbrowsesettings RENAME COLUMN blast_db_id to blastdb_id;
-- -- ALTER TABLE api.training_blastdbs DROP COLUMN  blast_db_id;

-- -- -- Check Sequence Types table
-- -- -- SELECT * FROM api.collections where name is NULL;
-- -- -- SELECT * FROM api.collections where display_name is NULL;
-- -- COPY (SELECT id, name, display_name FROM api.collections ORDER BY id ASC) TO '/opt/collections.csv' DELIMITER ',' CSV HEADER;

-- -- -- Check Sequence Types table
-- -- -- SELECT * FROM api.sequencetypes where molecule_type is NULL;
-- -- -- SELECT * FROM api.sequencetypes where dataset_type is NULL;
-- -- COPY (SELECT * FROM api.sequencetypes ORDER BY id ASC) TO '/opt/sequencetypes.csv' DELIMITER ',' CSV HEADER;

-- -- -- -- CHeck Organisms Table
-- -- -- SELECT * FROM api.organisms where genus is NULL;
-- -- -- SELECT * FROM api.organisms where species is NULL;
-- -- -- SELECT * FROM api.organisms where short_name is NULL;
-- -- -- SELECT * FROM api.organisms where tax_id is NULL;
-- -- -- SELECT * FROM api.organisms where is_shown = False;
-- -- COPY (SELECT * FROM api.organisms ORDER BY id ASC) TO '/opt/organisms.csv' DELIMITER ',' CSV HEADER;

-- -- -- Check Fasta Files table
-- -- -- SELECT * FROM api.fastafiles where checksum is NULL;
-- -- -- SELECT * FROM api.fastafiles where file_name is NULL;
-- -- -- SELECT * FROM api.fastafiles where is_shown = False;
-- -- COPY (SELECT id, file_name, checksum, is_shown FROM api.fastafiles ORDER BY id ASC) TO '/opt/fastafiles.csv' DELIMITER ',' CSV HEADER;


-- -- -- -- Check Shared Database Table Foreihgn Keys
-- -- -- SELECT * FROM api.databases where fastafile_id not in (SELECT id FROM api.fastafiles );
-- -- -- SELECT * FROM api.databases where sequencetype_id not in (SELECT id FROM api.sequencetypes );
-- -- -- SELECT * FROM api.databases where organism_id not in (SELECT id FROM api.organisms);
-- -- -- SELECT * FROM api.databases where title is NULL;
-- -- -- SELECT * FROM api.databases where description is NULL;
-- -- -- SELECT * FROM api.databases where is_shown = False;
-- -- COPY (SELECT id, organism_id, sequencetype_id, fastafile_id, title, description, is_shown FROM api.databases ORDER BY id ASC) TO '/opt/databases.csv' DELIMITER ',' CSV HEADER;


-- -- -- -- Check Production BlastDBs
-- -- -- select * FROM api.production_blastdbs where  organism_id not in (SELECT id FROM api.organisms);
-- -- -- select * FROM api.production_blastdbs where  database_id not in (SELECT id FROM api.databases);
-- -- COPY (SELECT * FROM api.production_blastdbs ORDER BY id ASC) TO '/opt/production_blastdbs.csv' DELIMITER ',' CSV HEADER;

-- -- -- -- Check Production HmmerDBs
-- -- -- select * FROM api.production_hmmerdbs where  organism_id not in (SELECT id FROM api.organisms);
-- -- -- select * FROM api.production_hmmerdbs where  database_id not in (SELECT id FROM api.databases);
-- -- COPY (SELECT * FROM api.production_hmmerdbs ORDER BY id ASC) TO '/opt/production_hmmerdbs.csv' DELIMITER ',' CSV HEADER;

-- -- -- Check production JBrowse Settings
-- -- -- select * from api.production_jbrowsesettings where blastdb_id not in (select id from api.production_blastdbs );
-- -- COPY (SELECT * FROM api.production_jbrowsesettings  ORDER BY id ASC) TO '/opt/production_jbrowsesettings.csv' DELIMITER ',' CSV HEADER;

-- -- -- -- Check Training BlastDBs
-- -- -- select * FROM api.training_blastdbs where  organism_id not in (SELECT id FROM api.organisms);
-- -- -- select * FROM api.training_blastdbs where  database_id not in (SELECT id FROM api.databases);
-- -- COPY (SELECT * FROM api.training_blastdbs ORDER BY id ASC) TO '/opt/training_blastdbs.csv' DELIMITER ',' CSV HEADER;

-- -- -- -- Check Training HmmerDBs
-- -- -- select * FROM api.training_hmmerdbs where  organism_id not in (SELECT id FROM api.organisms);
-- -- -- select * FROM api.training_hmmerdbs where  database_id not in (SELECT id FROM api.databases);
-- -- COPY (SELECT * FROM api.training_hmmerdbs ORDER BY id ASC) TO '/opt/training_hmmerdbs.csv' DELIMITER ',' CSV HEADER;

-- -- -- Check Training JBrowse Settings
-- -- -- select * from api.training_jbrowsesettings where blastdb_id not in (select id from api.training_blastdbs );
-- -- COPY (SELECT * FROM api.training_jbrowsesettings  ORDER BY id ASC) TO '/opt/training_jbrowsesettings.csv' DELIMITER ',' CSV HEADER;