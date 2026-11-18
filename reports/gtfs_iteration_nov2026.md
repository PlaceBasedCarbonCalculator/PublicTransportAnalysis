# Towards a definitive GTFS: errors found, fixed and still open (November 2026)

This continues `tnds_conversion_audit_stops.md`. That report found the
TNDS conversion faithful except for `txc_filter_files()`, proposed three
fixes, and measured them. Those fixes are now in UK2GTFS (`d557efe`,
installed 13 November 2026). This round asked four further questions:

1. Why do services run out early in TNDS and not in BODS?
2. Which further bugs does UK2GTFS have, and what does fixing them change?
3. Where is the DfT's BODS GTFS wrong, and why?
4. Can a combination of sources get closer to the published timetables than
   any one of them?

The evidence is the same as before: operators' own published timetables,
read at named timing points (`data/stop_pdf_documents.csv`), set against
each feed at the same place, and the raw TransXChange behind every feed.
A second snapshot is added. The July 2026 check could not judge most
documents, because they are October or November editions; the November
2026 snapshots (TNDS, BODS GTFS and the BODS TransXChange archive, all
11 November) are counted over 16-29 November, the fortnight those documents
are in force for.

*Scripts: `scripts/tnds_conversion_audit/`. New this round: `txc_index.py`
(one row per raw TransXChange file in a TNDS snapshot or BODS archive:
operator, lines, period, creation date, journeys, mode; written to
`data/txc_index/`), `horizon.py`, `coverage.py`, `compare_actions.py` (two
filter runs side by side, with the duplication each change puts back),
`mode_compare.py`, `no_profile.py`.*

## Short answer

* **Services run out early only in TNDS because TNDS is a derived extract.**
  Operators publish to BODS mostly open-ended; TNDS re-issues the same
  timetables in dated blocks and lags BODS by weeks. In July 2026 173 lines
  ran out inside the window in TNDS only, 9 in BODS only. In November, 4.
* **UK2GTFS had eight more faults**, all fixed and tested: five in the
  filter that chooses between files, one of them new (a route passing to
  another operator was run twice), and three in conversion (passing stops,
  "no operating profile", "bookable" notes). Two of the fixes broke
  something on the way and the checks caught both before they were kept.
* **The DfT's BODS GTFS is the least accurate of the three feeds** in
  November: within 15% of the operator's timetable on 34 of 78 readings,
  against 54 for TNDS and 51 for UK2GTFS's conversion of the same BODS
  data. It runs the West Midlands network two to three times over, doubles
  weekends on First South Yorkshire, and gives the Glasgow Subway,
  heritage railways and the DLR the wrong mode.
* **A combination helps, but only service by service**: each source has
  services the other lacks or has out of date. The gain at the case stops
  is one reading; §5 sets out how to build it.

## 1. Why services run out early in TNDS

Every operator and line live in the window in both raw sources, July 2026:

| | Lines |
|---|---|
| In both sources, live in the window | 8,593 |
| Run out inside the window in TNDS only | **173** |
| Run out inside the window in BODS only | 9 |
| Run out in both | 7 |

"Runs out" means the last date any of the line's files covers falls inside
the 14-day window. Two mechanisms, and neither is the converter:

* **TNDS re-issues open-ended timetables in short blocks.** 63% of BODS
  files carry no end date, against 31% of TNDS files. First Essex, First
  Bristol, First Dorset, Metrobus, Transdev and others publish to BODS
  open-ended, and TNDS holds the same timetables as dated blocks, many a
  week long (`SE_FG_FESX_C1_2_A`: 26 July to 1 August), with no block after
  the last. First Essex alone accounts for 39 lines, First Bristol 22 and
  First Dorset 18.
* **TNDS lags.** Reading Buses and Newbury & District publish five-week
  blocks to both. In July, BODS already held the next block (to 31 August,
  uploaded 21 and 24 July); TNDS's newest Reading files were created
  20 May and stop on 2 August. 77 lines between the two operators.

That is why only TNDS shows it: BODS is the operators' live upload, mostly
open-ended, and TNDS is a derived extract with dated blocks and a lag.

**It varies from snapshot to snapshot.** In November the same comparison
finds 4 lines running out early in TNDS only, out of 8,670 (two Go North
East lines, Stagecoach North East 836, MOVP 33). The July snapshot was a bad one. Any series
built on TNDS snapshots inherits a decay that differs from year to year,
which `source_disagreement_investigation.md` measured at 3-10%.

