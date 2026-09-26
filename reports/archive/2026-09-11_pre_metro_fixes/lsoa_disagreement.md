# Where TNDS and the DfT's BODS GTFS disagree most, zone by zone



The comparison report (`bus_source_comparison.md`) measures how far the three
bus timetable sources disagree nationally. This report asks a narrower and more
practical question: **for which individual LSOAs (Data Zones in Scotland) does
the choice between TNDS and the DfT's BODS GTFS change the answer most, and
which bus routes are responsible?**

Both sources are the **2026** snapshot, deduplicated with
`UK2GTFS::gtfs_deduplicate()` so that neither describes the same bus twice,
and counted over the same 28-day window (**2026-07-27 to
2026-08-23**) on the **plain LSOA21 / DZ22 boundaries**. The
published trips-per-zone outputs use zones widened for stop access; this
report does not, because widened zones overlap and a disagreement at a stop
in several of them would be counted several times over:

- TNDS (TransXChange), converted with `UK2GTFS::transxchange2gtfs()`:
  tnds_20260726_merged.zip
- BODS GTFS, the DfT's own rendering, used as supplied:
  20260726

The measure is **total bus trip-runs in the window**: every vehicle journey
that calls at least once inside the zone, weighted by the number of times it
runs over the 28 days. A journey counts once per zone however many of the
zone's stops it calls at, which is exactly what `gtfs_trips_per_zone()` does, so
these numbers reconcile with the comparison report's zone totals. Unlike
`tph_daytime_avg` — the measure the pipeline publishes — it includes the night
band and does not weight weekdays, so it is a plain total.

## The national picture


|Measure                                         |       Value|
|:-----------------------------------------------|-----------:|
|Zones with counted bus service in either source |      40,819|
|Total bus trip-runs, TNDS                       | 191,138,742|
|Total bus trip-runs, BODS GTFS                  | 203,021,824|
|Zones where TNDS counts more                    |       9,823|
|Zones where BODS GTFS counts more               |      11,743|
|Zones where the two agree exactly               |      19,253|
|Zones with service in TNDS only                 |         294|
|Zones with service in BODS GTFS only            |         262|

Nationally TNDS counts 191,138,742 bus trip-runs against BODS GTFS's 203,021,824, so BODS GTFS is the higher of the two by 11,883,082 (-5.9% of the BODS GTFS total). The direction is not uniform: BODS GTFS is the higher source in 11,743 zones and TNDS in 9,823, so the national total is a partial cancellation of disagreements pointing opposite ways.

At zone level the two agree exactly in only 19,253 of 40,819 zones (47.2%), and in **556 zones** one source shows a bus service where the other shows none at all — 294 in TNDS only, 262 in BODS GTFS only. Those are the zones where the choice of source is not a matter of degree.

![plot of chunk gap-dist](figures/lsoagap-gap-dist-1.png)

### Is the disagreement spread across the country or concentrated?

Every zone, ordered by its difference and plotted in that order: the far left is
where TNDS counts most more, the far right where the DfT's GTFS does. The
histogram above shows how many zones fall in each band; this shows the shape of
the whole distribution at once, and in particular whether the national totals
are driven by a long broad disagreement or by a short extreme tail.

![plot of chunk gap-curve](figures/lsoagap-gap-curve-1.png)

On a linear axis the middle of that curve is flat whether the zones there agree
exactly or differ by a hundred departures, because the ends are thousands of
times larger. The same curve on a signed logarithmic axis separates the two —
each gridline is ten times the last, in both directions from zero:

![plot of chunk gap-curve-log](figures/lsoagap-gap-curve-log-1.png)

Summed over every zone, the two sources differ by **20,559,612 trip-runs** in absolute terms, against **11,883,082** between the national totals — the difference between those two figures is disagreement that cancels between zones pointing opposite ways. Of the absolute total, the worst **1%** of zones carry **22.8%** and the worst **10%** carry **76.2%**.

By size of difference: **5,186 zones** differ by 1,000 trip-runs or more (12.7% of all zones), **8,382** by between 100 and 1,000, **7,998** by between 1 and 100, and **19,253** agree exactly. A zone differing by 100 trip-runs over 28 days is under four departures a day; one differing by 1,000 is thirty-six.

