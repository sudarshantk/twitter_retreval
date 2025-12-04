.libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor)), .libPaths()))
library(rtweet)
token <- readLines("data/bearer_token.txt", warn = FALSE)
client <- rtweet_client(bearer = token)
q <- "new cancer rate in bangalore OR new cancer rate in bengaluru lang:en -is:retweet"
res <- tryCatch(tweet_search_recent(query = q, max_results = 50, tweet_fields = c("id","text","created_at"), client = client), error = function(e) e)
if (inherits(res, "error")) { message("recent search error: ", conditionMessage(res)) } else { print(nrow(res)); print(head(res$text)) }
