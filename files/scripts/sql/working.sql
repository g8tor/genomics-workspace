----------------------------IGNORE----------------------------
SELECT
        json_build_object(
                data.organism_id::TEXT,
                jsonb_object_agg(data.molecule_type, data.db_data)
        ) AS dbs_by_type
FROM (
  SELECT
    p.organism_id,
    p.molecule_type,
    json_agg(
      jsonb_build_object(
        'id', p.database_id,
        'label', p.description
      )
    ) AS db_data
  FROM production.blast AS p
  WHERE p.organism_id = 59
  GROUP BY p.organism_id,p.molecule_type
  ORDER BY p.organism_id DESC
) AS data GROUP BY data.organism_id; 
-------------------------------------------------------------
WITH counts as (
SELECT  molecule_type, jsonb_build_object(
                   'id', concat('id-',lower(regexp_replace(dataset_type,' ','-'))),
                   'database-type', lower(regexp_replace(dataset_type,' ','-')),
                   'label',concat(dataset_type,' - ',count(database_id),' databases'),
                   'organism', 'all-organism',
                   'value',concat('all-',lower(regexp_replace(dataset_type,' ','-')))
                ) as data from production.blast GROUP BY molecule_type,dataset_type ORDER BY molecule_type,dataset_type ASC
),tmp AS ( 
  select molecule_type,json_agg(data) as stats from counts group by molecule_type
),tmp_db_data AS (
  SELECT
  o.organism_id,
  jsonb_object_agg(
    o.molecule_type,
    (
      SELECT json_agg(
        jsonb_build_object(
          'id', i.database_id,
          'label', i.description
        )
      )
      FROM production.blast AS i
      WHERE i.organism_id = o.organism_id
      AND i.molecule_type = o.molecule_type
    )
  ) as rec
FROM production.blast AS o
GROUP BY o.organism_id
)
SELECT json_build_object(
        'counts', (
          SELECT json_object_agg(molecule_type,stats)
          FROM tmp
        ),
        'organisms',(
          SELECT json_object_agg( DISTINCT organism,organism_id)
          FROM production.blast AS ORGS
        ),
        'databases',( 
          SELECT json_object_agg(organism_id,rec)
          FROM tmp_db_data
        ) 
)
----------------------------IGNORE----------------------------

SELECT organism_id , 
FROM production.blast as b
ORDER BY organism_id ASC


 SELECT json_build_object(
        'organisms',(
                SELECT json_object_agg( DISTINCT organism,organism_id)
                FROM production.blast AS ORGS)
)
;

WITH counts as (
SELECT  molecule_type, jsonb_build_object(
                   'id', concat('id-',lower(regexp_replace(dataset_type,' ','-'))),
                   'database-type', lower(regexp_replace(dataset_type,' ','-')),
                   'label',concat(dataset_type,' - ',count(database_id),' databases'),
                   'organism', 'all-organism',
                   'value',concat('all-',lower(regexp_replace(dataset_type,' ','-')))
                ) as data from production.blast GROUP BY molecule_type,dataset_type ORDER BY molecule_type,dataset_type ASC
)  
SELECT json_build_object(
        'counts', (
          json_object_agg(molecule_type,data) from counts
        )
        
)


CREATE OR REPLACE VIEW production.blast_stats AS    
WITH counts as (
SELECT  molecule_type, jsonb_build_object(
                   'id', concat('id-',lower(regexp_replace(dataset_type,' ','-'))),
                   'database-type', lower(regexp_replace(dataset_type,' ','-')),
                   'label',concat(dataset_type,' - ',count(database_id),' databases'),
                   'organism', 'all-organism',
                   'value',concat('all-',lower(regexp_replace(dataset_type,' ','-')))
                ) as data from production.blast GROUP BY molecule_type,dataset_type ORDER BY molecule_type,dataset_type ASC
),tmp AS ( 
  select molecule_type,json_agg(data) as stats from counts group by molecule_type
)
SELECT json_build_object(
        'counts', (
          select json_object_agg(molecule_type,stats) from tmp
        ),
        'organisms',(
                SELECT json_object_agg( DISTINCT organism,organism_id)
                FROM production.blast AS ORGS
        ) 
)


WITH tmp_dbs AS (
  SELECT  organism_id, molecule_type, 
          json_agg(json_build_object('id',database_id,'label',description)) as db
  FROM production.blast
  WHERE organism_id IN (59,1)
  GROUP BY organism_id,molecule_type ORDER BY organism_id ASC
) select organism_id,jsonb_object_agg(molecule_type,db) from tmp_dbs; 


SELECT o.organism_id,o.molecule_type,(
  json_agg((
    select json_build_object('id',database_id,'labe;',description)
    FROM production.blast as i 
    WHERE i.organism_id = o.organism_id 
    AND i.molecule_type = o.molecule_type
    GROUP BY i.organismism_id,i.molecule_type
))) as db from production.blast WHERE organism_id = 59 GROUP BY organism_id,molecule_type;




CREATE OR REPLACE VIEW production.blast_ui AS(
WITH tmp_db_data AS (
  SELECT 
  o.organism_id,
  jsonb_object_agg(
    o.molecule_type,
    (
      SELECT json_agg(
        jsonb_build_object(
          'id', i.database_id,
          'label', i.description
        )
      )
      FROM production.blast AS i
      WHERE i.organism_id = o.organism_id
      AND i.molecule_type = o.molecule_type
    )
  ) as rec
FROM production.blast AS o
WHERE o.organism_id in (1,2,59)
GROUP BY o.organism_id
)
select json_build_object(
  'databases',( 
    SELECT json_object_agg(organism_id,rec)
    FROM tmp_db_data
  )
)


SELECT json_build_object(
  'databases',
  json_object_agg(
    organism_id,
    rec
  )
) FROM tmp_db_data;


select json_build_object(
  'databases',( 
    SELECT json_object_agg(organism_id,rec)
    FROM tmp_db_data
  )
) FROM tmp_db_data;



---------------------------------------------------------------
WITH counts as (
SELECT  molecule_type, jsonb_build_object(
                   'id', concat('id-',lower(regexp_replace(dataset_type,' ','-'))),
                   'database-type', lower(regexp_replace(dataset_type,' ','-')),
                   'label',concat(dataset_type,' - ',count(database_id),' databases'),
                   'organism', 'all-organism',
                   'value',concat('all-',lower(regexp_replace(dataset_type,' ','-')))
                ) as data from production.blast GROUP BY molecule_type,dataset_type ORDER BY molecule_type,dataset_type ASC
),tmp AS ( 
  select molecule_type,json_agg(data) as stats from counts group by molecule_type
),tmp_db_data AS (
  SELECT
  o.organism_id,
  jsonb_object_agg(
    o.molecule_type,
    (
      SELECT json_agg(
        jsonb_build_object(
          'id', i.database_id,
          'label', i.description
        )
      )
      FROM production.blast AS i
      WHERE i.organism_id = o.organism_id
      AND i.molecule_type = o.molecule_type
    )
  ) as rec
FROM production.blast AS o
GROUP BY o.organism_id
)
SELECT json_build_object(
        'counts', (
          SELECT json_object_agg(molecule_type,stats)
          FROM tmp
        ),
        'organisms',(
          SELECT json_object_agg( DISTINCT organism,organism_id)
          FROM production.blast AS ORGS
        ),
        'databases',( 
          SELECT json_object_agg(organism_id,rec)
          FROM tmp_db_data
        ) 
)