The curve is not symmetric. It crosses zero at rank **9,824 of 40,819**, 24.1% of the way along, and the two ends are of very different size: the highest zone is **+18,886** and the lowest **-74,064**, so the drop on the right is about 4 times the rise on the left. BODS GTFS counts more service than TNDS in more zones and by a wider margin.

The left-hand side is not one country's story either way. Of the **9,823 zones** where TNDS counts more, the split by country is 9,173 England, 353 Wales, 297 Scotland; but among the worst **1%** of that side it is 84 England, 11 Wales, 4 Scotland. England leads on both counts here, though that is a property of this snapshot rather than of the sources: on the February 2026 feeds the extremes were mostly Scottish. The top-ten tables below rank by size, so they show only the second of those two answers.

So the answer to "a few extreme zones or many moderate ones" is both, and the two facts have to be held together: the tail is heavy enough that a tenth of zones account for 76.2% of all disagreement, yet **12.7% of zones** differ by more than thirty-six departures a day, which is not a rounding error in any of them. The choice of source changes the answer over most of the country, and changes it drastically in a small part of it.

## The zones that disagree most

Ranked on the absolute difference in trip-runs, both directions. The last three
columns split each zone's difference into services **only** one source carries
and services **both** carry at different frequencies — the same decomposition
the comparison report applies nationally, but computed within the zone. They are
signed contributions and add up to `Difference`, so "Only BODS" is negative:
service the DfT feed has and TNDS does not pulls the difference down.

Expect repeated localities. City-centre LSOAs are small and the zone polygons
are widened by 500 m, so half a dozen adjacent zones can all contain the same
bus station and all rank together on the same handful of services. That is a
faithful answer to "which zones disagree most" rather than a fault in the
ranking, but it means the tables describe fewer distinct places than rows. The
route-level section below therefore takes one zone per locality.

### Zones where TNDS counts substantially more service


|Zone      |Locality                       |Country  |    TNDS| BODS GTFS| Difference| Only TNDS| Only BODS| Frequency|
|:---------|:------------------------------|:--------|-------:|---------:|----------:|---------:|---------:|---------:|
|E01004513 |Mapleton Road (SW18)           |England  |  25,028|     6,142|     18,886|    18,876|         0|        10|
|E01032896 |New Street                     |England  |  33,997|    20,756|     13,241|     2,048|         0|    11,193|
|S01014636 |Salisbury Place                |Scotland |  28,240|    15,236|     13,004|         0|         0|    13,004|
|E01035376 |Chester Bus Interchange        |England  |  44,728|    33,580|     11,148|         0|       -40|    11,188|
|E01004397 |Walthamstow Bus Station        |England  | 111,252|   101,004|     10,248|        60|         0|    10,188|
|E01035378 |Grosvenor Street               |England  |  19,468|    11,252|      8,216|         0|         0|     8,216|
|E01033223 |Bus Station                    |England  |  69,044|    61,043|      8,001|     2,644|       -96|     5,453|
|E01021782 |Loughton Station               |England  |  19,972|    12,052|      7,920|        40|         0|     7,880|
|E01003750 |Chingford Lane (IG8)           |England  |  23,772|    16,182|      7,590|       280|         0|     7,310|
|S01016759 |Co-op Supermarket              |Scotland |  10,272|     2,710|      7,562|     6,423|         0|     1,139|
|E01003670 |St Aubyns School               |England  |  19,308|    11,768|      7,540|       240|         0|     7,300|
|E01024940 |Bus Station                    |England  |  19,908|    12,368|      7,540|     1,444|        -8|     6,104|
|E01004377 |Chelmsford Rd /Woodford New Rd |England  |  18,016|    10,484|      7,532|       240|         0|     7,292|
|E01002218 |Alexandra Avenue (HA2)         |England  |  25,380|    17,939|      7,441|         0|         0|     7,441|
|E01021766 |Audleigh Place                 |England  |  13,304|     6,712|      6,592|         0|         0|     6,592|

### Zones where BODS GTFS counts substantially more service


