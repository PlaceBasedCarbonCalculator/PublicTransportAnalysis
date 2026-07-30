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
|2026 |2026-02-09 to 2026-03-08 |tnds_20260204_merged.zip |bods_txc_20260204.zip      |20260204           |

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

## Feed-level summary


|Year |Source              | Agencies| Routes| Routes in window| Trips in window| Missing departure times|
|:----|:-------------------|--------:|------:|----------------:|---------------:|-----------------------:|
|2022 |TNDS (TransXChange) |      950| 17,115|           17,115|       1,271,716|                       0|
|2022 |BODS (TransXChange) |      455|  9,290|            9,290|         467,636|                       0|
|2022 |BODS (GTFS)         |      920| 13,526|           13,526|         897,228|                       0|
|2023 |TNDS (TransXChange) |      910| 15,472|           15,472|       1,232,783|                       0|
|2023 |BODS (TransXChange) |      498| 10,197|           10,197|         530,557|                       0|
|2023 |BODS (GTFS)         |      879| 12,930|           12,930|         875,935|                       0|
|2024 |TNDS (TransXChange) |      856| 15,742|           15,742|       1,285,098|                       0|
|2024 |BODS (TransXChange) |      453|  9,997|            9,997|         533,634|                       0|
|2024 |BODS (GTFS)         |      858| 13,556|           13,556|         919,507|                       0|
|2025 |TNDS (TransXChange) |      819| 16,362|           16,362|       1,383,585|                       0|
|2025 |BODS (TransXChange) |      477| 12,060|           12,060|         569,443|                       0|
|2025 |BODS (GTFS)         |      661| 13,743|           13,743|       1,392,731|                       0|
|2026 |TNDS (TransXChange) |      804| 16,776|           16,776|       1,452,131|                       0|
|2026 |BODS (TransXChange) |      467| 13,719|           13,719|         759,481|                       0|
|2026 |BODS (GTFS)         |      649| 13,716|           13,716|       1,566,566|                       0|

## National bus service totals

Total counted bus (`route_type == 3`) departures from stops, summed over all
zones (a departure serving stops in more than one zone is counted in each, so
levels are comparable between sources but are not a national vehicle-trip
count).


|Year |        TNDS|    BODS TXC|   BODS GTFS|TNDS vs BODS GTFS |BODS TXC vs BODS GTFS |
|:----|-----------:|-----------:|-----------:|:-----------------|:---------------------|
|2022 | 442,079,508| 135,010,126| 442,407,165|-0.1%             |-69.5%                |
|2023 | 439,259,094| 139,142,619| 427,138,122|+2.8%             |-67.4%                |
|2024 | 443,584,141| 143,100,062| 446,857,322|-0.7%             |-68.0%                |
|2025 | 449,334,040| 152,134,017| 461,108,648|-2.6%             |-67.0%                |
|2026 | 428,016,177| 174,322,202| 483,670,443|-11.5%            |-64.0%                |

![plot of chunk totals-chart](figures/comparison-totals-chart-1.png)

## Zone-level agreement

Per-zone average daytime bus trips per hour (`tph_daytime_avg`, the headline
measure used by Carbon & Place), each TransXChange-derived source against the
BODS GTFS baseline.


