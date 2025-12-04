#!/usr/bin/env Rscript
# 02_preprocess.R — Clean text: URLs, mentions, hashtags, emojis, punctuation, lowercase, stopwords (no stemming, keep numbers)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(quanteda)
})

input_path <- file.path("data", "collected_tweets.csv")
sample_path <- file.path("data", "sample_tweets.csv")
output_path <- file.path("data", "clean_tweets.csv")

if (!file.exists(input_path)) {
  message("Collected tweets not found. Falling back to sample.")
  input_path <- sample_path
}

df <- readr::read_csv(input_path, show_col_types = FALSE)
stopifnot("text" %in% names(df))

clean_text <- function(x) {
  x <- tolower(x)
  # Remove URLs
  x <- str_replace_all(x, "http[s]?://\\S+", " ")
  x <- str_replace_all(x, "www\\.\\S+", " ")
  # Remove mentions and hashtags (keep word part for hashtags)
  x <- str_replace_all(x, "@[A-Za-z0-9_]+", " ")
  x <- str_replace_all(x, "#", " ")
  # Remove emojis & non-ASCII
  x <- iconv(x, from = "UTF-8", to = "ASCII", sub = "")
  # Remove punctuation (keep numbers)
  x <- str_replace_all(x, "[[:punct:]]", " ")
  # Collapse spaces
  x <- str_squish(x)
  x
}

tokenize_and_process <- function(x) {
  toks <- str_split(x, "\\s+")
  sw <- stopwords("en")
  toks <- lapply(toks, function(t) {
    t <- t[!(t %in% sw)]
    t <- t[nchar(t) > 1]
    t
  })
  sapply(toks, function(t) paste(t, collapse = " "))
}

df <- df %>% dplyr::mutate(text = as.character(text))
df <- df %>% dplyr::mutate(text_clean = clean_text(text))
df <- df %>% dplyr::mutate(text_clean = tokenize_and_process(text_clean))

readr::write_csv(df, output_path)
message("Saved cleaned tweets to ", output_path)