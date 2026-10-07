# Can a combined TNDS + BODS TransXChange feed beat the DfT's BODS GTFS?

October 2026 snapshots, counted over 5–18 October 2026 (the 14-day study
window). Sources: TNDS TransXChange (extracted 2 October), the BODS
TransXChange change archive (3 October), and the DfT's own BODS GTFS
rendering (3 October).

> **The defect this report found has since been fixed.** Investigating why
> BODS TransXChange looked thin turned up a `txc_filter_files()` defect that
> was deleting whole day types from *both* TransXChange sources. It is fixed
> in UK2GTFS and both feeds have been reconverted. The diagnostic sections
> below describe the data as it was with the defect present — that is the
> evidence that motivated the fix, so the tables are left as measured and
> marked **(pre-fix)**. "The fix, and what it changed" near the end reports
> the result. The report's conclusions about the combined feed survive it.

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

**The combined feed is not worth building.** It adds 0.65% to the national
zone-level mean over TNDS alone, and for the one purpose where a merge
genuinely helps — filling zones where TNDS has no service at all — BODS
TransXChange is strictly worse than the DfT's GTFS:

| blank zones (no bus service counted) | pre-fix | after the fix |
|---|---:|---:|
| TNDS alone | 91 | 92 |
| TNDS + BODS TransXChange | 33 | 34 |
| **TNDS + BODS GTFS** | **7** | **7** |
| all three | 7 | 7 |

Adding BODS TransXChange on top of TNDS + BODS GTFS changes nothing. If the
aim is coverage, the pairing to use is TNDS + BODS GTFS. Fixing the filter
defect raised BODS TransXChange's national mean by 18% and still did not
change this: its gaps are where TNDS is strong, so closing them adds little.

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
  Go-Ahead's Brighton & Hove and Metrobus, and Bee Network. Testing three of
  them found two causes, not one: Metrobus and Arriva Yorkshire really do
  publish less than TNDS carries, while Brighton & Hove publishes **dated**
  vehicle journeys instead of recurring patterns, which makes a run-count
  comparison undercount it ninefold. So this layer is real but its size is
  overstated by the measure.

**One new UK2GTFS defect falls out of this, and it is now fixed.** Rule 1 of
`txc_filter_files()` keyed on operator + ServiceCode + StartDate + line, with
the operating day set absent from the key and from the metadata it read at
all, so a publisher filing one document per day type lost all but one. It
affected TNDS as well as BODS. See "The fix, and what it changed" for what
reconverting on the fix produced — in short, BODS TransXChange gained 18% at
zone level, TNDS's bus counts moved 0.08%, and Manchester Metrolink went from
67% short of the independent reading to within 2% of it.

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

## Which sources hold which services (pre-fix)

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

## Why BODS TransXChange is thin: two separate mechanisms (pre-fix)

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

### Mechanism two: particular English operators (pre-fix)

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
missing services nor truncated calendars explain it.

The cause turns out to differ by operator, and the archive section below
settles it: for Metrobus and Arriva Yorkshire the BODS data really is thinner
than TNDS's, while **for Brighton & Hove the ratio of 0.117 is largely an
artefact of how it publishes** — dated journeys rather than recurring
patterns — and not a real shortfall at all. The ratios in this table should
therefore be read as an upper bound on the gap, not a measurement of it.
Which operators are affected is not something this report establishes beyond
the three tested.

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

### The operator shortfall: filter, not archive

The raw archive's journey counts cannot be compared with TNDS's directly,
because BODS holds many revisions per route — 3.2 files per line for Arriva
Yorkshire, 3.3 for Metrobus, 13.7 for Brighton & Hove — and summing them
counts the same timetable over and over. The comparable number is the
journeys in the files that *survive* the revision filter, which is what the
conversion actually sees. Running the same `txc_filter_files()` with the same
filter date over each operator's BODS files:

| operator | BODS files | kept | journeys, all revisions | journeys kept | TNDS journeys | kept ÷ TNDS |
|:---|---:|---:|---:|---:|---:|---:|
| Brighton & Hove | 1,080 | 262 | 68,670 | 13,659 | 11,161 | **1.224** |
| Arriva Yorkshire | 296 | 82 | 9,363 | 2,604 | 7,613 | **0.342** |
| Metrobus | 240 | 72 | 7,660 | 1,815 | 14,305 | **0.127** |

