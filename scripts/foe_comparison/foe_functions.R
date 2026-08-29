# Functions for the Friends of the Earth bus-decline replication.
#
# The 2023 Friends of the Earth report "How Britain's bus services have
# drastically declined" was produced from the TransportBlackspots pipeline.
# This file rebuilds that report's headline measures from the outputs of
# *this* repo, and from the pre-rewrite TransportBlackspots outputs, so the
# two can be put side by side.
#
# The method is copied from TransportBlackspots, not reinvented:
#   scripts/make-stats/combine_trips_per_lsoa.R  (weekday means, tph_daytime_avg)
#   scripts/toby-analysis/final/clean-data.R     (outlier removal, interpolation)
#   scripts/toby-analysis/final/weighted-regional-means.R  (aggregation)
#
# Deliberately standalone: nothing here is part of the targets pipeline.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

INPUT_DATA <- "../inputdata"

# The five time bands and their lengths in hours, as used by
# UK2GTFS::gtfs_trips_per_zone().
BAND_HOURS <- c("Morning_Peak" = 4, "Midday" = 5, "Afternoon_Peak" = 3,
                "Evening" = 4, "Night" = 8)

# The periods the report is built on. tph_daytime_avg is the headline.
REPORT_PERIODS <- c(
  "tph_weekday_Morning_Peak", "tph_weekday_Midday", "tph_weekday_Afternoon_Peak",
  "tph_weekday_Evening", "tph_weekday_Night",
  "tph_Sat_Morning_Peak", "tph_Sat_Midday", "tph_Sat_Afternoon_Peak",
  "tph_Sat_Evening", "tph_Sat_Night",
  "tph_Sun_Morning_Peak", "tph_Sun_Midday", "tph_Sun_Afternoon_Peak",
  "tph_Sun_Evening", "tph_Sun_Night",
  "tph_daytime_avg")

# Years present in both output series. 2012 and 2013 have no source data.
YEARS_COMMON <- c(2004:2011, 2014:2023)


# ---------------------------------------------------------------------------
# Geography
# ---------------------------------------------------------------------------

#' Build the LSOA21/DZ22 lookup: local authority, region, rurality, population
#'
#' @description The zone ids in the trips-per-zone outputs are 2021 LSOAs in
#'   England and Wales and 2022 Data Zones in Scotland. This assembles the
#'   attributes the report aggregates by. Population is ONS mid-2022 for
#'   England and Wales and the 2022 census for Scotland; a single population
#'   vintage is used for every year so that weighting never moves the trend.
#' @param path The inputdata folder.
#' @return A data frame keyed on `zone_id`.
build_zone_lookup <- function(path = INPUT_DATA) {

  # England and Wales: population by 2021 LSOA, carrying 2023 LAD codes.
  ew_pop <- readxl::read_excel(
    file.path(path, "population/pop2022-2024.xlsx"),
    sheet = "Mid-2022 LSOA 2021", skip = 3)
  ew_pop <- ew_pop |>
    transmute(zone_id = `LSOA 2021 Code`,
              la_code = `LAD 2023 Code`,
              la_name = `LAD 2023 Name`,
              population = as.numeric(Total))

  # England and Wales rurality: the ONS 2021 two-fold urban/rural flag.
  ew_ruc <- readr::read_csv(
    file.path(path, "rural_urban/Rural_Urban_Classification_(2021)_of_LSOAs_in_EW.csv"),
    show_col_types = FALSE) |>
    transmute(zone_id = LSOA21CD, rural_urban = Urban_rural_flag)

  # England and Wales region, via the 2011 LSOA the 2021 LSOA came from.
  # Split/merged zones can match more than one parent; regions do not change
  # under those splits, so taking the first match is safe.
  lsoa11_rgn <- readr::read_csv(
    file.path(path, "boundaries/GB_OA_LSOA_MSOA_LAD_Classifications_2017.csv"),
    show_col_types = FALSE) |>
    distinct(LSOA11CD, region = RGN11NM)
  lsoa11_21 <- readr::read_csv(
    file.path(path, "boundaries/LSOA_(2011)_to_LSOA_(2021)_to_Local_Authority_District_(2022)_Lookup_for_England_and_Wales_(Version_2).csv"),
    show_col_types = FALSE) |>
    distinct(LSOA11CD, LSOA21CD)
  ew_rgn <- lsoa11_21 |>
    left_join(lsoa11_rgn, by = "LSOA11CD") |>
    filter(!is.na(region)) |>
    distinct(zone_id = LSOA21CD, .keep_all = TRUE) |>
    select(zone_id, region)

  ew <- ew_pop |>
    left_join(ew_ruc, by = "zone_id") |>
    left_join(ew_rgn, by = "zone_id") |>
    # A handful of 2021 LSOAs are wholly new and match no 2011 parent; the
    # W-prefix is unambiguous, and English ones are recovered from the LAD.
    mutate(region = ifelse(is.na(region) & startsWith(zone_id, "W"), "Wales", region))

  # Scotland: 2022 Data Zones. Population from the 2022 census (a SuperWEB2
  # export with ten lines of preamble), everything else from the NRS lookup.
  sc_pop <- readr::read_csv(
    file.path(path, "population_scotland/scotlandcensus2022_Ethnic2_People_DataZone.csv"),
    skip = 11, col_names = c("zone_id", "white", "other", "population", "blank"),
    col_types = readr::cols(.default = readr::col_character()), progress = FALSE) |>
    filter(startsWith(zone_id, "S01")) |>
    transmute(zone_id, population = as.numeric(population))

  sc_lup <- readr::read_csv(
    file.path(path, "boundaries/DataZone2022lookup_2024-12-16.csv"),
    show_col_types = FALSE) |>
    transmute(zone_id = DZ22_Code,
              la_code = LA_Code,
              la_name = LA_Name,
              # The Scottish six-fold class has no urban/rural flag. Classes 1
              # and 2 are settlements of 10,000+, which is the same threshold
              # the ONS uses to call an English or Welsh LSOA urban; small
              # towns (3 and 4) sit below it and are rural here, as they are
              # in the ONS scheme.
              rural_urban = ifelse(UR6_Code %in% c(1, 2), "Urban", "Rural"),
              region = "Scotland")

  sc <- sc_lup |> left_join(sc_pop, by = "zone_id")

  bind_rows(ew, sc) |>
    filter(!is.na(zone_id)) |>
    select(zone_id, la_code, la_name, region, rural_urban, population)
}


