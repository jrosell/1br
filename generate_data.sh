Rscript --vanilla generate_data.R 1e6
cp measurements.csv measurements.1e6.csv

Rscript --vanilla generate_data.R 1e7
cp measurements.csv measurements.1e7.csv

Rscript --vanilla generate_data.R 1e8
cp measurements.csv measurements.1e8.csv

# Rscript --vanilla generate_data.R 1e9
# cp measurements.csv measurements.1e9.csv