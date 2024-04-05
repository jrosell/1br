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
    n = c("1e9"),
    {
      file_name <- paste0("measurements.", n, ".csv")
      res <- bench::mark(
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
  return(all)
}

results <- run()
BRRR::skrrrahh(13)
sessionInfo()
