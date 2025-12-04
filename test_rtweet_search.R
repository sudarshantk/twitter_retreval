.libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor)), .libPaths()))
library(rtweet)
token <- readLines("data/bearer_token.txt", warn = FALSE)
Sys.setenv(TWITTER_BEARER_TOKEN = token)
q <- "new cancer rate in bangalore OR new cancer rate in bengaluru lang:en -is:retweet"
res <- tryCatch(search_recent(query = q, max_results = 50, fields = list(tweet = c("id","text","created_at"))), error = function(e) e)
if (inherits(res, "error")) { message("search_recent error: ", conditionMessage(res)) } else { print(nrow(res)); print(head(res$text)) }
