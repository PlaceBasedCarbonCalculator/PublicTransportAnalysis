# Does the revision filter explain the operator shortfall?
#
# For three operators whose converted BODS feed holds a fraction of TNDS's
# journeys, this runs the same txc_filter_files() the conversion runs, with
# the same filter date, over that operator's BODS files, and counts the
# vehicle journeys in the files that SURVIVE. That survivor count is the one
# comparable with TNDS: the raw archive holds every revision, so its total
# counts the same timetable many times over.
#
# Caveat: the filter is run per operator rather than over the whole archive.
# Its rules key on service code and operator, so an operator's files are
# reconciled among themselves either way, but a cross-operator interaction
# would not be reproduced here.

suppressMessages({library(data.table); library(xml2)})
source("R/config.R")
cfg <- load_cfg()

# Where scripts/txc_extract_operator.py put the per-operator files. Pass the
# directory as the first argument; it defaults to a sibling of the repository
# so nothing is written inside it.
ops_dir <- function() {
  a <- commandArgs(TRUE)
  if (length(a) && nzchar(a[1])) a[1] else
    file.path(tempdir(), "bods_ops")
}


OPS <- ops_dir()
FILTER_DATE <- as.Date("2026-10-05")
TNDS_J <- c(BHBC = 11161L, WRAY = 7613L, METR = 14305L)

# Counting <VehicleJourney> openings in the raw bytes rather than parsing the
# document. Parsing 1,080 Brighton & Hove files with xml2 takes over half an
# hour; this takes seconds, and an element count needs no tree.
count_j <- function(f) {
  txt <- tryCatch(readChar(f, file.size(f), useBytes = TRUE),
                  error = function(e) NULL)
  if (is.null(txt)) return(0L)
  length(gregexpr("<VehicleJourney[ >]", txt, fixed = FALSE)[[1]][
    gregexpr("<VehicleJourney[ >]", txt, fixed = FALSE)[[1]] > 0])
}

res <- rbindlist(lapply(list.dirs(OPS, recursive = FALSE), function(d) {
  noc <- basename(d)
  files <- list.files(d, pattern = "[.]xml$", full.names = TRUE)
  message("\n=== ", noc, ": ", length(files), " files ===")
  j_all <- sum(vapply(files, count_j, 0L))
  message("  journeys across every revision: ", j_all)
  t0 <- Sys.time()
  kept <- UK2GTFS::txc_filter_files(files, date = FILTER_DATE,
                                    ncores = min(8L, cfg$ncores))
  message("  kept ", length(kept), " files in ",
          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
          " min")
  j_kept <- sum(vapply(kept, count_j, 0L))
  message("  journeys in the survivors:      ", j_kept)
  data.table(noc = noc, files = length(files), files_kept = length(kept),
             journeys_all = j_all, journeys_kept = j_kept,
             tnds_journeys = TNDS_J[[noc]])
}))

res[, kept_over_tnds := round(journeys_kept / tnds_journeys, 3)]
cat("\n=== survivors against TNDS ===\n")
print(res)
cat("\nIf kept_over_tnds is near 1, the BODS archive and the filter are fine\n",
    "and the converted feed's shortfall lies further downstream.\n",
    "If it is well below 1, the surviving revisions genuinely hold fewer\n",
    "journeys than TNDS does for the same operator and dates.\n", sep = "")
saveRDS(res, file.path(cfg$out_dir, "bods_operator_filter_check.Rds"))
cat("\nwrote data/bods_operator_filter_check.Rds\n")