## 2. UK2GTFS: what was wrong, and what fixing it did

### 2.1 The filter, third round

`tnds_conversion_audit_stops.md` left 1,642 journeys lost in the July window
on six lines. Each was traced to the raw files:

| Route | What the files are | Rule that removed it | Fix |
|---|---|---|---|
| Arriva Cymru 35, 27, 5, 14 | One file per depot, same ServiceCode, line and days, both open into 2027 | Rule 2 kept "the latest start" and dropped the other depot's journeys (share of journeys repeated: 0) | Rule 2 drops an earlier version only if the operative one repeats its journeys |
| East Yorkshire M4 | Two variants exported nine seconds apart | Rule 2, as above (share 0) | As above |
| Peter's Travel 343 | A weekday file and a mostly-Saturday file at the same times | Rule 4 saw 95% of journeys "repeated" | Journeys match only on a shared day of the week |
| TfL N97, N74 | An every-night file and a Saturday-only file, same start, different ends | Rule 4 "same start, different end" stood the every-night file down until December | A shorter file stands in for a longer one only if it runs on every day the longer one does within its own period |

Two intermediate versions failed the national check, and the failures shaped
the final rules:

* Requiring the shorter file to cover the longer one's days *across the
  week* stopped TfL's one-weekend engineering-works overlays from
  replacing the District line's whole-week file, and put back 8,076
  duplicate journeys. The test now looks only at the weekdays inside the
  shorter file's own period.
* Matching journeys on days made a re-timed successor on a frequent route
  look like a sibling: TfL's 195, re-timed from every 21 to every 22
  minutes, repeats only 47% of its journeys within three minutes on the
  same days, and both copies survived (1,026 duplicates). Lowering the
  threshold to a quarter fixed that, but dropped Metrolink's
  replacement-bus files and Compass's 100, which overlap 28-42% and are
  genuinely different services (1,056 journeys lost). What separates them
  is the journey count: a re-timed successor keeps it (433 against 418),
  overlapping siblings do not (439 against 531; 53 against 43). Between a
  quarter and a half of the journeys, files are now versions only when
  their counts are within a tenth of each other (`txc_versions()`).

**Measured on the whole July 2026 snapshot, against the filter as installed
from `d557efe`:**

| | |
|---|---|
| Files whose outcome changes | 25 |
| Files the installed filter keeps that the new one drops | 2, carrying **no** journeys in the window |
| Window journeys put back | **3,365** |
| ... of which duplicate a journey already kept | 484 (one Metrolink replacement-bus file, half new service and half overlap, which a file-level filter cannot split) |
| Window journeys removed with nothing in their place | 11,934 → **9,053** |

Most of the 9,053 are TfL successor registrations re-timed by more than
three minutes, where removing the old file is right; the 3-minute match
calls them "not replaced". Eight new tests in `test_txc_filter.R`; the full
UK2GTFS suite passes (315 tests).

### 2.2 A route that changes operator

The filter keyed every reconciliation on the operator, so when a route
passes to another operator and the outgoing operator's open-ended files
stay published, both are counted. On 1 November 2026 NXWM's routes passed to
West Midlands Bus Limited (§3.2); in UK2GTFS's conversion of the November
BODS archive route 74 then runs 896 journeys on Tuesday 17 November, 448
under each operator, for the 448 actually run.

New rule (end of `txc_overlap_plan()`): a file is closed the day before
another operator's file starts where the two publish the same lines, serve
at least half the same stops (taken from the file's own stop list, so
journeys are read only for real candidates), run on the same days, are
versions of one timetable by the journey test of §2.1, **and** at least
half the outgoing file's journeys reappear in the incoming one. The last
condition is directional on purpose: First Potteries' 35-journey route 9
sits inside D&G's 130-journey route 9 (97% of First's journeys are at D&G's
times), and without it D&G's file was closed in favour of First's.

| | TNDS July 2026 | BODS November 2026 |
|---|---|---|
| Files the rule closes | 11 | 204 |
| ... NXWM → West Midlands Bus | - | 127 |
| ... National Express Coventry → West Midlands Bus | - | 17 |
| ... others | 11 (Ambassador → Konect in Norfolk, Bee Network contract moves, Compass → Stagecoach, Stagecoach Cumbria 2, RAMB → LEMN 361, Stagecoach South West 66) | 60 (Bee Network contracts, Arriva North East → Arriva Scotland, Nottingham City → Kinchbus and others) |

