install_required_packages <- function(install) {
    if (update) {
        pak::pak("arrow")
        pak::pak("Rdatatable/data.table")
        pak::pak("tidyverse/tidyverse")
        pak::pak("tidyverse/dplyr")
        pak::pak("tidyverse/dbplyr")
        pak::pak("tidyverse/dtplyr")
        install.packages("polars", repos = "https://rpolars.r-universe.dev")
        install.packages("duckdb", repos = c("https://duckdb.r-universe.dev", "https://cloud.r-project.org"))
        pak::pak("RfastOfficial/Rfast")
        pak::pak("brooke-watson/BRRR")
        pak::pak("patchwork")
        pak::pak("duckdblabs/duckplyr")
        pak::pak("bench")
        pak::pak("etiennebacher/tidypolars")
    }
}

# Only if appropiate
# install_required_packages(install = TRUE) 


