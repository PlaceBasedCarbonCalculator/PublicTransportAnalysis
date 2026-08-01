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


|Year |28-day counting window   |TNDS snapshot            |BODS TransXChange snapshot |BODS GTFS snapshot |
|:----|:------------------------|:------------------------|:--------------------------|:------------------|
|2022 |2022-10-31 to 2022-11-27 |tnds_20221102_merged.zip |bods_txc_20221102.zip      |20221102           |
|2023 |2023-10-30 to 2023-11-26 |tnds_20231101_merged.zip |bods_txc_20231101.zip      |20231101           |
|2024 |2024-10-07 to 2024-11-03 |tnds_20241004_merged.zip |bods_txc_20241007.zip      |20241007           |
|2025 |2025-10-06 to 2025-11-02 |tnds_20251003_merged.zip |bods_txc_20251006.zip      |20251006           |
|2026 |2026-07-27 to 2026-08-23 |tnds_20260726_merged.zip |bods_txc_20260725.zip      |20260726           |

Within a year all three sources are counted with
`UK2GTFS::gtfs_trips_per_zone()` over the **same 28-day window** and the
**same widened LSOA zones**, so every difference below is a difference in the
sources or their conversion, not in the counting method. Route types were
harmonised to the set used throughout this analysis (0 tram, 1 metro, 2 rail,
3 bus, 4 ferry, **200 coach**); coach is kept distinct from local bus in every
source, and the headline bus comparisons are for `route_type == 3` only.

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

### Which 2026 snapshot, and why not February

Two 2026 triples exist on the data drive, February and July. The series uses
**July**. February was dropped because its TNDS side is distorted by
registrations that expire *inside* the counting window: about a quarter of the
feed's bus trips stop part-way through it, and the effect is large enough to
exceed the whole measured gap to BODS GTFS, so every February figure was
incomparable with the other four years. The mechanism is general and is
measured for every year below — February was simply the window in which it
dominated. Using July has a second benefit: it is the same snapshot the
published-timetable validation (`pdf_validation.md`) checks against, so the
comparison's most recent year and the PDF validation now describe the same
feeds.

All five years of both TransXChange sources were converted with one UK2GTFS
build. An earlier version of this report mixed builds across the series, which
made part of the apparent year-on-year improvement in BODS TransXChange coverage
an artefact of the converter rather than of the data.

## Feed-level summary

`Agencies` and `Routes` count the whole converted feed; `Routes in window` and
`Trips in window` count only what operates inside the 28-day window. **Compare
sources on the windowed columns.** The whole-feed columns are not like-for-like:
a TNDS conversion is kept for the snapshot date ±45 days and a
BODS TransXChange one for ±31, so TNDS carries a longer stretch of calendar and
its whole-feed counts are correspondingly higher. That difference disappears
once anything is counted over a window, which is every other figure in this
report.


|Year |Source              | Agencies| Routes| Routes in window| Trips in window| Missing departure times|
|:----|:-------------------|--------:|------:|----------------:|---------------:|-----------------------:|
|2022 |TNDS (TransXChange) |      950| 17,115|           17,115|       1,271,716|                       0|
|2022 |BODS (TransXChange) |      457| 10,233|           10,233|         482,781|                       0|
|2022 |BODS (GTFS)         |      920| 13,526|           13,526|         897,228|                       0|
|2023 |TNDS (TransXChange) |      910| 15,472|           15,472|       1,232,783|                       0|
|2023 |BODS (TransXChange) |      500| 11,250|           11,250|         544,662|                       0|
|2023 |BODS (GTFS)         |      879| 12,930|           12,930|         875,935|                       0|
|2024 |TNDS (TransXChange) |      856| 15,742|           15,742|       1,285,098|                       0|
|2024 |BODS (TransXChange) |      459| 11,046|           11,046|         551,598|                       0|
|2024 |BODS (GTFS)         |      858| 13,556|           13,556|         919,507|                       0|
|2025 |TNDS (TransXChange) |      819| 16,362|           16,362|       1,383,585|                       0|
|2025 |BODS (TransXChange) |      477| 12,061|           12,061|         569,443|                       0|
|2025 |BODS (GTFS)         |      661| 13,743|           13,743|       1,392,731|                       0|
|2026 |TNDS (TransXChange) |      808| 17,212|           17,212|       1,248,088|                       0|
|2026 |BODS (TransXChange) |      439| 11,999|           11,999|         485,701|                       0|
|2026 |BODS (GTFS)         |      633| 12,822|           12,822|       1,282,704|                       0|

