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
            AND c.relname != 'app_organism'
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


SET client_min_messages TO ERROR;
----------------------------------------------------------
-- Create and populate the fastafiles table
----------------------------------------------------------
CREATE TABLE fastafiles (
  checksum VARCHAR(200) NOT NULL,
  file_name VARCHAR(300) NOT NULL,
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

BEGIN;
ALTER TABLE blast_jbrowsesetting
DROP CONSTRAINT IF EXISTS "blast_jbrowsesetting_blast_db_id_583d9543_fk_blast_blastdb_id",
DROP CONSTRAINT IF EXISTS "blast_jbrowses_blast_db_id_704033e7148f2da8_fk_blast_blastdb_id",
DROP CONSTRAINT IF EXISTS "blast_db_id",
ADD CONSTRAINT "blast_db_id"
  FOREIGN KEY ("blast_db_id")
  REFERENCES "blast_blastdb"(id)
  ON DELETE CASCADE;

ALTER TABLE blast_blastdb
DROP CONSTRAINT IF EXISTS "blast_blastdb_organism_id_656c41fd_fk_app_organism_id",
DROP CONSTRAINT IF EXISTS "blast_blastdb_type_id_23b0ab37204b0e84_fk_blast_sequencetype_id",
DROP CONSTRAINT IF EXISTS "blast_blastdb_type_id_fkey",
DROP CONSTRAINT IF EXISTS "app_organism_id",
ADD CONSTRAINT "app_organism_id"
  FOREIGN KEY ("organism_id")
  REFERENCES "app_organism"(id)
  ON DELETE CASCADE;


ALTER TABLE hmmer_hmmerdb
DROP CONSTRAINT IF EXISTS "hmmer_hmmerdb_organism_id_5d59d15b_fk_app_organism_id";

DELETE FROM blast_blastdb  WHERE is_shown = False;
DELETE FROM hmmer_hmmerdb  WHERE is_shown = False OR id in (125,225);
DELETE FROM app_organism WHERE id = 43;

UPDATE blast_blastdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/',''));
UPDATE blast_blastdb SET title = regexp_replace(title,'^.*\/','') WHERE title like '/%';
UPDATE blast_blastdb SET description = trim(description);

UPDATE hmmer_hmmerdb set fasta_file = trim(regexp_replace(fasta_file,'^.*\/',''));
UPDATE hmmer_hmmerdb SET title = regexp_replace(title,'^.*\/','') WHERE title like '/%';
UPDATE hmmer_hmmerdb SET description = trim(description);

ALTER TABLE blast_blastdb 
ADD COLUMN database_id INTEGER,
ADD COLUMN fastafile_id INTEGER,
ADD COLUMN checksum VARCHAR(200),
ADD COLUMN url VARCHAR(200);
ALTER TABLE blast_blastdb RENAME COLUMN  type_id TO sequencetype_id;
ALTER TABLE blast_blastdb RENAME COLUMN  fasta_file TO file_name;

ALTER TABLE hmmer_hmmerdb
ADD COLUMN database_id INTEGER,
ADD COLUMN fastafile_id INTEGER,
ADD COLUMN checksum VARCHAR(200);
ALTER TABLE hmmer_hmmerdb RENAME COLUMN  fasta_file TO file_name;

MERGE INTO blast_blastdb b
USING blast_jbrowsesetting j
ON b.id = j.blast_db_id
WHEN MATCHED THEN
    UPDATE SET url = j.url;

COMMIT;


MERGE INTO blast_blastdb b
USING fastafiles f
ON b.file_name = f.file_name
WHEN MATCHED THEN
    UPDATE SET checksum = f.checksum;

MERGE INTO hmmer_hmmerdb b
USING fastafiles f
ON b.file_name = f.file_name
WHEN MATCHED THEN
    UPDATE SET checksum = f.checksum;

ALTER TABLE blast_blastdb
ALTER COLUMN checksum SET NOT NULL,
DROP CONSTRAINT IF EXISTS "app_organism_id",
DROP COLUMN title,
DROP COLUMN is_shown;

ALTER TABLE hmmer_hmmerdb
ALTER COLUMN checksum SET NOT NULL,
DROP COLUMN title,
DROP COLUMN is_shown;

-- -- Update *.organism tables
UPDATE app_organism set short_name = lower(short_name);

ALTER TABLE app_organism 
DROP COLUMN IF EXISTS description,
ADD COLUMN IF NOT EXISTS organism_id INTEGER UNIQUE;

DROP TABLE fastafiles;
DROP TABLE blast_jbrowsesetting;
-- DROP TABLE app_organism;
DROP TABLE blast_sequencetype;

-- ALTER TABLE blast_blastdb DROP COLUMN file_name;
-- ALTER TABLE hmmer_hmmerdb DROP COLUMN file_name;
SELECT * FROM get_all_table_row_counts();

