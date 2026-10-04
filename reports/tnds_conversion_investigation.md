# Why TNDS is wrong where it is: the raw TransXChange behind the 2026-07-26 snapshot

The zone check in `reports/pdf_validation.md` found 80 route × zone checks
(reliable, counted at the zone) where the pipeline's TNDS count is more than
15% away from the operator's published timetable. This report goes back to
the raw TransXChange those counts were made from, the TNDS snapshot
`data_20260726` in both of its editions (TransXChange 2.1 at the top level,
2.5 in `TNDSV2.5/`), and asks two questions:

1. Does the pipeline + UK2GTFS make a mistake in converting these
   timetables? If so, what is it and how is it fixed?
2. Do the 2.1 and 2.5 files differ, does that explain the wrong counts, and
   would the 2.5 files give better results?

## Short answers

**1. Mostly no, with one exception.** For 72 of the 78 checks that could
be compared (Edinburgh's two could not; see section 4), an independent
count of the raw TransXChange (written from the schema, not from UK2GTFS)
gives the same number as the pipeline, journey for journey. The counts are
wrong because the data are wrong, not because the conversion is. The
exception is a **bug in UK2GTFS's overlap reconciliation**
(`txc_overlap_plan()`, rule 4 of `txc_filter_files()`). When a publisher
splits one timetable across several files that share operator, description,
line, operating period and creation time, the rule treats them as competing
registrations and keeps only one. In Chelmsford this cost X30 more than half
its journeys (pipeline 231, raw 498), and C7, 336 and 333 lost smaller
amounts. Nationally it drops 110 such sibling files, 91 of them live in the
analysis window, with 2,603 vehicle journeys. The fix is a short change,
given below and in `scripts/tnds_investigation/uk2gtfs_overlap_siblings.patch`.

**2. Yes, use 2.5.** The 2.5 edition is the 2.1 edition minus 240 files
(14,449 vehicle journeys); it adds no files and changes none. 178 of the
removed files are still published in another region: they are
**cross-boundary duplicates** that TNDS's own deduplication removes from the
2.5 output only. The pipeline reads the 2.1 files and converts each region on
its own, so nothing downstream can see the second copy. That is the whole
reason TNDS **doubles** the North-east London routes (20, 167, 215, 275, 462:
exactly twice the TfL schedule in 2.1, exactly the schedule in 2.5) and
Stagecoach 125 in Preston (two copies under two operator codes). Switching
to 2.5 fixes all 8 of those checks and changes nothing else in the 80.

2.5 does not fix the other causes, which are in the source data and are the
same in both editions:

| Cause | Checks | Places | Fixed by 2.5? | Fixed by the UK2GTFS patch? |
|---|---:|---|---|---|
| File ends inside the window, no successor published (weekly / fortnightly operator exports) | 34, plus the 4 sibling routes below | Reading, Chelmsford, Weymouth | no | no |
| Cross-region duplicate | 8 | North-east London, Preston | **yes** | no |
| Sibling files dropped by UK2GTFS rule 4 | 4 | Chelmsford X30, C7, 336, 333 | no | **yes** |
| Stale local-authority file, expired by its own "Data Expires" note | 9 | Hull | no | no |
| Stub files that miss the zone | 9 | Crawley (Metrobus) | no | no |
| Old edition, summer timetable missing | 6 | Brighton | no | no |
| Not a TNDS error: two operators share a route number | 4 | Birmingham 50, Black Country 9, 59, 82 | – | – |
| Not a TNDS error: the leaflet reading is doubtful | 2 | Southampton 17, 18 | – | – |
| Unexplained, small | 2 | Aylesbury 4, Birmingham X20 | – | – |
| Mild, within the spread of the other routes in the zone | 2 | Edinburgh 29 (1.19), 47 (0.80) | – | – |

## How this was checked

* The two editions were downloaded from the shared folder: 11 regional zips
  each, plus `log.txt` and `servicereport.csv`.
* `txscan.py` reads the header of every TransXChange file in every zip:
  ServiceCode, lines, operator, OperatingPeriod, CreationDateTime,
  RevisionNumber, SchemaVersion, Description, number of vehicle journeys,
  and any far-future `DaysOfNonOperation` with its note.
* `txc_count.py` is an independent journey counter. It reads TransXChange
  calendars: OperatingPeriod; OperatingProfile from the journey, its pattern
  or its service; RegularDayType; Special Days; Serviced Organisations;
  Bank Holidays. It counts runs at the zone's stops on each date from
  2026-07-27 to 2026-08-23.
* `rawcheck.py` runs that counter, for each of the 80 checks, over every
  file in every region that publishes the route, in both editions.
* `overlap_emulation.py` is a line-for-line Python port of UK2GTFS
  `txc_overlap_plan()`, run over the header scans with and without the
  proposed fix.
* `compare_versions.py` compares the two editions file by file.

All of these are in `scripts/tnds_investigation/`. The raw TNDS data are not
committed.

bustimes.org was used to look at current service, but its `?date=` parameter
only reaches the current week. It cannot show what ran in the July–August
window, so it is not a reference for these counts.

## 1. The conversion

### The pipeline count equals the raw count

| Place | Routes | Pipeline | Raw 2.1 count |
|---|---|---|---|
| Reading | 1, 3, 4, 5, 6, 9, 11, 16, 17, 18, 21, 25, 26, 28, 29, 33 | equal on every route | |
| Weymouth | 1, 2, 4, 8, 10 | equal | |
| Chelmsford | C1, C2, C3, C5, C8, C9, C10, X10, 170, 351, 700 | equal | |
| North-east London | 20, 167, 215, 275, 462 | 2× the TfL schedule | 2× the TfL schedule |
| Preston | 125 | 8,816 / 8,008 | 8,816 / 8,008 |
| Hull | X46 | 834 | 834 |
| Hull | 35, 45, 51, 54, 56, 57, 58, 104 | 0 | 0 |
| Brighton | 12, 14, 18, 25 | equal | |
| Southampton | 17, 18 | equal | |
| Black Country, Birmingham | 9, 50, 59, 82, X20 | equal | |

So UK2GTFS reads these calendars as the schema says, including Serviced
Organisation days, special days and the "expires" non-operation ranges. The
2.5 notation (`principalTimingPoint` for `PTP`, `RegistrationDocument`,
`DynamicDestinationDisplay`) is already handled by
`transxchange_export_functions.R`.

Two small differences are left where the pipeline counts *more* than the
raw files: Aylesbury 4 (1,400 against 884, one file,
`bucks_RLNE_4A_4_1_4_1.xml`) and Brighton 12A (2,512 against 2,400). They
were not pursued; both are minor next to the causes below.

### The bug: rule 4 drops sibling files

`txc_overlap_plan()` groups files by operator + normalised Description +
lines and reconciles overlapping operating periods. It was written for
successive registrations: TfL mints a new ServiceCode at each
re-registration and leaves the old file open. For identical periods it keeps
the most recently created file. For the same start with different ends, it
moves the longer one's start past the shorter one's end.

Some publishers instead split **one** timetable across several files. First
Essex publishes route X30 like this:

| File | ServiceCode | Period | Created | Description | VJs |
|---|---|---|---|---|---:|
| SE_FG_FESX_X30_1.xml | SE_FG_FESX_X30_1 | 26 Jul – 1 Aug | 2026-07-14 06:59:42 | Sweyne Park School | 126 |
| SE_FG_FESX_X30_2_A.xml | SE_FG_FESX_X30_2 | 26 Jul – 1 Aug | 2026-07-14 06:59:42 | Sweyne Park School | 147 |
| SE_FG_FESX_X30_3_A.xml | SE_FG_FESX_X30_3 | 26 Jul – 1 Aug | 2026-07-14 06:59:42 | Sweyne Park School | 12 |
| SE_FG_FESX_X30_4_A.xml | SE_FG_FESX_X30_4 | 26 Jul – 1 Aug | 2026-07-14 06:59:42 | Sweyne Park School | 16 |

The four files have one operator, one description, one line and one period,
so they form one group. Their creation times are equal, so the tie-break
falls to RevisionNumber, which is equal too, and three of the four are
dropped. The description "Sweyne Park School" is a generic export label that
First Essex stamps on unrelated routes, so it doesn't distinguish them. The
files carry different journeys. The same pattern (`_2_A`, `_3_A`, ...) is
Stagecoach's and First's export convention across England, for example
Stagecoach X4 in Cumbria, whose `_1` and `_4_A` files have no departure time
in common.

At the Chelmsford zone:

| Route | Pipeline | Raw (all files) | Raw files |
|---|---:|---:|---|
| X30 | 231 | 498 | X30_1 231, X30_2_A 225, X30_3_A 18, X30_4_A 24 |
| C7 | 171 | 192 | C7_1 171, C7_2_A 21 |
| 336 | 140 | 187 | 336_2_A 140, 336_3_A 47 |
| 333 | 165 | 170 | 333_2_A 165, 333_3_A 5 |

These four are also weekly files (next section), so fixing the bug alone
does not bring them to the timetable.

Nationally, the port of the rule over the 2.1 headers gives these results:

| Region | Files rule 4 drops | With fix | Sibling files restored | Restored and live in window | VJs |
|---|---:|---:|---:|---:|---:|
| SE | 53 | 7 | 46 | 40 | 1,233 |
| NW | 69 | 58 | 11 | 11 | 371 |
| SW | 33 | 7 | 26 | 21 | 246 |
| NE | 8 | 1 | 7 | 6 | 218 |
| EM | 150 | 135 | 15 | 9 | 206 |
| Y | 2 | 0 | 2 | 1 | 185 |
| W | 3 | 0 | 3 | 3 | 144 |
| EA, WM, L | 23 | 23 | 0 | 0 | 0 |
| **All** | **341** | **231** | **110** | **91** | **2,603** |

A further 12 sibling files are truncated by the same-start rule instead of
dropped. Most restored files are school-day variants, so the effect is
concentrated in term time, but it includes whole timetables such as Go North
East X66 (184 VJ) and Stagecoach 84 Chester–Crewe (78 VJ). The fix does not
touch any London file, so the TfL re-registration case that rule 4 was
written for keeps working.

**Fix** (`scripts/tnds_investigation/uk2gtfs_overlap_siblings.patch`,
against itsleeds/UK2GTFS 6824b31). A successor registration is always
written later than the file it replaces. Two files written at the same
instant with different ServiceCodes are parts of one publication, so the
pair is skipped:

```r
          if (max(si, sj) > min(ei, ej)) next          # no overlap

          # Siblings, not registrations. ...
          if (!is.na(meta$CreationDateTime[i]) &&
              !is.na(meta$CreationDateTime[j]) &&
              meta$CreationDateTime[i] == meta$CreationDateTime[j] &&
              meta$ServiceCode[i] != meta$ServiceCode[j]) next
```

A stricter alternative is to drop a file under the identical-period rule
only when its journeys substantially repeat the other file's (for example,
more than half its departure times at the first stop in common). That is
more robust if a publisher stamps every file in a bulk export with one time,
but it needs the journeys read before filtering. The patch has not been run
in R here: R could not be installed in this environment. It is a one-branch
change, and the Python port reproduces the effect.

