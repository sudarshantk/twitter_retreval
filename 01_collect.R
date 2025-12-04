#!/usr/bin/env Rscript
# 01_collect.R — Collect tweets using Twitter API v2 (bearer) or rtweet fallback; otherwise sample CSV

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(httr2)
  library(jsonlite)
})

terms <- c("AI", "machine learning", "data science")
outfile <- file.path("data", "collected_tweets.csv")
sample_path <- file.path("data", "sample_tweets.csv")
bearer_file <- file.path("data", "bearer_token.txt")

# Allow CLI args: first arg is a query string or comma-separated topics; second is n
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1 && nzchar(args[1])) {
  # Split by comma and trim
  terms <- strsplit(args[1], ",")[[1]]
  terms <- stringr::str_trim(terms)
}
if (length(args) >= 2 && nzchar(args[2])) {
  n_total <- suppressWarnings(as.integer(args[2]))
  if (!is.na(n_total) && n_total > 0) {
    options(collect_n = n_total)
  }
}

collect_tweets <- function(query_terms, n = getOption("collect_n", 500)) {
  # Try bearer-based recent search via direct API first (most reliable across rtweet versions)
  message("Attempting to collect tweets via Twitter API v2 (bearer)...")
  res <- NULL

  # Load bearer token from env or file
  bt <- Sys.getenv("TWITTER_BEARER_TOKEN", unset = Sys.getenv("RTWEET_BEARER", unset = ""))
  if (!nzchar(bt) && file.exists(bearer_file)) {
    bt_lines <- tryCatch(readLines(bearer_file, warn = FALSE), error = function(e) "")
    bt <- stringr::str_squish(bt_lines[which(nchar(bt_lines) > 0)][1])
    if (nzchar(bt)) {
      message("Using bearer token from ", bearer_file)
      Sys.setenv(TWITTER_BEARER_TOKEN = bt)
    }
  }
  if (nzchar(bt) && grepl("%", bt, fixed = TRUE)) {
    bt <- utils::URLdecode(bt)
  }

  # Helper: one query via v2 recent search with pagination
  recent_search_v2 <- function(q, target_n) {
    endpoint <- "https://api.twitter.com/2/tweets/search/recent"
    acc <- list()
    fetched <- 0L
    next_token <- NULL
    repeat {
      remain <- max(1L, target_n - fetched)
      page_n <- min(100L, remain) # API max per page
      req <- request(endpoint) |>
        req_auth_bearer_token(token = bt) |>
        req_url_query(
          query = q,
          max_results = page_n,
          `tweet.fields` = "id,text,created_at,lang",
          expansions = "author_id"
        )
      if (!is.null(next_token)) {
        req <- req_url_query(req, pagination_token = next_token)
      }
      resp <- tryCatch(req_perform(req), error = function(e) e)
      if (inherits(resp, "error")) {
        message("Recent search request failed: ", conditionMessage(resp))
        break
      }
      body <- tryCatch(resp_body_json(resp, simplifyVector = TRUE), error = function(e) NULL)
      if (is.null(body) || is.null(body$data)) {
        if (!is.null(body$meta) && !is.null(body$meta$result_count) && body$meta$result_count == 0) {
          message("No results returned for query: ", q)
        }
        break
      }
      dat <- as.data.frame(body$data, stringsAsFactors = FALSE)
      if (!"text" %in% names(dat)) {
        # Ensure text present; if not, skip
        message("No text field found in API response; skipping page.")
        break
      }
      acc[[length(acc) + 1L]] <- dat
      fetched <- fetched + nrow(dat)
      next_token <- body$meta$next_token
      if (is.null(next_token) || fetched >= target_n) break
    }
    if (length(acc) == 0) return(NULL)
    out <- dplyr::bind_rows(acc)
    # Normalize column names
    if ("id" %in% names(out)) out$status_id <- as.character(out$id)
    out
  }

  # Round-robin across terms
  res <- purrr::map_dfr(query_terms, function(q) {
    per_term <- ceiling(n / max(1L, length(query_terms)))
    recent_search_v2(q, per_term)
  })

  # If bearer API failed entirely, try rtweet fallback (older v1.1 search)
  if (is.null(res) && requireNamespace("rtweet", quietly = TRUE)) {
    message("Falling back to rtweet::search_tweets (v1.1)...")
    res <- tryCatch({
      purrr::map_dfr(query_terms, function(q) {
        per_term <- ceiling(n / max(1L, length(query_terms)))
        rtweet::search_tweets(q, n = per_term, lang = "en", include_rts = FALSE)
      })
    }, error = function(e) {
      message("rtweet fallback failed: ", conditionMessage(e))
      NULL
    })
  }

  res
}

fallback_to_sample <- function(sample_csv) {
  message("Falling back to local sample dataset: ", sample_csv)
  readr::read_csv(sample_csv, show_col_types = FALSE) |> 
    dplyr::mutate(text = as.character(text))
}

tweets <- collect_tweets(terms, n = 600)

if (is.null(tweets) || !("text" %in% names(tweets))) {
  if (!file.exists(sample_path)) {
    stop("Sample dataset not found at ", sample_path)
  }
  tweets <- fallback_to_sample(sample_path)
} else {
  tweets <- dplyr::select(tweets, dplyr::any_of(c("status_id", "created_at", "text")))
}

# Normalize structure
if (!"status_id" %in% names(tweets)) {
  tweets$status_id <- as.character(seq_len(nrow(tweets)))
}
if (!"created_at" %in% names(tweets)) {
  tweets$created_at <- Sys.time()
}
tweets <- dplyr::select(tweets, status_id, created_at, text)

readr::write_csv(tweets, outfile)
message("Saved collected tweets to ", outfile)