|Zone      |Locality                  |Country |    TNDS| BODS GTFS| Difference| Only TNDS| Only BODS| Frequency|
|:---------|:-------------------------|:-------|-------:|---------:|----------:|---------:|---------:|---------:|
|E01033620 |Church Centre             |England | 134,556|   208,620|    -74,064|         0|         0|   -74,064|
|E01034091 |Bus Station               |England |  10,995|    66,571|    -55,576|       501|    -3,578|   -52,499|
|E01033617 |Albert Street             |England | 100,336|   151,028|    -50,692|         0|         0|   -50,692|
|E01034092 |Cathedral                 |England |  11,837|    60,111|    -48,274|       498|      -212|   -48,560|
|E01033415 |Friar Street              |England |  24,918|    71,384|    -46,466|     1,544|         0|   -48,010|
|E01033140 |Parkway                   |England |   9,668|    52,895|    -43,227|       309|      -180|   -43,356|
|E01033561 |Moor St Selfridges        |England |  81,536|   122,344|    -40,808|         0|         0|   -40,808|
|E01033615 |Markets                   |England |  65,888|   100,304|    -34,416|         0|         0|   -34,416|
|E01034313 |Wolverhampton Bus Station |England |  67,926|   100,521|    -32,595|         0|         0|   -32,595|
|E01010102 |West Bromwich Bus Station |England |  60,306|    88,662|    -28,356|     2,168|         0|   -30,524|
|E01002968 |Cromwell Road Bus Station |England |  94,740|   122,222|    -27,482|        40|         0|   -27,522|
|E01031585 |Bus Station               |England |   7,228|    33,548|    -26,320|         0|   -26,532|       212|
|E01033420 |Kings Road                |England |   9,814|    35,836|    -26,022|        20|         0|   -26,042|
|E01017032 |City Shops South          |England |  32,139|    56,709|    -24,570|     1,296|         0|   -25,866|
|E01010125 |Chelmsley Interchange     |England |  33,288|    57,456|    -24,168|         0|       -32|   -24,136|

Across the 60 zones investigated in detail, the differences come to 74,163 trip-runs on services only TNDS carries, 78,597 on services only BODS GTFS carries, and a net -660,999 from services both carry at different frequencies. Missing services, not frequency differences, dominate.

## Is either source still counting the same bus twice?

A zone's total can be inflated without any extra service existing, if the feed
publishes one journey more than once. Both feeds have already been through
`UK2GTFS::gtfs_deduplicate()`, so what follows measures what that deliberately
left behind, not the sources as published.

The test used here is the looser of the two: within each zone a journey is
identified by the (stop, departure time) pairs it makes at that zone's stops,
and two trips with the same route number, the same signature and the same
operating **date** are the same bus counted twice. Removal is stricter than
that — it needs the whole itinerary to match, the route and trip attributes to
agree, and every date of the copy removed to be covered by the copy kept.
Anything reported below therefore falls in the gap between the two: copies that
overlap in the window only partly, or that one source publishes under a
different route number or operator.

The date matters to both. GTFS models a school-term journey and its holiday
twin as two trips with identical times and complementary calendars, which is
correct modelling; a test that ignored dates would call every one of those a
duplicate.


Table: Whole-feed duplicate journeys remaining, by source

|Source              | Bus trips| Distinct journeys|  Trip-days| Duplicate runs| Share|
|:-------------------|---------:|-----------------:|----------:|--------------:|-----:|
|TNDS (TransXChange) | 1,102,686|           826,884|  9,401,680|          2,896|  0.0%|
|BODS (GTFS)         | 1,128,176|           861,410| 10,000,181|         78,830|  0.8%|

Nationally, **0.8%** of the counted runs still left in BODS (GTFS) are the same journey twice on one day, against 0.0% in the other source. Across the whole feed a journey is its entire itinerary, which is a stricter test than the zone-level one below: inside a zone only the part of the trip that touches the zone's stops can be compared.

Across the 60 zones investigated, the duplicate runs still present account for a median of **0.0%** of TNDS's counted trip-days and **1.7%** of the DfT GTFS's. Totals: 17,737 of 1,940,181 TNDS trip-days and 288,370 of 2,605,098 BODS GTFS trip-days.



Table: Zones with the largest share of duplicated runs remaining in BODS GTFS

