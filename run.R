library(DBI)
library(data.table)
library(ggplot2)
library(tibble)
library(dplyr)
library(tidyr)
library(polars)
library(Rfast)
library(duckdb)
library(dtplyr)
library(patchwork)
library(arrow)

run <- function() {
  all <- bench::press(
    n = c("1e6", "1e7", "1e8"),
    # n = c("1e6", "1e7", "1e8", "1e9"), # nolint: commented_code_linter.
    {
      file_name <- paste0("measurements.", n, ".csv")
      res <- bench::mark(
        duckdb_import_parallel = {
          sqltxt <- paste0(
            "select
                  state, min(measurement) as min_m,
                  max(measurement) as max_m,
                  avg(measurement) as mean_m
            from read_csv('", file_name, "',
                  parallel = true,
                  delim = ',',
                  header = true,
                  columns = {
                      'measurement': 'DOUBLE',
                      'state': 'VARCHAR'
                  }
            )
            group by state"
          )
          con <- dbConnect(duckdb(), dbdir = ":memory:")
          dbGetQuery(con, sqltxt)
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        duckdb_dplyr_parallel = {
          con <- dbConnect(duckdb(), ":memory:")
          df <- dplyr::tbl(con, paste0("read_csv('", file_name, "',
                      parallel = true,
                      delim = ',',
                      header = true,
                      columns = {
                          'measurement': 'DOUBLE',
                          'state': 'VARCHAR'
                      }
                  )"), check_from = FALSE)
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ) |>
            collect()
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        duckdb_dplyr = {
          con <- dbConnect(duckdb(), ":memory:")
          df <- dplyr::tbl(con, file_name, check_from = FALSE)
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ) |>
            collect()
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        DT_dplyr = {
          df <- data.table::fread(file_name)
          df <- df |> summarise(
            .by = state,
            mean = mean(measurement),
            min = min(measurement),
            max = max(measurement)
          )
          df <- NULL
          gc()
        },
        DT_dplyr_range = {
          df <- data.table::fread(file_name)
          df <- df |>
            dplyr::reframe(
              .by = state,
              mean = mean(measurement),
              name = c("min", "max"),
              value = range(measurement)
            ) |>
            pivot_wider()
          df <- NULL
          gc()
        },
        DT_datatable = {
          df <- data.table::fread(file_name)
          df <- df[,
            .(
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ),
            by = state
          ]
          df <- NULL
          gc()
        },
        DT_datatable_range = {
          fun <- function(x) {
            range <- range(x)
            list(mean = mean(x), min = range[1], max = range[2])
          }
          df <- data.table::fread(file_name)
          df <- df[, fun(measurement), by = state]
          df <- NULL
          gc()
        },
        DT_Rfast = {
          df <- data.table::fread(
            file_name,
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
          df <- NULL
          gc()
        },
        arrow = {
            df <- read_csv_arrow(file_name) |>
                summarise(
                    .by = state,
                    mean = mean(measurement),
                    min = min(measurement),
                    max = max(measurement)
                ) |>
                collect()
            df <- NULL
            gc()
        },
        scan_polars = {
            df <- pl$scan_csv(file_name)$
                group_by("state")$
                agg(
                    pl$col("measurement")$min()$alias("min_m"),
                    pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
                    pl$col("measurement")$mean()$alias("mean_m")
                )$
                collect()
            df <- NULL
            gc()
        },
        DT_polars = {
          df <- data.table::fread(file_name)
          df <- polars::pl$DataFrame(df)$
            group_by("state")$
            agg(
            polars::pl$col("measurement")$min()$alias("min_m"),
            polars::pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
            polars::pl$col("measurement")$mean()$alias("mean_m")
          )
          df <- NULL
          gc()
        },
        dtplyr = {
          df <- data.table::fread(
            file_name,
            stringsAsFactors = TRUE
          )
          df <- lazy_dt(df) %>%
            summarise(
              .by = state,
              mean = mean(measurement),
              min = min(measurement),
              max = max(measurement)
            ) %>%
            as_tibble()
          df <- NULL
          gc()
        },
        filter_gc = FALSE,
        min_iterations = 10,
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
