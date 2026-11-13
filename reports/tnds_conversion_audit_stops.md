# Where TNDS misses the timetable: conversion or data?

The stop-level section of `pdf_validation.md` sets 109 routes through the case
stops of `stop_disagreement.md` against operators' own timetables. TNDS misses
the document by more than 15% on 61 of them, over the window or on the single
day. This report takes those 61 back to the raw TransXChange in the TNDS
snapshot the pipeline converts (`data_20260726/TNDSV2.5`) and asks, for each,
whether UK2GTFS lost or invented journeys, or converted faithfully a file that
was itself wrong. It then measures nationally the one place where the
conversion does go wrong, and proposes fixes to UK2GTFS, which are written and
tested but not yet installed or rebuilt.

It follows `tnds_conversion_investigation.md` (the zone checks, October 2026),
which found one converter bug, sibling files split from one export, since
fixed. The method is the same.

*Scripts: `scripts/tnds_conversion_audit/`. `txcday.py` counts the journeys a
raw TransXChange file runs on a date, written from the schema rather than from
UK2GTFS; `raw_counts.py` and `feed_counts.R` set raw and converted counts side
by side by route and date; `filter_actions.R`, `lost_journeys.py` and
`classify_losses.py` measure what `txc_filter_files()` removes nationally.*

## Short answer

**The conversion is faithful for every one of the 61 routes except two.** For
each, the raw files and the converted feed give the same journeys on every
date of the window, to the journey. The misses are in the data: timetables
TNDS does not have, has in an old edition, has in weekly blocks that stop
inside the window, or holds in a form the publisher got wrong. A timetable
cannot be fixed in a converter that does not have it.

**The two exceptions are both `txc_filter_files()`**, the step that decides
which of several files describing one service to keep: Chelmsford's 371 lost a
week and the 3 lost half its weekday journeys. Measured over the whole
snapshot, the same step deletes **13,969 journeys in the 14-day window that
nothing replaces**, through four distinct defects. That is 0.30% of TNDS's
4.72 million, but it falls on whole lines: Arriva's Rhyl–Llandudno 12 (2,076
journeys), Metrolink's replacement buses (about 6,100), Stirling University's
summer timetable (1,182). The proposed fixes cut it to 1,642, drop nothing the
current filter keeps, and pass the UK2GTFS test suite.

## 1. The 61 routes, raw against converted

Counted for every date 27 July–9 August, raw (`txcday.py`) against the
pipeline's TNDS feed. "Raw = feed" means equal on every date.

