#' The main CatalogueExport analyses (for v5.x)
#'
#' @description
#' \code{exportResults} exports the results to a csv file for upload to the Catalogue
#' @param connectionDetails       An R object of type \code{connectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package.
#' @param resultsDatabaseSchema   Fully qualified name of database schema that we can write final results to. Default is cdmDatabaseSchema. 
#'                                On SQL Server, this should specifiy both the database and the schema, so for example, on SQL Server, 'cdm_results.dbo'.
#' @param analysisIds             A vector containing the set of CatalogueExport analysisIds for which results will be generated. 
#' @param smallCellCount          To avoid patient identifiability, cells with small counts (<= smallCellCount) are deleted. Set to NULL if you don't want any deletions.
#' @param exportFolder            Folder to export the results to.
#'
#' @export
exportResultsToCSV <- function(connectionDetails,
                               resultsDatabaseSchema,
                               analysisIds = c(),
                               smallCellCount = 5,
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
                                             min_cell_count = smallCellCount,
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