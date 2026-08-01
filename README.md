# PublicTransportAnalysis

A clean, reproducible [`targets`](https://books.ropensci.org/targets/) workflow
measuring scheduled public transport service for every small area in Great
Britain, for each year from 2004 to 2025. It supersedes the analysis half of
[ITSleeds/TransportBlackspots](https://github.com/ITSLeeds/TransportBlackspots),
keeping only the part consumed by the
[Carbon & Place](https://www.carbon.place) build pipeline (`../build`).

## Outputs

The main outputs are one file per year:

```
data/trips_per_lsoa21_22_by_mode_<year>.Rds        (2004-2011, 2014-2025)
```

Each is a data frame keyed on `zone_id` (LSOA 2021 code for England & Wales,
Data Zone 2022 for Scotland) × `route_type` (GTFS mode: 0 tram, 1 metro,
2 rail, 3 bus, 4 ferry, **200 coach**, 1100 air), with 75 value columns:

- `runs_<Day>_<Band>` — vehicle departures counted at stops in the zone over
  the 28-day study window (7 days × 5 time bands),
- `tph_<Day>_<Band>` — the same normalised to trips per hour,
- `routes_<Band>` — distinct routes serving the zone in each band.

Time bands by departure hour: Night 22:00–06:00, Morning Peak 06:00–10:00,
Midday 10:00–15:00, Afternoon Peak 15:00–18:00, Evening 18:00–22:00. Trips
departing after midnight (GTFS times ≥ 24:00) count as Night.

**Coach (200) is now separated from local bus (3) in every year** — see
*Changes from TransportBlackspots*. Analyses wanting the old "bus" concept
(which silently included coach up to 2023) should sum route types 3 and 200.

These files are consumed by `../build/R/public_transport_frequency.R` (the
`pt_frequency` target): copy them to `../inputdata/pt_frequency/`.

A secondary output is a three-way comparison of the October 2025 bus
timetable sources:
[reports/bus_source_comparison_2025.md](reports/bus_source_comparison_2025.md).

## Method

1. **Convert timetables to GTFS** with
   [UK2GTFS](https://github.com/ITSLeeds/UK2GTFS) (the development version;
   the analysis relies on functions and fixes not yet on CRAN). **Every
   source is converted from raw data by this pipeline** (see *Conversions*
   below), so all years benefit from the same, current converter — the
   pre-converted GTFS on the data drive, produced by older UK2GTFS
   versions, is not reused.
2. **Remove duplicated journeys** with `UK2GTFS::gtfs_deduplicate()`, applied
   to every feed of every source and year as it is read for counting
   (`read_feed()`). Feeds assembled from many publishers, or from several
   revisions of one publisher's data, describe the same vehicle journey
   twice — 3.7% of the DfT BODS GTFS bus runs and 2.6% of TNDS's (see
   `reports/lsoa_disagreement.md`). That is a property of the feed, not of
   the road, and it inflates every count made from it. A copy is removed only
   where the whole itinerary matches (stops, arrival and departure times,
   boarding rules), the route agrees, and every date it runs is also run by
   the copy kept, so no date loses service.
3. **Count trips per zone** with `UK2GTFS::gtfs_trips_per_zone()`: stops are
   spatially joined to zones, each service's runs per weekday within the
   study window are counted (applying `calendar_dates` exceptions with
   proper GTFS semantics), each stop-time is bucketed into a time band by
   departure hour, and results are aggregated to zone × mode × day × band.
   For feeds with `frequencies.txt` (BODS GTFS), every departure implied by
   a frequency window is counted in its own time band.
4. **Combine bus and rail** feeds for a year by summing the per-zone counts
   (2023 first takes the element-wise maximum of a spring and an autumn bus
   snapshot, because school-term services differ between terms).

### Zones

Zones are LSOA 2021 (E&W) / Data Zone 2022 (Scotland) boundaries widened for
transport access: areas smaller than a 500 m-radius circle are unioned with a
500 m buffer of their population-weighted centroid (a stop just outside a
small urban area still counts), large rural areas keep their full boundary,
and everything is buffered a further 100 m to catch stops digitised just
offshore. A stop falling in more than one zone counts in each — so summing
`runs_*` across zones over-counts national totals; use the per-zone values.

The zone file is cached at `input/GB_LSOA_2021_22_full_or_500mBuff.Rds`
(copied from the TransportBlackspots checkout if available, otherwise rebuilt
from PlaceBasedCarbonCalculator inputs by `R/zones.R::build_zones()`). The
stop-to-zone join runs with `sf_use_s2(FALSE)` (planar geometry), matching
how all published outputs were produced.

**The source-comparison and zone-gap analyses use the plain boundaries
instead** (`input/GB_LSOA_2021_22_plain.Rds`, cached by
`R/zones.R::ensure_plain_zones()` from the same PlaceBasedCarbonCalculator
build input the widened zones are derived from). Widening makes the zones
overlap, so one stop falls in several and a disagreement between two sources
at that stop is counted several times over. Those analyses ask how far two
sources differ, not what a resident can reach; unmodified boundaries tile the
country, so each stop lands in exactly one zone and each difference is counted
once. Both versions cover the same 43,064 areas with the same codes.

### Study windows

Every feed is counted over a **28-day window that always starts on a
Monday** — exactly four of every weekday — derived by flooring the source's
snapshot date to the Monday of its week. This makes `runs_*` directly
comparable across years and the `tph_*` normalisation exact.

| Year | Bus source | Bus window (Mon–Sun) | Rail source | Rail window |
|------|-----------|----------------------|-------------|-------------|
| 2004–2011 | NPTDR October snapshot | Monday of the week of 1 Oct + 28 d | (within NPTDR) | — |
| 2014 | Bus Archive (TNDS weekly) | 2014-10-06 – 2014-11-02 | — | — |
| 2015 | Bus Archive | 2015-10-05 – 2015-11-01 | — | — |
| 2016 | Bus Archive | 2016-10-03 – 2016-10-30 | — | — |
| 2017 | Bus Archive | 2017-10-02 – 2017-10-29 | — | — |
| 2018 | TNDS | 2018-05-14 – 2018-06-10 | ATOC | 2018-10-15 – 2018-11-11 |
| 2019 | TNDS | 2019-10-07 – 2019-11-03 | ATOC | 2019-08-26 – 2019-09-22 |
| 2020 | TNDS | 2020-06-29 – 2020-07-26 | ATOC | 2020-11-23 – 2020-12-20 |
| 2021 | TNDS | 2021-10-11 – 2021-11-07 | ATOC | 2021-10-04 – 2021-10-31 |
| 2022 | TNDS | 2022-10-31 – 2022-11-27 | ATOC | 2022-10-31 – 2022-11-27 |
| 2023 | TNDS, max(spring, autumn) | 2023-05-01 – 2023-05-28 and 2023-10-30 – 2023-11-26 | ATOC | 2023-05-01 – 2023-05-28 |
| 2024 | BODS GTFS | 2024-10-07 – 2024-11-03 | ATOC | 2024-09-30 – 2024-10-27 |
| 2025 | BODS GTFS | 2025-10-06 – 2025-11-02 | **Rail Data Portal** | 2025-10-06 – 2025-11-02 |

October is the preferred analysis month (a "normal" school-term month); the
exceptions (2018/2020/2023 bus, some rail snapshots) are where no October
snapshot was archived. The 2020 window falls between COVID lockdowns and
reflects substantially reduced timetables.

### Conversions performed by this pipeline

All conversions are done from raw data into `gtfs/` (per-file intermediate
results are cached under `gtfs/cache/` so interrupted runs resume):

- **NPTDR 2004–2011** — the raw `October-<year>.zip` ATCO-CIF archives via
  `nptdr2gtfs()`, which uses the historic bank holiday and school-term data
  shipped with UK2GTFS.
- **Bus Archive 2014–2017** — the raw weekly regional TransXChange
  snapshots via `transxchange2gtfs()`. Snapshots are dated on Tuesdays;
  each converted week is trimmed to its Monday–Sunday week before merging
  so the merged feed exactly tiles the Monday-aligned study window. A
  static 2013–2018 bank-holiday table (cross-checked against UK2GTFS's
  `historic_bank_holidays`) extends the gov.uk calendar back over this era.
- **TNDS snapshots 2018–2023 and October 2025** — the 11 regional zips
  *plus the NCSD national coach archive* via `transxchange2gtfs()`
  (Scottish bank holidays for `S.zip`), trimmed to ±31 days around the
  snapshot and merged.
- **Rail 2018–2024** — the raw ATOC CIF snapshots via `atoc2gtfs()`.
- **Rail October 2025** — from the National Rail Data Portal
  (`RailDataPortal/20251006/timetable.zip`), the successor to the ATOC data
  feed, converted with `atoc2gtfs()` (the current UK2GTFS handles the
  portal's newer CIF flavour).
- **BODS TransXChange October 2025** — converted for the source-comparison
  report; the BODS change archive is de-duplicated with
  `filter_duplicate_files` (keeping the dataset revisions valid on
  2025-10-06).

Every TransXChange/NPTDR conversion gets the same post-treatment:
`gtfs_clean()`, known-bad stop coordinates patched from
`UK2GTFS::naptan_replace`, and `gtfs_interpolate_times()` to fill missing
intermediate stop times.

## Running the pipeline

```r
# in this directory (R >= 4.3, dev UK2GTFS >= 0.4.0 installed)
targets::tar_make()      # or: Rscript run.R
```

External inputs expected (configure in `R/config.R`, or set `UK2GTFS_DATA`):

- `D:/OneDrive - University of Leeds/Data/UK2GTFS/` — the timetable archive
  (NPTDR, Bus Archive, TNDS, ATOC, OpenBusData, RailDataPortal). Read-only.
- `../../ITSleeds/TransportBlackspots` or `../build` — only for the zone
  polygons (copied/rebuilt once into `input/`).

The pipeline is resumable (`_targets/` caches every step) and takes many
hours end-to-end: the year counts are ~20–60 min each and the two
TransXChange conversions for the comparison are the slowest steps.

## Changes from TransportBlackspots

This repo reproduces the TransportBlackspots methodology but is **not**
output-identical to the `.Rds` files previously distributed from that repo.
The differences are deliberate:

1. **A real workflow.** One declarative `targets` pipeline replaces ~15
   interdependent scripts with hand-edited year lists, commented-out blocks
   and copy-pasted per-year branches. The year/source/window mapping is a
   single table in [R/config.R](R/config.R).
2. **Analysis functions live in UK2GTFS.** `gtfs_trips_per_zone()`,
   `gtfs_trim_dates()`, `gtfs_stop_frequency()` and friends were moved
   upstream (with regression tests) during the 2026 audit; the repo-local
   copy (`R/stops_per_week_functions.R`) is gone. This repo contains **no
   GTFS-processing logic of its own**, only orchestration.
3. **Corrected `calendar_dates` handling** (UK2GTFS fix, July 2026). The
   published outputs were generated before the fix: cancellations were
   subtracted even on days a service did not operate, and duplicate
   exception rows in merged feeds were double-counted, producing
   under-counts and occasional negative run counts. TransXChange feeds
   routinely "cancel" bank-holiday-type days for every service of a route
   regardless of its day pattern, so the under-count was widespread.
4. **Standardised 28-day Monday-aligned windows for every year.** The
   published 2004–2011 outputs used calendar-month windows (1–31 October:
   five Fridays/Saturdays/Sundays but four of other weekdays), and other
   years used windows not aligned to weeks. Raw `runs_*` values are now
   comparable across years and days; previously weekend counts in NPTDR
   years were inflated ~25 % relative to mid-week days.
5. **Every source re-converted from raw data.** The old workflow reused
   GTFS conversions made with UK2GTFS versions from 2023 or earlier; this
   pipeline converts NPTDR, Bus Archive, TNDS (including the NCSD coach
   archive), ATOC and Rail Data Portal data from raw with the current
   converter, and re-merges the 2014–2017 weekly feeds Monday-aligned
   (previously Tuesday-aligned, misallocating services across window
   boundaries).
6. **Coach (GTFS extended type 200) separated from local bus (3)**
   (UK2GTFS change, July 2026). Previously UK2GTFS folded coach into bus,
   so the 2004–2023 "bus" series silently included National Express-style
   coach services while the 2024+ BODS GTFS years excluded them — an
   inconsistency at the source switch. Coach is now a separate mode in
   every year. Sum types 3 + 200 to recover the old bus-including-coach
   concept for 2004–2023.
7. **`frequencies.txt` support** (UK2GTFS, July 2026). The BODS GTFS feeds
   (2024, 2025) describe some services as frequency windows rather than
   individual trips; these departures were previously ignored. Each implied
   departure is now counted in its correct time band.
8. **Extended to 2025**, with rail from the new National Rail Data Portal
   (the ATOC feed this analysis previously used was retired).
9. **Only the Carbon & Place outputs.** The FOE-specific downstream analysis
   (blackspot classification, quintiles, maps, xlsx exports) stays in
   TransportBlackspots; this repo produces just the per-year frequency
   files, plus the source-comparison report.

Two further UK2GTFS bugs were found and fixed while building this pipeline
(July 2026): `gtfs_merge()` corrupted the S4 Period time columns produced by
`gtfs_read()` (making feeds read from disk unmergeable), and `gtfs_read()`
mistyped `frequencies.txt` and numeric-looking id columns. Regression tests
are in `../UK2GTFS/tests/testthat/test_bug_fixes.R`.

If you need to compare against the old outputs: the published files
correspond to pre-July-2026 UK2GTFS conversions and counting, month-based
windows for 2004–2011, Tuesday-aligned 2014–2017 merges, and coach counted
inside bus up to 2023. `scripts/compare_published_outputs.R` quantifies the
differences year by year.

## Data sources and known limitations

Scheduled, not actual, service throughout: everything derives from published
timetables; cancellations on the day, reliability and short-notice changes
are invisible.

| Era | Source | Limitations |
|-----|--------|-------------|
| 2004–2011 | **NPTDR** (National Public Transport Data Repository), annual October snapshots | Data quality varies by year and region; some rail/metro/tram included but coverage of non-bus modes is inconsistent; some stops have missing/bad coordinates (dropped or patched); 2012–2013 do not exist (the programme was discontinued, later replaced by TNDS archiving). |
| 2014–2017 | **Bus Archive** TNDS weekly snapshots | Essentially no rail, tram or metro — bus (`route_type == 3`) is the only mode with a continuous series across this gap. Weekly snapshots must be stitched; snapshot dates are Tuesdays. |
| 2018–2023 | **TNDS** (Traveline National Dataset) | Bus/coach/ferry/tram but no heavy rail (added separately from ATOC). Coach comes from the separate NCSD archive, **discontinued after February 2025**. Compiled from local authority systems; late-notice operator changes can lag. From ~2021 TNDS England content is itself increasingly derived from BODS. Not every year has an October snapshot archived (2018: May; 2020: July). |
| 2018–2024 rail | **ATOC / Rail Delivery Group CIF** | London Underground is *not* in the CIF feed; metro coverage relies on TNDS/BODS. Includes some rail-replacement and ship services (recoded appropriately by UK2GTFS). |
| 2024–2025 | **BODS GTFS** (DfT's GTFS rendering of the Bus Open Data Service) | Statutory coverage is *English local bus services only*: Scottish and Welsh coverage is partial (voluntary/cross-border publication, Traveline Cymru uploads) — treat Scottish/Welsh 2024–2025 levels and trends with caution. Uses extended route types (e.g. 200 coach), harmonised where this analysis needs it. Includes `frequencies.txt`-based services. |
| 2025 rail | **National Rail Data Portal CIF** | Successor to the ATOC feed; newer CIF flavour (RSPS5046). Same scope caveats as ATOC (no London Underground). |

Further caveats:

- **The 2017 → 2018 transition mixes sources** (Bus Archive → TNDS) and
  **2023 → 2024 switches bus source entirely** (TNDS → BODS GTFS). The
  source-comparison report quantifies the TNDS/BODS difference at a point in
  time where all sources exist; read cross-boundary trends with that
  context.
- **2020 reflects COVID-era timetables**, and its bus and rail windows are
  five months apart.
- **A few stops fall outside all zones** (mostly offshore/erroneous
  coordinates); they appear as `zone_id = NA` rows in the outputs — drop
  them before analysis (the build pipeline does).
- **Use `tph_*` for cross-year comparison.** Although all windows are now
  exactly 28 days, `tph_*` is the intended comparable measure.
- **Mode composition is only trustworthy for bus.** Rail is absent
  2014–2017 and separately sourced elsewhere; tram/metro coverage varies by
  source. Coach (200) coverage depends on the NCSD archive for TNDS years
  and on operator publication to BODS for 2024–2025; there is **no coach
  data at all in the October 2025 TNDS snapshot** (NCSD discontinued).

## Repo layout

```
_targets.R        pipeline definition (all targets)
R/config.R        paths, study-window rule, year/source table
R/zones.R         zone polygon construction
R/convert.R       UK2GTFS conversions (Bus Archive merges, RDP rail, TXC)
R/frequency.R     per-year trips-per-zone computation
R/comparison.R    October 2025 three-source bus comparison
reports/          comparison report (Rmd + rendered md)
data/             outputs (gitignored; copy to ../inputdata/pt_frequency)
gtfs/             GTFS built by this pipeline (gitignored)
input/            cached zone polygons (gitignored)
```
