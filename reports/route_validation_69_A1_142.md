# Checking three more routes against published timetables, 2026

`reports/route_279_pdf_validation.md` checked the largest single TNDS / BODS
GTFS disagreement in the 2026 snapshot — the London **279** — against the
operator's running schedules, and found TNDS and BODS TransXChange exactly
right and BODS GTFS carrying the timetable 2.4 times over. It ended by
recommending that the other large disagreements be checked the same way,
because several of them run in the *opposite* direction.

This report does that for the next three, using timetables supplied for:

|Route|Operator                     |Corridor                                |Comparison-report figures (28-day window)|
|:----|:----------------------------|:---------------------------------------|:----------------------------------------|
|69   |Blue Triangle / Go-Ahead London|Walthamstow Bus Station – Canning Town|TNDS 13,378 vs BODS GTFS 5,622 (2.38×)   |
|A1   |First Bristol, Bath & the West|Bristol Airport – Bristol Bus Station  |TNDS 3,236 vs BODS GTFS 10,082 (0.32×)   |
|142  |Bee Network (Metroline)       |Manchester – Parrs Wood                |TNDS 10,006 vs BODS GTFS 2,645 (3.78×)   |

**The headline is that the 279's verdict does not generalise. On the 69 and
the 142 it is TNDS that carries the timetable twice; on the A1 both sources
are wrong in opposite directions and neither is usable. And two of the three
gaps turn out to be partly an artefact of this pipeline's own counting rather
than of either source.**

## Summary

|Route|Published, 28-day window|TNDS               |BODS TXC           |BODS GTFS, counted correctly|BODS GTFS, as this pipeline counts it|
|:----|-----------------------:|:------------------|:------------------|:---------------------------|:------------------------------------|
|279  |               **8,284**|8,284 **exact**    |8,284 **exact**    |19,622 (+137%)              |19,622                               |
|69   |               **7,624**|13,378 (+75%)      |absent from feed   |7,060 (−7%, the 2 missing days)|5,622 (−26%)                      |
|A1   |               **6,916**|3,236 (−53%)       |10,596 (+53%)      |10,082 (+46%)               |10,082                               |
|142  |          not established|10,006             |176                |6,232                       |2,645                                |

Every one of the four routes is wrong in at least one source, and no source
is right on all of them.

---

## Route 69 — TNDS runs the term-time and half-term timetables at the same time

### The reference

39 TfL running schedules were supplied, covering every day type from `MT`
(Monday–Thursday) through `MoSc` (School Monday), `MoHo` (Non-School Monday),
the night schedules (`MTNt` and friends, headed `N69` but part of route 69 in
every feed), and the Christmas, New Year and Good Friday specials.

They are not all the same vintage, and that matters. The most recent set —
service change **70187, "Ibus Data Import", implemented 9 May 2026** — has
plain `MT`/`Fr`/`Sa`/`Su` schedules with no school variants at all. The
school/holiday set is older: service change **64037, implemented 24 June
2023**. Only one of the two can be what the February 2026 feeds contain, and
the journey counts settle which:

|Schedule set                      |Weekday| Saturday| Sunday|
|:---------------------------------|------:|--------:|------:|
|2023 school/holiday (`MoSc`+`MTNt`)|**286**|  **272**|**204**|
|May 2026 new contract (`MT`+`MTNt`)|    246|      235|    202|
|**Both 2026 feeds**                |**286**|  **272**|**204**|

The feeds carry the 2023-vintage structure, as they must — the new contract
had not started. Counts are day schedule plus night schedule: 273 + 13 = 286
on a weekday, 259 + 13 = 272 on a Saturday, 191 + 13 = 204 on a Sunday. At
Canning Town Bus Station, 281 of those 286 weekday departures match the
schedule to the minute.

**Published total for the window: 20 × 286 + 4 × 272 + 4 × 204 = 7,624.**

### What each feed says

