.libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor)), .libPaths()))
library(rtweet)
ap <- rtweet_app(readLines("data/bearer_token.txt", warn = FALSE))
auth_as(ap)
q <- "new cancer rate in bangalore OR new cancer rate in bengaluru lang:en -is:retweet"
p <- tweet_search_recent(query = q, n = 50, parse = FALSE)
print(length(p))
print(names(p[[1]]))
print(head(p[[1]]$data$text))
