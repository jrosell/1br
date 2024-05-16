library(ggplot2)
library(tibble)
library(dplyr)
library(patchwork)
library(duckplyr)

threads <- 8
duckdb_set_threads <- \(conn) {
  dbExecute(conn = conn, paste0("PRAGMA threads='", threads, "'"))
}

run <- function() {
  all <- bench::press(
    n = c("1e6", "1e7", "1e8", "1e9"),
    {
      file_name <- paste0("measurements.", n, ".csv")
      res <- bench::mark(
        duckplyr_df_from_csv = {
          print("duckplyr_df_from_csv")
          df <- duckplyr::duckplyr_df_from_csv(file_name) |>
            group_by(state) |>
            summarize(
              state_min = min(measurement),
              state_sum = sum(measurement),
              state_n = n(),
              state_max = max(measurement)
            ) |>
            mutate(state_mean = state_sum / state_n) |>
            select(state, state_min, state_mean, state_max) |>
            collect()
          print(df)
        },
        memory = FALSE,
        filter_gc = FALSE,
        min_iterations = 10,
        check = FALSE
      )
      print(res)
      p <- ggplot2::autoplot(res, type = "violin") +
        labs(title = paste(n, "rows"))
      pdf(NULL)
      ggsave(paste0(Sys.Date(), "_", n, "_duckplyr_rows.png"), plot = p)
      res
    }
  )
  print(all)
  return(all)
}

results <- run()
p <- results %>%
  ggplot2::autoplot(type = "violin") + labs(title = paste(n, "rows"))
pdf(NULL)
ggsave(paste0(Sys.Date(), "_all_duckplyr_rows.png"), plot = p)
BRRR::skrrrahh(13)
sessionInfo()