## National bus service totals

Total counted bus (`route_type == 3`) departures from stops, summed over all
zones (a departure serving stops in more than one zone is counted in each, so
levels are comparable between sources but are not a national vehicle-trip
count).


|Year |        TNDS|    BODS TXC|   BODS GTFS|TNDS vs BODS GTFS |BODS TXC vs BODS GTFS |
|:----|-----------:|-----------:|-----------:|:-----------------|:---------------------|
|2022 | 442,079,664| 139,211,362| 442,407,165|-0.1%             |-68.5%                |
|2023 | 439,242,722| 143,000,981| 427,138,122|+2.8%             |-66.5%                |
|2024 | 443,606,461| 147,214,625| 446,857,322|-0.7%             |-67.1%                |
|2025 | 449,301,260| 152,134,017| 461,108,648|-2.6%             |-67.0%                |
|2026 | 453,210,665| 149,095,182| 474,121,998|-4.4%             |-68.6%                |

![plot of chunk totals-chart](figures/comparison-totals-chart-1.png)

## Zone-level agreement

Per-zone average daytime bus trips per hour (`tph_daytime_avg`, the headline
measure used by Carbon & Place), each TransXChange-derived source against the
BODS GTFS baseline.


|Year |Comparison            | Pearson r| Spearman rho| Median abs diff (tph)|Zones within 10% |
|:----|:---------------------|---------:|------------:|---------------------:|:----------------|
|2022 |TNDS vs BODS GTFS     |     0.981|        0.941|                  0.55|55.0%            |
|2022 |BODS TXC vs BODS GTFS |     0.312|        0.225|                  2.93|25.6%            |
|2022 |TNDS vs BODS TXC      |     0.319|        0.211|                  3.78|16.8%            |
|2023 |TNDS vs BODS GTFS     |     0.989|        0.946|                  0.21|65.2%            |
|2023 |BODS TXC vs BODS GTFS |     0.285|        0.189|                  2.76|26.8%            |
|2023 |TNDS vs BODS TXC      |     0.279|        0.190|                  3.66|19.7%            |
|2024 |TNDS vs BODS GTFS     |     0.992|        0.981|                  0.10|72.0%            |
|2024 |BODS TXC vs BODS GTFS |     0.340|        0.260|                  2.79|28.9%            |
|2024 |TNDS vs BODS TXC      |     0.340|        0.243|                  3.30|22.0%            |
|2025 |TNDS vs BODS GTFS     |     0.987|        0.978|                  0.09|70.2%            |
|2025 |BODS TXC vs BODS GTFS |     0.340|        0.250|                  2.56|31.2%            |
|2025 |TNDS vs BODS TXC      |     0.294|        0.212|                  3.25|22.2%            |
|2026 |TNDS vs BODS GTFS     |     0.982|        0.970|                  0.06|72.8%            |
|2026 |BODS TXC vs BODS GTFS |     0.374|        0.278|                  2.88|29.8%            |
|2026 |TNDS vs BODS TXC      |     0.306|        0.239|                  2.92|27.5%            |

![plot of chunk agreement-chart](figures/comparison-agreement-chart-1.png)

## Coverage by country

BODS is an **England-only statutory requirement**; Scottish and Welsh
services reach it only where operators cross the border or publish
voluntarily. TNDS ingests the Scottish and Welsh traveline data directly, so
country-level coverage is where the sources should differ most.


|Year |Country  |  Zones| TNDS mean tph| BODS TXC mean tph| BODS GTFS mean tph| TNDS zero-service zones| BODS TXC zero-service zones| BODS GTFS zero-service zones|
|:----|:--------|------:|-------------:|-----------------:|------------------:|-----------------------:|---------------------------:|----------------------------:|
|2022 |England  | 33,663|         21.82|              8.28|              21.85|                       0|                           0|                            0|
|2022 |Scotland |  7,326|         15.31|              0.00|              15.92|                       0|                           1|                            0|
|2022 |Wales    |  1,909|         11.36|              2.96|               8.03|                       0|                           0|                            0|
|2023 |England  | 33,659|         21.64|              8.39|              20.95|                       0|                           0|                            0|
|2023 |Scotland |  7,330|         15.71|              0.02|              15.65|                       0|                           0|                            0|
|2023 |Wales    |  1,910|          8.37|              4.99|               8.01|                       0|                           0|                            0|
|2024 |England  | 33,654|         22.22|              8.65|              22.37|                       0|                           0|                            0|
|2024 |Scotland |  7,333|         14.13|              0.01|              14.06|                       0|                           0|                            0|
|2024 |Wales    |  1,908|          8.11|              4.21|               9.19|                       0|                           0|                            0|
|2025 |England  | 33,669|         21.97|              8.98|              22.71|                       0|                           0|                            0|
|2025 |Scotland |  7,320|         16.65|              0.00|              16.44|                       0|                           1|                            0|
|2025 |Wales    |  1,907|          8.19|              3.46|               8.04|                       0|                           0|                            0|
|2026 |England  | 33,666|         22.33|              8.79|              23.63|                       0|                           0|                            0|
|2026 |Scotland |  7,332|         15.72|              0.01|              15.49|                       0|                           0|                            0|
|2026 |Wales    |  1,909|          8.18|              3.34|               7.62|                       0|                           0|                            0|

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

