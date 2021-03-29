# @file CatalogueExport
#
# Copyright 2020 European Health Data and Evidence Network (EHDEN)
#
# This file is part of CatalogueExport and is based on OHDSI's Achilles
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @author European Health Data and Evidence Network
# @author Peter Rijnbeek


#' The main CatalogueExport analyses (for v5.x)
#'
#' @description
#' \code{CatalogueExport} exports a set of  descriptive statistics summary from the CDM, to be uploaded in the Database Catalogue.
#'
#' @details
#' \code{CatalogueExport} exports a set of  descriptive statistics summary from the CDM, to be uploaded in the Database Catalogue.
#' 
#' @param connectionDetails                An R object of type \code{connectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package.
#' @param cdmDatabaseSchema    	           Fully qualified name of database schema that contains OMOP CDM schema.
#'                                         On SQL Server, this should specifiy both the database and the schema, so for example, on SQL Server, 'cdm_instance.dbo'.
#' @param resultsDatabaseSchema		         Fully qualified name of database schema that we can write final results to. Default is cdmDatabaseSchema. 
#'                                         On SQL Server, this should specifiy both the database and the schema, so for example, on SQL Server, 'cdm_results.dbo'.
#' @param scratchDatabaseSchema            Fully qualified name of the database schema that will store all of the intermediate scratch tables, so for example, on SQL Server, 'cdm_scratch.dbo'. 
#'                                         Must be accessible to/from the cdmDatabaseSchema and the resultsDatabaseSchema. Default is resultsDatabaseSchema. 
#'                                         Making this "#" will run CatalogueExport in single-threaded mode and use temporary tables instead of permanent tables.
#' @param vocabDatabaseSchema		           String name of database schema that contains OMOP Vocabulary. Default is cdmDatabaseSchema. On SQL Server, this should specifiy both the database and the schema, so for example 'results.dbo'.
#' @param oracleTempSchema                 For Oracle only: the name of the database schema where you want all temporary tables to be managed. Requires create/insert permissions to this database. 
#' @param sourceName		                   String name of the data source name. If blank, CDM_SOURCE table will be queried to try to obtain this.
#' @param analysisIds		                   (OPTIONAL) A vector containing the set of CatalogueExport analysisIds for which results will be generated. 
#'                                         If not specified, all analyses will be executed. Use \code{\link{getAnalysisDetails}} to get a list of all CatalogueExport analyses and their Ids.
#' @param createTable                      If true, new results tables will be created in the results schema. If not, the tables are assumed to already exist, and analysis results will be inserted (slower on MPP).
#' @param smallCellCount                   To avoid patient identifiability, cells with small counts (<= smallCellCount) are deleted. Set to NULL if you don't want any deletions.
#' @param cdmVersion                       Define the OMOP CDM version used:  currently supports v5 and above. Use major release number or minor number only (e.g. 5, 5.3)
#' @param createIndices                    Boolean to determine if indices should be created on the resulting CatalogueExport tables. Default= TRUE
#' @param numThreads                       (OPTIONAL, multi-threaded mode) The number of threads to use to run CatalogueExport in parallel. Default is 1 thread.
#' @param tempPrefix               (OPTIONAL, multi-threaded mode) The prefix to use for the scratch CatalogueExport analyses tables. Default is "tmpach"
#' @param dropScratchTables                (OPTIONAL, multi-threaded mode) TRUE = drop the scratch tables (may take time depending on dbms), FALSE = leave them in place for later removal.
#' @param sqlOnly                          Boolean to determine if CatalogueExport should be fully executed. TRUE = just generate SQL files, don't actually run, FALSE = run CatalogueExport
#' @param outputFolder                     Path to store logs and SQL files
#' @param verboseMode                      Boolean to determine if the console will show all execution steps. Default = TRUE
#' @return                                 An object of type \code{catalogueResults} containing details for connecting to the database containing the results 
#' @examples                               
#' \dontrun{
#' connectionDetails <- createConnectionDetails(dbms="sql server", server="some_server")
#' results <- achilles(connectionDetails = connectionDetails, 
#'                     cdmDatabaseSchema = "cdm", 
#'                     resultsDatabaseSchema="results", 
#'                     scratchDatabaseSchema="scratch",
#'                     sourceName="Some Source", 
#'                     cdmVersion = "5.3", 
#'                     numThreads = 10,
#'                     outputFolder = "output")
#' }
#' @export
catalogueExport <- function (connectionDetails, 
                      cdmDatabaseSchema,
                      resultsDatabaseSchema = cdmDatabaseSchema, 
                      scratchDatabaseSchema = resultsDatabaseSchema,
                      vocabDatabaseSchema = cdmDatabaseSchema,
                      oracleTempSchema = resultsDatabaseSchema,
                      sourceName = "", 
                      analysisIds = "", 
                      createTable = TRUE,
                      smallCellCount = 5, 
                      cdmVersion = "5", 
                      createIndices = TRUE,
                      numThreads = 1,
                      tempPrefix = "tmpach",
                      dropScratchTables = TRUE,
                      sqlOnly = FALSE,
                      outputFolder = "output",
                      verboseMode = TRUE) {
  
  achillesSql <- c()
  catalogueSql <- c()
  
  dir.create(file.path(outputFolder), showWarnings = FALSE)
  
  startTime <- Sys.time()
  
  # Log execution -----------------------------------------------------------------------------------------------------------------
  ParallelLogger::clearLoggers()
  unlink(file.path(outputFolder, "log_catalogueExport.txt"))
  
  if (verboseMode) {
    appenders <- list(ParallelLogger::createConsoleAppender(),
                      ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_catalogueExport.txt")))    
  } else {
    appenders <- list(ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_catalogueExport.txt")))
  }
  
  logger <- ParallelLogger::createLogger(name = "catalogueExport",
                                         threshold = "INFO",
                                         appenders = appenders)
  ParallelLogger::registerLogger(logger) 
  
  # Try to get CDM Version if not provided ----------------------------------------------------------------------------------------
  
  if (missing(cdmVersion)) {
    cdmVersion <- .getCdmVersion(connectionDetails, cdmDatabaseSchema)
  }
  
  cdmVersion <- as.character(cdmVersion)
  
  # Check CDM version is valid ---------------------------------------------------------------------------------------------------
  
  if (compareVersion(a = as.character(cdmVersion), b = "5") < 0) {
    stop("Error: Invalid CDM Version number; this function is only for v5 and above. Check the cdm_source table!")
  }
  
  # Check the vocabulary version is available from cdm_source
  
  vocabularyVersion <- .getVocabularyVersion(connectionDetails, cdmDatabaseSchema)
  if (is.na(vocabularyVersion)) {
    stop("Error: The vocabulary version needs to be available in the cdm_source table")
  }
  
  
  # Establish folder paths --------------------------------------------------------------------------------------------------------
  
  if (!dir.exists(outputFolder)) {
    dir.create(path = outputFolder, recursive = TRUE)
  }
  
  # Get source name if none provided ----------------------------------------------------------------------------------------------
  
  if (missing(sourceName) & !sqlOnly) {
    sourceName <- .getSourceName(connectionDetails, cdmDatabaseSchema)
  }
  
  # Obtain analyses to run --------------------------------------------------------------------------------------------------------
  
  analysisDetails <- getAnalysisDetails()
  costIds <- analysisDetails$ANALYSIS_ID[analysisDetails$COST == 1]
  
  if (!missing(analysisIds)) {
    analysisDetails <- analysisDetails[analysisDetails$ANALYSIS_ID %in% analysisIds, ]
  }
  
  # Check if cohort table is present ---------------------------------------------------------------------------------------------
  
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  
  sql <- SqlRender::render("select top 1 cohort_definition_id from @resultsDatabaseSchema.cohort;", 
                           resultsDatabaseSchema = resultsDatabaseSchema)
  sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
  
  # cohortTableExists <- tryCatch({
  #   dummy <- DatabaseConnector::querySql(connection = connection, sql = sql, errorReportFile = "cohortTableNotExist.sql")
  #   TRUE
  # }, error = function(e) {
  #   unlink("cohortTableNotExist.sql")
  #   ParallelLogger::logWarn("Cohort table not found, will skip analyses 1700 and 1701")
  #   FALSE
  # })
  # DatabaseConnector::disconnect(connection = connection)
  # 
  # if (!cohortTableExists) {
  #   analysisDetails <- analysisDetails[!analysisDetails$ANALYSIS_ID %in% c(1700,1701),]
  # }
  
  if (cdmVersion < "5.3") { 
    analysisDetails <- analysisDetails[!analysisDetails$ANALYSIS_ID == 1425,]
  }
  
  resultsTables <- list(
    list(detailType = "results",
         tablePrefix = tempPrefix, 
         schema = read.csv(file = system.file("csv", "schemas", "schema_catalogue_results.csv", package = "CatalogueExport"), 
                           header = TRUE),
         analysisIds = analysisDetails[analysisDetails$DISTRIBUTION <= 0, ]$ANALYSIS_ID),
    list(detailType = "results_dist",
         tablePrefix = sprintf("%1s_%2s", tempPrefix, "dist"),
         schema = read.csv(file = system.file("csv", "schemas", "schema_catalogue_results_dist.csv", package = "CatalogueExport"), 
                           header = TRUE),
         analysisIds = analysisDetails[abs(analysisDetails$DISTRIBUTION) == 1, ]$ANALYSIS_ID))
  
  # Initialize thread and scratchDatabaseSchema settings and verify ParallelLogger installed ---------------------------
  
  schemaDelim <- "."
  
  if (numThreads == 1 || scratchDatabaseSchema == "#") {
    numThreads <- 1
    
  if (.supportsTempTables(connectionDetails)) {
     scratchDatabaseSchema <- "#"
     schemaDelim <- "s_"
  }
    
    ParallelLogger::logInfo("Beginning single-threaded execution")
    
    # first invocation of the connection, to persist throughout to maintain temp tables
    connection <- DatabaseConnector::connect(connectionDetails = connectionDetails) 
  } else if (!requireNamespace("ParallelLogger", quietly = TRUE)) {
    stop(
      "Multi-threading support requires package 'ParallelLogger'.",
      " Consider running single-threaded by setting",
      " `numThreads = 1` and `scratchDatabaseSchema = '#'`.",
      " You may install it using devtools with the following code:",
      "\n    devtools::install_github('OHDSI/ParallelLogger')",
      "\n\nAlternately, you might want to install ALL suggested packages using:",
      "\n    devtools::install_github('EHDEN/CatalogueExport', dependencies = TRUE)",
      call. = FALSE
    ) 
  } else {
    ParallelLogger::logInfo("Beginning multi-threaded execution")
  }
  
  # Check if createTable is FALSE and no analysisIds specified -----------------------------------------------------
  
  if (!createTable & missing(analysisIds)) {
    createTable <- TRUE
  }
  
  ## Remove existing results if createTable is FALSE ----------------------------------------------------------------
  
  if (!createTable) {
    .deleteExistingResults(connectionDetails = connectionDetails,
                           resultsDatabaseSchema = resultsDatabaseSchema,
                           analysisDetails = analysisDetails)  
  }
  
  # Create analysis table ------------------------------------------------------------- 
  
  if (createTable) {
    analysesSqls <- apply(analysisDetails, 1, function(analysisDetail) {  
      SqlRender::render("select @analysisId as analysis_id, '@analysisName' as analysis_name,
                           '@stratum1Name' as stratum_1_name, '@stratum2Name' as stratum_2_name,
                           '@stratum3Name' as stratum_3_name, '@stratum4Name' as stratum_4_name,
                           '@stratum5Name' as stratum_5_name", 
                        analysisId = analysisDetail["ANALYSIS_ID"],
                        analysisName = analysisDetail["ANALYSIS_NAME"],
                        stratum1Name = analysisDetail["STRATUM_1_NAME"],
                        stratum2Name = analysisDetail["STRATUM_2_NAME"],
                        stratum3Name = analysisDetail["STRATUM_3_NAME"],
                        stratum4Name = analysisDetail["STRATUM_4_NAME"],
                        stratum5Name = analysisDetail["STRATUM_5_NAME"])
    })  
    
    sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "analyses/create_analysis_table.sql", 
                                             packageName = "CatalogueExport", 
                                             dbms = connectionDetails$dbms,
                                             warnOnMissingParameters = FALSE,
                                             resultsDatabaseSchema = resultsDatabaseSchema,
                                             analysesSqls = paste(analysesSqls, collapse = " \nunion all\n "))
    
    achillesSql <- c(achillesSql, sql)
    
    if (!sqlOnly) {
      if (numThreads == 1) { 
        # connection is already alive
        DatabaseConnector::executeSql(connection = connection, sql = sql)
      } else {
        
        tryCatch({
          connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
          DatabaseConnector::executeSql(connection = connection, sql = sql, errorReportFile = file.path(outputFolder, "SqlError.txt"))
        },
        error = function (e) {
          ParallelLogger::logError(paste0("Query was not executed successfully, see ",file.path(outputFolder,"SqlError.txt")," for more details"))
        }, finally = {
          DatabaseConnector::disconnect(connection = connection)
          rm(connection)
        })
        
      }
    }
  }
  
  # Clean up existing scratch tables -----------------------------------------------
  
  if ((numThreads > 1 || !.supportsTempTables(connectionDetails)) && !sqlOnly) {
    # Drop the scratch tables
    ParallelLogger::logInfo(sprintf("Dropping scratch CatalogueExport tables from schema %s", scratchDatabaseSchema))
    
    dropAllScratchTables(connectionDetails = connectionDetails,
                         scratchDatabaseSchema = scratchDatabaseSchema,
                         tempPrefix = tempPrefix,
                         numThreads = numThreads,
                         tableTypes = c("catalogueExport"),
                         outputFolder = outputFolder)
    
    ParallelLogger::logInfo(sprintf("Temporary CatalogueExport tables removed from schema %s", scratchDatabaseSchema))
  }
  
 
  
  # Generate Main Analyses ----------------------------------------------------------------------------------------------------------------
  
  mainAnalysisIds <- analysisDetails$ANALYSIS_ID

  # Get the CatalogueExport Analysis
  mainSqls <- lapply(mainAnalysisIds, function(analysisId) {
    list(analysisId = analysisId,
         sql = .getAnalysisSql(analysisId = analysisId,
                               connectionDetails = connectionDetails,
                               schemaDelim = schemaDelim,
                               scratchDatabaseSchema = scratchDatabaseSchema,
                               cdmDatabaseSchema = cdmDatabaseSchema,
                               resultsDatabaseSchema = resultsDatabaseSchema,
                               vocabDatabaseSchema = vocabDatabaseSchema,
                               oracleTempSchema = oracleTempSchema,
                               cdmVersion = cdmVersion,
                               tempAchillesPrefix = tempPrefix,
                               resultsTables = resultsTables,
                               sourceName = sourceName,
                               numThreads = numThreads,
                               outputFolder = outputFolder)
    )
  })
  
  achillesSql <- c(achillesSql, lapply(mainSqls, function(s) s$sql))
  
  
  if (!sqlOnly) {
    ParallelLogger::logInfo("Executing multiple queries. This could take a while")
    
    if (numThreads == 1) {
      for (mainSql in mainSqls) {
        start <- Sys.time()
        ParallelLogger::logInfo(sprintf("Analysis %d (%s) -- START", mainSql$analysisId, 
                                        analysisDetails$ANALYSIS_NAME[analysisDetails$ANALYSIS_ID == mainSql$analysisId]))
        tryCatch({
          DatabaseConnector::executeSql(connection = connection, sql = mainSql$sql)
          delta <- Sys.time() - start
          ParallelLogger::logInfo(sprintf("[Main Analysis] [COMPLETE] %d (%f %s)", 
                                          as.integer(mainSql$analysisId), 
                                          delta, 
                                          attr(delta, "units")))  
        }, error = function(e) {
          ParallelLogger::logError(sprintf("[Main Analysis] [ERROR] %d (%s)", 
                                           as.integer(mainSql$analysisId), 
                                           e))
          DatabaseConnector::disconnect(connection)
          stop()
        })
      }
    } else {
      cluster <- ParallelLogger::makeCluster(numberOfThreads = numThreads, singleThreadToMain = TRUE)
      results <- ParallelLogger::clusterApply(cluster = cluster, 
                                              x = mainSqls, 
                                              function(mainSql) {
                                                start <- Sys.time()
                                                connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
                                                on.exit(DatabaseConnector::disconnect(connection = connection))
                                                ParallelLogger::logInfo(sprintf("[Main Analysis] [START] %d (%s)", 
                                                                                as.integer(mainSql$analysisId), 
                                                                                analysisDetails$ANALYSIS_NAME[analysisDetails$ANALYSIS_ID == mainSql$analysisId]))
                                                tryCatch({
                                                  DatabaseConnector::executeSql(connection = connection, sql = mainSql$sql)
                                                  delta <- Sys.time() - start
                                                  ParallelLogger::logInfo(sprintf("[Main Analysis] [COMPLETE] %d (%f %s)", 
                                                                                  as.integer(mainSql$analysisId), 
                                                                                  delta, 
                                                                                  attr(delta, "units")))  
                                                }, error = function(e) {
                                                  ParallelLogger::logError(sprintf("[Main Analysis] [ERROR] %d (%s)", 
                                                                                   as.integer(mainSql$analysisId), 
                                                                                   e))
                                                  ParallelLogger::stopCluster(cluster = cluster)
                                                  DatabaseConnector::disconnect(connection)
                                                  stop()
                                                })
                                              })
      
      ParallelLogger::stopCluster(cluster = cluster)
    }
  }
  
  # Merge scratch tables into final analysis tables -------------------------------------------------------------------------------------------
  
  include <- sapply(resultsTables, function(d) { any(d$analysisIds %in% analysisDetails$ANALYSIS_ID) })
  resultsTablesToMerge <- resultsTables[include]
  
  mergeSqls <- lapply(resultsTablesToMerge, function(table) {
    .mergeScratchTables(resultsTable = table,
                                connectionDetails = connectionDetails,
                                analysisIds = analysisDetails$ANALYSIS_ID,
                                createTable = createTable,
                                schemaDelim = schemaDelim,
                                scratchDatabaseSchema = scratchDatabaseSchema,
                                resultsDatabaseSchema = resultsDatabaseSchema,
                                oracleTempSchema = oracleTempSchema,
                                cdmVersion = cdmVersion,
                                tempPrefix = tempPrefix,
                                numThreads = numThreads,
                                smallCellCount = smallCellCount,
                                outputFolder = outputFolder,
                                sqlOnly = sqlOnly)
  })
  
  achillesSql <- c(achillesSql, mergeSqls)
  
  if (!sqlOnly) {
    
    ParallelLogger::logInfo("Merging scratch CatalogueExport tables")
    
    if (numThreads == 1) {
      tryCatch({
        for (sql in mergeSqls) {
          DatabaseConnector::executeSql(connection = connection, sql = sql)
        }
      }, error = function(e) {
        ParallelLogger::logError(sprintf("Merging scratch CatalogueExport tables [ERROR] (%s)",
                                         e))
        DatabaseConnector::disconnect(connection)
        stop()
      })
    } else {
      cluster <- ParallelLogger::makeCluster(numberOfThreads = numThreads, singleThreadToMain = TRUE)
      tryCatch({
        dummy <- ParallelLogger::clusterApply(cluster = cluster,
                                              x = mergeSqls,
                                              function(sql) {
                                                connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
                                                on.exit(DatabaseConnector::disconnect(connection = connection))
                                                DatabaseConnector::executeSql(connection = connection, sql = sql)
                                              })
      }, error = function(e) {
        ParallelLogger::logError(sprintf("Merging scratch CatalogueExport tables [ERROR] (%s)",
                                         e))
        ParallelLogger::stopCluster(cluster = cluster)
        DatabaseConnector::disconnect(connection)
        stop()
      })
      ParallelLogger::stopCluster(cluster = cluster)
    }
  }
  
  if (!sqlOnly) {
    ParallelLogger::logInfo(sprintf("Done. Catalogue results can now be found in schema %s", resultsDatabaseSchema))
  }
  
  # Clean up scratch tables -----------------------------------------------
  
  if (numThreads == 1 & .supportsTempTables(connectionDetails)) {
    # Dropping the connection removes the temporary scratch tables if running in serial
    DatabaseConnector::disconnect(connection = connection)
  } else if (dropScratchTables & !sqlOnly) {
    # Drop the scratch tables
    ParallelLogger::logInfo(sprintf("Dropping scratch Catalogie tables from schema %s", scratchDatabaseSchema))
    
    dropAllScratchTables(connectionDetails = connectionDetails, 
                         scratchDatabaseSchema = scratchDatabaseSchema, 
                         tempPrefix = tempPrefix, 
                         numThreads = numThreads,
                         tableTypes = c("catalogueExport"),
                         outputFolder = outputFolder)
    
    ParallelLogger::logInfo(sprintf("Temporary Catalogue tables removed from schema %s", scratchDatabaseSchema))
  }
  
  # Create indices -----------------------------------------------------------------
  
  indicesSql <- "/* INDEX CREATION SKIPPED PER USER REQUEST */"
  
  if (createIndices) {
    catalogueTables <- lapply(unique(analysisDetails$DISTRIBUTION), function(a) {
      if (a == 0) {
        "catalogue_results"
      } else {
        "catalogue_results_dist"
      }
    })
    indicesSql <- createIndices(connectionDetails = connectionDetails,
                                resultsDatabaseSchema = resultsDatabaseSchema,
                                outputFolder = outputFolder,
                                sqlOnly = sqlOnly,
                                verboseMode = verboseMode, 
                                catalogueTables = unique(catalogueTables))
  }
  achillesSql <- c(achillesSql, indicesSql)
  
 
  if (sqlOnly) {
    SqlRender::writeSql(sql = paste(achillesSql, collapse = "\n\n"), targetFile = file.path(outputFolder, "catalogue_export.sql"))
    ParallelLogger::logInfo(sprintf("All Catalogue Export SQL scripts can be found in folder: %s", file.path(outputFolder, "catalogue_export.sql")))
  }
 
  totalTime <- Sys.time() - startTime
  ParallelLogger::logInfo(sprintf("[Total Runtime] %f %s", totalTime, attr(totalTime, "units"))) 
  # Export to csv  -----------------------------------------------------------------
  
  exportResultsToCSV(connectionDetails,
                    resultsDatabaseSchema,
                    analysisIds = analysisIds,
                    smallCellCount = smallCellCount,
                    exportFolder = outputFolder) 
  ParallelLogger::logInfo(sprintf("Done. The database characteristics have been exported to: %s", file.path(outputFolder, "catalogue_results.csv"))) #ToDO Add timestamp
  ParallelLogger::logInfo("This file can now be uploaded in the Database Catalogue")
  
  ParallelLogger::unregisterLogger("catalogueExport")
  
  # Return results ----------------------------------------------------------------
  
  
  catalogueResults <- list(resultsConnectionDetails = connectionDetails,
                          resultsTable = "catalogue_results",
                          resultsDistributionTable = "catalogue_results_dist",
                          analysis_table = "catalogue_analysis",
                          sourceName = sourceName,
                          analysisIds = analysisDetails$ANALYSIS_ID,
                          achillesSql = paste(achillesSql, collapse = "\n\n"),
                          indicesSql = indicesSql,
                          call = match.call())
  
  class(catalogueResults) <- "catalogueResults"
  
  invisible(catalogueResults)
}


#' Create indicies
#' 
#' @details 
#' Post-processing, create indices to help performance. Cannot be used with Redshift.
#' 
#' @param connectionDetails                An R object of type \code{connectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package.
#' @param resultsDatabaseSchema		         Fully qualified name of database schema that we can write final results to. Default is cdmDatabaseSchema. 
#'                                         On SQL Server, this should specifiy both the database and the schema, so for example, on SQL Server, 'cdm_results.dbo'.
#' @param outputFolder                     Path to store logs and SQL files
#' @param sqlOnly                          TRUE = just generate SQL files, don't actually run, FALSE = run Achilles
#' @param verboseMode                      Boolean to determine if the console will show all execution steps. Default = TRUE 
#' @param catalogueTables                  Which CatalogueExport tables should be indexed? Default is both catalogue_results and catalogue_results_dist. 
#' 
#' @export
createIndices <- function(connectionDetails,
                          resultsDatabaseSchema,
                          outputFolder,
                          sqlOnly = FALSE,
                          verboseMode = TRUE,
                          catalogueTables = c("catalogue_results", "catalogue_results_dist")) {
  
  # Log execution --------------------------------------------------------------------------------------------------------------------
  
  unlink(file.path(outputFolder, "log_createIndices.txt"))
  if (verboseMode) {
    appenders <- list(ParallelLogger::createConsoleAppender(),
                      ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_createIndices.txt")))    
  } else {
    appenders <- list(ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_createIndices.txt")))
  }
  logger <- ParallelLogger::createLogger(name = "createIndices",
                                         threshold = "INFO",
                                         appenders = appenders)
  ParallelLogger::registerLogger(logger) 
  
  dropIndicesSql <- c()
  indicesSql <- c()
  
  # dbms specific index operations -----------------------------------------------------------------------------------------
  
  if (connectionDetails$dbms %in% c("redshift", "netezza", "bigquery")) {
    return (sprintf("/* INDEX CREATION SKIPPED, INDICES NOT SUPPORTED IN %s */", toupper(connectionDetails$dbms)))
  }
  
  if (connectionDetails$dbms == "pdw") {
    indicesSql <- c(indicesSql, 
                    SqlRender::render("create clustered columnstore index ClusteredIndex_Catalogue_results on @resultsDatabaseSchema.catalogue_results;",
                                      resultsDatabaseSchema = resultsDatabaseSchema))
  }
  
  indices <- read.csv(file = system.file("csv", "post_processing", "indices.csv", package = "CatalogueExport"), 
                      header = TRUE, stringsAsFactors = FALSE)
  
  # create index SQLs ------------------------------------------------------------------------------------------------  
  
  for (i in 1:nrow(indices)) {
    if (indices[i,]$TABLE_NAME %in% catalogueTables) {
      sql <- SqlRender::render(sql = "drop index @resultsDatabaseSchema.@indexName;",
                               resultsDatabaseSchema = resultsDatabaseSchema,
                               indexName = indices[i,]$INDEX_NAME)
      sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
      dropIndicesSql <- c(dropIndicesSql, sql)
      
      sql <- SqlRender::render(sql = "create index @indexName on @resultsDatabaseSchema.@tableName (@fields);",
                               resultsDatabaseSchema = resultsDatabaseSchema,
                               tableName = indices[i,]$TABLE_NAME,
                               indexName = indices[i,]$INDEX_NAME,
                               fields = paste(strsplit(x = indices[i,]$FIELDS, split = "~")[[1]], collapse = ","))
      sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
      indicesSql <- c(indicesSql, sql)
    }
  }
  
  if (!sqlOnly) {
    connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
    on.exit(DatabaseConnector::disconnect(connection = connection))
    
    try(DatabaseConnector::executeSql(connection = connection, sql = paste(dropIndicesSql, collapse = "\n\n")), silent = TRUE)
    DatabaseConnector::executeSql(connection = connection, 
                                  sql = paste(indicesSql, collapse = "\n\n"))
  }
  
  ParallelLogger::unregisterLogger("createIndices")
  
  invisible(c(dropIndicesSql, indicesSql))
}


#' Get all analysis details
#' 
#' @details 
#' Get a list of all analyses with their analysis IDs and strata.
#' 
#' @return 
#' A data.frame with the analysis details.
#' 
#' @export
getAnalysisDetails <- function() {
  read.csv( 
    system.file(
      "csv", 
      "analyses", 
      "catalogue_analysis_details.csv", 
      package = "CatalogueExport"),
    stringsAsFactors = FALSE
  )
}

#' Drop all possible scratch tables
#' 
#' @details 
#' Drop all possible CatalogueExport scratch tables
#' 
#' @param connectionDetails                An R object of type \code{connectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package.
#' @param scratchDatabaseSchema            string name of database schema that CatalogueExport scratch tables were written to. 
#' @param tempPrefix               The prefix to use for the "temporary" (but actually permanent) CatalogueExport analyses tables. Default is "tmpach"
#' @param numThreads                       The number of threads to use to run this function. Default is 1 thread.
#' @param tableTypes                       The types of scratch tables to drop: catalogueExport
#' @param outputFolder                     Path to store logs and SQL files
#' @param verboseMode                      Boolean to determine if the console will show all execution steps. Default = TRUE  
#' 
#' @export
dropAllScratchTables <- function(connectionDetails, 
                                 scratchDatabaseSchema, 
                                 tempPrefix = "tmpach", 
                                 numThreads = 1,
                                 tableTypes = "catalogueExport",
                                 outputFolder,
                                 verboseMode = TRUE) {
  
  # Log execution --------------------------------------------------------------------------------------------------------------------
  
  unlink(file.path(outputFolder, "log_dropScratchTables.txt"))
  if (verboseMode) {
    appenders <- list(ParallelLogger::createConsoleAppender(),
                      ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_dropScratchTables.txt")))    
  } else {
    appenders <- list(ParallelLogger::createFileAppender(layout = ParallelLogger::layoutParallel, 
                                                         fileName = file.path(outputFolder, "log_dropScratchTables.txt")))
  }
  logger <- ParallelLogger::createLogger(name = "dropAllScratchTables",
                                         threshold = "INFO",
                                         appenders = appenders)
  ParallelLogger::registerLogger(logger) 
  
  
  # Initialize thread and scratchDatabaseSchema settings ----------------------------------------------------------------
  
  schemaDelim <- "."
  
  if (numThreads == 1 || scratchDatabaseSchema == "#") {
    numThreads <- 1
    
    if (.supportsTempTables(connectionDetails)) {
      scratchDatabaseSchema <- "#"
      schemaDelim <- "s_"
    }
  }
  
  if ("catalogueExport" %in% tableTypes) {
    
    # Drop CatalogueExport Scratch Tables ------------------------------------------------------
    
    analysisDetails <- getAnalysisDetails()
    
    resultsTables <- lapply(analysisDetails$ANALYSIS_ID[analysisDetails$DISTRIBUTION <= 0], function(id) {
      sprintf("%s_%d", tempPrefix, id)
    })
    
    resultsDistTables <- lapply(analysisDetails$ANALYSIS_ID[abs(analysisDetails$DISTRIBUTION) == 1], function(id) {
      sprintf("%s_dist_%d", tempPrefix, id)
    })
    
    dropSqls <- lapply(c(resultsTables, resultsDistTables), function(scratchTable) {
      sql <- SqlRender::render("IF OBJECT_ID('@scratchDatabaseSchema@schemaDelim@scratchTable', 'U') IS NOT NULL DROP TABLE @scratchDatabaseSchema@schemaDelim@scratchTable;", 
                               scratchDatabaseSchema = scratchDatabaseSchema,
                               schemaDelim = schemaDelim,
                               scratchTable = scratchTable)
      sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
    })
    
    cluster <- ParallelLogger::makeCluster(numberOfThreads = numThreads, singleThreadToMain = TRUE)
    dummy <- ParallelLogger::clusterApply(cluster = cluster, 
                                          x = dropSqls, 
                                          function(sql) {
                                            connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
                                            tryCatch({
                                              DatabaseConnector::executeSql(connection = connection, sql = sql)  
                                            }, error = function(e) {
                                              ParallelLogger::logError(sprintf("Drop CatalogueExport Scratch Table -- ERROR (%s)", e))  
                                            }, finally = {
                                              DatabaseConnector::disconnect(connection = connection)
                                            })
                                          })
    
    ParallelLogger::stopCluster(cluster = cluster)
  }

  ParallelLogger::unregisterLogger("dropAllScratchTables")
}


.getCdmVersion <- function(connectionDetails, 
                           cdmDatabaseSchema) {
  sql <- SqlRender::render(sql = "select cdm_version from @cdmDatabaseSchema.cdm_source",
                           cdmDatabaseSchema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  cdmVersion <- tryCatch({
    c <- tolower((DatabaseConnector::querySql(connection = connection, sql = sql))[1,])
    gsub(pattern = "v", replacement = "", x = c)
  }, error = function (e) {
    ""
  }, finally = {
    DatabaseConnector::disconnect(connection = connection)
    rm(connection)
  })
  
  cdmVersion
}

.getVocabularyVersion <- function(connectionDetails, 
                           cdmDatabaseSchema) {
  sql <- SqlRender::render(sql = "select vocabulary_version from @cdmDatabaseSchema.cdm_source",
                           cdmDatabaseSchema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  vocabularyVersion <- tryCatch({
    c <- tolower((DatabaseConnector::querySql(connection = connection, sql = sql))[1,])
    gsub(pattern = "v", replacement = "", x = c)
  }, error = function (e) {
    ""
  }, finally = {
    DatabaseConnector::disconnect(connection = connection)
    rm(connection)
  })
  
  vocabularyVersion
}

.supportsTempTables <- function(connectionDetails) {
  !(connectionDetails$dbms %in% c("bigquery"))
}

.getAnalysisSql <- function(analysisId, 
                            connectionDetails,
                            schemaDelim,
                            scratchDatabaseSchema,
                            cdmDatabaseSchema,
                            resultsDatabaseSchema,
                            vocabDatabaseSchema,
                            oracleTempSchema,
                            cdmVersion,
                            tempAchillesPrefix, 
                            resultsTables,
                            sourceName,
                            numThreads,
                            outputFolder) {
  
  SqlRender::loadRenderTranslateSql(sqlFilename = file.path("analyses", paste(analysisId, "sql", sep = ".")),
                                    packageName = "CatalogueExport",
                                    dbms = connectionDetails$dbms,
                                    warnOnMissingParameters = FALSE,
                                    scratchDatabaseSchema = scratchDatabaseSchema,
                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                    vocabDatabaseSchema = vocabDatabaseSchema,
                                    resultsDatabaseSchema = resultsDatabaseSchema,
                                    schemaDelim = schemaDelim,
                                    tempAchillesPrefix = tempAchillesPrefix,
                                    oracleTempSchema = oracleTempSchema,
                                    source_name = sourceName,
                                    package_version = packageVersion(pkg = "CatalogueExport"),
                                    cdmVersion = cdmVersion,
                                    singleThreaded = (scratchDatabaseSchema == "#"))
}

.mergeScratchTables <- function(resultsTable,
                                        analysisIds,
                                        createTable,
                                        connectionDetails,
                                        schemaDelim,
                                        scratchDatabaseSchema,
                                        resultsDatabaseSchema,
                                        oracleTempSchema,
                                        cdmVersion,
                                        tempPrefix,
                                        numThreads,
                                        smallCellCount,
                                        outputFolder,
                                        sqlOnly,
                                        includeRawCost) {
  
  castedNames <- apply(resultsTable$schema, 1, function(field) {
    SqlRender::render("cast(@fieldName as @fieldType) as @fieldName", 
                      fieldName = field["FIELD_NAME"],
                      fieldType = field["FIELD_TYPE"])
  })
  
  # obtain the analysis SQLs to union in the merge ------------------------------------------------------------------
  
  detailSqls <- lapply(resultsTable$analysisIds[resultsTable$analysisIds %in% analysisIds], function(analysisId) { 
    analysisSql <- SqlRender::render(sql = "select @castedNames from 
                                     @scratchDatabaseSchema@schemaDelim@tablePrefix_@analysisId", 
                                     scratchDatabaseSchema = scratchDatabaseSchema,
                                     schemaDelim = schemaDelim,
                                     castedNames = paste(castedNames, collapse = ", "), 
                                     tablePrefix = resultsTable$tablePrefix, 
                                     analysisId = analysisId)
    
    if (!sqlOnly) {
      # obtain the runTime for this analysis
      runTime <- .getResultBenchmark(analysisId,
                                             outputFolder)
      
      benchmarkSelects <- lapply(resultsTable$schema$FIELD_NAME, function(c) {
        if (tolower(c) == "analysis_id") {
          sprintf("%d as analysis_id", .getBenchmarkOffset() + as.integer(analysisId))
        } else if (tolower(c) == "stratum_1") {
          sprintf("'%s' as stratum_1", runTime)
        } else if (tolower(c) == "count_value") {
          sprintf("%d as count_value", smallCellCount + 1) 
        } else {
          sprintf("NULL as %s", c)
        }
      })
      
      benchmarkSql <- SqlRender::render(sql = "select @benchmarkSelect",
                                        benchmarkSelect = paste(benchmarkSelects, collapse = ", "))
      
      analysisSql <- paste(c(analysisSql, benchmarkSql), collapse = " union all ")
      
    } 
    analysisSql
  })
  

  SqlRender::loadRenderTranslateSql(sqlFilename = "analyses/merge_catalogue_tables.sql",
                                    packageName = "CatalogueExport",
                                    dbms = connectionDetails$dbms,
                                    warnOnMissingParameters = FALSE,
                                    createTable = createTable,
                                    resultsDatabaseSchema = resultsDatabaseSchema,
                                    oracleTempSchema = oracleTempSchema,
                                    detailType = resultsTable$detailType,
                                    detailSqls = paste(detailSqls, collapse = " \nunion all\n "),
                                    fieldNames = paste(resultsTable$schema$FIELD_NAME, collapse = ", "),
                                    smallCellCount = smallCellCount)
}

.getSourceName <- function(connectionDetails,
                           cdmDatabaseSchema) {
  sql <- SqlRender::render(sql = "select cdm_source_name from @cdmDatabaseSchema.cdm_source",
                           cdmDatabaseSchema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  sourceName <- tryCatch({
    s <- DatabaseConnector::querySql(connection = connection, sql = sql)
    s[1,]
  }, error = function (e) {
    ""
  }, finally = {
    DatabaseConnector::disconnect(connection = connection)
    rm(connection)
  })
  sourceName
}

.deleteExistingResults <- function(connectionDetails,
                                   resultsDatabaseSchema,
                                   analysisDetails) {
  
  
  resultIds <- analysisDetails$ANALYSIS_ID[analysisDetails$DISTRIBUTION == 0]
  distIds <- analysisDetails$ANALYSIS_ID[analysisDetails$DISTRIBUTION == 1]
  
  if (length(resultIds) > 0) {
    sql <- SqlRender::render(sql = "delete from @resultsDatabaseSchema.catalogue_results where analysis_id in (@analysisIds);",
                             resultsDatabaseSchema = resultsDatabaseSchema,
                             analysisIds = paste(resultIds, collapse = ","))
    sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
    
    connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
    on.exit(DatabaseConnector::disconnect(connection = connection))
    DatabaseConnector::executeSql(connection = connection, sql = sql)
  }
  
  if (length(distIds) > 0) {
    sql <- SqlRender::render(sql = "delete from @resultsDatabaseSchema.catalogue_results_dist where analysis_id in (@analysisIds);",
                             resultsDatabaseSchema = resultsDatabaseSchema,
                             analysisIds = paste(distIds, collapse = ","))
    sql <- SqlRender::translate(sql = sql, targetDialect = connectionDetails$dbms)
    connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
    on.exit(DatabaseConnector::disconnect(connection = connection))
    DatabaseConnector::executeSql(connection = connection, sql = sql)
  }
}

.getResultBenchmark <- function(analysisId,
                                        outputFolder) {
  
  logs <- utils::read.table(file = file.path(outputFolder, "log_catalogueExport.txt"), 
                     header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  names(logs) <- c("startTime", "thread", "logType", "package", "packageFunction", "comment")
  logs <- logs[grepl(pattern = "COMPLETE", x = logs$comment),]
  logs$analysisId <- logs$runTime <- NA
  
  for (i in 1:nrow(logs)) {
    logs[i,]$analysisId <- .getAnalysisId(logs[i,]$comment)
    logs[i,]$runTime <- .getRunTime(logs[i,]$comment)
  }
  
  logs <- logs[logs$analysisId == analysisId,]
  if (nrow(logs) == 1) {
    logs[1,]$runTime
  } else {
    "ERROR: check log files"
  }
}

.formatName <- function(name) {
  gsub("_", " ", gsub("\\[(.*?)\\]_", "", gsub(" ", "_", name)))
}

.getAnalysisId <- function(comment) {
  comment <- .formatName(comment)
  as.integer(gsub("\\s*\\([^\\)]+\\)","", as.character(comment)))
}

.getRunTime <- function(comment) {
  comment <- .formatName(comment)
  gsub("[\\(\\)]", "", regmatches(comment, gregexpr("\\(.*?\\)", comment))[[1]])
}

.getBenchmarkOffset <- function() {
  2000000
}