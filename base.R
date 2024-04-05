library(purrr)
library(tibble)
library(dplyr)

file_name <- 'measurements.1e6.csv'
# file_name <- 'measurements.1e9.csv'

cities <- c(
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
        for (city in cities) {
            sethash(stations, city, c(99999, -99999, 0, NA_real_))
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
        for (city in cities) {
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
                sum_temp,
                n,
                mean_temp = sum_temp/n
            ) %>% 
            arrange(city) %>% 
            mutate(across(everything(), unname))
        list_result
    },
    list_batches = {
        con <- file(file_name, 'r');
        batch <- 10000
        stations <- vector(mode = "list", length = 50)
        temp <- vector(mode = "list", length = 50)
        for (city in cities) {
            stations[[city]] <- c(99999, -99999, 0, NA_real_)
            temp[[city]] <- rep(NA_real_, batch)
        }
        invisible(readLines(con, n = 1))
        while(length(line <- readLines(con, n = batch)) > 0) {
            lines <- strsplit(line, ",")
            for(index in seq_along(lines)){
                vals <- lines[[index]]
                city <- vals[2]
                temp[[city]][index] <- as.double(vals[1])
            }
            for (city in cities) {
                station <- stations[[city]]
                stations[[city]] <- c(
                    min(station[1], temp[[city]], na.rm = TRUE),
                    max(station[2], temp[[city]], na.rm = TRUE),
                    sum(station[3], temp[[city]], na.rm = TRUE),
                    sum(station[4], !is.na(temp[[city]]), na.rm = TRUE)
                )
            }
        }
        close(con)
        stations_df <- do.call(rbind, stations)
        batch_result <- 
            tibble(
                sum_temp = stations_df[, 3],
                n = stations_df[, 4]
            ) %>%
            transmute(
                city = rownames(stations_df),
                min_temp = stations_df[, 1],
                max_temp = stations_df[, 2],
                sum_temp,
                n,
                mean_temp = sum_temp / n
            ) %>% 
            arrange(city) %>% 
            mutate(across(everything(), unname))
        batch_result
    },
    filter_gc = FALSE,
    min_iterations = 1,
    check = TRUE
)
print(res)