|Date range        |Weekday| TNDS| BODS GTFS| Published|
|:-----------------|:------|----:|---------:|---------:|
|2 Feb, 3 Feb      |Mon,Tue|  574|     **0**|       286|
|4–13 Feb          |Mon–Fri|574 / 572|      286|       286|
|**16–20 Feb** (half-term)|Mon–Fri|  574|  288 / 286|       286|
|23–27 Feb         |Mon–Fri|574 / 572|      286|       286|
|every Saturday    |Sat    |  272|       272|       272|
|every Sunday      |Sun    |  204|       204|       204|
|**Window total**  |       |**13,378**|**7,060**|**7,624**|

BODS GTFS is right on every day it covers; its only error is the two days
before the snapshot date, already documented for the 279.

TNDS runs **574 journeys on a Monday–Thursday where 286 operate**, every week
of the year.

### Why

TNDS route 2286 has seven services. Three are the term-time timetable and two
are the half-term timetable:

|Service| Trips|calendar.txt pattern|calendar_dates in the window|
|:------|-----:|:-------------------|:---------------------------|
|1665   |   286|Monday              |cancelled 16–20 Feb         |
|1660   |   286|Tue–Thu             |cancelled 16–20 Feb         |
|1650   |   286|Friday              |cancelled 16–20 Feb         |
|**1670**|  288|**Mon–Thu**         |**added 16–20 Feb**         |
|**1649**|  286|**Friday**          |**added 16–20 Feb**         |
|1647   |   272|Saturday            |—                           |
|1646   |   204|Sunday              |—                           |

The cancellations are right: the term-time services correctly stop for
half-term week. The additions are the problem. Services 1670 and 1649 are the
half-term timetable, and they should run *only* on 16–20 February — but their
`calendar.txt` rows carry full weekday flags over 31 January to 7 March, so
they already run every Monday–Thursday and every Friday in the period. Under
GTFS semantics an "added" date on a day the calendar already operates is a
no-op, so the exceptions change nothing and both timetables run side by side
all year.

They really are the same timetable twice: services 1665 and 1670 share **286
of 286** Canning Town departure minutes; so do 1660 and 1670, and 1650 and
1649.

BODS GTFS encodes the same thing correctly — services 40243/40315/40242 are
cancelled on the half-term dates and 40309/40306 added — which is why it
lands on the published figure.

---

## Route A1 — an identical re-registration that TNDS dropped and BODS kept twice

### The reference

A National Public Transport Information passenger timetable, *"valid from
31/08/2025 until further notice"*, generated 13 April 2026. It lists every
journey in both directions with ATCO stop codes.

|Direction                    | Mon–Fri| Saturday| Sunday|
|:----------------------------|-------:|--------:|------:|
|Bristol Airport → Bus Station|     128|      110|    110|
|Bus Station → Bristol Airport|     129|      112|    112|
|**Total per operating day**  | **257**|  **222**|**222**|

(The generator prints the Sunday tables twice; the duplicate copies are
identical and are collapsed above.)

**Published total for the window: 20 × 257 + 4 × 222 + 4 × 222 = 6,916.**

Checked against the feeds at the terminus, Airport → Bus Station matches
exactly — 128 / 110 / 110, nothing unmatched in either direction — in TNDS
and in both BODS TransXChange versions. Bus Station → Airport matches 125 of
129 on weekdays, 108 of 112 on Saturdays and 110 of 112 on Sundays; the
handful of differences are minutes, not journeys.

### What each feed says

|Date range     | TNDS| BODS TXC 381| BODS TXC 382| BODS GTFS| Published|
|:--------------|----:|------------:|------------:|---------:|---------:|
|2–3 Feb        |  257|          257|            0|     **0**|       257|
|4–14 Feb       |  257|          257|            0|       257|       257|
|**15 Feb – 1 Mar**|**0**|      257|          257|   **514**|       257|
|**Window total**|**3,236**|**6,916**|    **3,680**|**10,082**|**6,916**|