(The filter is run per operator rather than over the whole archive. Its rules
key on service code and operator, so an operator's files are reconciled among
themselves either way, but a cross-operator interaction would not show up.)

**The low two rows are the filter, not the archive.** This table originally
read as showing that Metrobus and Arriva Yorkshire simply publish less than
TNDS carries, with nothing for a fix to recover. That was wrong, and the fix
in "Which rule, exactly" below is what shows it: once rule 1 stops deleting
day types, the same files and the same filter date give

| operator | files kept | journeys kept | journeys ÷ TNDS |
|:---|---:|---:|---:|
| Brighton & Hove | 262 → **571** | 13,659 → 36,636 | 1.224 → 3.283 |
| Arriva Yorkshire | 82 → **199** | 2,604 → 7,140 | 0.342 → **0.938** |
| Metrobus | 72 → **144** | 1,815 → 4,893 | 0.127 → 0.342 |

Arriva Yorkshire reaches parity with TNDS, so its shortfall was the filter
throughout. Metrobus trebles but still holds a third of TNDS's journeys, so it
is part defect and part genuine under-publication. Brighton & Hove rises to
3.3 times TNDS, which is what its dated-journey representation implies — each
journey appears once per weekly block, and the archive holds four blocks — not
over-retention.

**Brighton & Hove is the opposite case, and a different problem entirely.**
What survives holds 22% *more* journeys than TNDS, and the converted feed
duly has 9,670 trips against TNDS's 11,161 — yet it counts 4,956 journeys in
the window against TNDS's 45,838, a ninth. The feeds disagree by nine times
while holding the same number of trips, because they represent time
differently:

| | TNDS | BODS TransXChange |
|:---|:---|:---|
| routes | 74 | 258 |
| trips | 11,161 | 9,670 |
| calendar rows | many | 13 |
| operating period | 18 Aug – 16 Nov | one week at a time (4–10 Oct, 11–17 Oct, 18–24 Oct, 25 Oct – 1 Nov) |
| weekdays flagged per trip | 1, 5, 6 or 7 | 1 (median) |
| trips covering the whole window | 100% | **0%** |
| trips with no day in the window | 0 | 2,383 |

Brighton & Hove publishes **dated** vehicle journeys to BODS — each journey
tied to a single weekday inside a one-week operating period, 2,335 trips per
weekly block — where TNDS carries recurring patterns with a three-month
calendar. Counting journeys as trips × operating days is correct for the
second representation and collapses under the first.

This is a methodological finding rather than a fact about bus service, and it
reaches further than this report: **a run-based comparison between TNDS and
BODS TransXChange is not like-for-like for any operator publishing dated
journeys**, and the per-operator ratios in the previous section will overstate
the shortfall for those operators. It does not affect the coverage
conclusions, which count whether a zone or a service has any service at all,
nor the London and Scotland findings, which are about absence.

### And the filter is dropping complementary day types

The representation difference explains why a run count collapses for Brighton
& Hove, but not the whole magnitude, so the files the filter discards were
compared with the ones it keeps. Restricting to the 538 files whose operating
period actually overlaps the window — the September blocks are legitimately
superseded by the 5 October filter date and prove nothing — it keeps 210
files holding 9,952 journeys and discards 328 holding 23,033.

Those 328 split cleanly in two:

| discarded files overlapping the window | files | journeys |
|:---|---:|---:|
| same service, period **and** day type as a file that was kept — a genuine duplicate revision | 161 | 10,998 |
| a service/period/day-type combination **no kept file has** | 167 | 12,035 |

The second row is loss. And it is not loss of whole services: all 167 belong
to services that survive in some other file, so nothing disappears
altogether. What disappears is day types. Of the 36 Brighton & Hove services
with files overlapping the window, **8 have fewer day types kept than the
archive holds** — a Saturday or a Sunday timetable discarded while the
weekday one survives. Per weekly block the pattern is consistent: of roughly
47 weekday files the filter keeps most, of roughly 45 Saturday files it keeps
11–15, and of roughly 40 Sunday files it keeps 8–11.

So both mechanisms are at work, and neither alone accounts for the ninefold
gap.

### Which rule, exactly

It is **rule 1**, not the overlap reconciliation. Rule 1 deduplicates on
operator + `ServiceCode` + `StartDate` + line, keeping the file with the
highest `RevisionNumber`, and **the operating day set is not in that key — nor
in the metadata `txc_filter_files()` reads at all.** Brighton & Hove publishes
one file per day type for the same service, line and weekly operating period,
so all of them collide on that key and one survives.