|Year |Comparison            | Pearson r| Spearman rho| Median abs diff (tph)|Zones within 10% |
|:----|:---------------------|---------:|------------:|---------------------:|:----------------|
|2022 |TNDS vs BODS GTFS     |     0.981|        0.941|                  0.55|55.0%            |
|2022 |BODS TXC vs BODS GTFS |     0.310|        0.218|                  3.05|24.9%            |
|2022 |TNDS vs BODS TXC      |     0.317|        0.202|                  3.94|15.8%            |
|2023 |TNDS vs BODS GTFS     |     0.989|        0.946|                  0.21|65.2%            |
|2023 |BODS TXC vs BODS GTFS |     0.283|        0.182|                  2.92|26.0%            |
|2023 |TNDS vs BODS TXC      |     0.277|        0.181|                  3.80|19.0%            |
|2024 |TNDS vs BODS GTFS     |     0.992|        0.981|                  0.10|72.0%            |
|2024 |BODS TXC vs BODS GTFS |     0.334|        0.246|                  2.95|27.5%            |
|2024 |TNDS vs BODS TXC      |     0.335|        0.230|                  3.45|21.0%            |
|2025 |TNDS vs BODS GTFS     |     0.987|        0.978|                  0.09|70.1%            |
|2025 |BODS TXC vs BODS GTFS |     0.340|        0.250|                  2.56|31.2%            |
|2025 |TNDS vs BODS TXC      |     0.295|        0.212|                  3.25|22.2%            |
|2026 |TNDS vs BODS GTFS     |     0.953|        0.923|                  0.50|68.3%            |
|2026 |BODS TXC vs BODS GTFS |     0.440|        0.300|                  2.69|31.5%            |
|2026 |TNDS vs BODS TXC      |     0.242|        0.163|                  4.05|21.2%            |

![plot of chunk agreement-chart](figures/comparison-agreement-chart-1.png)

## Coverage by country

BODS is an **England-only statutory requirement**; Scottish and Welsh
services reach it only where operators cross the border or publish
voluntarily. TNDS ingests the Scottish and Welsh traveline data directly, so
country-level coverage is where the sources should differ most.


|Year |Country  |  Zones| TNDS mean tph| BODS TXC mean tph| BODS GTFS mean tph| TNDS zero-service zones| BODS TXC zero-service zones| BODS GTFS zero-service zones|
|:----|:--------|------:|-------------:|-----------------:|------------------:|-----------------------:|---------------------------:|----------------------------:|
|2022 |England  | 33,663|         21.82|              8.03|              21.85|                       0|                           0|                            0|
|2022 |Scotland |  7,326|         15.31|              0.00|              15.92|                       0|                           1|                            0|
|2022 |Wales    |  1,909|         11.36|              2.83|               8.03|                       0|                           0|                            0|
|2023 |England  | 33,660|         21.64|              8.15|              20.95|                       0|                           0|                            0|
|2023 |Scotland |  7,330|         15.71|              0.02|              15.65|                       0|                           0|                            0|
|2023 |Wales    |  1,910|          8.37|              4.90|               8.01|                       0|                           0|                            0|
|2024 |England  | 33,654|         22.22|              8.41|              22.37|                       0|                           0|                            0|
|2024 |Scotland |  7,333|         14.13|              0.01|              14.06|                       0|                           0|                            0|
|2024 |Wales    |  1,908|          8.11|              4.08|               9.19|                       0|                           0|                            0|
|2025 |England  | 33,669|         21.97|              8.98|              22.71|                       0|                           0|                            0|
|2025 |Scotland |  7,320|         16.65|              0.00|              16.44|                       0|                           1|                            0|
|2025 |Wales    |  1,907|          8.18|              3.46|               8.04|                       0|                           0|                            0|
|2026 |England  | 33,677|         20.83|             10.26|              24.24|                       0|                           0|                            0|
|2026 |Scotland |  7,332|         16.06|              0.01|              15.53|                       0|                           0|                            0|
|2026 |Wales    |  1,907|          7.88|              3.40|               7.79|                       0|                           0|                            0|

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
`route_id`s is still compared as a single service.

The unit counted here is **vehicle journeys in the 28-day window** — a
journey counts once however many stops or zones it passes through. This is a
stricter measure than the zone-level departure counts above.


|Year | Matched services| In all three sources| TNDS only| BODS TXC only| BODS GTFS only|
|:----|----------------:|--------------------:|---------:|-------------:|--------------:|
|2022 |           16,891|                6,464|     1,244|           232|            241|
|2023 |           15,727|                6,438|     1,412|            91|            143|
|2024 |           15,717|                7,093|       934|            30|            223|
|2025 |           15,921|                8,419|     1,327|            43|            121|
|2026 |           16,120|                8,323|     1,301|            15|            146|