The calendars say why:

|Feed             |Service block            |Valid                  |
|:----------------|:------------------------|:----------------------|
|TNDS 11073       |the only block           |2026-02-01 → **2026-02-14**|
|BODS TXC 381     |old registration         |2026-02-01 → 2026-03-07|
|BODS TXC 382     |new registration         |2026-02-15 → 2026-03-07|
|BODS GTFS 32450  |old registration         |2026-02-04 → 2026-11-04|
|BODS GTFS 32450  |new registration         |2026-02-15 → 2026-11-15|

The operator re-registered the A1 with effect from 15 February 2026, and the
new registration is an **identical timetable** — BODS TXC routes 381 and 382
share every departure minute (256 of 256 on weekdays, 110 of 110 and 112 of
112 at the weekend).

- **TNDS** expired the old registration on 14 February and never picked up
  the new one, so it reports the A1 as not running at all for the last 15
  days of the window: **3,236, or 47% of the truth.**
- **BODS TransXChange** kept the old registration running past its
  replacement *and* added the new one, so from 15 February it counts every
  journey twice: **10,596, or 153%.** Route 381 on its own is exactly 6,916 —
  the published figure to the journey.
- **BODS GTFS** does the same, both registrations under one `route_id`:
  **10,082, or 146%** (the shortfall against BODS TXC is the two missing days
  at the start).

Note that the `txc_filter_files()` de-duplication described in
`bus_source_comparison.md` did not catch this: the two registrations are
different datasets, not two revisions of one, so keeping "the revision valid
on the analysis date" leaves both.

---

## Route 142 — the same doubling as the 69, but no ground truth available

**The supplied document cannot validate the February window.**
`142_26-SC-0249_Summer.pdf` is the *Summer* timetable, valid **19 July to 29
August 2026**, and it says on its face that it makes "minor changes to the
times of Monday to Friday journeys during the quieter summer period". It also
prints frequent-service blocks as "and every 10 minutes until", so it does
not list journeys individually. Neither an exact February journey count nor a
minute-level check can be taken from it. What follows is therefore a
comparison of the feeds with each other, not against a published truth.

The structure is nevertheless conclusive about duplication. TNDS holds the
142 under **three** `route_id`s where BODS GTFS holds one:

|Weekday pattern|TNDS route 3890| BODS GTFS 70659| Departure minutes in common|
|:--------------|--------------:|---------------:|---------------------------:|
|Mon–Thu        |            102|              51|                      **51**|
|Mon–Fri        |            324|             162|                     **162**|
|Friday         |            102|              51|                      **51**|
|Saturday       |            202|             202|                         202|
|Sunday         |            193|             193|                         193|

On every weekday pattern TNDS carries exactly twice what BODS GTFS carries,
and every BODS GTFS journey is one of the two copies. Saturday and Sunday are
identical in both and are not duplicated — the same signature as route 69, and
the same cause: route 3890's services 1420/1423/1412 are shadowed by
1966/1973/1643, later-dated copies with the same weekday flags.

TNDS route **3980** (248 trips) is different again: it shares **no** departure
minute with 3890, and BODS GTFS has nothing corresponding to it. It may be a
legitimate variant — the published timetable notes that the 142 leaflet
"includes early morning bus 42 journeys" — or a third stale copy. The supplied
document cannot settle it.

BODS TransXChange has 44 Friday journeys and nothing else: for practical
purposes the 142 is absent from it, as the London 69 is.

---

## Two pipeline problems this exposed

### 1. Services defined only in `calendar_dates.txt` are being dropped

This is the larger finding, and it is in this repository's code rather than in
any feed.

GTFS permits a `service_id` to appear only in `calendar_dates.txt`, with no
`calendar.txt` row — the service then runs on exactly the listed dates. The
DfT's national GTFS uses this heavily: **1,544 of its services, carrying
81,566 trips (4.9% of the feed), have no `calendar.txt` row.** TNDS and BODS
TransXChange have none at all.

