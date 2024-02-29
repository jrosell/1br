install_required_packages <- function(install) {
  if (install) {
    rlang::check_installed("arrow")
    rlang::check_installed(
      "data.table",
      action = \(pkg, ...)  pak::pak("Rdatatable/data.table")
    )
    rlang::check_installed(
      "tidyverse",
      action = \(pkg, ...)  pak::pak("tidyverse/tidyverse")
    )
    rlang::check_installed(
      "dplyr",
      action = \(pkg, ...)  pak::pak("tidyverse/dplyr")
    )
    rlang::check_installed(
      "dbplyr",
      action = \(pkg, ...)  pak::pak("tidyverse/dbplyr")
    )
    rlang::check_installed(
      "dtplyr",
      action = \(pkg, ...)  pak::pak("tidyverse/dtplyr")
    )
    rlang::check_installed(
      "polars",
      action = \(pkg, ...) {
        Sys.setenv(NOT_CRAN = "true")
        install.packages("polars", repos = "https://rpolars.r-universe.dev")
      }
    )
    rlang::check_installed(
      "duckdb",
      action = \(pkg, ...) {
        Sys.setenv(NOT_CRAN = "true")
        install.packages(
          "duckdb",
          repos = c(
            "https://duckdb.r-universe.dev", "https://cloud.r-project.org"
          )
        )
      }
    )
    rlang::check_installed(
      "Rfast",
      action = \(pkg, ...) pak::pak("RfastOfficial/Rfast")
    )
    rlang::check_installed(
      "BRRR",
      action = \(pkg, ...) pak::pak("brooke-watson/BRRR")
    )
    rlang::check_installed("patchwork")
  }
}

install_required_packages(install = FALSE) # Only if appropiate
