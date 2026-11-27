# Conversions with a choice of TNDS edition and of stop locations
#
# These are the conversion functions of R/convert.R with two more choices,
# kept apart from them on purpose: targets tracks a function's body, so
# editing convert_txc_cached() or convert_tnds_snapshot() would mark every
# yearly conversion and everything downstream of it outdated, and a rebuild
# would then quietly take the new UK2GTFS defaults. The series keeps the
# functions it was built with; the November 2026 city comparison uses these.
# When the series is next rebuilt deliberately, fold them back together.
#
# * edition: TNDS publishes each snapshot as TransXChange 2.1 regional zips
#   and a 2.5 rendering in TNDSV2.5/. See tnds_edition() for why 2.5 is the
#   series' choice. tnds_edition_choose() can also force 2.1, or build a
#   "blend": 2.5 plus the 2.1-only files whose service 2.5 does not carry.
# * stop_locations: UK2GTFS 0.4.1 can take a stop's position from the
#   TransXChange file where NaPTAN lacks it (see ?UK2GTFS::transxchange2gtfs).
#   The series was built with "naptan" (the only behaviour before 0.4.1).

#' transxchange2gtfs() with the pipeline's settings, saving the stop report
#'
#' The conversion's stop location report (attribute "stop_location_report")
#' is written next to the cache as <cache>_stop_locations.csv, because the
#' attribute does not survive writing the feed.
txc2gtfs <- function(src, cal, naptan, cfg, scotland = "auto",
                     filter_duplicate_files = FALSE, filter_date = Sys.Date(),
                     stop_locations = "naptan", cache_zip) {
  if (utils::packageVersion("UK2GTFS") < "0.4.1") {
    stop("stop_locations needs UK2GTFS >= 0.4.1")
  }
  gtfs <- UK2GTFS::transxchange2gtfs(src, silent = TRUE, cal = cal,
                                     naptan = naptan, ncores = cfg$ncores,
                                     scotland = scotland, try_mode = TRUE,
                                     force_merge = TRUE,
                                     filter_duplicate_files =
                                       filter_duplicate_files,
                                     filter_date = filter_date,
                                     stop_locations = stop_locations)
  rep <- attr(gtfs, "stop_location_report")
  if (!is.null(rep)) {
    dir.create(dirname(cache_zip), showWarnings = FALSE, recursive = TRUE)
    data.table::fwrite(rep, sub("\\.zip$", "_stop_locations.csv", cache_zip))
  }
  gtfs
}

#' The cache and output name tag for a stop_locations setting
stop_location_tag <- function(stop_locations) {
  if (stop_locations == "naptan") "" else paste0("_", stop_locations)
}

#' convert_txc_cached() with a stop_locations choice
convert_txc_cached_sl <- function(src_zip, cache_zip, cal, naptan, scotland,
                                  cfg, trim = NULL,
                                  filter_duplicate_files = FALSE,
                                  filter_date = Sys.Date(),
                                  stop_locations = "naptan_fill") {
  if (!file.exists(cache_zip)) {
    message("Converting ", src_zip)
    gtfs <- txc2gtfs(src_zip, cal = cal, naptan = naptan, cfg = cfg,
                     scotland = scotland,
                     filter_duplicate_files = filter_duplicate_files,
                     filter_date = filter_date,
                     stop_locations = stop_locations, cache_zip = cache_zip)
    gtfs <- post_convert(gtfs, cfg$ncores)
    dir.create(dirname(cache_zip), showWarnings = FALSE, recursive = TRUE)
    write_repo_gtfs(gtfs, gsub("\\.zip$", "", basename(cache_zip)),
                    dirname(cache_zip))
    rm(gtfs)
  } else {
    message("Using cached ", cache_zip)
  }
  gtfs <- UK2GTFS::gtfs_read(cache_zip)
  if (!is.null(trim)) {
    gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = trim[1],
                                     enddate = trim[2])
  }
  gtfs
}

#' Which TNDS zips to convert for a chosen edition
#'
#' `"2.5"` and `"2.1"` force one edition (the series' rule is tnds_edition()).
#' `"blend"` is the 2.5 edition plus the 2.1-only files whose service 2.5
#' does not carry under the same line anywhere in Britain: services 2.5 lost,
#' rather than the cross-boundary copies it removed on purpose. In the 18
#' November 2026 snapshot 2.5 lacked about 250 files of 2.1; most were
#' copies, but Arriva's 9 Bridgnorth-Wolverhampton, Arriva 87 in
#' Leicestershire and Stagecoach South Wales 130/150 were not. The blend
#' zips are built by tnds_blend_zips().
#'
#' NCSD.zip (national coach, 2.1 only) is added to every edition where the
#' snapshot has it, as tnds_edition() does; iom.zip is left out.
#'
#' @return list(version, zips, cache_suffix)
tnds_edition_choose <- function(src, edition = c("2.5", "2.1", "blend"),
                                blend_dir = NULL) {
  edition <- match.arg(edition)
  top <- list.files(src, pattern = "\\.zip$", full.names = TRUE)
  ncsd <- top[grepl("NCSD", basename(top), ignore.case = TRUE)]
  if (edition == "2.1") {
    return(list(version = "2.1", zips = top, cache_suffix = "_v21"))
  }
  v25 <- list.files(file.path(src, "TNDSV2.5"), pattern = "\\.zip$",
                    full.names = TRUE)
  v25 <- v25[!grepl("^iom\\.zip$", basename(v25), ignore.case = TRUE)]
  if (!length(v25)) stop("No TNDSV2.5 edition in ", src)
  if (edition == "blend") {
    bz <- file.path(blend_dir, basename(v25))
    if (is.null(blend_dir) || !all(file.exists(bz))) {
      stop("Blend zips not built in ", blend_dir, "; see tnds_blend_zips()")
    }
    return(list(version = "blend", zips = c(bz, ncsd), cache_suffix = "_blend"))
  }
  list(version = "2.5", zips = c(v25, ncsd), cache_suffix = "_v25")
}

