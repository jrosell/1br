library(DBI)
library(data.table)
library(polars)
library(ggplot2)
library(tibble)
library(dplyr)
library(tidyr)
library(Rfast)
library(duckdb)
library(dtplyr)
library(patchwork)
library(arrow)
library(tidypolars)

threads <- 8
data.table::setDTthreads(threads)
Sys.setenv(POLARS_MAX_THREADS = threads)
arrow::set_cpu_count(threads)
duckdb_set_threads <- \(conn) {
    dbExecute(conn = conn, paste0("PRAGMA threads='",threads,"'"))
}

run <- function() {
  all <- bench::press(
    n = c("1e6", "1e7", "1e8"),
    # n = c("1e6", "1e7", "1e8", "1e9"), # nolint: commented_code_linter.
    {
      file_name <- paste0("measurements.", n, ".csv")
      res <- bench::mark(
        duckdb_import_parallel = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          sqltxt <- "select
                  state, min(measurement) as min_m,
                  max(measurement) as max_m,
                  avg(measurement) as mean_m
            from read_csv('measurements.csv',
                  parallel = true,
                  delim = ',',
                  header = true,
                  columns = {
                      'measurement': 'DOUBLE',
                      'state': 'VARCHAR'
                  }
            )
            group by state"
          con <- dbConnect(duckdb(), dbdir = ":memory:")
          duckdb_set_threads(con)
          df <- dbGetQuery(con, sqltxt)
          print(as_tibble(df), n = Inf)
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        duckdb_dplyr_parallel = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          con <- dbConnect(duckdb(), ":memory:")
          duckdb_set_threads(con)
          df <- dplyr::tbl(con, "read_csv('measurements.csv',
                      parallel = true,
                      delim = ',',
                      header = true,
                      columns = {
                          'measurement': 'DOUBLE',
                          'state': 'VARCHAR'
                      }
                  )", check_from = FALSE)
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        duckdb_dplyr = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          con <- dbConnect(duckdb(), ":memory:")
          duckdb_set_threads(con)
          df <- dplyr::tbl(con, "measurements.csv", check_from = FALSE)
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        DT_dplyr = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread("measurements.csv")
          df <- df |> summarise(
            .by = state,
            mean = mean(measurement),
            min = min(measurement),
            max = max(measurement)
          )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_tidypolars_dplyr = {
            file.copy(file_name, "measurements.csv", overwrite = TRUE)
            df <- pl$scan_csv("measurements.csv")
            df <- df |> summarise(
                .by = state,
                mean = mean(measurement),
                min = min(measurement),
                max = max(measurement)
                ) |>
                collect()
            print(as_tibble(df), n = Inf)
            df <- NULL
            gc()
        },
        DT_datatable = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread("measurements.csv")
          df <- df[,
            .(
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ),
            by = state
          ]
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        DT_datatable_range = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          fun <- function(x) {
            range <- range(x)
            list(mean = mean(x), min = range[1], max = range[2])
          }
          df <- data.table::fread("measurements.csv")
          df <- df[, fun(measurement), by = state]
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        DT_Rfast = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread(
            "measurements.csv",
            stringsAsFactors = TRUE
          )
          lev_int <- as.numeric(df$state)
          minmax <- Rfast::group(
            df$measurement, lev_int,
            method = "min.max"
          )
          df <- data.frame(
            state = levels(df$state),
            mean = Rfast::group(
              df$measurement, lev_int,
              method = "mean"
            ),
            min = minmax[1, ],
            max = minmax[2, ]
          )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        arrow = {
            file.copy(file_name, "measurements.csv", overwrite = TRUE)
            df <- read_csv_arrow("measurements.csv") |>
                summarise(
                    .by = state,
                    mean = mean(measurement),
                    min = min(measurement),
                    max = max(measurement)
                ) |>
                collect()
            print(as_tibble(df), n = Inf)
            df <- NULL
            gc()
        },
        scan_polars = {
            file.copy(file_name, "measurements.csv", overwrite = TRUE)
            df <- pl$scan_csv("measurements.csv")$
                group_by("state")$
                agg(
                    pl$col("measurement")$min()$alias("min_m"),
                    pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
                    pl$col("measurement")$mean()$alias("mean_m")
                )$
                collect()
            print(as_tibble(df), n = Inf)
            df <- NULL
            gc()
        },
        DT_polars = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread("measurements.csv")
          df <- polars::pl$DataFrame(df)$
            group_by("state")$
            agg(
            polars::pl$col("measurement")$min()$alias("min_m"),
            polars::pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
            polars::pl$col("measurement")$mean()$alias("mean_m")
          )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        dtplyr = {
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread(
            "measurements.csv",
            stringsAsFactors = TRUE
          )
          df <- lazy_dt(df) %>%
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_polars_streaming = {
            print("scan_polars_streaming")
            file.copy(file_name, "measurements.csv", overwrite = TRUE)
            df <- pl$scan_csv("measurements.csv")$
                group_by("state")$
                agg(
                    pl$col("measurement")$min()$alias("min_m"),
                    pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
                    pl$col("measurement")$mean()$alias("mean_m")
                )$
                collect(streaming = TRUE)
            print(as_tibble(df), n = Inf)
            df <- NULL
            gc()
        },
        scan_tidypolars_dplyr_streaming = {
            print("scan_tidypolars_dplyr_streaming")
            file.copy(file_name, "measurements.csv", overwrite = TRUE)
            df <- pl$scan_csv("measurements.csv")
            df <- df |> summarise(
                .by = state,
                mean = mean(measurement),
                min = min(measurement),
                max = max(measurement)
            ) |>
                collect(streaming = TRUE)
            print(as_tibble(df), n = Inf)
            df <- NULL
            gc()
        },
        filter_gc = FALSE,
        min_iterations = 5,
        check = FALSE
      )
      print(res)
      p <- ggplot2::autoplot(res, type = "violin") +
        labs(title = paste(n, "rows"))
      pdf(NULL)
      ggsave(paste0(Sys.Date(), "_", n, "_rows.png"), plot = p)
      res
    }
  )
  print(all)
  p <- ggplot2::autoplot(all, type = "violin") +
    labs(title = "all")
  pdf(NULL)
  ggsave(paste0(Sys.Date(), "_all_rows.png"), plot = p)
  return(all)
}

results <- run()
readr::write_rds(results, paste0(Sys.Date(), "_all.rds"))

BRRR::skrrrahh(13)
sessionInfo()