### Missing services, or different frequencies?

For the TNDS / BODS GTFS pair — the two sources that agree most closely at
zone level — the total gap splits into journeys on services the other source
does not carry at all, and journeys on services both carry but time
differently.


|Year | Services in both| TNDS-only services| BODS GTFS-only services| Journeys on TNDS-only services| Journeys on BODS GTFS-only services| Net difference on shared services| Total gap (TNDS - BODS GTFS)|
|:----|----------------:|------------------:|-----------------------:|------------------------------:|-----------------------------------:|---------------------------------:|----------------------------:|
|2022 |           11,641|              1,393|                     920|                        490,515|                             332,069|                           -39,490|                      118,956|
|2023 |           10,980|              1,623|                   1,032|                        588,194|                             381,149|                           127,330|                      334,375|
|2024 |           11,814|              1,034|                   1,013|                        302,683|                             329,578|                          -198,887|                     -225,782|
|2025 |           11,736|              1,370|                     803|                        277,833|                             147,877|                          -463,701|                     -333,745|
|2026 |           11,606|              1,328|                     839|                        271,663|                             172,665|                        -1,461,796|                   -1,362,798|

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
|2022 |              88|                       79|                           48|                 68,264|                      67,357|13.9%                       |20.3%                            |
|2023 |              83|                       70|                           49|                 66,238|                      65,533|11.3%                       |17.2%                            |
|2024 |             110|                       93|                           48|                 92,281|                      92,720|30.5%                       |28.1%                            |
|2025 |              60|                       50|                           18|                 51,575|                      50,527|18.6%                       |34.2%                            |
|2026 |              77|                       55|                           15|                 45,849|                      45,566|16.9%                       |26.4%                            |

This is a persistent, material share of the apparent gap, present in every year of the series: 11.3%-30.5% of the journeys attributed to TNDS-only services and 17.2%-34.2% of those attributed to BODS GTFS-only services belong to a service the *other* source also carries, under a different name. In 2026, 55 of the 77 pairs match to the journey, which puts them beyond reasonable doubt, and 15 of them have no route number in TNDS at all.


Table: Largest services counted as exclusive to both sources at once, 2026

|From                 |To                   |TNDS number | TNDS journeys|BODS GTFS number | BODS GTFS journeys|Operator     |
|:--------------------|:--------------------|:-----------|-------------:|:----------------|------------------:|:------------|
|Friar Lane           |Friar Lane           |indigo      |         5,579|IGO              |              5,724|Trent Barton |
|Friar Lane           |Swallow Drive        |(blank)     |         5,129|RM               |              4,516|Trent Barton |
|Victoria Bus Station |Victoria Bus Station |(blank)     |         4,488|RA               |              4,584|Trent Barton |
|Bus Station          |Bus Station          |(blank)     |         3,697|IF               |              3,744|Trent Barton |
|Bus Station          |Bus Station          |swift       |         3,028|TM               |              2,712|Trent Barton |
|Market Place         |Market Place         |my15        |         2,956|15               |              3,016|Trent Barton |
|Friar Lane           |Friar Lane           |(blank)     |         2,867|SN               |              2,948|Trent Barton |
|Corporation Street   |Corporation Street   |(blank)     |         2,052|TA               |              2,092|Trent Barton |
|Coach Park           |Coach Park           |(blank)     |         1,694|SNX              |              1,752|Trent Barton |
|Parliament Street    |Parliament Street    |(blank)     |         1,525|CC               |              1,544|Trent Barton |
|Tram Park & Ride     |Tram Park & Ride     |(blank)     |         1,408|C                |              1,408|Trent Barton |
|Mount Street         |Mount Street         |(blank)     |         1,393|KC               |              1,416|Trent Barton |

