# Optional Dockerfile for running the Shiny app

FROM rocker/r-ver:4.3.2

# System deps for compilation
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Install required R packages
RUN R -e "install.packages(c('rtweet','tm','tidyverse','quanteda','text2vec','text','stringr','proxy','SnowballC','shiny','ggplot2','textfeatures','reticulate'), dependencies=TRUE)"

# Expose Shiny port
EXPOSE 8080

# Run the Shiny app; 07_shiny_app.R starts the server on port 8080
CMD ["Rscript", "07_shiny_app.R"]