Simulating rule 1 on its own over the 497 Brighton files whose period
overlaps the window: it keeps 212 and drops 285. Of those 285,

| dropped by rule 1, against the survivor that displaced it | files |
|:---|---:|
| identical day set — a true duplicate, correctly dropped | 22 |
| **different day set — complementary, wrongly dropped** | 263 |
| no survivor carrying those lines | 0 |

The full filter keeps 210 where rule 1 alone keeps 212, so rules 2 to 4
account for two files and rule 1 for everything else. A representative case:
service `PK0001213:1`, line 2, period 4–10 October — the Sunday file is
dropped and the Monday-to-Friday file kept, both at `RevisionNumber` 47.

This is a different defect from the overlap/sibling one in
`reports/tnds_conversion_investigation.md`, and **the patch already applied
does not cover it**: that patch skips rule 4's reconciliation when two files
share a `CreationDateTime` and differ in `ServiceCode`, whereas here the
`ServiceCode` is identical, the day set differs, and the loss happens in rule
1 before rule 4 is reached. The fix is to read the day set and add it to rule
1's key, which is the same "a finer key can only split a group" move that the
operator was added to the key for. That is a UK2GTFS change, is not made here,
and should be measured the way the last one was — with
`scripts/patch_effect_exact.R`, against the same archives.

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

| journeys in window | pre-fix | after the fix |
|:---|---:|---:|
| TNDS alone | 4,868,159 | 4,872,041 |
| BODS TransXChange alone | 2,402,575 | 2,784,219 |
| DfT BODS GTFS | 5,041,768 | 5,041,768 |
| union, best-of | 4,951,759 | 4,963,481 |
| union, naive sum | 7,270,734 | 7,656,260 |

| | pre-fix | after the fix |
|:---|---:|---:|
| union / BODS GTFS | 0.982 | **0.985** |
| union / TNDS alone | 1.017 | **1.019** |
| naive sum / BODS GTFS | 1.442 | **1.519** |

At zone level, on the measure the pipeline actually publishes
(time-weighted daytime trips per hour, mean over 40,834 zones):

| | pre-fix | after the fix |
|:---|---:|---:|
| TNDS | 9.5443 | 9.5497 |
| BODS TransXChange | 4.1932 | 4.9675 |
| DfT BODS GTFS | 9.8757 | 9.8754 |
| union, best-of | 9.5941 | 9.6118 |

The merge buys **+0.65%** after the fix, against +0.52% before — the fix makes
BODS TransXChange a better feed without making it a more useful *addition*,
because what it gained was service TNDS already had. 9.4% of zones gain
anything at all, up from 7.2%.

The gain was also shrinking year on year as the two sources converged. That
table is left on the unfixed filter throughout, because only 2026 was
reconverted and mixing a fixed 2026 row into four unfixed ones would not be a
trend:

| year (pre-fix) | TNDS | BODS TXC | BODS GTFS | union | TXC as % of TNDS | union gain |
|:---|---:|---:|---:|---:|---:|---:|
| 2022 | 9.380 | 3.578 | 9.374 | 9.504 | 38.1 | +1.32% |
| 2023 | 9.162 | 3.672 | 9.090 | 9.249 | 40.1 | +0.95% |
| 2024 | 9.450 | 3.850 | 9.685 | 9.506 | 40.7 | +0.59% |
| 2025 | 9.522 | 4.040 | 9.692 | 9.557 | 42.4 | +0.36% |
| 2026 | 9.544 | 4.193 | 9.876 | 9.594 | 43.9 | +0.52% |

### Why it is so small, and why that was predictable

BODS TransXChange's coverage is almost exactly nested inside TNDS's. Where it
is strong (England outside London) TNDS is strong too, and on 72% of shared
services the two agree to the journey — 82% after the fix. Where TNDS is weak it is weak as well.
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

## The fix, and what it changed

Two changes to `txc_filter_files()` (UK2GTFS `cb6c1d7`):

1. **Rule 1 keys on the operating day set** alongside the line. Day sets are
   read from `DaysOfWeek` and expanded first, so `MondayToFriday` and the five
   days listed separately compare equal rather than looking like two
   timetables.
