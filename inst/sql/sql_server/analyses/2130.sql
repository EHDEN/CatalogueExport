-- 2130	Number of descendant device exposure records,by device_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)

WITH CTE_procedure AS (
	SELECT ca.ancestor_concept_id AS concept_id, COUNT_BIG(*)
 AS DRC
	FROM @cdmDatabaseSchema.device_exposure co
		JOIN @vocabDatabaseSchema.concept_ancestor ca
			ON ca.descendant_concept_id = co.device_concept_id
	GROUP BY ca.ancestor_concept_id
)
SELECT  2130 as analysis_id,
  CAST(co.device_concept_id AS VARCHAR(255)) AS stratum_1,
  cast(null as varchar(255)) AS stratum_2,
  cast(null as varchar(255)) as stratum_3,
  cast(null as varchar(255)) as stratum_4,
  cast(null as varchar(255)) as stratum_5,
  floor((c.DRC+99)/100)*100 as count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_2130
FROM @cdmDatabaseSchema.device_exposure co
	JOIN CTE_procedure c
		ON c.concept_id = co.device_concept_id
GROUP BY co.device_concept_id, c.DRC
;
