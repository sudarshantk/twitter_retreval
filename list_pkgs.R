lib <- .libPaths()[1]
ip <- installed.packages(lib.loc = lib)
print("Installed packages in lib:")
print(ip[ , c("Package","Version")])