### The design limit: regions are converted separately

`convert_tnds_snapshot()` converts each regional zip with its own
`txc_filter_files()` pass and then `gtfs_merge()`s the results. A service
published in two regions is therefore never compared with itself. Even a
national pass would not catch the London case reliably, because the TfL
copy (`tfl_60-275-_-y05-60820.xml`) and the Essex copy
(`essex_275_ELBG_PK_275_PK0001938-19_20260228_20260713_040750.xml`) have
different ServiceCodes and descriptions. The right fix is the source's own
deduplication, which is what the 2.5 edition carries (next section).

## 2. TransXChange 2.1 against 2.5

| Region | 2.1 files | 2.5 files | Removed in 2.5 | VJs removed | Removed but still published in another region |
|---|---:|---:|---:|---:|---:|
| EA | 596 | 578 | 18 | 332 | 17 |
| W | 844 | 814 | 30 | 1,128 | 22 |
| NE | 812 | 790 | 22 | 805 | 12 |
| Y | 1,369 | 1,346 | 23 | 1,213 | 22 |
| WM | 1,267 | 1,254 | 13 | 440 | 13 |
| EM | 1,532 | 1,466 | 66 | 4,687 | 55 |
| L | 899 | 899 | 0 | 0 | 0 |
| SW | 2,131 | 2,131 | 0 | 0 | 0 |
| NW | 2,315 | 2,276 | 39 | 2,408 | 13 |
| SE | 2,943 | 2,914 | 29 | 3,436 | 24 |
| **England and Wales** | **14,708** | **14,468** | **240** | **14,449** | **178** |