# ---------------------------------------------------------------------------
# Loading and deriving the report measures
# ---------------------------------------------------------------------------

#' Read one year of trips-per-zone output and reduce it to bus
#'
#' @param dir Folder holding `trips_per_lsoa21_22_by_mode_<year>.Rds`.
#' @param year Year to read.
#' @param route_types Route types treated as "bus". The pre-rewrite outputs
#'   carry coach services inside route type 3; the rewritten pipeline codes
#'   coach separately as the GTFS extended type 200. Passing `c(3, 200)`
#'   therefore compares like with like, and passing `3` isolates the split.
#' @return A data frame of one row per zone with the derived period columns.
read_bus_year <- function(dir, year, route_types = c(3, 200)) {

  f <- file.path(dir, paste0("trips_per_lsoa21_22_by_mode_", year, ".Rds"))
  x <- readRDS(f)
  x <- x[x$route_type %in% route_types & !is.na(x$zone_id), ]

  # Where coach is split out a zone has two rows; the report wants total bus
  # service, so the frequency columns are summed back together. `rowsum()` on
  # a matrix rather than a grouped `across()`: 75 columns over 40,000 groups
  # is slow enough through dplyr to dominate the whole load.
  value_cols <- setdiff(names(x), c("zone_id", "route_type"))
  m <- as.matrix(x[, value_cols])
  m[is.na(m)] <- 0
  agg <- rowsum(m, x$zone_id, reorder = TRUE)
  x <- data.frame(zone_id = rownames(agg), agg, check.names = FALSE,
                  stringsAsFactors = FALSE, row.names = NULL)

  names(x) <- gsub(" ", "_", names(x))
  add_derived_periods(x) |> mutate(year = year)
}

#' Add the weekday means and the daytime average
#'
#' @description Mirrors TransportBlackspots
#'   scripts/make-stats/combine_trips_per_lsoa.R. Note that despite the report
#'   describing the daytime average as weekdays only, the published formula
#'   averages all seven days over the 06:00-22:00 bands; it is reproduced here
#'   exactly as published so the numbers are comparable.
add_derived_periods <- function(x) {

  weekdays <- c("Mon", "Tue", "Wed", "Thu", "Fri")
  for (band in names(BAND_HOURS)) {
    cols <- paste0("tph_", weekdays, "_", band)
    x[[paste0("tph_weekday_", band)]] <- rowMeans(as.matrix(x[, cols]))
  }

  day_bands <- c("Morning_Peak", "Midday", "Afternoon_Peak", "Evening")
  hrs <- BAND_HOURS[day_bands]
  weekday_part <- rowSums(sapply(day_bands, function(b)
    x[[paste0("tph_weekday_", b)]] * 5 * hrs[[b]]))
  weekend_part <- rowSums(sapply(c("Sat", "Sun"), function(d)
    rowSums(sapply(day_bands, function(b) x[[paste0("tph_", d, "_", b)]] * hrs[[b]]))))
  x$tph_daytime_avg <- (weekday_part + weekend_part) / (7 * 16)

  x[, c("zone_id", REPORT_PERIODS)]
}

