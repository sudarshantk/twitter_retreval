lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor))
.libPaths(c(lib, .libPaths()))
install.packages(c("quanteda","text2vec","glmnet","Matrix","data.table","ggplot2"), repos = "https://cloud.r-project.org")
