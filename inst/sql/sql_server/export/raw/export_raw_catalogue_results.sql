-- combine all results
SELECT analysis_id, stratum_1, stratum_2, stratum_3, stratum_4, stratum_5, count_value,
        cast(null as float) min_value,
        cast(null as float) max_value,
        cast(null as float) avg_value,
        cast(null as float) stdev_value,
        cast(null as float) median_value,
        cast(null as float) p10_value,
        cast(null as float) p25_value,
        cast(null as float) P75_value,
        cast(null as float) p90_value
FROM  @results_database_schema.catalogue_results
WHERE count_value > @min_cell_count
{@analysis_ids != ''} ? {AND analysis_id IN (@analysis_ids)}

UNION

select * from @results_database_schema.catalogue_results_dist
WHERE count_value > @min_cell_count
{@analysis_ids != ''} ? {AND analysis_id IN (@analysis_ids)}
ORDER BY analysis_id ASC
;