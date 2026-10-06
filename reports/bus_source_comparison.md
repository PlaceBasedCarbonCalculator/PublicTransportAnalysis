# Comparing the three bus timetable sources, 2022–2026



Since the Bus Open Data Service (BODS) became the statutory home of English
bus timetables, three parallel versions of "the bus timetable" exist:

1. **TNDS (TransXChange)** — the Traveline National Dataset, compiled by the
   traveline consortium from local authority and operator data. This was the
   source used for the 2018–2023 analysis years. Converted to GTFS with
   `UK2GTFS::transxchange2gtfs()`.
2. **BODS (TransXChange)** — the raw TransXChange files that operators
   publish directly to the DfT's Bus Open Data Service (its "change archive"
   containing every dataset revision, filtered to the revisions valid on the
   analysis date). Converted to GTFS with `UK2GTFS::transxchange2gtfs()`.
3. **BODS (GTFS)** — the DfT's own GTFS rendering of the BODS data, used
   directly without any UK2GTFS conversion. This is the source used for the
   2024 and 2025 analysis years.

This report compares all three over **five years, one matched snapshot per
year**, to establish whether the differences seen in October 2025 are a
persistent property of the sources or an artefact of one snapshot.


|Year |counting window          |TNDS snapshot            |BODS TransXChange snapshot |BODS GTFS snapshot |
|:----|:------------------------|:------------------------|:--------------------------|:------------------|
|2022 |2022-10-31 to 2022-11-13 |tnds_20221102_merged.zip |bods_txc_20221102.zip      |20221102           |
|2023 |2023-10-30 to 2023-11-12 |tnds_20231101_merged.zip |bods_txc_20231101.zip      |20231101           |
|2024 |2024-10-07 to 2024-10-20 |tnds_20241004_merged.zip |bods_txc_20241007.zip      |20241007           |
|2025 |2025-10-06 to 2025-10-19 |tnds_20251003_merged.zip |bods_txc_20251006.zip      |20251006           |
|2026 |2026-10-05 to 2026-10-18 |tnds_20261002_merged.zip |bods_txc_20261003.zip      |20261003           |

Within a year all three sources are deduplicated with
`UK2GTFS::gtfs_deduplicate()`, then counted with
`UK2GTFS::gtfs_trips_per_zone()` over the **same window** and the
**same plain LSOA21 / DZ22 boundaries**, so every difference below is a
difference in the sources or their conversion, not in the counting method.
(The published trips-per-zone outputs use zones widened for stop access.
This comparison uses the unmodified boundaries: widened zones overlap, so one
stop falls in several of them and a difference between two sources at that
stop would be counted several times over.) Route types were
harmonised to the set used throughout this analysis (0 tram, 1 metro, 2 rail,
3 bus, 4 ferry, **200 coach**); coach is kept distinct from local bus in every
source, and the headline bus comparisons are for `route_type == 3` only.
Everything that is not a bus is covered separately, and for the whole series
rather than these five years, in [`non_bus_modes.md`](non_bus_modes.md).

### Why the series starts in 2022, and not 2021

The comparison needs all three sources at one date. That is not available for
2021:

- The **BODS TransXChange change archive begins in May 2022** — there is no
  earlier archive on the data drive, so a 2021 three-way comparison is
  impossible.
- The only **2021 BODS GTFS** snapshot is from **January 2021**, while the
  nearest TNDS snapshots are December 2020 and September 2021. Any pairing
  spans at least eight weeks of the third national lockdown, during which
  operators were cutting timetables week by week — the date gap, not the
  sources, would dominate the result.

2026 is included in its place, giving five years of genuinely matched
snapshots. Two structural changes fall inside the series and are visible in
the numbers below: **TNDS discontinued its separate NCSD national coach
archive after February 2025**, and the TNDS regional files grew substantially
from the 2025 snapshots onward.

### Which 2026 snapshot

Three 2026 triples exist on the data drive: February, July and October. The
series uses **October**.

February was dropped first, because its TNDS side is distorted by
registrations that expire *inside* the counting window: about a quarter of the
feed's bus trips stopped part-way through it, and the effect was large enough
to exceed the whole measured gap to BODS GTFS, so every February figure was
incomparable with the other years. The mechanism is general and is measured
for every year below — February was simply the window in which it dominated.

July then held the slot until the October snapshots arrived, and has now been
replaced by them. July was the most recent snapshot there was at the time, and
it doubled as the published-timetable validation snapshot. It is also a
*summer* snapshot sitting among four October ones, which is the worst case for
reading TNDS twice over: the weekly-export operators' files end inside the
window, and the school-day journeys that make up much of the restored sibling
service are not running. October is where every other year in this series and
in the main per-year outputs is anchored, so 2026 is now anchored there too.

The July triple has not gone away. It is still converted, and it is still what
`pdf_validation.md` checks against published timetables and what the
zone-level analysis in `lsoa_disagreement.md` is counted over, because the
documents collected for it are valid for that window and no other. The
comparison and the validation therefore no longer describe the same feeds,
which they did while July held this slot.

