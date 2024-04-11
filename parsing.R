file_size <- '1e6'
file_name <- paste0('measurements.', file_size, '.csv')

states <- c(
    "NC", "MA", "TX", "VT", "OR", "NY", "ND", "NV", "SD", "IN", 
    "ID", "RI", "TN", "SC", "PA", "WV", "CT", "NE", "KY", "DE", 
    "MT", "ME", "AL", "WI", "IA", "MI", "UT", "LA", "WA", "NM", 
    "AR", "MO", "MD", "MN", "KS", "AK", "OK", "NH", "NJ", "AZ", 
    "CA", "HI", "IL", "GA", "WY", "CO", "MS", "VA", "OH", "FL"
)

# chunk_size <- as.numeric(file_size)
# con <- file(file_name)
# lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
# close(con)
# lines_list <- strsplit(lines, ",", fixed = TRUE, useBytes =  TRUE) 
# lines_vector <- unlist(lines_list, recursive = FALSE, use.names = FALSE)
# index <- (1:length(lines_list) %% 2) == 1
# split_measurement <- split(as.double(lines_vector[index]), lines_vector[!index])
# summary_stats <- vapply(split_measurement, function(x) c(min(x), max(x), mean(x)), double(3))
# summary_stats

res <- bench::mark(
    str_extract = {
        chunk_size <- as.numeric(file_size)
        con <- file(file_name)
        lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
        close(con)
        m <- lines |> 
            stringr::str_extract("(\\d+),(.*)", group = c(1, 2)) |> 
            unlist(recursive = FALSE, use.names = FALSE)
        temps <- m[,1]
        names(temps) <- m[,2]
        temps
    },
    strsplit = {
        chunk_size <- as.numeric(file_size)
        con <- file(file_name)
        lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
        close(con)
        lines_vector <- lines |>
            strsplit(split = ",") |> 
            unlist(recursive = FALSE, use.names = FALSE)
        index <- (1:length(lines_vector) %% 2) == 1
        temps <- lines_vector[index]
        names(temps) <- lines_vector[!index]
        temps
    },
    strsplit_fixed = {
        chunk_size <- as.numeric(file_size)
        con <- file(file_name)
        lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
        close(con)
        lines_vector <- lines |>
            strsplit(split = ',', fixed = TRUE) |> 
            unlist(recursive = FALSE, use.names = FALSE)
        index <- (1:length(lines_vector) %% 2) == 1
        temps <- lines_vector[index]
        names(temps) <- lines_vector[!index]
        temps
    },
    stringi = {
        chunk_size <- as.numeric(file_size)
        con <- file(file_name)
        lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
        close(con)
        lines_vector <- stringi::stri_split_fixed(lines, ',') |> 
            unlist(recursive = FALSE, use.names = FALSE)
        index <- (1:length(lines_vector) %% 2) == 1
        temps <- lines_vector[index]
        names(temps) <- lines_vector[!index]
        temps
    },
    stringi2 = {
        chunk_size <- as.numeric(file_size)
        con <- file(file_name)
        lines <- scan(con, n = chunk_size, skip = 1, what = character(), quiet = TRUE)
        close(con)
        lines_vector <- lines |>
            stringi::stri_split_fixed(pattern = ',') |> 
            unlist(recursive = FALSE, use.names = FALSE)
        index <- (1:length(lines_vector) %% 2) == 1
        temps <- lines_vector[index]
        names(temps) <- lines_vector[!index]
        temps
    },
    read_delim = {
        df <- read.delim(file_name, sep=",", header=TRUE)
        temps <- df$measurement
        names(temps) <- df$state
        temps
    },
    filter_gc = FALSE,
    min_iterations = 5,
    check = FALSE
)
print(res)