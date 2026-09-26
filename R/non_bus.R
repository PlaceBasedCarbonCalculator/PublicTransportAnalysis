# Audit of everything that is not a bus.
#
# WHY THIS EXISTS
#
# Every other validation and comparison stage in this repo is hard-filtered to
# `route_type == 3`: comparison.R:212, lsoa_gap.R:43, route_match.R:169, and
# near_duplicate_journeys.Rmd scopes its rule to "buses only" on purpose. That
# was a reasonable place to start - bus is 97% of the trips and the whole of
# the Friends of the Earth question - but it meant nothing ever looked at the
# other 3%, and three separate defects lived there undisturbed:
#
#   1. TfL publishes one Underground line into TNDS as several TransXChange
#      files with overlapping validity. UK2GTFS blanks any LineName longer
#      than six characters, and gtfs_deduplicate() keys an unnamed route on
#      its own route_id, so 93% of metro trips were exempt from deduplication
#      and single years came out at twice the true frequency.
#   2. gtfs_merge() numbered file_id per table rather than per feed, so a feed
#      missing calendar_dates shifted every later feed's cancellations onto the
#      preceding feed's services. This one did hit bus, hard, and still went
#      unnoticed for months because nothing compared a merged feed against the
#      regions that went into it.
#   3. The NAPTAN join moved after apply_standard_modes(), silently disabling
#      the thirteen mode rules that match on a stop's name. The Docklands
#      Light Railway came out as heavy rail in half the series.
#
# Defects 1 and 3 are invisible to a bus-only check by construction. Defect 2
# was visible and was still missed. So this stage is not "the same checks with
# a different filter" - it asks the questions whose absence let those three
# through:
#
#   - does every system carry the SAME route_type in every feed?  (3)
#   - does any fixed-track line appear as more than one live copy?  (1)
#   - which routes are exempt from deduplication for want of a name?  (1)
#   - is the same service present in two feeds that are summed?
#   - when does each system enter and leave the series at all?
#
# The last is not a defect but a comparability trap: the metro series means
# "Tyne and Wear plus Glasgow" in 2014-2015, "those plus part of the
# Underground" in 2016, and "the whole Underground plus the DLR" from 2018.
# A reader who plots it as one line is reading an archive artefact.

suppressPackageStartupMessages({
  library(data.table)
})

# Everything except bus. 3 is excluded because it is covered exhaustively
# elsewhere; 200 (coach) is included because it is a road mode that the
# sources disagree about, and it is folded into bus downstream, so a defect in
# it lands in the bus figures where no bus check will find it.
NON_BUS_TYPES <- c(0L, 1L, 2L, 4L, 6L, 11L, 200L, 1100L)

MODE_LABEL <- c(`0` = "tram", `1` = "metro", `2` = "rail", `3` = "bus",
                `4` = "ferry", `6` = "aerial lift", `11` = "trolleybus",
                `200` = "coach", `1100` = "air")

# The afternoon peak as UK2GTFS::gtfs_trips_per_zone() defines it
NB_AP_HOURS <- 15:17
NB_AP_BAND_HOURS <- 3


#' Read named tables out of a GTFS zip without unpacking all of it
#'
#' A merged national feed's stop_times is tens of millions of rows and is the
#' only table here that is expensive, so it is read once per feed and dropped
#' immediately afterwards.
#'
#' @param feed path to a GTFS zip
#' @param tables table names, without the .txt
#' @param select optional named list of columns per table
#' @return a named list of data.tables, NULL for any table the zip lacks
nb_read_tables <- function(feed, tables, select = NULL,
                           scratch = file.path(tempdir(), "non_bus")) {
  td <- file.path(scratch, basename(feed))
  dir.create(td, showWarnings = FALSE, recursive = TRUE)
  out <- lapply(tables, function(tb) {
    f <- file.path(td, paste0(tb, ".txt"))
    if (!file.exists(f)) {
      ok <- try(utils::unzip(feed, files = paste0(tb, ".txt"), exdir = td,
                             overwrite = TRUE), silent = TRUE)
      if (inherits(ok, "try-error") || !file.exists(f)) return(NULL)
    }
    args <- list(f, colClasses = list(character = c("arrival_time",
                                                    "departure_time")))
    if (!is.null(select[[tb]])) args$select <- select[[tb]]
    # colClasses names two columns most tables do not have; fread warns and
    # ignores them, which is the wanted behaviour but not the wanted output
    suppressWarnings(do.call(data.table::fread, args))
  })
  names(out) <- tables
  out
}