Every closure was listed with the file that took over and checked by hand.
Eleven run backwards: West Midlands Bus published copies of some routes
backdated to 30 August, NXWM versions of them start 2 September, so those
routes pass back to NXWM. Each journey is still counted once, under the
outgoing operator's name. Four tests in `test_txc_filter.R`, including that
the same line number in another town and two operators sharing a route at
different times are left alone.

### 2.3 Three conversion bugs

Both were found because a BODS file failed or converted to nothing:

* **`clean_pass()` blanked every link it did not remove.** It dropped
  passing points with `jps[jps$To.Activity != "pass", ]`. An unstated
  activity is NA, and indexing rows with NA turns them into rows of NA, so
  a file that marks only its passes lost every other link and failed to
  convert: Tanat Valley's X81 ("subscript out of bounds"). Also fixed: a run
  of consecutive passes now carries all their running times, not just the
  last one's, and the merged link starts where the first removed link did,
  so the stop sequence still chains.
* **`clean_days()` turned "no operating profile" into "never runs".** A
  file with no OperatingProfile on any journey, pattern or service gives
  an empty day pattern; `strsplit("")` is empty and `all()` of an empty test
  is TRUE, so it fell into the named-days branch and came out as zero days,
  never reaching the branch that already meant "every day". Eight BODS
  files in November (219 journeys: TfL 411, 216, 635, 626, the X81, two
  Grindles Coaches files), none in TNDS. BODS GTFS runs them every day too.
  Two of the TfL routes look like school routes, for which every day
  overstates; the file gives nothing better.

  **The first version of this fix introduced an error, caught by the
  November check.** The import read a service's days as the first
  `DaysOfWeek` anywhere under it, so a service whose profile is
  `<HolidaysOnly/>` also came out as an empty pattern, which the old bug
  had turned into "no days" (right, by accident) and the fix turned into
  "every day". Arriva North East's route 43 publishes its bank-holiday
  timetable that way, and UK2GTFS's count of its routes rose by half
  overnight (route 43 at Durham: 618 → 989 a week against a timetable of
  672). In the November BODS archive 188 files (3,437 journeys) have such a
  service profile, in TNDS 4. `import_services()` now reads the service's
  own profile: `HolidaysOnly`, or a profile without regular days, has no
  regular weekdays; only a service with no profile at all is every day.

* **"Bookable" removed scheduled services.** `transxchange_export()` drops
  any journey with a note containing "book", meaning to leave out services
  that run only on demand. In the November TNDS snapshot that removes
  14,765 journeys and empties 123 files. Most are not demand responsive:
  Ember's express coaches carry "Pre-book online" on every journey (11,680),
  Orkney Ferries and others note that foot passengers must book, and some
  journeys are dropped because one request stop "can be served but only by
  request to driver or by pre-booking". New `bookable_note()` leaves a
  journey out only where the note makes the journey itself depend on
  booking ("Demand responsive service", "Journeys must be booked",
  "Must be booked at least one hour before departure"), and is never wider
  than the old test: a note that does not mention booking at all leaves the
  journey in (a first version dropped Felixstowe's foot ferry, whose note
  says "actual journey times will vary on demand"). About 12,250 journeys
  come back and about 2,500 genuinely demand-responsive ones stay out. Orkney Ferries' OF2, every journey "Must be booked at least one hour
  before departure", stays out, which is the intended reading of a
  run-on-request ferry. The BODS archive is barely affected (6 journeys).

All three have tests in `test_bug_fixes.R`.

### 2.4 What was not a converter fault

A South Dorset Coaches file in the November BODS archive is not well-formed
XML (an unescaped `&`) and is skipped. The faults listed in
`tnds_conversion_audit_stops.md` §1 (Metrobus's holidays-only files, East
Yorkshire's "Data Expires" calendar, First Essex's weekly blocks, the
Stevenage re-timed overlay) are in the data.

## 3. Where the DfT's BODS GTFS is wrong

### 3.1 Journeys counted twice where versions are not closed

NXWM publishes each timetable change as a new file and leaves the previous
one open-ended. In November its BODS dataset holds, for route 74, versions
starting 30 August and 25 October, both open; for route 6, three. Read
literally, every version runs forever. In July, against NXWM's own
timetables in force, BODS GTFS carried **2.21×** the 6, **2.03×** the 14 and
**1.79×** the 74, where TNDS carried 1.06, 1.09 and 1.00. The DfT's
converter does not close an earlier version when a later one starts;
UK2GTFS's filter does (rules 2-4).