Two naming habits produce these pairs, and they carry very different weight. In 2026, TNDS holds the longer name in 46 pairs and the shorter one in 12, with 15 carrying no number at all. One habit is a marketing name or local variant against a bare code - `indigo`/`IGO`, `my15`/`15`, `comet`/`CMT`, each agreeing on journeys to within 5%. The other is school-service prefixes and suffixes (`S458`/`458`, `807D`/`808`), a long tail of tiny services: it is why **Go North East Limited** contributes the most pairs (31) while **Trent Barton** contributes the most journeys (38,455 of 45,849).

One caveat on reading the table: where an operator runs many routes between
the same pair of generic terminals, the *aggregate* is sound but an individual
pairing can be wrong, because the counterpart is chosen as the closest journey
count among same-terminal, same-operator candidates. The rows to trust
unreservedly are the ones whose counts match exactly.

`match_route_services()` does have a second pass that links routes on stop
overlap alone (80%) when the numbers fail, but it only considers routes left
**completely unpaired** by the first pass. A service that a source splits
across two or more route_ids sharing one number is linked to *itself* in the
first pass, so it is no longer unpaired and the second pass never sees it —
which is precisely the situation for these multi-registration branded
operators. Widening that pass to whole components, rather than lone routes,
is the fix.

Among the services **both** sources carry, how closely do they agree on the
number of journeys?


|Year | Shared services|Within 2% |Within 10% |Differ by more than 50% |Median absolute difference |
|:----|---------------:|:---------|:----------|:-----------------------|:--------------------------|
|2022 |          11,641|59.8%     |69.6%      |8.9%                    |0.0%                       |
|2023 |          10,980|80.3%     |84.5%      |3.7%                    |0.0%                       |
|2024 |          11,814|75.1%     |79.3%      |2.7%                    |0.0%                       |
|2025 |          11,736|74.8%     |78.8%      |4.2%                    |0.0%                       |
|2026 |          11,606|60.1%     |78.9%      |8.3%                    |0.9%                       |

In the four autumn windows (2022–2025) most shared services agree *exactly*:
the modal TNDS ÷ BODS GTFS journey-count ratio is 1.00 and around 60% of
services are identical. **The February 2026 window is the exception**, and the
reason is not a converter disagreement about school terms but the age of the
TNDS snapshot relative to the window.

A TNDS snapshot carries the registration that is operative *at the snapshot
date*. The BODS change archive also carries future-dated files, so it holds the
successor timetable where TNDS does not. Any window extending weeks past a TNDS
snapshot therefore understates TNDS, and it does so lumpily, because operators
re-register around school terms. Measured on the rebuilt 2026 feed
(snapshot 2026-02-04, window 2026-02-09 to 2026-03-08):

- Of 1,384,215 TNDS bus trips, **335,493 (24.2%) sit on calendars that expire
  before the feed's own end date**, and they average **2.14 runs** in the window
  against **8.17** for trips that survive to it.
- The expiry is concentrated on two dates: **172,345 trips end Saturday
  2026-02-14** and **72,373 end Saturday 2026-02-21** — the Saturdays either
  side of English school half-term (16–20 February 2026).
- TNDS counts about **9.29 M** bus journeys in the window. Had nothing expired
  early it would count roughly **11.66 M, or 25% more**. Early expiry alone
  costs some **2.19 M journeys**, which is larger than the entire 1.36 M
  journey gap to BODS GTFS: run the full window and TNDS would *exceed* it.

A second, smaller effect compounds it. `convert_tnds_snapshot()` trims each
region to the snapshot date ±31 days, so this feed ends on **2026-03-07** while
its counting window runs to **2026-03-08**. The window's last day is empty in
TNDS by construction, costing a further **0.18 M journeys**.

(Trip and date counts here are exact counts from the feed's `calendar` and
`trips` tables; the journey totals are rounded, because they depend on the
run-counting convention and are quoted only to size the effect.)

