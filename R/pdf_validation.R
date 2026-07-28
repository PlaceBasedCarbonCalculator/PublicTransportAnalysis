# Validating the converted feeds against published timetables.
#
# The multi-year comparison (R/comparison.R) can say the three sources
# disagree; only a published timetable says which is right. This checks
# individual routes in all three sources against the PDFs in
# data/example_timetables, over the current snapshot (validation_snapshot()),
# because published timetables are obtainable for today and rarely for the
# past.
#
# Routes are resolved by public number plus an operator pattern, never by
# route_id: ids are assigned per snapshot and differ between the three feeds.

#' Routes with a published timetable, and how to read each one
#'
#' `format` selects the reader in R/pdf_timetable.R:
#'   tfl   - TfL running schedule, one row per vehicle journey (`node` names
#'           the timing point counted)
#'   column- passenger timetable, one column per journey (`stop_regex` names
#'           the row counted, `directions` separates the two directions)
#'
#' `expect` is the journeys-per-operating-day the document implies, where it
#' can be read off unambiguously; NA where the document abbreviates in a way
#' that cannot be resolved (see the 142).
validation_routes <- function() {
  list(
    list(key = "279", short_name = "279", operator = "Arriva London",
         format = "tfl", node = "AD803",
         files = c(MT = "Schedule_279-MT.pdf", Fr = "Schedule_279-Fr.pdf",
                   Sa = "Schedule_279-Sa.pdf", Su = "Schedule_279-Su.pdf"),
         note = "TfL running schedule; every journey listed"),

    list(key = "69", short_name = "69",
         operator = "Blue Triangle|Go.?Ahead London",
         format = "tfl", node = "AA501",
         files = c(MT = "Schedule_69-MT.pdf", Fr = "Schedule_69-Fr.pdf",
                   Sa = "Schedule_69-Sa.pdf", Su = "Schedule_69-Su.pdf",
                   MTNt = "Schedule_69-MTNt.pdf", FrNt = "Schedule_69-FrNt.pdf",
                   SaNt = "Schedule_69-SaNt.pdf", SuNt = "Schedule_69-SuNt.pdf"),
         combine = c(MTNt = "MT", FrNt = "Fr", SaNt = "Sa", SuNt = "Su"),
         note = paste("day and night schedules combine to one operating day;",
                      "these are the May 2026 contract schedules, so they",
                      "match a current snapshot but not the February one")),
    # TfL also issues route 69 as schooldays/school-holiday variants
    # (MoSc/MoHo, TWTSc/TWTHo, FrSc/FrHo) and as bank holiday, Good Friday,
    # Christmas Eve, Boxing Day and New Year schedules. None is wired in,
    # for two measured reasons: the schooldays and school-holiday schedules
    # carry an identical number of journeys at AA501 (273 either way), so
    # they cannot test the ServicedOrganisation handling. The bank holiday
    # schedules do differ - Bh is 191 against 233 for a normal Monday to
    # Thursday - and 31 August now falls inside the `bankhol` window, so
    # they are testable in principle. What is still missing is the
    # comparison: feed_route_departures() totals a whole 28-day window, in
    # which one substituted day is well inside the noise. Using them needs
    # per-date counts rather than another document.

    list(key = "A1", short_name = "A1", operator = "First Bristol",
         format = "column",
         file = "EFA01__0000979_TP.pdf",
         stop_regex = "^Bristol Airport, Public Transport Interchange",
         directions = c(
           out = "Bristol Airport - Bristol Temple Meads - Bristol Bus Station",
           back = "Bristol Bus Station - Bristol Temple Meads - Bristol Airport"),
         note = "National PTI; all times explicit; Sunday table printed twice"),

    list(key = "21", short_name = "21", operator = "First Bristol",
         format = "column",
         file = "EFA01__0000b3a_TP.pdf",
         stop_regex = "^Newbridge, Newbridge P&R",
         directions = c(out = "Newbridge Park & Ride - Bath Centre",
                        back = "Bath Centre - Newbridge Park & Ride"),
         note = "valid from 06/04/2026, so current for this snapshot"),

    list(key = "1_1A", short_name = c("1", "1A"),
         operator = "Stagecoach.*(North West|Cumbria)",
         format = "column",
         file = "CNL 0625 1 1A WEB.pdf",
         stop_regex = "Lancaster Bus Station stand 17 dep",
         directions = c(
           to_heysham = "Lancaster University . Bus Station . Morecambe . Heysham",
           to_university = "Heysham . Morecambe . Bus Station . Lancaster University"),
         note = paste("frequent periods abbreviated as minutes past each hour",
                      "and expanded; carries university term-time and",
                      "holiday-only journeys, so it exercises the",
                      "ServicedOrganisation handling directly")),

    # Greater Manchester. The 143 and 111 carry the largest TNDS-versus-BODS
    # gap in the whole comparison (143: 24,158 against 336). Both are summer
    # editions, which for once is what is wanted: 19 July - 29 August 2026
    # contains the validation window entirely.
    list(key = "111", short_name = "111", operator = "Bee Network|Metroline",
         format = "column", file = "111_26-SC-0230_Summer.pdf",
         stop_regex = "^Southern Cemetery, Bus Station",
         directions = NULL,
         note = paste("summer edition covering the window; the frequent",
                      "period is abbreviated in-column and this page mixes",
                      "a 12-minute and a 15-minute block")),

    list(key = "143", short_name = "143", operator = "Bee Network|Metroline",
         format = "column", file = "143_26-SC-0248_Summer.pdf",
         stop_regex = "^West Didsbury, Central Road",
         directions = NULL,
         note = "summer edition covering the window; 10-minute headway block"),

    # Scotland. These replace the unusable Lothian documents: the SPT
    # generator prints every time explicitly, so no expansion is needed.
    # Several routes share one table, hence routes_in_table/count_routes.
    list(key = "G1", short_name = c("1", "1A"),
         operator = "First Glasgow|Greater Glasgow",
         format = "column",
         files = c(MF = "timetable_1-1A-1C-1E.pdf",
                   Sa = "timetable_1-1A-1C-1E_saturday.pdf",
                   Su = "timetable_1-1A-1C-1E_sunday.pdf"),
         stop_regex = "^Clydebank, Chalmers St",
         directions = NULL,
         routes_in_table = c("1", "1A", "1C", "1E"),
         count_routes = c("1", "1A"),
         note = paste("both directions are printed without any direction",
                      "heading - the stop order simply reverses partway -",
                      "so this counts departures at one stop across both")),

    list(key = "X85", short_name = c("X85", "X87"),
         operator = "First Glasgow|Greater Glasgow",
         format = "column",
         files = c(MF = "timetable_X85-X87.pdf",
                   Sa = "timetable_X85-X87_saturday.pdf",
                   Su = "timetable_X85-X87_sunday.pdf"),
         stop_regex = "^Kirkintilloch, Catherine St",
         directions = NULL,
         routes_in_table = c("X85", "X87"),
         note = "two routes in one table, both counted"),

    list(key = "F38", short_name = "38", operator = "First|Midland Bluebird",
         format = "column", file = "38-timetable-20250915-5aa561fc.pdf",
         stop_regex = "^Larbert Viaduct",
         directions = NULL,
         note = paste("Falkirk-Stirling; the 'then every 15 mins until'",
                      "legend is stacked one word per stop row inside the",
                      "table, which is why it needs positional reading")),

    list(key = "SF2A", short_name = "2A", operator = "Stagecoach",
         format = "column", file = "ESCOT_Fife_Service_2A_Timetable.pdf",
         stop_regex = "^Fife Leisure Park",
         directions = NULL,
         note = "Dunfermline circular; minutes-past-the-hour abbreviation"),

    list(key = "SF34", short_name = c("34", "34A", "34B"),
         operator = "Stagecoach",
         format = "column",
         file = "ESCOT_Fife_Service_34_34A_34B_Timetable.pdf",
         stop_regex = "^Chapel Roundabout",
         directions = NULL,
         routes_in_table = c("34", "34A", "34B"),
         note = "Kirkcaldy circular; three routes in one table"),

    list(key = "SF90", short_name = c("90A", "90B", "91A"),
         operator = "Stagecoach",
         format = "column", file = "ESCOT_Special_Fife_90_91.pdf",
         stop_regex = "^David Russell Apts",
         directions = NULL,
         routes_in_table = c("90A", "90B", "91A"),
         note = "St Andrews circular; three routes in one table"),

    list(key = "SFX24", short_name = c("X24", "X27"),
         operator = "Stagecoach",
         format = "column", file = "ESCOT_Special_X24_X27.pdf",
         stop_regex = "^Glenrothes Bus Station Dep",
         directions = NULL,
         routes_in_table = c("X24", "X27"),
         note = "Fife-Glasgow limited stop; tests longer-distance services"),

    # Wales. TNDS is effectively the only source with real coverage there,
    # so until now nothing independent checked it.
    list(key = "CDF1", short_name = "1", operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "1-timetable-20260719-78437e73.pdf",
         stop_regex = "^Leckwith Close",
         directions = NULL,
         note = "city circle, commencing 19/07/2026 so current for the window"),

    list(key = "CDF24", short_name = "24", operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "24-timetable-20260719-baf4da5e.pdf",
         stop_regex = "^Three Elms",
         directions = NULL,
         note = "commencing 19/07/2026; minutes-past-the-hour abbreviation"),

    list(key = "CDF608", short_name = "608",
         operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "608-timetable-20230903-be43cf29.pdf",
         stop_regex = "^Channel View Road",
         directions = NULL,
         note = paste("schooldays-only school service, one journey each way.",
                      "The edition is from 2023, so a zero in the feeds may",
                      "mean the service has gone rather than that the",
                      "conversion lost it - and in a school-holiday window",
                      "it should correctly not run at all")),

    list(key = "CDF62", short_name = c("62", "63", "64"),
         operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "62-timetable-20260412-d4fd5ee2.pdf",
         stop_regex = "^Llandaff Fields",
         directions = NULL,
         routes_in_table = c("62", "63", "64"),
         note = paste("valid from 12/04/2026; three routes in one table.",
                      "Counted at Llandaff Fields because it is the only",
                      "stop named identically in both directions - the",
                      "inbound tables call the outbound's Black Lion stop",
                      "something else. Carries a 'Sundays & public holidays'",
                      "table, so it also covers the 31 August holiday")),

    # Kinchbus published only artwork as PDF - no text layer at all - so
    # this one comes from a Word extract instead.
    list(key = "KB9", short_name = "9", operator = "Kinchbus|trentbarton",
         format = "docx", file = "Kinchbus 9.docx",
         stop_regex = "^Costock Main Street",
         note = paste("Loughborough-Nottingham. One Monday-to-Saturday table",
                      "carries both day types, marked per journey: NS runs",
                      "Monday to Friday only, S on Saturdays only, unmarked",
                      "on both, so it is read once per day type. Also",
                      "publishes a separate Sunday & Bank Holiday Monday",
                      "table - the only bank holiday reference in the set")),

    list(key = "TBALL", short_name = NULL, long_name_regex = "allestree",
         operator = "trentbarton|Kinchbus|Wellglade",
         format = "docx", file = "Kinchbus allestree .docx",
         stop_regex = "^Kedleston Road University",
         note = paste("trentbarton Derby-Allestree, from a Word extract:",
                      "the six PDFs of this timetable have no text layer at",
                      "all. The document names no route number - its 'Bus",
                      "No' column is blank - so it is matched on route long",
                      "name, which needs confirming against the feeds.",
                      "Monday-Friday includes journeys marked 'F - Fridays",
                      "only', so that figure is the Friday service level and",
                      "slightly overstates Monday to Thursday. Carries a",
                      "Sunday & Bank Holiday Monday table")),

    list(key = "142", short_name = "142", operator = "Bee Network|Metroline",
         format = "column",
         file = "142_26-SC-0249_Summer.pdf",
         stop_regex = "^East Didsbury, Parrs Wood",
         directions = NULL,
         skip = TRUE,
         note = paste("SUMMER timetable (19 Jul - 29 Aug 2026): covers this",
                      "snapshot, but merges route 42 journeys into the same",
                      "table, so the count is not attributable to route 142")),

    # Lothian: poppler takes ten minutes or more per document, so these two
    # dominate the runtime of this target. They are the only Scottish
    # validation available, which is worth the wait.
    # Direction titles are matched on the route number and the terminus named
    # first, not on the full "A to B" phrase: reading these documents as
    # positioned words reorders it to "Airport City Centre to".
    list(key = "L100", short_name = "100", operator = "Lothian",
         format = "column", file = "r100-260222.pdf",
         stop_regex = "^Edinburgh Airport",
         directions = c(from_airport = "^100 Airport",
                        to_airport = "^100 City Centre"),
         note = paste("NOT USABLE YET. The frequent-service period is a",
                      "separate mini-table whose closing time sits on a",
                      "different baseline from its opening time, so the block",
                      "is not detected and the count omits it entirely. Also",
                      "note the legend reads 'up to every 10 mins', which is",
                      "a ceiling rather than a timetable. Needs a reader that",
                      "assigns cells in two dimensions instead of by text",
                      "row.")),

    list(key = "L26", short_name = "26", operator = "Lothian",
         format = "column", file = "r26-260222.pdf",
         stop_regex = "^Clerwood",
         directions = c(to_seton = "^26 Clerwood",
                        to_clerwood = "^26 Seton Sands"),
         note = paste("NOT USABLE YET, same reason as the 100. Saturday also",
                      "runs over two pages as 'Saturdays continued'."))
  )
}