The unit counted here is **vehicle journeys in the 28-day window** — a
journey counts once however many stops or zones it passes through. This is a
stricter measure than the zone-level departure counts above.


|Year | Matched services| In all three sources| TNDS only| BODS TXC only| BODS GTFS only|
|:----|----------------:|--------------------:|---------:|-------------:|--------------:|
|2022 |           17,045|                6,904|       986|           252|            215|
|2023 |           16,043|                6,751|     1,107|           139|            120|
|2024 |           15,815|                7,807|       926|            29|            172|
|2025 |           15,905|                8,419|     1,311|            42|            119|
|2026 |           20,724|                6,428|       763|           739|            124|

### Missing services, or different frequencies?

For the TNDS / BODS GTFS pair — the two sources that agree most closely at
zone level — the total gap splits into journeys on services the other source
does not carry at all, and journeys on services both carry but time
differently.


|Year | Services in both| TNDS-only services| BODS GTFS-only services| Journeys on TNDS-only services| Journeys on BODS GTFS-only services| Net difference on shared services| Total gap (TNDS - BODS GTFS)|
|:----|----------------:|------------------:|-----------------------:|------------------------------:|-----------------------------------:|---------------------------------:|----------------------------:|
|2022 |           11,642|              1,407|                     913|                        484,304|                             326,429|                           -38,919|                      118,956|
|2023 |           10,978|              1,652|                   1,030|                        594,482|                             390,893|                           130,786|                      334,375|
|2024 |           11,811|              1,026|                   1,014|                        301,431|                             330,842|                          -196,371|                     -225,782|
|2025 |           11,737|              1,354|                     802|                        276,498|                             147,685|                          -462,558|                     -333,745|
|2026 |            9,428|                825|                     452|                        240,734|                             177,328|                          -533,913|                     -470,507|

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
|2022 |              87|                       78|                           47|                 68,132|                      67,225|14.1%                       |20.6%                            |
|2023 |              83|                       71|                           49|                 66,458|                      65,773|11.2%                       |16.8%                            |
|2024 |             110|                       93|                           47|                 92,353|                      92,792|30.6%                       |28.0%                            |
|2025 |              60|                       50|                           18|                 51,595|                      50,527|18.7%                       |34.2%                            |
|2026 |              25|                       22|                            5|                 23,312|                      23,167|9.7%                        |13.1%                            |

This is a persistent, material share of the apparent gap, present in every year of the series: 9.7%-30.6% of the journeys attributed to TNDS-only services and 13.1%-34.2% of those attributed to BODS GTFS-only services belong to a service the *other* source also carries, under a different name. In 2026, 22 of the 25 pairs match to the journey, which puts them beyond reasonable doubt, and 5 of them have no route number in TNDS at all.


Table: Largest services counted as exclusive to both sources at once, 2026

