#!/usr/bin/env Rscript
# 05_search.R — Semantic search: embed query, compute cosine similarity, return top results

# Ensure per-user library path is available (Windows)
user_lib <- file.path(path.expand("~"), "Documents", "R", "win-library",
                     paste0(R.version$major, ".", R.version$minor))
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(text2vec)
  library(stringr)
  library(Matrix)
})

# Ensure reticulate uses the project-local Python venv when available (for BERT)
try({
  venv_py <- normalizePath(file.path(getwd(), ".venv", "Scripts", "python.exe"),
                           winslash = "\\", mustWork = FALSE)
  if (file.exists(venv_py) && nzchar(venv_py)) {
    Sys.setenv(RETICULATE_PYTHON = venv_py)
  }
}, silent = TRUE)

# Helper to robustly extract a numeric embedding vector from text::textEmbed output
extract_text_embedding <- function(out) {
  # Generic deep search for a dense numeric vector (>= 100 dims)
  find_numeric <- function(x) {
    if (is.numeric(x)) return(as.numeric(x))
    if (is.matrix(x)) return(as.numeric(x[1, , drop = TRUE]))
    if (inherits(x, "tbl") || is.data.frame(x)) {
      # Prefer columns named like Dim*
      cn <- colnames(x);
      dim_cols <- grep("^Dim", cn, value = TRUE)
      if (length(dim_cols) > 0) return(as.numeric(x[1, dim_cols]))
      return(as.numeric(x[1, , drop = TRUE]))
    }
    if (is.list(x)) {
      # Try common paths first
      if (!is.null(x$texts)) {
        cand <- find_numeric(x$texts)
        if (is.numeric(cand) && length(cand) >= 100) return(cand)
      }
      if (!is.null(x$sentence_embeddings)) {
        cand <- find_numeric(x$sentence_embeddings)
        if (is.numeric(cand) && length(cand) >= 100) return(cand)
      }
      if (!is.null(x$embeddings)) {
        cand <- find_numeric(x$embeddings)
        if (is.numeric(cand) && length(cand) >= 100) return(cand)
      }
      # Otherwise search each element
      for (nm in names(x)) {
        cand <- find_numeric(x[[nm]])
        if (is.numeric(cand) && length(cand) >= 100) return(cand)
      }
      # Flatten list of scalars
      vec <- tryCatch(unlist(x, use.names = FALSE), error = function(e) NULL)
      if (is.numeric(vec) && length(vec) >= 100) return(as.numeric(vec))
    }
    NULL
  }
  vec <- find_numeric(out)
  if (!is.null(vec)) return(vec)
  # Prefer sentence-level embeddings when available
  if (is.list(out)) {
    if (!is.null(out$sentence_embeddings) && !is.null(out$sentence_embeddings$texts)) {
      tx <- out$sentence_embeddings$texts
      if (is.matrix(tx)) return(as.numeric(tx[1, , drop = TRUE]))
      if (is.data.frame(tx)) return(as.numeric(tx[1, , drop = TRUE]))
      if (is.list(tx)) {
        # Handle list-of-scalars structure (Dim1_texts, Dim2_texts, ...)
        vec <- tryCatch(unlist(tx, use.names = FALSE), error = function(e) NULL)
        if (!is.null(vec)) return(as.numeric(vec))
      }
    }
    # Older versions expose under embeddings$texts
    if (!is.null(out$embeddings)) {
      emb <- out$embeddings
      if (!is.null(emb$texts)) {
        tx <- emb$texts
        if (is.matrix(tx)) return(as.numeric(tx[1, , drop = TRUE]))
        if (is.data.frame(tx)) return(as.numeric(tx[1, , drop = TRUE]))
        if (is.list(tx)) {
          vec <- tryCatch(unlist(tx, use.names = FALSE), error = function(e) NULL)
          if (!is.null(vec)) return(as.numeric(vec))
        }
      }
      # Try any matrix-like item inside embeddings
      for (nm in names(emb)) {
        item <- emb[[nm]]
        if (is.matrix(item)) return(as.numeric(item[1, , drop = TRUE]))
        if (is.data.frame(item)) return(as.numeric(as.matrix(item[1, , drop = TRUE])))
      }
    }
    # Some versions return out$texts as matrix/data.frame
    if (!is.null(out$texts)) {
      tx <- out$texts
      if (is.matrix(tx)) return(as.numeric(tx[1, , drop = TRUE]))
      if (is.data.frame(tx)) return(as.numeric(tx[1, , drop = TRUE]))
    }
    # Fallback: flatten any list to numeric
    vec <- tryCatch(unlist(out, use.names = FALSE), error = function(e) NULL)
    if (!is.null(vec)) return(as.numeric(vec))
  }
  if (is.matrix(out)) return(as.numeric(out[1, , drop = TRUE]))
  if (is.data.frame(out)) return(as.numeric(out[1, , drop = TRUE]))
  if (is.numeric(out)) return(as.numeric(out))
  NULL
}

