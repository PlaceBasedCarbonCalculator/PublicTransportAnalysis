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
|2026 |2026-02-02 to 2026-03-01 |tnds_20260204_merged.zip |bods_txc_20260204.zip      |20260204           |

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
|2022 |TNDS (TransXChange) |      950| 17,128|           17,128|       1,271,968|                       0|
|2022 |BODS (TransXChange) |      455|  9,297|            9,297|         468,291|                       0|
|2022 |BODS (GTFS)         |      920| 13,526|           13,526|         897,188|                       0|
|2023 |TNDS (TransXChange) |      910| 15,480|           15,480|       1,233,513|                       0|
|2023 |BODS (TransXChange) |      498| 10,198|           10,198|         531,125|                       0|
|2023 |BODS (GTFS)         |      879| 12,930|           12,930|         875,903|                       0|
|2024 |TNDS (TransXChange) |      856| 15,771|           15,771|       1,285,802|                       0|
|2024 |BODS (TransXChange) |      453|  9,998|            9,998|         534,468|                       0|
|2024 |BODS (GTFS)         |      858| 13,556|           13,556|         919,478|                       0|
|2025 |TNDS (TransXChange) |      818| 16,345|           16,345|       1,385,008|                       0|
|2025 |BODS (TransXChange) |      469| 10,994|           10,994|         556,002|                       0|
|2025 |BODS (GTFS)         |      661| 13,743|           13,743|       1,329,251|                       0|
|2026 |TNDS (TransXChange) |      802| 16,772|           16,772|       1,502,581|                       0|
|2026 |BODS (TransXChange) |      460| 12,487|           12,487|         743,956|                       0|
|2026 |BODS (GTFS)         |      649| 13,716|           13,716|       1,524,350|                       0|

## National bus service totals

Total counted bus (`route_type == 3`) departures from stops, summed over all
zones (a departure serving stops in more than one zone is counted in each, so
levels are comparable between sources but are not a national vehicle-trip
count).


|Year |        TNDS|    BODS TXC|   BODS GTFS|TNDS vs BODS GTFS |BODS TXC vs BODS GTFS |
|:----|-----------:|-----------:|-----------:|:-----------------|:---------------------|
|2022 | 464,392,564| 143,832,909| 442,400,572|+5.0%             |-67.5%                |
|2023 | 474,201,705| 145,795,968| 427,134,091|+11.0%            |-65.9%                |
|2024 | 477,804,581| 148,406,500| 446,856,232|+6.9%             |-66.8%                |
|2025 | 467,000,097| 154,684,230| 444,719,870|+5.0%             |-65.2%                |
|2026 | 461,530,277| 171,349,643| 425,489,667|+8.5%             |-59.7%                |

![plot of chunk totals-chart](figures/comparison-totals-chart-1.png)

## Zone-level agreement

Per-zone average daytime bus trips per hour (`tph_daytime_avg`, the headline
measure used by Carbon & Place), each TransXChange-derived source against the
BODS GTFS baseline.


|Year |Comparison            | Pearson r| Spearman rho| Median abs diff (tph)|Zones within 10% |
|:----|:---------------------|---------:|------------:|---------------------:|:----------------|
|2022 |TNDS vs BODS GTFS     |     0.963|        0.930|                  1.01|47.0%            |
|2022 |BODS TXC vs BODS GTFS |     0.308|        0.215|                  3.16|23.9%            |
|2022 |TNDS vs BODS TXC      |     0.361|        0.214|                  4.74|12.8%            |
|2023 |TNDS vs BODS GTFS     |     0.983|        0.944|                  0.59|54.7%            |
|2023 |BODS TXC vs BODS GTFS |     0.285|        0.184|                  2.97|24.5%            |
|2023 |TNDS vs BODS TXC      |     0.246|        0.181|                  3.92|18.2%            |
|2024 |TNDS vs BODS GTFS     |     0.986|        0.981|                  0.30|65.3%            |
|2024 |BODS TXC vs BODS GTFS |     0.336|        0.245|                  2.95|26.5%            |
|2024 |TNDS vs BODS TXC      |     0.304|        0.229|                  3.54|20.1%            |
|2025 |TNDS vs BODS GTFS     |     0.972|        0.965|                  0.52|56.6%            |
|2025 |BODS TXC vs BODS GTFS |     0.308|        0.218|                  2.67|26.1%            |
|2025 |TNDS vs BODS TXC      |     0.299|        0.206|                  3.53|21.1%            |
|2026 |TNDS vs BODS GTFS     |     0.958|        0.946|                  1.58|38.3%            |
|2026 |BODS TXC vs BODS GTFS |     0.393|        0.273|                  2.55|24.1%            |
|2026 |TNDS vs BODS TXC      |     0.278|        0.199|                  4.21|20.3%            |