|From                    |To                           |TNDS number | TNDS journeys|BODS GTFS number | BODS GTFS journeys|Operator             |
|:-----------------------|:----------------------------|:-----------|-------------:|:----------------|------------------:|:--------------------|
|Victoria Bus Station    |Victoria Bus Station         |one         |         5,040|1                |              5,040|trentbarton          |
|Friar Lane              |Swallow Drive                |mln         |         4,516|RM               |              4,516|trentbarton          |
|Stonehurst Court        |Stonehurst Court             |18          |         3,400|20               |              3,287|Brighton & Hove      |
|Whittingham Avenue      |Travel Centre                |24          |         1,904|24SO             |              1,904|Stephensons of Essex |
|Parliament Street       |Parliament Street            |cal         |         1,548|CC               |              1,548|trentbarton          |
|Tram Park & Ride        |Tram Park & Ride             |con         |         1,408|C                |              1,408|trentbarton          |
|East Beach              |Leigh-on-Sea Railway Station |99          |         1,008|99OT             |              1,008|Ensign Bus           |
|Woodthorpe Shops        |Woodthorpe Shops             |12          |           824|Y12              |                824|East Yorkshire       |
|Broad Marsh Bus Station |Broad Marsh Bus Station      |rv          |           704|RV1              |                704|trentbarton          |
|Rail Station Car Park   |Rail Station Car Park        |(blank)     |           528|Walk and Ride    |                528|PC Coaches           |
|Travel Centre           |Travel Centre                |14          |           400|14SO             |                376|Stephensons of Essex |
|Market Street           |Market Street                |(blank)     |           304|ZIP              |                304|Dews Coaches         |

Two naming habits produce these pairs, and they carry very different weight. In 2026, TNDS holds the longer name in 6 pairs and the shorter one in 12, with 5 carrying no number at all. One habit is a marketing name or local variant against a bare code - `one`/`1`, `mln`/`RM`, `cal`/`CC`, each agreeing on journeys to within 5%. The other is school-service prefixes and suffixes (`S458`/`458`, `807D`/`808`), a long tail of tiny services: it is why **Stephensons of Essex** contributes the most pairs (6) while **trentbarton** contributes the most journeys (13,216 of 23,312).

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
|2022 |          11,642|59.9%     |69.7%      |8.9%                    |0.0%                       |
|2023 |          10,978|80.4%     |84.5%      |3.7%                    |0.0%                       |
|2024 |          11,811|75.1%     |79.3%      |2.7%                    |0.0%                       |
|2025 |          11,737|74.8%     |78.8%      |4.3%                    |0.0%                       |
|2026 |           9,428|80.8%     |85.7%      |3.6%                    |0.0%                       |

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
|2022 |TNDS (TransXChange) |2022-11-27  |2022-12-17 |2022-11-27 | 1,369,015|        20.9%|        0.91|          8.64|        9,618,695|      10,094,888|
|2022 |BODS (TransXChange) |2022-11-27  |2022-12-03 |2022-11-27 |   496,885|        10.9%|        2.79|          9.44|        4,326,816|       4,486,302|
|2022 |BODS (GTFS)         |2022-11-27  |2023-07-21 |2022-11-27 |   892,481|         6.4%|        1.41|         11.30|        9,499,739|       9,703,933|
|2023 |TNDS (TransXChange) |2023-11-26  |2023-12-16 |2023-11-26 | 1,205,340|        17.9%|        2.70|          8.94|        9,435,368|      10,235,397|
|2023 |BODS (TransXChange) |2023-11-26  |2023-12-02 |2023-11-26 |   555,683|        15.3%|        2.31|          9.13|        4,495,292|       5,036,791|
|2023 |BODS (GTFS)         |2023-11-26  |2024-07-19 |2023-11-26 |   859,163|        10.7%|        4.19|         11.37|        9,100,993|       9,585,307|
|2024 |TNDS (TransXChange) |2024-11-03  |2024-11-18 |2024-11-03 | 1,273,488|        23.9%|        3.72|          8.77|        9,628,172|      10,227,422|
|2024 |BODS (TransXChange) |2024-11-03  |2024-11-07 |2024-11-03 |   554,471|         7.6%|        6.33|          8.56|        4,654,008|       4,787,679|
|2024 |BODS (GTFS)         |2024-11-03  |2025-06-27 |2024-11-03 |   883,569|         6.2%|        9.52|         11.27|        9,853,954|      10,075,415|
|2025 |TNDS (TransXChange) |2025-11-02  |2025-11-17 |2025-11-02 | 1,319,077|        24.7%|        3.99|          8.54|        9,786,316|      10,635,878|
|2025 |BODS (TransXChange) |2025-11-02  |2025-11-06 |2025-11-02 |   576,009|         7.7%|        6.51|          8.50|        4,805,860|       4,995,705|
|2025 |BODS (GTFS)         |2025-11-02  |2125-09-28 |2025-11-02 | 1,298,108|         8.6%|        3.86|          8.22|       10,120,061|      10,590,978|
|2026 |TNDS (TransXChange) |2026-08-23  |2026-09-09 |2026-08-23 | 1,433,756|        20.6%|        0.87|          8.41|        9,832,604|      10,136,628|
|2026 |BODS (TransXChange) |2026-08-23  |2026-08-25 |2026-08-23 |   492,518|         5.0%|        1.36|          9.95|        4,691,140|       4,783,194|
|2026 |BODS (GTFS)         |2026-08-23  |2027-08-02 |2026-08-23 | 1,342,877|         6.0%|        3.57|          8.15|       10,303,111|      10,622,332|