df_path <- file.path("data", "clean_tweets.csv")
tfidf_rds <- file.path("data", "tfidf.rds")
glove_vecs_rds <- file.path("data", "glove_word_vectors.rds")
glove_sent_rds <- file.path("data", "glove_embeddings.rds")
bert_rds <- file.path("data", "bert_embeddings.rds")

if (!file.exists(df_path)) stop("Cleaned tweets not found. Run 02_preprocess.R first.")
df <- readr::read_csv(df_path, show_col_types = FALSE)

safe_norm <- function(x) {
  s <- sqrt(sum(x^2, na.rm = TRUE))
  if (is.na(s) || s == 0) 1e-8 else s
}

# Robust coercion helpers
as_numeric_matrix <- function(x) {
  if (is.null(x)) stop("Corpus matrix is NULL")
  if (inherits(x, "Matrix")) x <- as.matrix(x)
  if (is.data.frame(x)) x <- as.matrix(x)
  if (is.list(x)) {
    x2 <- tryCatch(as.matrix(do.call(rbind, x)), error = function(e) NULL)
    if (is.null(x2)) stop("Cannot coerce corpus to numeric matrix")
    x <- x2
  }
  storage.mode(x) <- "double"
  if (length(dim(x)) != 2) stop("Corpus is not two-dimensional")
  x
}

as_numeric_vector <- function(v, d = NULL) {
  if (is.list(v)) v <- unlist(v, use.names = FALSE)
  if (is.matrix(v) || is.data.frame(v)) v <- as.numeric(v)
  v <- as.numeric(v)
  if (!is.null(d) && length(v) != d) {
    if (length(v) < d) v <- c(v, rep(0, d - length(v))) else v <- v[seq_len(d)]
  }
  v
}
cosine_sim <- function(mat, vec) {
  # Ensure numeric matrix/vector
  mat <- as_numeric_matrix(mat)
  vec <- as_numeric_vector(vec, ncol(mat))
  # mat: n x d, vec: d
  sims <- as.numeric(mat %*% vec)
  mat_norms <- sqrt(rowSums(mat^2)); mat_norms[mat_norms == 0] <- 1e-8
  sims / (mat_norms * safe_norm(vec))
}

embed_query_tfidf <- function(query) {
  arts <- readRDS(tfidf_rds)
  vocab <- arts$vocab
  tfidf <- arts$tfidf
  dtm <- arts$dtm
  tokenizer <- text2vec::word_tokenizer
  it <- itoken(query, tokenizer = tokenizer, progressbar = FALSE)
  v <- vocab_vectorizer(vocab)
  dtm_q <- create_dtm(it, v)
  vec_q <- tfidf$transform(dtm_q)
  # Convert sparse query vector to dense numeric of matching dimension
  q_dense <- as.numeric(as.matrix(vec_q))
  list(query = q_dense, corpus = dtm)
}