nb_clear <- function(feed, scratch = file.path(tempdir(), "non_bus")) {
  unlink(file.path(scratch, basename(feed)), recursive = TRUE)
  invisible(NULL)
}


#' Which named system each route belongs to, and what mode it was given
#'
#' Identical in method to UK2GTFS's own apply_standard_modes(): a route
#' belongs to a system when at least `threshold` of the distinct stops it
#' calls at match that system's NAPTAN name pattern. Reporting the route's
#' ACTUAL route_type beside that is the whole point - a system whose mode
#' disagrees with the rule is one the rule did not reach.
#'
#' Identifying a system by its stops rather than by its operator code is
#' deliberate: operator codes are not stable between archives (NPTDR reuses
#' them across eras, and `CAB` means something different before 2012), whereas
#' a station's NAPTAN name is.
#'
#' @param g tables from nb_read_tables(): routes, trips, stop_times, stops
#' @param threshold share of a route's stops that must match
#' @return a data.table of system, route_type, routes, trips, agencies
nb_system_modes <- function(g, threshold = 0.8) {
  ov <- UK2GTFS::standard_mode_overrides()
  ov <- ov[!is.na(ov$stop_pattern) & nzchar(ov$stop_pattern), , drop = FALSE]
  if (is.null(g$stops) || is.null(g$stop_times) || nrow(g$stops) == 0) {
    return(NULL)
  }

  # unique on the join key. A rail CIF feed can carry the same TIPLOC twice
  # in stops.txt, and a duplicate key on the right of a join multiplies the
  # left side instead of labelling it - which is a silent overcount of every
  # route through that stop, not just a data.table error.
  sp <- unique(g$stops[, list(stop_id = as.character(stop_id),
                              stop_name = as.character(stop_name))],
               by = "stop_id")
  sp[, sys := NA_character_]
  # first pattern wins, as in the package: the table is ordered so the
  # specific patterns precede the general ones
  for (i in seq_len(nrow(ov))) {
    hit <- is.na(sp$sys) & grepl(ov$stop_pattern[i], sp$stop_name,
                                 ignore.case = TRUE, useBytes = TRUE)
    sp[hit, sys := ov$system[i]]
  }
  marked <- sp[!is.na(sys)]
  if (nrow(marked) == 0) return(NULL)

  st <- g$stop_times[, list(trip_id = as.character(trip_id),
                            stop_id = as.character(stop_id))]
  # same reason as sp above: trips and routes are used here as lookups, so a
  # repeated trip_id or route_id would multiply rows rather than label them
  tr <- unique(g$trips[, list(trip_id = as.character(trip_id),
                              route_id = as.character(route_id))],
               by = "trip_id")
  ro <- unique(g$routes[, list(route_id = as.character(route_id),
                               agency_id = as.character(agency_id),
                               route_type = as.integer(route_type))],
               by = "route_id")

  rs <- unique(merge(st, tr, by = "trip_id")[, list(route_id, stop_id)])
  rs <- merge(rs, sp[, list(stop_id, sys)], by = "stop_id", all.x = TRUE)
  n <- rs[, list(n = .N), by = "route_id"]
  h <- rs[!is.na(sys), list(n_hit = .N), by = c("route_id", "sys")]
  h <- merge(h, n, by = "route_id")[n_hit / n >= threshold]
  if (nrow(h) == 0) return(NULL)
  # where two systems both clear the threshold the closer match wins
  h[, share := n_hit / n]
  setorderv(h, c("route_id", "share"), c(1L, -1L))
  h <- h[!duplicated(h$route_id)]
  h <- merge(h, ro, by = "route_id")
  nt <- tr[, list(trips = .N), by = "route_id"]
  h <- merge(h, nt, by = "route_id", all.x = TRUE)
  h[is.na(trips), trips := 0L]
  h[, list(routes = .N, trips = sum(trips),
           agencies = paste(sort(unique(agency_id)), collapse = "/")),
    by = c("sys", "route_type")]
}


