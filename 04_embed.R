#!/usr/bin/env Rscript
# 04_embed.R — Generate semantic embeddings: GloVe (trained) and BERT via text::textEmbed()

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(text2vec)
})

# Configure reticulate to use project-local Python venv for BERT embeddings
try({
  venv_py <- normalizePath(file.path(getwd(), ".venv", "Scripts", "python.exe"),
                           winslash = "\\", mustWork = FALSE)
  if (file.exists(venv_py) && nzchar(venv_py)) {
    Sys.setenv(RETICULATE_PYTHON = venv_py)
  }
}, silent = TRUE)

input_path <- file.path("data", "clean_tweets.csv")
glove_vecs_rds <- file.path("data", "glove_word_vectors.rds")
glove_sent_rds <- file.path("data", "glove_embeddings.rds")
bert_rds <- file.path("data", "bert_embeddings.rds")

if (!file.exists(input_path)) stop("Cleaned tweets not found. Run 02_preprocess.R first.")
df <- readr::read_csv(input_path, show_col_types = FALSE)
texts <- df$text_clean

# -----------------------------
# Train GloVe word vectors
# -----------------------------
message("Training GloVe word vectors (small rank for demo)...")
tokenizer <- text2vec::word_tokenizer
it <- itoken(texts, tokenizer = tokenizer, progressbar = FALSE)
vocab <- create_vocabulary(it)
vectorizer <- vocab_vectorizer(vocab)
it2 <- itoken(texts, tokenizer = tokenizer, progressbar = FALSE)
tcm <- create_tcm(it2, vectorizer, skip_grams_window = 5)

glove <- GlobalVectors$new(rank = 50, x_max = 10)
wv_main <- glove$fit_transform(tcm, n_iter = 20)
wv_context <- glove$components
word_vectors <- wv_main + t(wv_context)

saveRDS(word_vectors, glove_vecs_rds)
message("Saved GloVe word vectors to ", glove_vecs_rds)

# Sentence embeddings by averaging word vectors
message("Computing GloVe sentence embeddings (average of word vectors)...")
avg_embed <- function(text, wv) {
  toks <- tokenizer(text)[[1]]
  iv <- intersect(toks, rownames(wv))
  if (length(iv) == 0) return(rep(0, ncol(wv)))
  colMeans(wv[iv, , drop = FALSE])
}

glove_sent <- t(vapply(texts, avg_embed, wv = word_vectors, FUN.VALUE = numeric(ncol(word_vectors))))
colnames(glove_sent) <- paste0("glove_", seq_len(ncol(glove_sent)))

saveRDS(list(embeddings = glove_sent, ids = seq_len(nrow(df))), glove_sent_rds)
message("Saved GloVe sentence embeddings to ", glove_sent_rds)

# -----------------------------
# BERT embeddings via text::textEmbed()
# -----------------------------
message("Generating BERT embeddings via text::textEmbed (will fallback if unavailable)...")
bert_ok <- requireNamespace("text", quietly = TRUE)
bert_embeddings <- NULL

bert_try <- tryCatch({
  if (!bert_ok) stop("Package 'text' not available")
  # Use default model; text::textEmbed will manage backend via reticulate
  # Use a lighter sentence-transformers model to reduce download size and startup time
  out <- text::textEmbed(texts, model = "sentence-transformers/all-MiniLM-L6-v2")
  # Attempt to extract a sensible matrix
  if (is.list(out)) {
    if (!is.null(out$embeddings$texts)) {
      as.matrix(out$embeddings$texts)
    } else if (!is.null(out$texts)) {
      as.matrix(out$texts)
    } else {
      stop("Unexpected structure from textEmbed output")
    }
  } else if (is.matrix(out) || is.data.frame(out)) {
    as.matrix(out)
  } else {
    stop("Unsupported return type from textEmbed")
  }
}, error = function(e) {
  message("textEmbed failed or unavailable: ", conditionMessage(e))
  bert_ok <<- FALSE
  NULL
})

if (!is.null(bert_try)) {
  bert_embeddings <- bert_try
  saveRDS(list(embeddings = bert_embeddings, ids = seq_len(nrow(df))), bert_rds)
  message("Saved BERT embeddings to ", bert_rds)
} else {
  message("BERT unavailable; falling back to GloVe sentence embeddings for downstream use.")
  # Save a placeholder that indicates fallback
  saveRDS(list(embeddings = glove_sent, ids = seq_len(nrow(df)), fallback = TRUE), bert_rds)
}

message("Embedding generation complete.")