### 3.2 An operator change counted twice

From 1 November 2026 NXWM's routes are run by **West Midlands Bus Limited**
(NOC WMBL, licence PD2093720). The new operator's dataset carries the same
routes under the same local registration numbers (route 74 is
`PD0001111_43010081` under NXWM, `PD2093720_43010081` under WMBL), and
NXWM's open-ended files are still in BODS. TNDS carries only the new
operator from 1 November. Journeys on Tuesday 17 November:

| Route | BODS GTFS: NXWM + WMBL | UK2GTFS from BODS TXC (before §2.2) | Real |
|---|---|---|---|
| 74 | 448 + 896 = **1,344** | 448 + 448 = 896 | 448 |
| 50 | 361 + 722 = **1,083** | 361 + 381 = 742 | about 380 |
| 14 | 236 + 608 = **844** | 304 | about 300 |
| 6 | 586 + 1,356 = **1,942** | 368 + 678 = 1,046 | about 680 |

BODS GTFS counts these routes about three times: the outgoing operator's
files, and within the new operator's dataset both its 1 November and its
15 November versions (open-ended, never closed). "Real" is the new
operator's current version alone, which TNDS also carries.

### 3.3 Services BODS does not have

* **Brighton & Hove 50, 18 and 12A** are absent from the operator's BODS
  dataset in July and November; TNDS has all three, and the published
  timetables confirm them.
* **Nottingham Express Transit** (1,941 journeys a fortnight in TNDS) is in
  neither BODS archive nor BODS GTFS.
* **Heritage railways**: Romney Hythe & Dymchurch, Spa Valley, Swanage and
  Dartmouth Steam are in TNDS and not in BODS GTFS.
* **Ember** (Scottish express coach) is not in the BODS Coach dataset, which
  is this pipeline's coach source from 2024, and the pipeline drops TNDS's
  coach routes in those years (`year_sources()`), so Ember is absent from
  the published coach series. TNDS has it, and with the `bookable_note()`
  fix (§2.3) UK2GTFS now converts it.
* **Scotland, Wales and London** are largely absent from the BODS
  TransXChange archive (in November TNDS has 4,185 live operator-lines BODS
  lacks: 1,504 Scottish, 696 London, 479 Welsh; some of the rest are the
  same lines under another operator code, such as NXWM's `OC:WMB` in TNDS
  against `WMBL` in BODS); the DfT fills these into
  BODS GTFS from TNDS.

### 3.4 Wrong mode for a right service

Route by route, matched on the stops each serves (`mode_compare.py`, July
2026):

| Service | BODS GTFS | TNDS (as converted) |
|---|---|---|
| Glasgow Subway | tram (0) | metro |
| Docklands Light Railway | rail (2) | metro |
| Bo'ness & Kinneil, Strathspey, Keith & Dufftown, Leadhills & Wanlockhead railways | tram (0) | rail |

The times and stops agree; only the route type differs. A mode-by-mode
analysis taking non-bus modes from BODS GTFS would count four heritage
steam railways as trams and the Subway as a tram line. National coach
routes are absent from TNDS since NCSD was withdrawn, so their mode cannot
be cross-checked this way.

## 4. The November check: three feeds against the timetables

Target `stop_pdf_nov` (`R/stop_pdf_validation.R`, `stop_check_snapshot_nov()`):
the same case stops and readings as the July check, counted over
16-29 November and on Tuesday 17 November in three feeds: TNDS 11 November
and the BODS TransXChange archive of the same day, both converted by
UK2GTFS as it now stands, and the DfT's BODS GTFS as published. Which
edition is in force is re-decided for the window (`stop_doc_status()`):
the latest edition dated on or before 16 November is in force if it was
collected within 60 days of the window, unless a newer edition is held on
disk. Go-Ahead's archive was re-listed on 14 November for this, which
added Brighton & Hove's 27 September 12 (it prints its stops as graphics
and could not be read) and East Yorkshire's 6 September 56/57 (images
only; counted by eye from the rendered pages, 83/72/50 and 86/73/53 a day
at Hull Interchange).

**Two document problems were found and handled, not scored:**

* West Midlands Bus's November sheets for routes 2, 3, 4, 5, 17, 17A and 35
  print every journey twice: pairs of columns leaving the same stop at the
  same minute, differing in a stop or two (route 17A: two journeys from
  Birmingham International at 04:47). TNDS and UK2GTFS's BODS feed each run
  one 04:47; the DfT's BODS GTFS runs three. The sheets look generated from
  the operator's own data with both its 1 and 15 November versions in
  force, which is the doubling of §3.2. All three feeds read about half of
  them. They are marked unreliable (`PRINTED_TWICE` in `read_docs.py`).
