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
  tryCatch({
    # Obtain the data from the results tables
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
    readr::write_csv(results, file.path(exportFolder, paste0("catalogue_results-",Sys.Date(),".csv"))) },
  error = function (e) {
    ParallelLogger::logError(paste0("Export query was not executed successfully"))
  }, finally = {
    DatabaseConnector::disconnect(connection = connection)
    rm(connection)
  })
  
}