2. **Rule 4 leaves files whose operating days do not intersect alone.**
   Without this the first change would have been undone: one file per day type
   shares an operating period exactly, and rule 4's identical-period branch
   would have kept the newest and called the rest duplicate registrations. The
   test is disjointness, not inequality, so a successor registration that
   merely drops Saturday still shares the weekdays with the file it replaces
   and reconciles as before.

Rules 2 and 3 are deliberately unchanged. They split on the ServiceCode alone
and keep the version operative on the filter date; adding the day type there
would stop a revision that *withdraws* Saturday service from closing its
predecessor, resurrecting the withdrawn journeys. That is a worse failure than
the one being fixed and not one the data shows.

Seven tests added; the suite is 1,104 passing, 0 failing.

### How it was measured

Both TransXChange feeds were reconverted from the same archives over the same
window with the same filter date, and the comparison rebuilt. **The DfT's BODS
GTFS was deliberately not reconverted** — `txc_filter_files()` never touches
it — so its column is a fixed point. Its largest per-zone change across 40,834
zones is **exactly zero**, which is what establishes that everything below is
the fix and not the pipeline drifting underneath. `scripts/daytype_fix_effect.R`
asserts this.

### Feed size

| | routes | trips | trips in window |
|:---|:---|:---|:---|
| TNDS | 16,706 → 16,842 (+0.8%) | 1,427,557 → 1,444,062 (+1.2%) | 1,205,154 → 1,217,780 (+1.0%) |
| BODS TransXChange | 12,555 → **15,605 (+24.3%)** | 677,837 → **798,061 (+17.7%)** | 537,670 → **648,081 (+20.5%)** |
| BODS GTFS | unchanged | unchanged | unchanged |

The revision filter now keeps **13,816** of the BODS archive's 20,203 files
where it kept about 9,400. On the TNDS side its removals fell to 255 files
nationally, and to zero in the North East and West Midlands.

### What moved, by mode

Runs — trips times the days they operate, which is what the published measure
counts — in the TNDS feed:

| mode | runs before | runs after | change |
|:---|---:|---:|---:|
| bus | 4,900,457 | 4,904,339 | +0.08% |
| tram | 70,621 | 84,444 | **+19.57%** |
| metro | 165,135 | 165,135 | 0.00% |
| rail | 544 | 544 | 0.00% |
| ferry | 50,938 | 50,938 | 0.00% |
| coach | 2,043 | 2,043 | 0.00% |

**No route group anywhere lost runs.** The change is purely additive: 47 route
groups gained, none lost.

So the honest answer on TNDS is in two parts. Its **bus** counts barely move —
0.08% nationally, because the recovered files are small weekend services on
rural routes. Its **tram** counts move a great deal, and that is the finding
worth having.

### Manchester Metrolink: a two-thirds undercount, repaired

Metrolink's trips nearly quadrupled, which looked like inflation until checked
against the DfT's GTFS — which carries Metrolink and which the fix does not
touch:

| Metrolink, journeys per day in the window | |
|:---|---:|
| TNDS **before** the fix | 475.6 |
| TNDS **after** the fix | **1,463.0** |
| BODS GTFS (independent, untouched) | 1,431.9 |

TNDS was carrying a third of Manchester's tram service. It now agrees with the
independent reading to 2.2%. Per line the pattern is the same: BlueLine's runs
went from 146 in a fortnight — ten a day, for a Manchester tram line — to
2,335. This is in the published outputs, because tram is counted in
`trips_<year>`.

### Zone level, and agreement with the DfT's feed

| mean daytime trips per hour | before | after |
|:---|---:|---:|
| TNDS | 9.5443 | 9.5499 (+0.06%) |
| BODS TransXChange | 4.1932 | **4.9676 (+18.47%)** |
| BODS GTFS | 9.8757 | 9.8757 (0.00%) |

Distance to the DfT's feed, as mean `|log(ratio)|` over zones both carry —
lower is closer:

| | before | after |
|:---|---:|---:|
| TNDS vs BODS GTFS | 0.0876 | 0.0864 |
| BODS TransXChange vs BODS GTFS | 0.4943 | **0.2675** |

BODS TransXChange halves its distance to the DfT's own rendering of the same
upstream data, which is the strongest single sign the fix is right: the two
should agree, and they now agree twice as closely.

### The gain is where the defect predicted it

