# UK2GTFS conversion report

## Settings

| setting | value |
|---|---|
| path_in | EA.zip |
| uk2gtfs_version | 0.4.2 |
| run_at | 2026-11-20 09:37:56 |
| xml_files | 706 |
| filter_duplicate_files | TRUE |
| filter_date | 2026-11-18 |
| stop_locations | naptan_fill |
| scotland | FALSE |
| bank_holidays | 180 dates, 2013-01-01 to 2028-12-26 |
| naptan_stops | 476258 |
| ncores | 20 |
| try_mode | TRUE |
| force_merge | TRUE |

## Input files

706 files: dropped 1, kept 705.

| decision | rule | reason | files |
|---|---|---|---|
| dropped | 4 | identical period | 1 |
| kept |  |  | 705 |

### Files dropped or changed

| file | lines | operator | decision | rule | reason | by | new_start | new_end |
|---|---|---|---|---|---|---|---|---|
| suf_12-80A-_-y08-1.xml | 80A | CSVC | dropped | 4 | identical period: the older upload of the same registration | suf_12-80A-_-y08-2.xml |  |  |

## Failures

(none)

## Stop locations

| source | stops | calls |
|---|---|---|
| naptan | 12297 | 1397959 |
| none | 51 | 483 |

Stops with source `none` have no position and are removed, with every call at them, by gtfs_clean().

## Later steps

| step | detail | n |
|---|---|---|
| transxchange2gtfs | files converted | 694 |
| transxchange2gtfs | stops without a position | 51 |
| gtfs_deduplicate_copies | pairs of copies | 0 |
| gtfs_clean | stops removed: no coordinates | 51 |
| gtfs_clean | stop_times removed: stop has no location | 483 |
| gtfs_clean | trips removed | 0 |
| gtfs_deduplicate | identical trips removed | 2 |