| What TNDS shows | Routes | Raw = feed? | Cause |
|---|---|---|---|
| Absent: Metrobus 10, 100, 200 (Gatwick) | 3 | yes | Every journey in the three TNDS files is `HolidaysOnly`: they run on bank holidays and nothing else. A publishing fault (the "square" exporter); BODS has them right. |
| Absent: East Yorkshire 56, 57 (Hull) | 2 | yes | The files carry `DaysOfNonOperation` from 15 Dec 2025 to 2099, noted "Data Expires Three Months From Export Date". Already in `source_disagreement_investigation.md`. |
| Absent: Brighton & Hove 20 | 1 | yes | No file for the 20 in TNDS. |
| Absent: First Essex 42A | 1 | yes | Sunday-only; not in TNDS. |
| Half over the window, right on the day: First Essex C-routes, 700, 702, X10, 13, 13B, 331, 351, 47, 73B (Chelmsford, Stansted) | 18 | yes | TNDS has First Essex in **weekly** files (`SE_FG_FESX_C1_2_A`: 26 Jul–1 Aug); nothing after 1 August. The known TNDS horizon problem. |
| Short on the day: First Essex 31, 333, 336, 3, 13A, 332, 73, C1, C7E, X30 | 10 | yes, except the 3 | Same weekly files, and later (31 August) documents. The **3** is a filter fault: raw 12 a weekday, feed 6 (§2). |
| Short on the day: First Essex 371 | 1 | **no** | Raw 48 a weekday in week one, feed 1 (§2). |
| Short: Brighton & Hove 12, 14, 12A | 3 | yes | TNDS holds the 13 April 2026 registrations; the documents are the 19 July editions. TNDS never got the summer timetable. |
| High: Brighton & Hove 18 | 1 | yes | The 2025 document read at Churchill Square prints one direction there; a reading limit, not a feed fault. |
| High over the window, right on the day: Arriva SB1, SB2, SB3, SB5 (Stevenage) | 4 | feed *lower* | The raw file carries the full Monday–Friday timetable **and**, from 28 June, a second Wednesday–Friday set re-timing most of the same journeys (156 of them, 40 at the same minute). UK2GTFS's `gtfs_deduplicate()` already removes the exact copies (raw 273 on a Wednesday, feed 189); the near copies remain. A publishing fault. |
| High: Arriva 55 (Stevenage), Stagecoach Hull 14 | 2 | yes | Later documents (November, September). |
| Short: NXWM 2, 3, 17A, X20, X21, 5A; Stagecoach Hull 111, 12A, 33C; South Pennine SC2 | 10 | yes | November or later documents; the July TNDS files are the operators' July registrations. |
| High: NXWM 50, 81 | 2 | yes | The 81 is two operators (NXWM and Banga) and the document is NXWM's alone; the 50 likewise has a Diamond 50 alongside. Matching, not conversion. |
| Gatwick Hoppa GH1, GH2 | 2 | yes | TNDS still carries the GH2, registered May 2025, which the operator says it withdrew in May 2026. |
| Stagecoach Hull 11, 8 | 2 | yes | Later documents; the 8 needed `txcday.py` to read organisation calendars that list only working days, after which it matched the feed exactly (178 on a weekday). UK2GTFS was right. |

So the converter is faithful wherever TNDS has the timetable. The pattern
`source_disagreement_investigation.md` found at zone level holds at stop
level: **TNDS is wrong where its data are wrong**: no forward horizon, stale
or missing registrations, publisher faults. What a converter can do about those
is detect and report them (proposal 5).

## 2. The filter: what `txc_filter_files()` removes, nationally

TNDS often holds several files for one service: re-uploads, successor
registrations, weekly blocks, a timetable split across files.
`txc_filter_files()` keeps one version of each, and rewrites operating periods
where registrations overlap. To measure what it gets wrong, the installed
filter was run on all 17,122 files exactly as the pipeline runs it, and every
journey it removes from the window was looked for among the files it keeps
(same line, same first stop, same date, within 3 minutes). A journey not found
there, on a line where the kept files run less than 80% of what the removed
file did, is **lost**, not re-timed.

| Defect | Files | Journeys lost (window) | Example |
|---|---|---|---|
| **A. Rule 2 is blind to lines** | 10 | 4,316 | Arriva Cymru registers lines 12 and X12 under one ServiceCode, `12/X12`, in two files starting 7 and 8 June. Rule 2 keeps "the latest start per ServiceCode": the 16-journey X12 file, and line 12 (453 journeys, Rhyl–Llandudno) is deleted as superseded. Also 2, 4, 11M, 15, G8C in North Wales. |
| **B. Rule 4 merges siblings from different exports** | 13 | 6,638 | Siblings are files that divide one timetable between them. First Essex's 371 is `371_1` (one journey a day, exported 14 July) and `371_4` (the rest, exported 7 July). The October fix recognises siblings only by an identical creation time, so these are treated as competing registrations, and "same start, different end" moves `371_4` to start 2 August. Metrolink's replacement-bus files and First Cymru's X5 are the same. |
| **C. Rule 1 merges siblings within one export** | 1 | 1,182 | Stirling's line UL: two files, same code, line, period and weekdays, created 41 ms apart. One runs on the university's working days, the other on every other day, and the summer timetable was deleted as a repeated upload. |
| D. Other same-code duplicates | 10 | 1,833 | Mostly North Wales and Scottish files not yet explained (§4). |
| **Total** | **34** | **13,969** | 0.30% of TNDS's 4,723,029 journeys in the window |