All five years of both TransXChange sources were converted with one UK2GTFS
build. An earlier version of this report mixed builds across the series, which
made part of the apparent year-on-year improvement in BODS TransXChange coverage
an artefact of the converter rather than of the data.

## Feed-level summary

`Agencies` and `Routes` count the whole converted feed; `Routes in window` and
`Trips in window` count only what operates inside the counting window. **Compare
sources on the windowed columns.** The whole-feed columns are not like-for-like:
a TNDS conversion is kept for the snapshot date ±45 days and a
BODS TransXChange one for ±31, so TNDS carries a longer stretch of calendar and
its whole-feed counts are correspondingly higher. That difference disappears
once anything is counted over a window, which is every other figure in this
report.


|Year |Source              | Agencies| Routes| Routes in window| Trips in window| Missing departure times|
|:----|:-------------------|--------:|------:|----------------:|---------------:|-----------------------:|
|2022 |TNDS (TransXChange) |      943| 16,419|           16,419|       1,162,385|                       0|
|2022 |BODS (TransXChange) |      457| 10,213|           10,213|         460,140|                       0|
|2022 |BODS (GTFS)         |      920| 13,526|           13,526|         893,156|                       0|
|2023 |TNDS (TransXChange) |      901| 14,889|           14,889|       1,181,478|                       0|
|2023 |BODS (TransXChange) |      500| 11,248|           11,248|         520,146|                       0|
|2023 |BODS (GTFS)         |      879| 12,930|           12,930|         871,684|                       0|
|2024 |TNDS (TransXChange) |      848| 15,428|           15,428|       1,155,096|                       0|
|2024 |BODS (TransXChange) |      460| 10,994|           10,994|         489,381|                       0|
|2024 |BODS (GTFS)         |      858| 13,556|           13,556|         906,472|                       0|
|2025 |TNDS (TransXChange) |      806| 15,836|           15,836|       1,224,639|                       0|
|2025 |BODS (TransXChange) |      479| 12,036|           12,036|         477,447|                       0|
|2025 |BODS (GTFS)         |      661| 13,743|           13,743|       1,218,108|                       0|
|2026 |TNDS (TransXChange) |      790| 16,706|           16,706|       1,205,154|                       0|
|2026 |BODS (TransXChange) |      448| 12,555|           12,555|         537,670|                       0|
|2026 |BODS (GTFS)         |      626| 13,801|           13,801|       1,259,744|                       0|

## National bus service totals

Total counted bus (`route_type == 3`) departures from stops, summed over all
zones. The plain boundaries tile the country, so each stop falls in one zone
and a journey is counted once per zone it passes through — levels are
comparable between sources but are still not a national vehicle-trip count,
because a journey crossing several zones contributes to each.

> **These levels are not comparable with versions of this report published
> before August 2026.** Earlier editions counted over the *widened* zones the
> published trips-per-zone outputs use, and those overlap: a stop falls in 2.6
> of them on average, so one bus was counted in every overlapping zone it
> passed through and the national totals were about 2.3 times the figures
> below. Nothing was lost in the change — only 186 of 318,931 stops fall
> outside all plain zones — and the *relative* differences between sources,
> which is what this report is for, barely moved. Compare ratios and per-zone
> agreement across editions, never levels.


|Year |       TNDS|   BODS TXC|   BODS GTFS|TNDS vs BODS GTFS |BODS TXC vs BODS GTFS |
|:----|----------:|----------:|-----------:|:-----------------|:---------------------|
|2022 | 96,090,441| 35,666,970|  96,166,516|-0.1%             |-62.9%                |
|2023 | 94,072,328| 36,654,019|  93,419,342|+0.7%             |-60.8%                |
|2024 | 97,142,272| 38,546,700|  99,528,838|-2.4%             |-61.3%                |
|2025 | 98,084,039| 40,535,409|  99,895,179|-1.8%             |-59.4%                |
|2026 | 98,452,009| 42,104,719| 101,960,799|-3.4%             |-58.7%                |

![plot of chunk totals-chart](figures/comparison-totals-chart-1.png)

## Zone-level agreement

Per-zone average daytime bus trips per hour (`tph_daytime_avg`, the headline
measure used by Carbon & Place), each TransXChange-derived source against the
BODS GTFS baseline.


