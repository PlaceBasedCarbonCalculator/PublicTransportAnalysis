# Did the October 2026 fixes improve the zone checks?

`reports/pdf_validation.md` carries 201 checks of a published
timetable against TNDS and the DfT's BODS GTFS **at a zone**, over 45 zones.
They were measured before the three October 2026 changes - the UK2GTFS
overlap patch, the move to the TransXChange 2.5 edition of TNDS, and the
counting window going from 28 days to 14 - and that section of the report
is hand-written, so knitting does not refresh it. This re-measures all 201
on the current pipeline.

No PDF was read again. `data/zone_pdf_validation.csv` already holds each
document's journeys per operating day, which is what the documents were
needed for and does not depend on the pipeline. What is recomputed is the
document's window total, from journeys per day times the number of each
day type in the current 14-day window, and the TNDS and BODS GTFS run
counts at the zone, from the current feeds. Both sides move onto the 14-day
window together, so the **ratios** stay comparable with the published ones
even though the counts halve. Written by `scripts/zone_check_refresh.R`
and `scripts/zone_check_refresh_report.R`; the full table is
`data/zone_pdf_validation_refreshed.csv`.

Window: **2026-07-27 to 2026-08-09** (14 days). Snapshot: the July 2026 triple, unchanged.

Three columns of TNDS, not two, so that the window and the conversion can
be told apart:

| Column | Window | TNDS edition | UK2GTFS |
|---|---|---|---|
| `published` | 28 days | 2.1 | overlap rule unpatched |
| `prefix` | 14 days | 2.1 | overlap rule unpatched |
| `fixed` | 14 days | 2.5 | **patched** |

`published` against `prefix` is the window alone; `prefix` against
`fixed` is the conversion fixes alone. Both were counted by the same R
code over the same zones, so no part of the difference is method.

## How close is each source to the document?

Reliable checks only (183 of 201; the rest are documents whose reading
the PDF reader could not be trusted on). *Distance* is the mean of
|log(ratio)|, so that reading half the timetable and reading twice it count
the same; lower is better. *Within 15%* is the number of checks the
verdict rule would call right.

**Two tables, because one number hides the finding.** A source that
carries *nothing* at a zone has a ratio of 0, which no ratio scale can
express: floored at 0.001 it contributes |log| of 6.9, about 22 times the typical
error where both sources do carry the service. TNDS carries nothing on 18 of these
checks and BODS GTFS on 9.

* TNDS absent: Crawley and Gatwick (9), Hull (8), Brighton (1)
* BODS GTFS absent: Aylesbury (3), Brighton (3), Swansea (2), Portsmouth (1)

The TNDS absences are the Metrobus stub files around Crawley and the Hull
local-authority files that expired by their own "Data Expires" note -
defects in the source data that no conversion change can repair, and which
the October 2026 fixes did not touch. Averaged in, they swamp everything
else and the comparison becomes a count of absences. Reported separately,
the first table says how well each source describes a timetable it has,
and the second says how often it has one at all.

### Where both sources carry the service

| Source | Median ratio | Distance | Within 15% of 156 |
|---|---:|---:|---:|
| TNDS, as published (28 d, 2.1, unpatched) | 0.92 | 0.629 | 72 |
| TNDS, the 14-day window alone (2.1, unpatched) | 0.94 | 0.398 | 78 |
| **TNDS, fixed** (14 d, 2.5, patched) | 0.94 | 0.310 | 93 |
| BODS GTFS (14 d) | 1.46 | 0.473 | 41 |

### Every reliable check, absences included

| Source | Median ratio | Distance | Within 15% of 183 |
|---|---:|---:|---:|
| TNDS, as published (28 d, 2.1, unpatched) | 0.90 | 1.225 | 78 |
| TNDS, the 14-day window alone (2.1, unpatched) | 0.92 | 1.030 | 84 |
| **TNDS, fixed** (14 d, 2.5, patched) | 0.92 | 0.956 | 99 |
| BODS GTFS (14 d) | 1.34 | 0.752 | 56 |