Most of what the filter removes is right. It drops 807 files, carrying 110,843
journeys in the window, and 82,328 of those are found again in a kept file:
the superseded copies it exists to remove.

## 3. Proposed fixes to UK2GTFS

All in `R/txc_filter_files.R`, uncommitted in the UK2GTFS checkout, each with a
regression test in `tests/testthat/test_txc_filter.R` (68 filter tests, full
suite passes).

1. **Rule 2 per line and day set** (A). The operative version is chosen for
   each line and day type, as rule 1 already does, and a file is kept if it is
   the operative version of any of its lines.
2. **Journeys decide whether two files are siblings or versions** (B, C).
   A successor registration repeats most of its predecessor's journeys; a
   sibling repeats almost none. New `txc_journey_keys()` reads each
   journey's first stop and departure minute, and `txc_journey_share()`
   gives the share of the smaller file found in the other within 3 minutes.
   Rule 1 drops a duplicate, and rule 4 truncates or drops a file, only where
   the share is at least 0.5. Journeys are read only for files in a contested
   pair. A file whose journeys cannot be read is treated as before.
3. **Term and outside-term calendars are different days** (C). The day set
   each file is compared on now includes which side of a
   `ServicedOrganisation` calendar it runs on. Rule 4 treats files on opposite
   sides as disjoint. Without this, a dense term timetable "matches" a sparse
   holiday one on times alone (Stirling's pair shares 99%).

**Measured effect, July 2026 snapshot, edited source against installed:**

| | Installed | Proposed |
|---|---|---|
| Files dropped | 778 | 532 |
| Files truncated | 29 | 18 |
| Journeys removed in window | 110,843 | 95,103 |
| … of which **lost** | **13,969** | **1,642** |
| Files the current filter keeps that the proposal drops | – | **0** |

257 files come back, carrying 15,740 journeys in the window. Only 111 of
those journeys match a journey already kept, so the rescued files add at most
about 0.7% of their volume as duplication. Of the remainder, `gtfs_deduplicate()`
removes the exact copies anyway.

4. **Not yet fixed: what is left (1,642 journeys).** Two TfL night routes
   (N74, N97) truncated by rule 4; Arriva Cymru 27 and 35, where the dropped
   file runs school-day journeys under eight separate `ServicedOrganisation`s;
   Peter's Travel 343 in Scotland; a Yorkshire M4. Each needs reading
   individually.
5. **Proposed, not written: report what cannot be fixed.** Several of the
   data faults in §1 are machine-detectable, and UK2GTFS could warn on them
   rather than convert silently:
   * a file in which every journey is `HolidaysOnly` (Metrobus);
   * a `DaysOfNonOperation` range running into the far future (East
     Yorkshire's "Data Expires");
   * a service whose last date falls inside a short window, with no successor
     (First Essex's weekly files);
   * a file carrying two overlapping day types with mostly re-timed journeys
     (Stevenage).

   A warning per file, collected by `txc_filter_files()` or
   `transxchange2gtfs()`, would have flagged all four.

## 4. What this does not settle

* Most documents in the stop check are **later editions** (`pdf_validation.md`
  says which). Where raw equals feed this does not matter: the converter is
  faithful whatever the right answer was. It does mean the ratios in §1 are not
  measurements of TNDS against the July timetable.
* "Lost" relies on the 3-minute match and the 80% line test. A journey
  re-timed by more than 3 minutes on a line that also shrank would be counted
  lost. The examples in §2 were checked by hand.
* The fixes change what the pipeline converts. Reaching the outputs needs
  UK2GTFS reinstalled (back up `extdata` first, see the `.Rprofile` note) and
  the TNDS conversion caches deleted, since the cache does not see package
  changes. Nothing has been reinstalled or rebuilt.