|Zone      |Locality       | TNDS trip-days|TNDS duplicate | BODS trip-days|BODS duplicate |
|:---------|:--------------|--------------:|:--------------|--------------:|:--------------|
|E01001843 |Moulins Road   |          6,044|0.0%           |              0|NA%            |
|E01013509 |Sunny Grove    |          5,284|0.0%           |              0|NA%            |
|E01021587 |Skerry Rise    |          2,502|0.0%           |         23,483|41.3%          |
|E01021592 |Cockney Corner |          2,874|0.0%           |         25,882|39.2%          |
|E01021542 |Hospital       |          3,331|0.0%           |         21,746|38.2%          |
|E01021543 |Erick Avenue   |          2,251|0.0%           |         20,658|37.6%          |
|E01033140 |Parkway        |          9,668|0.0%           |         52,895|36.9%          |
|E01034091 |Bus Station    |         10,995|0.1%           |         66,571|36.2%          |
|E01034092 |Cathedral      |         11,837|0.0%           |         60,111|33.3%          |
|E01030751 |Sunbury Cross  |         14,772|0.0%           |         35,696|30.2%          |
|E01020554 |Kings Statue   |          5,427|0.0%           |         28,832|27.1%          |
|E01034290 |High Street    |         16,004|0.0%           |         36,449|20.5%          |

A duplicate here is a statement about the feed, not about the road: two identical journeys on one day is one bus described twice. These are the ones deduplication would not remove without risking real service, so where a source's remaining excess over the other is close to its remaining duplicate share, the zone's gap is still an artefact of the feed; where it is not, the gap is real service one source lacks.

## What is actually going on in those zones

The route-level breakdown for the largest disagreement in each direction.
"Service" is a group of routes matched across the two sources on route number
and stop pattern, so a service split across several `route_id`s in one source
is compared as one thing.


### E01004513 — Mapleton Road (SW18) (England)

TNDS 25,028 trip-runs, BODS GTFS 6,142, difference **18,886**. 3 stops in the zone; 9 services only in TNDS, 0 only in BODS GTFS, 3 in both.



|Service |Description                                    |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:----------------------------------------------|-----:|---------:|----------:|:-------------------------|
|87      |Wandsworth Plain - Aldwych / Drury Lane        | 3,624|         0|      3,624|only in TNDS              |
|39      |Putney Bridge Station - Clapham Junction Stati | 3,280|         0|      3,280|only in TNDS              |
|170     |Danebury Avenue /Minstead Gdns - Victoria Stat | 3,152|         0|      3,152|only in TNDS              |
|37      |Putney Heath / Green Man - Peckham Bus Station | 3,036|         0|      3,036|only in TNDS              |
|156     |Wimbledon Bus Station - Vauxhall Bus Station   | 2,828|         0|      2,828|only in TNDS              |
|337     |Northcote Road (SW11) - Richmond Bus Station   | 2,396|         0|      2,396|only in TNDS              |
|N87     |Fairfield Bus Station - Aldwych / Drury Lane   |   560|         0|        560|only in TNDS              |
|N44     |Aldwych / Bush House - Sutton Station / The Qu |   280|       270|         10|both, different frequency |


### E01032896 — New Street (England)

TNDS 33,997 trip-runs, BODS GTFS 20,756, difference **13,241**. 27 stops in the zone; 7 services only in TNDS, 0 only in BODS GTFS, 28 in both.



|Service |Description                      |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:--------------------------------|-----:|---------:|----------:|:-------------------------|
|X38     |High Street - Corporation Street | 8,184|     4,092|      4,092|both, different frequency |
|vil     |Derby - Burton upon Trent        | 1,648|         0|      1,648|only in TNDS              |
|9       |New Street - Terminal Building   | 3,008|     1,504|      1,504|both, different frequency |
|8       |Burton - Swadlincote             | 2,552|     1,276|      1,276|both, different frequency |
|21      |New Street - Pingle School       | 1,976|       988|        988|both, different frequency |
|V3      |High Street - Bus Station        | 1,824|       912|        912|both, different frequency |
|401     |Bus Station - New Street         | 1,984|     1,152|        832|both, different frequency |
|2       |New Street - Sussex Road         | 1,140|       560|        580|both, different frequency |


### S01014636 — Salisbury Place (Scotland)

TNDS 28,240 trip-runs, BODS GTFS 15,236, difference **13,004**. 5 stops in the zone; 0 services only in TNDS, 0 only in BODS GTFS, 14 in both.



