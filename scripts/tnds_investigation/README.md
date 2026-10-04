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
