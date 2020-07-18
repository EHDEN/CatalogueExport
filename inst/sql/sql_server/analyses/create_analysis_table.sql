IF OBJECT_ID('@resultsDatabaseSchema.catalogue_analysis', 'U') IS NOT NULL
  drop table @resultsDatabaseSchema.catalogue_analysis;

with cte_analyses
as
(
  @analysesSqls
)
select 
  analysis_id,
	analysis_name,
	stratum_1_name,
	stratum_2_name,
	stratum_3_name,
	stratum_4_name,
	stratum_5_name
into @resultsDatabaseSchema.catalogue_analysis
from cte_analyses;