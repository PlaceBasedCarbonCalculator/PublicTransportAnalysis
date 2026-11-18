# The files txc_filter_files() hands to the converter, kept on disk.
#
# Runs the installed filter region by region exactly as the pipeline does
# (snapshot date as reference date, overlap resolution on) and leaves the kept
# files - rewritten operating periods included - under <out dir>/<region>/, so
# that faithful.py can count the journeys those files publish and set them
# against the converted feed. keptlist-style summaries delete this directory;
# this script is for when the files themselves are wanted.
#
# usage: Rscript filtered_files.R <snapshot dir> <YYYY-MM-DD> <out dir> [ncores]
options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
suppressMessages(library(UK2GTFS))
a <- commandArgs(TRUE)
ncores <- if (length(a) > 3) as.integer(a[4]) else 12L
uz <- get("unzip_recursive", asNamespace("UK2GTFS"))
d <- file.path(a[1], "TNDSV2.5"); if (!dir.exists(d)) d <- a[1]
ex <- file.path(tempdir(), "ff"); unlink(ex, recursive = TRUE); dir.create(ex)
dir.create(a[3], recursive = TRUE, showWarnings = FALSE)
for (z in list.files(d, "[.]zip$", full.names = TRUE)) {
  reg <- sub("[.]zip$", "", basename(z))
  if (tolower(reg) == "iom") next
  uz(z, exdir = file.path(ex, reg), silent = TRUE)
  files <- list.files(file.path(ex, reg), "[.]xml$", recursive = TRUE,
                      full.names = TRUE, ignore.case = TRUE)
  od <- file.path(a[3], reg); unlink(od, recursive = TRUE)
  k <- txc_filter_files(files, date = as.Date(a[2]), ncores = ncores,
                        out_dir = od, quiet = TRUE)
  cat(reg, length(files), "in,", length(k), "kept\n")
  unlink(file.path(ex, reg), recursive = TRUE)
}
unlink(ex, recursive = TRUE)