In TNDS the share of bus trips ending before the horizon ranges from **17.9% in 2023** up to **24.7% in 2025**. In that worst year they average 3.99 runs against 8.54 for the trips that last to the horizon, and scaling them up would lift the TNDS total from 9,786,316 to about 10,635,878 journeys — a shortfall of **849,562**, against a measured gap to BODS GTFS of 333,745. The expiry is concentrated on a few dates rather than spread through the window — in 2025, 2025-10-25 (133,432 trips); 2025-10-18 (33,580 trips) — which is the signature of collective re-registration rather than of services being withdrawn one by one.

The DfT's BODS GTFS is not immune to the same measure (6.0%-10.7%), which is worth knowing before reading it as the stable baseline, though it is a continuously updated feed rather than a dated registration snapshot, so the two are not measuring quite the same thing.

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

|Route |Operator                      |From                                   |To                                     | TNDS journeys| BODS TXC journeys|
|:-----|:-----------------------------|:--------------------------------------|:--------------------------------------|-------------:|-----------------:|
|TRAM  |Nottingham Express Transit    |Clifton South Tram Stop                |Clifton South Tram Stop                |        14,740|                 0|
|SHTL  |Gatwick Interterminal Shuttle |Gatwick North Terminal Shuttle Station |Gatwick North Terminal Shuttle Station |        13,776|                 0|
|sky   |trentbarton                   |Friar Lane                             |Friar Lane                             |         5,896|                 0|
|PREM  |Bus4Us                        |Coach Station                          |Coach Station                          |         5,180|                 0|
|one   |trentbarton                   |Victoria Bus Station                   |Victoria Bus Station                   |         5,040|                 0|
|SWI   |Trent Barton                  |Bus Station                            |Bus Station                            |         4,608|                 0|
|mln   |trentbarton                   |Friar Lane                             |Swallow Drive                          |         4,516|                 0|
|all   |trentbarton                   |Corporation Street                     |Corporation Street                     |         4,184|                 0|
|skye  |trentbarton                   |Coach Park                             |Coach Park                             |         3,504|                 0|
|18    |Brighton & Hove               |Stonehurst Court                       |Stonehurst Court                       |         3,400|                 0|
|vil   |trentbarton                   |Market Place                           |Bus Station                            |         3,296|                 0|
|50    |Brighton & Hove               |Bottom of Davey Drive                  |Bottom of Davey Drive                  |         3,256|                 0|


Table: Busiest services in BODS GTFS but absent from TNDS, 2026

|Route |Operator                              |From                       |To                         | BODS GTFS journeys| BODS TXC journeys|
|:-----|:-------------------------------------|:--------------------------|:--------------------------|------------------:|-----------------:|
|10    |Metrobus                              |North Terminal Bus Station |North Terminal Bus Station |              7,172|               784|
|757   |Arriva Beds and Bucks                 |Airport Bus Station        |Airport Bus Station        |              6,720|               160|
|1     |trentbarton                           |Victoria Bus Station       |Victoria Bus Station       |              5,040|             5,040|
|RM    |trentbarton                           |Friar Lane                 |Swallow Drive              |              4,516|             4,516|
|100   |Metrobus                              |Oriel School               |Oriel School               |              3,728|               332|
|2     |Metrobus                              |Yewlands Walk              |Yewlands Walk              |              3,676|               288|
|HE    |Go Ahead Luton Parkway                |HereEast / The Yard        |HereEast / The Yard        |              3,620|                60|
|C     |Fastrack (Arriva Kent Thameside)      |Manor Way Roundabout       |Manor Way Roundabout       |              3,363|             2,295|
|20    |Brighton & Hove Bus and Coach Company |Stonehurst Court           |Stonehurst Court           |              3,287|               341|
|20    |Metrobus                              |Orchard Drive              |Orchard Drive              |              3,272|               376|
|SN    |trentbarton                           |Friar Lane                 |Friar Lane                 |              2,948|             2,948|
|3     |Metrobus                              |Brettingham Close          |Brettingham Close          |              2,776|               212|


Table: Largest journey-count disagreements on services both sources carry, 2026