|Year |Comparison            | Pearson r| Spearman rho| Median abs diff (tph)|Zones within 10% |
|:----|:---------------------|---------:|------------:|---------------------:|:----------------|
|2022 |TNDS vs BODS GTFS     |     0.985|        0.952|                  0.04|71.4%            |
|2022 |BODS TXC vs BODS GTFS |     0.452|        0.300|                  1.49|29.9%            |
|2022 |TNDS vs BODS TXC      |     0.456|        0.290|                  1.79|24.5%            |
|2023 |TNDS vs BODS GTFS     |     0.984|        0.930|                  0.04|72.2%            |
|2023 |BODS TXC vs BODS GTFS |     0.450|        0.293|                  1.36|31.4%            |
|2023 |TNDS vs BODS TXC      |     0.455|        0.297|                  1.53|29.1%            |
|2024 |TNDS vs BODS GTFS     |     0.990|        0.975|                  0.01|81.6%            |
|2024 |BODS TXC vs BODS GTFS |     0.473|        0.321|                  1.43|32.2%            |
|2024 |TNDS vs BODS TXC      |     0.474|        0.316|                  1.45|30.1%            |
|2025 |TNDS vs BODS GTFS     |     0.991|        0.983|                  0.00|82.6%            |
|2025 |BODS TXC vs BODS GTFS |     0.480|        0.346|                  1.29|33.6%            |
|2025 |TNDS vs BODS TXC      |     0.482|        0.340|                  1.32|32.3%            |
|2026 |TNDS vs BODS GTFS     |     0.989|        0.984|                  0.00|81.7%            |
|2026 |BODS TXC vs BODS GTFS |     0.502|        0.367|                  1.26|35.2%            |
|2026 |TNDS vs BODS TXC      |     0.493|        0.355|                  1.21|33.9%            |

![plot of chunk agreement-chart](figures/comparison-agreement-chart-1.png)

## Coverage by country

BODS is an **England-only statutory requirement**; Scottish and Welsh
services reach it only where operators cross the border or publish
voluntarily. TNDS ingests the Scottish and Welsh traveline data directly, so
country-level coverage is where the sources should differ most.


|Year |Country  |  Zones| TNDS mean tph| BODS TXC mean tph| BODS GTFS mean tph| TNDS zero-service zones| BODS TXC zero-service zones| BODS GTFS zero-service zones|
|:----|:--------|------:|-------------:|-----------------:|------------------:|-----------------------:|---------------------------:|----------------------------:|
|2022 |England  | 32,426|         10.13|              4.39|              10.13|                       0|                           0|                            0|
|2022 |Scotland |  6,547|          6.60|              0.00|               6.82|                       0|                           1|                            0|
|2022 |Wales    |  1,878|          6.14|              1.95|               5.14|                       0|                           0|                            0|
|2023 |England  | 32,390|          9.89|              4.50|               9.79|                       0|                           0|                            0|
|2023 |Scotland |  6,546|          6.71|              0.01|               6.78|                       0|                           0|                            0|
|2023 |Wales    |  1,881|          5.09|              2.18|               5.02|                       0|                           0|                            0|
|2024 |England  | 32,391|         10.27|              4.72|              10.51|                       0|                           0|                            0|
|2024 |Scotland |  6,542|          6.67|              0.01|               6.71|                       0|                           0|                            0|
|2024 |Wales    |  1,881|          5.05|              2.24|               5.86|                       0|                           0|                            0|
|2025 |England  | 32,436|         10.37|              4.95|              10.59|                       0|                           0|                            0|
|2025 |Scotland |  6,518|          6.57|              0.00|               6.56|                       0|                           1|                            0|
|2025 |Wales    |  1,882|          5.21|              2.33|               5.02|                       0|                           0|                            0|
|2026 |England  | 32,440|         10.36|              5.07|              10.74|                       0|                           0|                            0|
|2026 |Scotland |  6,507|          6.79|              0.37|               6.94|                       0|                           0|                            0|
|2026 |Wales    |  1,886|          5.04|              2.26|               5.07|                       0|                           0|                            0|

## What the sources actually disagree about

The zone-level statistics say *how much* the sources differ. To say *what*
they differ about, individual bus routes were matched between the three
feeds.

Routes cannot be matched on identifiers — `route_id` is source-specific and
the BODS GTFS `agency_id` is a synthetic code (`OP77`), not a NOC. Instead
each route is identified by its **public route number plus the set of stops
it serves**. Two routes are linked when they share a normalised route number
and their stop sets overlap by at least half; connected components of that
graph are treated as one **service**. Linking runs *within* a source as well
as between them, so a service that one source splits across several
`route_id`s is still compared as a single service. A second pass then links
whatever the numbers failed to pair, on stop overlap alone (80%), because the
sources do not always agree on what a service's public number is.

The unit counted here is **vehicle journeys in the counting window** — a
journey counts once however many stops or zones it passes through. This is a
stricter measure than the zone-level departure counts above.


|Year | Matched services| In all three sources| TNDS only| BODS TXC only| BODS GTFS only|
|:----|----------------:|--------------------:|---------:|-------------:|--------------:|
|2022 |           17,265|                6,863|     1,004|           267|            107|
|2023 |           15,979|                6,717|     1,091|           150|            119|
|2024 |           16,838|                7,757|       929|            33|            166|
|2025 |           17,619|                8,344|     1,300|            51|            122|
|2026 |           18,709|                8,634|       958|            26|            106|

### Missing services, or different frequencies?

For the TNDS / BODS GTFS pair — the two sources that agree most closely at
zone level — the total gap splits into journeys on services the other source
does not carry at all, and journeys on services both carry but time
differently.


