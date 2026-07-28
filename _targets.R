# targets pipeline: public transport frequency per LSOA, 2004-2025.
#
# Main outputs: data/trips_per_lsoa21_22_by_mode_<year>.Rds, consumed by the
# PlaceBasedCarbonCalculator build pipeline (../build, `pt_frequency` target).
# Also: a three-way comparison of the bus timetable sources, one snapshot per
# year for 2022-2026 (reports/bus_source_comparison.md).
#
# Every source is converted from RAW timetable data with the current
# (audited/fixed) UK2GTFS: NPTDR ATCO-CIF, Bus Archive and TNDS TransXChange
# (incl. the NCSD coach archive), ATOC / Rail Data Portal CIF. The 2024/2025
# bus figures sum this pipeline's own TNDS conversion with the DfT-produced
# BODS GTFS, which is used as supplied — it is an independently converted
# source in its own right.
#
# Run with run.R or targets::tar_make(). The conversions take days of
# compute in total; targets caches every step and the multi-file
# conversions also cache per file (gtfs/cache/), so interrupted runs resume.

library(targets)

tar_option_set(
  packages = c("UK2GTFS", "sf", "dplyr", "tidyr", "lubridate", "purrr",
               "data.table", "igraph"),
  format = "rds",
  memory = "transient",
  garbage_collection = TRUE
)

for (f in list.files("R", full.names = TRUE)) source(f)

# --- Bus source comparison targets, built programmatically ---
#
# One target per source and year (so an interrupted run resumes at the last
# completed source), then one combining target per year, then one report
# over all years. The TNDS and BODS TransXChange feeds are converted by this
# pipeline, so those targets are referenced by symbol to create the
# dependency; the BODS GTFS feed is read from the data drive as supplied.
cmp_tnds_target <- c(`2022` = "tnds_20221102", `2023` = "tnds_20231101",
                     `2024` = "tnds_20241004", `2025` = "tnds_20251003",
                     `2026` = "tnds_20260204")

comparison_targets <- unlist(lapply(comparison_years(), function(y) {
  ys <- as.character(y)
  feed_target <- c(tnds = cmp_tnds_target[[ys]],
                   bods_txc = paste0("bods_txc_", ys),
                   bods_gtfs = NA_character_)

  per_source <- lapply(comparison_sources(), function(s) {
    dep <- feed_target[[s]]
    call <- if (is.na(dep)) {
      bquote(comparison_source_result(.(y), .(s), zones_file))
    } else {
      bquote(comparison_source_result(.(y), .(s), zones_file, .(as.name(dep))))
    }
    tar_target_raw(sprintf("cmp_%s_%s", ys, s), call)
  })

  combine <- tar_target_raw(
    paste0("comparison_", ys),
    bquote(combine_year_comparison(
      .(y),
      list(.(as.name(sprintf("cmp_%s_tnds", ys))),
           .(as.name(sprintf("cmp_%s_bods_txc", ys))),
           .(as.name(sprintf("cmp_%s_bods_gtfs", ys)))))),
    format = "file")

  c(per_source, list(combine))
}), recursive = FALSE)

comparison_report_target <- tar_target_raw(
  "comparison_report",
  as.call(c(quote(render_comparison_report),
            list(as.call(c(quote(c),
                           lapply(paste0("comparison_", comparison_years()),
                                  as.name)))))),
  format = "file")

