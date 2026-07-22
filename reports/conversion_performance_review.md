# Conversion pipeline performance review

*2026-07-17. Written while the pipeline was mid-run (`tnds_20211012` converting);
no code has been changed. All timings are measured from this run's `targets`
metadata, the pipeline log, and the modification times of the per-region cache
files in `gtfs/cache/`, which bracket each conversion stage exactly.*

## 1. Where the time has gone so far

Completed conversion targets, slowest first (`targets::tar_meta()`):

| Target | Hours | Output |
|---|---|---|
| tnds_20191008 | 19.9 | 444 MB |
| tnds_20180515 | 7.3 | 359 MB |
| tnds_20231101 | 5.9 | 326 MB |
| tnds_20251003 | 5.6 | 364 MB |
| nptdr_2008 | 5.5 | 398 MB |
| nptdr_2007 | 5.4 | 384 MB |
| nptdr_2011 | 5.3 | 378 MB |
| nptdr_2009 / 2010 / 2005 / 2006 | 4.5–4.8 | 285–407 MB |
| bods_txc_2025 | 2.9 | 104 MB |
| nptdr_2004 | 2.8 | 191 MB |
| rail (each of 8 ATOC/RDP years) | **0.07–0.15** | 23–42 MB |

The rail CIF conversions are effectively free. All of the cost is in the two
bus paths: TransXChange (TNDS / BODS / Bus Archive) and NPTDR ATCO-CIF.

### 1.1 TransXChange: the XML *import* phase dominates, and it is pathological on big files

`transxchange2gtfs()` runs two parallel phases per region — "Importing
TransXchange files" then "Converting to GTFS" — followed by
single-threaded merge/clean/interpolate/write. The log timestamps split these
precisely. For `tnds_20180515` (7.3 h total): import ≈ 2.9 h, everything after
≈ 4.2 h, spread fairly evenly over 12 regions.

But the 19.9 h of `tnds_20191008` is not spread evenly — it is almost entirely
two regions' *import* phases:

| Region (2019) | Import | Everything after | Total |
|---|---|---|---|
| **NE** | **7 h 24 m** | 1 h 42 m | 9 h 07 m |
| **SE** | **1 h 51 m** | 1 h 30 m | 3 h 21 m |
| L | ~2 h | ~24 m | 2 h |
| other 9 regions | minutes each | 10–45 m each | ~4 h |

NE 2019 is 841 files / 2.66 GB uncompressed with a dozen 30–56 MB XML files
(`NE_410_PA0019SIN_*`, `NE_Tees_PB*`). NE 2018 is nearly the same total size
(2.2 GB, max file 34 MB) yet imported in 40 minutes. Import cost is therefore
**super-linear in single-file size**: one 56 MB file pins one worker for hours
while the other 9 cores go idle (files are processed largest-first, so the
whole phase waits on it).

The cause is in dev UK2GTFS `import_OperatingProfile()`
(`R/import_OperatingProfile.R:21-251`): an R `for` loop over **every
`OperatingProfile` element — one per vehicle journey**, i.e. tens of
thousands of iterations for a big file, each iteration making ~20 `xml2`
calls, building 1–3 tiny `data.frame`s and up to two `merge()` cross-joins.
Worse, `import_notes2()` (`R/transxchange_import_functions.R:362-388`) calls
`xml2::xml_child(vehiclejourneys, i)` inside its loop — an O(n) sibling walk
per call, so **O(n²) in the number of journeys** for files where journeys
carry notes. A 30k-journey file costs ~900M node traversals. That is the
7-hour file. `import_services()` and `import_journeypatternsections()` are
vectorised (`xml_find_all` over node sets) and are not the problem.

### 1.2 TransXChange: the "everything after" half

The remaining ~1.5–4 h per snapshot is per-region export + `post_convert` +
write, of which two items stand out:

- **`gtfs_interpolate_times()`** (called in `post_convert()`,
  `R/convert.R:133`): per-trip `stops_interpolate()` using lubridate Period
  (S4) arithmetic, with a `dplyr::group_split()` into one tibble per trip
  shipped to workers. Typical TNDS region: 50k–160k of its trips need
  interpolation (from the log, e.g. NE 2018 "105338 of 121640 trips").
- **`transxchange_export()` per-trip R loops** for files with exclusions /
  ServicedOrganisations (`split(trips, trips$trip_id)` + `lapply`,
  `R/transxchange_export.R:421-427`) and the per-journey-pattern loops in
  `make_stop_times()` (`R/transxchange_export_functions.R:462-488`). These run
  inside the parallel export phase, so they hurt less than import, but they
  are why "Converting to GTFS" still takes 1.5 h for NE 2019.

### 1.3 NPTDR: ~5 h/year, and it is not the CIF reading

Reading the 449 CIF files takes ~6 minutes (log progress ETA). The remaining
~4.5 h per year is:

- **`gtfs_interpolate_times()` again, at 8× the TNDS scale**: NPTDR times are
  minute-resolution HHMM, so consecutive stops constantly share times — the
  log shows **983,489 of 1,276,283 trips (2006)** and **1,186,804 of
  1,558,602 (2007)** needing interpolation. `group_split()` of a ~30M-row
  stop_times table into ~1M one-trip tibbles, serialising them to 10 workers,
  then Period arithmetic per trip, is plausibly 2–3 of the 4.5 hours.
- **`nptdr_schedule2routes()` + `nptdr_makeCalendar()`** — single-threaded;
  `nptdr_makeCalendar()` does `group_split()` + `purrr::map()` per schedule
  with exceptions (`R/nptdr_export.R:46-84`).