|Service |Description                                    |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:----------------------------------------------|-----:|---------:|----------:|:-------------------------|
|3       |Mayfield - Wester Hailes Clovenstone           | 4,212|     2,100|      2,112|both, different frequency |
|31      |Rosewell or Bonnyrigg - East Craigs            | 4,096|     2,048|      2,048|both, different frequency |
|37      |Silverknowes - Easter Bush or Penicuik Deanbur | 3,504|     1,792|      1,712|both, different frequency |
|7       |Newhaven - Edinburgh Royal Infirmary           | 2,940|     1,464|      1,476|both, different frequency |
|29      |Silverknowes - Gorebridge Birkenside           | 2,728|     1,344|      1,384|both, different frequency |
|49      |Fort Kinnaird - Edinburgh Royal Infirmary      | 2,660|     1,284|      1,376|both, different frequency |
|8       |Muirhouse - Edinburgh Royal Infirmary          | 2,488|     1,220|      1,268|both, different frequency |
|47      |Cammo - Penicuik Ladywood                      | 2,280|     1,144|      1,136|both, different frequency |


### E01035376 — Chester Bus Interchange (England)

TNDS 44,728 trip-runs, BODS GTFS 33,580, difference **11,148**. 26 stops in the zone; 1 services only in TNDS, 1 only in BODS GTFS, 46 in both.



|Service |Description                                    |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:----------------------------------------------|-----:|---------:|----------:|:-------------------------|
|10      |Bus Interchange - Quay Shopping Centre         | 5,304|     2,652|      2,652|both, different frequency |
|1       |Wrexham Bus Station 7 - Chester Railway Statio | 3,008|     1,504|      1,504|both, different frequency |
|11      |Chester Bus Interchange - Holywell Bus Station | 2,800|     1,400|      1,400|both, different frequency |
|4       |Chester Railway Station - Bus Station 5        | 2,304|     1,152|      1,152|both, different frequency |
|PR1     |Chester Bus Interchange - Wrexham Road, Park & | 1,832|       916|        916|both, different frequency |
|41      |Bus Interchange - Whitchurch Bus Station       | 1,216|       608|        608|both, different frequency |
|X4      |Chester Railway Station - Bus Station 5        | 1,200|       600|        600|both, different frequency |
|T8      |Corwen Interchange - Chester Railway Station S | 1,056|       468|        588|both, different frequency |


### E01004397 — Walthamstow Bus Station (England)

TNDS 111,252 trip-runs, BODS GTFS 101,004, difference **10,248**. 13 stops in the zone; 1 services only in TNDS, 0 only in BODS GTFS, 21 in both.



|Service |Description                                    |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:----------------------------------------------|-----:|---------:|----------:|:-------------------------|
|275     |Walthamstow Bus Station - Barkingside Tesco    | 7,840|     3,960|      3,880|both, different frequency |
|20      |Debden - Walthamstow                           | 6,804|     3,392|      3,412|both, different frequency |
|215     |Lee Valley Campsite - Walthamstow Bus Station  | 5,640|     2,820|      2,820|both, different frequency |
|675     |St James Street Station - Broadmead Road (IG8) |    60|         0|         60|only in TNDS              |
|N38     |Walthamstow Bus Station - Victoria Bus Station |   940|       909|         31|both, different frequency |
|N26     |Victoria Station - Chingford Station           |   644|       621|         23|both, different frequency |
|N73     |Great Titchfield Street / Oxford Circus Statio |   776|       754|         22|both, different frequency |
|55      |                                               | 6,740|     6,740|          0|both, different frequency |


### E01033620 — Church Centre (England)

TNDS 134,556 trip-runs, BODS GTFS 208,620, difference **-74,064**. 42 stops in the zone; 2 services only in TNDS, 0 only in BODS GTFS, 46 in both.



|Service |Description |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:-----------|-----:|---------:|----------:|:-------------------------|
|6       |            | 5,256|    10,952|     -5,696|both, different frequency |
|74      |            | 8,224|    13,592|     -5,368|both, different frequency |
|14      |            | 5,440|    10,096|     -4,656|both, different frequency |
|97      |            | 4,776|     8,992|     -4,216|both, different frequency |
|9       |            | 4,336|     8,276|     -3,940|both, different frequency |
|95      |            | 4,160|     7,848|     -3,688|both, different frequency |
|94      |            | 4,224|     7,892|     -3,668|both, different frequency |
|87      |            | 4,272|     7,576|     -3,304|both, different frequency |


### E01034091 — Bus Station (England)

TNDS 10,995 trip-runs, BODS GTFS 66,571, difference **-55,576**. 13 stops in the zone; 7 services only in TNDS, 4 only in BODS GTFS, 40 in both.



