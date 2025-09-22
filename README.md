
## 1br

### Introduction

This is 1 Billion Row challenge with R. <em>Note that 1 billion in
english = 1 millardo en español = 10e9.</em>

- This is the repo inspired by [Gunnar
  Morlng’s](https://www.morling.dev/blog/one-billion-row-challenge/) 1
  billion row challenge to see which functions / libraries are quickest
  in summarizing the mean, min and max of a 1 billion rows of record
- This work is based on
  [alejandrohagan/1br](https://github.com/alejandrohagan/1br) and
  [\#5](https://github.com/alejandrohagan/1br/issues/5).
- I added some duckdb options and the polars scan option. In order to do
  it I’ve added a file copy and file reading steps in each benchmark
  method to be sure to compare the pipelines without caching and a
  maximum of 8 threads.
- If you see any issues or have suggestions of improvements, please let
  me know.

### Instructions

- Generate 1e5, 1e6, 1e7, 1e8, 1e9 data running: ./generate_data.sh
- Run the benchmark running: Rscript run.R or Rscript run_all.R (Or
  execute run_small.R if you noly want to run only 1e5, 1e6, 1e7, 1e8).
- Check the generated plots and the results.

### Results

#### 2025-09-22

It seems that duckdb, duckplyr and dplyr (with duckdb or tidypolars
streaming backends) are good options for 1e9 rows.

``` r
suppressPackageStartupMessages(library(tidyverse))

read_rds(here::here("output", "2025-09-22_all.rds")) |> 
  select(n, expression, median) |> 
  mutate(expression = map_chr(expression, deparse1)) |>
  mutate(expression = map_chr(expression, ~ {
    str_match(.x, 'print\\(\\"([^\\"]+)\\"\\)')[,2]
  })) |> 
  group_by(n) |> 
  arrange(median) |>   
  group_map(\(x, group) {
    x |> mutate(n = group$n) |> print()    
  }) |> 
  invisible()
```

    ## # A tibble: 5 × 3
    ##   expression                        median n    
    ##   <chr>                           <bch:tm> <chr>
    ## 1 scan_tidypolars_dplyr_streaming    175ms 1e6  
    ## 2 duckdb_import_parallel             259ms 1e6  
    ## 3 read_csv_duckdb                    259ms 1e6  
    ## 4 duckdb_dplyr_parallel              367ms 1e6  
    ## 5 duckdb_dplyr                       412ms 1e6  
    ## # A tibble: 5 × 3
    ##   expression                        median n    
    ##   <chr>                           <bch:tm> <chr>
    ## 1 scan_tidypolars_dplyr_streaming    485ms 1e7  
    ## 2 duckdb_import_parallel             529ms 1e7  
    ## 3 read_csv_duckdb                    542ms 1e7  
    ## 4 duckdb_dplyr_parallel              649ms 1e7  
    ## 5 duckdb_dplyr                       695ms 1e7  
    ## # A tibble: 5 × 3
    ##   expression                        median n    
    ##   <chr>                           <bch:tm> <chr>
    ## 1 duckdb_import_parallel             2.89s 1e8  
    ## 2 read_csv_duckdb                    2.92s 1e8  
    ## 3 duckdb_dplyr_parallel              2.98s 1e8  
    ## 4 duckdb_dplyr                       3.02s 1e8  
    ## 5 scan_tidypolars_dplyr_streaming    3.42s 1e8  
    ## # A tibble: 5 × 3
    ##   expression                        median n    
    ##   <chr>                           <bch:tm> <chr>
    ## 1 duckdb_dplyr_parallel              40.6s 1e9  
    ## 2 duckdb_dplyr                       40.7s 1e9  
    ## 3 duckdb_import_parallel             40.9s 1e9  
    ## 4 read_csv_duckdb                    41.8s 1e9  
    ## 5 scan_tidypolars_dplyr_streaming      49s 1e9

![](output/2025-09-22_1e9_rows.png)

![](output/2025-09-22_all_rows.png)

#### 2024-02-29

![](output/2024-02-29_all_rows.png)

### What can you do?

If you want, you have time and enough memory available in your computer,
then you can try to run the benchmark yourself and get the results.

If you what, look at other languages solutions (run.php for PHP, run.cpp
for C++ or onebrc/src/main.rs for rust)

Feedback is welcome. You can open an issue in this repo.
