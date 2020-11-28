-- 1801	Number of measurement occurrence records, by measurement_concept_id

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 1801 as analysis_id, 
	CAST(m.measurement_concept_id AS VARCHAR(255)) as stratum_1,
	CASE
        WHEN COUNT_BIG(m.PERSON_ID)<=10 THEN cast('<=10' as varchar(255))
        WHEN COUNT_BIG(m.PERSON_ID)<=100 THEN cast('11-10ˆ2' as varchar(255))
        WHEN COUNT_BIG(m.PERSON_ID)<=1000 THEN cast('10ˆ2-10ˆ3' as varchar(255))
        WHEN COUNT_BIG(m.PERSON_ID)<=10000 THEN cast('10ˆ3-10ˆ4' as varchar(255))
        WHEN COUNT_BIG(m.PERSON_ID)<=100000 THEN cast('10ˆ4-10ˆ5' as varchar(255))
        WHEN COUNT_BIG(m.PERSON_ID)<=1000000 THEN cast('10ˆ5-10ˆ6' as varchar(255))
        ELSE cast('>10ˆ6' as varchar(255))
    END as stratum_2,
	cast(null as varchar(255)) as stratum_3, cast(null as varchar(255)) as stratum_4, cast(null as varchar(255)) as stratum_5,
	cast(9999999 as bigint) as count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_1801
from
	@cdmDatabaseSchema.measurement m
group by m.measurement_CONCEPT_ID
;
