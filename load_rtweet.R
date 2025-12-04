.libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor)), .libPaths()))
tryCatch({ library(rtweet); cat("rtweet loaded\n") }, error = function(e) { message("load error: ", conditionMessage(e)) })
