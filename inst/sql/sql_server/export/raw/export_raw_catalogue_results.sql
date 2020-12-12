-- combine all results
SELECT analysis_id, stratum_1, stratum_2, stratum_3, stratum_4, stratum_5, count_value,
       min_value = NULL,
       max_value = NULL,
       avg_value = NULL,
       stdev_value = NULL,
       median_value = NULL,
       p10_value = NULL,
       p25_value = NULL,
       P75_value = NULL,
       p90_value = NULL
FROM  @results_database_schema.catalogue_results
WHERE count_value > @min_cell_count
{@analysis_ids != ''} ? {AND analysis_id IN (@analysis_ids)}

UNION

select * from @results_database_schema.catalogue_results_dist
WHERE count_value > @min_cell_count
{@analysis_ids != ''} ? {AND analysis_id IN (@analysis_ids)}
;