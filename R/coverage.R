# Where and when the timetable archives actually have data.
#
# The series runs 2004-2025 across four different sources, and the sources do
# not all cover the whole country in every year. The manual's coverage figure
# (images/manual/transport_bus_data.webp) recorded that as a hand-assessed
# region-by-year grid, last revised several years ago and stopping at 2023.
# This rebuilds the same idea from the converted feeds themselves, at ATCO
# administrative area rather than region, and keeps it current: the target
# takes every feed as a dependency, so reconverting any year re-measures it.
#
# The unit is the ATCO administrative area, because that is the unit the
# archives are actually assembled from - a missing area is a missing set of
# files, which is what a coverage gap physically is. Every stop id in every
# era carries its area in the first three characters (NaPTAN AtcoCode), and
# 99.6-100% of stops in every feed join to UK2GTFS's `atco_areas` lookup, so
# one rule works across NPTDR, the Bus Archive and TNDS alike.
#
# Only the bus-side feeds are measured. The rail CIF feeds are keyed on TIPLOC
# rather than ATCO, so the same join cannot be made, and rail coverage is a
# different question with a different source.

#' ATCO administrative areas, with boundaries
#'
#' UK2GTFS ships these as an sf object: 147 areas with a code, a name, a
#' region and a polygon, including the four "Great Britain" pseudo-areas that
#' hold the national air, ferry, rail and tram networks.
#'
#' @return an sf data frame, or NULL if the package data is unavailable
#' @keywords internal
coverage_atco_areas <- function() {
  f <- system.file("extdata", "atco_areas.rda", package = "UK2GTFS")
  if (!nzchar(f) || !file.exists(f)) return(NULL)
  e <- new.env()
  load(f, envir = e)
  if (!"atco_areas" %in% ls(e)) return(NULL)
  a <- e$atco_areas
  # the lookup writes these as "  Scotland (630)" - the code is already the
  # atco_code column, and the leading space makes an otherwise identical
  # region name compare unequal to a plain one
  a$region <- trimws(sub("[(].*$", "", a$region))
  a$name <- trimws(a$name)
  a
}