The two tables disagree about which source is better, and both are right.
Where both carry the service TNDS is the more accurate by a wide margin;
counting the absences, BODS GTFS is, because TNDS is the one that goes
missing. Neither the patch nor the 2.5 edition nor the shorter window
addresses an absence, so the second table barely moves.

On this measure TNDS is **closer to** the published timetables than it was:
distance 0.629 before, 0.310 after, a change of -51%.
Of that, the window accounts for -0.231 and the conversion fixes -0.087.

## Verdicts

The verdict rule is the one `scripts/zone_pdf_validation/assemble.py`
used, ported in `scripts/zone_check_refresh.R`: a source is *right* when it
is within 15% of the document, *absent* when it carries nothing.

| Verdict | published | 14d only | fixed |
|---|---:|---:|---:|
| TNDS right | 73 | 75 | 75 |
| neither; BODS GTFS closer | 45 | 37 | 36 |
| BODS GTFS right | 34 | 36 | 21 |
| both agree | 0 | 5 | 20 |
| neither; TNDS closer | 20 | 19 | 20 |
| TNDS absent | 15 | 15 | 15 |
| BODS GTFS absent | 6 | 6 | 6 |
| TNDS absent; BODS GTFS off | 5 | 5 | 5 |
| BODS GTFS absent; TNDS off | 3 | 3 | 3 |

38 of the 201 checks change verdict. 

| From | To | Checks |
|---|---|---:|
| BODS GTFS right | both agree | 15 |
| neither; TNDS closer | TNDS right | 7 |
| neither; BODS GTFS closer | neither; TNDS closer | 7 |
| TNDS right | both agree | 5 |
| neither; BODS GTFS closer | BODS GTFS right | 3 |
| BODS GTFS right | neither; BODS GTFS closer | 1 |

## The places the investigation named

`reports/tnds_conversion_investigation.md` traced the disagreements to
causes. These are the zones for each cause it identified, with what the
fixes did to them.

### North-east London (cross-region duplicate, fixed by 2.5)

15 checks. Median TNDS ratio to the document: 2.00 as published, 2.00 on the 14-day window alone, **1.00** fixed, against BODS GTFS 1.00.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01021766 | 167 | 1,356 | 2.00 | 2.00 | 1.00 | 1.00 |
| E01021767 | 167 | 1,356 | 2.00 | 2.00 | 1.00 | 1.00 |
| E01021782 | 167 | 1,356 | 2.00 | 2.00 | 1.00 | 1.00 |
| E01003670 | 20 | 1,696 | 2.01 | 2.01 | 1.00 | 1.00 |
| E01003750 | 20 | 1,696 | 2.01 | 2.01 | 1.00 | 1.00 |
| E01004377 | 20 | 1,696 | 2.01 | 2.01 | 1.00 | 1.00 |
| E01004397 | 20 | 1,696 | 2.01 | 2.01 | 1.00 | 1.00 |
| E01021782 | 20 | 1,696 | 2.01 | 2.01 | 1.00 | 1.00 |
| E01004397 | 215 | 1,418 | 1.99 | 1.99 | 0.99 | 0.99 |
| E01003670 | 275 | 1,960 | 2.00 | 2.00 | 1.00 | 1.01 |
| E01003750 | 275 | 1,960 | 2.00 | 2.00 | 1.00 | 1.01 |
| E01004377 | 275 | 1,960 | 2.00 | 2.00 | 1.00 | 1.01 |
| E01004397 | 275 | 1,960 | 2.00 | 2.00 | 1.00 | 1.01 |
| E01021766 | 275 | 1,960 | 2.00 | 2.00 | 1.00 | 1.01 |
| E01021767 | 462 | 1,602 | 2.00 | 2.00 | 1.00 | 1.00 |

### Preston (cross-region duplicate, fixed by 2.5)

2 checks. Median TNDS ratio to the document: 2.49 as published, 2.49 on the 14-day window alone, **1.24** fixed, against BODS GTFS 1.24.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01024940 | 125 | 1,832 | 2.41 | 2.41 | 1.20 | 1.20 |
| E01033223 | 125 | 1,558 | 2.57 | 2.57 | 1.28 | 1.28 |