![plot of chunk agreement-chart](figures/comparison-agreement-chart-1.png)

## Coverage by country

BODS is an **England-only statutory requirement**; Scottish and Welsh
services reach it only where operators cross the border or publish
voluntarily. TNDS ingests the Scottish and Welsh traveline data directly, so
country-level coverage is where the sources should differ most.


|Year |Country  |  Zones| TNDS mean tph| BODS TXC mean tph| BODS GTFS mean tph| TNDS zero-service zones| BODS TXC zero-service zones| BODS GTFS zero-service zones|
|:----|:--------|------:|-------------:|-----------------:|------------------:|-----------------------:|---------------------------:|----------------------------:|
|2022 |England  | 33,665|         23.55|              8.55|              21.85|                       0|                           0|                            0|
|2022 |Scotland |  7,326|         13.84|              0.00|              15.92|                       0|                           1|                            0|
|2022 |Wales    |  1,909|         11.40|              3.03|               8.03|                       0|                           0|                            0|
|2023 |England  | 33,660|         23.65|              8.54|              20.95|                       0|                           0|                            0|
|2023 |Scotland |  7,331|         15.85|              0.02|              15.65|                       0|                           0|                            0|
|2023 |Wales    |  1,910|          8.62|              5.15|               8.01|                       0|                           0|                            0|
|2024 |England  | 33,654|         24.14|              8.71|              22.37|                       0|                           0|                            0|
|2024 |Scotland |  7,333|         14.25|              0.02|              14.06|                       0|                           0|                            0|
|2024 |Wales    |  1,908|          8.34|              4.26|               9.19|                       0|                           0|                            0|
|2025 |England  | 33,669|         22.95|              9.11|              21.77|                       0|                           0|                            0|
|2025 |Scotland |  7,320|         16.82|              0.00|              16.34|                       0|                           1|                            0|
|2025 |Wales    |  1,907|          8.40|              3.69|               7.56|                       0|                           0|                            0|
|2026 |England  | 33,677|         22.56|             10.08|              21.15|                       0|                           0|                            0|
|2026 |Scotland |  7,332|         16.94|              0.02|              14.25|                       0|                           0|                            0|
|2026 |Wales    |  1,907|          8.42|              3.57|               6.82|                       0|                           0|                            0|

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
|2022 |           17,088|                6,484|     1,412|           276|            226|
|2023 |           15,897|                6,434|     1,603|           128|            220|
|2024 |           15,830|                7,102|     1,086|            35|            305|
|2025 |           18,587|                5,951|     2,049|           391|            172|
|2026 |           18,598|                5,841|     2,116|           383|            190|

### Missing services, or different frequencies?

For the TNDS / BODS GTFS pair — the two sources that agree most closely at
zone level — the total gap splits into journeys on services the other source
does not carry at all, and journeys on services both carry but time
differently.


|Year | Services in both| TNDS-only services| BODS GTFS-only services| Journeys on TNDS-only services| Journeys on BODS GTFS-only services| Net difference on shared services| Total gap (TNDS - BODS GTFS)|
|:----|----------------:|------------------:|-----------------------:|------------------------------:|-----------------------------------:|---------------------------------:|----------------------------:|
|2022 |           11,711|              1,614|                     857|                        586,889|                             360,295|                           709,114|                      935,708|
|2023 |           10,918|              1,861|                   1,100|                        662,742|                             414,978|                           752,151|                      999,915|
|2024 |           11,763|              1,259|                   1,074|                        344,044|                             340,891|                           424,318|                      427,471|
|2025 |            9,475|              3,839|                     445|                        569,526|                             140,204|                           142,550|                      571,872|
|2026 |            9,319|              3,893|                     467|                        599,555|                             152,867|                           369,273|                      815,961|