The fault is in `UK2GTFS::gtfs_trim_dates()`, whose line
`trips <- trips[trips$service_id %in% calendar$service_id, ]` deletes those
trips outright (and whose sibling line drops their `calendar_dates` rows).
`R/route_match.R::route_window_summary()` calls it first thing;
`trip_runs_in_window()` would give the same services zero runs in any case,
because it builds its weekday matrix from `calendar.txt` and discards
exceptions whose service is not in it.

In the 2026 window that removes **414,019 bus journeys — 4.3% of the BODS
GTFS bus total — across 4,793 of its 13,153 bus routes.**

It hits exactly the routes this report is about, because the DfT uses
calendar_dates-only services for **school-holiday substitutions**:

|Route| BODS GTFS as counted| BODS GTFS counted correctly| Journeys restored|
|:----|--------------------:|---------------------------:|-----------------:|
|69   |                5,622|                       7,060|             1,438|
|142  |                2,645|                       6,232|             3,587|
|279  |               19,622|                      19,622|                 0|
|A1   |               10,082|                      10,082|                 0|

For the 142 the effect is severe enough to be qualitative: as counted, BODS
GTFS appeared to run **no Monday–Friday service at all** except during
half-term week. It runs 242–257 weekday journeys throughout.

**This affects the zone-level `tph` figures too, not only the route-level
tables.** `gtfs_trips_per_zone()` *does* apply the right GTFS semantics
further down — it left-joins the calendar, fills missing runs with zero and
then takes `extra` where the calendar contributes nothing — but it calls
`gtfs_trim_dates()` before it gets there, so the trips have already gone.
A minimal fixture makes the point: a feed with one conventional Monday–Friday
service and one calendar_dates-only service adding two Mondays inside the
window returns `runs_Mon_Midday = 4` before the fix and the correct `6`
after. `gtfs_stop_frequency()` trims the same way and is affected the same
way.

So every output of the comparison is understated for BODS GTFS: the national
totals, the per-zone `tph_daytime_avg`, the country tables, the
matched-services counts, the missing-versus-frequency decomposition and the
worked examples.

**Fixed** in `UK2GTFS` (`R/stops_per_week_functions.R`): `gtfs_trim_dates()`
now keeps a service with no `calendar.txt` row when at least one of its
`exception_type = 1` dates falls inside the window, and keeps its exception
rows unclipped (there is no calendar range to clip them to). Services whose
added dates all fall outside the window are still dropped, as a
`calendar.txt` service whose range never reaches the window would be.
Regression tests cover both the trim and `gtfs_trips_per_zone()`.

This repository's `trip_runs_in_window()` still needs the matching change:
seed the service list from the union of `calendar` and `calendar_dates`
rather than from `calendar` alone. Until then, re-running the comparison will
correct the zone-level figures but not the route-level ones.

### 2. The UK2GTFS holiday-profile duplication has a detectable signature

The fault behind routes 69 and 142 — a school-holiday operating profile
written with full weekday flags *and* redundant `calendar_dates` additions —
leaves a fingerprint: an `exception_type = 1` row on a date the service's own
`calendar.txt` already covers.

|Feed              | Added dates in window| Redundant| Services| Routes affected|
|:-----------------|---------------------:|---------:|--------:|---------------:|
|TNDS              |                10,221|     4,984|      746|       **3,891**|
|BODS TransXChange |                18,149|    10,238|    1,078|           2,876|
|BODS GTFS         |                   144|        95|       13|              31|

Both UK2GTFS-converted sources show it at scale; the DfT's own conversion
essentially does not. That places the fault in the TransXChange→GTFS
conversion, not in the underlying registrations.

A redundant addition is a *lead*, not proof — some are harmless — but 3,891
TNDS bus routes carry the signature, and on the two routes examined here it
meant an exact doubling of weekday service.