|Route |Operator                              |From                           |To                            | TNDS journeys| BODS GTFS journeys| Difference|Ratio |
|:-----|:-------------------------------------|:------------------------------|:-----------------------------|-------------:|------------------:|----------:|:-----|
|279   |Arriva London North                   |Bus Station                    |Manor House                   |         8,284|             18,492|    -10,208|0.45  |
|150   |Arriva London North                   |Becontree Heath Leisure Centre |Lambourne Road                |         4,520|             13,560|     -9,040|0.33  |
|74    |National Express West Midlands        |Colmore Circus                 |Colmore Circus                |        10,900|             19,876|     -8,976|0.55  |
|216   |London United                         |Elmsleigh Bus Station          |Elmsleigh Bus Station         |         2,616|             11,076|     -8,460|0.24  |
|466   |ARRIVA LONDON SOUTH LIMITED           |Westway Common                 |Addington Village Interchange |         5,204|             13,408|     -8,204|0.39  |
|X38   |Trent Barton                          |Corporation Street             |Corporation Street            |        12,276|              4,092|      8,184|3.00  |
|C1    |First Essex                           |Hospital                       |Hospital                      |           824|              8,872|     -8,048|0.09  |
|2     |First Wessex, Dorset & South Somerset |Kings Statue                   |King Statue K8 Approach       |           918|              8,541|     -7,623|0.11  |
|50    |National Express West Midlands        |Moor St Selfridges             |Moor St Selfridges            |        11,488|             18,648|     -7,160|0.62  |
|1     |First Wessex, Dorset & South Somerset |Kings Statue                   |Rip Croft Shelter             |           756|              7,855|     -7,099|0.10  |
|3     |First Portsmouth, Fareham & Gosport   |Bus Station                    |South Parade Pier             |         4,152|             10,869|     -6,717|0.38  |
|290   |London United                         |Arragon Road (TW1)             |Arragon Road (TW1)            |         2,788|              9,464|     -6,676|0.29  |
|235   |LONDON UNITED BUSWAYS LIMITED         |The Three Fishes               |Great West Quarter            |         6,640|             13,280|     -6,640|0.50  |
|96    |ARRIVA LONDON NORTH LIMITED           |Thomas Street                  |Bus Station                   |         6,908|             13,540|     -6,632|0.51  |
|1     |First Portsmouth, Fareham & Gosport   |South Parade Pier              |The Hard Interchange          |         4,120|             10,720|     -6,600|0.38  |

## Interpretation

- Across 2022-2026 the TNDS bus total runs between -4.4% and +2.8% of the BODS GTFS total, and the BODS TransXChange total between -68.6% and -66.5%.
- Per-zone agreement with BODS GTFS is stable across the series: Pearson r ranges 0.981-0.992 for TNDS and 0.285-0.374 for BODS TransXChange.
- Of TNDS bus journeys, 2.4%-6.3% sit on services BODS GTFS does not carry at all; of BODS GTFS journeys, 1.5%-4.3% sit on services TNDS does not carry.
- Where both sources carry a service, 69.7%-85.7% of services agree on the 28-day journey count to within 10%.
- Agreement on shared services is weakest in **2022** (median difference 0.0%, 59.9% of services within 2%) against 74.8%-80.8% within 2% in the other years. In that window 20.9% of TNDS bus trips sit on calendars ending before it does, which is the largest single identified contributor.
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
- **Duplication, in every source.** The BODS change archive contains every
  revision of every dataset; superseded revisions were dropped with
  `UK2GTFS::txc_filter_files()`, keeping the revision valid on the analysis
  date. Residual duplication — the same service published by both an operator
  and a local authority scheme — inflates the TransXChange-derived sources, and
  TNDS demonstrably publishes some services twice (see the duplicate-registration
  table in `pdf_validation.md`).

  It is **not** the case that the DfT's GTFS is free of this. Measured on the
  July 2026 feed, 3.7% of its counted bus runs are the same journey on the same
  day, concentrated on a minority of `route_id`s, some of which are duplicated
  in their entirety; for First Bristol's 21 the duplication is the whole of its
  disagreement with both TNDS and the published timetable.
  `lsoa_disagreement.md` measures this for both sources. Treat every source as
  capable of counting a bus twice, and note that this is one of the few
  disagreements where an independent check can say which source is wrong.
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
  28-day window under GTFS calendar semantics, including `calendar_dates`
  exceptions. They are not passenger-facing frequencies.
