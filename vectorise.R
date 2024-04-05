library(purrr)
library(tibble)
library(dplyr)
library(data.table)

file_name <- 'measurements.1e6.csv'
# file_name <- 'measurements.1e9.csv'

states <- c(
    "NC", "MA", "TX", "VT", "OR", "NY", "ND", "NV", "SD", "IN", 
    "ID", "RI", "TN", "SC", "PA", "WV", "CT", "NE", "KY", "DE", 
    "MT", "ME", "AL", "WI", "IA", "MI", "UT", "LA", "WA", "NM", 
    "AR", "MO", "MD", "MN", "KS", "AK", "OK", "NH", "NJ", "AZ", 
    "CA", "HI", "IL", "GA", "WY", "CO", "MS", "VA", "OH", "FL"
)

con <- file(file_name, 'r');
batch <- 100000
invisible(readLines(con, n = 1))
lines <- readLines(con, n = batch)
close(con)

process_batch_lines <- \(lines) {
    stations <- vector(mode = "list", length = 50)
    for (state in states) {
        stations[[state]] <- c(99999, -99999, 0, 0)
    }
    map(lines, \(line) {
        line_vector <- stringr::str_split_1(line,",")
        measurement <- as.double(line_vector[1])
        state <- line_vector[2]
        station <- stations[[state]]
        stations[[state]] <<- c(
            min(station[1], measurement),
            max(station[2], measurement),
            sum(station[3], measurement),
            sum(station[4], 1)
        )
    })
    stations
}
# process_batch_lines(lines)

process_batch_string_index <- \(lines) {
    lines_list <- strsplit(lines, ",", fixed = TRUE) 
    lines_vector <- unlist(lines_list)
    index <- (1:length(lines_list)) %% 2
    measurement <- as.double(lines_vector[index])
    state <- lines_vector[!index]
    df <-
        data.table(
            measurement = measurement,
            state = state
        ) |>
        summarise(
            .by = state,
            min = min(measurement),
            max = max(measurement),
            n = n(),
        )
    df
}
# print(process_batch_string_index(lines))


process_batch_base <- \(lines) {
    lines_list <- strsplit(lines, ",", fixed = TRUE) 
    lines_vector <- unlist(lines_list)
    index <- (1:length(lines_list)) %% 2
    measurement <- as.double(lines_vector[index])
    state <- lines_vector[!index]
    split_measurement <- split(measurement, state)
    summary_stats <- sapply(split_measurement, function(x) c(min(x), max(x), sum(x), length(x)))
    summary_stats <- as.data.frame(t(summary_stats))
    colnames(summary_stats) <- c("Min", "Max", "Sum", "Count")
    summary_stats
}

res <- bench::mark(
    process_batch_string_index = {
        string_index_result <- process_batch_string_index(lines)
    },
    process_batch_base = {
        process_batch_base_result <- process_batch_base(lines)
    },
    filter_gc = FALSE,
    min_iterations = 1,
    check = FALSE
)
print(res)

# lt <- lengths(touches)
# groups <- rep.int(seq_along(touches), lt)
# outcome <- rep.int(outcome, lt)
# value <- rep.int(value, lt) 
# touches <- unlist(touches)
# dates <- unlist(strsplit(date_str, ">", fixed = TRUE))
# not_empty <- touches != ''
# dates <- dates[not_empty] 
# touches <- touches[not_empty]
# re <- lu[touches]

con <- file(file_name, 'r')
lines <- readLines(con, n = batch)
while (!is.na(lines[1])) {
    print(is.na(lines[1]))
    lines <- readLines(con, n = batch)
}
close(con)