* **No new files, and no changed content.** Every 2.5 file has a 2.1 file
  of the same name with the same number of vehicle journeys. The
  differences inside are notation: SchemaVersion 2.5,
  `RegistrationDocument="true"`, `principalTimingPoint`, added
  `DynamicDestinationDisplay`.
* **The removals are deduplication.** Both `log.txt` files say "Apply
  Deduplication Cross Boundary: True", but only the 2.5 output has had it
  applied. In the 2.1 output, Essex still carries ELBG's London routes, for
  example `essex_20_ELBG_...`, `essex_167_ELBG_...` and `essex_215_ELBG_...`.
  The 2.1 output also carries within-region repeats, for example Derbyshire
  `derbs_ADER_X38_X38.xml` and `derbs_ADER_X38_X38_1.xml`, 117 VJ each.
  The other 62 removed files were not traced; they include repeats of
  this kind (the TNDS log also mentions a BODS exclude file).

The effect on the checks:

| Check | Timetable | Pipeline (2.1) | Raw 2.1 | Raw 2.5 | BODS |
|---|---:|---:|---:|---:|---:|
| North-east London 275 | 3,920 | 7,840 | 7,840 | **3,920** | 3,960 |
| North-east London 20 | 3,392 | 6,804 | 6,804 | **3,392** | 3,392 |
| North-east London 215 | 2,836 | 5,640 | 5,640 | **2,820** | 2,820 |
| North-east London 462 | 3,204 | 6,408 | 6,408 | **3,204** | 3,204 |
| North-east London 167 | 2,712 | 5,424 | 5,424 | **2,712** | 2,712 |
| Preston 125 (E01024940) | 3,664 | 8,816 | 8,816 | **4,408** | 4,408 |
| Preston 125 (E01033223) | 3,116 | 8,008 | 8,008 | **4,004** | 4,004 |

