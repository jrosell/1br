# Preparations ----

stopifnot(requireNamespace("rlang"))
rlang::check_installed("pak")
options(
  repos = c(
    "https://community.r-multiverse.org",
    "https://jrosell.r-universe.dev",
    getOption("repos")
  )
)
pkgs <- rlang::chr(
  "rlang" = "rlang",
  "polars",
  "DBI",
  "data.table",
  "ggplot2",
  "tibble",
  "dplyr",
  "tidyr",
  "duckdb",
  "dtplyr",
  "patchwork",
  "arrow",
  "tidypolars",
  "jrrosell",
)
pak::sysreqs_check_installed(pkgs) # rustup install nightly
pak::pak(pkgs)
libs <- ifelse(names(pkgs) == "", pkgs, names(pkgs))
lapply(libs, library, quiet = TRUE, character.only = TRUE) |> invisible()


# Configuration ----

threads <- 8
data.table::setDTthreads(threads)
Sys.setenv(POLARS_MAX_THREADS = threads)
arrow::set_cpu_count(threads)
duckdb_set_threads <- \(conn) {
  DBI::dbExecute(conn = conn, paste0("PRAGMA threads='", threads, "'"))
}

# Benchmark ----
run <- function() {
  all <- bench::press(
    n = c("1e6", "1e7", "1e8"),
    # n = c("1e6", "1e7", "1e8", "1e9"),
    # n = c("1e9"),
    {
      file_name <- here::here("data", paste0("measurements.", n, ".csv"))
      res <- bench::mark(
        duckdb_import_parallel = {
          print("duckdb_import_parallel")
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
          print("duckdb_dplyr_parallel")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          con <- dbConnect(duckdb(), ":memory:")
          duckdb_set_threads(con)
          df <- dplyr::tbl(
            con,
            "read_csv('measurements.csv',
                      parallel = true,
                      delim = ',',
                      header = true,
                      columns = {
                          'measurement': 'DOUBLE',
                          'state': 'VARCHAR'
                      }
                  )"
          )
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        duckdb_dplyr = {
          print("duckdb_dplyr")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          con <- dbConnect(duckdb(), ":memory:")
          duckdb_set_threads(con)
          df <- dplyr::tbl(con, "measurements.csv", check_from = FALSE)
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          dbDisconnect(con, shutdown = TRUE)
          gc()
        },
        DT_dplyr = {
          print("DT_dplyr")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread("measurements.csv")
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_tidypolars_dplyr = {
          print("scan_tidypolars_dplyr")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- pl$scan_csv("measurements.csv")
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        DT_datatable = {
          print("DT_datatable")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread("measurements.csv")
          df <- df[,
            .(
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ),
            by = state
          ]
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        DT_datatable_range = {
          print("DT_datatable_range")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          fun <- function(x) {
            range <- range(x)
            list(mean = mean(x, na.rm = TRUE), min = range[1], max = range[2])
          }
          df <- data.table::fread("measurements.csv")
          df <- df[, fun(measurement), by = state]
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        arrow = {
          print("arrow")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- read_csv_arrow("measurements.csv") |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ) |>
            collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_polars = {
          print("scan_polars")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- pl$scan_csv("measurements.csv")$group_by("state")$agg(
            pl$col("measurement")$min()$alias("min_m"),
            pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
            pl$col("measurement")$mean()$alias("mean_m")
          )$collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        dtplyr = {
          print("dtplyr")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- data.table::fread(
            "measurements.csv",
            stringsAsFactors = TRUE
          )
          df <- lazy_dt(df) %>%
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            )
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_polars_streaming = {
          print("scan_polars_streaming")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- pl$scan_csv("measurements.csv")$group_by("state")$agg(
            pl$col("measurement")$min()$alias("min_m"),
            pl$col("measurement")$max()$alias("max_m"), # nolint: indentation_linter, line_length_linter.
            pl$col("measurement")$mean()$alias("mean_m")
          )$collect()
          print(as_tibble(df), n = Inf)
          df <- NULL
          gc()
        },
        scan_tidypolars_dplyr_streaming = {
          print("scan_tidypolars_dplyr_streaming")
          file.copy(file_name, "measurements.csv", overwrite = TRUE)
          df <- pl$scan_csv("measurements.csv")
          df <- df |>
            summarise(
              .by = state,
              mean = mean(measurement, na.rm = TRUE),
              min = min(measurement, na.rm = TRUE),
              max = max(measurement, na.rm = TRUE)
            ) |>
            collect(engine = "streaming")
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
      ggsave(
        here::here(
          "output",
          paste0(Sys.Date(), "_", n, "_rows.png")
        ),
        plot = p
      )
      res
    }
  )
  print(all)
  p <- ggplot2::autoplot(all, type = "violin") +
    labs(title = "all")
  pdf(NULL)
  ggsave(here::here("output", paste0(Sys.Date(), "_all_rows.png")), plot = p)
  return(all)
}

results <- run()
readr::write_rds(results, paste0(Sys.Date(), "_all.rds"))

jrrosell::notify_finished(
  "job",
  "Well done",
  sound = "fanfare",
  tictoc_result = tictoc::toc()
)
sessionInfo()
