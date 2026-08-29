# Adds the uncleaned year-by-year trends to data/foe_comparison.Rds.
#
# The main run cleans each series over the year range it covers, and
# forecast::tsclean() sees the whole series at once - so the cleaned 2010 value
# of a series ending in 2025 is not the cleaned 2010 value of one ending in
# 2023. That is fine for the percentage-change tables, which are built from
# matched 2023-ending runs, but it makes the cleaned series the wrong thing to
# draw a previous-versus-rebuilt trend line from.
#
# These trends are taken straight from the outputs with no cleaning at all, so
# both pipelines are on identical footing at every point.
#
# Run after run_foe_comparison.R:
#   Rscript scripts/foe_comparison/add_raw_trends.R

source("scripts/foe_comparison/foe_functions.R")

OUT <- "data/foe_comparison.Rds"
res <- readRDS(OUT)

years_old <- res$years$to_2023
years_new <- res$years$to_2025

message("Loading uncleaned series")
old_raw <- load_series(file.path(INPUT_DATA, "pt_frequency"), years_old, c(3, 200))
new_raw <- load_series("data", years_new, c(3, 200))

raw_trend <- function(series, group_cols) {
  series |>
    inner_join(res$lookup, by = "zone_id") |>
    filter(!is.na(population), !is.na(tph)) |>
    group_by(across(all_of(c(group_cols, "period_name", "year")))) |>
    summarise(tph = weighted.mean(tph, population), .groups = "drop")
}

res$trends$old_gb_uncleaned <- raw_trend(old_raw, character(0))
res$trends$new_gb_uncleaned <- raw_trend(new_raw, character(0))
res$trends$old_settlement_uncleaned <- raw_trend(old_raw, "settlement")
res$trends$new_settlement_uncleaned <- raw_trend(new_raw, "settlement")
res$trends$old_region_uncleaned <- raw_trend(old_raw, "region")
res$trends$new_region_uncleaned <- raw_trend(new_raw, "region")

# Recompute the year-by-year agreement. The correlation has to be taken before
# the weighted means overwrite `old` and `new` with scalars - summarise()
# evaluates its arguments in order against the results of the earlier ones.
res$zone_agreement <- inner_join(
  old_raw |> filter(period_name == "tph_daytime_avg") |> select(zone_id, year, old = tph),
  new_raw |> filter(period_name == "tph_daytime_avg") |> select(zone_id, year, new = tph),
  by = c("zone_id", "year")) |>
  inner_join(res$lookup, by = "zone_id") |>
  filter(!is.na(population)) |>
  group_by(year) |>
  summarise(zones = n(),
            correlation = cor(old, new, use = "complete.obs"),
            spearman = cor(old, new, use = "complete.obs", method = "spearman"),
            old = weighted.mean(old, population, na.rm = TRUE),
            new = weighted.mean(new, population, na.rm = TRUE),
            .groups = "drop") |>
  mutate(ratio = new / old)

saveRDS(res, OUT)
message("Updated ", OUT)