* Two reads of the documents during the rebuild returned no edition date
  for First Essex's 332 and 46 because `pdftotext` failed under load; a
  rerun read them correctly.

**Result, 78 readings whose timetable is in force:**

| Feed | Within 15%, fortnight | Within 15%, Tuesday | Route absent | Over 1.5× | Median error |
|---|---|---|---|---|---|
| TNDS (UK2GTFS) | **54** | **54** | 2 | 3 | 7.4% |
| BODS TransXChange (UK2GTFS) | 51 | 52 | 6 | **1** | 7.6% |
| BODS GTFS (DfT) | 34 | 36 | 6 | 21 | 26% |

| Which feeds are right | Readings | Routes |
|---|---|---|
| All three | 33 | First Essex C-routes, 13, 351, 371, 700, 702, X10; Stagecoach Hull 12-40; East Yorkshire 56, 57; Brighton 14; Go North East Q3X; Metrobus 200 |
| TNDS and UK2GTFS-BODS, not the DfT's GTFS | 16 | West Midlands Bus 1, 11, 11A, 23, 24, 50, 74, 87, 94, 95, 97, 97A, 126, X20 (DfT 1.9-3.0×); First South Yorkshire 207, 73 (DfT 1.5-1.7× over the fortnight, right on the Tuesday: weekends doubled) |
| TNDS only | 5 | Brighton 50, Sheffield 181, SC1 (absent from BODS); West Midlands Bus X21, X22 (UK2GTFS-BODS 0.70-0.74, unexplained) |
| A BODS feed only | 2 | Brighton 20 (absent from TNDS); Gatwick Hoppa GH2, withdrawn in May, still in TNDS and the DfT's GTFS, rightly absent from UK2GTFS-BODS |
| None | 22 | see below |

