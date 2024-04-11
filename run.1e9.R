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
  dbExecute(conn = conn, paste0("PRAGMA threads='", threads, "'"))
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
          df <- df |>
            summarise(
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
        duckplyr_df_from_csv = {
          print("duckplyr_df_from_csv")
          df <- duckplyr::duckplyr_df_from_csv(file_name) |>
            summarize(
              .by = state,
              state_min = min(measurement),
              state_max = max(measurement),
              state_sum = sum(measurement),
              state_n = n()
            ) |>
            mutate(state_mean = state_sum / state_n) |>
            select(state, state_min, state_mean, state_max) |>
            collect()
          print(df)
        },
        arrow_dataset = {
          print("arrow_dataset")
          ds <- arrow::open_csv_dataset(file_name)
          df <- ds |>
            summarize(
              .by = state,
              state_min = min(measurement),
              state_max = max(measurement),
              state_sum = sum(measurement),
              state_n = n()
            ) |>
            mutate(state_mean = state_sum / state_n) |>
            select(state, state_min, state_mean, state_max) |>
            collect()
          df
        },
        arrow_dataset_batch_processing = {
          print("arrow_dataset_batch_processing")
          ds <- arrow::open_csv_dataset(file_name)
          df <- ds |>
            arrow::map_batches(function(batch) {
              batch |>
                as.data.frame() |>
                summarize(
                  .by = state,
                  state_min = min(measurement),
                  state_max = max(measurement),
                  state_sum = sum(measurement),
                  state_n = n()
                ) |>
                arrow::as_record_batch()
            }) |>
            mutate(state_mean = state_sum / state_n) |>
            select(state, state_min, state_mean, state_max) |>
            collect()
          df
        },
        # dt_sed_paralel = {
        #   print("dt_sed_paralel")
        #   chunk_size <- as.numeric(n)
        #   n_chunks <- 7
        #   skips <- seq(1, chunk_size + 1, length.out = n_chunks + 1)[1:n_chunks - 1]
        #   nrows <- chunk_size / n_chunks
        #   result_list <- parallel::mclapply(skips, mc.cores = 8, FUN = \(skip){
        #     df <- data.table::fread(file_name, sep = ",", skip = skip, nrows = nrows, header = FALSE, nThread = 1)
        #     df <- df[,
        #       .(
        #         mean = mean(measurement),
        #         min = min(measurement),
        #         max = max(measurement)
        #       ),
        #       by = state
        #     ]
        #   })
        #   result_df <- data.table::rbindlist(result_list)
        #   result_df
        # },
        memory = FALSE,
        filter_gc = FALSE,
        min_iterations = 1,
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