#' Departures per operating day implied by a route's published timetable
#'
#' @return data.table(key, daytype, direction, journeys, expanded)
published_departures <- function(spec, dir = "data/example_timetables") {
  if (identical(spec$format, "tfl")) {
    out <- data.table::rbindlist(lapply(names(spec$files), function(dt) {
      v <- read_tfl_schedule(file.path(dir, spec$files[[dt]]), node = spec$node)
      data.table::data.table(file_daytype = dt, direction = "all",
                             minutes = list(v))
    }))
    # TfL issues the night portion of a 24-hour route as its own schedule
    # (route 69's MTNt, FrNt, ...). One operating day is the day schedule plus
    # its night schedule, so they are combined before counting.
    out[, daytype := if (is.null(spec$combine)) file_daytype else
      ifelse(file_daytype %in% names(spec$combine),
             spec$combine[file_daytype], file_daytype)]
    return(out[, list(journeys = length(unlist(minutes)), expanded = FALSE,
                      upper_bound = FALSE, reliable = TRUE,
                      minutes = list(sort(unlist(minutes)))),
               by = list(daytype, direction)])
  }

  # Several routes are published as one document per day type.
  files <- if (!is.null(spec$files)) spec$files else c(all = spec$file)
  res <- if (identical(spec$format, "docx")) {
    lapply(files, function(f)
      read_docx_timetable(file.path(dir, f), stop_regex = spec$stop_regex))
  } else lapply(files, function(f)
    read_column_timetable(file.path(dir, f),
                          stop_regex = spec$stop_regex,
                          direction_patterns = spec$directions,
                          routes_in_table = spec$routes_in_table,
                          count_routes = spec$count_routes %||% spec$short_name,
                          day_patterns = spec$day_patterns %||%
                            eval(formals(read_column_timetable)$day_patterns)))
  times <- data.table::rbindlist(lapply(seq_along(res), function(i) {
    t <- res[[i]]$times
    if (nrow(t)) t[, block := block + i * 1000L]
    t
  }))
  reliable <- all(vapply(res, function(x) isTRUE(x$reliable), logical(1)))
  times <- tt_dedupe_repeated_blocks(times)
  if (!nrow(times)) {
    return(data.table::data.table(daytype = character(0), direction = character(0),
                                  journeys = integer(0), expanded = logical(0),
                                  upper_bound = logical(0), reliable = logical(0),
                                  minutes = list()))
  }
  out <- times[, list(journeys = .N, expanded = any(expanded),
                      upper_bound = any(upper_bound),
                      minutes = list(sort(minutes))),
               by = list(daytype, direction)]
  out[, continuous := vapply(minutes, tt_no_hole, logical(1))]
  out[, reliable := reliable & continuous]
  out[]
}

