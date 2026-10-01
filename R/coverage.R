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

#' Measure one feed's coverage, by ATCO area
#'
#' Three numbers per area, because they fail in different ways. `stops` is
#' what the feed describes, `served` is how many of those a vehicle actually
#' calls at, and `departures` is how much service that amounts to. A feed can
#' list an area's stops and run nothing from them, which `stops` alone would
#' score as present.
#'
#' @param feed path to a GTFS zip
#' @param label the feed's label, carried through to the result
#' @return a data.table of one row per area
#' @keywords internal
#' @param cache_dir where per-feed results are kept between runs
coverage_feed_areas <- function(feed, label,
                                cache_dir = file.path("gtfs", "cache",
                                                      "coverage")) {
  if (!file.exists(feed)) {
    message("  missing, skipped: ", feed)
    return(NULL)
  }
  # Cached per feed, keyed on the feed's own modification time, so a
  # reconverted year re-measures itself and an interrupted run resumes.
  # A TNDS stop_times is fifty million rows and the largest feeds have
  # killed this process outright before; losing twenty minutes of completed
  # work to the twenty-first feed is avoidable.
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  key <- paste0(sub("[.]zip$", "", basename(feed)), "_",
                format(file.mtime(feed), "%Y%m%d%H%M%S"), ".rds")
  cf <- file.path(cache_dir, key)
  if (file.exists(cf)) {
    message("  ", label, ": cached")
    out <- readRDS(cf)
    out$label <- label
    return(data.table::as.data.table(out))
  }

  message("  ", label, ": ", basename(feed))
  s <- coverage_read(feed, "stops", select = "stop_id")
  if (is.null(s)) return(NULL)
  data.table::setDT(s)
  s[, stop_id := as.character(stop_id)]
  a <- s[, list(stops = .N), by = list(atco_code = substr(stop_id, 1L, 3L))]
  rm(s); gc(verbose = FALSE)

  # one added column rather than a second table: the stop_id vector is tens
  # of millions of elements and does not want copying
  st <- coverage_read(feed, "stop_times", select = "stop_id")
  if (is.null(st)) return(NULL)
  data.table::setDT(st)
  st[, stop_id := as.character(stop_id)]
  st[, atco_code := substr(stop_id, 1L, 3L)]
  b <- st[, list(served = data.table::uniqueN(stop_id), departures = .N),
          by = "atco_code"]
  rm(st); gc(verbose = FALSE)

  out <- merge(a, b, by = "atco_code", all = TRUE)
  out[is.na(stops), stops := 0L]
  out[is.na(served), served := 0L]
  out[is.na(departures), departures := 0L]
  saveRDS(as.data.frame(out), cf)
  out[, label := label]
  out[]
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

  # one row per bus-side feed. 2024 and 2025 take bus from two feeds each
  # (the TNDS snapshot and the BODS coach dataset), and both count towards
  # that year's coverage, so they are measured separately and summed.
  feeds <- data.table::rbindlist(lapply(spec, function(s) {
    data.table::rbindlist(lapply(seq_along(s$bus), function(i) {
      w <- study_window(s$bus[[i]]$ref)
      data.table::data.table(
        year = s$year, path = s$bus[[i]]$path,
        ref = as.character(s$bus[[i]]$ref),
        window_start = as.character(w$startdate),
        window_end = as.character(w$enddate),
        label = paste0(s$year, " ", sub("[.]zip$", "", basename(s$bus[[i]]$path))))
    }))
  }), fill = TRUE)
  stopifnot(!any(duplicated(feeds$label)))
  res$feeds <- feeds

  # the analysis years, and the gap. 2012 and 2013 have no archive at all:
  # NPTDR stopped after 2011 and the Bus Archive starts in 2014.
  res$years <- sort(unique(feeds$year))
  res$missing_years <- setdiff(min(res$years):max(res$years), res$years)

  message("Measuring coverage of ", nrow(feeds), " bus feeds")
  per <- lapply(seq_len(nrow(feeds)), function(i) {
    coverage_feed_areas(feeds$path[i], feeds$label[i])
  })
  raw <- data.table::rbindlist(per, fill = TRUE)
  if (nrow(raw) == 0) stop("no feed could be measured")
  raw <- merge(raw, feeds[, list(label, year)], by = "label", all.x = TRUE)

  # sum the feeds that make up one year, then put every area on every year so
  # an absent area is a zero rather than a missing row - the whole point of
  # the exercise is the rows that are not there
  by_year <- raw[, list(stops = sum(stops), served = sum(served),
                        departures = sum(departures)),
                 by = c("year", "atco_code")]
  areas <- coverage_atco_areas()
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
  # common scale: a Bus Archive year merges four weekly snapshots, so its
  # feeds hold roughly four times the departures of an NPTDR or TNDS year
  # (about 220 million against 28 to 71 million). Any benchmark taken across
  # years in raw departures inherits that, and 2020 in particular came out
  # amber almost everywhere for a reason that had nothing to do with the
  # pandemic. A share cancels the multiplier, and it also cancels a genuine
  # national change - which is right here, because this measures coverage,
  # not service.
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
