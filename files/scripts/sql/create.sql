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
    "display_name" VARCHAR(100) NOT NULL UNIQUE);

    ALTER TABLE public.collections

    ADD UNIQUE(name, display_name);

    INSERT INTO public.collections (name, display_name)
        VALUES
            ('production','Production Collection'),
            ('training','Training Collection');
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
       file_name , null as description, null as src, checksum
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

ALTER TABLE databases
ADD PRIMARY KEY (id),
ADD CONSTRAINT fk_organism FOREIGN KEY (organism_id) REFERENCES organisms,
ADD CONSTRAINT fk_fastafile FOREIGN KEY (fastafile_id) REFERENCES fastafiles,
ADD CONSTRAINT fk_sequencetype FOREIGN KEY (sequencetype_id) REFERENCES sequencetypes,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN fastafile_id SET NOT NULL,
ALTER COLUMN description SET NOT NULL,
ALTER COLUMN id SET DEFAULT nextval('databases_id_seq'),
DROP COLUMN file_name;
----------------------------------------------------------
-- End Create and populate the databases table
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the production blastdbs
----------------------------------------------------------
\echo Create Production BlastDBs Table
\o

CREATE TABLE production.blastdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, d.sequencetype_id, b.url, b.checksum
FROM django.blast_blastdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases )
ORDER BY url asc;

ALTER TABLE production.blastdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE production.blast_id_seq START 1;
UPDATE production.blastdbs SET id = nextval('production.blast_id_seq');

ALTER TABLE production.blastdbs 
ADD PRIMARY KEY (id),
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
\echo Create Production JBrowse Settings Table
CREATE TABLE production.jbrowsesettings AS 
SELECT id, id as blastdb_id, url
FROM production.blastdbs
WHERE url IS NOT NULL
ORDER BY id ASC;

\o /dev/null
CREATE SEQUENCE production.jbrowsesettings_id_seq START 1;
SELECT setval('production.jbrowsesettings_id_seq', (SELECT MAX(id) FROM production.jbrowsesettings));

ALTER TABLE production.jbrowsesettings
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN blastdb_id SET NOT NULL,
ALTER COLUMN url SET NOT NULL,
ADD PRIMARY KEY (id),
ADD UNIQUE(url),
ADD UNIQUE(blastdb_id),
ADD UNIQUE(blastdb_id,url),
ADD CONSTRAINT fk_blastdb FOREIGN KEY (blastdb_id) REFERENCES production.blastdbs,
ALTER COLUMN id SET DEFAULT nextval('production.jbrowsesettings_id_seq');
----------------------------------------------------------
-- End Create and populate the production jbrowsesettings
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the production hmmerdbs
----------------------------------------------------------
\echo Create Production HmmerDBs Table

CREATE TABLE production.hmmerdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, b.checksum
FROM django.hmmer_hmmerdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases );

ALTER TABLE production.hmmerdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
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
SELECT  0 as id, d.organism_id, d.id as database_id, d.sequencetype_id, b.url, b.checksum
FROM django_training.blast_blastdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases )
ORDER BY url asc;

ALTER TABLE training.blastdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN sequencetype_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
DROP COLUMN IF EXISTS checksum;

CREATE SEQUENCE training.blast_id_seq START 1;
UPDATE training.blastdbs SET id = nextval('training.blast_id_seq');

ALTER TABLE training.blastdbs 
ADD PRIMARY KEY (id),
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
\echo Create Training JBrowse Settings Table
CREATE TABLE training.jbrowsesettings AS 
SELECT id, id as blastdb_id, url
FROM training.blastdbs
WHERE url IS NOT NULL
ORDER BY id ASC;

CREATE SEQUENCE training.jbrowsesettings_id_seq START 1;
SELECT setval('training.jbrowsesettings_id_seq', (SELECT MAX(id) FROM training.jbrowsesettings));
ALTER TABLE training.jbrowsesettings
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN blastdb_id SET NOT NULL,
ALTER COLUMN url SET NOT NULL,
ADD PRIMARY KEY (id),
ADD UNIQUE(url),
ADD UNIQUE(blastdb_id),
ADD UNIQUE(blastdb_id,url),
ADD CONSTRAINT fk_blastdb FOREIGN KEY (blastdb_id) REFERENCES training.blastdbs,
ALTER COLUMN id SET DEFAULT nextval('training.jbrowsesettings_id_seq');
----------------------------------------------------------
-- End Create and populate the training jbrowsesettings
----------------------------------------------------------

----------------------------------------------------------
-- Create and populate the training hmmerdbs
----------------------------------------------------------
\echo Create Training HmmerDbs Table
CREATE TABLE training.hmmerdbs AS
SELECT  0 as id, d.organism_id, d.id as database_id, b.checksum
FROM django_training.hmmer_hmmerdb b
JOIN databases d ON d.checksum =  b.checksum
WHERE b.checksum in (SELECT checksum from databases );

ALTER TABLE training.hmmerdbs
ALTER COLUMN id SET NOT NULL,
ALTER COLUMN organism_id SET NOT NULL,
ALTER COLUMN database_id SET NOT NULL,
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