Neither effect is a converter bug, and neither should be read as TNDS carrying
less service. The consequence for interpretation is that a TNDS figure measures
**service as registered at the snapshot date**, not service operated across the
window — so a TNDS snapshot should either be counted over a window inside its
operative period, or reported with that caveat attached. It is also a reminder
that the counting window, not only the source, affects how closely the sources
agree.

![plot of chunk shared-chart](figures/comparison-shared-chart-1.png)

### Worked examples

The largest services each source carries and the other does not, and the
largest disagreements on services both carry, for **2026**.




Table: Busiest services in TNDS but absent from BODS GTFS, 2026

|Route  |Operator            |From                      |To                        | TNDS journeys| BODS TXC journeys|
|:------|:-------------------|:-------------------------|:-------------------------|-------------:|-----------------:|
|Sprint |Kinchbus            |Holywell Park             |Holywell Park             |         6,120|                 0|
|indigo |Trent Barton        |Friar Lane                |Friar Lane                |         5,579|                 0|
|       |Trent Barton        |Friar Lane                |Swallow Drive             |         5,129|                 0|
|       |Go Ahead London     |Manor Way Roundabout      |Bus Station               |         4,871|                 0|
|PREM   |Bus4Us              |Coach Station             |Coach Station             |         4,806|                 0|
|       |Go Ahead London     |Acacia Hall Fastrack Hub  |Bus Station               |         4,603|                 0|
|       |Go Ahead London     |Garrick Street            |Sharp Way                 |         4,552|                 0|
|400    |Oxford Bus Company  |Railway Station           |Railway Station           |         4,548|                 0|
|       |Trent Barton        |Victoria Bus Station      |Victoria Bus Station      |         4,488|                 0|
|727    |Stagecoach Bluebird |Airport Terminal Stance 1 |Airport Terminal Stance 1 |         4,439|                 0|
|59     |Stagecoach Bluebird |Howes Road                |Howes Road                |         4,156|                 0|
|       |Kinchbus            |St Margaret's Bus Station |St Margaret's Bus Station |         4,115|                 0|


Table: Busiest services in BODS GTFS but absent from TNDS, 2026

|Route |Operator               |From                 |To                   | BODS GTFS journeys| BODS TXC journeys|
|:-----|:----------------------|:--------------------|:--------------------|------------------:|-----------------:|
|757   |Arriva Beds and Bucks  |Airport Bus Station  |Airport Bus Station  |              6,720|               120|
|IGO   |trentbarton            |Friar Lane           |Friar Lane           |              5,724|             5,586|
|F     |Go Ahead Luton Parkway |Manor Way Roundabout |Bus Station          |              5,044|             3,640|
|1     |trentbarton            |Victoria Bus Station |Victoria Bus Station |              5,040|             4,941|
|B     |Go Ahead Luton Parkway |Garrick Street       |Sharp Way            |              4,704|             3,440|
|RA    |trentbarton            |Victoria Bus Station |Victoria Bus Station |              4,584|             4,508|
|RM    |trentbarton            |Friar Lane           |Swallow Drive        |              4,516|             4,430|
|SKY   |Kinchbus               |Bus Station          |Bus Station          |              4,208|             4,115|
|A     |Go Ahead Luton Parkway |Home Gardens         |Bus Station          |              4,192|             3,000|
|SP    |Kinchbus               |Railway Station      |Railway Station      |              3,908|             3,862|
|IF    |trentbarton            |Bus Station          |Bus Station          |              3,744|             3,704|
|HE    |Go Ahead Luton Parkway |HereEast / The Yard  |HereEast / The Yard  |              3,620|                60|


Table: Largest journey-count disagreements on services both sources carry, 2026