embed_query_glove <- function(query) {
  wv <- readRDS(glove_vecs_rds)
  glove_raw <- readRDS(glove_sent_rds)$embeddings
  # Unwrap nested structures if present
  while (is.list(glove_raw) && !is.null(glove_raw$embeddings)) {
    glove_raw <- glove_raw$embeddings
  }
  glove_sent <- tryCatch({
    if (is.matrix(glove_raw)) {
      storage.mode(glove_raw) <- "double"
      glove_raw
    } else if (is.data.frame(glove_raw)) {
      as.matrix(glove_raw)
    } else if (is.list(glove_raw)) {
      cand <- tryCatch(as.matrix(do.call(rbind, glove_raw)), error = function(e) NULL)
      if (is.null(cand)) stop("GloVe sentence embeddings not in matrix form")
      storage.mode(cand) <- "double"
      cand
    } else {
      stop("Unrecognized GloVe embeddings type")
    }
  }, error = function(e) {
    stop(conditionMessage(e))
  })
  tokenizer <- text2vec::word_tokenizer
  toks <- tokenizer(query)[[1]]
  iv <- intersect(toks, rownames(wv))
  if (length(iv) == 0) qv <- rep(0, ncol(wv)) else qv <- colMeans(wv[iv, , drop = FALSE])
  list(query = qv, corpus = glove_sent)
}

embed_query_bert <- function(query) {
  be <- readRDS(bert_rds)
  mat_raw <- be$embeddings
  # Unwrap nested structures if present
  while (is.list(mat_raw) && !is.null(mat_raw$embeddings)) {
    mat_raw <- mat_raw$embeddings
  }
  mat <- tryCatch({
    if (is.matrix(mat_raw)) {
      storage.mode(mat_raw) <- "double"
      mat_raw
    } else if (is.data.frame(mat_raw)) {
      as.matrix(mat_raw)
    } else if (is.list(mat_raw)) {
      cand <- tryCatch(as.matrix(do.call(rbind, mat_raw)), error = function(e) NULL)
      if (is.null(cand)) stop("BERT embeddings are not a numeric matrix; using GloVe fallback")
      storage.mode(cand) <- "double"
      cand
    } else {
      stop("Unrecognized BERT embeddings type; using GloVe fallback")
    }
  }, error = function(e) {
    message(conditionMessage(e))
    readRDS(glove_sent_rds)$embeddings
  })
  # Guard against empty or non-2D corpus; fallback to GloVe sentence embeddings
  used_glove_corpus <- FALSE
  if (is.null(dim(mat)) || length(dim(mat)) != 2 || nrow(mat) == 0 || ncol(mat) == 0) {
    message("BERT corpus embeddings empty; falling back to GloVe corpus.")
    mat <- readRDS(glove_sent_rds)$embeddings
    used_glove_corpus <- TRUE
  }
  # Attempt to embed query using text::textEmbed
  qv <- tryCatch({
    if (used_glove_corpus) {
      # Align query to GloVe when corpus uses GloVe
      embed_query_glove(query)$query
    } else {
      if (!requireNamespace("text", quietly = TRUE)) stop("Package 'text' not available")
      # Use a lighter sentence-transformers model for faster query embedding
      out <- text::textEmbed(query, model = "sentence-transformers/all-MiniLM-L6-v2")
      vec <- extract_text_embedding(out)
      if (is.null(vec)) stop("Unsupported query embedding structure")
      vec
    }
  }, error = function(e) {
    message("BERT query embedding failed: ", conditionMessage(e), ". Falling back to GloVe.")
    embed_query_glove(query)$query
  })
  # Ensure query length matches corpus columns
  qv <- as_numeric_vector(qv, ncol(mat))
  list(query = qv, corpus = mat)
}

search_tweets <- function(query, method = c("tfidf", "glove", "bert"), top_n = 10) {
  method <- match.arg(method)
  q <- str_squish(tolower(query))
  if (nchar(q) == 0) stop("Query must be non-empty.")
  emb <- switch(method,
    tfidf = embed_query_tfidf(q),
    glove = embed_query_glove(q),
    bert  = embed_query_bert(q)
  )
  sims <- cosine_sim(emb$corpus, emb$query)
  ord <- order(sims, decreasing = TRUE)
  idx <- head(ord, top_n)
  tibble::tibble(
    rank = seq_along(idx),
    similarity = sims[idx],
    text = df$text[idx],
    text_clean = df$text_clean[idx]
  )
}

# Example CLI usage (only when invoked with arguments)
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 0) {
    q <- paste(args, collapse = " ")
    res <- tryCatch(search_tweets(q, method = "bert", top_n = 10), error = function(e) e)
    print(res)
  }
}