The defect deleted Saturday and Sunday files, so a real fix must show up on
those days and not spread evenly. Change in BODS TransXChange runs by day:

| Sat | Sun | Mon | Tue | Wed | Thu | Fri |
|---:|---:|---:|---:|---:|---:|---:|
| **+44.3%** | **+20.1%** | +13.7% | +14.8% | +14.8% | +14.8% | +14.6% |

Saturday gains three times what a weekday does. This is the prediction the
diagnosis made, tested after the fact.

### Agreement between the two TransXChange sources

| services both run | before | after |
|:---|---:|---:|
| identical run counts | 72.2% | **81.5%** |
| within 5% | 73.8% | 84.7% |
| BODS TransXChange lower than TNDS | 24.2% | **14.4%** |
| identical stop sets | 69.7% | 70.5% |

### Regions: the English shortfall largely dissolves

BODS TransXChange as a percentage of TNDS's journeys:

| region | before | after |
|:---|---:|---:|
| South East | 63.2 | **86.4** |
| North West | 63.7 | **86.0** |
| Yorkshire | 83.6 | **95.4** |
| East Midlands | 85.8 | **94.6** |
| West Midlands | 81.7 | 88.2 |
| North East | 65.0 | 73.9 |
| East Anglia | 94.8 | 96.1 |
| South West | 99.6 | 100.0 |
| Wales | 44.7 | 48.3 |
| London | 4.7 | 4.9 |
| Scotland | 5.2 | 5.3 |

The "mechanism two" layer of this report — a 77% English shortfall
concentrated on particular operators — was substantially the defect, not the
data. What survives is **mechanism one**: London and Scotland, which are a
statutory boundary and which the fix cannot and does not touch.

### No duplicate inflation

The risk of keying rule 1 more finely is that files which *are* alternative
versions of one timetable both survive and the service is counted twice.
Deduplication is where that would show:

| | removed / trips, before | after |
|:---|---:|---:|
| TNDS | 32,895 / 1,460,452 = 2.25% | **32,895** / 1,476,957 = 2.23% |
| BODS TransXChange | 13,066 / 690,903 = 1.89% | 13,326 / 811,387 = 1.64% |

TNDS removed **exactly the same 32,895 duplicates** while gaining 16,505
trips: the recovered files introduced none at all. BODS TransXChange's
duplicate count rose by 260 against 120,484 trips gained, so 0.2% of what came
back was duplicate. Both rates fell.

### The one side effect, and why it is not the filter choosing definitions

178 stops changed position between the two feeds, 141 by more than 200 m and
112 by more than a kilometre — one by 100 km. I first read this as the
stop-identity non-determinism already on record and attributed it to the
filter keeping more files. **That was wrong**, and the first
thing that kills it is that the TransXChange files **carry no coordinates at
all** — searching the whole October archive for the largest movers returns a
`CommonName` and nothing else. Positions come from a single join to NaPTAN
applied once to the merged feed, and then from `patch_naptan()`, which
overwrites known-bad locations from `UK2GTFS::naptan_replace`. Surviving files
cannot vote on a coordinate they never state.

What the moves actually are is UK2GTFS's own stop-location patch tables
landing in the rebuild where the earlier feed did not have them.

| the 178 moved stops | n | of which > 1 km | at the authoritative position before | after |
|:---|---:|---:|---:|---:|
| in `naptan_replace` (503 known-bad NaPTAN locations) | 143 | 96 | 1 | **143** |
| in `naptan_missing` (42,031 stops absent from NaPTAN) | 22 | 16 | 8 | **14** |
| in neither | 13 | 0 | — | — |

**Both groups move towards correctness, and 165 of the 178 are repairs.**
Every one of the 143 lands on the position `naptan_replace` publishes as the
correct one, against one that was already there; counting all
`naptan_replace` stops present in both feeds, 61 of 246 sat at the corrected
position before and 203 after. The 22 in `naptan_missing` are the other way
round — all 22 have since been added to NaPTAN proper, so that table is stale
for them, and the after feed puts 14 of them on the live NaPTAN position
against 8 before. (This is the group containing the 100 km move,
`1100DEA11988`, which NaPTAN and the TransXChange both call Mannings Way and
which the earlier feed had as Start Point Car Park on the opposite coast — a
stop already on record as flipping between the September and October
editions.) `naptan_replace` is
concentrated exactly where the movement is — 270 of its 503 rows are
Leicestershire (ATCO 260), 123 are national ferry terminals (930) and 93 are
Leicester (269), which is 108, 17 and 19 of the movers respectively. The 13 in
neither table are all Hertfordshire and all under 250 m, and they are the
only candidates for the stop-identity mechanism I originally blamed for all
178.