#' Read a whole series of years into one long table
#'
#' @return A data frame with `zone_id`, `year`, `period_name`, `tph`.
load_series <- function(dir, years, route_types = c(3, 200)) {
  out <- lapply(years, function(y) read_bus_year(dir, y, route_types))
  bind_rows(out) |>
    pivot_longer(all_of(REPORT_PERIODS), names_to = "period_name", values_to = "tph")
}


# ---------------------------------------------------------------------------
# Cleaning - the step the published figures depend on
# ---------------------------------------------------------------------------

#' Clean one zone-by-year series the way the published report did
#'
#' @description A faithful port of TransportBlackspots
#'   scripts/toby-analysis/final/clean-data.R. In order: drop 2004 (too
#'   incomplete to use), hold 2020 out so the pandemic is not treated as an
#'   outlier, blank any pre-2020 value more than one standard deviation below
#'   the zone's mean, blank any pre-2010 value below half the zone's peak, drop
#'   zones left with three or fewer observations, then run `forecast::tsclean()`
#'   to replace outliers and interpolate the gaps.
#'
#'   The two blanking rules are one-sided: they can only remove *low* values,
#'   and they apply only to the early years. That systematically lifts the
#'   2006-08 baseline and so widens every decline measured from it. Both series
#'   are put through it identically, and `clean = FALSE` results are reported
#'   alongside so the effect is visible rather than assumed.
#'
#' @param series Long table from `load_series()`.
#' @param years The full set of years the time series should span.
#' @param workers Periods are independent, so they are cleaned in parallel.
#'   `tsclean()` on one zone takes about 4 ms and there are tens of thousands
#'   of zones in each of sixteen periods, which is an hour if run serially.
#' @return `series` with `tph_cleaned`, `outlier` and `interpolated` columns.
clean_series <- function(series, years, workers = 8) {

  # Split up front rather than filtering inside the loop: the workers are then
  # sent one period each instead of a copy of the whole series.
  by_period <- split(series[, c("zone_id", "year", "tph", "period_name")],
                     series$period_name)

  if (workers > 1) {
    old_plan <- future::plan(future::multisession, workers = min(workers, length(by_period)))
    old_limit <- options(future.globals.maxSize = 4 * 1024^3)
    on.exit({future::plan(old_plan); options(old_limit)}, add = TRUE)
    lapply_fn <- function(X, FUN) future.apply::future_lapply(
      X, FUN, future.seed = TRUE,
      future.packages = c("dplyr", "data.table", "forecast"))
  } else {
    lapply_fn <- lapply
  }

  out <- lapply_fn(by_period, function(d) {
    p <- d$period_name[1]
    d <- d[, c("zone_id", "year", "tph")]

    # Every zone needs a slot for every year, so that a missing year is a gap
    # in the time series rather than a shorter series.
    full <- expand.grid(zone_id = unique(d$zone_id), year = years,
                        stringsAsFactors = FALSE)
    d <- left_join(full, d, by = c("zone_id", "year"))

    pandemic <- d |> filter(year == 2020) |> transmute(zone_id, tph_pandemic = tph)

    d <- d |>
      mutate(tph = ifelse(year == 2020, NA, tph)) |>
      filter(year != 2004) |>
      arrange(zone_id, year) |>
      group_by(zone_id) |>
      mutate(max_pct = tph / max(tph, na.rm = TRUE),
             zscore = (tph - mean(tph, na.rm = TRUE)) / sd(tph, na.rm = TRUE)) |>
      ungroup() |>
      mutate(tph = ifelse(tph == 0 & is.nan(max_pct), 0,
                          ifelse(year < 2020 & zscore < -1, NA, tph)),
             tph = ifelse(year < 2010 & max_pct < 0.5 & !is.na(tph), NA, tph))

    keep <- d |>
      group_by(zone_id) |>
      summarise(n_obs = sum(!is.na(tph)), .groups = "drop") |>
      filter(n_obs > 3)
    d <- d[d$zone_id %in% keep$zone_id, ]

    cleaned <- run_tsclean(d, start_year = min(setdiff(years, 2004)))

    d <- d |>
      inner_join(cleaned, by = c("zone_id", "year")) |>
      filter(year != 2020) |>
      bind_rows(pandemic |> filter(zone_id %in% unique(d$zone_id)) |>
                  mutate(year = 2020)) |>
      arrange(zone_id, year) |>
      mutate(tph = ifelse(year == 2020, tph_pandemic, tph),
             tph_cleaned = ifelse(year == 2020, tph_pandemic, tph_cleaned),
             outlier = ifelse(is.na(tph != tph_cleaned), FALSE, tph != tph_cleaned),
             interpolated = is.na(tph) & !is.na(tph_cleaned),
             period_name = p) |>
      mutate(tph = pmax(tph, 0), tph_cleaned = pmax(tph_cleaned, 0)) |>
      select(zone_id, year, period_name, tph, tph_cleaned, outlier, interpolated)

    d
  })

  bind_rows(out)
}