![plot of chunk exclusive-chart](figures/comparison-exclusive-chart-1.png)

Among the services **both** sources carry, how closely do they agree on the
number of journeys?


|Year | Shared services|Within 2% |Within 10% |Differ by more than 50% |Median absolute difference |
|:----|---------------:|:---------|:----------|:-----------------------|:--------------------------|
|2022 |          11,711|57.2%     |66.7%      |10.9%                   |0.0%                       |
|2023 |          10,918|65.3%     |71.1%      |7.3%                    |0.0%                       |
|2024 |          11,763|62.1%     |68.4%      |5.9%                    |0.0%                       |
|2025 |           9,475|60.5%     |68.4%      |8.3%                    |0.0%                       |
|2026 |           9,319|4.2%      |61.1%      |10.2%                   |8.7%                       |

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

|Route  |Operator                |From                  |To                             | TNDS journeys| BODS TXC journeys|
|:------|:-----------------------|:---------------------|:------------------------------|-------------:|-----------------:|
|143    |Bee Network (Metroline) |Piccadilly Gardens    |Central Road                   |        24,158|               336|
|43     |Bee Network (Metroline) |Piccadilly Gardens    |Manchester Airport The Station |        13,297|                96|
|UL     |Midland Bluebird        |Stance A              |Stance A                       |        12,152|                 0|
|86     |Bee Network (Metroline) |Piccadilly Gardens    |Piccadilly Gardens             |        11,428|             3,640|
|50     |Bee Network (Metroline) |Parrs Wood            |Parrs Wood                     |        11,166|             3,540|
|111    |Bee Network (Metroline) |Piccadilly Gardens    |Southern Cemetery Bus Station  |         9,114|             3,060|
|101    |Bee Network (Metroline) |Piccadilly Gardens    |Piccadilly Gardens             |         8,299|             2,560|
|UNI1   |Stagecoach South East   |Bus Station           |Bus Station                    |         7,728|             7,728|
|85     |Bee Network (Metroline) |Piccadilly Gardens    |Chorlton Bus Station           |         7,370|             2,340|
|20     |Replacement Buses       |St Marys Butts        |Reading University             |         6,916|             6,916|
|368    |Bee Network (Metroline) |Stockport Interchange |Stockport Interchange          |         6,420|               348|
|Sprint |Kinchbus                |Holywell Park         |Holywell Park                  |         6,144|                 0|


Table: Busiest services in BODS GTFS but absent from TNDS, 2026

|Route |Operator               |From                 |To                   | BODS GTFS journeys| BODS TXC journeys|
|:-----|:----------------------|:--------------------|:--------------------|------------------:|-----------------:|
|757   |Arriva Beds and Bucks  |Airport Bus Station  |Airport Bus Station  |              6,240|               160|
|IGO   |trentbarton            |Friar Lane           |Friar Lane           |              5,296|             5,724|
|F     |Go Ahead Luton Parkway |Manor Way Roundabout |Bus Station          |              4,680|             3,640|
|1     |trentbarton            |Victoria Bus Station |Victoria Bus Station |              4,654|             5,040|
|B     |Go Ahead Luton Parkway |Garrick Street       |Sharp Way            |              4,360|             3,440|
|RA    |trentbarton            |Victoria Bus Station |Victoria Bus Station |              4,236|             4,584|
|RM    |trentbarton            |Friar Lane           |Swallow Drive        |              4,166|             4,516|
|A     |Go Ahead Luton Parkway |Home Gardens         |Bus Station          |              3,892|             3,000|
|SKY   |Kinchbus               |Bus Station          |Bus Station          |              3,888|             4,208|
|SP    |Kinchbus               |Railway Station      |Railway Station      |              3,578|             3,908|
|IF    |trentbarton            |Bus Station          |Bus Station          |              3,452|             3,744|
|HE    |Go Ahead Luton Parkway |HereEast / The Yard  |HereEast / The Yard  |              3,169|                60|