#### Diagnosis, confirmed in the source XML

The TNDS TransXChange file for the 69
(`TransXChange/data_20260204/L.zip`, `tfl_16-69-_-y05-60306.xml`) declares one
serviced organisation, `SOId_XX-school`, whose `Holidays` ranges include
**2026-02-16 to 2026-02-20**. Its vehicle journeys split into two groups:

|Operating profile fragment                                    | Journeys|Means                     |
|:-------------------------------------------------------------|--------:|:-------------------------|
|`ServicedOrganisationDayType/DaysOfNonOperation/Holidays`      |      858|term time only            |
|`ServicedOrganisationDayType/DaysOfOperation/Holidays`         |  **574**|school holidays only      |

574 is exactly TNDS's excess: the number of journeys it adds to every ordinary
weekday.

`R/transxchange_export.R` handles the two forms asymmetrically:

- **Non-operation** → `VehicleJourneys_exclude` → `exclude_trips()`
  (`R/transxchange_export_functions.R:7`), which *narrows the trip's
  `StartDate`/`EndDate`* where an excluded range covers either end and emits
  `exception_type = 2` rows for ranges in the middle. The calendar really is
  restricted.
- **Operation** → `VehicleJourneys_include` → `list_include_days()`
  (`R/transxchange_export_functions.R:67`), which only expands the ranges into
  a list of dates and emits `exception_type = 1` rows. Nothing touches
  `trips$StartDate`, `trips$EndDate` or `trips$DaysOfWeek` — and Step 4
  (`R/transxchange_export.R:547`) builds `calendar.txt` straight from those
  three columns.

So a holidays-only journey is written with the full weekly calendar over the
whole service period, plus additions on the holiday dates. Under GTFS
semantics an addition on a day the calendar already runs is a no-op, so the
journey runs every week — alongside the term-time journey it was meant to
replace. Hence both the doubling and the redundant-add fingerprint.

#### The fix (implemented)

Make inclusion restrictive, mirroring exclusion: an `include_trips()` beside
`exclude_trips()`, applied at Step 1b.

**The two kinds of inclusion have to be separated first.**
`VehicleJourneys_include` mixes `SpecialDaysOperation/DaysOfOperation`, which
is genuinely additive ("also run on these extra dates" — Christmas specials
and the like), with the serviced-organisation days, which are restrictive.
Restricting both drops any journey whose special days fall outside the service
period: on the 69 that silently deleted the entire Saturday service, whose
journeys carry a `SpecialDaysOperation` for 24 and 29–31 December 2025. The
serviced-organisation ranges are now carried separately as
`VehicleJourneys_so_include` and only those are restrictive.

```r
include_trips <- function(trip_sub, trip_inc) {
  inc <- trip_inc[[trip_sub$trip_id[1]]]
  if (is.null(inc)) return(trip_sub)         # no serviced-organisation inclusion
  inc <- inc[inc$StartDate <= inc$EndDate, ]
  if (nrow(inc) == 0) return(trip_sub[NULL, ])

  # clip the trip to the span the organisation's ranges actually cover
  start <- max(min(inc$StartDate), trip_sub$StartDate)
  end   <- min(max(inc$EndDate),   trip_sub$EndDate)
  if (start > end) return(trip_sub[NULL, ])  # never runs

  trip_sub$StartDate <- start
  trip_sub$EndDate   <- end

  # everything inside the span but outside the ranges is excluded
  span <- seq(start, end, by = "days")
  keep <- unique(do.call(c, Map(seq.Date, inc$StartDate, inc$EndDate,
                                MoreArgs = list(by = "days"))))
  gaps <- span[!span %in% keep]
  trip_sub$exclude_days <- list(sort(unique(c(unlist(trip_sub$exclude_days), gaps))))
  trip_sub
}
```

