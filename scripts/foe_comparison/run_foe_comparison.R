# Rebuild the 2023 Friends of the Earth bus-decline headlines from both the
# pre-rewrite TransportBlackspots outputs and this repo's outputs, and save
# everything the report needs into one object.
#
# Run from the repo root:
#   Rscript scripts/foe_comparison/run_foe_comparison.R
#
# Standalone by design - not a targets pipeline stage. Takes roughly half an
# hour, almost all of it in forecast::tsclean().

source("scripts/foe_comparison/foe_functions.R")

OLD_DIR <- file.path(INPUT_DATA, "pt_frequency")   # TransportBlackspots, Nov 2025
NEW_DIR <- "data"                                  # this repo, Aug 2026
OUT <- "data/foe_comparison.Rds"

# Both series are compared over the years they share, ending in 2023 as the
# published report did. The rewritten pipeline also has 2024 and 2025, which
# are carried separately so the extension does not disturb the comparison:
# tsclean() sees the whole series at once, so adding years would change the
# cleaned values in the years already published.
YEARS_TO_2023 <- YEARS_COMMON
YEARS_TO_2025 <- c(YEARS_COMMON, 2024, 2025)

message("Building zone lookup")
lookup <- build_zone_lookup()
lookup <- add_settlement_class(lookup, NEW_DIR, year = 2023)

message("Loading series")
# Coach is folded back into bus for both series. The pre-rewrite pipeline had
# no separate coach type, so this is what makes the two comparable.
old_raw <- load_series(OLD_DIR, YEARS_TO_2023, route_types = c(3, 200))
new_raw <- load_series(NEW_DIR, YEARS_TO_2023, route_types = c(3, 200))
new_raw_25 <- load_series(NEW_DIR, YEARS_TO_2025, route_types = c(3, 200))
# Bus alone, to size the coach reclassification on its own.
new_bus_only <- load_series(NEW_DIR, YEARS_TO_2023, route_types = 3)

message("Cleaning old series")
old_clean <- clean_series(old_raw, YEARS_TO_2023)
message("Cleaning new series")
new_clean <- clean_series(new_raw, YEARS_TO_2023)
message("Cleaning new series to 2025")
new_clean_25 <- clean_series(new_raw_25, YEARS_TO_2025)

# ---------------------------------------------------------------------------
# The comparison points and their aggregations
# ---------------------------------------------------------------------------

message("Aggregating")

points <- list(
  old        = zone_comparison_points(old_clean, "tph_cleaned", 2023),
  new        = zone_comparison_points(new_clean, "tph_cleaned", 2023),
  old_raw    = zone_comparison_points(old_clean, "tph", 2023),
  new_raw    = zone_comparison_points(new_clean, "tph", 2023),
  new_2025   = zone_comparison_points(new_clean_25, "tph_cleaned", 2025))

agg <- function(fn) lapply(points, fn)

region_tables     <- agg(function(p) aggregate_points(p, lookup, "region"))
settlement_tables <- agg(function(p) aggregate_points(p, lookup, "settlement"))
la_tables         <- agg(function(p) aggregate_points(p, lookup, c("la_code", "la_name")))
gb_tables         <- agg(function(p) aggregate_points(p, lookup, character(0)))

trends <- list(
  old = aggregate_trend(old_clean, lookup, "settlement"),
  new = aggregate_trend(new_clean_25, lookup, "settlement"),
  old_gb = aggregate_trend(old_clean, lookup),
  new_gb = aggregate_trend(new_clean_25, lookup),
  old_gb_raw = aggregate_trend(old_clean, lookup, value = "tph"),
  new_gb_raw = aggregate_trend(new_clean_25, lookup, value = "tph"),
  old_region = aggregate_trend(old_clean, lookup, "region"),
  new_region = aggregate_trend(new_clean_25, lookup, "region"))

# ---------------------------------------------------------------------------
# How much of the difference is which
# ---------------------------------------------------------------------------

# Coach: the same zones and years counted with and without route type 200.
coach_effect <- inner_join(
  new_raw |> filter(period_name == "tph_daytime_avg") |> rename(tph_with_coach = tph),
  new_bus_only |> filter(period_name == "tph_daytime_avg") |> rename(tph_bus_only = tph),
  by = c("zone_id", "year", "period_name")) |>
  inner_join(lookup, by = "zone_id") |>
  filter(!is.na(population)) |>
  group_by(year) |>
  summarise(with_coach = weighted.mean(tph_with_coach, population),
            bus_only = weighted.mean(tph_bus_only, population), .groups = "drop") |>
  mutate(coach_share = 1 - bus_only / with_coach)

# How much work the cleaning step is doing in each series, by year.
cleaning_effect <- bind_rows(
  old_clean |> mutate(series = "old"),
  new_clean |> mutate(series = "new")) |>
  filter(period_name == "tph_daytime_avg") |>
  group_by(series, year) |>
  summarise(zones = n(),
            pct_outlier = mean(outlier, na.rm = TRUE),
            pct_interpolated = mean(interpolated, na.rm = TRUE),
            .groups = "drop")

# Zone-level agreement between the two series, uncleaned, year by year.
zone_agreement <- inner_join(
  old_raw |> filter(period_name == "tph_daytime_avg") |> select(zone_id, year, old = tph),
  new_raw |> filter(period_name == "tph_daytime_avg") |> select(zone_id, year, new = tph),
  by = c("zone_id", "year")) |>
  inner_join(lookup, by = "zone_id") |>
  filter(!is.na(population)) |>
  group_by(year) |>
  # The correlation has to come before the weighted means: summarise()
  # evaluates in order, so `old` and `new` are scalars after those two lines.
  summarise(zones = n(),
            correlation = cor(old, new, use = "complete.obs"),
            spearman = cor(old, new, use = "complete.obs", method = "spearman"),
            old = weighted.mean(old, population),
            new = weighted.mean(new, population),
            .groups = "drop") |>
  mutate(ratio = new / old)

result <- list(
  built = Sys.time(),
  lookup = lookup,
  points = points,
  region = region_tables,
  settlement = settlement_tables,
  la = la_tables,
  gb = gb_tables,
  trends = trends,
  coach_effect = coach_effect,
  cleaning_effect = cleaning_effect,
  zone_agreement = zone_agreement,
  years = list(to_2023 = YEARS_TO_2023, to_2025 = YEARS_TO_2025))

saveRDS(result, OUT)
message("Wrote ", OUT)