|Service |Description | TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:-----------|----:|---------:|----------:|:-------------------------|
|C1      |            |  817|     8,575|     -7,758|both, different frequency |
|C2      |            |  617|     6,675|     -6,058|both, different frequency |
|C10     |            |  364|     4,740|     -4,376|both, different frequency |
|C5      |            |  517|     4,843|     -4,326|both, different frequency |
|C3      |            |  348|     3,948|     -3,600|both, different frequency |
|X30     |            |    0|     3,290|     -3,290|only in BODS GTFS         |
|X30     |            |  231|     3,474|     -3,243|both, different frequency |
|C8      |            |  276|     3,444|     -3,168|both, different frequency |


### E01033617 — Albert Street (England)

TNDS 100,336 trip-runs, BODS GTFS 151,028, difference **-50,692**. 26 stops in the zone; 1 services only in TNDS, 0 only in BODS GTFS, 43 in both.



|Service |Description |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:-----------|-----:|---------:|----------:|:-------------------------|
|16      |            | 6,488|    11,768|     -5,280|both, different frequency |
|14      |            | 5,440|    10,096|     -4,656|both, different frequency |
|95      |            | 4,160|     7,848|     -3,688|both, different frequency |
|94      |            | 4,224|     7,892|     -3,668|both, different frequency |
|74      |            | 4,112|     7,300|     -3,188|both, different frequency |
|9       |            | 2,168|     4,224|     -2,056|both, different frequency |
|X51     |            | 4,104|     6,064|     -1,960|both, different frequency |
|87      |            | 2,124|     4,040|     -1,916|both, different frequency |


### E01034092 — Cathedral (England)

TNDS 11,837 trip-runs, BODS GTFS 60,111, difference **-48,274**. 13 stops in the zone; 4 services only in TNDS, 3 only in BODS GTFS, 41 in both.



|Service |Description | TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:-----------|----:|---------:|----------:|:-------------------------|
|C1      |            |  676|     7,556|     -6,880|both, different frequency |
|C5      |            |  517|     5,755|     -5,238|both, different frequency |
|C2      |            |  570|     5,146|     -4,576|both, different frequency |
|C9      |            |  286|     4,290|     -4,004|both, different frequency |
|C7      |            |  171|     3,324|     -3,153|both, different frequency |
|C8      |            |  248|     3,372|     -3,124|both, different frequency |
|C10     |            |  364|     3,444|     -3,080|both, different frequency |
|C3      |            |  342|     3,246|     -2,904|both, different frequency |


### E01033415 — Friar Street (England)

TNDS 24,918 trip-runs, BODS GTFS 71,384, difference **-46,466**. 47 stops in the zone; 7 services only in TNDS, 0 only in BODS GTFS, 48 in both.



|Service |Description |  TNDS| BODS GTFS| Difference|Cause                     |
|:-------|:-----------|-----:|---------:|----------:|:-------------------------|
|17      |            | 1,629|     6,516|     -4,887|both, different frequency |
|5       |            | 1,102|     4,408|     -3,306|both, different frequency |
|6       |            | 1,052|     4,208|     -3,156|both, different frequency |
|26      |            |   950|     3,800|     -2,850|both, different frequency |
|21      |            |   761|     3,044|     -2,283|both, different frequency |
|3       |            |   759|     3,036|     -2,277|both, different frequency |
|600     |            |   745|     2,980|     -2,235|both, different frequency |
|33      |            |   623|     2,492|     -1,869|both, different frequency |

## Interpretation

- The largest single-zone disagreement is E01033620 (Church Centre), where the two sources differ by 74,064 trip-runs over the four weeks — 35.5% of the larger of the two figures.
- Within the zones investigated, 13.2% of the difference (by trip-runs) is services one source carries and the other does not at all, against 86.8% from differing frequencies on shared services.
- 2 of the 60 zones investigated have **no counted bus service at all** in one of the two sources. For those zones the choice of source is not a matter of degree: one says the zone has a bus service and the other says it has none.
- Disagreement by country: England 62.5% of zones; Wales 36.4% of zones; Scotland 9.5% of zones 

### Why these particular zones

The zone-level pattern is the national pattern concentrated. The causes below
are ordered by how much of the remaining gap each accounts for, and the first
three were each traced to a named service rather than inferred.

