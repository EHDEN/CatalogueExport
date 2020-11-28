-- 201	Number of visit occurrence records, by visit_concept_id
-- restricted to visits overlapping with observation period

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 201 as analysis_id, 
	CAST(vo1.visit_concept_id AS VARCHAR(255)) as stratum_1,
	CASE
        WHEN COUNT_BIG(vo1.PERSON_ID)<=10 THEN cast('<=10' as varchar(255))
        WHEN COUNT_BIG(vo1.PERSON_ID)<=100 THEN cast('11-10ˆ2' as varchar(255))
        WHEN COUNT_BIG(vo1.PERSON_ID)<=1000 THEN cast('10ˆ2-10ˆ3' as varchar(255))
        WHEN COUNT_BIG(vo1.PERSON_ID)<=10000 THEN cast('10ˆ3-10ˆ4' as varchar(255))
        WHEN COUNT_BIG(vo1.PERSON_ID)<=100000 THEN cast('10ˆ4-10ˆ5' as varchar(255))
        WHEN COUNT_BIG(vo1.PERSON_ID)<=1000000 THEN cast('10ˆ5-10ˆ6' as varchar(255))
        ELSE cast('>10ˆ6' as varchar(255))
    END as stratum_2,
	cast(null as varchar(255)) as stratum_3, cast(null as varchar(255)) as stratum_4, cast(null as varchar(255)) as stratum_5,
	cast(9999999as bigint) as count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_201
from
	@cdmDatabaseSchema.visit_occurrence vo1 inner join 
  @cdmDatabaseSchema.observation_period op on vo1.person_id = op.person_id
  -- only include events that occur during observation period
  where vo1.visit_start_date <= op.observation_period_end_date and
  isnull(vo1.visit_end_date,vo1.visit_start_date) >= op.observation_period_start_date
group by vo1.visit_concept_id
;
