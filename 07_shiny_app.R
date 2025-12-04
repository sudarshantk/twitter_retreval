#!/usr/bin/env Rscript
# 07_shiny_app.R — Shiny app for semantic tweet search with visualization

suppressMessages({
  # Prefer user-writable libraries on Windows
  ul_local <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor))
  ul_docs  <- file.path(path.expand("~"), "Documents", "R", "win-library", paste0(R.version$major, ".", R.version$minor))
  libs <- .libPaths()
  if (nzchar(Sys.getenv("LOCALAPPDATA")) && dir.exists(ul_local)) libs <- c(ul_local, libs)
  if (dir.exists(ul_docs)) libs <- c(ul_docs, libs)
  .libPaths(unique(libs))
})

suppressPackageStartupMessages({
  library(shiny)
  library(dplyr)
  library(ggplot2)
})

# Point reticulate at project-local Python venv for BERT support
try({
  venv_py <- normalizePath(file.path(getwd(), ".venv", "Scripts", "python.exe"),
                           winslash = "\\", mustWork = FALSE)
  if (file.exists(venv_py) && nzchar(venv_py)) {
    Sys.setenv(RETICULATE_PYTHON = venv_py)
  }
}, silent = TRUE)

# Source search functions
source("05_search.R")

ui <- fluidPage(
  titlePanel("Semantic Information Retrieval on Twitter"),
  sidebarLayout(
    sidebarPanel(
      textInput("query", "Enter your query:", value = "machine learning in healthcare"),
      radioButtons("method", "Embedding method:", choices = c("TF-IDF" = "tfidf", "GloVe" = "glove", "BERT" = "bert"), selected = "bert"),
      actionButton("search", "Search"),
      helpText("This app embeds your query and returns the most similar tweets.")
    ),
    mainPanel(
      h4("Top 10 Results"),
      tableOutput("results"),
      h4("Similarity Scores"),
      plotOutput("score_plot", height = "300px"),
      h4("Top Terms in Results"),
      plotOutput("terms_plot", height = "300px")
    )
  )
)

server <- function(input, output, session) {
  results <- reactiveVal(NULL)

  observeEvent(input$search, {
    req(input$query)
    method <- input$method
    res <- tryCatch({
      search_tweets(input$query, method = method, top_n = 10)
    }, error = function(e) {
      showNotification(paste("Search failed:", conditionMessage(e)), type = "error")
      NULL
    })
    results(res)
  })

  output$results <- renderTable({
    req(results())
    results() %>% dplyr::mutate(similarity = round(similarity, 4)) %>% dplyr::select(rank, similarity, text)
  })

  output$score_plot <- renderPlot({
    req(results())
    df <- results()
    ggplot2::ggplot(df, ggplot2::aes(x = stats::reorder(text, similarity), y = similarity)) +
      geom_col(fill = "steelblue") +
      coord_flip() +
      theme_minimal() +
      labs(x = "Tweet", y = "Cosine Similarity", title = "Similarity of Top Results")
  })

  output$terms_plot <- renderPlot({
    req(results())
    df <- results()
    toks <- unlist(strsplit(df$text_clean, "\\s+"))
    sw <- tryCatch({
      if (requireNamespace("quanteda", quietly = TRUE)) quanteda::stopwords("en") else c(
        "the","and","is","to","of","in","a","for","on","with","that","this","it","as","at","by"
      )
    }, error = function(e) {
      c("the","and","is","to","of","in","a","for","on","with","that","this","it","as","at","by")
    })
    toks <- toks[!(toks %in% sw)]
    toks <- toks[nchar(toks) > 1]
    if (length(toks) == 0) return(NULL)
    top <- as.data.frame(table(toks)) %>%
      dplyr::arrange(dplyr::desc(Freq)) %>%
      utils::head(15)
    ggplot2::ggplot(top, ggplot2::aes(x = stats::reorder(toks, Freq), y = Freq)) +
      geom_col(fill = "darkorange") +
      coord_flip() +
      theme_minimal() +
      labs(x = "Token", y = "Frequency", title = "Top Terms in Retrieved Tweets")
  })
}

# If running via Rscript, launch the app on a predictable port/host
app <- shinyApp(ui, server)
port <- as.integer(Sys.getenv("PORT", unset = 8080))
host <- Sys.getenv("HOST", unset = "127.0.0.1")
if (!interactive()) {
  shiny::runApp(app, port = port, host = host)
} else {
  app
}