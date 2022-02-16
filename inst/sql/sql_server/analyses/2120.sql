-- 2120	Number of device_exposure records by start month
 
--HINT DISTRIBUTE_ON_KEY(stratum_1)
WITH rawData AS (
  select
    YEAR(ce1.device_exposure_start_date)*100 + month(ce1.device_exposure_start_date) as stratum_1,
    COUNT_BIG(ce1.PERSON_ID) as count_value
  from
  @cdmDatabaseSchema.device_exposure ce1 inner join 
  @cdmDatabaseSchema.observation_period op on ce1.person_id = op.person_id
  -- only include events that occur during observation period
  where ce1.device_exposure_start_date <= op.observation_period_end_date and
  ce1.device_exposure_start_date >= op.observation_period_start_date
  
  group by YEAR(ce1.device_exposure_start_date)*100 + month(ce1.device_exposure_start_date)
)
SELECT
  2120 as analysis_id,
  CAST(stratum_1 AS VARCHAR(255)) as stratum_1,
  cast(null as varchar(255)) as stratum_2,
  cast(null as varchar(255)) as stratum_3,
  cast(null as varchar(255)) as stratum_4,
  cast(null as varchar(255)) as stratum_5,
  count_value,
  count_value as raw_count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_2120
FROM rawData;