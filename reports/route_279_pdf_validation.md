# Checking route 279 against the operator's published schedule, 2026

`reports/bus_source_comparison.md` identified the **279 (Waltham Cross Bus
Station – Manor House, Arriva London North)** as the single largest
journey-count disagreement between TNDS and BODS GTFS in the 2026 snapshot:
TNDS counted 8,284 vehicle journeys in the 28-day window against BODS GTFS's
19,622, a ratio of 0.42. That comparison could say the sources disagreed but
not which one was right.

This report settles it against the operator's own running schedules, obtained
as four PDFs in `data/example_timetables/`.

**Answer: TNDS is exactly right, and BODS TransXChange is exactly right.
Both reproduce the published schedule journey-for-journey and minute-for-minute.
BODS GTFS carries the same correct timetable but publishes it 2.4 times over,
and then loses the first two days of the counting window.**

## The reference: what the PDFs say

The four files are TfL running schedules (not passenger timetables) for
route 279, service change **70450 — Stop Sequence Change**, operator
**MN — Arriva**, implementation date **23 May 2026**. Each lists every
vehicle journey as a row, with departure times at the route's timing points,
the duty and bus run working it, and the garage positioning runs at each end.

|Day type            |PDF file             | Vehicles| Journeys|
|:-------------------|:--------------------|--------:|--------:|
|MT — Monday–Thursday|`Schedule_279-MT.pdf`|       30|      318|
|Fr — Friday         |`Schedule_279-Fr.pdf`|       30|      318|
|Sa — Saturday       |`Schedule_279-Sa.pdf`|       24|      263|
|Su — Sunday         |`Schedule_279-Su.pdf`|       17|      218|

That is **2,071 journeys per week**, and over the 28-day window used
throughout the comparison (2026-02-02 to 2026-03-01, which contains exactly
four of each weekday) **8,284 journeys**.

On a Monday–Thursday, 161 of the 318 journeys run towards Manor House and
157 away from it.

### The date caveat, and why it does not bite

The PDFs are the schedule implemented on **23 May 2026**; the GTFS snapshots
are from **4 February 2026**. The comparison is nevertheless exact, for a
reason the PDFs state themselves: the change is a *stop sequence* change, and
each schedule is headed `279-70450-<day>-MN-1- ST copied 67013` — the
scheduled times were copied unchanged from the previous schedule 67013. The
minute-level test below confirms this empirically: all 1,117 Manor House
departures in the February feeds (318 + 318 + 263 + 218 across the four day
types) appear in the May PDFs at the same minute, on the same day type.

## Method

Route 279 was extracted from each 2026 feed by `route_short_name`, and its
trips joined to `calendar.txt` and `calendar_dates.txt` to give the journeys
operating on each of the 28 dates. The PDF trip tables were parsed from the
PDF word coordinates (`pdftools::pdf_data()`), so each time is attached to
the correct timing-point column rather than to a guessed character position.

The two are compared at **Manor House Station** (`AD803` in the schedules,
NaPTAN `490000142F`/`490000142G` in the feeds), the one timing point every
journey in both directions passes. Journeys running past midnight are written
past `24:00` in the PDFs (the last Manor House departure of a Monday–Thursday
is `24:46`) but sometimes as `00:46` in GTFS; times before 04:00 are therefore
shifted forward 24 hours on both sides before comparison.

Each feed's 279 was separated by `route_id`, because — as it turns out — the
BODS GTFS feed does not hold the route only once.

## Result 1: journeys per day type

|Source                                 |Route(s)| Mon–Thu| Fri| Sat| Sun|Matches PDF |
|:--------------------------------------|:-------|-------:|---:|---:|---:|:-----------|
|**PDF (published schedule)**           |—       |     318| 318| 263| 218|—           |
|TNDS (TransXChange)                    |2166    |     318| 318| 263| 218|**yes**     |
|BODS (TransXChange)                    |693     |     318| 318| 263| 218|**yes**     |
|BODS (GTFS), agency OP839 Arriva London|138482  |     318| 318| 263| 218|**yes**     |
|BODS (GTFS), agency OP401 Arriva London North|10003 | 467| 397| 526| 436|no (+47% to +100%)|