On 2.5 the London routes match the TfL schedules exactly. Preston 125 falls to
the BODS level; the remaining gap to the leaflet (about 1.2–1.3×) is the
same in both sources, and is not duplication.

**Fix in the pipeline.** Read the 2.5 files when the snapshot has them, and
keep their cache apart from the 2.1 cache:

```r
convert_tnds_snapshot <- function(snapshot, cal, naptan, cfg = load_cfg()) {
  src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
  edition <- ""
  if (dir.exists(file.path(src, "TNDSV2.5"))) {
    src <- file.path(src, "TNDSV2.5")
    edition <- "_v25"
  }
  ...
    cache <- file.path(cfg$gtfs_dir, "cache",
                       paste0("tnds_", snapshot, edition),
                       paste0(region, ".zip"))
```

## 3. What neither edition fixes

### Files that end inside the window

The window runs four weeks from 27 July. The snapshot was built on 22 July,
and several large operators publish TNDS one week (or a fortnight) at a
time:

| Operator | Files | Period |
|---|---|---|
| First Essex (FESX) | SE_FG_FESX_* | 26 Jul – 1 Aug |
| First Dorset (FDOR) | SW_FG_FDOR_* | 26 Jul – 1 Aug |
| Reading Buses (RBUS) | "RDG 200726-020826_SER*.xml" | 20 Jul – 2 Aug |

Nothing after those dates is in the snapshot, so the four-week count holds
about one week of service. That gives the ratios of 0.2–0.3 for all 16
Reading routes, the 11 Chelmsford routes and the 5 Weymouth routes. Within the
covered week the counts are right: for example, Reading 1 is 412 against a
timetable of 1,648 over four weeks, exactly a quarter.

Across England and Wales, 326 live files (30,652 VJ, 2.7% of all live VJ)
end inside the window with no later file for the same operator and line.
The largest are RBUS (6,186), Stagecoach South (4,641), FESX (3,774), East
Yorkshire (3,471, the expired files below) and FDOR (2,873).

There is no conversion fix for this; the journeys are not in the source.
There are two ways to stop it reading as a service cut:

* Measure frequency over the dates the snapshot actually covers. For
  example, average the first full week after the snapshot (27 Jul – 2 Aug)
  and scale it to four weeks.
* Roll a service forward: when a service's last file ends inside the window
  and nothing replaces it, repeat its last week. This is what a passenger
  would expect of a weekly export, but it invents data, so it should be
  flagged.

