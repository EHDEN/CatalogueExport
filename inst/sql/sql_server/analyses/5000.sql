-- 5000	cdm name, cdm release date, cdm_version, vocabulary_version

--HINT DISTRIBUTE_ON_KEY(stratum_1)
select 5000 as analysis_id,  CAST('@source_name' AS VARCHAR(255)) as stratum_1, 
source_release_date as stratum_2, 
cdm_release_date as stratum_3, 
cdm_version as stratum_4,
vocabulary_version as stratum_5, 
9999 as count_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_5000
from @cdmDatabaseSchema.cdm_source;

-- HINT DISTRIBUTE_ON_KEY(stratum_1)
--select 5000 as analysis_id, CAST('@source_name' AS VARCHAR(255)) as stratum_1, 
--cast(null as varchar(255)) as stratum_2, cast(null as varchar(255)) as stratum_3, cast(null as varchar(255)) as stratum_4, cast(null as varchar(255)) as stratum_5,
--9999 as count_value, 
--  cast(null as float) as min_value,
--	cast(null as float) as max_value,
--	cast(null as float) as avg_value,
--	cast(null as float) as stdev_value,
--	cast(null as float) as median_value,
--	cast(null as float) as p10_value,
--	cast(null as float) as p25_value,
--	cast(null as float) as p75_value,
--	cast(null as float) as p90_value
--into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_dist_5000
-- from @cdmDatabaseSchema.person;
