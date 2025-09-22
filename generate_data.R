library(data.table)
library(datasets)

file_name <- "measurements.csv"
chunk_size <- 1e8
n_rows <- as.integer(commandArgs(trailingOnly = TRUE))
cat("Creating dataset of", n_rows, "rows\n")

set.seed(2024)

first_chunk_size <- min(chunk_size, n_rows)
dt <- data.table(
  measurement = rnorm(first_chunk_size),
  state = sample(state.abb, first_chunk_size, replace = TRUE)
)
fwrite(dt, file_name)

if (n_rows > chunk_size) {
  for (start in seq(chunk_size + 1, n_rows, by = chunk_size)) {
    n <- min(chunk_size, n_rows - start + 1)
    dt <- data.table(
      measurement = rnorm(n),
      state = sample(state.abb, n, replace = TRUE)
    )
    fwrite(dt, file_name, append = TRUE, col.names = FALSE)
    cat("Written rows", start, "to", start + n - 1, "for", n_rows, "\n")
  }
}

size <- structure(file.info(file_name)$size, class = "object_size") |>
  format("auto")
message(
  "Finished saving dataset \"",
  file_name,
  "\". Its file size is: ",
  size,
  "."
)
