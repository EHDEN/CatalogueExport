CatalogueExport
===============
Exports the data from the OMOP-CDM that is necessary for the EHDEN Data Catalogue
 
Vignette: [Running CatalogueExport on Your CDM](https://github.com/EHDEN/CatalogueExport/raw/master/vignettes/RunningCatalogueExport.pdf) (To Add)

CatalogueExport exports a subset of the analysis generated with the **A**utomated **C**haracterization of **H**ealth **I**nformation at **L**arge-scale **L**ongitudinal **E**vidence **S**ystems ([Achilles](https://github,com/OHDSI/Achilles)) R-package to a comma-seperated files format that can be loaded in the EHDEN Database Catalogue. The results are visualized in the Database Dashboard and Network level visualizations.

CatalogueExport is actively being developed for CDM v5.x only.

## Exported Analyses

By default the following analyses are included in the export:

   ```{r echo = FALSE, results = 'asis'}
   library(knitr)
   kable(mtcars[1:5, ], captiomn = "test")
   ```

## Getting Started


1. Make sure you have your data in the OMOP CDM v5.x format
    (https://github.com/OHDSI/CommonDataModel).

1. This package makes use of rJava. Make sure that you have Java installed. If you don't have Java already installed on your computer (on most computers it already is installed), go to [java.com](https://java.com) to get the latest version. If you are having trouble with rJava, [this Stack Overflow post](https://stackoverflow.com/questions/7019912/using-the-rjava-package-on-win7-64-bit-with-r) may assist you when you begin troubleshooting.


1. In R, use the following commands to install CatalogueExport.

    ```r
    if (!require("devtools")) install.packages("devtools")
    
    # To install the master branch
    devtools::install_github("EHDEN/CatalogueExport")
    
    # To install latest release (if master branch contains a bug for you)
    # devtools::install_github("EHDEN/CatalogueExport@*release")  
    
    # To avoid Java 32 vs 64 issues 
    # devtools::install_github("EHDEN/CatalogieExport", args="--no-multiarch")  
    ```

1. To run the export execute the following R commands:
    
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
    
    ```r
    catalogueExport(connectionDetails, 
      cdmDatabaseSchema = "cdm5_inst", 
      resultsDatabaseSchema="results",
      vocabDatabaseSchema = "vocab",
      sourceName = "My Source Name", 
      cdmVersion = "5.3.0")
    ```

    
    The `"cdm5_inst"` cdmDatabaseSchema parameter, `"results"` resultsDatabaseSchema parameter, and `"scratch"` scratchDatabaseSchema parameter are the fully qualified names of the schemas holding the CDM data, targeted for result writing, and holding the intermediate scratch tables, respectively. See the [DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) package for details on settings the connection details for your database, for example by typing
      
    ```r
    ?createConnectionDetails
    ```

    The SQL platforms supported by [DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) and [SqlRender](https://github.com/OHDSI/SqlRender) are the **only** ones supported here in Achilles as `dbms`. `cdmVersion` can be *ONLY* 5.x (please look at prior commit history for v4 support).


## License

Achilles is licensed under Apache License 2.0


## Acknowledgements
- The European Health Data & Evidence Network has received funding from the Innovative Medicines Initiative 2 Joint Undertaking (JU) under grant agreement No 806968. The JU receives support from the European Union’s Horizon 2020 research 
- We like to thank the OHDSI community for their fantastic work on the Achilles R Package that provides the basis of most the analysis used in this package