#' Run forecast::tsclean() over every zone's series
#'
#' @description Split into its own function because it is the expensive part:
#'   one short time series per zone per period. `data.table` is used only to
#'   split cheaply; the modelling is `forecast::tsclean()` exactly as the
#'   original used.
run_tsclean <- function(d, start_year) {
  dt <- data.table::as.data.table(d[, c("zone_id", "year", "tph")])
  data.table::setorder(dt, zone_id, year)
  res <- dt[, .(year = year,
                tph_cleaned = as.numeric(forecast::tsclean(ts(tph, start = start_year)))),
            by = zone_id]
  as.data.frame(res)
}


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

#' Reduce a cleaned series to the report's three comparison points
#'
#' @description The published analysis compares a 2006-08 three-year mean
#'   against 2010 and against the latest year. The three-year baseline is the
#'   report's own device for coping with patchy early-year data.
#' @param final_year Year used as the end point.
zone_comparison_points <- function(cleaned, value = c("tph_cleaned", "tph"),
                                   final_year = 2023) {
  value <- match.arg(value)
  cleaned |>
    mutate(val = .data[[value]]) |>
    filter(year %in% c(2006, 2007, 2008, 2010, final_year)) |>
    mutate(point = case_when(year %in% 2006:2008 ~ "base_2006_08",
                             year == 2010 ~ "y2010",
                             TRUE ~ "y_final")) |>
    group_by(zone_id, period_name, point) |>
    summarise(val = mean(val, na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = point, values_from = val)
}

#' Population-weighted mean of a zone measure over a grouping
#'
#' @description Matches weighted-regional-means.R: a population-weighted mean
#'   of the zone values, then a percentage change between the weighted means
#'   (not a mean of the zone-level percentage changes, which a handful of zones
#'   going from near-zero to some service would dominate).
aggregate_points <- function(points, lookup, group_cols) {
  points |>
    inner_join(lookup, by = "zone_id") |>
    filter(!is.na(population)) |>
    group_by(across(all_of(c(group_cols, "period_name")))) |>
    summarise(zones = n(),
              base_2006_08 = weighted.mean(base_2006_08, population, na.rm = TRUE),
              y2010 = weighted.mean(y2010, population, na.rm = TRUE),
              y_final = weighted.mean(y_final, population, na.rm = TRUE),
              # last, so the weighted means above still see the zone vector
              population = sum(population),
              .groups = "drop") |>
    mutate(change_0823 = y_final - base_2006_08,
           change_1023 = y_final - y2010,
           pct_0823 = change_0823 / base_2006_08,
           pct_1023 = change_1023 / y2010)
}

#' Population-weighted national/grouped means for every year
#'
#' @description Used for the trend charts, where the whole series matters
#'   rather than the three comparison points.
aggregate_trend <- function(cleaned, lookup, group_cols = character(0),
                            value = c("tph_cleaned", "tph")) {
  value <- match.arg(value)
  cleaned |>
    mutate(val = .data[[value]]) |>
    inner_join(lookup, by = "zone_id") |>
    filter(!is.na(population), !is.na(val)) |>
    group_by(across(all_of(c(group_cols, "period_name", "year")))) |>
    summarise(tph = weighted.mean(val, population), .groups = "drop")
}

#' Classify zones into the report's London / urban / rural categories
#'
#' @description The report separates London zones with an Underground station
#'   from those without, because bus provision in the two is not comparable.
#'   Underground zones are identified the way the original did: zones with any
#'   metro service (GTFS route type 1) in the London region.
#' @param dir Folder of trips-per-zone outputs, used to find metro service.
#' @param year Year to read metro service from.
add_settlement_class <- function(lookup, dir, year = 2023) {

  x <- readRDS(file.path(dir, paste0("trips_per_lsoa21_22_by_mode_", year, ".Rds")))
  metro_zones <- unique(x$zone_id[x$route_type == 1 & !is.na(x$zone_id)])

  lookup |>
    mutate(settlement = case_when(
      region == "London" & zone_id %in% metro_zones ~ "London: on tube",
      region == "London" ~ "London: off tube",
      rural_urban == "Urban" ~ "Urban (outside London)",
      rural_urban == "Rural" ~ "Rural",
      TRUE ~ NA_character_))
}
