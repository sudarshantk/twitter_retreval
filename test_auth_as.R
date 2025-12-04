.libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor)), .libPaths()))
library(rtweet)
ap <- rtweet_app(readLines("data/bearer_token.txt", warn = FALSE))
auth_as(ap)
q <- "new cancer rate in bangalore OR new cancer rate in bengaluru lang:en -is:retweet"
res <- tryCatch(tweet_search_recent(query = q, n = 50, fields = list(tweet = c("id","text","created_at"))), error = function(e) e)
if (inherits(res, "error")) { message("recent search error: ", conditionMessage(res)) } else { print(nrow(res)); print(head(res$text)) }
