CREATE VIEW production.blast AS
SELECT b.organism_id, -- trim(concat(o.genus,' ',o.species,' ',o.infraspecies)) as organism, 
       CASE 
            WHEN s.molecule_type = 'nucl' THEN 'Nucleotide'
            ELSE 'Peptide'
       END as molecule_type,
       s.dataset_type,
       regexp_replace(lower(s.dataset_type),' ','-') as group,
       b.database_id,
       concat(s.dataset_type,' - ',d.description) as description
FROM production.blastdbs b
LEFT JOIN organisms o ON b.organism_id = o.id
LEFT JOIN databases d  ON b.database_id = d.id
JOIN sequencetypes s ON d.sequencetype_id = s.id
WHERE o.is_shown = True AND b.is_shown = True AND d.is_shown = True
ORDER BY organism,molecule_type, description ASC;




SELECT
    jsonb_object_agg(organism,organism_id) 
FROM production.blast
ORDER BY organism ASC;

SELECT json_build_object(
    'organisms',json_object_agg( DISTINCT organism,organism_id),
    'databases',json_object_agg( DISTINCT molecule_type,array_agg(DISTINCT description))
)
FROM production.blast;

SELECT json_build_object(
    'databases',json_build_object( DISTINCT jsonb_build_object(
        id,jsonb_build_object(
            'organism',organism,
            'organism_id',organism_id,
            'molecule_type',molecule_type,
            'group',group,
            'description',description
        )
)FROM production.blast;

SELECT json_build_object(
    'molecule_types',json_object_agg( DISTINCT molecule_type, json_build_object(
        'description',  description
)
FROM production.blast;


SELECT json_build_object(
    organism_id,json_object_build( DISTINCT molecule_type, json_agg(DISTINCT description)
)
FROM production.blast GROUP BY organism_id  WHERE organism_id = 59 ;

SELECT organism_id, json_build_object( molecule_type, json_agg(DISTINCT description))
FROM production.blast WHERE organism_id = 59  GROUP BY organism_id  ;



SELECT organism_id,molecule_type,
       json_agg(json_build_object('id',database_id,'label',description)) as db
FROM production.blast WHERE organism_id = 59  
GROUP BY organism_id,molecule_type
ORDER BY organism_id  ;

SELECT organism_id,json_object_agg(molecule_type,
       json_agg(json_build_object('id',database_id,'label',description))) as db
FROM production.blast WHERE organism_id = 59
GROUP BY organism_id,molecule_type
ORDER BY organism_id  ;

 SELECT organism_id,json_object_agg(molecule_type,1) as db
FROM production.blast WHERE organism_id = 59
GROUP BY organism_id,molecule_type
ORDER BY organism_id  ;




SELECT json_build_object(
    organism_id, json_build_object(molecule_type, json_agg(json_build_object(
        'id', database_id, 'label', concat(dataset_type, ' - ', description)
    )))
)
FROM production.blast
WHERE
    organism_id = 59
-- Grouping by molecule_type ensures that the aggregation is performed for each molecule type.
-- Ordering by molecule_type ensures the results are sorted in a predictable manner.
GROUP BY molecule_type ORDER BY molecule_type;