- **Mode classification, not missing service.** The largest single "only in
  TNDS" entry in the whole analysis is the Nottingham tram: TNDS files
  Nottingham Express Transit ("Clifton/Toton – Phoenix Park/Hucknall", agency
  `NEXT`) as `route_type = 3`, a *bus*, while the DfT's GTFS carries trams as
  `route_type = 0`. This analysis counts buses, so every one of its 144,488
  runs is credited to TNDS alone — more than twenty times the next largest
  TNDS-only service, and the whole of the Nottingham cluster in the table
  above, including the zone whose locality is "Highbury Vale Tram Stop".
  Nothing is missing from either feed. TNDS codes trams correctly elsewhere
  (79 `route_type = 0` routes, Metrolink and Tramlink among them), so this is
  specific to NET.
- **Duplicate publication in TNDS that no signature test can see.** A run of
  services read *exactly* twice in TNDS what they read in the DfT's GTFS —
  ratio 0.50 to two decimal places on the Debden–Walthamstow 20, the 275, the
  Preston–Bolton 125, the Wrexham–Chester 1 and 4, the Derby X38 and others.
  The mechanism was measured on the Preston–Bolton 125: TNDS holds it under two
  `route_id`s of 371 trips each, and **not one pair of them is a same-day
  duplicate under any signature** — whole itinerary, stop and departure time,
  or stop alone. The two registrations describe the same service at times that
  differ, so no signature test can match them and `gtfs_deduplicate()` is right
  to keep both. Its published timetable settles which source is wrong: TNDS
  reads 2.28 of the document, the DfT's GTFS 1.14. Whether every route in this
  group shares that mechanism is inferred from the exact factor of two, not
  separately measured.
- **Country coverage.** BODS is a statutory requirement for English local bus
  services only. Scottish and Welsh services reach it only where an operator
  crosses the border or publishes voluntarily, so Welsh and Scottish zones
  supply a disproportionate share of the "only in TNDS" cases, up to and
  including zones with no BODS GTFS service at all.
- **Interchanges amplify.** A zone containing a bus station or a major
  interchange has many services calling at many stops, so a single service
  missing from one source moves that zone's total by thousands of runs. The
  largest absolute disagreements are therefore concentrated on town-centre
  zones, and are not evidence that those places are badly described — the
  *relative* column is the fairer reading for them.
- **Snapshot age.** A TNDS snapshot carries the registration operative on the
  day it was taken; the BODS change archive holds future-dated files. Where a
  registration expires inside the counting window, TNDS counts a part-window
  service and BODS GTFS a whole-window one, which appears here as a frequency
  difference on a shared service rather than a missing service. See the
  snapshot-expiry section of the comparison report for the size of this effect.
- **Route naming.** Where the two sources disagree about a service's public
  number — TNDS carrying an operator's marketing name against the DfT's short
  code — the matching links them on stop pattern alone, and only for
  single-source groups. Any pair it still fails to link is counted as exclusive
  to each source, which inflates both "only in" columns at once.
- **Duplicate publication that survives removal.** Measured above, and it works
  in both directions: a source that describes one bus twice reports twice the
  service. Most of it is now removed before counting, but `gtfs_deduplicate()`
  keeps any copy whose dates are not fully covered by the copy kept, or whose
  route number or operator differs — so what is left still moves a zone's
  total. This is one of the few causes on this list that an outside check can
  settle, and where a published timetable has been brought to bear it has
  settled it (see `pdf_validation.md`).

### Caveats

- The unit is trip-runs touching a zone, not passenger-facing frequency. A
  zone crossed by a busy corridor scores highly whether or not the service is
  useful to people living there.
- Zones are the **plain** LSOA21 / DZ22 boundaries, not the widened polygons
  the published trips-per-zone outputs use. They tile the country, so each stop
  falls in exactly one zone and each disagreement is counted once. Levels here
  are therefore about 2.3 times lower than in editions of this report published
  before August 2026, which used the widened zones — a stop falls in 2.6 of
  those on average. Only 186 of 318,931 stops fall outside all plain zones.
  Totals still do not sum to a national trip count, because a journey crossing
  several zones contributes to each.
- The service groupings come from the same route matching the comparison report
  uses, with the same limitations: a wrong pairing shows up here as a spurious
  frequency difference, and a failed pairing as a service missing from both
  directions at once.
- Zones carry only a code, so the "Locality" column is the commonest locality
  prefix among the NaPTAN names of the stops inside the zone. It names the
  place, not the LSOA.
```