### Chelmsford (sibling files, fixed by the patch; also weekly exports)

28 checks. Median TNDS ratio to the document: 0.20 as published, 0.40 on the 14-day window alone, **0.42** fixed, against BODS GTFS 1.89.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01021542 | 170 | 734 | 0.20 | 0.40 | 0.40 | 1.24 |
| E01021587 | 170 | 734 | 0.20 | 0.40 | 0.40 | 1.24 |
| E01021592 | 170 | 734 | 0.20 | 0.40 | 0.40 | 1.24 |
| E01034091 | 170 | 734 | 0.20 | 0.40 | 0.40 | 1.24 |
| E01033140 | 333 | 528 | 0.16 | 0.31 | 0.32 | 1.12 |
| E01034091 | 333 | 528 | 0.16 | 0.31 | 0.32 | 1.12 |
| E01034092 | 333 | 528 | 0.16 | 0.31 | 0.32 | 1.12 |
| E01033140 | 336 | 500 | 0.14 | 0.28 | 0.37 | 1.25 |
| E01034091 | 336 | 500 | 0.14 | 0.28 | 0.37 | 1.25 |
| E01034092 | 336 | 500 | 0.14 | 0.28 | 0.37 | 1.25 |
| E01034091 | 351 | 422 | 0.24 | 0.47 | 0.47 | 2.52 |
| E01034092 | 351 | 422 | 0.24 | 0.47 | 0.47 | 2.52 |
| E01033140 | 700 | 806 | 0.25 | 0.50 | 0.50 | 1.59 |
| E01034092 | 700 | 806 | 0.25 | 0.50 | 0.50 | 1.59 |
| E01021542 | C1 | 2,022 | 0.20 | 0.40 | 0.40 | 1.89 |
| E01021587 | C1 | 2,022 | 0.20 | 0.40 | 0.40 | 1.89 |
| E01021592 | C1 | 2,022 | 0.20 | 0.40 | 0.40 | 1.89 |
| E01034091 | C1 | 1,162 | 0.35 | 0.70 | 0.70 | 3.34 |
| E01034091 | C10 | 782 | 0.23 | 0.47 | 0.47 | 2.80 |
| E01021592 | C2 | 702 | 0.44 | 0.88 | 0.88 | 4.31 |
| E01034091 | C2 | 702 | 0.44 | 0.88 | 0.88 | 4.31 |
| E01034091 | C3 | 360 | 0.48 | 0.97 | 0.97 | 5.00 |
| E01034091 | C5 | 556 | 0.46 | 0.93 | 0.93 | 3.89 |
| E01034091 | C7 | 480 | 0.18 | 0.36 | 0.40 | 2.44 |
| E01034091 | C8 | 588 | 0.23 | 0.47 | 0.47 | 2.69 |
| E01034092 | C9 | 606 | 0.24 | 0.47 | 0.47 | 3.30 |
| E01034091 | X10 | 640 | 0.22 | 0.44 | 0.44 | 1.61 |
| E01034091 | X30 | 1,170 | 0.10 | 0.20 | 0.43 | 2.53 |

### Reading (weekly exports, window change only)

