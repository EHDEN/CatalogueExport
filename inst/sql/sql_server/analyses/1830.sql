-- 830	Number of descendant measurement occurrence records,by procedure_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)

WITH CTE_procedure AS (
	SELECT ca.ancestor_concept_id AS concept_id, COUNT_BIG(*)
 AS DRC
	FROM @cdmDatabaseSchema.measurement co
		JOIN @cdmDatabaseSchema.concept_ancestor ca
			ON ca.descendant_concept_id = co.measurement_concept_id
	GROUP BY ca.ancestor_concept_id
)
SELECT  1830 as analysis_id,
  CAST(co.measurement_concept_id AS VARCHAR(255)) AS stratum_1,
  cast(null as varchar(255)) AS stratum_2,
  cast(null as varchar(255)) as stratum_3,
  cast(null as varchar(255)) as stratum_4,
  cast(null as varchar(255)) as stratum_5,
  floor((c.DRC+99)/100)*100 as count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_1830
FROM @cdmDatabaseSchema.measurement co
	JOIN CTE_procedure c
		ON c.concept_id = co.measurement_concept_id
GROUP BY co.measurement_concept_id, c.DRC
;