The `exception_type = 1` rows for serviced organisations are dropped: they add
nothing once the calendar is restricted. Days excluded by the gap calculation
are limited to those the journey's own `DaysOfWeek` would otherwise operate,
and an explicit `SpecialDaysOperation` inclusion still wins over a gap
exclusion, so no date is both added and cancelled for the same service.

#### Verification

Reconverting `tfl_16-69-_-y05-60306.xml` (TNDS London, 4 February 2026) with
the fix, against the published schedule:

|Day                        | Before| After|Published |
|:--------------------------|------:|-----:|:---------|
|Term-time Mon–Thu          |    574|   286|**286**   |
|Half-term Mon–Thu (16–19 Feb)|  574|   288|—         |
|Half-term Fri (20 Feb)     |    574|   286|—         |
|Saturday                   |    272|   272|**272**   |
|Sunday                     |    204|   204|**204**   |

The half-term figures now match what BODS GTFS carries for the same week (288
Mon–Thu, 286 Friday) to the journey. Trip and calendar counts are unchanged;
only `calendar_dates.txt` shrinks.

A wider check over six TransXChange files (two London, four East Midlands)
found the fix changes only routes that use serviced organisations, and
corrects each of them. On Stagecoach route 46, which restricts journeys to a
school's *term* dates, it also removes phantom service the additive treatment
had created:

|Route 46                  | Before| After|In the source XML     |
|:-------------------------|------:|-----:|:---------------------|
|Term-time Wednesday       |     23|    19|19 Mon–Fri journeys   |
|Half-term Wednesday       |     19|    15|4 of them school-only |
|Saturday                  |     23|    15|15 Saturday journeys  |
|Sunday                    |      8| **0**|**no Sunday journeys**|

The additive treatment had not merely failed to restrict: an
`exception_type = 1` row forces a service to run on a date its weekly calendar
does not cover, so Saturday-only journeys were being run on weekdays and
Sundays throughout the school terms. Routes with no serviced-organisation
operation (13W, 17, 73) are byte-identical before and after.

#### Notes on the implementation

- **Both forms on one journey.** A journey may reference one organisation's
  `Holidays` for non-operation and another's `WorkingDays` for operation.
  Exclusions are applied first, then the inclusion intersected.
- **`HolidaysOnly` with no `DaysOfWeek`.** `import_OperatingProfile()` sets
  `DaysOfWeek` to the literal `"HolidaysOnly"`, which `clean_days()` already
  maps to an all-zero week. That case was already correct and is untouched.
- **Bank-holiday inclusions are unchanged.** They arrive through
  `bank_holidays_inc` and are genuinely additive.
- **`service_id` grouping needed no change.** Step 5 keys on `start_date`,
  `end_date`, `DaysOfWeek` and the exception pattern, so restricted trips form
  their own services automatically.
- **Compactness.** A holidays-only service over a long service period gains an
  `exception_type = 2` row per term-time operating day. In practice
  `calendar_dates.txt` still shrank on the sample (1,807 rows to 504), because
  the redundant additions it replaces were more numerous. If that reverses on
  a national run, the alternative is to emit no `calendar.txt` row and only the
  operating dates — the calendar_dates-only shape the DfT uses, which
  `gtfs_trim_dates()` now supports.

**This is not a no-op for the published numbers.** TNDS is the bus source for
the 2018–2023 analysis years, so this reduces the TNDS national bus totals and
will change `trips_per_lsoa21_22_by_mode_*.Rds` for those years. The size of
the change has not been measured nationally — 3,891 routes (23% of TNDS bus
routes) carry the signature, though only 3.1% of trips sit on the affected
services. Reconverting a full TNDS snapshot and comparing totals is the
obvious next step.

---

## What this changes in the earlier reports

**`route_279_pdf_validation.md` attributed the February 2026 anomaly solely to
the two-day window truncation and called the half-term explanation in
`bus_source_comparison.md` wrong. That was too strong.** There are three
mechanisms, and school holidays are involved in two of them:

1. **Window truncation.** The window opens two days before the BODS GTFS
   snapshot. Still the largest single driver, and still evidenced by the
   ratio distribution piling onto 20/18, 24/22 and 28/26 (26.7% of shared
   services in 2026 against 0.6–0.8% in 2024 and 2025).
2. **Calendar_dates-only services dropped by `gtfs_trim_dates()`.** Worth
   4.3% of BODS GTFS bus journeys, concentrated on routes with school-holiday
   variants — which is why it looks like a half-term effect. It is a counting
   bug, not a source difference, and it reaches the zone-level figures as well
   as the route-level ones.
3. **UK2GTFS holiday-profile duplication in TNDS.** A genuine half-term
   handling difference between the converters, inflating TNDS on affected
   routes — the mechanism `bus_source_comparison.md` guessed at, though the
   direction is the reverse of what a "missing half-term service" would
   suggest: TNDS gains journeys rather than losing them.

The recommendation in the 279 report — anchor the window to start on or after
the BODS GTFS snapshot date — still stands, but it is not sufficient on its
own. Both counting problems should be fixed before the 2026 row of the
shared-services table is compared with the other years.

## What now holds across all four routes

- **No source is reliably right.** TNDS was exact on the 279 and 53% low on
  the A1 and roughly double on the 69 and 142. BODS GTFS was 2.4× high on the
  279, exact on the 69, and 46% high on the A1.
- **Duplicate publication is the dominant failure mode**, and it occurs in
  every source: two agency records for one operator (279, BODS GTFS), a
  superseded dataset version left running (279, BODS GTFS), an identical
  re-registration left running alongside its replacement (A1, both BODS
  feeds), and a holiday operating profile that never stops (69 and 142,
  TNDS).
- **Journey-count ratios near 2 or 2.4 are a duplication signature**, not a
  frequency difference. Both directions of the comparison report's
  "largest disagreements" table should be read that way.
- **BODS TransXChange remains unusable outside its coverage.** The London 69
  is absent from it entirely and the Manchester 142 is present only as 44
  Friday journeys, consistent with the −60% national gap.

## Caveats

- Four routes, one snapshot, chosen because they were the largest
  disagreements. The mechanisms generalise; the magnitudes do not.
- The 69's schedules are the 2023 school/holiday set and the May 2026 new
  contract; the 2023 set matches the feeds on journey counts for all three day
  types and on 281 of 286 weekday departure minutes, but the exact revision in
  force in February 2026 was not supplied, so the residual five minutes cannot
  be attributed.
- The A1's published document is dated "from 31/08/2025 until further notice"
  and was generated in April 2026, after the re-registration. Since both
  registrations carry identical times this does not affect the count, but it
  means the document cannot say which registration was intended to be live.
- The 142 has no usable reference at all for the analysis window, as set out
  above. Its entry in the summary table is a feed-to-feed comparison only.
- Minute-level checks use one timing point per route and direction (Canning
  Town for the 69; the two termini for the A1), not every stop.

## Sources used

|Route|Reference document(s)                                    |TNDS route(s)     |BODS TXC route(s)|BODS GTFS route(s)|
|:----|:--------------------------------------------------------|:-----------------|:----------------|:-----------------|
|69   |`data/example_timetables/Schedule_69-*.pdf` (39 files)    |2286              |—                |137853            |
|A1   |`data/example_timetables/EFA01__0000979_TP.pdf`           |11073             |381, 382         |32450             |
|142  |`data/example_timetables/142_26-SC-0249_Summer.pdf`       |3768, 3890, 3980  |8916             |70659             |

Feeds and window as in `route_279_pdf_validation.md`: `gtfs/tnds_20260204_merged.zip`,
`gtfs/bods_txc_20260204.zip`, `OpenBusData/GTFS/20260204/itm_all_gtfs.zip`,
counted over 2026-02-02 to 2026-03-01.