22 checks. Median TNDS ratio to the document: 0.25 as published, 0.49 on the 14-day window alone, **0.49** fixed, against BODS GTFS 0.99.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01033415 | 1 | 824 | 0.25 | 0.50 | 0.50 | 1.00 |
| E01033415 | 11 | 1,228 | 0.25 | 0.50 | 0.50 | 1.00 |
| E01033415 | 16 | 1,226 | 0.25 | 0.49 | 0.49 | 0.98 |
| E01033415 | 17 | 3,420 | 0.24 | 0.48 | 0.48 | 0.95 |
| E01033415 | 18 | 822 | 0.24 | 0.49 | 0.49 | 0.98 |
| E01033415 | 21 | 1,844 | 0.21 | 0.41 | 0.41 | 0.83 |
| E01033415 | 25 | 684 | 0.27 | 0.53 | 0.53 | 1.06 |
| E01033415 | 26 | 1,958 | 0.24 | 0.49 | 0.49 | 0.97 |
| E01033415 | 28 | 960 | 0.19 | 0.38 | 0.38 | 0.77 |
| E01033415 | 29 | 714 | 0.26 | 0.52 | 0.52 | 1.05 |
| E01033415 | 3 | 1,364 | 0.28 | 0.56 | 0.56 | 1.11 |
| E01033420 | 3 | 1,364 | 0.28 | 0.56 | 0.56 | 1.11 |
| E01033415 | 33 | 1,246 | 0.25 | 0.50 | 0.50 | 1.00 |
| E01033415 | 4 | 1,106 | 0.19 | 0.37 | 0.37 | 0.74 |
| E01033420 | 4 | 1,106 | 0.19 | 0.37 | 0.37 | 0.74 |
| E01033415 | 5 | 2,206 | 0.25 | 0.50 | 0.50 | 1.00 |
| E01033415 | 50 | 498 | 0.36 | 0.72 | 0.72 | 1.44 |
| E01033415 | 500 | 446 | 0.68 | 1.36 | 1.36 | 2.72 |
| E01033415 | 6 | 2,430 | 0.22 | 0.43 | 0.43 | 0.87 |
| E01033415 | 600 | 652 | 0.57 | 1.14 | 1.14 | 2.29 |
| E01033415 | 9 | 470 | 0.22 | 0.44 | 0.44 | 0.88 |
| E01033420 | 9 | 470 | 0.22 | 0.44 | 0.44 | 0.88 |

### Weymouth (weekly exports, window change only)

5 checks. Median TNDS ratio to the document: 0.28 as published, 0.55 on the 14-day window alone, **0.55** fixed, against BODS GTFS 1.80.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01020554 | 1 | 1,748 | 0.22 | 0.43 | 0.43 | 1.37 |
| E01020554 | 10 | 1,506 | 0.22 | 0.44 | 0.44 | 1.34 |
| E01020554 | 2 | 1,660 | 0.28 | 0.55 | 0.55 | 1.80 |
| E01020554 | 4 | 564 | 0.40 | 0.80 | 0.80 | 2.44 |
| E01020554 | 8 | 330 | 0.52 | 1.04 | 1.04 | 2.98 |

### Hull (stale local-authority files, expired by their own note)

9 checks. Median TNDS ratio to the document: 0.00 as published, 0.00 on the 14-day window alone, **0.00** fixed, against BODS GTFS 1.00.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01033104 | 104 | 784 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 35 | 764 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 45 | 976 | 0.00 | 0.00 | 0.00 | 0.99 |
| E01033104 | 51 | 962 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 54 | 772 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 56 | 984 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 57 | 1,072 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01033104 | 58 | 862 | 0.00 | 0.00 | 0.00 | 0.99 |
| E01033104 | X46 | 620 | 0.67 | 1.02 | 1.02 | 1.98 |

### Crawley (Metrobus stub files)

22 checks. Median TNDS ratio to the document: 0.00 as published, 0.00 on the 14-day window alone, **0.00** fixed, against BODS GTFS 1.05.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01031575 | 10 | 3,408 | 0.00 | 0.00 | 0.00 | 1.05 |
| E01031583 | 10 | 3,600 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01031585 | 10 | 3,604 | 0.00 | 0.00 | 0.00 | 1.00 |
| E01031575 | 100 | 1,316 | 0.00 | 0.00 | 0.00 | 1.36 |
| E01031583 | 100 | 0 | NA | NA | NA | NA |
| E01031585 | 100 | 1,332 | 0.00 | 0.00 | 0.00 | 1.34 |
| E01031585 | 2 | 954 | 0.00 | 0.00 | 0.00 | 1.90 |
| E01031575 | 20 | 0 | NA | NA | NA | NA |
| E01031583 | 20 | 0 | NA | NA | NA | NA |
| E01031585 | 20 | 0 | NA | NA | NA | NA |
| E01031575 | 200 | 1,074 | 0.00 | 0.00 | 0.00 | 1.08 |
| E01031583 | 200 | 0 | NA | NA | NA | NA |
| E01031575 | 3 | 0 | NA | NA | NA | NA |
| E01031583 | 3 | 0 | NA | NA | NA | NA |
| E01031585 | 3 | 1,336 | 0.00 | 0.00 | 0.00 | 1.04 |
| E01031575 | 4 | 0 | NA | NA | NA | NA |
| E01031585 | 4 | 2,180 | 0.00 | 0.00 | 0.00 | 0.38 |
| E01031575 | 400 | 0 | NA | NA | NA | NA |
| E01031583 | 400 | 0 | NA | NA | NA | NA |
| E01031585 | 400 | 678 | 0.00 | 0.00 | 0.00 | 1.07 |
| E01031575 | 5 | 0 | NA | NA | NA | NA |
| E01031585 | 5 | 2,180 | 0.00 | 0.00 | 0.00 | 0.38 |