#' Read one table out of a feed without leaving it on disk
#'
#' utils::unzip rather than a pipe from the `unzip` executable, which is not
#' on the PATH of every session this pipeline runs in. stop_times is tens of
#' millions of rows, so the extracted copy is removed as soon as it is read
#' rather than cached.
#'
#' @param feed path to a GTFS zip
#' @param table table name without the .txt
#' @param select columns to read
#' @return a data.table, or NULL if the feed has no such table
#' @keywords internal
coverage_read <- function(feed, table, select = NULL) {
  td <- file.path(tempdir(), "coverage", basename(feed))
  dir.create(td, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  f <- file.path(td, paste0(table, ".txt"))
  ok <- try(utils::unzip(feed, files = paste0(table, ".txt"), exdir = td,
                         overwrite = TRUE), silent = TRUE)
  if (inherits(ok, "try-error") || !file.exists(f)) return(NULL)
  args <- list(f)
  if (!is.null(select)) args$select <- select
  do.call(data.table::fread, args)
}

#' Put a feed's stops into ATCO areas
#'
#' Two mechanisms, because the sources do not agree on what a stop id is.
#' Every TransXChange- or ATCO-CIF-derived feed uses NaPTAN AtcoCodes, whose
#' first three characters are the administrative area, and 99.6-100% of them
#' join to the lookup. The rail CIF feeds key on TIPLOC instead ("ABDARE",
#' "ABDO"), where the leading characters mean nothing, so those stops are
#' placed by their coordinates. The result records which was used, because
#' the two are not equally exact and the report says so.
#'
#' @param s a data.table of stop_id, stop_lon, stop_lat
#' @param areas the ATCO areas sf
#' @return the same table with an `atco_code` column, plus an "assign"
#'   attribute of "prefix" or "spatial"
#' @keywords internal
coverage_assign_areas <- function(s, areas) {
  codes <- if (is.null(areas)) character(0) else areas$atco_code
  s[, atco_code := substr(stop_id, 1L, 3L)]
  rate <- if (length(codes)) mean(s$atco_code %in% codes) else 0
  if (rate >= 0.5 || is.null(areas)) {
    data.table::setattr(s, "assign", "prefix")
    data.table::setattr(s, "match_rate", rate)
    return(s)
  }
  # TIPLOC feed: fall back to position.
  #
  # The four "Great Britain" pseudo-areas are excluded from the join target.
  # They are national networks, not places, and their geometry spans the
  # whole country - left in, every station matches its own area and all of
  # them, five polygons deep. A station belongs to the authority it stands
  # in; what mode it carries is a separate question, answered by route_type.
  geo <- areas[areas$region != "Great Britain", ]
  ok <- !is.na(s$stop_lon) & !is.na(s$stop_lat)
  s[, atco_code := NA_character_]
  if (any(ok)) {
    pts <- sf::st_as_sf(s[ok, list(stop_lon, stop_lat)],
                        coords = c("stop_lon", "stop_lat"),
                        crs = sf::st_crs(geo))
    # one row per point, not one per point-polygon pair: a station on a
    # shared boundary matches both neighbours, so take its first area
    suppressMessages({
      idx <- sf::st_intersects(pts, geo, sparse = TRUE)
    })
    first <- vapply(idx, function(i) if (length(i)) i[[1]] else NA_integer_,
                    integer(1))
    s[ok, atco_code := geo$atco_code[first]]
  }
  data.table::setattr(s, "assign", "spatial")
  data.table::setattr(s, "match_rate", mean(!is.na(s$atco_code)))
  s
}

#' Measure one feed's coverage, by ATCO area and mode
#'
#' Three numbers, because they fail in different ways. `stops` is what the
#' feed describes, `served` is how many of those a vehicle actually calls at,
#' and `departures` is how much service that amounts to. A feed can list an
#' area's stops and run nothing from them, which `stops` alone would score as
#' present.
#'
#' Departures and served stops are broken down by `route_type` as well as by
#' area, so the same machinery answers "which modes does this year hold, and
#' where" without reading the feeds a second time.
#'
#' @param feed path to a GTFS zip
#' @param label the feed's label, carried through to the result
#' @param areas the ATCO areas sf, passed in rather than reloaded per feed
#' @param cache_dir where per-feed results are kept between runs
#' @return a list of `areas` (stops per area) and `modes` (served and
#'   departures per area and route_type)
#' @keywords internal
coverage_feed_areas <- function(feed, label, areas = coverage_atco_areas(),
                                cache_dir = file.path("gtfs", "cache",
                                                      "coverage")) {
  if (!file.exists(feed)) {
    message("  missing, skipped: ", feed)
    return(NULL)
  }
  # Cached per feed, keyed on the feed's own modification time, so a
  # reconverted year re-measures itself and an interrupted run resumes.
  # A TNDS stop_times is fifty million rows, so losing twenty minutes of
  # completed work to the twenty-second feed is worth avoiding. The v2 in
  # the key is the shape of the cached object: v1 had no mode breakdown.
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  key <- paste0(sub("[.]zip$", "", basename(feed)), "_",
                format(file.mtime(feed), "%Y%m%d%H%M%S"), "_v2.rds")
  cf <- file.path(cache_dir, key)
  if (file.exists(cf)) {
    message("  ", label, ": cached")
    out <- readRDS(cf)
    out$areas <- data.table::as.data.table(out$areas)
    out$modes <- data.table::as.data.table(out$modes)
    out$areas[, label := label]
    out$modes[, label := label]
    return(out)
  }

  message("  ", label, ": ", basename(feed))
  s <- coverage_read(feed, "stops",
                     select = c("stop_id", "stop_lon", "stop_lat"))
  if (is.null(s)) return(NULL)
  data.table::setDT(s)
  s[, stop_id := as.character(stop_id)]
  s <- coverage_assign_areas(s, areas)
  assign_by <- attr(s, "assign")
  a <- s[, list(stops = .N), by = "atco_code"]
  stop_area <- s[, list(stop_id, atco_code)]
  rm(s); gc(verbose = FALSE)

  # trip_id -> route_type, so departures can be split by mode
  tr <- coverage_read(feed, "trips", select = c("trip_id", "route_id"))
  ro <- coverage_read(feed, "routes", select = c("route_id", "route_type"))
  if (is.null(tr) || is.null(ro)) return(NULL)
  data.table::setDT(tr); data.table::setDT(ro)
  tr[, trip_id := as.character(trip_id)]
  tr[, route_id := as.character(route_id)]
  ro[, route_id := as.character(route_id)]
  tr[ro, route_type := i.route_type, on = "route_id"]
  tr <- tr[, list(trip_id, route_type)]

  # update joins rather than merges: the stop_times vector is tens of
  # millions of rows and does not want copying twice
  st <- coverage_read(feed, "stop_times", select = c("trip_id", "stop_id"))
  if (is.null(st)) return(NULL)
  data.table::setDT(st)
  st[, stop_id := as.character(stop_id)]
  st[, trip_id := as.character(trip_id)]
  st[tr, route_type := i.route_type, on = "trip_id"]
  st[stop_area, atco_code := i.atco_code, on = "stop_id"]
  b <- st[, list(served = data.table::uniqueN(stop_id), departures = .N),
          by = c("atco_code", "route_type")]
  rm(st, tr, ro, stop_area); gc(verbose = FALSE)

  out <- list(areas = as.data.frame(a), modes = as.data.frame(b),
              assign = assign_by)
  saveRDS(out, cf)
  out$areas <- data.table::as.data.table(out$areas)
  out$modes <- data.table::as.data.table(out$modes)
  out$areas[, label := label]
  out$modes[, label := label]
  out
}

#' Coverage of the bus-side feeds, by ATCO area and year
#'
#' @param feed_paths ignored; present so the target can depend on every feed
#'   and re-measure whenever one is reconverted
#' @param cfg pipeline config
#' @return path to data/coverage.Rds
#' @keywords internal
coverage_analysis <- function(feed_paths = NULL, cfg = load_cfg()) {
  spec <- year_sources(cfg)
  res <- list(generated = Sys.time())

  # one row per feed, both sides. 2024 and 2025 take bus from two feeds each
  # (the TNDS snapshot and the BODS coach dataset), and both count towards
  # that year's coverage, so they are measured separately and summed.
  mk <- function(f, y, side) {
    w <- study_window(f$ref)
    data.table::data.table(
      year = y, side = side, path = f$path, ref = as.character(f$ref),
      window_start = as.character(w$startdate),
      window_end = as.character(w$enddate),
      label = paste0(y, " ", sub("[.]zip$", "", basename(f$path))))
  }
  feeds_all <- data.table::rbindlist(lapply(spec, function(s) {
    b <- data.table::rbindlist(lapply(s$bus, mk, y = s$year, side = "bus"))
    r <- if (is.null(s$rail)) NULL else mk(s$rail, s$year, "rail")
    data.table::rbindlist(list(b, r), fill = TRUE)
  }), fill = TRUE)
  stopifnot(!any(duplicated(feeds_all$label)))
  feeds <- feeds_all[side == "bus"]
  res$feeds <- feeds
  res$feeds_all <- feeds_all

  # the analysis years, and the gap. 2012 and 2013 have no archive at all:
  # NPTDR stopped after 2011 and the Bus Archive starts in 2014.
  res$years <- sort(unique(feeds$year))
  res$missing_years <- setdiff(min(res$years):max(res$years), res$years)

  areas <- coverage_atco_areas()
  message("Measuring coverage of ", nrow(feeds_all), " feeds (",
          nrow(feeds), " bus, ", nrow(feeds_all) - nrow(feeds), " rail)")
  per <- lapply(seq_len(nrow(feeds_all)), function(i) {
    coverage_feed_areas(feeds_all$path[i], feeds_all$label[i], areas = areas)
  })
  names(per) <- feeds_all$label
  per <- per[!vapply(per, is.null, logical(1))]
  if (length(per) == 0) stop("no feed could be measured")
  res$assignment <- data.table::data.table(
    label = names(per),
    assign = vapply(per, function(x) {
      if (is.null(x$assign)) NA_character_ else as.character(x$assign)
    }, character(1)))

  # The area grid is the BUS side only, as it has always been. Adding the
  # rail CIF to it would change every figure in the report for a reason
  # unconnected to coverage, and the two sides are not independent anyway -
  # TNDS carries much of the same rail. The rail feeds are measured so the
  # mode section can use them, and are reported there.
  modes_all <- data.table::rbindlist(lapply(per, `[[`, "modes"), fill = TRUE)
  modes_all <- merge(modes_all, feeds_all[, list(label, year, side)],
                     by = "label", all.x = TRUE)
  res$modes_raw <- modes_all[]

  # no idcol: coverage_feed_areas already labels each table, and rbindlist
  # would then make a second column of the same name
  bus_labels <- feeds$label
  raw <- data.table::rbindlist(
    lapply(per[names(per) %in% bus_labels], function(x) {
      merge(x$areas, x$modes[, list(served = sum(served),
                                    departures = sum(departures)),
                             by = "atco_code"],
            by = "atco_code", all = TRUE)
    }), fill = TRUE)
  for (v in c("stops", "served", "departures")) {
    data.table::set(raw, which(is.na(raw[[v]])), v, 0L)
  }
  raw <- merge(raw, feeds[, list(label, year)], by = "label", all.x = TRUE)

  # sum the feeds that make up one year, then put every area on every year so
  # an absent area is a zero rather than a missing row - the whole point of
  # the exercise is the rows that are not there
  by_year <- raw[!is.na(atco_code),
                 list(stops = sum(stops), served = sum(served),
                      departures = sum(departures)),
                 by = c("year", "atco_code")]
  lookup <- if (is.null(areas)) {
    data.table::data.table(atco_code = unique(by_year$atco_code),
                           name = NA_character_, region = NA_character_)
  } else {
    data.table::as.data.table(sf::st_drop_geometry(areas))[
      , list(atco_code, name, region)]
  }
  # 900 is the national coach network. It is a real ATCO national code and
  # belongs with 910 rail, 920 air and 940 tram, but UK2GTFS's lookup carries
  # only those three, so it is named here rather than being swept into the
  # unassigned pile - it is one of the more informative rows in the report.
  if ("900" %in% by_year$atco_code && !"900" %in% lookup$atco_code) {
    lookup <- data.table::rbindlist(list(lookup, data.table::data.table(
      atco_code = "900", name = "National - National Coach",
      region = "Great Britain")), fill = TRUE)
  }
  # anything else the lookup does not know is a stray prefix, not an area
  extra <- setdiff(unique(by_year$atco_code), lookup$atco_code)
  if (length(extra) > 0) {
    lookup <- data.table::rbindlist(list(lookup, data.table::data.table(
      atco_code = extra, name = paste0("Unassigned (", extra, ")"),
      region = "Unassigned")), fill = TRUE)
  }
  grid <- data.table::CJ(year = res$years, atco_code = lookup$atco_code,
                         unique = TRUE)
  cov <- merge(grid, by_year, by = c("year", "atco_code"), all.x = TRUE)
  for (v in c("stops", "served", "departures")) {
    data.table::set(cov, which(is.na(cov[[v]])), v, 0L)
  }
  cov <- merge(cov, lookup, by = "atco_code", all.x = TRUE)

  # Prefixes that are not an administrative area at all - 000, 998, PTI, BRS
  # and a dozen more - appear in one or two feeds with a handful of stops and
  # would otherwise contribute a permanent baseline of about sixteen "absent"
  # areas a year. They are reported separately and kept out of the counts.
  res$unassigned <- cov[region == "Unassigned" & atco_code != "900",
                        list(years_present = sum(departures > 0),
                             stops = max(stops), departures = max(departures)),
                        by = "atco_code"][order(-stops)]
  cov <- cov[!(region == "Unassigned" & atco_code != "900")]

  # Share of the year's own total, not raw departures. The eras are not on a
  # common scale: a Bus Archive year merges one weekly snapshot per week of
  # the study window and holds every departure in each, so its feeds carry
  # several times the departures of an NPTDR or TNDS year - roughly four times
  # when the window was 28 days (about 220 million against 28 to 71 million),
  # and the ratio moves with study_weeks(), which is itself the reason not to
  # write it down. Any benchmark taken across years in raw departures inherits
  # the multiplier, and 2020 in particular came out amber almost everywhere
  # for a reason that had nothing to do with the pandemic. A share cancels it,
  # and it also cancels a genuine national change - which is right here,
  # because this measures coverage, not service.
  cov[, national := sum(departures), by = "year"]
  cov[, share := ifelse(national == 0, NA_real_, departures / national)]
  cov[, typical := stats::median(share[share > 0]), by = "atco_code"]
  cov[!is.finite(typical), typical := NA_real_]
  cov[, index := ifelse(is.na(typical) | typical == 0, NA_real_,
                        share / typical)]

  # An area that is missing because its stops are filed under a predecessor
  # authority is not a coverage gap. Local government reorganisation creates
  # ATCO areas mid-series - Central Bedfordshire and Cheshire West and
  # Chester in 2009, Leicester in 2007, Blackburn with Darwen in 2009 - and
  # the stops were in the archive all along under Bedford, Cheshire East,
  # Leicestershire and Lancashire. The test is whether the REGION grew when
  # the area first appeared: a genuine gap filling in adds the area's stops
  # to its region, a re-coding moves them within it. Central Bedfordshire
  # arrives with 1,346 stops and the South East grows by 535; Glasgow
  # arrives with 2,963 and Scotland grows by 18,142.
  rstops <- cov[, list(rstops = sum(stops)), by = c("year", "region")]
  yrs <- sort(unique(cov$year))
  first_real <- cov[!is.na(index) & index >= 0.25,
                    list(first_real = min(year)), by = "atco_code"]
  cov <- merge(cov, first_real, by = "atco_code", all.x = TRUE)
  late <- vapply(split(cov, cov$atco_code), function(d) {
    y1 <- d$first_real[1]
    if (is.na(y1)) return(FALSE)
    i <- match(y1, yrs)
    if (is.na(i) || i == 1L) return(FALSE)
    y0 <- yrs[i - 1L]
    rg <- d$region[1]
    r0 <- rstops[year == y0 & region == rg]$rstops
    r1 <- rstops[year == y1 & region == rg]$rstops
    a <- d$stops[d$year == y1]
    if (!length(r0) || !length(r1) || !length(a)) return(FALSE)
    (r1 - r0) < 0.5 * a
  }, logical(1))
  cov[, late_coded := late[as.character(atco_code)]]
  cov[is.na(late_coded), late_coded := FALSE]

  cov[, status := data.table::fcase(
    is.na(typical), "never present",
    departures == 0 & late_coded & !is.na(first_real) & year < first_real,
      "not yet coded separately",
    departures == 0, "absent",
    index < 0.25, "severe shortfall",
    index < 0.60, "partial",
    default = "present")]
  # areas that are in no feed in any year say nothing about coverage
  cov <- cov[!(status == "never present")]
  res$coverage <- cov[]
  res$recoded <- cov[status == "not yet coded separately",
                     list(years = paste(year, collapse = " "),
                          appears = first_real[1]),
                     by = c("atco_code", "name", "region")]

  # region and national roll-ups, on the same benchmark logic
  reg <- cov[, list(departures = sum(departures), served = sum(served),
                    areas = data.table::uniqueN(atco_code),
                    areas_absent = sum(status == "absent")),
             by = c("year", "region")]
  reg[, national := sum(departures), by = "year"]
  reg[, share := ifelse(national == 0, NA_real_, departures / national)]
  reg[, typical := stats::median(share[share > 0]), by = "region"]
  reg[, index := ifelse(is.na(typical) | typical == 0, NA_real_,
                        share / typical)]
  reg[, status := data.table::fcase(
    departures == 0, "absent",
    index < 0.25, "severe shortfall",
    index < 0.60, "partial",
    default = "present")]
  res$region <- reg[]
  res$national <- cov[, list(departures = sum(departures),
                             served = sum(served),
                             areas_present = sum(departures > 0),
                             areas_absent = sum(status == "absent"),
                             areas_recoded = sum(
                               status == "not yet coded separately")),
                      by = "year"][order(year)]

  # the headline verdict, computed here so the report cannot restate it.
  # "not yet coded separately" is deliberately excluded: those areas' service
  # is in the archive, under the predecessor authority's code.
  res$gaps <- cov[status %in% c("absent", "severe shortfall")][
    order(year, region, name)]

  # ---- every mode, not just bus ------------------------------------------
  #
  # The bus-side feeds are not bus-only: NPTDR carries rail, tram, metro,
  # ferry, coach and even air, and TNDS carries everything except heavy rail
  # in quantity. So the same measurements answer "which modes does each year
  # hold" with no extra reading. Rail is reported from both sides, because
  # the pipeline takes heavy rail from the CIF feeds and drops metro from
  # them, and only saying one of those would misrepresent the series.
  md <- data.table::copy(res$modes_raw)
  md[, route_type := as.integer(route_type)]
  md[is.na(route_type), route_type := -1L]
  res$modes <- md[, list(served = sum(served), departures = sum(departures),
                         areas = data.table::uniqueN(atco_code[!is.na(
                           atco_code) & departures > 0])),
                  by = c("year", "side", "route_type")][order(year, side,
                                                              route_type)]

  # per mode and area, bus side only, for the mode maps. Rail is excluded
  # here rather than mixed in: its stops are placed by coordinate and the
  # others by code, and a map that silently blends the two would imply a
  # precision the rail half does not have.
  res$mode_area <- md[side == "bus" & !is.na(atco_code),
                      list(departures = sum(departures)),
                      by = c("year", "route_type", "atco_code")]

  # which years hold a mode at all, the compact version of the above
  res$mode_years <- res$modes[departures > 0,
                              list(years = paste(sort(unique(year)),
                                                 collapse = " "),
                                   n_years = data.table::uniqueN(year),
                                   departures = sum(departures)),
                              by = c("side", "route_type")][order(side,
                                                                  route_type)]

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(cfg$out_dir, "coverage.Rds")
  saveRDS(res, out)
  message("Written ", out)
  out
}

#' Knit the data coverage report
#'
#' @param coverage_path path to data/coverage.Rds
#' @param cfg pipeline config
#' @return path to the rendered markdown
#' @keywords internal
render_coverage_report <- function(coverage_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$coverage_path <- normalizePath(coverage_path)
  # knit from inside reports/ so figure links in the md are relative to it,
  # and with knitr::knit rather than rmarkdown::render so no pandoc is needed
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "data_coverage.Rmd", output = "data_coverage.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "data_coverage.md")
}
