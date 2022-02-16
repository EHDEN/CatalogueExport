-- 800	Number of persons with at least one observation occurrence, by observation_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 800 as analysis_id, 
	CAST(o1.observation_CONCEPT_ID AS VARCHAR(255)) as stratum_1,
	cast(null as varchar(255)) as stratum_2,
	cast(null as varchar(255)) as stratum_3, 
	cast(null as varchar(255)) as stratum_4, 
	cast(null as varchar(255)) as stratum_5,
	floor((count_big(distinct o1.PERSON_ID)+99)/100)*100 as count_value,
count_big(distinct o1.PERSON_ID) as raw_count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_800
from
	@cdmDatabaseSchema.observation o1
group by o1.observation_CONCEPT_ID
;
