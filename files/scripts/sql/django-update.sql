ALTER DATABASE django SET client_min_messages TO ERROR;
ALTER DATABASE django_training SET client_min_messages TO ERROR;

\echo Begin Combining Django Dbs


-- -- Make sure to copy the fastafiles.md5 to the root
-- -- directory if the postgresql server before running
-- -- this script from the django conrainer.

-- -- Import the Fasta File Data
-- COPY fastafiles(checksum, file_name)
-- FROM '/fastafiles.md5'
-- DELIMITER ',';

-- Create the extension that allows us to query across dbs
CREATE EXTENSION postgres_fdw;

-- Create the training server
CREATE SERVER training FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5432', dbname 'django_training');

-- Create the user mapping
CREATE USER MAPPING FOR i5k SERVER training OPTIONS (user 'i5k', password 'i5k');

-- Create training schema
CREATE SCHEMA training;

-- Import the "foreign schema into the newly created training schema"
IMPORT FOREIGN SCHEMA public FROM SERVER training INTO training;

-- \o /dev/null

BEGIN;
ALTER TABLE blast_jbrowsesetting
DROP CONSTRAINT "blast_jbrowsesetting_blast_db_id_583d9543_fk_blast_blastdb_id",
ADD CONSTRAINT "blast_jbrowsesetting_blast_db_id_583d9543_fk_blast_blastdb_id"
  FOREIGN KEY ("blast_db_id")
  REFERENCES "blast_blastdb"(id)
  ON DELETE CASCADE;
  
COMMIT;
DELETE FROM blast_blastdb  WHERE is_shown = False;
\c django_training

BEGIN;
ALTER TABLE blast_jbrowsesetting
DROP CONSTRAINT "blast_jbrowses_blast_db_id_704033e7148f2da8_fk_blast_blastdb_id",
ADD CONSTRAINT "blast_jbrowses_blast_db_id_704033e7148f2da8_fk_blast_blastdb_id"
  FOREIGN KEY ("blast_db_id")
  REFERENCES "blast_blastdb"(id)
  ON DELETE CASCADE;
COMMIT;
DELETE FROM blast_blastdb  WHERE is_shown = False;
\c django


-- Update The *.hmmer_hmmerbds
DELETE FROM hmmer_hmmerdb  WHERE is_shown = False;
DELETE FROM training.hmmer_hmmerdb  WHERE is_shown = False;

-- Update short_name in *.organism tables
UPDATE app_organism set short_name = lower(short_name);
UPDATE training.app_organism set short_name = lower(short_name);

-- Update the blast_blastdb.fasta_file column
UPDATE blast_blastdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/',''));
UPDATE training.blast_blastdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/',''));

-- Update *hmmer_hmmerdb.fasta_file 
UPDATE hmmer_hmmerdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/','')) where is_shown = True;
UPDATE training.hmmer_hmmerdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/','')) where is_shown = True;
-- Update the file_name column by removing the path
-- UPDATE fastafiles SET file_name = trim(regexp_replace(file_name,'^.*\/',''));

-- Drop The Organism Description Column
ALTER TABLE app_organism DROP COLUMN description;
ALTER TABLE training.app_organism DROP COLUMN description;

-- Rename the fasta_file columns to file_name
ALTER TABLE blast_blastdb RENAME COLUMN fasta_file TO file_name;
-- Remove the organism_id CONSTRAINT so that we can easily update the
-- organism_id based on the combined api.organisms table
ALTER TABLE blast_blastdb DROP CONSTRAINT blast_blastdb_organism_id_656c41fd_fk_app_organism_id;


ALTER TABLE training.blast_blastdb RENAME COLUMN fasta_file TO file_name;
\c django_training
ALTER TABLE blast_blastdb DROP CONSTRAINT blast_blastdb_organism_id_656c41fd_fk_app_organism_id;
\c django
ALTER TABLE hmmer_hmmerdb RENAME COLUMN fasta_file TO file_name;
ALTER TABLE hmmer_hmmerdb DROP CONSTRAINT hmmer_hmmerdb_organism_id_5d59d15b_fk_app_organism_id;

ALTER TABLE training.hmmer_hmmerdb RENAME COLUMN fasta_file TO file_name;

\c django_training
ALTER TABLE hmmer_hmmerdb DROP CONSTRAINT hmmer_hmmerdb_organism_id_5d59d15b_fk_app_organism_id;

\c django
ALTER TABLE app_organism  ADD COLUMN organism_id INTEGER UNIQUE;

-- Update the training ids for app organisms
UPDATE
    app_organism ao
SET
    organism_id = tao.id
FROM
    training.app_organism tao
WHERE
    ao.display_name = tao.display_name;

UPDATE app_organism 
SET organism_id = NULL
WHERE id = organism_id;


ALTER TABLE blast_blastdb ADD COLUMN new_organism_id INTEGER UNIQUE;



UPDATE hmmer_hmmerdb
SET title = regexp_replace(title,'^.*\/','')
where title like '/%';


\c django_training 

UPDATE hmmer_hmmerdb
SET title = regexp_replace(title,'^.*\/','')
where title like '/%';

\c django
\o 
\echo -------------------------------------------------------UPDATED DJANGO DATABASE--------------------------------------------------------------------
\echo
SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount 
FROM pg_stat_all_tables 
WHERE schemaname in ('public','training') AND relname NOT LIKE 'pg%' AND relname NOT LIKE 'sql%' order by schemaname, relname ASC;

\c django_training
SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount 
FROM pg_stat_all_tables 
WHERE schemaname in ('public','training') AND relname NOT LIKE 'pg%' AND relname NOT LIKE 'sql%' order by schemaname, relname ASC;


\i /sql/combo.sql

\c django

\echo
\echo ---------------------------------------------------------API DATABASE DATA-----------------------------------------------------------------------
\echo
SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount FROM pg_stat_all_tables WHERE relname NOT LIKE 'pg%' AND relname NOT LIKE
'sql%' AND schemaname in ('api') order by schemaname, relname ASC ;


\c django_training

\echo Drop API Database
DROP DATABASE IF EXISTS api;
\echo Recreate API Database 
CREATE DATABASE api 
WITH TEMPLATE django;
ALTER DATABASE  api SET client_min_messages TO ERROR;
\c api

\echo Drop public schema

do $$ declare
    r record;
begin
    for r in (select tablename from pg_tables where schemaname = 'public') loop
        execute 'drop table if exists ' || quote_ident(r.tablename) || ' cascade';
    end loop;
end $$;

DROP SCHEMA training CASCADE;

\! rm api.pgc &> /dev/null
\! pg_dump -n api  -U i5k -d api  -C -c --if-exists -Fc -f api.pgc 2>/dev/null

\c api
set search_path to api;
ALTER TABLE collections SET SCHEMA public;
ALTER TABLE fastafiles SET SCHEMA public;
ALTER TABLE organisms SET SCHEMA public;
ALTER TABLE sequencetypes SET SCHEMA public;
-- CREATE SCHEMA public;
-- CREATE SCHEMA production;
-- CREATE SCHEMA training;
\d
\dn


