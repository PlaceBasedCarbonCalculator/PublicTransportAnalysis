# TNDS conversion investigation

Scripts behind `reports/tnds_conversion_investigation.md`. They go back to the
raw TransXChange of the TNDS snapshot `data_20260726` (both the 2.1 files and
the `TNDSV2.5/` files) and check the zone counts that disagreed with the
published timetables in `reports/pdf_validation.md`. Python only (pandas); no
R and no UK2GTFS needed.

Set `TNDS_WORK` to a directory that holds:

* `tnds/v21/<region>.zip` and `tnds/v25/<region>.zip`: the TNDS regional
  zips (not committed);
* `checks.pkl` and `geo/zone_stops.json` from the zone validation work
  directory (`scripts/zone_pdf_validation`, `$ZPV_WORK`).

| Script | What it does |
|---|---|
| `txscan.py v21 SE` | Header scan of every file in a region zip → `tnds/scan/v21_SE.pkl` |
| `txc_count.py` | Independent TransXChange journey counter (calendars, serviced organisations, special days, bank holidays) |
| `rawcheck.py` | Runs the counter over every file in every region that publishes each disagreeing route, in both editions |
| `compare_versions.py` | 2.1 against 2.5, file by file, and whether each removed file is published in another region |
| `overlap_emulation.py v21` | Python port of UK2GTFS `txc_overlap_plan()`, with and without the sibling fix |
| `uk2gtfs_overlap_siblings.patch` | The proposed UK2GTFS fix, against itsleeds/UK2GTFS 6824b31 |

## Using the UK2GTFS patch

`uk2gtfs_overlap_siblings.patch` changes one function in UK2GTFS,
`txc_overlap_plan()` in `R/txc_filter_files.R`, the overlap rule
`txc_filter_files()` applies when `resolve_overlaps = TRUE`. It stops the rule
reconciling two files that were written at the same instant
(`CreationDateTime`) under different `ServiceCode`s, because those are parts
of one publication, not successive registrations. It was written against
itsleeds/UK2GTFS commit `6824b31`. It has not been run in R; the Python port
in `overlap_emulation.py` shows its effect.

### 1. Apply it to a UK2GTFS checkout

From the UK2GTFS repository (for this project usually
`../../ITSleeds/UK2GTFS`):

```sh
git checkout -b overlap-siblings
git apply --check /path/to/PublicTransportAnalysis/scripts/tnds_investigation/uk2gtfs_overlap_siblings.patch
git apply /path/to/PublicTransportAnalysis/scripts/tnds_investigation/uk2gtfs_overlap_siblings.patch
git diff --stat      # R/txc_filter_files.R | 14 ++++++++++++++
```

If `--check` fails because UK2GTFS has moved on since `6824b31`, use
`git apply -3` to merge it, or add the block by hand. It is 14 lines placed
straight after the `# no overlap` line in the pair loop of
`txc_overlap_plan()`, before `if (si == sj && ei == ej) {`.

### 2. Install it

With no pipeline running:

```r
remotes::install_local("../../ITSleeds/UK2GTFS", force = TRUE)
packageDescription("UK2GTFS")$Built   # should be today
```

### 3. Check it on First Essex X30 (a few seconds, no pipeline)

Unzip the South East region of the TNDS snapshot and filter the X30 files:

```r
d <- file.path(tempdir(), "se")
unzip(file.path(Sys.getenv("UK2GTFS_DATA"), "TransXChange/data_20260726/SE.zip"),
      exdir = d)
x30 <- list.files(d, "^SE_FG_FESX_X30_", full.names = TRUE, recursive = TRUE)
kept <- UK2GTFS::txc_filter_files(x30, date = as.Date("2026-07-26"))
basename(kept)
```

The unpatched package keeps `SE_FG_FESX_X30_1.xml` and
`SE_FG_FESX_X30_5_A.xml` only. With the patch, `X30_2_A`, `X30_3_A` and
`X30_4_A` are kept as well. `X30_5_A` is the previous week's file, created
on a different date, and is still reconciled as before. The same test on
`list.files(d, "^SE_FG_FESX_(C7|336|333)_", ...)` should keep `C7_2_A`,
`336_3_A` and `333_3_A`.

### 4. Rebuild what it affects

Reinstalling UK2GTFS invalidates nothing. `targets` hashes this repository's
code, not the installed library, and every conversion is cached on disk (see
`rebuild_nonbus_fixes.R` for the same problem last time). Both the cached
regional conversions and the target have to go:

```r
# 1. the cached regional conversions of the snapshot
unlink(list.files(file.path(load_cfg()$gtfs_dir, "cache", "tnds_20260726"),
                  full.names = TRUE))
# 2. the target and everything downstream of it
targets::tar_invalidate(tnds_20260726)
targets::tar_make()
```

If you only want the regions the fix changes, delete only the SE, NW, SW, NE,
EM, Y and W caches. The emulation finds no sibling files in EA, WM or L.
`pdf_validation`, `pdf_validation_report` and the LSOA disagreement
counts then rebuild from the new feed.

The same rule also runs for the other TNDS snapshots (`tnds_2018...` to
`tnds_20251003`) and for the BODS TransXChange conversion
(`convert_bods_txc()`, cache `bods_txc_<snapshot>_full.zip`). They keep their
current results until their caches are deleted and their targets
invalidated in the same way.

If you also switch to the TransXChange 2.5 files
(`reports/tnds_conversion_investigation.md`, section 2), do both in one
rebuild. The suggested change there writes to a separate cache folder
(`tnds_20260726_v25`), so the old 2.1 cache can stay for comparison.
