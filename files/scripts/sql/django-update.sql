-- Create The Fasta File Table
\o /dev/null
CREATE TABLE IF NOT EXISTS fastafiles (
  id SERIAL,
  checksum VARCHAR(200) NOT NULL,
  file_name VARCHAR(300) NOT NULL,
  is_shown  BOOLEAN NOT NULL DEFAULT True,
  PRIMARY KEY (id),
  UNIQUE(checksum),
  UNIQUE(file_name)
);

-- Make sure to copy the fastafiles.md5 to the root
-- directory if the postgresql server before running
-- this script from the django conrainer.

-- Import the Fasta File Data
COPY fastafiles(checksum, file_name)
FROM '/fastafiles.md5'
DELIMITER ',';

\o
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

\o /dev/null

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
UPDATE fastafiles SET file_name = trim(regexp_replace(file_name,'^.*\/',''));

-- Drop THe Description Column
ALTER TABLE app_organism DROP COLUMN description;
ALTER TABLE training.app_organism DROP COLUMN description;

-- Rename the fasta_file columns to file_name
ALTER TABLE blast_blastdb RENAME COLUMN fasta_file TO file_name;
ALTER TABLE training.blast_blastdb RENAME COLUMN fasta_file TO file_name;
ALTER TABLE hmmer_hmmerdb RENAME COLUMN fasta_file TO file_name;
ALTER TABLE training.hmmer_hmmerdb RENAME COLUMN fasta_file TO file_name;
ALTER TABLE app_organism  ADD COLUMN train_id INTEGER UNIQUE;

-- Update the training ids for app organisms
UPDATE
    app_organism ao
SET
    train_id = tao.id
FROM
    training.app_organism tao
WHERE
    ao.display_name = tao.display_name;

UPDATE hmmer_hmmerdb
SET title = regexp_replace(title,'^.*\/','')
where title like '/%';


\c django_training 

UPDATE hmmer_hmmerdb
SET title = regexp_replace(title,'^.*\/','')
where title like '/%';

\o 
SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount 
FROM pg_stat_all_tables 
WHERE schemaname in ('public','training') AND relname NOT LIKE 'pg%' AND relname NOT LIKE 'sql%' order by schemaname, relname ASC;

\c django
SELECT schemaname,relname, n_tup_ins - n_tup_del as rowcount 
FROM pg_stat_all_tables 
WHERE schemaname in ('public','training') AND relname NOT LIKE 'pg%' AND relname NOT LIKE 'sql%' order by schemaname, relname ASC;

-- UPDATE
--     app_organism ao
-- SET
--     train_id = ao.id
-- WHERE
--     ao.train_id is NULL;


-- UPDATE hmmer_hmmerdb
-- SET title = regexp_replace(title,'^.*\/','')
-- where title like '/%';