### Brighton (old edition, no summer timetable)

7 checks. Median TNDS ratio to the document: 0.71 as published, 0.71 on the 14-day window alone, **0.71** fixed, against BODS GTFS 0.86.

| Zone | Route | Document (14 d) | TNDS published | TNDS 14d | TNDS fixed | BODS GTFS |
|---|---|---|---|---|---|---|
| E01016969 | 12 | 2,152 | 0.71 | 0.71 | 0.71 | 0.96 |
| E01016969 | 12A | 1,860 | 0.68 | 0.65 | 0.65 | 0.00 |
| E01016969 | 14 | 1,730 | 0.61 | 0.61 | 0.61 | 0.95 |
| E01016952 | 18 | 774 | 2.14 | 2.14 | 2.14 | 0.00 |
| E01016969 | 20 | 1,632 | 0.00 | 0.00 | 0.00 | 0.96 |
| E01016969 | 25 | 2,598 | 1.23 | 1.23 | 1.23 | 0.86 |
| E01016969 | 50 | 1,514 | 1.00 | 1.00 | 1.00 | 0.00 |

### Places not listed above

110 of the 201 checks fall in the places the
investigation named. The remaining 91 are in Aylesbury, Birmingham city centre, Black Country, Edinburgh, Kingston, Sunbury and Epsom, Portsmouth, Southampton, Swansea.
Those were either not TNDS errors at all (Birmingham and the Black
Country, where two operators share a route number and the check counts
both) or were never traced to a cause.

## What this does not settle

* **The 18 unreliable readings.** Where the PDF reader could not be trusted -
  a frequent-service abbreviation it failed to expand, a rotated table it
  could not transpose - the document figure is too low and the ratio is
  too high in both sources alike. They are reported but excluded above.
* **The shared-route-number checks.** Birmingham 50, Black Country 9, 59
  and 82 are run by two operators each and counted here by route number,
  so the document is one operator's and the feeds are both. The
  investigation's recommendation 4 was to drop or split them and that has
  not been done.
* **The causes neither fix addresses.** Hull's expired local-authority
  files, Crawley's Metrobus stubs and Brighton's missing summer edition
  are properties of the source data. A shorter window helps where a file
  ends inside it and does nothing where the file was never there: Hull and
  Crawley read 0.00 before and after, and Brighton is unmoved.

* **The weekly exports are halved, not fixed.** Reading, Chelmsford and
  Weymouth roughly doubled - Reading 0.25 to 0.49, Chelmsford 0.20 to
  0.42, Weymouth 0.28 to 0.55 - which is exactly what halving the window
  predicts and no more. They sit near 0.5 because the operators publish
  **one week** and the window is two, so the second week is still empty.
  A 7-day window would bring them to about 1.0, and that is the obvious
  thing to want, but it would hold one of each weekday instead of two:
  a single bank holiday, strike day or school-term boundary would then
  land on a weekday with nothing to average it against, and `tph_*` would
  swing on it. Two weeks is the shortest window that still holds a
  duplicate of every weekday. Getting these places right needs the
  horizon problem solved at the source - a per-operator flag, or BODS for
  the operators that publish weekly - rather than a shorter window.