|Year | Services in both| TNDS-only services| BODS GTFS-only services| Journeys on TNDS-only services| Journeys on BODS GTFS-only services| Net difference on shared services| Total gap (TNDS - BODS GTFS)|
|:----|----------------:|------------------:|-----------------------:|------------------------------:|-----------------------------------:|---------------------------------:|----------------------------:|
|2022 |           11,813|              1,417|                     732|                        233,011|                             149,681|                           -49,290|                       34,040|
|2023 |           10,954|              1,638|                   1,040|                        287,136|                             200,824|                           -34,466|                       51,846|
|2024 |           11,628|              1,020|                   1,011|                        149,680|                             165,986|                          -142,338|                     -158,644|
|2025 |           11,688|              1,338|                     807|                        138,615|                              80,170|                          -158,410|                      -99,965|
|2026 |           11,790|                978|                     688|                         88,603|                              79,653|                          -182,559|                     -173,609|

![plot of chunk exclusive-chart](figures/comparison-exclusive-chart-1.png)

#### How much of that is really the same service under another name?

The "exclusive" counts above are an upper bound on the coverage gap, because
the matching can only link two routes that agree on a public route number.
Where the two sources disagree about what the number *is* — TNDS carrying the
operator's marketing name, the DfT's GTFS carrying the short code — no link is
ever made and the one service is counted as exclusive to each source, twice
over.

The test below looks for exactly that: a TNDS-only service and a BODS
GTFS-only service that share **both terminals**, run under a recognisably
**identical operator name**, and carry a journey count **within 20%** of each
other. Requiring the operator to match as well keeps generic terminal names
("Bus Station") from pairing unrelated routes.


|Year | Paired services| ...with identical counts| ...with no TNDS route number| TNDS journeys involved| BODS GTFS journeys involved|Share of TNDS-only journeys |Share of BODS GTFS-only journeys |
|:----|---------------:|------------------------:|----------------------------:|----------------------:|---------------------------:|:---------------------------|:--------------------------------|
|2022 |              95|                       91|                            0|                 36,466|                      36,491|15.6%                       |24.4%                            |
|2023 |              91|                       79|                            0|                 36,557|                      36,536|12.7%                       |18.2%                            |
|2024 |             119|                      107|                            0|                 49,040|                      49,085|32.8%                       |29.6%                            |
|2025 |              75|                       64|                            0|                 25,915|                      25,688|18.7%                       |32.0%                            |
|2026 |              43|                       34|                            0|                 16,766|                      16,706|18.9%                       |21.0%                            |

This is a persistent, material share of the apparent gap, present in every year of the series: 12.7%-32.8% of the journeys attributed to TNDS-only services and 18.2%-32.0% of those attributed to BODS GTFS-only services belong to a service the *other* source also carries, under a different name. In 2026, 34 of the 43 pairs match to the journey, which puts them beyond reasonable doubt, and 0 of them have no route number in TNDS at all.


Table: Largest services counted as exclusive to both sources at once, 2026

|From                 |To                   |TNDS number | TNDS journeys|BODS GTFS number | BODS GTFS journeys|Operator             |
|:--------------------|:--------------------|:-----------|-------------:|:----------------|------------------:|:--------------------|
|Victoria Bus Station |Victoria Bus Station |one         |         2,520|1                |              2,520|trentbarton          |
|Friar Lane           |Swallow Drive        |mln         |         2,258|RM               |              2,258|trentbarton          |
|Stonehurst Court     |Stonehurst Court     |18          |         1,700|20               |              1,632|Brighton & Hove      |
|Friar Lane           |Friar Lane           |sky         |         1,474|SN               |              1,474|trentbarton          |
|Corporation Street   |Corporation Street   |all         |         1,046|TA               |              1,046|trentbarton          |
|Whittingham Avenue   |Travel Centre        |24          |           952|24SO             |                952|Stephensons of Essex |
|Coach Park           |Coach Park           |skye        |           876|SNX              |                876|trentbarton          |
|Parliament Street    |Parliament Street    |cal         |           774|CC               |                774|trentbarton          |
|Bus Station          |Bus Station          |SWI         |           768|SW               |                768|Trent Barton         |
|Park and Ride        |Park and Ride        |SHTL        |           756|Shuttle          |                756|Uno                  |
|Tram Park & Ride     |Tram Park & Ride     |con         |           704|C                |                704|trentbarton          |
|Woodthorpe Shops     |Woodthorpe Shops     |12          |           412|Y12              |                412|East Yorkshire       |

Two naming habits produce these pairs, and they carry very different weight. In 2026, TNDS holds the longer name in 12 pairs and the shorter one in 26, with 0 carrying no number at all. One habit is a marketing name or local variant against a bare code - `one`/`1`, `mln`/`RM`, `sky`/`SN`, each agreeing on journeys to within 5%. The other is school-service prefixes and suffixes (`S458`/`458`, `807D`/`808`), a long tail of tiny services: it is why **trentbarton** contributes both the most pairs (8) and the most journeys (10,004 of 16,766).

One caveat on reading the table: where an operator runs many routes between
the same pair of generic terminals, the *aggregate* is sound but an individual
pairing can be wrong, because the counterpart is chosen as the closest journey
count among same-terminal, same-operator candidates. The rows to trust
unreservedly are the ones whose counts match exactly.

