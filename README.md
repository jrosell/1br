
## 1br

### Introduction

1 Billion Row challenge with R:

- This is the repo inspired by [Gunnar
  Morlng’s](https://www.morling.dev/blog/one-billion-row-challenge/) 1
  billion row challenge to see which functions / libraries are quickest
  in summarizing the mean, min and max of a 1 billion rows of record
- This work is based on
  [alejandrohagan/1br](https://github.com/alejandrohagan/1br) and
  [\#5](https://github.com/alejandrohagan/1br/issues/5), but I’ve only
  used 1e8 rows.
- I added some duckdb options and polars scan option. In order to do it
  I’ve added a file copy and file reading steps in each benchmark method
  to be sure to compare the pipelines without caching and a maximum of 8
  threads.
- If you see any issues or have suggestions of improvements, please let
  me know.

Note: 1 billion in english = 1 millardo en español = 10e9

### Instructions

- If you need, execute install_required_packages(install = TRUE) from
  install.R file.
- Generate 1e5, 1e6, 1e7, 1e8, 1e9 data running: ./generate_data.sh
- Run the benchmark running: Rscript run.R or Rscript run-all.R. You can
  execute run-small.R to run only 1e5, 1e6, 1e7, 1e8.
- Check the generated plots and the results.

### Results

#### 2025-09-21

``` r
library(tidyverse)
read_rds(here::here("output", "2025-09-21_all.rds")) |> 
  select(n, expression, median) |> 
  group_by(n) |> 
  arrange(median) |>   
  group_map(\(x, group) {
    x |> mutate(n = group$n) |> print()    
  }) |> 
  invisible()
```

    ## # A tibble: 12 × 3
    ##    expression             median n    
    ##    <bch:expr>             <bch:> <chr>
    ##  1 DT_datatable            310ms 1e6  
    ##  2 DT_dplyr                312ms 1e6  
    ##  3 DT_datatable_range      313ms 1e6  
    ##  4 scan_tidypolars_dplyr   316ms 1e6  
    ##  5 scan_polars             317ms 1e6  
    ##  6 scan_tidypolars_dplyr…  318ms 1e6  
    ##  7 scan_polars_streaming   323ms 1e6  
    ##  8 arrow                   326ms 1e6  
    ##  9 dtplyr                  330ms 1e6  
    ## 10 duckdb_import_parallel  406ms 1e6  
    ## 11 duckdb_dplyr_parallel   491ms 1e6  
    ## 12 duckdb_dplyr            518ms 1e6  
    ## # A tibble: 12 × 3
    ##    expression             median n    
    ##    <bch:expr>           <bch:tm> <chr>
    ##  1 scan_tidypolars_dpl… 636.41ms 1e7  
    ##  2 duckdb_import_paral… 666.88ms 1e7  
    ##  3 scan_tidypolars_dpl… 688.49ms 1e7  
    ##  4 scan_polars_streami… 688.66ms 1e7  
    ##  5 scan_polars          728.12ms 1e7  
    ##  6 duckdb_dplyr_parall… 747.71ms 1e7  
    ##  7 duckdb_dplyr         806.42ms 1e7  
    ##  8 DT_datatable_range   864.66ms 1e7  
    ##  9 DT_datatable            1.16s 1e7  
    ## 10 dtplyr                  1.16s 1e7  
    ## 11 DT_dplyr                1.59s 1e7  
    ## 12 arrow                    1.6s 1e7  
    ## # A tibble: 12 × 3
    ##    expression             median n    
    ##    <bch:expr>             <bch:> <chr>
    ##  1 duckdb_import_parallel   3.1s 1e8  
    ##  2 duckdb_dplyr            3.21s 1e8  
    ##  3 duckdb_dplyr_parallel   3.21s 1e8  
    ##  4 scan_tidypolars_dplyr…  3.84s 1e8  
    ##  5 scan_tidypolars_dplyr   5.27s 1e8  
    ##  6 scan_polars             5.28s 1e8  
    ##  7 scan_polars_streaming   5.34s 1e8  
    ##  8 DT_datatable            7.19s 1e8  
    ##  9 DT_datatable_range      7.73s 1e8  
    ## 10 dtplyr                  7.78s 1e8  
    ## 11 arrow                   9.57s 1e8  
    ## 12 DT_dplyr                9.89s 1e8  
    ## # A tibble: 12 × 3
    ##    expression             median n    
    ##    <bch:expr>             <bch:> <chr>
    ##  1 duckdb_import_parallel  3.12s 1e9  
    ##  2 duckdb_dplyr_parallel   3.19s 1e9  
    ##  3 duckdb_dplyr            3.27s 1e9  
    ##  4 scan_tidypolars_dplyr…  3.75s 1e9  
    ##  5 scan_tidypolars_dplyr   5.17s 1e9  
    ##  6 scan_polars             5.25s 1e9  
    ##  7 scan_polars_streaming   5.32s 1e9  
    ##  8 DT_datatable            7.09s 1e9  
    ##  9 dtplyr                   7.9s 1e9  
    ## 10 DT_datatable_range      7.92s 1e9  
    ## 11 DT_dplyr                 9.5s 1e9  
    ## 12 arrow                    9.7s 1e9

![](output/2025-09-21_1e6_rows.png)

![](output/2025-09-21_1e7_rows.png)

![](output/2025-09-21_1e8_rows.png)

![](output/2025-09-21_1e9_rows.png)

![](output/2025-09-21_all_rows.png)

#### 2024-02-29

![](output/2024-02-29_1e6_rows.png)

![](output/2024-02-29_1e7_rows.png)

![](output/2024-02-29_1e8_rows.png)

![](output/2024-02-29_all_rows.png)

### What can you do?

If you want, you have time and enough memory available in your computer,
then you can try get the results:

- Generate 1e6, 1e7, 1e8 or 1e9 data running ./generate_data.sh
- Run the benchmark running Rscript run.R
- Check the generated plots.
- Compare with other languages and solutions (Look at compare.php or
  onebrc for for rust)

Feedback is welcome. You can open an issue in this repo.
