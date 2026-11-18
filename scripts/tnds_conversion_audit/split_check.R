# Which files the day-split rule in txc_overlap_plan() keeps running beside a
# successor that covers fewer weekdays (UK2GTFS, Nov 2026).
#
# Extracts a TNDS snapshot directory (one zip per region) or a BODS archive,
# runs txc_filter_files() from a UK2GTFS source tree, captures the metadata
# its rule 4 sees, and lists every split: the earlier file, the successor,
# their days and journey counts, and whether the successor is restricted to a
# ServicedOrganisation calendar (term or holiday only).
#
# usage: Rscript split_check.R <UK2GTFS source> <tnds dir | bods zip> <out csv> <date>
args <- commandArgs(trailingOnly = TRUE)
options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
suppressMessages(devtools::load_all(args[1], quiet = TRUE))
date <- as.Date(args[4])
ex <- file.path(tempdir(), "split_check")
unlink(ex, recursive = TRUE); dir.create(ex)
if (dir.exists(args[2])) {
  d <- file.path(args[2], "TNDSV2.5")
  if (!dir.exists(d)) d <- args[2]
  for (z in list.files(d, "[.]zip$", full.names = TRUE)) {
    if (tolower(basename(z)) == "iom.zip") next
    unzip_recursive(z, exdir = file.path(ex, sub("[.]zip$", "", basename(z))), silent = TRUE)
  }
  groups <- list.dirs(ex, recursive = FALSE)
} else {
  unzip_recursive(args[2], exdir = ex, silent = TRUE)
  groups <- ex
}
ns <- asNamespace("UK2GTFS")
orig <- get("txc_overlap_plan", ns)
captured <- new.env(); captured$meta <- list()
unlockBinding("txc_overlap_plan", ns)
assign("txc_overlap_plan", function(meta) {
  captured$meta[[length(captured$meta) + 1]] <- meta
  orig(meta)
}, ns)
rows <- list()
for (g in groups) {
  files <- list.files(g, pattern = "[.]xml$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  captured$meta <- list()
  invisible(txc_filter_files(files, date = date, ncores = 20, out_dir = tempfile()))
  for (meta in captured$meta) {
    plan <- orig(meta)
    sp <- attr(plan, "split_pairs")
    if (!nrow(sp)) next
    e <- match(sp$split, meta$file); l <- match(sp$by, meta$file)
    nvj <- function(f) length(xml2::xml_find_all(xml2::read_xml(f), "//d1:VehicleJourney"))
    rows[[length(rows) + 1]] <- data.frame(
      region = basename(g), noc = meta$NOC[e], lines = gsub("\r", ";", meta$Lines[e]),
      early = basename(sp$split), early_start = meta$StartDate[e], early_end = meta$EndDate[e],
      early_days = gsub("\r", ";", meta$Days[e]), early_vj = vapply(sp$split, nvj, 1L),
      late = basename(sp$by), late_start = meta$StartDate[l], late_end = meta$EndDate[l],
      late_days = gsub("\r", ";", meta$Days[l]), late_vj = vapply(sp$by, nvj, 1L),
      late_so = grepl("SO:", meta$Days[l]))
  }
}
out <- do.call(rbind, rows)
write.csv(out, args[3], row.names = FALSE)
cat("splits", if (is.null(out)) 0 else nrow(out), "\n")
if (!is.null(out)) print(table(out$region, out$late_so))