`match_route_services()` has a second pass for exactly this case: where the
numbers fail, it links routes on stop overlap alone (80%). It used to consider
only routes left **completely unpaired** by the first pass, which excluded the
operators that cause most of the trouble — a service one source splits across
several `route_id`s sharing a number is linked to *itself* in the first pass, so
it was no longer unpaired and the pass never saw it. It now runs over whole
connected components, confined to components whose routes all come from one
source (precisely the ones that would otherwise be reported as exclusive), so
those multi-registration branded services are candidates.

**The pairs counted above are therefore the residual**, not the whole naming
problem: services the improved matching still fails to link, because their stop
sets overlap by less than the 80% it asks for.

Among the services **both** sources carry, how closely do they agree on the
number of journeys?


|Year | Shared services|Within 2% |Within 10% |Differ by more than 50% |Median absolute difference |
|:----|---------------:|:---------|:----------|:-----------------------|:--------------------------|
|2022 |          11,813|86.4%     |89.8%      |2.5%                    |0.0%                       |
|2023 |          10,954|85.3%     |90.0%      |1.8%                    |0.0%                       |
|2024 |          11,628|87.9%     |90.7%      |1.8%                    |0.0%                       |
|2025 |          11,688|87.5%     |91.0%      |1.4%                    |0.0%                       |
|2026 |          11,790|89.4%     |91.9%      |1.6%                    |0.0%                       |

#### The age of a snapshot relative to its window

Where the agreement on shared services is weaker, the usual reason is not a
converter disagreement about school terms but the age of the snapshot relative
to the counting window.

A TransXChange snapshot carries the registration that is operative *at the
snapshot date* and nothing beyond it. The BODS change archive also holds
future-dated files, so it carries the successor timetable where a TNDS snapshot
does not. Any window extending weeks past a snapshot therefore understates the
source, and it does so lumpily, because operators re-register together — around
school terms above all. This is measured directly for every year and source:
the share of each feed's bus trips whose calendar ends before the **horizon**
— the earlier of the window end and the feed's own last date — and how often
those trips run compared with the ones that last to it. Measuring against the
horizon rather than the window end keeps the two effects apart: a feed trimmed
to a span that stops short of the window would otherwise report every one of
its trips as expiring, which says nothing about the timetable.


|Year |Source              |Window ends |Feed ends  |Horizon    | Bus trips| Ending early| Runs, early| Runs, lasting| Journeys counted| If none expired|
|:----|:-------------------|:-----------|:----------|:----------|---------:|------------:|-----------:|-------------:|----------------:|---------------:|
|2022 |TNDS (TransXChange) |2022-11-13  |2022-12-17 |2022-11-13 | 1,311,735|        20.1%|        0.42|          4.46|        4,785,733|       4,923,052|
|2022 |BODS (TransXChange) |2022-11-13  |2022-12-03 |2022-11-13 |   474,959|        10.0%|        2.45|          4.49|        2,035,628|       2,082,113|
|2022 |BODS (GTFS)         |2022-11-13  |2023-07-21 |2022-11-13 |   890,243|         6.1%|        0.83|          5.64|        4,751,693|       4,824,804|
|2023 |TNDS (TransXChange) |2023-11-12  |2023-12-16 |2023-11-12 | 1,161,689|        12.4%|        1.54|          4.35|        4,649,800|       4,891,243|
|2023 |BODS (TransXChange) |2023-11-12  |2023-12-02 |2023-11-12 |   534,929|        19.5%|        2.09|          4.37|        2,099,728|       2,325,686|
|2023 |BODS (GTFS)         |2023-11-12  |2024-07-19 |2023-11-12 |   856,501|         9.0%|        2.75|          5.63|        4,597,954|       4,727,267|
|2024 |TNDS (TransXChange) |2024-10-20  |2024-11-18 |2024-10-20 | 1,247,781|        11.0%|        1.12|          4.19|        4,809,097|       4,856,024|
|2024 |BODS (TransXChange) |2024-10-20  |2024-11-07 |2024-10-20 |   544,492|         4.3%|        2.82|          4.16|        2,235,229|       2,258,065|
|2024 |BODS (GTFS)         |2024-10-20  |2025-06-27 |2024-10-20 |   878,614|         2.7%|        5.25|          5.67|        4,967,741|       4,988,391|
|2025 |TNDS (TransXChange) |2025-10-19  |2025-11-17 |2025-10-19 | 1,267,930|        10.0%|        1.65|          4.09|        4,875,884|       5,002,593|
|2025 |BODS (TransXChange) |2025-10-19  |2025-11-06 |2025-10-19 |   569,529|         5.1%|        2.71|          4.17|        2,333,486|       2,364,211|
|2025 |BODS (GTFS)         |2025-10-19  |2125-09-28 |2025-10-19 | 1,263,811|         5.1%|        2.15|          4.02|        4,975,849|       5,087,753|
|2026 |TNDS (TransXChange) |2026-10-18  |2026-11-16 |2026-10-18 | 1,332,144|         5.8%|        0.79|          3.83|        4,868,159|       4,933,567|
|2026 |BODS (TransXChange) |2026-10-18  |2026-11-03 |2026-10-18 |   677,565|         7.3%|        1.68|          3.69|        2,402,575|       2,460,320|
|2026 |BODS (GTFS)         |2026-10-18  |2027-12-07 |2026-10-18 | 1,384,654|         2.8%|        1.88|          3.75|        5,041,768|       5,089,979|

