# Assert the installed UK2GTFS packaged data is the release this pipeline
# needs, and is not the corrupted v0.1.2 bundle. Exits non-zero if not, so a
# driver can refuse to convert anything.
#
# Why this exists. UK2GTFS refreshes its packaged data from .onLoad(), which
# runs in every worker process. When the GitHub API call fails or is rate
# limited - which 30 workers each sleeping 5 s and then calling it reliably
# causes - check_data() falls back to comparing against Sys.time(), decides
# the data is out of date whatever it is, downloads a hardcoded
# default_tag = "v0.1.2", unzips it into the shared library folder, and
# stamps date.txt with today so the result looks current.
#
# v0.1.2's all.zip is also bad in its own right: naptan_replace.rda in it is
# a byte-identical copy of naptan_missing.rda, so the 503 genuine
# stop-location corrections are replaced by 41,955 rows that get_naptan()
# has already appended. patch_naptan() then silently corrects nothing.
#
# On 2026-10-08 this happened four minutes into a series reconversion and was
# caught only because a stop-count did not reconcile. .Rprofile now sets
# options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE) to stop the
# automatic refresh; this script is the check that it held.

EXPECT <- list(
  date           = "2026-08-02",  # release v0.1.6
  naptan_replace = 503L,
  naptan_missing = 42031L
)

fail <- character(0)
note <- function(...) fail <<- c(fail, paste0(...))

opt <- getOption("UK2GTFS_opt_updateCachedDataOnLibaryLoad", NA)
cat("auto-update on library load:", opt, "\n")
if (!identical(as.logical(opt), FALSE)) {
  note("UK2GTFS_opt_updateCachedDataOnLibaryLoad is ", opt,
       ", not FALSE - workers may re-download and clobber the data")
}

d <- system.file("extdata", package = "UK2GTFS")
if (!nzchar(d) || !dir.exists(d)) {
  note("UK2GTFS extdata directory not found")
} else {
  dt <- tryCatch(readLines(file.path(d, "date.txt")),
                 error = function(e) NA_character_)
  cat("date.txt:", dt, "\n")
  if (!identical(dt[1], EXPECT$date)) {
    note("date.txt is ", dt[1], ", expected ", EXPECT$date,
         " - the data may have been downgraded to v0.1.2")
  }

  rd <- function(f) {
    p <- file.path(d, paste0(f, ".rda"))
    if (!file.exists(p)) return(NULL)
    e <- new.env(); n <- load(p, envir = e)
    e[[n[1]]]
  }
  rp <- rd("naptan_replace")
  nm <- rd("naptan_missing")
  cat("naptan_replace rows:", if (is.null(rp)) "MISSING" else nrow(rp),
      " naptan_missing rows:", if (is.null(nm)) "MISSING" else nrow(nm), "\n")

  if (is.null(rp)) note("naptan_replace.rda missing")
  if (is.null(nm)) note("naptan_missing.rda missing")
  if (!is.null(rp) && nrow(rp) != EXPECT$naptan_replace) {
    note("naptan_replace has ", nrow(rp), " rows, expected ",
         EXPECT$naptan_replace)
  }
  if (!is.null(nm) && nrow(nm) != EXPECT$naptan_missing) {
    note("naptan_missing has ", nrow(nm), " rows, expected ",
         EXPECT$naptan_missing)
  }
  # the signature of the corrupt bundle
  if (!is.null(rp) && !is.null(nm) &&
      identical(as.data.frame(rp), as.data.frame(nm))) {
    note("naptan_replace is a copy of naptan_missing - this is the ",
         "corrupted v0.1.2 bundle; restore v0.1.6 before converting")
  }
}

if (length(fail)) {
  cat("\nFAILED:\n")
  for (f in fail) cat("  - ", f, "\n", sep = "")
  quit(status = 1)
}
cat("\nUK2GTFS packaged data OK\n")
