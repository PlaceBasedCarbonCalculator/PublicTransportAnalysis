# Conversion of raw timetable data to GTFS with UK2GTFS.
#
# ALL sources are converted from raw data by this pipeline using the current
# (fixed) UK2GTFS, so every year benefits from the same converter: correct
# calendar handling, interpolated stop times, and coach distinguished from
# bus (GTFS extended route type 200). Nothing pre-converted on the data
# drive is reused except the DfT-produced BODS GTFS feeds (2024/2025 bus),
# which are an independent source in their own right.
#
# Everything written by these functions goes to this repo's gtfs/ directory.
# Slow multi-file conversions cache per-file GTFS under gtfs/cache/ so an
# interrupted target resumes instead of restarting.

#' Write a GTFS object to <dir>/<name>.zip and return the path
write_repo_gtfs <- function(gtfs, name, dir = load_cfg()$gtfs_dir) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  UK2GTFS::gtfs_write(gtfs, folder = dir, name = name)
  file.path(dir, paste0(name, ".zip"))
}

#' GB bank holidays 2013-2018 with TransXChange holiday names
#'
#' The gov.uk ics feed behind get_bank_holidays() only covers a rolling
#' window of recent years, and UK2GTFS's historic_bank_holidays data has
#' dates but not the names TransXChange operating profiles reference. This
#' static table (checked against historic_bank_holidays in txc_calendar())
#' covers the Bus Archive era. Substitute days carry the TransXChange
#' displacement names (e.g. BoxingDayHoliday).
static_bank_holidays <- function() {
  h <- function(name, date, ew = TRUE, scot = TRUE) {
    data.frame(name = name, date = as.Date(date), EnglandWales = ew,
               Scotland = scot)
  }
  rbind(
    h("NewYearsDay", "2013-01-01"), h("Jan2ndScotland", "2013-01-02", FALSE, TRUE),
    h("GoodFriday", "2013-03-29"), h("EasterMonday", "2013-04-01", TRUE, FALSE),
    h("MayDay", "2013-05-06"), h("SpringBank", "2013-05-27"),
    h("AugustBankHolidayScotland", "2013-08-05", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2013-08-26", TRUE, FALSE),
    h("StAndrewsDay", "2013-12-02", FALSE, TRUE),
    h("ChristmasDay", "2013-12-25"), h("BoxingDay", "2013-12-26"),

    h("NewYearsDay", "2014-01-01"), h("Jan2ndScotland", "2014-01-02", FALSE, TRUE),
    h("GoodFriday", "2014-04-18"), h("EasterMonday", "2014-04-21", TRUE, FALSE),
    h("MayDay", "2014-05-05"), h("SpringBank", "2014-05-26"),
    h("AugustBankHolidayScotland", "2014-08-04", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2014-08-25", TRUE, FALSE),
    h("StAndrewsDay", "2014-12-01", FALSE, TRUE),
    h("ChristmasDay", "2014-12-25"), h("BoxingDay", "2014-12-26"),

    h("NewYearsDay", "2015-01-01"), h("Jan2ndScotland", "2015-01-02", FALSE, TRUE),
    h("GoodFriday", "2015-04-03"), h("EasterMonday", "2015-04-06", TRUE, FALSE),
    h("MayDay", "2015-05-04"), h("SpringBank", "2015-05-25"),
    h("AugustBankHolidayScotland", "2015-08-03", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2015-08-31", TRUE, FALSE),
    h("StAndrewsDay", "2015-11-30", FALSE, TRUE),
    h("ChristmasDay", "2015-12-25"), h("BoxingDayHoliday", "2015-12-28"),

    h("NewYearsDay", "2016-01-01"), h("Jan2ndScotlandHoliday", "2016-01-04", FALSE, TRUE),
    h("GoodFriday", "2016-03-25"), h("EasterMonday", "2016-03-28", TRUE, FALSE),
    h("MayDay", "2016-05-02"), h("SpringBank", "2016-05-30"),
    h("AugustBankHolidayScotland", "2016-08-01", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2016-08-29", TRUE, FALSE),
    h("StAndrewsDay", "2016-11-30", FALSE, TRUE),
    h("ChristmasDayHoliday", "2016-12-27"), h("BoxingDay", "2016-12-26"),

    h("NewYearsDayHoliday", "2017-01-02"), h("Jan2ndScotlandHoliday", "2017-01-03", FALSE, TRUE),
    h("GoodFriday", "2017-04-14"), h("EasterMonday", "2017-04-17", TRUE, FALSE),
    h("MayDay", "2017-05-01"), h("SpringBank", "2017-05-29"),
    h("AugustBankHolidayScotland", "2017-08-07", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2017-08-28", TRUE, FALSE),
    h("StAndrewsDay", "2017-11-30", FALSE, TRUE),
    h("ChristmasDay", "2017-12-25"), h("BoxingDay", "2017-12-26"),

    h("NewYearsDay", "2018-01-01"), h("Jan2ndScotland", "2018-01-02", FALSE, TRUE),
    h("GoodFriday", "2018-03-30"), h("EasterMonday", "2018-04-02", TRUE, FALSE),
    h("MayDay", "2018-05-07"), h("SpringBank", "2018-05-28"),
    h("AugustBankHolidayScotland", "2018-08-06", FALSE, TRUE),
    h("LateSummerBankHolidayNotScotland", "2018-08-27", TRUE, FALSE),
    h("StAndrewsDay", "2018-11-30", FALSE, TRUE),
    h("ChristmasDay", "2018-12-25"), h("BoxingDay", "2018-12-26")
  )
}

#' Bank-holiday calendar for TransXChange conversions, any year
#'
#' The official gov.uk feed (get_bank_holidays()) covers only a rolling
#' window of recent years; the static 2013-2018 table extends it back over
#' the Bus Archive era. The static dates are cross-checked against
#' UK2GTFS's historic_bank_holidays data (which has dates but not the names
#' TransXChange needs).
txc_calendar <- function() {
  cal <- UK2GTFS::get_bank_holidays()

  hist_cal <- static_bank_holidays()

  # Cross-check against the dates recorded in UK2GTFS-data
  e <- new.env()
  UK2GTFS::load_data("historic_bank_holidays", envir = e)
  known <- get("historic_bank_holidays", envir = e)
  chk <- hist_cal[hist_cal$date <= max(known$date), ]
  missing <- chk$date[!chk$date %in% known$date]
  if (length(missing) > 0) {
    warning("Static bank holidays not in historic_bank_holidays: ",
            paste(missing, collapse = ", "))
  }

  hist_cal <- hist_cal[!hist_cal$date %in% cal$date, ]
  cal <- rbind(cal, hist_cal)
  cal[order(cal$date), ]
}

#' Patch known-bad NaPTAN stop locations (UK2GTFS::naptan_replace)
patch_naptan <- function(gtfs) {
  e <- new.env()
  UK2GTFS::load_data("naptan_replace", envir = e)
  rep <- e$naptan_replace
  rep <- rep[rep$stop_id %in% gtfs$stops$stop_id, ]
  if (nrow(rep) > 0) {
    message("Replacing ", nrow(rep), " stop locations from naptan_replace")
    missing_cols <- setdiff(names(gtfs$stops), names(rep))
    for (mc in missing_cols) rep[[mc]] <- NA
    gtfs$stops <- gtfs$stops[!gtfs$stops$stop_id %in% rep$stop_id, ]
    gtfs$stops <- rbind(gtfs$stops, rep[, names(gtfs$stops)])
  }
  gtfs
}

#' Standard post-conversion treatment for every converted feed
post_convert <- function(gtfs, ncores) {
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  gtfs <- patch_naptan(gtfs)
  gtfs <- UK2GTFS::gtfs_interpolate_times(gtfs, ncores = ncores)
  gtfs
}

#' Convert one TransXChange zip with caching
#'
#' Converts src_zip to GTFS and writes it to cache_zip; if cache_zip already
#' exists the conversion is skipped. Returns the feed read back from the
#' cache, optionally trimmed.
#'
#' filter_duplicate_files drops superseded versions of a service before
#' conversion and reconciles registrations whose operating periods overlap;
#' filter_date is the reference date deciding which version is operative.
convert_txc_cached <- function(src_zip, cache_zip, cal, naptan, scotland,
                               cfg, trim = NULL,
                               filter_duplicate_files = FALSE,
                               filter_date = Sys.Date()) {
  if (!file.exists(cache_zip)) {
    message("Converting ", src_zip)
    gtfs <- UK2GTFS::transxchange2gtfs(src_zip, silent = TRUE, cal = cal,
                                       naptan = naptan,
                                       ncores = cfg$ncores,
                                       scotland = scotland,
                                       try_mode = TRUE, force_merge = TRUE,
                                       filter_duplicate_files =
                                         filter_duplicate_files,
                                       filter_date = filter_date)
    gtfs <- post_convert(gtfs, cfg$ncores)
    dir.create(dirname(cache_zip), showWarnings = FALSE, recursive = TRUE)
    write_repo_gtfs(gtfs, gsub("\\.zip$", "", basename(cache_zip)),
                    dirname(cache_zip))
    rm(gtfs)
  } else {
    message("Using cached ", cache_zip)
  }
  # Always read back from the cache so every downstream step sees the
  # column classes gtfs_read() produces (the in-memory transxchange2gtfs
  # object stores calendar dates differently)
  gtfs <- UK2GTFS::gtfs_read(cache_zip)
  if (!is.null(trim)) {
    gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = trim[1],
                                     enddate = trim[2])
  }
  gtfs
}

#' Convert one NPTDR year (2004-2011) from the raw October archive
#'
#' NPTDR is ATCO-CIF; nptdr2gtfs() handles the archive zip directly and uses
#' the historic bank holiday and school term data shipped with UK2GTFS.
convert_nptdr_year <- function(year, naptan, cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "NPTDR", sprintf("October-%s.zip", year))
  gtfs <- UK2GTFS::nptdr2gtfs(src, silent = TRUE, naptan = naptan)
  gtfs <- post_convert(gtfs, cfg$ncores)
  write_repo_gtfs(gtfs, paste0("nptdr_", year))
}

#' Enumerate the raw Bus Archive weekly TransXChange zips for one year
#'
#' 2014-2016 are flat files "REGION yyyymmdd.zip"; 2017 has one folder per
#' weekly snapshot containing "REGION.zip". Returns a data frame with the
#' zip path, region code and snapshot date.
bus_archive_files <- function(year, cfg = load_cfg()) {
  root <- file.path(cfg$data_root, "Bus Archive", paste0(year, " Oct"))
  if (year %in% 2014:2016) {
    zips <- list.files(root, pattern = "\\.zip$", full.names = TRUE)
    base <- gsub("\\.zip$", "", basename(zips))
    parts <- strsplit(base, "\\s+")
    out <- data.frame(
      path = zips,
      region = vapply(parts, `[`, "", 1),
      snapshot = lubridate::ymd(vapply(parts, function(x) x[length(x)], ""))
    )
  } else {
    weeks <- list.dirs(root, recursive = FALSE)
    weeks <- weeks[grepl("^\\d{8}$", basename(weeks))]
    out <- do.call(rbind, lapply(weeks, function(w) {
      zips <- list.files(w, pattern = "\\.zip$", full.names = TRUE)
      data.frame(path = zips,
                 region = gsub("\\.zip$", "", basename(zips)),
                 snapshot = lubridate::ymd(basename(w)))
    }))
  }
  # Use the (up to) four weekly snapshots that tile the study window: the
  # Monday-aligned 28 days starting in the week of the first October snapshot
  win <- study_window(min(out$snapshot))
  out <- out[out$snapshot >= win$startdate & out$snapshot <= win$enddate, ]
  out[order(out$snapshot, out$region), ]
}

#' Build one year of the Bus Archive (2014-2017) from raw TransXChange
#'
#' Each weekly regional snapshot is converted (with caching), trimmed to the
#' Monday-Sunday week containing its snapshot date, and merged, so the
#' merged feed exactly tiles the Monday-aligned 28-day study window.
convert_bus_archive_year <- function(year, cal, naptan, cfg = load_cfg()) {
  files <- bus_archive_files(year, cfg)
  message(nrow(files), " weekly regional files for ", year)

  gtfs_all <- lapply(seq_len(nrow(files)), function(i) {
    f <- files[i, ]
    week_start <- lubridate::floor_date(f$snapshot, unit = "week",
                                        week_start = 1)
    cache <- file.path(cfg$gtfs_dir, "cache", paste0("busarchive_", year),
                       sprintf("%s_%s.zip", f$region,
                               format(f$snapshot, "%Y%m%d")))
    convert_txc_cached(f$path, cache, cal, naptan,
                       scotland = ifelse(f$region == "S", "yes", "no"),
                       cfg = cfg, trim = c(week_start, week_start + 6))
  })

  merged <- UK2GTFS::gtfs_merge(gtfs_all, force = TRUE)
  merged <- UK2GTFS::gtfs_clean(merged)
  write_repo_gtfs(merged, paste0("busarchive_", year, "_merged"))
}

#' How far either side of its snapshot date a TNDS conversion is kept
#'
#' The counting windows are 28 days, so 31 was enough for the comparison. It
#' was not enough for validation: validation_windows() has a second window
#' opening two weeks after the first so that a bank holiday falls inside it,
#' which ends 42 days past the snapshot. With a 31-day trim the last 11 days of
#' that window were empty in TNDS by construction, and every TNDS count in it
#' came out at almost exactly 17/28 of the first window's - an artefact that
#' made the two bank-holiday reference timetables (the Cardiff 62's "Sundays &
#' public holidays" table, Kinchbus's "Sunday & Bank Holiday Monday" table)
#' impossible to test against TNDS at all.
#'
#' 45 covers that window with a fortnight to spare. Widening only *adds*
#' calendar coverage: every consumer re-trims to its own window before
#' counting, so no figure inside a narrower window changes. The feed-level
#' totals in the comparison report (routes, trips, calendar_end) do grow,
#' because those are whole-feed counts rather than windowed ones.
#'
#' It does not make the extra fortnight as trustworthy as the rest. A snapshot
#' carries the registration operative on the day it was taken, so service late
#' in the window may have expired - which is a real property of the source,
#' now measurable rather than masked by an empty tail. See
#' window_expiry_stats().
tnds_trim_days <- function() 45L

#' Convert one TNDS snapshot (regional zips + NCSD coach archive) to GTFS
#'
#' Each regional zip is converted with caching, trimmed to +/- tnds_trim_days()
#' around the snapshot date, then merged. NCSD.zip (the national coach
#' services database) is included where present; it is absent from TNDS
#' snapshots after February 2025.
#'
#' Conversion filters duplicate files, with the snapshot date as the reference
#' date. TNDS is a current-data download rather than a change archive, so the
#' revision rules rarely fire; what does fire is the overlap reconciliation.
#' TNDS carries a service and its own successor registration at the same time,
#' both declaring periods that overlap, because publishers issue the successor
#' without closing the predecessor - Transport for London mints a new
#' ServiceCode each time, so the two are invisible to any check keyed on the
#' code. Converting both makes one bus into two near-identical journeys a few
#' minutes apart. See reports/near_duplicate_journeys.md.
convert_tnds_snapshot <- function(snapshot, cal, naptan, cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
  zips <- list.files(src, pattern = "\\.zip$", full.names = TRUE)
  if (length(zips) == 0) stop("No TNDS zips found in ", src)
  if (!any(grepl("NCSD", zips))) {
    message("Note: no NCSD.zip (coach) in TNDS snapshot ", snapshot)
  }

  snap_date <- lubridate::ymd(snapshot)
  gtfs_all <- lapply(zips, function(z) {
    region <- gsub("\\.zip$", "", basename(z))
    cache <- file.path(cfg$gtfs_dir, "cache", paste0("tnds_", snapshot),
                       paste0(region, ".zip"))
    convert_txc_cached(z, cache, cal, naptan,
                       scotland = ifelse(region == "S", "yes", "no"),
                       cfg = cfg,
                       trim = c(snap_date - tnds_trim_days(),
                                snap_date + tnds_trim_days()),
                       filter_duplicate_files = TRUE,
                       filter_date = snap_date)
  })

  merged <- UK2GTFS::gtfs_merge(gtfs_all, force = TRUE)
  merged <- UK2GTFS::gtfs_clean(merged)
  write_repo_gtfs(merged, paste0("tnds_", snapshot, "_merged"))
}

#' Convert one ATOC CIF snapshot to GTFS (rail, 2018-2024)
convert_atoc_date <- function(date, cfg = load_cfg()) {
  src_dir <- file.path(cfg$data_root, "ATOC", "timetable", date)
  zps <- list.files(src_dir, pattern = "\\.zip$", full.names = TRUE,
                    recursive = TRUE)
  zps <- zps[!grepl("xml", zps)]
  if (length(zps) != 1) stop("Expected one CIF zip in ", src_dir,
                             ", found ", length(zps))
  gtfs <- UK2GTFS::atoc2gtfs(zps, silent = TRUE, shapes = FALSE,
                             ncores = cfg$ncores)
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  write_repo_gtfs(gtfs, paste0("rail_atoc_", date))
}

#' Convert the National Rail Data Portal CIF timetable to GTFS (2025 on)
#'
#' The Rail Data Portal (opendata.nationalrail.co.uk) replaced the old ATOC
#' data feed; its timetable.zip is a CIF file in the newer RSPS5046 flavour,
#' which the current UK2GTFS atoc2gtfs() supports.
convert_rail_rdp <- function(snapshot = "20251006", cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "RailDataPortal", snapshot, "timetable.zip")
  gtfs <- UK2GTFS::atoc2gtfs(src, silent = TRUE, shapes = FALSE,
                             ncores = cfg$ncores)
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  write_repo_gtfs(gtfs, paste0("rail_rdp_", snapshot))
}

#' Convert the BODS TransXChange change archive to GTFS
#'
#' The Bus Open Data Service archive contains every revision of every
#' dataset; txc_filter_files()/filter_duplicate_files drops superseded
#' revisions of the same service, keeping the revision valid on filter_date.
convert_bods_txc <- function(snapshot, cal, naptan,
                             archive = "bodds_archive_20251005.zip",
                             filter_date = "2025-10-06",
                             cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "OpenBusData/TransXchange", snapshot, archive)

  cache <- file.path(cfg$gtfs_dir, "cache",
                     paste0("bods_txc_", snapshot, "_full.zip"))
  if (!file.exists(cache)) {
    gtfs <- UK2GTFS::transxchange2gtfs(src, silent = TRUE, cal = cal,
                                       naptan = naptan,
                                       ncores = cfg$ncores,
                                       try_mode = TRUE, force_merge = TRUE,
                                       filter_duplicate_files = TRUE,
                                       filter_date = as.Date(filter_date))
    gtfs <- post_convert(gtfs, cfg$ncores)
    dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE)
    write_repo_gtfs(gtfs, gsub("\\.zip$", "", basename(cache)),
                    dirname(cache))
    rm(gtfs)
  }
  # Read back so trimming sees gtfs_read() column classes
  gtfs <- UK2GTFS::gtfs_read(cache)
  snap_date <- lubridate::ymd(snapshot)
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = snap_date - 31,
                                   enddate = snap_date + 31)
  write_repo_gtfs(gtfs, paste0("bods_txc_", snapshot))
}
