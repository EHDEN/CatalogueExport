CatalogueExport
===============
Exports the data from the OMOP-CDM that is necessary for the EHDEN Database Catalogue
 
Vignette: [Running CatalogueExport on Your CDM](https://github.com/EHDEN/CatalogueExport/raw/master/vignettes/RunningCatalogueExport.pdf) (To Add)

CatalogueExport exports a subset of the analysis generated with the **A**utomated **C**haracterization of **H**ealth **I**nformation at **L**arge-scale **L**ongitudinal **E**vidence **S**ystems ([Achilles](https://github,com/OHDSI/Achilles)) R-package to a comma-seperated files format that can be loaded in the EHDEN Database Catalogue. 
The results are visualized in the Database Dashboard and Network level visualizations.

**Note that in CatalogueExport no exact counts for concept_ids are exported but these are rounded up to the nearest 100 and will therefore only be an approximation which is enough for univariate feasibility assessments in the catalogue.**

CatalogueExport is actively being developed for CDM v5.x only.

## Getting Started


1. Make sure you have your data in the OMOP CDM v5.x format
    (https://github.com/OHDSI/CommonDataModel).

2. This package makes use of rJava. Make sure that you have Java installed. If you don't have Java already installed on your computer (on most computers it already is installed), go to [java.com](https://java.com) to get the latest version. If you are having trouble with rJava, [this Stack Overflow post](https://stackoverflow.com/questions/7019912/using-the-rjava-package-on-win7-64-bit-with-r) may assist you when you begin troubleshooting.


3. In R, use the following commands to install CatalogueExport.

    ```r
    if (!require("devtools")) install.packages("devtools")
    
    # To install the master branch
    devtools::install_github("EHDEN/CatalogueExport")
    
    # To install latest release (if master branch contains a bug for you)
    # devtools::install_github("EHDEN/CatalogueExport@*release")  
    
    # To avoid Java 32 vs 64 issues 
    # devtools::install_github("EHDEN/CatalogieExport", args="--no-multiarch")  
    ```

4. To run the CatalogueExport analyses, first determine if you'd like to run the function in multi-threaded mode or in single-threaded mode. 
    
    **In multi-threaded mode**
    
    The analyses are run in multiple SQL sessions, which can be set using the `numThreads` setting and setting scratchDatabaseSchema to something other than `#`. For example, 10 threads means 10 independent SQL sessions. Intermediate results are written to scratch tables before finally being combined into the final results tables. Scratch tables are permanent tables; you can either choose to have Achilles drop these tables (`dropScratchTables = TRUE`) or you can drop them at a later time (`dropScratchTables = FALSE`). Dropping the scratch tables can add time to the full execution. If desired, you can set your own custom prefix for all Achilles analysis scratch tables (tempAchillesPrefix).
    
    **In single-threaded mode**
    
    The analyses are run in one SQL session and all intermediate results are written to temp tables before finally being combined into the final results tables. Temp tables are dropped once the package is finished running. Single-threaded mode can be invoked by either setting `numThreads = 1` or `scratchDatabaseSchema = "#"`.
    
    Use the following commands in R: 
  
    ```r
    library(CatalogueExport)
    connectionDetails <- createConnectionDetails(
      dbms="redshift", 
      server="server.com", 
      user="secret", 
      password='secret', 
      port="5439")
    ```
    
    **Single-threaded mode**
    
    ```r
    catalogueExport(connectionDetails, 
      cdmDatabaseSchema = "cdm5_inst", 
      resultsDatabaseSchema="results",
      vocabDatabaseSchema = "vocab",
      numThreads = 1,
      sourceName = "My Source Name", 
      cdmVersion = "5.3.0")
    ```

    **Multi-threaded mode**
    
    ```r
    catalogueExport(connectionDetails, 
      cdmDatabaseSchema = "cdm5_inst", 
      resultsDatabaseSchema = "results",
      scratchDatabaseSchema = "scratch",
      vocabDatabaseSchema = "vocab",
      numThreads = 10,
      sourceName = "My Source Name", 
      smallCellCount = 5,
      cdmVersion = "5.3.0")
    ```

The `"cdm5_inst"` cdmDatabaseSchema parameter, `"results"` resultsDatabaseSchema parameter, and `"scratch"` scratchDatabaseSchema parameter are the fully qualified names of the schemas holding the CDM data, targeted for result writing, and holding the intermediate scratch tables, respectively. See the [DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) package for details on settings the connection details for your database, for example by typing
      
    ```r
    ?createConnectionDetails
    ```

The SQL platforms supported by [DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) and [SqlRender](https://github.com/OHDSI/SqlRender) are the **only** ones supported here in Achilles as `dbms`. `cdmVersion` can be *ONLY* 5.x (please look at prior commit history for v4 support). If you do not specify the sourceName or cdmVersion they are read from the cdm_source table in the cdm. 

The package contains a [CodeToRun.R](https://github.com/EHDEN/CatalogueExport/blob/master/extras/CodeToRun.R) file in the extra folder for convenience.
    
## Excuted Analyses

The following analyses are included in the export by default: [Analyses](https://github.com/EHDEN/CatalogueExport/blob/master/inst/csv/analyses/catalogue_analysis_details.csv)

If you like to view the parameterized sql that is executed for a specific analyses you can run the following command:

```r
  printAnalysisSql(analysisId = 101)
```

In case you first want to check all sql that is executed against the CDM you can set `sql_only = TRUE`. This will not execute anything but will create a sql file in your output folder.

## Upload results in the Database Catalogue

The output file created in you output folder can be uploaded in the EHDEN Database Catalogue if you have the upload rights for your database.

1. Login to the EHDEN Portal (https://portal.ehden.eu)
2. Navigate to your database and click on "Dashboard Data Upload" tab (see figure below). The select the file to upload. You can see the upload history on this page as ell
<table>
<tr valign="bottom">
<td width = 50%>
<img src="https://github.com/EHDEN/CatalogueExport/raw/master/extras/upload.png"/>
</td>
</table>

All visualisations in the Database Dashboard and the Network Dashboards will now automatically reflect the new characteristics of your database. Please rerun this procedure for every CDM update so the dashboard shows the latest version of your data.

Support
=======
We use the <a href="https://github.com/EHDEN/CatalogueExport/issues">GitHub issue tracker</a> for all questions/comments/bugs/issues/enhancements.

## Project status: Beta
The tool is currently under development and **should not be used yet**.

## License

CatalogueExport is licensed under Apache License 2.0


## Acknowledgements
- The European Health Data & Evidence Network has received funding from the Innovative Medicines Initiative 2 Joint Undertaking (JU) under grant agreement No 806968. The JU receives support from the European Union’s Horizon 2020 research 
- We like to thank the [contributors](https://github.com/OHDSI/Achilles/graphs/contributors) of the OHDSI community for their fantastic work on the Achilles R Package that provides the basis of the code and analysis used in this package

