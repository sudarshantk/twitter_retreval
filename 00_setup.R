#!/usr/bin/env Rscript
# 00_setup.R — Install and load required packages; set up project folders

# List of required packages
required_packages <- c(
  # Core
  "readr", "dplyr", "purrr", "tidyr", "stringr",
  # NLP/Vectorization
  "quanteda", "text2vec", "tm", "SnowballC",
  # Embeddings and bridges
  "text", "reticulate",
  # App and viz
  "shiny", "ggplot2",
  # Optional / may be unavailable on this R version
  "rtweet", "proxy", "textfeatures"
)

ensure_package <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing package: ", pkg)
    options(repos = c(CRAN = "https://cloud.r-project.org"))
    try(install.packages(pkg, dependencies = TRUE), silent = TRUE)
  }
  silently_library(pkg)
}

## Ensure a writable user library on Windows (avoid Program Files permission issues)
user_lib <- tryCatch({
  file.path(Sys.getenv("USERPROFILE"), "Documents", "R", 
            paste0("win-library/", paste(R.version$major, R.version$minor, sep = ".")))
}, error = function(e) {
  NULL
})

if (!is.null(user_lib)) {
  dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_lib, .libPaths()))
  message("Using user library: ", user_lib)
}

# Load all packages safely
silently_library <- function(pkg) {
  tryCatch({
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    TRUE
  }, error = function(e) {
    message("Package not available or failed to load: ", pkg, "; proceeding with fallbacks.")
    FALSE
  })
}

invisible(lapply(required_packages, ensure_package))

# Create project directories
dir.create("data", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs", showWarnings = FALSE, recursive = TRUE)

# Use a fixed seed for reproducibility
set.seed(42)

message("Setup complete. Packages loaded and directories prepared.")