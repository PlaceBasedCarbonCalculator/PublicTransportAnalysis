# Stop locations: how good is each source's idea of where a stop is?
#
# UK2GTFS took stop positions only from NaPTAN until 0.4.1, and the pipeline's
# NaPTAN copy (the naptan target) is frozen at 2 August 2026, so a stop opened
# since then lost every call. 0.4.1 can take the position the TransXChange file
# gives instead. Whether that is safe depends on the files: do they give
# positions at all, and when they do, do they agree with NaPTAN? This measures
# that for every file of TNDS (both editions), the BODS TransXChange archive
# and the BODS Coach feed, from scripts/stop_locations/txc_stop_points.py.

#' The full NaPTAN CSV (with Status and dates), downloaded once
#'
#' get_naptan() keeps only id, code, name and position. The quality report
#' also needs each stop's Status (active, inactive, pending) and dates.
download_naptan_raw <- function(dest) {
  if (!file.exists(dest)) {
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
    utils::download.file(
      "https://naptan.api.dft.gov.uk/v1/access-nodes?dataFormat=csv", dest,
      mode = "wb", quiet = TRUE)
  }
  dest
}

#' Distance in metres between WGS84 points (equirectangular)
geo_dist_m <- function(lon1, lat1, lon2, lat2) {
  rad <- pi / 180
  x <- (lon2 - lon1) * rad * cos((lat1 + lat2) / 2 * rad)
  y <- (lat2 - lat1) * rad
  6371000 * sqrt(x * x + y * y)
}

#' British National Grid to WGS84, vectorised, NA-safe
bng_to_wgs84 <- function(e, n) {
  lon <- lat <- rep(NA_real_, length(e))
  ok <- !is.na(e) & !is.na(n) & e > 0 & n > 0
  if (any(ok)) {
    p <- sf::st_as_sf(data.frame(e = e[ok], n = n[ok]), coords = c("e", "n"),
                      crs = 27700)
    xy <- sf::st_coordinates(sf::st_transform(p, 4326))
    lon[ok] <- xy[, 1]
    lat[ok] <- xy[, 2]
  }
  list(lon = lon, lat = lat)
}