list(
  # Zone polygons: LSOA21 (E&W) / DZ22 (Scotland), widened for stop access
  tar_target(zones_file, ensure_zones(load_cfg()), format = "file"),

  # Shared conversion inputs. cue never: a fresh NaPTAN/bank-holiday download
  # must not invalidate (and so force reconversion of) every timetable; use
  # tar_invalidate(c(txc_cal, naptan)) to refresh them deliberately.
  tar_target(txc_cal, txc_calendar(), cue = tar_cue(mode = "never")),
  tar_target(naptan, UK2GTFS::get_naptan(), cue = tar_cue(mode = "never")),

  # --- Conversions from raw data ---

  # NPTDR ATCO-CIF October archives (bus, coach, ferry, some rail/metro)
  tar_target(nptdr_2004, convert_nptdr_year(2004, naptan), format = "file"),
  tar_target(nptdr_2005, convert_nptdr_year(2005, naptan), format = "file"),
  tar_target(nptdr_2006, convert_nptdr_year(2006, naptan), format = "file"),
  tar_target(nptdr_2007, convert_nptdr_year(2007, naptan), format = "file"),
  tar_target(nptdr_2008, convert_nptdr_year(2008, naptan), format = "file"),
  tar_target(nptdr_2009, convert_nptdr_year(2009, naptan), format = "file"),
  tar_target(nptdr_2010, convert_nptdr_year(2010, naptan), format = "file"),
  tar_target(nptdr_2011, convert_nptdr_year(2011, naptan), format = "file"),

  # Bus Archive weekly TransXChange snapshots, Monday-week trimmed + merged
  tar_target(busarchive_2014, convert_bus_archive_year(2014, txc_cal, naptan), format = "file"),
  tar_target(busarchive_2015, convert_bus_archive_year(2015, txc_cal, naptan), format = "file"),
  tar_target(busarchive_2016, convert_bus_archive_year(2016, txc_cal, naptan), format = "file"),
  tar_target(busarchive_2017, convert_bus_archive_year(2017, txc_cal, naptan), format = "file"),

  # TNDS TransXChange snapshots (11 regions + NCSD coach where present)
  tar_target(tnds_20180515, convert_tnds_snapshot("20180515", txc_cal, naptan), format = "file"),
  tar_target(tnds_20191008, convert_tnds_snapshot("20191008", txc_cal, naptan), format = "file"),
  tar_target(tnds_20200701, convert_tnds_snapshot("20200701", txc_cal, naptan), format = "file"),
  tar_target(tnds_20211012, convert_tnds_snapshot("20211012", txc_cal, naptan), format = "file"),
  tar_target(tnds_20221102, convert_tnds_snapshot("20221102", txc_cal, naptan), format = "file"),
  tar_target(tnds_20231101, convert_tnds_snapshot("20231101", txc_cal, naptan), format = "file"),
  tar_target(tnds_20241004, convert_tnds_snapshot("20241004", txc_cal, naptan), format = "file"),
  tar_target(tnds_20251003, convert_tnds_snapshot("20251003", txc_cal, naptan), format = "file"),

  # Rail: ATOC CIF (2018-2024), then the National Rail Data Portal (2025)
  tar_target(rail_2018, convert_atoc_date("2018-10-16"), format = "file"),
  tar_target(rail_2019, convert_atoc_date("2019-08-31"), format = "file"),
  tar_target(rail_2020, convert_atoc_date("2020-11-26"), format = "file"),
  tar_target(rail_2021, convert_atoc_date("2021-10-09"), format = "file"),
  tar_target(rail_2022, convert_atoc_date("2022-11-02"), format = "file"),
  tar_target(rail_2023, convert_atoc_date("2023-11-01"), format = "file"),
  tar_target(rail_2024, convert_atoc_date("2024-10-05"), format = "file"),
  tar_target(rail_rdp_2025, convert_rail_rdp("20251006"), format = "file"),

  # --- Per-year frequency statistics (the files ../build consumes) ---

  tar_target(trips_2004, run_year(2004, zones_file, nptdr_2004), format = "file"),
  tar_target(trips_2005, run_year(2005, zones_file, nptdr_2005), format = "file"),
  tar_target(trips_2006, run_year(2006, zones_file, nptdr_2006), format = "file"),
  tar_target(trips_2007, run_year(2007, zones_file, nptdr_2007), format = "file"),
  tar_target(trips_2008, run_year(2008, zones_file, nptdr_2008), format = "file"),
  tar_target(trips_2009, run_year(2009, zones_file, nptdr_2009), format = "file"),
  tar_target(trips_2010, run_year(2010, zones_file, nptdr_2010), format = "file"),
  tar_target(trips_2011, run_year(2011, zones_file, nptdr_2011), format = "file"),
  tar_target(trips_2014, run_year(2014, zones_file, busarchive_2014), format = "file"),
  tar_target(trips_2015, run_year(2015, zones_file, busarchive_2015), format = "file"),
  tar_target(trips_2016, run_year(2016, zones_file, busarchive_2016), format = "file"),
  tar_target(trips_2017, run_year(2017, zones_file, busarchive_2017), format = "file"),
  tar_target(trips_2018, run_year(2018, zones_file, tnds_20180515, rail_2018), format = "file"),
  tar_target(trips_2019, run_year(2019, zones_file, tnds_20191008, rail_2019), format = "file"),
  tar_target(trips_2020, run_year(2020, zones_file, tnds_20200701, rail_2020), format = "file"),
  tar_target(trips_2021, run_year(2021, zones_file, tnds_20211012, rail_2021), format = "file"),
  tar_target(trips_2022, run_year(2022, zones_file, tnds_20221102, rail_2022), format = "file"),
  tar_target(trips_2023, run_year(2023, zones_file, tnds_20231101, rail_2023), format = "file"),
  tar_target(trips_2024, run_year(2024, zones_file, tnds_20241004, rail_2024), format = "file"),
  tar_target(trips_2025, run_year(2025, zones_file, tnds_20251003, rail_rdp_2025), format = "file"),

  # --- Bus source comparison, 2022-2026: TNDS TransXChange vs BODS
  # --- TransXChange vs BODS GTFS, each year counted over one shared
  # --- window and the same zones.
  #
  # The TNDS feeds for 2022-2025 are the same targets the main trips_<year>
  # outputs use; 2026 is converted only for the comparison. The BODS
  # TransXChange change archives are converted here (the archive file name
  # does not always match its folder, hence the explicit `archive`).
  tar_target(tnds_20260204, convert_tnds_snapshot("20260204", txc_cal, naptan), format = "file"),

  tar_target(bods_txc_2022, convert_bods_txc("20221102", txc_cal, naptan,
                                             archive = "bodds_archive_20221102.zip",
                                             filter_date = "2022-11-02"), format = "file"),
  tar_target(bods_txc_2023, convert_bods_txc("20231101", txc_cal, naptan,
                                             archive = "bodds_archive_20231101.zip",
                                             filter_date = "2023-11-01"), format = "file"),
  tar_target(bods_txc_2024, convert_bods_txc("20241007", txc_cal, naptan,
                                             archive = "bodds_archive_20241006.zip",
                                             filter_date = "2024-10-07"), format = "file"),
  tar_target(bods_txc_2025, convert_bods_txc("20251006", txc_cal, naptan,
                                             archive = "bodds_archive_20251005.zip",
                                             filter_date = "2025-10-06"), format = "file"),
  tar_target(bods_txc_2026, convert_bods_txc("20260204", txc_cal, naptan,
                                             archive = "bodds_archive_20260204.zip",
                                             filter_date = "2026-02-04"), format = "file"),

  # --- Validation against published timetables ---
  #
  # A current snapshot of all three sources, converted the same way as the
  # comparison feeds. Published timetables are easy to obtain for today and
  # hard for the past, so the PDFs in data/example_timetables are checked
  # against this rather than against a historic snapshot.
  tar_target(tnds_20260726, convert_tnds_snapshot("20260726", txc_cal, naptan),
             format = "file"),
  tar_target(bods_txc_20260725,
             convert_bods_txc("20260725", txc_cal, naptan,
                              archive = "bodds_archive_20260725.zip",
                              filter_date = "2026-07-26"), format = "file"),

  tar_target(pdf_validation, validate_published_timetables(
    zones_file, tnds_20260726, bods_txc_20260725), format = "file"),
  tar_target(pdf_validation_report, render_validation_report(pdf_validation),
             format = "file"),

  comparison_targets,
  comparison_report_target
)