Two further checks bound how much of this the filter could possibly own.
`patch_naptan()` runs per regional feed and the merge then keeps the first
contributing region's copy — which it does in **246 of 246** cases, 203
patched and 43 not. But only **5** of the 246 are present in more than one
region at all, so which region supplies a stop can account for at most 5 of
the 178 moves, not 178. And every one of the 43 that remain unpatched is
unpatched in *every* region holding it: 40 Scottish ferry terminals sitting
4–163 m off the published correction, which is the ferry stop-identity
question already on record, and 3 in the West Midlands.

**What is not established is why the earlier build patched only 61 of the 246
when this one patched 203.** The leading explanation is that the two builds
did not use the same packaged data — reinstalling UK2GTFS to pick up the fix
resets `inst/extdata/date.txt`, which forces a fresh download of the
separately versioned datasets, and the installed bundle was indeed rewritten
during the session. But the build logs weaken it: *both* builds report
`patch_naptan()` replacing stop locations, so the table was not simply absent
from the first. The per-region counts those logs give (13, 126, 6, 284, 435,
6, 22, 18, 72, 2, 5) also do not reconcile with the 251 `naptan_replace` rows
actually present across the region caches, which is unexplained and may be a
separate defect in how the patch is applied or counted. That is worth its own
look and is recorded as open.

**No service moved with them.** The 178 stops carry exactly 24,192
`stop_times` calls in *both* feeds — 0.042% of 57.5 million — and the 112 that
moved more than a kilometre carry 10,686, or 0.019%. Nothing was gained or
lost at a moved stop; the same departures are now attributed to a different
place.

The consequence for the measurement is that the zone-level before-and-after —
322 zones up and 31 down, 266 tph gained against 38 tph redistributed — is
substantially this data refresh and not the filter. No zone lost service
because a route lost runs, which is the claim that matters, and the mode and
route totals above are unaffected because they do not depend on where a stop
is. The general lesson is sharper than the one I first drew: **a zone-level
before-and-after is only clean if both feeds were built against the same
packaged UK2GTFS data**, and reinstalling the package to apply a code change
can break that silently. Whatever the precise cause of the 61-to-203 change
turns out to be, it is not the filter choosing between TransXChange
definitions, because the files hold no coordinates to choose between.

### What this leaves outdated

`trips_2026` — the published output — along with `coverage` and `non_bus` and
their reports. Since the fix changes TNDS, **every year of the published
series would change if rebuilt**, most visibly in tram. Only 2026 has been
rebuilt here.

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
  counted twice. The union/GTFS ratio of 0.985 should be read against that:
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
Rscript scripts/source_triangulation.R 2026       # the three-way tables
Rscript scripts/source_forward_horizon.R          # the decay curves

python  scripts/txc_archive_index.py   $IDX       # index both raw archives
python  scripts/txc_compare_same_route.py $IDX 40 # same route, both archives

python  scripts/txc_extract_operator.py $IDX $OPS BHBC,WRAY,METR
Rscript scripts/bods_operator_filter_check.R $OPS # survivors against TNDS
Rscript scripts/bods_daytype_filter_check.R  $OPS # what the filter discards
python  scripts/txc_rule1_daytype_sim.py  $OPS/BHBC  # which rule drops them
python  scripts/txc_daytype_collisions.py tnds       # does TNDS collide too?

Rscript scripts/daytype_fix_effect.R              # the fix, end to end
```

`source_triangulation.R` reads the `cmp_2026_*` targets and writes
`data/source_triangulation_2026.Rds`; `source_forward_horizon.R` reads the
untrimmed conversion caches and writes `data/source_forward_horizon.Rds`. The
indexers take an output directory and write their CSVs there; the two filter
checks read the per-operator files `txc_extract_operator.py` lays down and
write `data/bods_operator_filter_check.Rds` and `data/bhbc_filter_detail.Rds`.

None of these is a pipeline target. They answer a one-off question and none
feeds the published outputs. The index CSVs are intermediate and are not kept
in the repository: they are about 40 MB and are rebuilt in roughly an hour.