Three of the four renderings reproduce the published journey count exactly,
on every day type. The fourth does not, and it is not a near miss: on a
Saturday it claims twice the service that runs.

## Result 2: journeys minute by minute

Departures at Manor House Station, treated as a multiset of clock minutes and
compared against the PDF for the same day type.

|Source                    |Day type| PDF| Feed| Matched| In PDF, not in feed| In feed, not in PDF|
|:-------------------------|:-------|---:|----:|-------:|-------------------:|-------------------:|
|TNDS                      |Mon–Thu | 318|  318|     318|                   0|                   0|
|TNDS                      |Fri     | 318|  318|     318|                   0|                   0|
|TNDS                      |Sat     | 263|  263|     263|                   0|                   0|
|TNDS                      |Sun     | 218|  218|     218|                   0|                   0|
|BODS TransXChange         |Mon–Thu | 318|  318|     318|                   0|                   0|
|BODS TransXChange         |Fri     | 318|  318|     318|                   0|                   0|
|BODS TransXChange         |Sat     | 263|  263|     263|                   0|                   0|
|BODS TransXChange         |Sun     | 218|  218|     218|                   0|                   0|
|BODS GTFS — OP839 (138482)|Mon–Thu | 318|  318|     318|                   0|                   0|
|BODS GTFS — OP839 (138482)|Fri     | 318|  318|     318|                   0|                   0|
|BODS GTFS — OP839 (138482)|Sat     | 263|  263|     263|                   0|                   0|
|BODS GTFS — OP839 (138482)|Sun     | 218|  218|     218|                   0|                   0|
|BODS GTFS — OP401 (10003) |Mon–Thu | 318|  467|     318|                   0|             **149**|
|BODS GTFS — OP401 (10003) |Fri     | 318|  397|     318|                   0|              **79**|
|BODS GTFS — OP401 (10003) |Sat     | 263|  526|     263|                   0|             **263**|
|BODS GTFS — OP401 (10003) |Sun     | 218|  436|     218|                   0|             **218**|

This is a stronger test than it looks. The Monday–Thursday and Friday
schedules are different timetables that happen to have the same journey
count — 146 of the 318 Manor House departures fall at a minute the other day
type does not use — so matching both exactly, in the right day type, cannot
be coincidence.

Hourly departures at Manor House, Monday–Thursday:

| Hour| PDF| TNDS| BODS TXC| BODS GTFS OP839| BODS GTFS OP401|
|----:|---:|----:|--------:|---------------:|---------------:|
|   05|   2|    2|        2|               2|               2|
|   06|  13|   13|       13|              13|              16|
|   07|  18|   18|       18|              18|              25|
|   08|  21|   21|       21|              21|              37|
|   09|  20|   20|       20|              20|              29|
|   10|  18|   18|       18|              18|              27|
|   11|  18|   18|       18|              18|              27|
|   12|  18|   18|       18|              18|              28|
|   13|  18|   18|       18|              18|              27|
|   14|  18|   18|       18|              18|              27|
|   15|  17|   17|       17|              17|              27|
|   16|  20|   20|       20|              20|              35|
|   17|  20|   20|       20|              20|              33|
|   18|  18|   18|       18|              18|              27|
|   19|  18|   18|       18|              18|              26|
|   20|  14|   14|       14|              14|              21|
|   21|  13|   13|       13|              13|              18|
|   22|  12|   12|       12|              12|              13|
|   23|  13|   13|       13|              13|              13|
|   24|   9|    9|        9|               9|               9|

