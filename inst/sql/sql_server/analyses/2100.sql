-- 2100	Number of persons with at least one device exposure , by device_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 2100 as analysis_id, 
  CAST(m.device_CONCEPT_ID AS VARCHAR(255)) as stratum_1,
	cast(null as varchar(255)) as stratum_2,
	cast(null as varchar(255)) as stratum_3,
	cast(null as varchar(255)) as stratum_4,
	cast(null as varchar(255)) as stratum_5,
	floor((count_big(distinct m.PERSON_ID)+99)/100)*100 as count_value,
count_big(distinct m.PERSON_ID) as raw_count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_2100
from
	@cdmDatabaseSchema.device_exposure m
group by m.device_CONCEPT_ID
;
