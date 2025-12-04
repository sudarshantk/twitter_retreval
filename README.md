# Semantic Information Retrieval on Twitter Using Data-Driven Text Mining

This R-based project implements an end-to-end pipeline for collecting tweets (via `rtweet` or a local CSV fallback), preprocessing text, vectorizing content (TF-IDF), generating semantic embeddings (GloVe and BERT via `text::textEmbed()`), performing similarity-based retrieval, evaluating ranking quality, and exposing an interactive Shiny dashboard.

## File Structure
- `00_setup.R` — installs and loads packages; creates folders
- `01_collect.R` — collects tweets via `rtweet`, falls back to `data/sample_tweets.csv`
- `02_preprocess.R` — cleans text (URLs, mentions, hashtags, emojis, punctuation), lowercases, removes stopwords, stems
- `03_vectorize_tfidf.R` — builds TF-IDF matrix using `text2vec`
- `04_embed.R` — computes embeddings
  - GloVe (trained on the corpus; sentence embeddings are averages of word vectors)
  - BERT via `text::textEmbed()` (fallbacks to GloVe if unavailable)
- `05_search.R` — search function that embeds a query and returns top-10 tweets ranked by cosine similarity
- `06_eval.R` — evaluation: Precision@K, MAP, nDCG; saves a metrics plot
- `07_shiny_app.R` — Shiny app with query input, method selection, results table, and visuals
- `data/sample_tweets.csv` — local sample dataset (offline use)
- `outputs/` — generated plots
- `Dockerfile` — optional container for running the app

## Setup
1. Install R (>= 4.2) and RTools (Windows) as needed.
2. Run:
   - `Rscript 00_setup.R`
3. If using Twitter API: configure `rtweet` authentication (e.g., environment variables or OAuth). No keys are hardcoded.

## Run the Pipeline
1. Collect tweets (or fallback):
   - `Rscript 01_collect.R`
2. Preprocess text:
   - `Rscript 02_preprocess.R`
3. Build TF-IDF artifacts:
   - `Rscript 03_vectorize_tfidf.R`
4. Generate embeddings (GloVe + BERT):
   - `Rscript 04_embed.R`
   - If `text::textEmbed()` fails (e.g., missing backend or offline), BERT will automatically fallback to GloVe sentence embeddings.

## Semantic Search (CLI)
You can test the search from the command line:

```
Rscript 05_search.R "machine learning in healthcare"
```

To switch methods in code, call:
- `search_tweets("your query", method = "tfidf", top_n = 10)`
- `search_tweets("your query", method = "glove", top_n = 10)`
- `search_tweets("your query", method = "bert", top_n = 10)`

## Evaluation
Run:
```
Rscript 06_eval.R
```
Outputs:
- Console prints of metrics per query and method
- `outputs/eval_metrics.png` — aggregated metrics as bar charts

## Shiny App
Start the dashboard:
```
Rscript 07_shiny_app.R
```
Then open the browser at `http://127.0.0.1:8080/`.

Features:
- Query input box and method selection (TF-IDF, GloVe, BERT)
- Table of top-10 tweets with similarity scores
- Bar plot of similarity scores
- Bar plot of top terms in retrieved results

Notes:
- If BERT embeddings are not available (failure in `text::textEmbed()`), the app will still run using GloVe sentence embeddings.
- All file paths are relative (e.g., `data/sample_tweets.csv`).

## Docker (Optional)
Build:
```
docker build -t twitter-semantic-search .
```
Run:
```
docker run -p 8080:8080 twitter-semantic-search
```

## Design Choices
- Error-safe fallbacks ensure offline functionality.
- TF-IDF provides sparse baselines; GloVe and BERT provide dense semantics.
- Cosine similarity for ranking.
- Simple heuristic relevance labels for evaluation demos.

## Troubleshooting
- Missing packages: re-run `Rscript 00_setup.R`.
- `rtweet` authentication: consult `rtweet` docs for OAuth/app-only setup.
- `text::textEmbed` issues: ensure Python and `transformers` are available; otherwise rely on GloVe fallback.