|Route |Operator                            |From                           |To                            | TNDS journeys| BODS GTFS journeys| Difference|Ratio |
|:-----|:-----------------------------------|:------------------------------|:-----------------------------|-------------:|------------------:|----------:|:-----|
|466   |Arriva London South                 |Westway Common                 |Addington Village Interchange |         6,596|             20,220|    -13,624|0.33  |
|279   |Arriva London North                 |Manor House                    |Bus Station                   |         8,066|             21,192|    -13,126|0.38  |
|A1    |First Bristol, Bath & the West      |Bus Station                    |Public Transport Interchange  |         1,507|             12,325|    -10,818|0.12  |
|2     |First Portsmouth, Fareham & Gosport |The Hard Interchange           |Allaway Avenue Shops          |         1,131|             11,466|    -10,335|0.10  |
|74    |National Express West Midlands      |Colmore Circus                 |Colmore Circus                |        11,138|             20,753|     -9,615|0.54  |
|150   |Arriva London North                 |Becontree Heath Leisure Centre |Lambourne Road                |         4,437|             13,620|     -9,183|0.33  |
|3     |First Portsmouth, Fareham & Gosport |Bus Station                    |South Parade Pier             |         1,014|             10,171|     -9,157|0.10  |
|28    |First Essex                         |Bus Station                    |Bus Station                   |           961|             10,047|     -9,086|0.10  |
|1     |First Portsmouth, Fareham & Gosport |South Parade Pier              |South Parade Pier             |           996|              9,954|     -8,958|0.10  |
|216   |London United                       |Elmsleigh Bus Station          |Elmsleigh Bus Station         |         2,588|             11,113|     -8,525|0.23  |
|21    |First Bristol, Bath & the West      |Newbridge P&R                  |Newbridge P&R                 |           756|              9,132|     -8,376|0.08  |
|X30   |First Essex                         |Bus Station                    |Bus Station                   |           506|              8,645|     -8,139|0.06  |
|54    |First Essex                         |Library                        |Library                       |           902|              8,684|     -7,782|0.10  |
|B1    |First Essex                         |Fenton Way                     |Bus Station                   |           866|              8,476|     -7,610|0.10  |
|275   |Stagecoach London                   |Barkingside Tesco              |St James Street Station       |        11,569|              3,960|      7,609|2.92  |

## Interpretation

- Across 2022-2026 the TNDS bus total runs between -11.5% and +2.8% of the BODS GTFS total, and the BODS TransXChange total between -69.5% and -64.0%.
- Per-zone agreement with BODS GTFS is stable across the series: Pearson r ranges 0.953-0.992 for TNDS and 0.283-0.440 for BODS TransXChange.
- Of TNDS bus journeys, 2.8%-6.2% sit on services BODS GTFS does not carry at all; of BODS GTFS journeys, 1.5%-4.2% sit on services TNDS does not carry.
- Where both sources carry a service, 69.6%-84.5% of services agree on the 28-day journey count to within 10%.
- The agreement on shared services is near-exact in the four autumn windows (median difference 0%, 59.8%-80.3% of services within 2%) but not in the February 2026 window (median difference 0.9%, only 60.1% within 2%). That window is measured against a snapshot whose registrations expire inside it: 24.2% of TNDS bus trips sit on calendars ending before the feed does, costing roughly 2.19 M journeys — more than the whole gap to BODS GTFS.
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
- **Duplication handling.** The BODS change archive contains every revision
  of every dataset; superseded revisions were dropped with
  `UK2GTFS::txc_filter_files()` keeping the revision valid on the analysis
  date. Residual duplication (the same service published by both an operator
  and a local authority scheme) inflates counts in the TransXChange-derived
  sources; the DfT GTFS pipeline applies its own de-duplication.
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
  re-register around school terms. This is the dominant effect in the February
  2026 window and is measured above. It is not a defect in either source, but
  it does mean the two columns answer slightly different questions.
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
- The stop-overlap fallback that exists for this case only rescues routes left
  **completely unpaired** by the number match, so it cannot help a service that
  a source splits across several route_ids under one number. Widening it to
  operate on connected components rather than lone routes would close most of
  the gap, at the cost of re-running the matching for every year.
- Journey counts are the number of vehicle journeys operating in the
  28-day window under GTFS calendar semantics, including `calendar_dates`
  exceptions. They are not passenger-facing frequencies.
