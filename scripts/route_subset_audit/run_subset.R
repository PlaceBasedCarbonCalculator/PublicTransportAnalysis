# The subset harness: filter, convert and count one working subset.
#
# usage: R_LIBS=<lib with the UK2GTFS build under test> \
#        Rscript scripts/route_subset_audit/run_subset.R <subset dir> <filter date> <check date> <out prefix> [ncores] [feed cache dir]
#
# <subset dir> holds tnds/<region>/*.xml and bods/<container>/*.xml, as written
# by extract_subset.py. Each TNDS region and the whole of bods are filtered
# with txc_filter_files on <filter date> (the snapshot date, as the pipeline
# does) and converted with transxchange2gtfs. Every converted feed is written
# to <feed cache dir>/<src>_<group>.zip and reused by a rerun with the same
# prefix, so the counting can be changed without converting again. Counts are
# per feed and summed: the TNDS 2.5 edition has no cross-region duplicates, so
# no merge is needed (and it is the merge step the pipeline reads back from
# disk for). Outputs:
#   <prefix>_kept.csv    one row per input file: kept?, operator, lines, period,
#                        revision, journeys (the why.R columns)
#   <prefix>_routes.csv  trips on <check date> per source, operator and line
#   <prefix>_stops.csv   departures on <check date> per source, operator, line and stop
suppressMessages({ library(data.table) })
options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
suppressMessages(library(UK2GTFS))
a <- commandArgs(TRUE)
subset_dir <- a[1]; fdate <- as.Date(a[2]); cdate <- as.Date(a[3]); prefix <- a[4]
ncores <- if (length(a) >= 5) as.integer(a[5]) else 4L
cache_dir <- if (length(a) >= 6) a[6] else file.path("F:/tmp_r/subset_feeds", basename(prefix))
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
cat("UK2GTFS", as.character(packageVersion("UK2GTFS")), "from", find.package("UK2GTFS"), "\n")
cal <- targets::tar_read(txc_cal)
naptan <- targets::tar_read(naptan)

file_meta <- function(f) {
  t <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  g1 <- function(p, s = t) { m <- regmatches(s, regexpr(p, s, perl = TRUE)); if (length(m)) sub("^<[^>]*>", "", sub("<[^>]*>$", "", m)) else NA }
  sv <- regmatches(t, regexpr("(?s)<Service[ >].*?</Service>", t, perl = TRUE))
  if (!length(sv)) sv <- ""
  lines <- regmatches(sv, gregexpr("<LineName>[^<]*</LineName>", sv, perl = TRUE))[[1]]
  so <- regmatches(t, gregexpr("<(Holidays|WorkingDays)/>", t, perl = TRUE))[[1]]
  data.table(file = basename(f),
             noc = g1("<NationalOperatorCode>[^<]*</NationalOperatorCode>"),
             opname = g1("<OperatorShortName>[^<]*</OperatorShortName>"),
             desc = g1("<Description>[^<]*</Description>", sv),
             lines = paste(gsub("<[^>]*>", "", lines), collapse = "|"),
             start = g1("<StartDate>[^<]*</StartDate>", sv), end = g1("<EndDate>[^<]*</EndDate>", sv),
             mod = gsub("^.*=\"|\"$", "", g1("ModificationDateTime=\"[^\"]*\"")),
             rev = gsub("^.*=\"|\"$", "", g1("RevisionNumber=\"[^\"]*\"")),
             vj = lengths(regmatches(t, gregexpr("<VehicleJourney[ >]", t, perl = TRUE))),
             so = paste(gsub("[<>/]", "", so), collapse = " "))
}

as_day <- function(x) if (inherits(x, "Date")) x else as.Date(as.character(x), tryFormats = c("%Y%m%d", "%Y-%m-%d"))