#' Normalise a line's long name so two publications of it group together
#'
#' Case, punctuation and word order all vary between TransXChange files for
#' the same line. Sorting the words is crude but it is what makes
#' "Ealing Broadway - Upminster" and "Upminster to Ealing Broadway" the same
#' line, which is necessary to count copies of it.
nb_normalise_line <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[^a-z0-9 ]+", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  vapply(strsplit(x, " ", fixed = TRUE),
         function(w) paste(sort(w[nzchar(w)]), collapse = " "),
         character(1))
}


#' Live copies of one line, and the journeys that exist only because of them
#'
#' For each line and each date inside the counting window: how many journeys
#' all live copies claim between them, and how many the single largest copy
#' claims on its own. The difference is the phantom - service that exists in
#' the feed only because the same timetable was published more than once.
#'
#' Counted per DATE, not per feed, because a superseded copy with a short
#' calendar is legitimate on the dates the replacement does not cover. Taking
#' the largest copy rather than the first is what keeps a genuine
#' mid-window timetable change from being scored as duplication.
#'
#' @param g tables: routes, trips, calendar, calendar_dates
#' @param ref the feed's window reference date
#' @param by group by mode, or by mode and line
#' @return a data.table of trip_days, phantom, pct and how many lines
nb_phantom <- function(g, ref, route_types = NON_BUS_TYPES,
                       by = c("route_type", "line")) {
  by <- match.arg(by)
  if (is.null(g$routes) || nrow(g$routes) == 0) return(NULL)
  ro <- g$routes[route_type %in% route_types]
  if (nrow(ro) == 0) return(NULL)
  ro <- copy(ro)
  ro[, route_id := as.character(route_id)]
  ro[, line := nb_normalise_line(route_long_name)]
  # a line is identified by operator, mode and name together: two operators
  # may run a line of the same number, and the same name under two modes is
  # exactly the inconsistency being looked for elsewhere
  ro[, key := paste(agency_id, route_type, route_short_name, line, sep = "|")]

  # A route with no route_long_name gets a key of its own, so it can never be
  # grouped with anything - the same treatment gtfs_deduplicate() gives an
  # unnamed route, and for the same reason.
  #
  # This is not a nicety. The measure assumes one route_id is one published
  # timetable, which holds for TransXChange but not for ATCO-CIF: NPTDR gives
  # every metro route a blank long name and splits one line across hundreds of
  # route_ids carrying a handful of trips each - 920 routes under 18 line codes
  # in 2007, 136 of them District line. Grouping those by name reported 79% of
  # Underground service as duplicated when none of it was. Keying them
  # individually reports nothing instead, which is correct: duplication in a
  # feed with no route names cannot be detected this way at all, and saying so
  # is the point of `measurable` below.
  ro[, named := !is.na(route_long_name) & nzchar(trimws(route_long_name))]
  ro[named == FALSE, key := paste0("
unnamed
", route_id)]

  tr <- g$trips[as.character(route_id) %in% ro$route_id]
  if (nrow(tr) == 0) return(NULL)
  win <- study_window(ref)
  d <- UK2GTFS:::service_operating_dates(g, unique(as.character(tr$service_id)))
  d <- d[date %in% as.integer(seq(win$startdate, win$enddate, by = "day"))]
  if (nrow(d) == 0) return(NULL)

  x <- merge(tr[, list(route_id = as.character(route_id),
                       service_id = as.character(service_id))],
             d, by = "service_id", allow.cartesian = TRUE)
  x <- x[, list(trips = .N), by = c("route_id", "date")]
  x <- merge(x, unique(ro[, list(route_id, key, line, route_type)],
                       by = "route_id"), by = "route_id")

  g2 <- x[, list(total = sum(trips), biggest = max(trips), copies = .N),
          by = c("key", "line", "route_type", "date")]
  # how much of each mode's service sits on routes the measure can actually
  # see, so a 0% phantom on an unnamed feed is not read as "no duplication"
  nm <- merge(x[, list(route_id, date, trips)],
              unique(ro[, list(route_id, named, route_type)], by = "route_id"),
              by = "route_id")
  cover <- nm[, list(trip_days_all = sum(trips),
                     trip_days_named = sum(trips[named])), by = "route_type"]
  cover[, measurable := round(100 * trip_days_named / trip_days_all, 1)]

  grp <- if (by == "route_type") "route_type" else c("route_type", "line")
  s <- g2[, list(trip_days = sum(total),
                 phantom = sum(total - biggest),
                 lines = uniqueN(key),
                 lines_affected = uniqueN(key[copies > 1])), by = grp]
  s[, pct := round(100 * phantom / trip_days, 1)]
  s <- merge(s, cover[, list(route_type, measurable)], by = "route_type",
             all.x = TRUE)
  s[order(route_type, -phantom)]
}


#' Routes carrying no route_short_name, by mode
#'
#' route_short_name is the field gtfs_deduplicate() groups candidate routes
#' on, and an unnamed route is keyed on its own route_id, so it can never
#' share a group with its own duplicate. A blank name is therefore an
#' exemption from deduplication, and this is the measure of how many trips
#' hold one.
#'
#' @param g tables: routes, trips
#' @return a data.table of route_type, routes, trips and the blank shares
nb_blank_names <- function(g) {
  if (is.null(g$routes) || nrow(g$routes) == 0) return(NULL)
  ro <- copy(g$routes)
  ro[, route_id := as.character(route_id)]
  ro <- unique(ro, by = "route_id")
  ro[, blank := is.na(route_short_name) | !nzchar(trimws(route_short_name))]
  n <- g$trips[, list(trips = .N), by = list(route_id = as.character(route_id))]
  ro <- merge(ro, n, by = "route_id", all.x = TRUE)
  ro[is.na(trips), trips := 0L]
  ro[, list(routes = .N, routes_blank = sum(blank),
            trips = sum(trips), trips_blank = sum(trips[blank])),
     by = "route_type"][
       , `:=`(pct_routes = round(100 * routes_blank / routes, 1),
              pct_trips = round(100 * trips_blank / trips, 1))][
                 order(route_type)]
}


#' Everything measured on one feed, in a single pass
#'
#' stop_times is read once and dropped, because on a merged national feed it
#' is the only table whose size matters.
#'
#' @param feed path to a GTFS zip
#' @param ref the feed's window reference date
#' @param label how the report should name this feed
#' @return a named list of per-feed data.tables
nb_audit_feed <- function(feed, ref, label) {
  if (!file.exists(feed)) {
    message("  missing, skipped: ", feed)
    return(NULL)
  }
  message("  ", label, " (", basename(feed), ")")
  g <- nb_read_tables(feed, c("routes", "trips", "calendar", "calendar_dates",
                              "stops", "stop_times"),
                      select = list(stop_times = c("trip_id", "stop_id",
                                                   "departure_time")))
  stamp <- function(x) {
    if (is.null(x) || nrow(x) == 0) return(NULL)
    x <- copy(x)
    x[, `:=`(feed = basename(feed), label = label)]
    x[]
  }
  out <- list(
    systems = stamp(nb_system_modes(g)),
    phantom = stamp(nb_phantom(g, ref, by = "route_type")),
    phantom_line = stamp(nb_phantom(g, ref, by = "line")),
    blank = stamp(nb_blank_names(g)))
  rm(g)
  nb_clear(feed)
  gc(verbose = FALSE)
  out
}


#' Fixed-track service carried by a year's rail feed as well as its bus feed
#'
#' From 2018 each year sums a bus feed and a rail feed, and sum_feeds() adds
#' their counts, so a service in both is counted twice. Matching stop ids
#' cannot detect it - TNDS uses ATCO codes, the rail CIF uses TIPLOCs - but the
#' zone join is spatial, so the double count lands in whichever zone holds the
#' station.
#'
#' This identifies the rail feed's side by route_type and agency NAME, not by
#' stop-name pattern. The patterns in standard_mode_overrides() are NAPTAN
#' names ("Bank DLR Station", "Tyne and Wear Metro Station"); the rail CIF
#' names its stops from TIPLOCs and matches none of them, so a stop-pattern
#' check on a rail feed finds nothing and cannot tell "no overlap" from "cannot
#' see". The CIF does name its operators plainly - agency LT is "London
#' Underground", TW is "Tyne & Wear Metro" - so that is what is used.
#'
#' @param spec one year's entry from year_sources()
#' @return a data.table of year, agency, mode and trips in the rail feed
nb_cross_source <- function(spec) {
  if (is.null(spec$rail)) return(NULL)
  path <- spec$rail$path
  if (!file.exists(path)) return(NULL)
  g <- nb_read_tables(path, c("agency", "routes", "trips"))
  if (is.null(g$routes) || nrow(g$routes) == 0) return(NULL)
  ro <- unique(g$routes[, list(route_id = as.character(route_id),
                               agency_id = as.character(agency_id),
                               route_type = as.integer(route_type))],
               by = "route_id")
  # fixed-track modes only: heavy rail in a rail feed is what it is for
  ro <- ro[route_type %in% c(0L, 1L)]
  if (nrow(ro) == 0) {
    rm(g); nb_clear(path); gc(verbose = FALSE)
    return(data.table(year = spec$year, agency_id = NA_character_,
                      agency_name = NA_character_, route_type = NA_integer_,
                      routes = 0L, trips = 0L,
                      dropped = 1L %in% spec$rail$drop_route_types))
  }
  n <- g$trips[as.character(route_id) %in% ro$route_id,
               list(trips = .N), by = list(route_id = as.character(route_id))]
  ro <- merge(ro, n, by = "route_id", all.x = TRUE)
  ro[is.na(trips), trips := 0L]
  if (!is.null(g$agency) && "agency_name" %in% names(g$agency)) {
    ag <- unique(g$agency[, list(agency_id = as.character(agency_id),
                                 agency_name = as.character(agency_name))],
                 by = "agency_id")
    ro <- merge(ro, ag, by = "agency_id", all.x = TRUE)
  } else {
    ro[, agency_name := NA_character_]
  }
  out <- ro[, list(routes = .N, trips = sum(trips)),
            by = c("agency_id", "agency_name", "route_type")]
  rm(g); nb_clear(path); gc(verbose = FALSE)
  out[, `:=`(year = spec$year,
             dropped = 1L %in% spec$rail$drop_route_types)]
  out[order(-trips)]
}


#' The published series for every mode except bus
#'
#' The era-break table. A mode that is absent for a block of years, or that
#' changes by an order of magnitude between adjacent years, is not showing a
#' change in service - it is showing which archive that year came from.
#'
#' @return a data.table of year, mode, zones and national tph
nb_published_series <- function(years = c(2004:2011, 2014:2025),
                                cfg = load_cfg()) {
  col <- "tph_Wed_Afternoon Peak"
  rbindlist(lapply(years, function(y) {
    f <- file.path(cfg$out_dir,
                   sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y))
    if (!file.exists(f)) return(NULL)
    x <- as.data.table(readRDS(f))
    if (!col %in% names(x)) return(NULL)
    tot <- sum(x[[col]], na.rm = TRUE)
    # group by route_type alone and add the year afterwards: `y` is a scalar
    # from the enclosing lapply, and data.table requires every element of `by`
    # to be as long as the table
    out <- x[, list(zones = uniqueN(zone_id[get(col) > 0]),
                    tph = sum(get(col), na.rm = TRUE),
                    pct_of_all = round(100 * sum(get(col), na.rm = TRUE) / tot,
                                       3)),
             by = list(route_type = as.integer(route_type))]
    out[, year := y]
    out[]
  }), fill = TRUE)
}


#' Audit every non-bus mode, across every feed in the series
#'
#' @param feed_paths the converted feeds, passed so targets tracks them
#' @param cfg configuration
#' @return path to the written Rds
non_bus_analysis <- function(feed_paths = NULL, cfg = load_cfg()) {
  spec <- year_sources(cfg)
  res <- list(generated = Sys.time())

  # one row per feed actually used by a year, bus side and rail side
  feeds <- rbindlist(lapply(spec, function(s) {
    b <- rbindlist(lapply(seq_along(s$bus), function(i) {
      data.table(year = s$year, side = "bus", path = s$bus[[i]]$path,
                 ref = as.character(s$bus[[i]]$ref))
    }))
    r <- if (is.null(s$rail)) NULL else
      data.table(year = s$year, side = "rail", path = s$rail$path,
                 ref = as.character(s$rail$ref))
    rbindlist(list(b, r), fill = TRUE)
  }), fill = TRUE)
  # The label is the join key that puts year and side back onto each per-feed
  # result, so it has to identify a FEED, not a year and side. 2024 and 2025
  # each take bus from two feeds - the TNDS snapshot and the BODS coach
  # dataset - so "2024 bus" names two of them, and a lookup keyed on it
  # multiplies every row it touches instead of labelling it.
  feeds[, label := paste0(year, " ", side)]
  feeds[, n_side := .N, by = "label"]
  feeds[n_side > 1, label := paste0(label, " ",
                                    sub("[.]zip$", "", basename(path)))]
  feeds[, n_side := NULL]
  stopifnot(!any(duplicated(feeds$label)))
  res$feeds <- feeds

  message("Auditing ", nrow(feeds), " feeds")
  per <- lapply(seq_len(nrow(feeds)), function(i) {
    nb_audit_feed(feeds$path[i], feeds$ref[i], feeds$label[i])
  })
  pull <- function(nm) {
    out <- rbindlist(lapply(per, function(x) x[[nm]]), fill = TRUE)
    if (nrow(out) == 0) return(out)
    # unique() as well as the uniqueness check above: this join must be a
    # lookup, and a silent row multiplication here would inflate every table
    # in the report rather than fail
    merge(out, unique(feeds[, list(label, year, side)], by = "label"),
          by = "label", all.x = TRUE)
  }
  res$systems <- pull("systems")
  res$phantom <- pull("phantom")
  res$phantom_line <- pull("phantom_line")
  res$blank <- pull("blank")

  message("Checking for services present in two summed feeds")
  res$cross_source <- rbindlist(lapply(spec, nb_cross_source), fill = TRUE)

  message("Reading the published series")
  res$series <- nb_published_series(cfg = cfg)

  # the headline verdicts, computed here so the report cannot restate them
  # differently
  if (nrow(res$systems) > 0) {
    chk <- res$systems[, list(modes = paste(sort(unique(
      MODE_LABEL[as.character(route_type)])), collapse = ", "),
      n_modes = uniqueN(route_type), feeds = uniqueN(feed)), by = "sys"]
    res$mode_consistency <- chk[order(-n_modes, sys)]
    res$inconsistent <- chk[n_modes > 1]$sys
  }

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(cfg$out_dir, "non_bus_audit.Rds")
  saveRDS(res, out)
  message("Written ", out)
  out
}


#' Knit the non-bus audit to markdown
render_non_bus_report <- function(audit_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$audit_path <- normalizePath(audit_path)
  # knit from inside reports/ so figure links in the md are relative to it,
  # and with knitr::knit rather than rmarkdown::render so no pandoc is needed
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "non_bus_modes.Rmd", output = "non_bus_modes.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "non_bus_modes.md")
}