- The QR "repetitions" loop in `importCIF()` (`R/nptdr.R` QR block) does
  per-repetition lubridate `hm()` parsing — minor but easy to vectorise.
- `gtfs_write()` is fine (`data.table::fwrite` + `zip::zipr`).

### 1.4 What is still to run (where speedups would actually pay)

At the time of writing: `tnds_20211012` is mid-conversion; still queued are
`tnds_20200701`, `tnds_20221102`, `tnds_20241004`, and — the big one —
**`busarchive_2015/2016/2017`**: each is ~44 weekly-regional TransXChange
conversions (4 Monday weeks × 11 regions). At observed per-region rates that
is roughly 10–20 h per year from scratch, so the Bus Archive block is likely
the largest remaining cost (2014 completed in 44 m only because its weekly
caches already existed). After conversions come the 20 `trips_*` counting
targets, which are outside the scope of this report.

## 2. How to speed it up, ranked

### 2.1 Run conversion targets concurrently (no UK2GTFS changes, zero output risk)

The pipeline currently runs one target at a time with `cfg$ncores = 10` on a
36-core / 256 GB machine — and the long single-file import tails mean even
those 10 cores are often mostly idle. The remaining conversions are mutually
independent and write to separate cache directories. Adding a
[crew](https://wlandau.github.io/crew/) controller to `_targets.R`:

```r
tar_option_set(controller = crew::crew_controller_local(workers = 3))
```

runs three targets at once (each internally parallel with its own 10 workers)
for roughly a 2–3× wall-time reduction on everything left, with no change to
any output byte. Memory is comfortable: peak observed usage per conversion is
well under 50 GB. This cannot be enabled mid-run — apply it when the current
`tar_make()` stops.

### 2.2 Vectorise `import_OperatingProfile()` and fix `import_notes2()` (the single biggest code win)

This removes the 7-hour import tails. The common case — a journey with just
`RegularDayType/DaysOfWeek` and maybe `BankHolidayOperation` — can be done
vectorised over the whole `VehicleJourney` node set with
`xml_find_first(nodeset, ...)` (C-level, one call per *field* instead of ~20
calls per *journey*), falling back to the existing loop only for the rare
journeys containing `SpecialDaysOperation` / `ServicedOrganisationDayType`
elements (find those with one `xml_find_all` first). In `import_notes2()`,
replace `xml_child(vehiclejourneys, i)` with a single `xml_children()` call
indexed by `i` to remove the O(n²) sibling walk.

Expected effect: NE-2019-class regions drop from ~7 h to minutes; typical
region imports drop from 10–40 m to a few minutes; a TNDS snapshot goes from
5–20 h to roughly 2–4 h. This also directly accelerates the three Bus Archive
years and any future BODS conversion.

### 2.3 Rewrite `gtfs_interpolate_times()` on numeric seconds (biggest NPTDR win, helps every path)

All the information needed is per-trip runs of duplicated arrival times; the
whole operation is expressible vectorised in data.table on integer seconds:
order by `trip_id, stop_sequence`, flag duplicate runs with `rleid`, and
linearly interpolate (`approx()` or arithmetic on run indices) between run
boundaries — no `group_split()`, no per-trip tibbles, no Period arithmetic,
no parallelism needed. A ~1M-trip NPTDR feed should take low minutes instead
of hours. The refactor must be verified output-identical (§3).

NPTDR years are already converted, so this pays off only for the remaining
TXC targets (~15–60 m each) — unless NPTDR is ever reconverted, where it
would save ~2–3 h/year.

### 2.4 Raise `cfg$ncores` while targets still run one-at-a-time

With 36 physical cores, `ncores = 10` leaves most of the machine idle during
the import/export/interpolate phases. If §2.1 (crew) is adopted, keep ~10–12
per target; if not, raising `cfg$ncores` to ~24 is a free ~1.5–2× on the
parallel phases (watch RAM only for BODS-archive-sized imports).

### 2.5 Smaller items (worth doing opportunistically, not urgent)

- `importCIF()` QR repetitions block (`R/nptdr.R`): vectorise the per-row
  lubridate `hm()` arithmetic.
- `transxchange_export()` exclusions: replace `split()`/`lapply` per trip
  with a data.table join on the exclusion table.
- `nptdr_makeCalendar()`: replace per-schedule `group_split`/`map` with
  data.table by-group operations.
- `gtfs_merge()` / `seconds_to_period_hms()`: Period reconstruction over
  ~30M stop_times rows costs a few minutes per merged snapshot; could stay
  numeric until `gtfs_write()`.
- The per-file `gtfs_validate_internal()` "Error [stops]" console reports are
  noisy but cheap; not a performance issue.

## 3. Safety notes before touching anything

- **Don't edit UK2GTFS while `tar_make()` is mid-target.** The parallel
  phases spawn fresh workers that `library(UK2GTFS)` at phase start, so a
  reinstall mid-conversion could mix package versions inside one target.
  Apply changes between runs (interrupting between targets is safe — every
  conversion is cached).
- **`targets` does not track package code**, so completed targets stay valid
  after a UK2GTFS reinstall. That is desirable here, but it also means any
  *behaviour*-changing edit would silently create inconsistency between
  already-converted and not-yet-converted years. Performance work must
  therefore be output-identical.
- **Verification recipe**: the per-region caches make this easy. Convert one
  already-cached region (e.g. `tnds_20231101` NE) with the modified package
  into a scratch directory and diff the extracted GTFS tables against
  `gtfs/cache/tnds_20231101/NE.zip` — they should be byte-identical apart
  from file ordering. Do the same for one NPTDR year if
  `gtfs_interpolate_times()` is rewritten (compare against a small
  `n_files=` subset conversion, since full reconversion is 5 h).