`window_expiry_stats()` already measures the effect. These numbers say it is
concentrated in a handful of operators, which makes a per-operator flag
practical.

### Hull: stale local-authority files

The East Yorkshire routes in Hull (35, 45, 51, 54, 56, 57, 58, 104) come
from the Yorkshire local-authority export, for example `SVRYHBO057.xml`,
created 2025-09-15. Every journey in these files has
`DaysOfNonOperation` 2025-12-15 → 2099-01-01 with the note "Data Expires
Three Months From Export Date". UK2GTFS honours that correctly, so the files
run nothing in 2026. X46 (`SVRYEDX046.xml`) expires on 13 August, inside the
window, which gives 834 against 1,240. In the Yorkshire region, 13 files of
this kind expired before the window and 77 expire inside it. BODS has the
current East Yorkshire data and matches the leaflets.

### Crawley: Metrobus stubs

The TNDS Metrobus files (`square_METR_*`) are stubs. Route 10, for example,
has 165 VJ against 989 in BODS, has no `Frequency` elements, and does not
serve the zone's stops at all. Both editions count 0. BODS matches the
leaflets.

### Brighton: old edition

The `square_BHBC_*` files start in April 2026 and do not carry the summer
timetable. Routes 12, 12A and 14 read about 0.6–0.7 of the leaflet, and
route 20 is absent. Route 25 reads 1.23× and route 18 2.1× the leaflet.
The 18 leaflet reading looks wrong, and BODS has no 18 at the zone to
compare with.

## 4. Checks that are not TNDS errors

* **Route numbers shared by two operators.** In Birmingham city centre, 50 is
  run by both Diamond (`cen_18-50-T`, 2,800) and National Express West
  Midlands (`cen_33-50-Y`, 8,688). In the Black Country, 59, 9 and 82 also
  have a second operator. The leaflet is one operator's. On the NXWM file
  alone:

  | Route | NXWM file | Leaflet |
  |---|---:|---:|
  | 82 | 1,268 | 1,268 |
  | 59 | 3,624 | 3,488 |
  | 9 | 1,592 | 1,452 |

  These are artefacts of the zone check, which counts by route number, and
  should be removed from the TNDS error tally.
* **Southampton 17 and 18.** The TNDS files are sequential (17: `-y10-1`
  to 31 July, then `-y10-2`), not duplicated. At the zone they have a bus
  about every 10 minutes **each way**: 17 has 89 inbound and 89 outbound a
  weekday, and 18 has 94 and 93. The leaflet counts (17: 98, 18: 68 a
  weekday) and BODS (about 100 a weekday) are close to one direction's
  worth. The 18 leaflet is also a temporary edition for the Bargate Street
  closure (7 Nov 2025 – 9 Jan 2026), read at a proxy stop. The TNDS count
  is credible; the checks are not.
* **Edinburgh 29 and 47.** Each has one Lothian file in the window, with no
  copy in either edition or any other region. Every one of their journeys
  that reaches the zone calls at two of its stops, one per direction. The
  stop list used for the raw count holds only one direction's stops, so it
  counts half (47: 1,144; 29: 1,316), the same as BODS. The pipeline counts
  both directions. Its ratios (0.80, 1.19) are within the spread of the
  other Edinburgh routes checked in the same zones (0.95–1.11), so they
  were not pursued.
* **Birmingham X20** (1,528 against 1,936) is one NXWM file with no
  duplicate and no truncation; it was not pursued.

## Recommendations

1. **Convert the `TNDSV2.5` files.** This fixes every duplicated count found
   here, at no cost: the 2.5 edition loses nothing that is not published
   elsewhere or repeated.
2. **Apply the UK2GTFS sibling patch.** This recovers about 2,600 VJ in 91
   files nationally, Chelmsford X30 among them.
3. **Report, rather than hide, the short-horizon files.** Flag services whose
   last file ends inside the window (RBUS, FESX, FDOR, Stagecoach South and
   the expiring Yorkshire LA files) and measure them over the covered dates.
   Alternatively, use BODS for those operators, which publishes the full
   period.
4. **Drop the shared-route-number checks** (Birmingham 50, Black Country 9,
   59, 82) and **Southampton 17, 18** from the TNDS error tally in
   `pdf_validation.md`, or count them per operator.