#' Does a day's reading have a hole in it?
#'
#' The failure that matters is not a reader that crashes but one that quietly
#' returns a plausible subset - a whole block of the day missed because its
#' heading, its stop label or its abbreviation was written differently. It
#' shows up as an implausible gap between consecutive departures: the Fife 34
#' reads as running 06:10-10:10 and then nothing until 18:31.
#'
#' The test is deliberately loose, because genuinely sparse services exist
#' and a false alarm costs a usable reference. It only fires when a single
#' gap dwarfs the rest of the day's spacing.
tt_no_hole <- function(m, floor_mins = 150, factor = 8) {
  m <- sort(unique(m))
  if (length(m) < 6) return(TRUE)
  g <- diff(m)
  max(g) <= max(floor_mins, factor * stats::median(g))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Journeys operating on each date of the window, for one route in one feed
#'
#' Routes are located by public number and operator, and every matching
#' route_id is summed: a source that splits one service across several ids
#' (TNDS holds the Manchester 142 under three) must still be compared as one.
feed_route_departures <- function(gtfs, short_name, operator, win,
                                  long_name_regex = NULL) {
  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  agency <- data.table::as.data.table(as.data.frame(gtfs$agency))
  routes[, route_id := as.character(route_id)]
  if ("agency_id" %in% names(routes) && "agency_id" %in% names(agency)) {
    routes <- merge(routes,
                    unique(agency[, list(agency_id = as.character(agency_id),
                                         agency_name = as.character(agency_name))],
                           by = "agency_id"),
                    by.x = "agency_id", by.y = "agency_id", all.x = TRUE)
  } else {
    routes[, agency_name := NA_character_]
  }
  # Some operators brand rather than number. trentbarton's Derby-Allestree
  # service is published as "allestree" with the bus number column left
  # blank, so there is no short name to match on and the long name is the
  # only handle the feeds offer.
  by_short <- if (is.null(short_name)) rep(FALSE, nrow(routes)) else
    toupper(trimws(routes$route_short_name)) %in% toupper(short_name)
  by_long <- if (is.null(long_name_regex)) rep(FALSE, nrow(routes)) else
    grepl(long_name_regex, routes$route_long_name, ignore.case = TRUE)
  keep <- (by_short | by_long) &
    grepl(operator, routes$agency_name, ignore.case = TRUE)
  ids <- routes$route_id[which(keep)]
  if (!length(ids)) {
    return(list(route_ids = character(0), runs = 0L, per_date = NULL))
  }

  trimmed <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                                      enddate = win$enddate)
  runs <- trip_runs_in_window(trimmed)
  trips <- data.table::as.data.table(as.data.frame(trimmed$trips))
  trips <- trips[as.character(route_id) %in% ids,
                 list(trip_id = as.character(trip_id))]
  runs <- runs[trip_id %in% trips$trip_id]
  list(route_ids = ids, runs = sum(runs$runs))
}

