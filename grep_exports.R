library(rtweet)
fx <- getNamespaceExports("rtweet")
print(grep("search|tweet_search|recent", fx, value=TRUE))
