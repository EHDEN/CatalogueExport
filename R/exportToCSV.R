#' @export
exportResultsToCSV <- function(connectionDetails,
                               resultsDatabaseSchema,
                               analysisIds = c(),
                               minCellCount = 5,
                               exportFolder ="./output") {
  # Ensure the export folder exists
  if (!file.exists(exportFolder)) {
    dir.create(exportFolder, recursive = TRUE)
  }
  
  # Connect to the database
  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))
  
  # Obtain the data from the achilles tables
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "export/raw/export_raw_catalogue_results.sql", 
                                           packageName = "CatalogueExport", 
                                           dbms = connectionDetails$dbms,
                                           warnOnMissingParameters = FALSE,
                                           results_database_schema = resultsDatabaseSchema,
                                           min_cell_count = minCellCount,
                                           analysis_ids = analysisIds)
  ParallelLogger::logInfo("Querying catalogue_results")
  results <- DatabaseConnector::querySql(connection = connection, sql = sql)
  
  # Save the data to the export folder
  readr::write_csv(results, file.path(exportFolder, "catalogue_results.csv"))
}