trips_on <- function(gtfs, day) {
  wd <- c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")[lubridate::wday(day, week_start = 1)]
  cal <- as.data.table(gtfs$calendar)
  on <- cal[as_day(start_date) <= day & as_day(end_date) >= day & as.integer(get(wd)) == 1, as.character(service_id)]
  cd <- as.data.table(gtfs$calendar_dates)
  if (nrow(cd)) {
    cd <- cd[as_day(date) == day]
    on <- setdiff(union(on, cd[exception_type == 1, as.character(service_id)]),
                  cd[exception_type == 2, as.character(service_id)])
  }
  tr <- as.data.table(gtfs$trips)[as.character(service_id) %in% on, list(trip_id = as.character(trip_id), route_id = as.character(route_id))]
  rt <- as.data.table(gtfs$routes)[, list(route_id = as.character(route_id), line = toupper(gsub("\\s+", "", route_short_name)),
                                          agency_id = as.character(agency_id))]
  ag <- as.data.table(gtfs$agency)[, list(agency_id = as.character(agency_id), agency = as.character(agency_name))]
  tr <- merge(merge(tr, rt, by = "route_id"), ag, by = "agency_id", all.x = TRUE)
  st <- as.data.table(gtfs$stop_times)[, list(trip_id = as.character(trip_id), stop_id = as.character(stop_id))]
  st <- merge(st, tr[, list(trip_id, agency, line)], by = "trip_id")
  list(routes = tr[, list(trips = .N), by = list(agency, line)],
       stops = st[, list(deps = .N), by = list(agency, line, stop_id)])
}

run_source <- function(src) {
  d <- file.path(subset_dir, src)
  if (!dir.exists(d)) return(NULL)
  groups <- if (src == "tnds") list.dirs(d, recursive = FALSE) else d
  kept <- list(); routes <- list(); stops <- list()
  for (g in groups) {
    files <- list.files(g, "[.]xml$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
    if (!length(files)) next
    name <- paste0(src, "_", basename(g))
    zip <- file.path(cache_dir, paste0(name, ".zip"))
    kept_csv <- file.path(cache_dir, paste0(name, "_kept.csv"))
    if (file.exists(zip) && file.exists(kept_csv)) {
      cat(src, basename(g), "cached\n")
      m <- fread(kept_csv, colClasses = "character"); m[, kept := kept == "TRUE"]
      gtfs <- gtfs_read(zip)
    } else {
      k <- txc_filter_files(files, date = fdate, ncores = ncores, quiet = TRUE)
      m <- rbindlist(lapply(files, file_meta))
      m[, `:=`(src = src, group = basename(g), kept = file %in% basename(k))]
      cat(src, basename(g), length(files), "files,", length(k), "kept\n")
      gtfs <- transxchange2gtfs(k, silent = TRUE, ncores = ncores, cal = cal, naptan = naptan,
                                scotland = if (basename(g) == "S") "yes" else "no",
                                try_mode = TRUE, force_merge = TRUE, filter_duplicate_files = FALSE)
      gtfs_write(gtfs, folder = cache_dir, name = name)
      fwrite(m, kept_csv)
      gtfs <- gtfs_read(zip)
    }
    kept[[g]] <- m
    counts <- trips_on(gtfs, cdate)
    counts$routes[, `:=`(src = src, group = basename(g))]
    counts$stops[, `:=`(src = src, group = basename(g))]
    routes[[g]] <- counts$routes; stops[[g]] <- counts$stops
    rm(gtfs); gc()
  }
  list(kept = rbindlist(kept), routes = rbindlist(routes), stops = rbindlist(stops))
}
res <- Filter(Negate(is.null), lapply(c("tnds", "bods"), run_source))
fwrite(rbindlist(lapply(res, `[[`, "kept")), paste0(prefix, "_kept.csv"))
fwrite(rbindlist(lapply(res, `[[`, "routes")), paste0(prefix, "_routes.csv"))
fwrite(rbindlist(lapply(res, `[[`, "stops")), paste0(prefix, "_stops.csv"))
cat("written", prefix, "\n")