#' Measure stop location quality in every TransXChange source
#'
#' @param points_dir txc_stop_points.py output
#' @param naptan the pipeline's NaPTAN copy (the naptan target)
#' @param naptan_raw path to the full current NaPTAN CSV
#' @param bods_gtfs path to a BODS GTFS zip, whose stops.txt is compared too
#' @param conversions named vector of stop location reports
#'   (<cache>_stop_locations.csv) from the naptan_fill conversions
#' @return path to data/stop_locations_<date>.Rds
stop_location_analysis <- function(points_dir, naptan, naptan_raw, bods_gtfs,
                                   conversions = NULL, date = "20261118",
                                   cfg = load_cfg()) {
  # --- NaPTAN: the frozen copy and the current register --------------------
  nr <- data.table::fread(naptan_raw, select = c(
    "ATCOCode", "CommonName", "Easting", "Northing", "Status",
    "CreationDateTime", "ModificationDateTime", "StopType"),
    colClasses = list(character = "ATCOCode"))
  ll <- bng_to_wgs84(nr$Easting, nr$Northing)
  nr[, `:=`(stop_id = toupper(ATCOCode), n_lon = ll$lon, n_lat = ll$lat,
            created = as.Date(substr(CreationDateTime, 1, 10)))]
  nr <- unique(nr, by = "stop_id")
  frozen <- toupper(data.table::as.data.table(naptan)$stop_id)

  # --- every file's declared stops ------------------------------------------
  srcs <- sub("_points\\.csv\\.gz$", "",
              list.files(points_dir, "_points\\.csv\\.gz$"))
  pts <- data.table::rbindlist(lapply(srcs, function(s) {
    data.table::fread(file.path(points_dir, paste0(s, "_points.csv.gz")),
                      colClasses = list(character = c("stop_id", "noc",
                                                      "publisher", "grid")))
  }))
  pts[, stop_id := toupper(stop_id)]
  pts[, used := as.logical(used)]
  irish <- !is.na(pts$grid) & pts$grid != "" & pts$grid != "UKOS"
  pts[irish, `:=`(easting = NA, northing = NA)]
  ll <- bng_to_wgs84(pts$easting, pts$northing)
  pts[, `:=`(t_lon = data.table::fifelse(!is.na(lon), lon, ll$lon),
             t_lat = data.table::fifelse(!is.na(lat), lat, ll$lat))]
  pts[!(t_lon > -11 & t_lon < 3 & t_lat > 49 & t_lat < 61.5),
      `:=`(t_lon = NA, t_lat = NA)]
  pts[, located := !is.na(t_lon)]
  pts[, coord := data.table::fcase(
    !is.na(easting) & !is.na(lon), "grid + WGS84",
    !is.na(easting), "grid",
    !is.na(lon), "WGS84",
    default = "none")]

  files <- data.table::rbindlist(lapply(srcs, function(s) {
    data.table::fread(file.path(points_dir, paste0(s, "_files.csv")),
                      colClasses = list(character = c("noc", "publisher")))
  }))
  # Whether a file locates its stops is what matters, not the element it uses:
  # BODS writes <AnnotatedStopPointRef> with a <Location> inside, TfL full
  # <StopPoint> definitions, and most of TNDS bare references.
  # TNDS file names start with the supplier's prefix (tfl_, twm_, essex_,
  # square_, ...); Yorkshire's are SVR<code>, and Scotland's and Wales's are
  # named by service. Name those by region instead.
  label_publisher <- function(dt) {
    dt[startsWith(source, "tnds") & grepl("^SVR", basename(file)),
       publisher := "svr"]
    dt[startsWith(source, "tnds") & (is.na(publisher) | publisher == ""),
       publisher := paste0(tolower(sub("\\.zip$", "", zip)), " (unprefixed)")]
  }
  label_publisher(files)
  label_publisher(pts)
  files[, kind := data.table::fcase(
    declared == 0, "no stops declared",
    located == declared, "every stop located",
    located == 0, "no stop located",
    default = "some stops located")]
  files[, form := data.table::fcase(
    declared == 0, "none",
    full == declared, "full StopPoint definitions",
    full == 0, "AnnotatedStopPointRef",
    default = "both")]

  # --- per file: what form are the stops in? --------------------------------
  file_forms <- files[, .N, by = list(source, form, kind)]
  file_forms[, share := N / sum(N), by = source]
  pub_forms <- files[, list(files = .N,
                            full_share = sum(full) / max(1, sum(declared)),
                            located_share = sum(located) / max(1, sum(declared)),
                            undeclared_files = sum(undeclared > 0)),
                     by = list(source, publisher)][order(source, -files)]

  # --- per stop: the stops the timetables call at --------------------------
  used <- pts[used == TRUE, list(located = any(located), files = .N),
              by = list(source, stop_id)]
  used[, `:=`(in_frozen = stop_id %in% frozen,
              in_current = stop_id %in% nr$stop_id)]
  used <- merge(used, nr[, list(stop_id, Status, created)], by = "stop_id",
                all.x = TRUE)
  stop_cov <- used[, list(
    stops = .N,
    located_in_txc = mean(located),
    missing_frozen = sum(!in_frozen),
    missing_frozen_located = sum(!in_frozen & located),
    missing_current = sum(!in_current),
    missing_current_located = sum(!in_current & located),
    inactive = sum(in_current & Status != "active", na.rm = TRUE)),
    by = source]
  missing_frozen <- used[in_frozen == FALSE][order(source, -files)]

  # --- where both give a position: how far apart? ---------------------------
  d <- merge(pts[located == TRUE, list(source, publisher, file, stop_id,
                                       t_lon, t_lat, coord)],
             nr[!is.na(n_lon), list(stop_id, CommonName, n_lon, n_lat, Status,
                                    ModificationDateTime)],
             by = "stop_id")
  d[, dist := geo_dist_m(t_lon, t_lat, n_lon, n_lat)]
  dist_summary <- function(x) {
    list(defs = length(x), median_m = stats::median(x),
         p95_m = stats::quantile(x, 0.95, names = FALSE),
         over_50m = mean(x > 50), over_250m = mean(x > 250),
         over_1km = mean(x > 1000))
  }
  dist_src <- d[, dist_summary(dist), by = source]
  dist_pub <- d[, dist_summary(dist), by = list(source, publisher)][
    order(source, -defs)]
  dist_coord <- d[, dist_summary(dist), by = list(source, coord)]
  worst <- d[dist > 1000][order(-dist)][, head(.SD, 40), by = source]

  # --- the same stop defined differently by different files ----------------
  med <- pts[located == TRUE, list(m_lon = stats::median(t_lon),
                                   m_lat = stats::median(t_lat),
                                   defs = .N),
             by = list(source, stop_id)]
  sp <- merge(pts[located == TRUE, list(source, stop_id, t_lon, t_lat)],
              med, by = c("source", "stop_id"))
  sp <- sp[, list(defs = defs[1], spread_m = max(geo_dist_m(t_lon, t_lat,
                                                            m_lon, m_lat))),
           by = list(source, stop_id)]
  spread <- sp[defs > 1, list(stops = .N, over_50m = sum(spread_m > 50),
                              over_250m = sum(spread_m > 250),
                              over_1km = sum(spread_m > 1000)), by = source]

  # --- BODS GTFS's own stop positions --------------------------------------
  tmp <- tempfile("bods_stops")
  utils::unzip(bods_gtfs, "stops.txt", exdir = tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  gs <- data.table::fread(file.path(tmp, "stops.txt"),
                          colClasses = list(character = "stop_id"))
  gs <- gs[, list(stop_id = toupper(stop_id), g_lon = as.numeric(stop_lon),
                  g_lat = as.numeric(stop_lat))]
  gs <- merge(gs, nr[!is.na(n_lon), list(stop_id, n_lon, n_lat)], by = "stop_id")
  gs[, dist := geo_dist_m(g_lon, g_lat, n_lon, n_lat)]
  gtfs_dist <- gs[, dist_summary(dist)]

  # --- what naptan_fill did in the conversions -----------------------------
  conv <- NULL
  if (length(conversions)) {
    conv <- data.table::rbindlist(lapply(names(conversions), function(nm) {
      fs <- conversions[[nm]]
      r <- data.table::rbindlist(lapply(fs, data.table::fread), fill = TRUE)
      r[, list(stops = .N, calls = sum(calls)), by = source][, conversion := nm]
    }))
  }

  out <- list(date = date, sources = srcs,
              naptan_frozen_n = length(frozen), naptan_current_n = nrow(nr),
              naptan_status = nr[, .N, by = Status],
              file_forms = file_forms, pub_forms = pub_forms,
              stop_cov = stop_cov, missing_frozen = missing_frozen,
              dist_src = dist_src, dist_pub = dist_pub, dist_coord = dist_coord,
              worst = worst, spread = spread,
              spread_worst = sp[defs > 1][order(-spread_m)][, head(.SD, 20),
                                                          by = source],
              gtfs_dist = gtfs_dist, conversions = conv)
  dest <- file.path(cfg$out_dir, sprintf("stop_locations_%s.Rds", date))
  saveRDS(out, dest)
  dest
}

#' The stop location reports a conversion wrote next to its caches
#'
#' @param dep the conversion target (only so targets orders this after it)
#' @param stem a cache folder (TNDS: one report per region) or a cache file
#'   name without .zip (BODS)
conversion_stop_reports <- function(dep, stem, cfg = load_cfg()) {
  base <- file.path(cfg$gtfs_dir, "cache", stem)
  if (dir.exists(base)) {
    list.files(base, "_stop_locations\\.csv$", full.names = TRUE)
  } else {
    f <- paste0(base, "_stop_locations.csv")
    f[file.exists(f)]
  }
}

#' Knit the stop location report
render_stop_location_report <- function(path, rmd, cfg = load_cfg()) {
  env <- new.env(parent = globalenv())
  env$loc_path <- normalizePath(path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = basename(rmd), output = "stop_location_quality.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "stop_location_quality.md")
}
