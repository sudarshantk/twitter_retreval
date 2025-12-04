lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", paste0(R.version$major, ".", R.version$minor))
.libPaths(c(lib, .libPaths()))
install.packages(c("readr","dplyr","purrr","stringr"), repos = "https://cloud.r-project.org")
