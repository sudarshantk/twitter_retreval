#!/usr/bin/env Rscript
# 00_realtime.R — End-to-end: collect via rtweet, preprocess, vectorize, embed

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)
query <- if (length(args) >= 1) args[1] else "AI,machine learning,data science"
count <- if (length(args) >= 2) suppressWarnings(as.integer(args[2])) else 500
if (is.na(count) || count <= 0) count <- 500

message("[Realtime] Collecting tweets for: ", query, " (n=", count, ")")
source("01_collect.R")
invisible(collect_tweets(strsplit(query, ",")[[1]] , n = count))

message("[Realtime] Preprocessing collected tweets...")
source("02_preprocess.R")

message("[Realtime] Building TF-IDF artifacts...")
source("03_vectorize_tfidf.R")

message("[Realtime] Generating embeddings (GloVe + BERT if available)...")
source("04_embed.R")

df <- readr::read_csv(file.path("data","clean_tweets.csv"), show_col_types = FALSE)
message("[Realtime] Done. Corpus size: ", nrow(df), " tweets. Files refreshed in data/.")