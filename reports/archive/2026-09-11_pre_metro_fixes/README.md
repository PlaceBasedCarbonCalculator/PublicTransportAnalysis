# Reports as published before the September 2026 rebuild

These are the report files at commit ef0e178, the last state before the three
defects below were fixed and every timetable reconverted. They are kept so the
published figures remain citable and so the change in any number can be traced
to a cause rather than reconstructed from memory.

The current reports in `reports/` are built from the rebuilt data and are the
ones to use.

## What changed between these and the current versions

1. **Duplicate published copies of Underground lines.** TfL files one line
   into TNDS as several TransXChange documents with overlapping validity.
   UK2GTFS blanked any `LineName` over six characters, and
   `gtfs_deduplicate()` keys an unnamed route on its own `route_id`, so 93%
   of metro trips were exempt from deduplication. Leytonstone (E01004440) read
   96.8 trips per hour in 2021 and 101.3 in 2025 against ~55 either side.

2. **`gtfs_merge()` numbered `file_id` per table, not per feed.** The NCSD
   coach archive carries no `calendar_dates`, so eight of twelve TNDS regions
   had their cancellations applied to the preceding region's services. Bus was
   the worst affected mode. **These archived reports carry that defect**, so
   their bus figures are too low on every weekday in 2018-2023; it was never a
   regression introduced by the metro work.

3. **The NAPTAN join ran after the mode rules.** Introduced by a conversion
   speedup and caught during this rebuild, before publication. It affected
   intermediate builds only, not the figures in these archived reports.

Defects 1 and 2 are both present in the numbers here. Defect 3 is not.

## Provenance

- Outputs behind these reports: `backups/pre_metro_fixes_2026-09-11/`
- Feeds behind those outputs: `backups/gtfs_pre_metro_fixes/` (12 GB, kept
  because reproducing them needs the pre-fix package)
- The old-against-new comparison: `reports/rebuild_comparison_2026-09.md`