At the stop-times level the agreement is literal. TNDS and BODS GTFS route
138482 contain **identical** `stop_times` for this route — the same 54,164
rows over the same 97 stops, with the same arrival and departure times (the
only formal difference is that TNDS numbers `stop_sequence` from 1 and the
DfT feed from 0). BODS TransXChange differs from TNDS on 446 of those 54,164
rows, every one of them by **one second** at a single interpolated
non-timing-point stop — a rounding difference in UK2GTFS's interpolation, not
a timetable difference.

## Result 3: journeys per date across the 28-day window

|Date                       |Weekday| PDF| TNDS| BODS TXC| BODS GTFS OP839| BODS GTFS OP401| BODS GTFS total|
|:--------------------------|:------|---:|----:|--------:|---------------:|---------------:|---------------:|
|**2026-02-02**             |Mon    | 318|  318|      318|           **0**|           **0**|           **0**|
|**2026-02-03**             |Tue    | 318|  318|      318|           **0**|           **0**|           **0**|
|2026-02-04                 |Wed    | 318|  318|      318|             318|             467|             785|
|2026-02-05                 |Thu    | 318|  318|      318|             318|             467|             785|
|2026-02-06                 |Fri    | 318|  318|      318|             318|             397|             715|
|2026-02-07                 |Sat    | 263|  263|      263|             263|             526|             789|
|2026-02-08                 |Sun    | 218|  218|      218|             218|             436|             654|
|**Window total**           |       |**8,284**|**8,284**|**8,284**|7,648|11,974|**19,622**|

The remaining 20 days (2026-02-09 to 2026-03-01) repeat the 04–08 February
pattern exactly, in all five columns.

TNDS and BODS TransXChange land on 8,284 — the published figure — to the
journey. BODS GTFS's 19,622 is 2.37 times the true number, and its two
component routes are wrong in opposite directions for two unrelated reasons.

## Why BODS GTFS disagrees

The `vehicle_journey_code` field in the DfT feed preserves the identity of
the source TransXChange journey, and it makes the cause unambiguous. Every
279 journey in the feed carries a code of the form
`VJ_8-279-_-y05-<version>-<n>-<daytype>` — the same TransXChange service
`8-279-_-y05` throughout, in two versions:

|Version| Journeys| Present in route 10003 (OP401)| Present in route 138482 (OP839)|
|:------|--------:|:------------------------------|:-------------------------------|
|62015  |    1,117|yes                            |yes                             |
|62013  |      709|yes                            |no                              |

### Cause 1 — the same timetable published under two agency records

Version 62015 *is* the published schedule: 318 / 318 / 263 / 218 journeys,
matching the PDFs exactly. It appears **twice** in the feed, once under
agency `OP839` ("Arriva London", NOC `AVLO`) and once under agency `OP401`
("Arriva London North", NOC `ALNO`). The two copies carry different synthetic
`trip_id`s — so nothing in the feed marks them as duplicates — but the
`vehicle_journey_code` sets are identical, all 1,117 of them, and the
departure times are identical on every day type. The 279 is operated by one
company under one contract; the feed simply holds the same TransXChange file
under two NOC records for it.

### Cause 2 — a superseded version left in alongside the current one

Version 62013 is an earlier version of the same service: 149 Monday–Thursday,
79 Friday, 263 Saturday and 218 Sunday journeys, present only under `OP401`.
It is not a copy of 62015 — it is a slightly different timetable, offset by
one to three minutes at most points (Saturday, first departures from Manor
House: 05:41 / 05:53 / 06:00 / 06:06 against the published 05:43 / 05:55 /
06:00 / 06:07; only 158 of its 263 Saturday minutes coincide with the current
version). It runs on its own `service_id`s in parallel with 62015 over the
whole feed period, so on any Saturday in the window the feed asserts 526
journeys on a route that runs 263.

Together these give the 2.4× overstatement. Note that the comparison report's
route matching did not create this: it correctly recognised routes 10003 and
138482 as one service, because they *are* one service. The duplication is in
the feed.

### Cause 3 — the feed has no history, and the window starts before it

