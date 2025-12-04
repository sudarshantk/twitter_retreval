#!/usr/bin/env Rscript
# 06_eval.R — Evaluate retrieval with Precision@K, MAP, nDCG; plot results

# Ensure per-user library path is available (Windows)
user_lib <- file.path(path.expand("~"), "Documents", "R", "win-library",
                     paste0(R.version$major, ".", R.version$minor))
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

source("05_search.R")

queries <- c("ai", "machine learning", "data science")
methods <- c("tfidf", "glove", "bert")
k_values <- c(5, 10)

# Dummy relevance: binary 1 if original text contains query term(s)
is_relevant <- function(text, query) {
  q_terms <- str_split(tolower(query), "\\s+")[[1]]
  any(str_detect(tolower(text), str_c(q_terms, collapse = "|")))
}

precision_at_k <- function(ranked_texts, query, k = 10) {
  labs <- as.integer(vapply(ranked_texts, is_relevant, query = query, FUN.VALUE = logical(1)))
  sum(labs[seq_len(min(k, length(labs)))]) / k
}

average_precision <- function(ranked_texts, query) {
  labs <- as.integer(vapply(ranked_texts, is_relevant, query = query, FUN.VALUE = logical(1)))
  rel_indices <- which(labs == 1)
  if (length(rel_indices) == 0) return(0)
  precs <- vapply(seq_along(rel_indices), function(i) {
    k <- rel_indices[i]
    sum(labs[seq_len(k)]) / k
  }, FUN.VALUE = numeric(1))
  mean(precs)
}

ndcg_at_k <- function(ranked_texts, query, k = 10) {
  labs <- as.integer(vapply(ranked_texts, is_relevant, query = query, FUN.VALUE = logical(1)))
  k <- min(k, length(labs))
  gains <- labs[seq_len(k)]
  dcg <- sum((2^gains - 1) / log2(2:(k + 1)))
  igains <- sort(labs, decreasing = TRUE)[seq_len(k)]
  idcg <- sum((2^igains - 1) / log2(2:(k + 1)))
  if (idcg == 0) return(0)
  dcg / idcg
}

results <- list()
for (m in methods) {
  for (q in queries) {
    res <- search_tweets(q, method = m, top_n = 50)
    if (nrow(res) == 0) next
    texts <- res$text
    for (k in k_values) {
      p_at_k <- precision_at_k(texts, q, k)
      ap <- average_precision(texts, q)
      ndcg <- ndcg_at_k(texts, q, k)
      results[[length(results) + 1]] <- tibble(
        method = m, query = q, k = k,
        precision_at_k = p_at_k, MAP = ap, nDCG = ndcg
      )
    }
  }
}

metrics_df <- dplyr::bind_rows(results)
print(metrics_df)

# Aggregate by method for plotting
agg <- metrics_df %>% 
  dplyr::group_by(method) %>% 
  dplyr::summarize(
    precision_at_5 = mean(precision_at_k[k == 5]),
    precision_at_10 = mean(precision_at_k[k == 10]),
    MAP = mean(MAP),
    nDCG_10 = mean(nDCG[k == 10])
  ) %>% dplyr::ungroup() %>% 
  tidyr::pivot_longer(cols = -method, names_to = "metric", values_to = "score")

plot_path <- file.path("outputs", "eval_metrics.png")
p <- ggplot(agg, aes(x = method, y = score, fill = method)) +
  geom_col(position = position_dodge()) +
  facet_wrap(~ metric, scales = "free_y") +
  theme_minimal() +
  labs(title = "Retrieval Metrics by Method", x = "Method", y = "Score") +
  guides(fill = "none")

ggsave(plot_path, p, width = 10, height = 6)
message("Saved metrics plot to ", plot_path)