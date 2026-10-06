# Can a combined TNDS + BODS TransXChange feed beat the DfT's BODS GTFS?

October 2026 snapshots, counted over 5–18 October 2026 (the 14-day study
window). Sources: TNDS TransXChange (extracted 2 October), the BODS
TransXChange change archive (3 October), and the DfT's own BODS GTFS
rendering (3 October).

## The question

The DfT describes its BODS GTFS as BODS TransXChange with TNDS filling the
gaps. If that is what it is, then no service should be missing from the GTFS
unless it is missing from both TransXChange sources — and yet
`reports/zone_pdf_validation_refresh.md` found services absent from both.
That prompted three questions, asked in order of how much turns on them:

1. Does the BODS TransXChange archive hold routes the other two sources lack?
2. Which routes appear in only one of the three datasets?
3. Would converting TNDS and BODS TransXChange **together** give a better
   feed than using the DfT's GTFS?

With two supporting questions: when TNDS stops early, does BODS TransXChange
carry on? And is BODS TransXChange's thinness regional, operator-based, or
random?

## Answers, up front

**The combined feed is not worth building.** It adds 0.5% to the national
zone-level mean over TNDS alone, and for the one purpose where a merge
genuinely helps — filling zones where TNDS has no service at all — BODS
TransXChange is strictly worse than the DfT's GTFS:

| blank zones (no bus service counted) | zones |
|---|---:|
| TNDS alone | 91 |
| TNDS + BODS TransXChange | 33 |
| **TNDS + BODS GTFS** | **7** |
| all three | 7 |

Adding BODS TransXChange on top of TNDS + BODS GTFS changes nothing. If the
aim is coverage, the pairing to use is TNDS + BODS GTFS.

**BODS TransXChange's thinness is regional first and operator-specific
second, and not random.** Two separate mechanisms, which the rest of this
report separates:

- London and Scotland are all but absent — 4.7% and 5.2% of TNDS's journeys
  respectively. Between them they are 86% of all the service BODS
  TransXChange is missing.
- Within England outside London it holds 77% of TNDS's journeys, and that
  shortfall is concentrated: 72% of shared services match TNDS **exactly**,
  while 11% of them sit at or below 60% of TNDS and account for 82% of the
  gap. Those are particular operators, chiefly the Arriva companies,
  Go-Ahead's Brighton & Hove and Metrobus, and Bee Network.

**Almost nothing is missing from both TransXChange sources.** 267 service
groups (6,914 journeys, 0.14% of the national total) are carried only by the
DfT's GTFS — and 46% of those carry a route number *and* operator that TNDS
does have, so they are route-matching artefacts rather than real gaps. The
genuine residue is under 5,000 journeys nationally.

**The early-expiry premise has largely dissolved at a 14-day window.** TNDS
still runs 99.7% of its first-Monday service on the last day of the window,
so there is nothing for BODS TransXChange to rescue inside it. Further out
BODS TransXChange does carry further — at five months it retains 88% against
TNDS's 71% — which matters for a forward-looking feed but not for this
measure.

## What is being counted

Every figure comes from one matched set of service groups, built by
`match_route_services()` — the same function
`reports/bus_source_comparison.md` uses, so the groups are the same ones.
A service group is a public route number plus a set of stops, linked across
sources; `scripts/source_triangulation.R` re-runs the matching because
`combine_year_comparison()` keeps only the cast runs table and discards the
per-route membership this needs.

Two different things are measured per group and source, and conflating them
is the trap this report exists to avoid:

- **carried** — the source has a route for this service whose calendar
  reaches the window at all
- **running** — the source has it operating, with journeys counted, inside
  the window

The comparison report's services table holds only runs. On that table a
service a source carries but does not happen to run that fortnight is
indistinguishable from one it has never heard of: both are a zero. That
mattered here: **24 services look exclusive to the DfT's GTFS on a runs test
and are in fact in TNDS, carried but not running** — among them Stagecoach's
Cumbria EL1 (396 journeys in the GTFS) and First's Portsmouth U2 (392), which
between them are a third of the 1,164 journeys that distinction accounts for.