Of the 22 that no feed gets right, **15 have all three feeds agreeing with
each other** (First Essex 3, 13A, 31, 46, 73, 332, 333, C7E, X30; Stagecoach
Hull 11, 12A, 33C, 111; Brighton 25; Metrobus 100 except that UK2GTFS-BODS
is closer at 1.16). Three independent routes to the same number make a
converter fault unlikely there; either the reading or the operators'
upstream data is wrong, and the sheets are not consistent enough to say
which. Brighton 12A (all three absent: Brighton's BODS dataset has no 12A
and TNDS's file does not run in November) and 18 (a one-direction reading)
are reading or data limits. The NXWM-period West Midlands documents for 5A,
6, 81 and 82 disagree with all three.

**What each fix did in November**, UK2GTFS's BODS feed within 15% of the
in-force timetables: 48 (round 3) → 51 (round 4, operator handover; the
West Midlands routes 50, 6, 74, 97, 97A, 8 and X8 move from 1.4-2.2× to
TNDS's figures). The holidays-only fix of round 5 corrected a regression
of round 4 (Arriva North East's routes back from about 1.5× to 0.92 of
their timetables) on readings that are not in force over the window, so
it does not move the table. TNDS is unchanged at the case stops by rounds 4
and 5, as expected: the faults they fix are in the BODS archive and in
Scotland and Suffolk, where there are no case stops.

## 5. A combined source

Taking each reading from TNDS where TNDS has the route at the document's
place and from UK2GTFS's BODS conversion where it does not scores 55 of 78
(TNDS alone 54), with 1 route absent instead of 2 and a median error of
7.0%. The other order (BODS first, TNDS to fill) scores 53. On the
November evidence:

* **TNDS converted by UK2GTFS is the best single source**, and the DfT's
  BODS GTFS the worst: it overcounts wherever an operator leaves
  superseded versions open, which on the West Midlands network is every
  route, and it labels several non-bus services with the wrong mode.
* **UK2GTFS's conversion of the BODS archive now comes within one reading
  of TNDS** (51 against 54 at 15%, the same median error) after the
  handover rule, and it has two properties TNDS lacks: no forward-horizon
  decay (§1; 173 lines ran out early in the July TNDS snapshot) and
  withdrawn services disappearing (Gatwick Hoppa GH2).
* **The two fail in different places.** TNDS misses what BODS has
  that TNDS has not caught up with (Brighton 20, Reading's next block in
  July); BODS misses Scotland, London and Wales, Brighton 50/18/12A,
  Sheffield SC1/SC2/181, Nottingham's tram and Ember.

So a combination is worth having, but not the wholesale merge that
`source_triangulation.md` tested and rejected: that put two copies of
every service both carry into one feed. What the evidence supports is a
**per-service choice** made in TransXChange, before conversion, where the
identities needed to make it still exist. A design:

1. Index both archives (as `txc_index.py` does) and match services across
   them on line name plus at least half their stops, the test the
   operator-handover rule already uses, because operator codes differ
   between the two (NXWM is `OC:WMB` in TNDS and `TNXB`/`WMBL` in BODS).
2. For a matched service take the source whose newest file is newer and
   whose period covers the window; the other source's files for it are
   dropped. A service in one source only is taken from that source.
3. Run `txc_filter_files()` over the chosen files as now.

The day-by-day test of whether it beats TNDS alone is the November check
plus the July check (which BODS would win on the horizon cases); on this
evidence the gain at the case stops is small (one reading), and the larger
gains are where there are no case stops yet (Reading-type horizon loss,
withdrawn services). It is not built here.

## 6. What changed in UK2GTFS, and what is still open

All in the UK2GTFS checkout, **uncommitted**, installed 15 November 2026;
the full test suite passes (319 tests).

| Change | File | Effect measured |
|---|---|---|
| Rule 2 keeps an earlier sibling with other journeys | `txc_filter_files.R` | Arriva Cymru 35, 27, 5, 14; East Yorkshire M4 |
| Journeys match only on shared days | `txc_filter_files.R` | Peter's Travel 343 |
| Shorter period must cover the longer one's days within its own period | `txc_filter_files.R` | TfL N97, N74; District line overlays still reconciled |
| `txc_versions()`: count test between 25% and 50% share | `txc_filter_files.R` | TfL 195 still a version; Metrolink, Compass siblings kept |
| Operator handover rule | `txc_filter_files.R` | NXWM/NX Coventry → West Midlands Bus (144 files), 60 more in BODS, 11 in TNDS |
| `clean_pass()` | `transxchange_export_functions.R` | Tanat Valley X81 converts |
| `clean_days("")` = every day; service profile read properly | `transxchange_export_functions.R`, `transxchange_import_functions.R` | 8 BODS files with no profile run; 188 holidays-only service files do not |
| `bookable_note()` | `transxchange_export.R`, `transxchange_export_functions.R` | about 12,250 TNDS journeys back (Ember 11,680) |

July national filter check (`compare_actions.py`, against `d557efe`): 3,365
window journeys put back, 484 of them duplicates, none removed; journeys
removed with nothing replacing them 11,934 → 9,053.

**Still open:**

* The 15 November readings where all three feeds agree and the timetable
  does not (§4).
* ~~West Midlands Bus X21 and X22, where UK2GTFS's BODS feed has about three
  quarters of TNDS's journeys.~~ Resolved in round 8i (§7).
* The 9,053 journeys the filter still removes unmatched in July, most of
  them TfL successor registrations re-timed by more than three minutes;
  a looser match would tell those from real losses.
* The combined source of §5.
* The rest of the series: only the validation snapshots (July and November
  2026) are reconverted. Every other TNDS and BODS TransXChange cache is
  still from the old package and must be deleted and rebuilt to carry these
  fixes into the published outputs (about 40 hours,
  `scripts/rebuild_daytype_series.ps1`).
* Service-level `BankHolidayOperation` is imported but never applied, so a
  holidays-only service never gets its bank-holiday dates.

## 7. Postscript: the route-subset rounds (17-18 November 2026)

The filter was reworked again on a subset of disagreeing routes, in fifteen
steps (rounds 8a-8o); the method, every rule change and the route-by-route
counts are in `route_subset_audit.md`. The five validation targets were
rebuilt with the result on 18 November. Against round 6b: UK2GTFS's BODS
TransXChange feed is within 15% of the in-force November timetables on 59
readings (58), TNDS on 61 (61), the DfT's BODS GTFS on 41 (41); median
errors unchanged at 5.5 / 5.5 / 12.9%. The two readings that moved are
Metrobus 100 and 200 in BODS TransXChange, now equal to TNDS. West Midlands
Bus X21 and X22, open in §6, are within 15% from round 8i
(successive editions are no longer run side by side). These counts come
from `scripts/tnds_conversion_audit/nov_summary.R` on the current readings
and are not directly comparable with the round-4 table in §4.