In TNDS the share of bus trips ending before the horizon ranges from **5.8% in 2026** up to **20.1% in 2022**. In that worst year they average 0.42 runs against 4.46 for the trips that last to the horizon, and scaling them up would lift the TNDS total from 4,785,733 to about 4,923,052 journeys — a shortfall of **137,319**, against a measured gap to BODS GTFS of 34,040. The expiry is concentrated on a few dates rather than spread through the window — in 2022, 2022-10-29 (142,280 trips); 2022-11-05 (30,802 trips) — which is the signature of collective re-registration rather than of services being withdrawn one by one.

The DfT's BODS GTFS is not immune to the same measure (2.7%-9.0%), which is worth knowing before reading it as the stable baseline, though it is a continuously updated feed rather than a dated registration snapshot, so the two are not measuring quite the same thing.

Every feed reaches at least as far as its own window, so none of the difference above is a conversion trim running out (TNDS is kept to the snapshot date ±45 days).

(`If none expired` scales each early-ending trip's run count by the ratio of
the horizon to the part of it the trip is available for. It assumes the expiring
service would have continued at its own rate, so it is an upper bound quoted
only to size the effect; the trip and date counts either side of it are exact
counts from the feed's `calendar` and `trips` tables.)

None of this is a converter bug, and none of it should be read as a source
carrying less service. The consequence for interpretation is that a snapshot
figure measures **service as registered at the snapshot date**, not service
operated across the window — so a snapshot should either be counted over a
window inside its operative period, or reported with that caveat attached. It is
also a reminder that the counting window, not only the source, affects how
closely the sources agree.

![plot of chunk shared-chart](figures/comparison-shared-chart-1.png)

### Worked examples

The largest services each source carries and the other does not, and the
largest disagreements on services both carry, for **2026**.




Table: Busiest services in TNDS but absent from BODS GTFS, 2026

|Route  |Operator              |From                             |To                               | TNDS journeys| BODS TXC journeys|
|:------|:---------------------|:--------------------------------|:--------------------------------|-------------:|-----------------:|
|Sprint |Kinchbus              |Railway Station                  |Railway Station                  |         3,072|                 0|
|PREM   |Bus4Us                |Coach Station                    |Coach Station                    |         2,590|                 0|
|one    |trentbarton           |Victoria Bus Station             |Victoria Bus Station             |         2,520|                 0|
|mln    |trentbarton           |Friar Lane                       |Swallow Drive                    |         2,258|                 0|
|BL1    |Transpora Bus         |Gleadless Road/Seagrave Crescent |Eckington Way/Station Road       |         2,138|                 0|
|38     |Bee Network           |Lomax Way                        |Piccadilly Gardens               |         1,866|                 0|
|18     |Brighton & Hove       |Stonehurst Court                 |Stonehurst Court                 |         1,700|                 0|
|50     |Brighton & Hove       |Bottom of Davey Drive            |Bottom of Davey Drive            |         1,628|                 0|
|sky    |trentbarton           |Friar Lane                       |Friar Lane                       |         1,474|                 0|
|SC1    |South Pennine         |Sheffield Interchange/B1         |Sheffield Interchange            |         1,268|                 0|
|NOVO   |Bus4Us                |Coach Station                    |Coach Station                    |         1,260|                 0|
|4      |First Cymru Buses Ltd |Morriston Hospital Main Entrance |Morriston Hospital Main Entrance |         1,158|             1,158|


Table: Busiest services in BODS GTFS but absent from TNDS, 2026

|Route |Operator                              |From                   |To                   | BODS GTFS journeys| BODS TXC journeys|
|:-----|:-------------------------------------|:----------------------|:--------------------|------------------:|-----------------:|
|757   |Arriva Beds and Bucks                 |Airport Bus Station    |Airport Bus Station  |              3,360|                80|
|1     |trentbarton                           |Victoria Bus Station   |Victoria Bus Station |              2,520|             2,520|
|RM    |trentbarton                           |Friar Lane             |Swallow Drive        |              2,258|             2,258|
|SP    |Kinchbus                              |Railway Station        |Railway Station      |              1,954|             1,954|
|900   |Northstar                             |Monument Market Street |Interchange          |              1,868|             1,868|
|20    |Brighton & Hove Bus and Coach Company |Stonehurst Court       |Stonehurst Court     |              1,632|               132|
|SN    |trentbarton                           |Friar Lane             |Friar Lane           |              1,474|             1,474|
|15    |Arriva North East                     |Kiora Hall             |Kiora Hall           |              1,426|                 0|
|TM    |trentbarton                           |Bus Station            |Bus Station          |              1,356|             1,356|
|58    |East Yorkshire                        |Cottingham Castle Road |Hessle The Square    |              1,110|             1,110|
|57    |East Yorkshire                        |Bilton Main Road       |Hessle The Square    |              1,084|             1,084|
|56    |East Yorkshire                        |Bilton Main Road       |Bilton Main Road     |              1,080|             1,080|


Table: Largest journey-count disagreements on services both sources carry, 2026

|Route |Operator                              |From                      |To                             | TNDS journeys| BODS GTFS journeys| Difference|Ratio |
|:-----|:-------------------------------------|:-------------------------|:------------------------------|-------------:|------------------:|----------:|:-----|
|279   |Arriva London North                   |Bus Station               |Manor House Station            |         4,372|              9,476|     -5,104|0.46  |
|370   |Arriva London North                   |Mercury Gardens           |Bus Station                    |         2,410|              6,542|     -4,132|0.37  |
|466   |ARRIVA LONDON SOUTH LIMITED           |Westway Common            |Addington Village Interchange  |         2,620|              6,732|     -4,112|0.39  |
|216   |London United                         |Elmsleigh Bus Station     |Elmsleigh Bus Station          |         1,338|              5,246|     -3,908|0.26  |
|96    |ARRIVA LONDON NORTH LIMITED           |Thomas Street             |Bus Station                    |         3,464|              6,912|     -3,448|0.50  |
|235   |LONDON UNITED BUSWAYS LIMITED         |The Three Fishes          |Great West Quarter             |         3,320|              6,640|     -3,320|0.50  |
|290   |London United                         |Arragon Road (TW1)        |Arragon Road (TW1)             |         1,394|              4,638|     -3,244|0.30  |
|19    |ARRIVA LONDON NORTH LIMITED           |Finsbury Park Interchange |Finsbury Park Interchange      |         3,242|              6,484|     -3,242|0.50  |
|406   |London United                         |Cromwell Road Bus Station |High Street                    |         1,378|              4,376|     -2,998|0.31  |
|80    |LONDON GENERAL TRANSPORT SERVICES LTD |Reynold's Close           |Downview and Highdown Prisons  |         3,014|              5,976|     -2,962|0.50  |
|313   |Arriva London North                   |Chingford Station         |Potters Bar Railway Station    |         1,466|              4,398|     -2,932|0.33  |
|418   |London United                         |Cromwell Road Bus Station |Waterloo Road                  |         1,340|              4,260|     -2,920|0.31  |
|410   |ARRIVA LONDON SOUTH LIMITED           |Shotfield                 |Crystal Palace Parade          |         2,808|              5,616|     -2,808|0.50  |
|364   |BLUE TRIANGLE BUSES LIMITED           |Hainault Street           |Ballards Road                  |         2,680|              5,360|     -2,680|0.50  |
|150   |Arriva London North                   |Lambourne Road            |Becontree Heath Leisure Centre |         2,280|              4,906|     -2,626|0.46  |

## Interpretation

- Across 2022-2026 the TNDS bus total runs between -3.4% and +0.7% of the BODS GTFS total, and the BODS TransXChange total between -62.9% and -58.7%.
- Per-zone agreement with BODS GTFS is stable across the series: Pearson r ranges 0.984-0.991 for TNDS and 0.450-0.502 for BODS TransXChange.
- Of TNDS bus journeys, 1.8%-6.2% sit on services BODS GTFS does not carry at all; of BODS GTFS journeys, 1.6%-4.4% sit on services TNDS does not carry.
- Where both sources carry a service, 89.8%-91.9% of services agree on the journey count in the window to within 10%.
- Agreement on shared services is weakest in **2023** (median difference 0.0%, 85.3% of services within 2%) against 86.4%-89.4% within 2% in the other years. In that window 12.4% of TNDS bus trips sit on calendars ending before it does, which is the largest single identified contributor.
- The measured differences above are upper bounds on two counts: route matching cannot link a service the two sources number differently (see the paired-services table), and a TNDS figure is service *as registered at the snapshot date*, not service operated across the window.

### Why the sources differ

- **Coverage obligations differ.** BODS is a statutory requirement for
  English local bus services only. TNDS carries the Scottish and Welsh
  traveline datasets. The BODS GTFS and BODS TransXChange feeds do include
  some Scottish and Welsh services (cross-border operators, voluntary
  publication, and TfW/Traveline Cymru bulk uploads), but coverage outside
  England should be treated as incomplete in both BODS-derived sources.
- **Different compilation routes.** TNDS is compiled and quality-assured by
  traveline from local authority systems; BODS TransXChange is published
  directly by operators (with varying quality and duplication across dataset
  revisions); BODS GTFS is the DfT's automated conversion of the latter.
  Services can legitimately appear in one and not another (e.g. new
  operators publishing only to BODS; local services still only in local
  authority systems).
- **Duplication, in every source — now removed before counting.** The BODS
  change archive contains every revision of every dataset; superseded revisions
  are dropped with `UK2GTFS::txc_filter_files()`, keeping the revision valid on
  the analysis date. Beyond that, every feed of every source passes through
  `UK2GTFS::gtfs_deduplicate()` before it is counted, which removes a journey
  the feed describes twice on the same day. On the October 2026 snapshots
  that is 5.4% of BODS (GTFS)'s trips, 2.2% of TNDS (TransXChange)'s trips and 1.9% of BODS (TransXChange)'s trips.

<!-- Those rates are measured, not derived from any target, so they go stale
     when a feed is reconverted. They are now read out of
     data/dedup_rates.Rds, which scripts/dedup_rates.R harvests from the
     conversion and counting logs of the last run, rather than typed in. If
     that file is missing the text says so instead of printing a stale
     figure. The older hand-measured July 2026 values were 5.2% of the DfT
     GTFS's trips and 2.3% of TNDS's.

     To re-measure by hand: read each feed exactly as read_feed() does
     (gtfs_read, drop shapes, drop stops with no stop_lon, gtfs_clean) and
     compare nrow(trips) before and after gtfs_deduplicate().

     TNDS re-measured 2026-10-03 after the ServiceCode/operator-key
     reconversion of 2026-10-02: 34,668 of 1,482,449 (2.34%), up from
     23,711 of 1,483,772 (1.60%) on 2026-08-08. The rise is a consequence of
     the fix rather than a regression - recovering the registrations that the
     ServiceCode collision had deleted also restored duplicate copies of some
     of them, and gtfs_deduplicate() is now removing those. The residual after
     removal stayed flat (TNDS duplicate runs 2,896 -> 2,920 in
     lsoa_disagreement.md), which is what says the extra duplicates are being
     caught rather than counted.

     DfT GTFS unchanged at 77,151 of 1,469,864 (5.2%) - that feed was not
     reconverted - against 47,242 (3.2%) with match_block = TRUE and
     match_operator = "agency_id". -->


  Two of that function's settings had to be loosened before it worked on these
  feeds, and both are worth knowing when reading any figure here. It originally
  required `block_id` to agree, but the DfT's GTFS fills `block_id` with a hash
  generated per dataset revision, so two copies of one journey never agreed and
  none were removed; and it grouped routes by `agency_id`, but one operator is
  regularly filed under several agency records — Arriva London North is both
  `OP401`/`ARVA` and `OP16197`/`ALNO` — which split duplicate journeys into
  different groups. With both loosened, First Bristol's 21 and A1 land exactly
  on their published timetables and exactly on TNDS.

  What is left is small but not zero: 0.8% of the DfT GTFS's counted runs and
  0.0% of TNDS's are still the same journey twice on a day, because removal is
  deliberately stricter than detection. `lsoa_disagreement.md` measures the
  residual for both sources. Treat every source as capable of counting a bus
  twice, and note that this is one of the few disagreements where an
  independent check can say which source is wrong.
- **Conversion differences.** The TransXChange sources are converted with
  UK2GTFS (this pipeline), while BODS GTFS is converted by the DfT's ITO
  World pipeline. Differences in how each handles operating profiles, bank
  holidays, school-term services and duplicate journeys show up as small
  per-zone differences even where the underlying timetable is identical.
- **The snapshot dates mean different things.** A TNDS snapshot is the
  registration operative on the day it was taken, and it carries nothing
  forward; the BODS change archive contains future-dated files, so it already
  holds the successor timetable. A counting window that reaches weeks past the
  TNDS snapshot therefore understates TNDS — sharply, where operators
  re-register around school terms. The size of this is measured per year above.
  It is not a defect in either source, but it does mean the two columns answer
  slightly different questions.
- **Coach coverage differs by design.** All sources distinguish coach (200)
  from local bus (3), but TNDS's coach data came from the separate NCSD
  archive, discontinued after February 2025 — so TNDS snapshots from 2025
  onward have no coach services at all. Services classified as coach in one
  source and bus in another also remain a real (small) difference.

### Caveats on the route matching

- Matching keys on the **public route number and stop pattern**. Where an
  operator renumbers a route between snapshots, or two genuinely different
  services share a number and a large part of their stop pattern, the match
  can be wrong. The stop-overlap threshold (half the smaller stop set) is a
  deliberate compromise: raising it splits legitimate matches where one
  source omits a branch, lowering it merges distinct services.
- Services counted as "absent" from a source may be present under a
  **different route number** rather than genuinely missing. This is not
  hypothetical: the paired-services table above shows it accounts for a fifth
  to a third of the journeys on "exclusive" services in every year of the
  series. The worked example tables should be read as leads to investigate, not
  as a certified list of gaps.
- The stop-overlap fallback for that case now operates on connected components
  rather than lone routes, so it does reach a service one source splits across
  several `route_id`s under a single number. It remains bounded by the 80%
  overlap it requires: where one source omits a branch or a length of a route,
  the overlap falls short and the pair is left unlinked.
- Journey counts are the number of vehicle journeys operating in the
  counting window under GTFS calendar semantics, including `calendar_dates`
  exceptions. They are not passenger-facing frequencies.