Regions come from the ATCO prefix of the stops each service calls at, not
from operator names — "Arriva" operates in nine traveline regions and the
question is geographic. 99.8% of running services resolve to a region.

## Which sources hold which services

18,709 service groups. `T` is TNDS, `X` is BODS TransXChange, `G` is the
DfT's BODS GTFS.

**Carried** — does the source have the route at all:

| pattern | services | TNDS journeys | BODS TXC journeys | BODS GTFS journeys |
|:---|---:|---:|---:|---:|
| `TXG` | 8,733 | 2,870,817 | 2,339,428 | 3,018,370 |
| `T--` | 3,423 | 84,609 | 0 | 0 |
| `T-G` | 3,094 | 1,908,821 | 0 | 1,944,909 |
| `-X-` | 2,579 | 0 | 650 | 0 |
| `-XG` | 578 | 0 | 58,791 | 71,575 |
| `--G` | 267 | 0 | 0 | 6,914 |
| `TX-` | 35 | 3,912 | 3,706 | 0 |

**Running** — does it have the service operating in the window:

| pattern | services | TNDS journeys | BODS TXC journeys | BODS GTFS journeys |
|:---|---:|---:|---:|---:|
| `TXG` | 8,634 | 2,827,289 | 2,339,130 | 2,973,474 |
| `---` | 5,227 | 0 | 0 | 0 |
| `T-G` | 3,156 | 1,952,267 | 0 | 1,988,641 |
| `T--` | 958 | 84,757 | 0 | 0 |
| `-XG` | 582 | 0 | 58,921 | 69,661 |
| `--G` | 106 | 0 | 0 | 9,992 |
| `-X-` | 26 | 0 | 818 | 0 |
| `TX-` | 20 | 3,846 | 3,706 | 0 |

Reading these together is the point.

**`T-G`, 3,094 services and 1.9 million TNDS journeys, is the single biggest
block** — services TNDS and the DfT's GTFS both have and BODS TransXChange
does not. This is the DfT's TNDS gap-filling working exactly as advertised,
and it is most of what the GTFS adds over the TransXChange archive it is
nominally built from.

**`-X-`, 2,579 services carried only by BODS TransXChange, carries just 650
journeys.** The change archive holds every revision of every dataset, so it
contains registrations that are not operating in the window — future-dated,
seasonal, or long expired but never withdrawn. As a coverage contribution
this is close to nothing.

**`--G`, 267 services and 6,914 journeys, is what is missing from both
TransXChange sources** — the thing that prompted the question. It is 0.14% of
the national total, and it does not survive inspection intact:

- **123 of the 267 (46%, 1,986 journeys) carry a route number and an operator
  name that TNDS does have**, once operator names are compared
  case-insensitively. These are route-matching failures — the stop sets were
  too different to link — not services TNDS lacks.
