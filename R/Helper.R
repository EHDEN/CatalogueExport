#' Print the sql of an analysis
#' 
#' @details 
#' Print the parameterized SQL that is run for an analysisId.
#' 
#' @param analysisId            An analysisId for which the sql will be printed.  
#' @param connectionDetails     An R object of type \code{connectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package. 
#' @return 
#' None
#' 
#' @export
printAnalysesSql<- function(analysisId,connectionDetails){
  
  sql <- tryCatch({
    sql = SqlRender::loadRenderTranslateSql( sqlFilename =  file.path("analyses", paste(analysisId, "sql", sep = ".")),
                                            tdbms = connectionDetails$dbms, packageName = "CatalogueExport")
    cat(sql)
  }, error = function (e) {
    cat("analysisId does not exist ") 
  }, finally = {
  })
}