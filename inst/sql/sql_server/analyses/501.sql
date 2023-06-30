-- 501	Number of records of death, by cause_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 501 as analysis_id, 
	CAST(d1.cause_concept_id AS VARCHAR(255)) as stratum_1,
	cast(null as varchar(255)) as stratum_2,
	cast(null as varchar(255)) as stratum_3,
	cast(null as varchar(255)) as stratum_4,
	cast(null as varchar(255)) as stratum_5,
	floor((count_big(d1.PERSON_ID)+99)/100)*100 as count_value,
    count_big(d1.PERSON_ID) as raw_count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_501
from
	@cdmDatabaseSchema.death d1
group by d1.cause_concept_id
;