Table: Largest journey-count disagreements on services both sources carry, 2026

|Route |Operator                                |From                                       |To                                         | TNDS journeys| BODS GTFS journeys| Difference|Ratio |
|:-----|:---------------------------------------|:------------------------------------------|:------------------------------------------|-------------:|------------------:|----------:|:-----|
|279   |Arriva London North                     |Manor House                                |Bus Station                                |         8,284|             19,622|    -11,338|0.42  |
|EL1   |BLUE TRIANGLE BUSES LIMITED             |Northgate Road                             |Ilford Station / Ilford Hill               |        17,027|              7,062|      9,965|2.41  |
|86    |EAST LONDON BUS & COACH COMPANY LIMITED |Stratford Bus Station                      |Romford Station                            |        15,904|              6,670|      9,234|2.38  |
|275   |EAST LONDON BUS & COACH COMPANY LIMITED |Barkingside Tesco                          |St James Street Station                    |        11,852|              3,658|      8,194|3.24  |
|1A    |Stagecoach North West                   |Underpass                                  |Underpass                                  |         7,995|                112|      7,883|71.38 |
|69    |BLUE TRIANGLE BUSES LIMITED             |Walthamstow Bus Station                    |Canning Town                               |        13,378|              5,622|      7,756|2.38  |
|139   |METROLINE TRAVEL LIMITED                |Golders Green Station                      |Waterloo Station / Waterloo Road           |        13,029|              5,477|      7,552|2.38  |
|109   |Transport UK                            |St George's Walk / Croydon Town Centre     |Brixton Station                            |        12,981|              5,442|      7,539|2.39  |
|134   |METROLINE TRAVEL LIMITED                |University College Hospital  / Euston Road |University College Hospital  / Euston Road |        13,128|              5,622|      7,506|2.34  |
|142   |Bee Network (Metroline)                 |Parrs Wood                                 |Piccadilly Gardens                         |        10,006|              2,645|      7,361|3.78  |
|100   |Stagecoach North West                   |Graduate College                           |Graduate College                           |         7,516|                326|      7,190|23.06 |
|213   |LONDON GENERAL TRANSPORT SERVICES LTD   |Fairfield Bus Station                      |Sutton Bus Garage                          |        11,394|              4,418|      6,976|2.58  |
|32    |METROLINE TRAVEL LIMITED                |Edgware Bus Station                        |Kilburn Park Station                       |        11,853|              4,989|      6,864|2.38  |
|A1    |First Bristol, Bath & the West          |Bus Station                                |Public Transport Interchange               |         3,236|             10,082|     -6,846|0.32  |
|222   |METROLINE WEST LIMITED                  |Uxbridge Station                           |Hounslow Bus Station                       |        11,411|              4,902|      6,509|2.33  |

## Interpretation

- Across 2022-2026 the TNDS bus total runs between +5.0% and +11.0% of the BODS GTFS total, and the BODS TransXChange total between -67.5% and -59.7%.
- Per-zone agreement with BODS GTFS is stable across the series: Pearson r ranges 0.958-0.986 for TNDS and 0.285-0.393 for BODS TransXChange.
- Of TNDS bus journeys, 3.3%-6.6% sit on services BODS GTFS does not carry at all; of BODS GTFS journeys, 1.5%-4.6% sit on services TNDS does not carry.
- Where both sources carry a service, 61.1%-71.1% of services agree on the 28-day journey count to within 10%.
- The agreement on shared services is near-exact in the four autumn windows (median difference 0%, 57.2%-65.3% of services within 2%) but not in the February 2026 window (median difference 8.7%, only 4.2% within 2%) — consistent with a school half-term falling inside the 2026 window and being handled differently by the two converters.

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
