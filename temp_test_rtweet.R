bt <- Sys.getenv("TWITTER_BEARER_TOKEN")
if (!nzchar(bt)) {
  bt_lines <- tryCatch(readLines("data/bearer_token.txt", warn = FALSE), error = function(e) "")
  bt <- bt_lines[which(nchar(bt_lines) > 0)][1]
}
bt <- utils::URLdecode(bt)
cat("Token length:", nchar(bt), "\n")
if (!nzchar(bt)) stop("No bearer token available")
library(rtweet)
auth <- rtweet::auth_bearer(token = bt)
rtweet::auth_as(auth)
x <- tryCatch(rtweet::search_recent("lang:en -is:retweet bengaluru cancer", max_results = 10), error = function(e) {print(e); NULL})
if (is.null(x)) {
  cat("search_recent returned NULL\n")
} else {
  print(names(x))
  print(utils::head(x$text, 3))
  print(utils::head(x$created_at))
}