- A further group are not registered local bus services at all:
  demand-responsive operations (TransportConnect's "Demand Responsive Area"),
  tourist shuttles (Golden Tours' Harry Potter studio service), works and
  school contracts.
- What is left is a genuine residue of small local services, under 5,000
  journeys nationally.

All 58 of the zones this group fills are in England and all 58 are already
covered by the DfT's GTFS.

The `T--` and `-X-` counts are upper bounds, for the reason
`reports/bus_source_comparison.md` sets out: matching cannot link a service
the two sources number differently, so one service can be counted as
exclusive to each source twice over.

## Why BODS TransXChange is thin: two separate mechanisms

Splitting the TNDS-minus-BODS-TransXChange gap by region, and within each
region into service BODS TransXChange never carries, service it carries but
does not run, and lower journey counts on service it does run:

| region | TNDS | BODS TXC | TXC as % | gap | missing | idle | frequency |
|:---|---:|---:|---:|---:|---:|---:|---:|
| London | 1,350,118 | 63,424 | 4.7 | 1,286,694 | 1,282,766 | 0 | 4,378 |
| Scotland | 447,902 | 23,447 | 5.2 | 424,455 | 427,305 | 0 | −2,850 |
| South East | 621,766 | 392,711 | 63.2 | 229,055 | 55,795 | 100 | 180,028 |
| North West | 504,712 | 321,290 | 63.7 | 183,422 | 34,276 | 4,438 | 146,312 |
| Wales | 167,378 | 74,748 | 44.7 | 92,630 | 77,650 | 0 | 16,000 |
| North East | 215,385 | 139,961 | 65.0 | 75,424 | 12,496 | 36,918 | 29,940 |
| West Midlands | 379,281 | 309,872 | 81.7 | 69,409 | 40,816 | 20 | 34,015 |
| Yorkshire | 326,140 | 272,696 | 83.6 | 53,444 | 22,994 | 1,266 | 42,746 |
| East Midlands | 307,555 | 263,743 | 85.8 | 43,812 | 31,198 | 648 | 33,312 |
| East Anglia | 108,184 | 102,586 | 94.8 | 5,598 | 6,068 | 204 | 1,618 |
| South West | 434,832 | 433,191 | 99.6 | 1,641 | 2,058 | 0 | 2,800 |

Nationally the gap is 2,465,584 journeys: **80.8%** service BODS
TransXChange never carries, **19.8%** lower journey counts on service it
does, and 1.8% service it carries but does not run. (Components can exceed
the gap where BODS TransXChange has journeys TNDS lacks, which is netted off;
the South West's row is small enough for that to dominate it.)

### Mechanism one: London and Scotland, at source

London and Scotland alone are 85.8% of the 1,993,422-journey missing-service
gap; adding Wales makes 89.7%. This is visible directly in the archive, which
is organised by publishing organisation. Of 338 organisations:

- **Scotland has essentially no publishers.** Only Borders Buses and the
  national Stagecoach Group entry match any Scottish operator name. Lothian,
  First Glasgow and McGills are absent outright. BODS is an England-only
  statutory duty, which `reports/bus_source_comparison.md` already notes;
  what is new here is the scale — 5.2% of TNDS's Scottish journeys — and that
  2026 is the first year it is not ~0% (0.0% in 2022 and 2025, 5.4% in 2026).
- **London's operators are present but publish almost nothing for TfL.**
  Metroline Travel Limited's whole entry is 15 TransXChange files, 7 of them
  in a dataset named `Metroline_TfL`. Arriva's London dataset is 15 files and
  its `TFL_BODs_TXCs` dataset 13; Stagecoach's `SC_TfL_Mar26` is 11. These
  are operators running hundreds of TfL routes between them. London local bus
  services are let under TfL contract rather than registered with a traffic
  commissioner, so the BODS publication duty does not reach them, and what is
  published is a token.

This is a statutory boundary, not a data defect, and no merge can fix it. The
DfT's GTFS has London and Scotland only because it ingests TNDS: it counts
106.0% and 102.5% of TNDS's journeys there, against BODS TransXChange's 4.7%
and 5.2%. TNDS is the primary source for both, however the feed is assembled.

### Mechanism two: particular English operators, and it is journeys not files

In England outside London, BODS TransXChange holds 77.2% of TNDS's journeys.
That residue is not spread evenly. Of 8,246 services both sources run there:

- **72.3% have identical journey counts** — not similar, identical
- 11.0% sit at or below 60% of TNDS, and **account for 82.3% of the gap**
- the ten worst operators account for **70.4%** of it

| operator | services | TNDS | BODS TXC | ratio |
|:---|---:|---:|---:|---:|
| Bee Network | 564 | 206,276 | 114,817 | 0.557 |
| Brighton & Hove | 65 | 42,500 | 4,956 | 0.117 |
| Arriva Yorkshire | 79 | 40,888 | 4,830 | 0.118 |
| Arriva Merseyside | 72 | 48,874 | 14,256 | 0.292 |
| Arriva | 108 | 46,808 | 12,234 | 0.261 |
| Metrobus | 69 | 27,726 | 3,122 | 0.113 |
| Arriva Kent and Surrey | 65 | 30,126 | 5,930 | 0.197 |
| Go North East | 175 | 64,814 | 44,814 | 0.691 |
| Arriva (in Beds and Bucks) | 43 | 19,766 | 3,734 | 0.189 |
| Arriva Midlands | 45 | 20,486 | 7,976 | 0.389 |

By contrast National Express West Midlands is at 0.953 and the whole South
West at 0.996.

Three things rule out the obvious explanations:

- **It is not missing files.** Across the ten Arriva and Go-Ahead companies
  above, BODS TransXChange *carries* 90.2% of the services TNDS runs; only
  9.8% (11.2% of the journeys) are absent entirely.
- **It is not short operating periods.** Every Arriva Yorkshire trip in the
  converted BODS feed has a calendar covering all 14 days of the window, and
  98.4% of Metrobus's do. The calendars are fine.
- **It is the journeys themselves.** Arriva Yorkshire: 7,613 trips across 34
  services in TNDS against 1,606 trips across 18 services in BODS
  TransXChange. Metrobus: 13,302 against 1,283.

So for these operators the *converted* BODS feed describes a far smaller
timetable than TNDS does for the same routes over the same dates, and neither
missing services nor truncated calendars explain it. Whether the cause is
partial publication by the operator or the revision filter discarding
siblings it should keep is **not settled here** — see "What this does not
settle" below. What can be said is that it is not a shortage of raw material:
the archive holds 2,761 TransXChange files under Arriva UK Bus alone.

## How far forward each source carries

`scripts/source_forward_horizon.R` counts bus journeys operating on every
date from two weeks before the snapshot to six months after, reading the
**untrimmed** conversion caches — the feeds in `gtfs/` are trimmed to ±45
days (TNDS) and ±31 days (BODS TransXChange), so they would show the trim's
cliff edge rather than each source's own horizon.

Indexed to the first Monday of the window:

| date | days out | TNDS | BODS TXC | BODS GTFS |
|:---|---:|---:|---:|---:|
| 2026-10-07 | 0 | 1.000 | 1.000 | 1.000 |
| 2026-10-14 | 7 | 0.998 | 1.005 | 1.014 |
| 2026-10-21 | 14 | 0.997 | 1.005 | 1.023 |
| 2026-11-04 | 28 | 0.990 | 0.993 | 1.082 |
| 2026-12-02 | 56 | 0.988 | 0.983 | 1.082 |
| 2027-01-31 | 116 | 0.280 | 0.324 | 0.321 |
| 2027-03-02 | 146 | 0.706 | 0.883 | 0.786 |
| 2027-04-01 | 176 | 0.682 | 0.834 | 0.760 |

(The January figures are the Christmas and New Year collapse, not expiry.)

**Inside the window there is nothing to rescue.** TNDS holds 99.7% at 14
days. The early drop-off that motivated halving the window from 28 days to 14
is, at 14 days, a sub-1% effect. BODS TransXChange cannot improve on that
because it is not materially better over the same span.

**Beyond about three months BODS TransXChange is the more durable source**,
at 0.883 against TNDS's 0.706 at five months — consistent with it being a
change archive holding successor revisions TNDS has not yet been given. That
is an argument for BODS TransXChange in a feed meant to describe the
*future*, not one measuring the present.

## Are the TransXChange files the same for the same route?

Everything above is measured after conversion. This section goes to the raw
archives, because the merge question turns on it: a merged feed is only safe
if the duplicate journeys can be recognised and dropped, and they can only be
recognised if the two archives describe the same journey the same way.
`scripts/txc_archive_index.py` indexes every TransXChange file in both — 
17,303 in TNDS (excluding the Isle of Man, which is outside GB and outside
BODS) and 20,203 in BODS.

**The two archives do not share a service identifier.** TNDS carries
Traveline's own construction (`cambs_A2BR_110_20110A`); BODS carries the
traffic commissioner's registration (`PH0005994:151`). Nothing can be joined
on it. The one key they agree on is the national operator code plus the line
name, so a route is identified below as an operator and a route number.

| | TNDS | BODS |
|:---|---:|---:|
| TransXChange files | 17,303 | 20,203 |
| vehicle journeys, all revisions | 1,555,555 | 1,095,942 |
| files with no EndDate (open-ended) | 13.9% | 39.4% |
| routes (operator + line) | 19,230 | 15,904 |

BODS has 17% more files than TNDS and 30% fewer journeys in them, because its
files are smaller and because many are superseded revisions of each other.
That it still holds only 70% of TNDS's journeys *counting every revision it
has ever published* is the clearest single statement of its coverage.

The open-ended share — 39.4% against 13.9% — is the mechanism behind the
forward-horizon curves above. A BODS registration is three times as likely to
declare no end date at all.

### Content, where both archives hold the route

Of 11,031 routes both archives carry, 40 were sampled where each side has few
enough files for the comparison to be about the timetable rather than about
choosing between revisions, and the departure times of their vehicle journeys
compared as multisets:

- **30 of 40 have identical departure times** — not similar, identical
- 93.0% of the sampled TNDS journeys are present in BODS
- 82.8% of the sampled BODS journeys are present in TNDS

Stop sets agree about as often. Across all 8,768 services both converted
feeds carry, **69.7% have identical stop sets**, 81.3% agree to a Jaccard of
0.95 or better, and 91.9% to 0.80 or better. (Jaccard is used here, which is
harsher than the overlap coefficient the route matching itself uses, so this
is not an artefact of how the services were paired.)

So for roughly seven routes in ten the two archives hold the same timetable
over the same stops, and the earlier finding that 72.3% of shared services
have identical journey counts is the same fact seen after conversion. **This
is the one genuinely encouraging result for a merge**: `gtfs_deduplicate()`
matches on route number, stops and times, so it would recognise and drop the
duplicates on about 70% of shared services. On the other 30% it would not,
and those would double-count.

### What this does *not* settle

The archive journey counts cannot be compared with TNDS's for a single
operator, because BODS holds many revisions per route — 3.2 files per line
for Arriva Yorkshire, 3.3 for Metrobus, 13.7 for Brighton & Hove. Summing
them counts the same timetable over and over. So these figures do **not**
show that the operator shortfall in the previous section is the revision
filter discarding service it should keep; settling that needs the filter run
over those operators' files and the survivors counted, which is in progress
and not reported here.

Two further caveats on this section. The operator-code key is imperfect: the
two archives spell some operators differently — National Express West
Midlands is `NXB` in TNDS and something else in BODS, which makes it look
absent from BODS when the converted feeds show it at 95% — so the route
counts and the regional shares below are indicative, not precise, and the
ATCO-based regional figures earlier in this report are the ones to rely on.
And the index covers all modes, not only bus, so London Underground (`LUL`)
and Caledonian MacBrayne (`CALM`) appear among the operators absent from
BODS, correctly but irrelevantly.

With those caveats, the archives corroborate the regional story directly.
Share of each TNDS region's journeys published under an operator code BODS
has heard of at all:

| TNDS region | % |
|:---|---:|
| Scotland | 13.9 |
| London | 53.8 |
| Wales | 55.3 |
| West Midlands | 56.7 |
| North West | 74.2 |
| North East | 77.9 |
| South West | 82.0 |
| Yorkshire | 82.6 |
| East Midlands | 85.5 |
| South East | 88.0 |
| East Anglia | 95.0 |

And the largest TNDS operators with no presence in the BODS archive are
exactly who the regional analysis predicts: Go-Ahead London (84,715
journeys), First Glasgow (46,681), Arriva London (44,477), London Central
(33,182), London General (33,299), Stagecoach Fife (23,678), Lothian (13,099)
and Stagecoach Bluebird (10,406).

## The combined feed, measured

A merged feed cannot be simulated exactly without solving the
de-duplication problem it depends on, so two bounds are given. "Best-of"
takes, per service, whichever source counts more journeys — what a perfect
merge with perfect de-duplication would yield. "Naive sum" adds them, which
is what a merge whose de-duplication fails would yield.

| | journeys in window |
|:---|---:|
| TNDS alone | 4,868,159 |
| BODS TransXChange alone | 2,402,575 |
| DfT BODS GTFS | 5,041,768 |
| union, best-of | 4,951,759 |
| union, naive sum | 7,270,734 |

- union / BODS GTFS = **0.982**
- union / TNDS alone = **1.017**
- naive sum / BODS GTFS = **1.442**

At zone level, on the measure the pipeline actually publishes
(time-weighted daytime trips per hour, mean over 40,833 zones):

| | mean tph |
|:---|---:|
| TNDS | 9.5443 |
| BODS TransXChange | 4.1932 |
| DfT BODS GTFS | 9.8757 |
| union, best-of | 9.5941 |

The merge buys **+0.52%**. 7.2% of zones gain anything at all; where there is
a gain it averages 0.69 tph. And the gain is shrinking as the two sources
converge — it was +1.32% in 2022:

| year | TNDS | BODS TXC | BODS GTFS | union | TXC as % of TNDS | union gain |
|:---|---:|---:|---:|---:|---:|---:|
| 2022 | 9.380 | 3.578 | 9.374 | 9.504 | 38.1 | +1.32% |
| 2023 | 9.162 | 3.672 | 9.090 | 9.249 | 40.1 | +0.95% |
| 2024 | 9.450 | 3.850 | 9.685 | 9.506 | 40.7 | +0.59% |
| 2025 | 9.522 | 4.040 | 9.692 | 9.557 | 42.4 | +0.36% |
| 2026 | 9.544 | 4.193 | 9.876 | 9.594 | 43.9 | +0.52% |

### Why it is so small, and why that was predictable

BODS TransXChange's coverage is almost exactly nested inside TNDS's. Where it
is strong (England outside London) TNDS is strong too, and on 72% of shared
services the two agree to the journey. Where TNDS is weak it is weak as well.
The 58 zones a merge fills are all in England and all already covered by the
DfT's GTFS. BODS TransXChange contributes 59,739 journeys that TNDS lacks —
1.2% of TNDS's total — against the 1,993,422 journeys TNDS has that it is
missing. It is outvoted thirty-three to one.

### The risk side

The naive-sum row is not hypothetical. A merged national feed must drop the
duplicate journeys on the 8,733 services both TransXChange sources carry, or
the count rises 44%. `gtfs_deduplicate()` matches on route number, stops and
times, so it will only catch a duplicate where the two archives describe the
journey identically. The previous section measures how often they do: about
70% of the time, which leaves roughly 2,600 services on which a merge would
double-count.

## Caveats

- **The exclusive counts are upper bounds.** Route matching cannot link a
  service the sources number differently; that inflates `T--` and `-X-` on
  both sides at once. The second matching pass on stop overlap alone reduces
  this but does not eliminate it.
- **Idle services have no region.** `route_window_summary()` records stops
  only for routes with trips in the window, so a carried-but-idle service has
  no stops to take an ATCO prefix from. 99.8% of *running* services resolve
  to a region; 0.9% of idle ones do. The region tables should therefore be
  read as describing running service, which is what they are used for.
- **The DfT's GTFS count is inflated by its own duplication.**
  `reports/bus_source_comparison.md` measures 3.7% of its bus runs as one bus
  counted twice. The union/GTFS ratio of 0.982 should be read against that:
  on a like-for-like basis the union is marginally ahead, not behind. This
  does not change the coverage conclusion, which is about blank zones rather
  than totals.
- **One inverted calendar row sits in each 2026 TransXChange feed** (TNDS
  service 2173, 3 Oct to 1 Oct; BODS TransXChange service 4217, 20 Sep to 12
  Sep). Both lie wholly before the window opens on 5 October, so they
  contribute zero journeys whether or not the UK2GTFS guard for inverted rows
  is present — which matters because `cmp_2026_*` was built shortly before
  that guard was committed, while 2022–2025 were built after it.
- **`study_weeks()` is 2.** Every journey count here is over 14 days and is
  not comparable with figures from the 28-day window without halving.

## Reproducing

```sh
Rscript scripts/source_triangulation.R 2026     # the three-way tables
Rscript scripts/source_forward_horizon.R        # the decay curves
python  scripts/txc_archive_index.py <out_dir>  # index both raw archives
python  scripts/txc_compare_same_route.py <out_dir> 40
```

`source_triangulation.R` reads the `cmp_2026_*` targets and writes
`data/source_triangulation_2026.Rds`; `source_forward_horizon.R` reads the
untrimmed conversion caches and writes `data/source_forward_horizon.Rds`.
Neither is a pipeline target: both answer a one-off question and neither
feeds the published outputs.