Route 138482 is a faithful rendering of the published timetable, yet it
returns 7,648 rather than 8,284 for the window. The missing 636 journeys are
exactly the Monday and Tuesday of the first week (318 + 318).

This is not specific to the 279. **All 2,051 calendars in the
`20260204/itm_all_gtfs.zip` feed start on or after 2026-02-04, and not one is
active on 2026-02-02.** The DfT's national GTFS is a forward-looking snapshot
that carries no history: it describes service from the extraction date
onward. The TransXChange sources do not behave this way — 1,746 of the 2,354
TNDS calendars and 3,326 of the 3,889 BODS TransXChange calendars are active
on 2026-02-02.

The 2026 snapshot triple is the only one in the comparison series where this
matters. The window is derived by flooring the reference date to its Monday,
and 2026-02-04 is a **Wednesday**, so the window opens two days before the
snapshot. In 2024 and 2025 the reference dates (2024-10-07, 2025-10-06) are
themselves Mondays and the window opens exactly on the snapshot date.

## Consequence for the multi-year comparison

> **Revised, 2026-07-25.** The paragraph below originally said the half-term
> diagnosis was simply wrong. Checking three further routes
> (`route_validation_69_A1_142.md`) showed that too strong: the two missing
> days are the largest single driver and the evidence for them stands, but
> school holidays are involved through two other mechanisms — services the DfT
> feed defines only in `calendar_dates.txt` (which this pipeline's route
> counting drops), and a UK2GTFS holiday-profile fault that makes TNDS run the
> term-time and half-term timetables simultaneously. See that report's
> "What this changes in the earlier reports".

`bus_source_comparison.md` flags the February 2026 window as the one year
where TNDS and BODS GTFS stop agreeing on shared services — the modal ratio
shifts to about 1.09 and the share of exactly-equal services collapses from
~60% to 4.2% — and attributes it tentatively to school half-term being
handled differently by the two converters. The evidence below shows that a
large part of the shift is something simpler: the two missing days.

A service losing the Monday and Tuesday of a 28-day window produces a TNDS ÷
BODS GTFS ratio that depends only on which days it runs:

|Operating pattern| Days in window| Days in BODS GTFS| Expected ratio|
|:----------------|--------------:|-----------------:|--------------:|
|Monday–Friday    |             20|                18|         1.1111|
|Monday–Saturday  |             24|                22|         1.0909|
|Every day        |             28|                26|         1.0769|
|Weekends only    |              8|                 8|         1.0000|

Those are precisely the values the 2026 data takes:

|Year| Shared services| Median ratio|Within 0.2% of one of the three signature ratios |Ratio in (1.07, 1.12] |
|:---|---------------:|------------:|:------------------------------------------------|:---------------------|
|2024|          11,763|        1.000|0.6%                                             |2.4%                  |
|2025|           9,475|        1.000|0.8%                                             |3.1%                  |
|2026|           9,319|    **1.0909**|**26.7%**                                       |**54.7%**             |

The 2026 median ratio is 1.0909 — 24 ÷ 22, the Monday-to-Saturday signature,
which is the commonest bus operating pattern in the country. A half-term
effect alone would not produce a distribution concentrated on three exact
rational values, so the missing days are certainly a large part of the shift;
the residual spread beyond those three spikes is where the other two
mechanisms (see the note above) sit.

**Recommended fix.** Anchor the counting window to start on or after the BODS
GTFS snapshot date rather than flooring the reference date to its Monday
regardless — for 2026 that means the window 2026-02-09 to 2026-03-08, or
using the 2026-05-06 snapshot (a Wednesday, so 2026-05-11 to 2026-06-07).
Until that is done, the 2026 BODS GTFS column is understated by roughly 7–11%
per service and the 2026 row of the "agreement on shared services" table
should not be compared with the other years.

Deduplicating BODS GTFS is a separate and harder problem, discussed below.

## What this says about the three sources

- **TNDS is not the weaker source.** For this route it is exactly right, and
  UK2GTFS's conversion of it reproduces the DfT's own conversion of the same
  underlying TransXChange row for row and second for second.
