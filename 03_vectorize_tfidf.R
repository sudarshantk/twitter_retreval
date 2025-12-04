#!/usr/bin/env Rscript
# 03_vectorize_tfidf.R — Build TF-IDF matrix with text2vec, save artifacts

suppressPackageStartupMessages({
  library(readr)
  library(text2vec)
})

input_path <- file.path("data", "clean_tweets.csv")
tfidf_rds <- file.path("data", "tfidf.rds")

if (!file.exists(input_path)) stop("Cleaned tweets not found. Run 02_preprocess.R first.")
df <- readr::read_csv(input_path, show_col_types = FALSE)
texts <- df$text_clean

tokenizer <- text2vec::word_tokenizer
it <- itoken(texts, tokenizer = tokenizer, progressbar = FALSE)

vocab <- create_vocabulary(it)
vocab <- prune_vocabulary(vocab, term_count_min = 2)
vectorizer <- vocab_vectorizer(vocab)
dtm <- create_dtm(it, vectorizer)

tfidf <- TfIdf$new()
dtm_tfidf <- tfidf$fit_transform(dtm)

artifacts <- list(
  vocab = vocab,
  tfidf = tfidf,
  dtm = dtm_tfidf,
  terms = colnames(dtm)
)

saveRDS(artifacts, tfidf_rds)
message("TF-IDF artifacts saved to ", tfidf_rds)