#' Build the blend edition's zips and the edition comparison tables
#'
#' Runs scripts/tnds_editions/tnds_editions.py over the snapshot. It writes
#' files.csv, pairs.csv, only21.csv and blend_added.csv to
#' data/tnds_editions/<snapshot>/, and one zip per region to
#' gtfs/cache/tnds_<snapshot>_blend_src/. Skipped if both already exist.
#' @param date the day a file must be operating on to count as active
#' @return the comparison folder
tnds_blend_zips <- function(snapshot, date, cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
  out <- file.path("data", "tnds_editions", snapshot)
  zdir <- file.path(cfg$gtfs_dir, "cache", paste0("tnds_", snapshot, "_blend_src"))
  if (!file.exists(file.path(out, "blend_added.csv")) ||
      length(list.files(zdir, "\\.zip$")) == 0) {
    st <- system2("python", c("-I", "scripts/tnds_editions/tnds_editions.py",
                              shQuote(src), out, as.character(date),
                              "--blend", zdir))
    if (st != 0) stop("tnds_editions.py failed")
  }
  out
}

#' convert_tnds_snapshot() with an edition and a stop_locations choice
#'
#' Output: gtfs/tnds_<snapshot>_<edition>[_<stop_locations>]_merged.zip,
#' with region caches in gtfs/cache/ under the same tag, so nothing the
#' series uses is overwritten.
convert_tnds_edition <- function(snapshot, cal, naptan, cfg = load_cfg(),
                                 edition = "2.5",
                                 stop_locations = "naptan_fill") {
  src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
  ed <- tnds_edition_choose(src, edition,
                            blend_dir = file.path(cfg$gtfs_dir, "cache",
                                                  paste0("tnds_", snapshot,
                                                         "_blend_src")))
  tag <- paste0(ed$cache_suffix, stop_location_tag(stop_locations))
  message("TNDS ", snapshot, ": edition ", ed$version, ", ",
          length(ed$zips), " archive(s), stop locations ", stop_locations)
  snap_date <- lubridate::ymd(snapshot)
  gtfs_all <- lapply(ed$zips, function(z) {
    region <- gsub("\\.zip$", "", basename(z))
    cache <- file.path(cfg$gtfs_dir, "cache", paste0("tnds_", snapshot, tag),
                       paste0(region, ".zip"))
    convert_txc_cached_sl(z, cache, cal, naptan,
                          scotland = ifelse(region == "S", "yes", "no"),
                          cfg = cfg,
                          trim = c(snap_date - tnds_trim_days(),
                                   snap_date + tnds_trim_days()),
                          filter_duplicate_files = TRUE,
                          filter_date = snap_date,
                          stop_locations = stop_locations)
  })
  merged <- UK2GTFS::gtfs_merge(gtfs_all, force = TRUE)
  merged <- UK2GTFS::gtfs_clean(merged)
  write_repo_gtfs(merged, paste0("tnds_", snapshot, tag, "_merged"))
}

#' convert_bods_txc() with a stop_locations choice
convert_bods_txc_sl <- function(snapshot, cal, naptan, archive, filter_date,
                                cfg = load_cfg(),
                                stop_locations = "naptan_fill") {
  src <- file.path(cfg$data_root, "OpenBusData/TransXchange", snapshot, archive)
  tag <- stop_location_tag(stop_locations)
  cache <- file.path(cfg$gtfs_dir, "cache",
                     paste0("bods_txc_", snapshot, tag, "_full.zip"))
  if (!file.exists(cache)) {
    gtfs <- txc2gtfs(src, cal = cal, naptan = naptan, cfg = cfg,
                     scotland = "auto", filter_duplicate_files = TRUE,
                     filter_date = as.Date(filter_date),
                     stop_locations = stop_locations, cache_zip = cache)
    gtfs <- post_convert(gtfs, cfg$ncores)
    dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE)
    write_repo_gtfs(gtfs, gsub("\\.zip$", "", basename(cache)), dirname(cache))
    rm(gtfs)
  }
  gtfs <- UK2GTFS::gtfs_read(cache)
  snap_date <- lubridate::ymd(snapshot)
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = snap_date - 31,
                                   enddate = snap_date + 31)
  write_repo_gtfs(gtfs, paste0("bods_txc_", snapshot, tag))
}

#' convert_bods_coach() with a stop_locations choice
convert_bods_coach_sl <- function(snapshot, cal, naptan, cfg = load_cfg(),
                                  stop_locations = "naptan_fill") {
  tag <- stop_location_tag(stop_locations)
  src <- file.path(cfg$data_root, "OpenBusData/Coach", snapshot, "TxC-2.4.zip")
  cache <- file.path(cfg$gtfs_dir, "cache",
                     paste0("bods_coach_", snapshot, tag, ".zip"))
  snap_date <- lubridate::ymd(snapshot)
  gtfs <- convert_txc_cached_sl(src, cache, cal, naptan, scotland = "auto",
                                cfg = cfg,
                                trim = c(snap_date - 31, snap_date + 31),
                                stop_locations = stop_locations)
  write_repo_gtfs(gtfs, paste0("bods_coach_", snapshot, tag))
}
