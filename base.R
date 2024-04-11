library(purrr)
library(tibble)
library(dplyr)

file_size <- "1e6"
file_name <- paste0("measurements.", file_size, ".csv")
chunk_size <- as.numeric(file_size)

states <- c(
  "NC", "MA", "TX", "VT", "OR", "NY", "ND", "NV", "SD", "IN",
  "ID", "RI", "TN", "SC", "PA", "WV", "CT", "NE", "KY", "DE",
  "MT", "ME", "AL", "WI", "IA", "MI", "UT", "LA", "WA", "NM",
  "AR", "MO", "MD", "MN", "KS", "AK", "OK", "NH", "NJ", "AZ",
  "CA", "HI", "IL", "GA", "WY", "CO", "MS", "VA", "OH", "FL"
)

res <- bench::mark(
  hash_line_by_line = {
      con <- file(file_name, 'r');
      stations <- hashtab()
      for (state in states) {
          sethash(stations, state, c(99999, -99999, 0, NA_real_))
      }
      invisible(readLines(con, n = 1))
      while(length(line <- readLines(con, n = 1)) > 0) {
          values <- strsplit(line, ",")[[1]]
          temp <- as.double(values[1])
          city <- values[2]
          station <- gethash(stations, city)
          sethash(stations, city, c(
              min(temp, station[1]),
              max(temp, station[2]),
              sum(temp, station[3]),
              sum(station[4], 1, na.rm = TRUE)
          ))
      }
      close(con)
      hashkeys <- function(h) {
          val <- vector("list", numhash(h))
          idx <- 0
          maphash(h, function(k, v) {
              idx <<- idx + 1
              val[idx] <<- list(k)
          })
          val
      }
      hash_result <- hashkeys(stations) |>
          purrr::map(\(city){
              vals <- gethash(stations, city)
              tibble(
                  city = city,
                  min_temp = vals[1],
                  max_temp = vals[2],
                  sum_temp = vals[3],
                  n = vals[4]
              )
          }) %>%
          list_rbind() %>%
          mutate(mean_temp = sum_temp / n) %>%
          arrange(city) %>%
          mutate(across(everything(), unname))
      hash_result
  },
  list_line_by_line = {
      con <- file(file_name, 'r');
      stations <- vector(mode = "list", length = 50)
      for (state in states) {
          stations[[city]] <- c(99999, -99999, 0, NA_real_)
      }
      invisible(readLines(con, n = 1))
      while(length(line <- readLines(con, n = 1)) > 0) {
          vals <- strsplit(line, ",")[[1]]
          temp <- as.double(vals[1])
          city <- vals[2]
          station <- stations[[city]]
          stations[[city]] <- c(
              min(station[1], temp),
              max(station[2], temp),
              sum(station[3], temp),
              sum(station[4], 1, na.rm = TRUE)
          )
      }
      close(con)
      stations_df <- do.call(rbind, stations)
      list_result <-
          tibble(
              sum_temp = stations_df[, 3],
              n = stations_df[, 4]
          ) %>%
          transmute(
              city = rownames(stations_df),
              min_temp = stations_df[, 1],
              max_temp = stations_df[, 2],
              mean_temp = sum_temp/n
          ) %>%
          arrange(city) %>%
          mutate(across(everything(), unname))
      list_result
  },
  list_batches = {
      con <- file(file_name, 'r');
      batch <- 3000
      stations <- vector(mode = "list", length = 50)
      invisible(readLines(con, n = 1))
      line <- readLines(con, n = batch)
      while(!is.na(line[1])) {
          temp <- vector(mode = "list", length = 50)
          lines <- strsplit(line, ",")
          for(index in seq_along(lines)){
              vals <- lines[[index]]
              state <- vals[2]
              temp[[state]][index] <- as.double(vals[1])
          }
          for (state in states) {
              station <- stations[[state]]
              stations[[state]] <- c(
                  min(station[1], temp[[state]], na.rm = TRUE),
                  max(station[2], temp[[state]], na.rm = TRUE),
                  sum(station[3], temp[[state]], na.rm = TRUE),
                  sum(station[4], !is.na(temp[[state]]), na.rm = TRUE)
              )
          }
          line <- readLines(con, n = batch)
      }
      close(con)
      stations_df <- do.call(rbind, stations)
      batch_result <-
          tibble(
              sum_temp = stations_df[, 3],
              n = stations_df[, 4]
          ) %>%
          transmute(
              state = rownames(stations_df),
              min_temp = stations_df[, 1],
              max_temp = stations_df[, 2],
              mean_temp = sum_temp / n
          ) %>%
          arrange(state) %>%
          mutate(across(everything(), unname))
      batch_result
  },
  named_vector_stringr_dbl = {
      chunk_size <- as.numeric(file_size)
      con <- file(file_name)
      lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
      close(con)
      m <- stringr::str_extract(lines, "^(....).*(..)", group = c(1, 2))
      temps <- as.double(m[,1])
      names(temps) <- m[,2]
      named_vector_result <- lapply(states, \(state){
          state_values <- temps[names(temps) == state]
          data.frame(
              state = state,
              min = min(state_values),
              max = max(state_values),
              mean = mean(state_values)
          )
      })
      named_vector_result
  },
  named_vector_base = {
      con <- file(file_name)
      lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
      close(con)
      lines_list <- strsplit(lines, ",", fixed = TRUE)
      lines_vector <- unlist(lines_list, recursive = FALSE, use.names = FALSE)
      index <- (1:length(lines_list) %% 2) == 1
      measurement <- as.double(lines_vector[index])
      state <- lines_vector[!index]
      split_measurement <- split(measurement, state)
      summary_stats <- vapply(split_measurement, function(x) c(min(x), max(x), mean(x)), double(3))
      summary_stats
  },
  read_delim_base = {
      df <- read.delim(file_name, sep=",", header=TRUE)
      vapply(
          split(df$measurement, df$state),
          function(x) c(min(x), max(x), mean(x)),
          double(3)
      )
  },
  memory = FALSE,
  filter_gc = FALSE,
  min_iterations = 1,
  check = FALSE
)
print(res)