- **BODS TransXChange is also exactly right here**, which is worth noting
  given that it looks catastrophically low at national level (-59.7% against
  BODS GTFS in 2026). Whatever is wrong with it nationally — coverage, not
  fidelity — is not wrong with it on this route.
- **BODS GTFS's national total is inflated, at least in part, by duplicate
  publication.** The 279 is one route, but the mechanism — one operator's data
  reaching the feed under two NOC records, plus a superseded dataset version
  left running in parallel — is general, and nothing in the feed flags either.
  The comparison report's "largest disagreements" table should therefore be
  read as a list of *candidate duplications*, in either source, rather than of
  TNDS overcounting.
- **The other London entries in that table run the opposite way, and need
  their own check.** EL1, 86, 275, 69, 139, 109, 134, 213, 32 and 222 all show
  TNDS ÷ BODS GTFS ratios of 2.33–3.24, i.e. TNDS roughly 2.4 times BODS
  GTFS — the mirror image of the 279's 0.42. A factor near 2.4 appearing on
  both sides of the same city is a strong hint that the same duplicate-
  publication mechanism operates in TNDS too, on a different set of London
  routes. This analysis does not establish that: it establishes only that for
  the 279 the duplication is in BODS GTFS.
  **Confirmed for the 69** in `route_validation_69_A1_142.md`: TNDS runs its
  term-time and half-term timetables simultaneously, doubling every weekday.
- **Duplication is detectable.** `vehicle_journey_code` survives the DfT's
  conversion and identifies the source TransXChange service and version. Two
  routes whose `vehicle_journey_code` sets overlap are the same service, and
  journeys from a lower version number of a service that also appears at a
  higher version number are superseded. This is a much sharper de-duplication
  key than the stop-set overlap the current route matching uses, and it is
  available in the feed today.

## Caveats

- One route, one snapshot. The 279 was chosen because it was the *largest*
  single disagreement in 2026, so it is by construction not typical; the
  duplication mechanism generalises, the magnitude does not.
- The PDFs are the May 2026 schedule compared against February 2026 feeds.
  The schedules are headed "ST copied 67013" and the minute-level match is
  exact on all four day types, so the timings are unchanged between the two —
  but a route whose times *had* changed could not be checked this way.
- The PDFs give scheduled timing points only, not every stop, and the
  minute-level test uses a single one of them — Manor House Station, the only
  timing point every journey in both directions passes. It is not a check of
  all 97 stops. (The stop-times identity between TNDS and BODS GTFS route
  138482 does cover all 97, but that compares two feeds to each other, not
  either of them to the PDFs.)
- The running schedules count vehicle journeys including garage positioning
  runs as part of the journey row; GTFS trips are the passenger journeys.
  The two coincide here at one row per journey, which is why the counts agree
  exactly, but the mapping is not guaranteed for routes with more complex
  vehicle workings.
- Bank holidays are outside the window, so `calendar_dates` handling is not
  exercised by this test.

## Reproducing this

`scripts/validate_route_279_pdf.R` runs the whole comparison from the four
PDFs and the three 2026 feeds and prints every table above. It needs
`pdftools`, `data.table` and read access to the BODS GTFS snapshot under
`cfg$data_root`.

Sources used:

|Role                |Path                                                      |
|:-------------------|:---------------------------------------------------------|
|Published schedules |`data/example_timetables/Schedule_279-{MT,Fr,Sa,Su}.pdf`   |
|TNDS (TransXChange) |`gtfs/tnds_20260204_merged.zip`, route 2166               |
|BODS (TransXChange) |`gtfs/bods_txc_20260204.zip`, route 693                   |
|BODS (GTFS)         |`OpenBusData/GTFS/20260204/itm_all_gtfs.zip`, routes 10003 and 138482|
|Window              |2026-02-02 to 2026-03-01 (28 days, four of each weekday)  |
