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
|2025 |TNDS (TransXChange) |      818| 16,342|           16,342|       1,382,656|                       0|
|2025 |BODS (TransXChange) |      469| 10,992|           10,992|         555,489|                       0|
|2025 |BODS (GTFS)         |      661| 13,743|           13,743|       1,392,731|                       0|
|2026 |TNDS (TransXChange) |      802| 16,769|           16,769|       1,452,117|                       0|
|2026 |BODS (TransXChange) |      460| 12,484|           12,484|         741,249|                       0|
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
|2025 | 449,128,166| 147,086,365| 461,108,648|-2.6%             |-68.1%                |
|2026 | 428,015,241| 169,208,215| 483,670,443|-11.5%            |-65.0%                |

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
|2025 |TNDS vs BODS GTFS     |     0.987|        0.978|                  0.09|70.2%            |
|2025 |BODS TXC vs BODS GTFS |     0.337|        0.238|                  2.88|29.3%            |
|2025 |TNDS vs BODS TXC      |     0.291|        0.200|                  3.48|21.1%            |
|2026 |TNDS vs BODS GTFS     |     0.953|        0.923|                  0.50|68.3%            |
|2026 |BODS TXC vs BODS GTFS |     0.440|        0.294|                  2.97|29.1%            |
|2026 |TNDS vs BODS TXC      |     0.240|        0.155|                  4.33|19.7%            |

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
|2025 |England  | 33,669|         21.97|              8.67|              22.71|                       0|                           0|                            0|
|2025 |Scotland |  7,320|         16.65|              0.00|              16.44|                       0|                           1|                            0|
|2025 |Wales    |  1,907|          8.03|              3.36|               8.04|                       0|                           0|                            0|
|2026 |England  | 33,677|         20.83|              9.96|              24.24|                       0|                           0|                            0|
|2026 |Scotland |  7,332|         16.06|              0.01|              15.53|                       0|                           0|                            0|
|2026 |Wales    |  1,907|          7.88|              3.31|               7.79|                       0|                           0|                            0|

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
|2022 |           17,129|                6,450|     1,430|           274|            321|
|2023 |           15,965|                6,428|     1,619|           119|            221|
|2024 |           15,891|                7,090|     1,077|            46|            305|
|2025 |           15,999|                7,671|     1,489|            68|            225|
|2026 |           16,087|                7,583|     1,520|            33|            249|

### Missing services, or different frequencies?

For the TNDS / BODS GTFS pair — the two sources that agree most closely at
zone level — the total gap splits into journeys on services the other source
does not carry at all, and journeys on services both carry but time
differently.


|Year | Services in both| TNDS-only services| BODS GTFS-only services| Journeys on TNDS-only services| Journeys on BODS GTFS-only services| Net difference on shared services| Total gap (TNDS - BODS GTFS)|
|:----|----------------:|------------------:|-----------------------:|------------------------------:|-----------------------------------:|---------------------------------:|----------------------------:|
|2022 |           11,584|              1,572|                     992|                        529,835|                             371,973|                           -38,906|                      118,956|
|2023 |           10,918|              1,821|                   1,104|                        622,248|                             417,244|                           129,371|                      334,375|
|2024 |           11,754|              1,174|                   1,087|                        312,464|                             341,299|                          -196,947|                     -225,782|
|2025 |           11,710|              1,527|                     838|                        285,980|                             156,509|                          -471,677|                     -342,206|
|2026 |           11,582|              1,544|                     874|                        286,048|                             181,473|                        -1,467,429|                   -1,362,854|

![plot of chunk exclusive-chart](figures/comparison-exclusive-chart-1.png)

Among the services **both** sources carry, how closely do they agree on the
number of journeys?


|Year | Shared services|Within 2% |Within 10% |Differ by more than 50% |Median absolute difference |
|:----|---------------:|:---------|:----------|:-----------------------|:--------------------------|
|2022 |          11,584|59.7%     |69.5%      |8.9%                    |0.0%                       |
|2023 |          10,918|80.4%     |84.6%      |3.6%                    |0.0%                       |
|2024 |          11,754|75.1%     |79.3%      |2.7%                    |0.0%                       |
|2025 |          11,710|74.9%     |78.9%      |4.2%                    |0.0%                       |
|2026 |          11,582|60.1%     |78.9%      |8.3%                    |0.9%                       |

In the four autumn windows (2022–2025) most shared services agree *exactly*:
the modal TNDS ÷ BODS GTFS journey-count ratio is 1.00 and around 60% of
services are identical. **The February 2026 window is the exception** — the
whole ratio distribution shifts to about 1.09 (TNDS counts ~9% more journeys
than BODS GTFS on the same services) and the share of exactly-equal services
collapses to 4%. February is the only window here that contains a school
half-term, so the most likely cause is the two converters handling term-time
and half-term operating profiles differently; the autumn windows sit clear of
school holidays and so agree far more closely. This is worth investigating
before relying on a February snapshot for anything frequency-sensitive, and is
a reminder that the counting window itself — not just the source — affects how
closely the sources agree.

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
|       |Trent Barton        |Victoria Bus Station      |Victoria Bus Station      |         4,933|                 0|
|       |Go Ahead London     |Manor Way Roundabout      |Bus Station               |         4,871|                 0|
|PREM   |Bus4Us              |Coach Station             |Coach Station             |         4,806|                 0|
|       |Go Ahead London     |Garrick Street            |Sharp Way                 |         4,552|                 0|
|       |Trent Barton        |Victoria Bus Station      |Victoria Bus Station      |         4,488|                 0|
|400    |Oxford Bus Company  |Railway Station           |Railway Station           |         4,460|                 0|
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

- Across 2022-2026 the TNDS bus total runs between -11.5% and +2.8% of the BODS GTFS total, and the BODS TransXChange total between -69.5% and -65.0%.
- Per-zone agreement with BODS GTFS is stable across the series: Pearson r ranges 0.953-0.992 for TNDS and 0.283-0.440 for BODS TransXChange.
- Of TNDS bus journeys, 2.9%-6.6% sit on services BODS GTFS does not carry at all; of BODS GTFS journeys, 1.5%-4.6% sit on services TNDS does not carry.
- Where both sources carry a service, 69.5%-84.6% of services agree on the 28-day journey count to within 10%.
- The agreement on shared services is near-exact in the four autumn windows (median difference 0%, 59.7%-80.4% of services within 2%) but not in the February 2026 window (median difference 0.9%, only 60.1% within 2%) — consistent with a school half-term falling inside the 2026 window and being handled differently by the two converters.

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
  **different route number** rather than genuinely missing. The worked
  example tables should be read as leads to investigate, not as a
  certified list of gaps.
- Journey counts are the number of vehicle journeys operating in the
  28-day window under GTFS calendar semantics, including `calendar_dates`
  exceptions. They are not passenger-facing frequencies.