#' Check every route with a published timetable against all three sources
#'
#' Writes data/pdf_validation.Rds and returns its path.
validate_published_timetables <- function(zones_path, ..., cfg = load_cfg()) {
  spec <- validation_snapshot()
  wins <- lapply(validation_windows(), study_window)
  for (nm in names(wins))
    message("Validation window ", nm, ": ", wins[[nm]]$startdate, " to ",
            wins[[nm]]$enddate)

  routes <- validation_routes()
  published <- lapply(routes, function(r) {
    if (isTRUE(r$skip)) return(NULL)
    out <- try(published_departures(r), silent = TRUE)
    if (inherits(out, "try-error")) {
      warning("could not read the timetable for ", r$key, ": ",
              conditionMessage(attr(out, "condition")))
      return(NULL)
    }
    out[, key := r$key][]
  })
  names(published) <- vapply(routes, `[[`, "", "key")

  feeds <- list()
  for (src in comparison_sources()) {
    message("Reading ", src)
    gtfs <- read_feed(spec[[src]], cfg)
    gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
    feeds[[src]] <- data.table::rbindlist(lapply(names(wins), function(wn) {
      data.table::rbindlist(lapply(routes, function(r) {
        f <- feed_route_departures(gtfs, r$short_name, r$operator, wins[[wn]],
                                   long_name_regex = r$long_name_regex)
        data.table::data.table(key = r$key, source = src, window = wn,
                               route_ids = paste(f$route_ids, collapse = "+"),
                               runs = f$runs)
      }))
    }))
    rm(gtfs); gc()
  }

  out <- list(snapshot = spec, window = wins,
              routes = routes,
              published = published,
              feeds = data.table::rbindlist(feeds))
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(cfg$out_dir, "pdf_validation.Rds")
  saveRDS(out, path)
  path
}

#' Knit the validation report to markdown
render_validation_report <- function(validation_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$validation_path <- normalizePath(validation_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "pdf_validation.Rmd", output = "pdf_validation.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "pdf_validation.md")
}
