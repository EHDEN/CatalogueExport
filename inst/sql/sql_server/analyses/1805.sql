-- 1805	Number of measurement records, by measurement_concept_id by measurement_type_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 1805 as analysis_id, 
	CAST(m.measurement_concept_id AS VARCHAR(255)) as stratum_1,
	CAST(m.measurement_type_concept_id AS VARCHAR(255)) as stratum_2,
	cast(null as varchar(255)) as stratum_3,
	cast(null as varchar(255)) as stratum_4,
	cast(null as varchar(255)) as stratum_5,
	floor((count_big(m.PERSON_ID)+99)/100)*100 as count_value,
count_big(m.PERSON_ID) as raw_count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_1805
from @cdmDatabaseSchema.measurement m
group by m.measurement_concept_id,	
	m.measurement_type_concept_id
;
