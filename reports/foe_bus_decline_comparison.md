# Have the Friends of the Earth bus-decline findings changed?





## The question

The 2023 Friends of the Earth report [*How Britain's bus services have
drastically declined*](https://policy.friendsoftheearth.uk/insight/how-britains-bus-services-have-drastically-declined)
was built on the timetable analysis in the
[TransportBlackspots](https://github.com/ITSLeeds/TransportBlackspots) repo.
This repo is a rewrite of that analysis, run after a long series of fixes to
[UK2GTFS](https://github.com/ITSLeeds/UK2GTFS), the package that converts two
decades of historic timetable formats into GTFS before anything is counted.

Those fixes changed the numbers. The question is whether they changed the
*findings*.

**Short answer: the direction survives and the size does not.** Bus service
outside London still fell heavily, rural areas still fell further than urban
ones, and London is still an enormous outlier. But the rebuilt conversion cuts
roughly 10 to 15 percentage points off the measured decline almost everywhere,
because it counts far less service in the 2004-2011 archives the baseline is
drawn from. Two individual claims in the report do not survive: London's
"almost constant level of bus provision" becomes a modest fall, and the naming
of the worst-hit local authorities changes substantially.

Along the way this turned up two defects in the pipeline's recent years, both
since fixed, described in section 7.

## What is being compared

Two runs of the same measure, over the same zones, with the same method:

| | Timetable outputs | Built |
|---|---|---|
| **Previous pipeline** | `../inputdata/pt_frequency/` (byte-identical to the TransportBlackspots `data/` folder) | November 2025 |
| **Rebuilt pipeline** | `data/` in this repo | August 2026 |

Both are `trips_per_lsoa21_22_by_mode_<year>.Rds`: scheduled vehicle
departures counted at the stops in each 2021 LSOA (2022 Data Zone in
Scotland), by mode, day of week and time band.

The analysis on top of them is a port of the published one, not a new one: the
weekday means and the `tph_daytime_avg` weighting from
`scripts/make-stats/combine_trips_per_lsoa.R`, the outlier-and-interpolation
clean from `scripts/toby-analysis/final/clean-data.R`, and the
population-weighted aggregation from
`scripts/toby-analysis/final/weighted-regional-means.R`. Both series go through
it identically, so a difference between the two columns is the timetable
conversion and not the analysis.

Four things to state before the numbers.

**The port reproduces the published figures.** Running it over the previous
pipeline's outputs recovers the published Table 3 to within a few percentage
points (section 3). That is what licenses reading the rebuilt column as a
change in the data rather than a change in the method.

**Coach has been folded back into bus.** The rebuilt pipeline codes coach
separately as GTFS extended route type 200; the previous one left coach inside
route type 3. Both columns count 3 and 200 together. This turns out to matter
very little either way (section 6).

**The published regional tables were counted over whole local authority
areas.** Published Tables 1 and 2 come from a `trips_per_la_by_mode` series
this repo does not produce, and their trips-per-hour levels (London 509, the
North East 276) are authority-wide totals. Only percentage changes are
comparable for regions. Published Table 3 *is* per-neighbourhood, so it
compares directly, levels and all.

**The previous-pipeline column is not the published run.** It is the November
2025 TransportBlackspots rerun on 2021 zones — the closest thing to the
published analysis that exists on the same geography. The published figures
came from an earlier run on 2011 zones.

## 1. The national trend


```
## Error in `UseMethod()`:
## ! no applicable method for 'mutate' applied to an object of class "NULL"
```


```
## Error:
## ! object 'trend' not found
```


| Year| Zones matched| Previous| Rebuilt| Rebuilt / previous| Zone correlation| Zone rank correlation|
|----:|-------------:|--------:|-------:|------------------:|----------------:|---------------------:|
| 2004|         31441|    22.53|   15.61|              0.693|            0.947|                 0.952|
| 2005|         39375|    26.29|   18.66|              0.710|            0.934|                 0.952|
| 2006|         39912|    27.50|   18.50|              0.673|            0.917|                 0.940|
| 2007|         40819|    35.11|   27.42|              0.781|            0.937|                 0.950|
| 2008|         42920|    34.70|   27.21|              0.784|            0.927|                 0.943|
| 2009|         42934|    33.50|   27.19|              0.812|            0.955|                 0.963|
| 2010|         42952|    33.95|   27.06|              0.797|            0.950|                 0.963|
| 2011|         42600|    32.92|   26.76|              0.813|            0.955|                 0.962|
| 2014|         39512|    22.43|   18.29|              0.816|            0.955|                 0.967|
| 2015|         39518|    21.41|   17.91|              0.836|            0.965|                 0.973|
| 2016|         39464|    21.00|   17.33|              0.825|            0.961|                 0.970|
| 2017|         39476|    20.50|   17.04|              0.831|            0.963|                 0.973|
| 2018|         42863|    26.81|   25.48|              0.950|            0.993|                 0.996|
| 2019|         42828|    28.62|   25.00|              0.874|            0.982|                 0.979|
| 2020|         42570|    21.39|   20.25|              0.947|            0.993|                 0.997|
| 2021|         42698|    24.96|   23.34|              0.935|            0.981|                 0.981|
| 2022|         42681|    25.03|   21.95|              0.877|            0.984|                 0.985|
| 2023|         42707|    25.44|   21.41|              0.841|            0.975|                 0.966|

The two curves have the same shape, and the correlation between the two runs
across the tens of thousands of individual neighbourhoods never falls below
0.92 — the rebuild is not
reshuffling *which* places have service. It is re-counting *how much*, and the
size of that re-count depends heavily on the year.

![plot of chunk ratio-chart](figures/foe-ratio-chart-1.png)

This is the finding that drives everything else. The rebuilt pipeline counts:

- about **24% less**
  service across the NPTDR years, 2004-2011;
- about **17% less**
  across the Bus Archive years, 2014-2017;
- about **10% less**
  across the TNDS years, 2018-2023.

The published baseline is the 2006-08 average and the published end point is
2023. The baseline sits in the era the rebuild changed most and the end point
in the era it changed least, so every decline measured between them gets
smaller.

## 2. By region


Table: Change in bus service, 2006-08 average to 2023

|Region                   | Published| Previous| Rebuilt| Rebuilt - previous (pp)|
|:------------------------|---------:|--------:|-------:|-----------------------:|
|North East               |      -52%|     -41%|    -40%|                    +0.7|
|Yorkshire and The Humber |      -47%|     -42%|    -39%|                    +2.9|
|North West               |      -45%|     -42%|    -37%|                    +4.6|
|Scotland                 |      -65%|     -64%|    -37%|                   +27.6|
|East Midlands            |      -60%|     -55%|    -35%|                   +20.2|
|West Midlands            |      -47%|     -42%|    -34%|                    +8.0|
|Wales                    |      -57%|     -50%|    -33%|                   +17.2|
|South West               |      -46%|     -45%|    -27%|                   +18.0|
|East of England          |      -44%|     -43%|    -26%|                   +16.9|
|South East               |      -43%|     -39%|    -17%|                   +22.4|
|London                   |        2%|       9%|     -8%|                   -16.9|

![plot of chunk region-chart](figures/foe-region-chart-1.png)



Every region outside London still shows a fall of at least
17%, so no region escapes the finding. But
two things move.

**Every regional decline is smaller**, by between +0.7 and
+27.6 percentage points.

**The ranking of regions changes materially.** The published worst three were
Scotland, East Midlands, Wales; in the rebuilt data they are
North East, Yorkshire and The Humber, North West. Scotland, the East Midlands and Wales
all move towards the middle of the table, because they are the regions whose
2004-2011 counts the rebuild cuts hardest. The rank correlation between the
published regional ordering and the rebuilt one is
0.53 across the ten regions outside London — the
"savage cuts everywhere except London" conclusion is unaffected, but which
region was worst hit is not a claim this data supports any more.


```
## Error in `UseMethod()`:
## ! no applicable method for 'select' applied to an object of class "NULL"
```

```
## Error in `UseMethod()`:
## ! no applicable method for 'select' applied to an object of class "NULL"
```

```
## Error:
## ! object 'o_reg' not found
```

The regional detail shows the re-count is not uniform. Scotland and the East
Midlands lose around 40% of their 2005-2011 counts, while Yorkshire and the
North West lose 13-16%. In the TNDS years most regions sit at 0.9 or above.
Whatever the conversion fixes did, they did it unevenly across the historic
archives, which is why the ranking of regions moves as well as the level.


Table: Change in bus service, 2010 to 2023

|Region                   | Published| Previous| Rebuilt| Rebuilt - previous (pp)|
|:------------------------|---------:|--------:|-------:|-----------------------:|
|East Midlands            |      -55%|     -49%|    -32%|                   +17.8|
|East of England          |      -33%|     -34%|    -21%|                   +13.2|
|London                   |        3%|       9%|     -9%|                   -17.4|
|North East               |      -50%|     -41%|    -41%|                    -0.8|
|North West               |      -39%|     -36%|    -31%|                    +5.4|
|Scotland                 |      -55%|     -58%|    -28%|                   +30.0|
|South East               |      -42%|     -37%|    -18%|                   +19.8|
|South West               |      -47%|     -44%|    -27%|                   +16.4|
|Wales                    |      -56%|     -49%|    -33%|                   +16.0|
|West Midlands            |      -48%|     -40%|    -32%|                    +8.6|
|Yorkshire and The Humber |      -44%|     -39%|    -36%|                    +2.5|

## 3. London, urban and rural

This is the published Table 3, and it is measured on the same geography as the
rebuild, so levels compare directly and not just changes.


|Location                              | Pub. 2006-08| Pub. 2023| Pub. change| Prev. 2006-08| Prev. 2023| Prev. change| Reb. 2006-08| Reb. 2023| Reb. change|
|:-------------------------------------|------------:|---------:|-----------:|-------------:|----------:|------------:|------------:|---------:|-----------:|
|London: not near Underground stations |         68.8|      78.5|         14%|          69.9|       80.5|          15%|         65.6|      62.8|         -4%|
|London: near Underground stations     |        127.8|     120.4|         -6%|         121.8|      120.3|          -1%|        116.2|      99.6|        -14%|
|Outside London: rural                 |          7.7|       3.7|        -52%|           8.0|        4.1|         -49%|          4.9|       3.5|        -29%|
|Outside London: urban                 |         29.5|      15.5|        -48%|          33.4|       17.7|         -47%|         24.0|      16.1|        -33%|

The three published columns and the three previous-pipeline columns agree
closely — -49% against a published -52%
for rural, -47% against -48%
for urban outside London, 15% against +14% for London away
from the Underground. The port is faithful.

The rebuilt column is a different picture in two ways.

**The falls are smaller.** Rural -29% rather than
-49%; urban outside London -33% rather than
-47%. Rural service still falls further than urban service, so
the relative claim holds, but the gap between them narrows.

**London no longer holds level.** The published finding was that London bus
provision was "almost constant", up 14% away from the Underground and down 6%
near it. The rebuilt data puts those at -4% and
-14%. That reverses the sign of the headline London claim. It
does *not* reverse the comparison that the report actually rests on: London
neighbourhoods still have four times the service of other urban ones and
eighteen times that of rural ones, and they still fell far less than anywhere
else.


```
## Error in `UseMethod()`:
## ! no applicable method for 'mutate' applied to an object of class "NULL"
```

```
## Error:
## ! object 'set_trend' not found
```


```
## Error:
## ! object 'set_trend' not found
```

Both series show the same two well-known holes: London is largely missing
before 2007 and again across the 2014-2017 Bus Archive years, which is exactly
what the published methodology warned about and imputed around. Those holes sit
between the baseline and the end point, so they shape the middle of the trend
lines without driving the headline changes.

## 4. The worst-hit local authorities

The published Table 4 named Hart, Fenland and Broxtowe as the three worst-hit
authorities. Those figures were counted over whole authority areas and these
are population-weighted neighbourhood means, so the levels differ; what matters
is whether the same places come out on top.


Table: The twenty largest proportional falls in the rebuilt data

|Local authority         |Region                   | 2006-08| 2023| Rebuilt change| Previous change| Rank, rebuilt| Rank, previous|
|:-----------------------|:------------------------|-------:|----:|--------------:|---------------:|-------------:|--------------:|
|Hart                    |South East               |     6.7|  2.0|         -70.3%|          -86.2%|             1|              1|
|Torbay                  |South West               |    16.8|  5.0|         -70.1%|          -50.9%|             2|            131|
|Fenland                 |East of England          |     6.3|  2.2|         -65.7%|          -81.4%|             3|              3|
|Cannock Chase           |West Midlands            |    11.6|  4.0|         -65.2%|          -67.2%|             4|             40|
|Mid Suffolk             |East of England          |     3.4|  1.2|         -62.8%|          -65.8%|             5|             48|
|Staffordshire Moorlands |West Midlands            |     7.2|  2.8|         -60.8%|          -76.9%|             6|              7|
|East Staffordshire      |West Midlands            |    14.0|  5.5|         -60.7%|          -62.6%|             7|             68|
|Renfrewshire            |Scotland                 |    41.1| 16.3|         -60.4%|          -73.7%|             8|             18|
|Melton                  |East Midlands            |     6.5|  2.6|         -60.3%|          -76.4%|             9|              9|
|Malvern Hills           |West Midlands            |     4.5|  1.8|         -60.2%|          -67.5%|            10|             38|
|Rotherham               |Yorkshire and The Humber |    19.8|  8.2|         -58.4%|          -57.6%|            11|             93|
|Falkirk                 |Scotland                 |    16.1|  6.9|         -57.3%|          -72.0%|            12|             21|
|Stoke-on-Trent          |West Midlands            |    24.2| 10.4|         -57.2%|          -74.3%|            13|             15|
|South Derbyshire        |East Midlands            |    12.3|  5.3|         -56.9%|          -65.5%|            14|             52|
|Clackmannanshire        |Scotland                 |    11.3|  5.0|         -56.0%|          -68.4%|            15|             32|
|North East Derbyshire   |East Midlands            |    13.9|  6.3|         -54.9%|          -62.4%|            16|             69|
|Herefordshire           |West Midlands            |     6.8|  3.1|         -54.9%|          -63.0%|            17|             64|
|Worcester               |West Midlands            |    15.8|  7.2|         -54.7%|          -65.0%|            18|             55|
|High Peak               |East Midlands            |    10.6|  4.8|         -54.7%|          -68.4%|            19|             33|
|Doncaster               |Yorkshire and The Humber |    23.1| 10.5|         -54.4%|          -35.1%|            20|            223|

This is where the rebuild bites hardest. Of the twenty authorities the report
named, 13 are in the previous pipeline's worst twenty but only
5 are in the rebuilt one's. The two pipelines agree with each
other on just 6 of twenty. Across all 349
authorities the rank correlation is 0.7 — strong enough that
the broad geography is stable, far too weak to support naming individual
places.

![plot of chunk la-scatter](figures/foe-la-scatter-1.png)


Table: The authorities the rebuild moves most

|Local authority              |Region          | Previous change| Rebuilt change| Difference (pp)|Direction                    |
|:----------------------------|:---------------|---------------:|--------------:|---------------:|:----------------------------|
|Bromley                      |London          |           54.5%|           2.7%|           -51.8|Bigger fall in rebuilt data  |
|Merton                       |London          |           46.9%|           0.6%|           -46.2|Bigger fall in rebuilt data  |
|Barking and Dagenham         |London          |           56.1%|          12.8%|           -43.3|Bigger fall in rebuilt data  |
|Greenwich                    |London          |           38.0%|           2.6%|           -35.4|Bigger fall in rebuilt data  |
|Na h-Eileanan Siar           |Scotland        |           -0.9%|         -35.7%|           -34.8|Bigger fall in rebuilt data  |
|Harrow                       |London          |           51.0%|          17.0%|           -34.0|Bigger fall in rebuilt data  |
|Lewisham                     |London          |           29.8%|          -3.7%|           -33.5|Bigger fall in rebuilt data  |
|Shetland Islands             |Scotland        |          -12.2%|         -44.0%|           -31.8|Bigger fall in rebuilt data  |
|Richmond upon Thames         |London          |           19.0%|         -11.7%|           -30.7|Bigger fall in rebuilt data  |
|Bexley                       |London          |           29.0%|          -0.5%|           -29.5|Bigger fall in rebuilt data  |
|Arun                         |South East      |          -67.6%|         -26.2%|           +41.5|Smaller fall in rebuilt data |
|Uttlesford                   |East of England |          -25.3%|          16.6%|           +42.0|Smaller fall in rebuilt data |
|Rochford                     |East of England |          -54.3%|         -12.2%|           +42.1|Smaller fall in rebuilt data |
|Lewes                        |South East      |          -33.8%|          10.6%|           +44.3|Smaller fall in rebuilt data |
|Angus                        |Scotland        |          -31.5%|          13.8%|           +45.3|Smaller fall in rebuilt data |
|Bath and North East Somerset |South West      |          -59.7%|         -14.2%|           +45.6|Smaller fall in rebuilt data |
|Slough                       |South East      |          -59.4%|         -10.2%|           +49.2|Smaller fall in rebuilt data |
|West Berkshire               |South East      |          -69.6%|         -19.7%|           +49.8|Smaller fall in rebuilt data |
|Reading                      |South East      |          -65.6%|         -13.4%|           +52.2|Smaller fall in rebuilt data |
|Wokingham                    |South East      |          -68.1%|          -6.4%|           +61.7|Smaller fall in rebuilt data |

The largest movers in one direction are almost all London boroughs, which the
rebuild takes from strong growth to roughly flat. In the other direction they
are authorities in the East of England, the South East and the East Midlands,
whose 2006-08 counts the rebuilt NPTDR conversion cuts hardest.

## 5. The London Sunday night comparison

The report's most quoted single statistic: of the 317 local authorities outside
London, only 59 had a weekday morning peak more frequent than the average
London Sunday night.


|Series            | London Sunday night, trips per hour| Authorities outside London| Of which beat it at weekday morning peak|
|:-----------------|-----------------------------------:|--------------------------:|----------------------------------------:|
|Published (2023)  |                                  NA|                        317|                                       59|
|Previous pipeline |                               28.42|                        316|                                       38|
|Rebuilt pipeline  |                               27.34|                        316|                                       29|

Neither pipeline reproduces the published count of 59, because the published
version counted over whole authority areas rather than per neighbourhood and
the authority list has changed since 2023. On this measure both pipelines are
*harsher* than the published figure. The finding is unaffected by the rebuild:
the overwhelming majority of authorities outside London have a weekday morning
peak worse than a London Sunday night.

## 6. Where the difference comes from

### Coach reclassification: almost none of it


| Year| Bus and coach| Bus only| Coach share|
|----:|-------------:|--------:|-----------:|
| 2004|         15.61|    15.61|       0.00%|
| 2005|         18.71|    18.61|       0.52%|
| 2006|         18.62|    18.43|       1.01%|
| 2007|         27.45|    27.19|       0.95%|
| 2008|         27.21|    27.02|       0.69%|
| 2009|         27.19|    27.11|       0.30%|
| 2010|         27.06|    26.98|       0.29%|
| 2011|         26.77|    26.64|       0.46%|
| 2014|         18.39|    18.34|       0.31%|
| 2015|         17.99|    17.93|       0.34%|
| 2016|         17.40|    17.34|       0.35%|
| 2017|         17.10|    17.04|       0.38%|
| 2018|         25.48|    25.32|       0.65%|
| 2019|         25.01|    24.85|       0.63%|
| 2020|         20.25|    20.23|       0.12%|
| 2021|         23.34|    23.26|       0.36%|
| 2022|         21.95|    21.86|       0.41%|
| 2023|         21.41|    21.30|       0.51%|

Coach is under 1% of scheduled service in every year, and because both columns
in this report include it, it cancels out entirely. It matters only for anyone
using the rebuilt outputs with `route_type == 3` alone, who would understate
service by the amounts above.

### The cleaning step: real, but not the explanation


| Year| Outliers replaced, previous| Outliers replaced, rebuilt| Interpolated, previous| Interpolated, rebuilt|
|----:|---------------------------:|--------------------------:|----------------------:|---------------------:|
| 2005|                        2.1%|                       2.8%|                  29.0%|                 29.2%|
| 2006|                        2.4%|                       3.6%|                  25.7%|                 29.6%|
| 2007|                        4.0%|                       6.2%|                  22.4%|                 21.8%|
| 2008|                        6.6%|                       6.1%|                  15.8%|                 16.0%|
| 2009|                        3.9%|                       5.0%|                  16.9%|                 14.4%|
| 2010|                        6.2%|                       6.6%|                   4.0%|                  5.8%|
| 2011|                        6.3%|                       5.8%|                   7.4%|                  9.6%|
| 2014|                        7.6%|                       6.1%|                  13.3%|                 13.7%|
| 2015|                        2.5%|                       3.4%|                  13.5%|                 14.0%|
| 2016|                        2.2%|                       2.4%|                  14.8%|                 15.6%|
| 2017|                        1.2%|                       1.7%|                  14.2%|                 15.6%|
| 2018|                        2.2%|                       2.3%|                  13.3%|                  5.6%|
| 2019|                        3.5%|                       3.3%|                   6.1%|                  8.2%|
| 2020|                        0.0%|                       0.0%|                   0.0%|                  0.0%|
| 2021|                        6.2%|                       4.9%|                   0.4%|                  0.7%|
| 2022|                        4.9%|                       4.9%|                   0.4%|                  0.7%|
| 2023|                        2.3%|                       3.1%|                   0.2%|                  0.7%|

The published method blanks any pre-2020 value more than one standard deviation
below its own neighbourhood's mean, and any pre-2010 value below half that
neighbourhood's peak, then interpolates the gaps. Both rules are one-sided and
apply only to early years, so they can only raise the 2006-08 baseline — and
every decline in the report is measured from that baseline. In the three
baseline years a sixth to a quarter of all neighbourhood-years are interpolated
rather than observed, in both pipelines.

Turning the cleaning off moves the headline numbers by a few percentage points
but does not change the comparison between the two pipelines:


Table: Change 2006-08 to 2023, with and without the published cleaning step

|Settlement             | Previous, uncleaned| Rebuilt, uncleaned| Previous, cleaned| Rebuilt, cleaned|
|:----------------------|-------------------:|------------------:|-----------------:|----------------:|
|London: off tube       |                 11%|                -7%|               15%|              -4%|
|London: on tube        |                 -5%|               -17%|               -1%|             -14%|
|Rural                  |                -54%|               -32%|              -49%|             -29%|
|Urban (outside London) |                -50%|               -35%|              -47%|             -33%|

### Deduplication and conversion: measured separately

The rest divides into two things that can be measured apart, and they turn out
to matter in completely different eras.

**What the feeds say.** The previous pipeline did not reconvert its sources: it
counted GTFS feeds converted in June-July 2023 (NPTDR) and November 2023
(TransXChange) and kept on the data drive. Applying one identical piece of
GTFS arithmetic to the old feed and the new one - how many departures does
each describe inside the same counting window? - isolates what reconversion
changed, with no counting code and no spatial join involved.

**What deduplication removes.** This repo's `read_feed()` runs
`UK2GTFS::gtfs_deduplicate()` between cleaning and counting. That function was
added to UK2GTFS on 2026-08-01, months after the previous outputs were built,
and TransportBlackspots went straight from `gtfs_clean()` to
`gtfs_trips_per_zone()`. It removes a journey only where the whole itinerary
matches another and every date it runs is also run by the copy kept.


Table: Rebuilt as a share of previous, split into its parts

| Year|Source | Conversion| Deduplication| Both together| Observed| Unexplained|
|----:|:------|----------:|-------------:|-------------:|--------:|-----------:|
| 2006|NPTDR  |      0.996|         0.716|         0.714|    0.673|       0.942|
| 2018|TNDS   |      0.948|         0.992|         0.940|    0.950|       1.011|
| 2023|TNDS   |      0.910|         0.992|         0.903|    0.841|       0.931|

Deduplication is measured on the feed for the year shown except 2018, which
takes the 2023 TNDS rate; deduplication removes 0.71% of trips in the 2024
snapshot and 0.71% in the 2023 one, so the TNDS rate is stable.

Read across the rows:

- **2006 is deduplication, and almost nothing else.** The two conversions of
  the NPTDR archive describe the same service to within half a percent. What
  changed is that duplicate journeys stopped being counted:
  28.4%
  of scheduled departures in the 2006 feed are a journey the archive describes
  more than once. NPTDR is assembled per administrative area and files a
  service in every area it touches - the 2006 archive has nine overlapping
  ATCO-CIF files - so this is duplication in the source, not in the converter.
- **2018 is the conversion, and almost nothing else.** Deduplication removes
  under 1% of a TNDS feed. The
  5.2% fall is the
  TransXChange converter, and conversion and deduplication together predict
  the observed figure almost exactly.
- **2023 is the conversion plus the end-point definition.** The conversion
  accounts for 9.0%; the
  remaining 6.9% is mostly the
  previous run taking the element-wise maximum of a spring and an autumn
  snapshot as its 2023 figure, which the feed comparison above cannot see
  because it uses the autumn feed alone.

So the two eras moved for unrelated reasons. The TransXChange work shows up
where you would expect it, in the TransXChange years, at 5-9%. The much larger
fall in the NPTDR years is deduplication of an archive that files the same bus
several times over — and because the published baseline is 2006-08, it is that
duplication, not the conversion, that the published decline was measured from.

Two further differences between the runs are worth separating out because they
are method, not conversion:

- **The 2023 end point is defined differently.** The previous run took the
  element-wise maximum of a spring and an autumn snapshot; the rebuilt run uses
  the November snapshot alone. Taking a maximum over two snapshots biases the
  end point upward, so this difference makes the *previous* pipeline's 2023
  decline look smaller than it otherwise would, partly offsetting the baseline
  effect that runs the other way.
- **The counting windows differ in the early years.** The previous outputs use
  calendar-month windows in several years (2005, 2006, 2007 and 2011 contain
  five Mondays rather than four); the rebuilt outputs are a whole number of
  Monday-aligned weeks throughout — 14 days, which was 28
  until October 2026 and is 14 now. Because trips per hour
  is normalised by the actual number of each weekday in the window, neither the
  calendar-month windows nor the change in length biases the measure, but it
  does mean the two runs are averaging over different stretches of the
  timetable. It is also why this comparison is made on `tph_*` and not on
  `runs_*`: the raw run counts are window totals and halved when the window
  did, in every year at once.

**Which run is closer to the truth is not fully settled here.** The validation
work in this repo — `reports/route_279_pdf_validation.md`,
`reports/route_validation_69_A1_142.md`, `reports/pdf_validation.md` — checks
converted timetables against operators' own published schedules, and confirms
the deduplication settings on modern feeds: with them the DfT feed's First
Bristol 21 lands on exactly the 3,296 journeys its operator prints, and without
them on 5,816. That is direct evidence that removing these duplicates is right.

It is evidence about BODS feeds in 2026, though, not about NPTDR in 2006. The
2006 duplication is far larger than anything seen in a modern feed, and no
NPTDR-era route has been checked against a published timetable. The mechanism
is credible and the direction is almost certainly right — an archive compiled
per administrative area really does list a cross-boundary service more than
once — but the exact size of the correction to the 2006-08 baseline, and so
the exact size of the decline, rests on a step that has not been validated on
the data it is being applied to. Checking a sample of NPTDR-era routes against
operator timetables is the single most valuable piece of follow-up work.

## 7. Two defects found and fixed on the way

### 2024 and 2025 counted nearly every bus twice

The rebuilt pipeline has 2024 and 2025, which the published report did not. As
originally built they showed scheduled service per neighbourhood roughly
doubling between 2023 and 2024 and staying there — not a change in bus
provision. `year_sources()` in `R/config.R` gave those two years **two** bus
feeds:

```
bus = list(feed("OpenBusData/GTFS/<date>/itm_all_gtfs.zip", ...),
           feed("gtfs/tnds_<date>_merged.zip", ...))
```

and `sum_feeds()` in `R/frequency.R` adds their counts. The BODS national GTFS
feed and the TNDS TransXChange conversion both cover the whole Great Britain
bus network — that overlap is the entire subject of
`reports/bus_source_comparison.md` — so nearly every journey was counted twice.
Deduplication could not catch it: `read_feed()` deduplicates within a feed, not
across two.

Those years now take local bus from TNDS alone, like 2018-2023 (coach comes
from a separate source, below), and have been recounted. Every year from 2004
to 2023 always drew its bus service from a single feed, so nothing else in this
report was affected.


```
## Error in `UseMethod()`:
## ! no applicable method for 'filter' applied to an object of class "NULL"
```

### Coach disappears from TNDS after 2024

TNDS carries national coach services in a separate NCSD archive inside each
snapshot. That archive is present up to February 2025 and gone from August 2025
onward, and the coach content of the converted feeds goes with it.


|Snapshot                 | Coach routes| Coach journeys| Share of road service|
|:------------------------|------------:|--------------:|---------------------:|
|tnds_20221102_merged.zip |          209|           8211|                 0.61%|
|tnds_20231101_merged.zip |          253|           8245|                 0.69%|
|tnds_20241004_merged.zip |          208|           8383|                 0.66%|
|tnds_20251003_merged.zip |           22|           2857|                 0.22%|
|tnds_20260204_merged.zip |           20|           2132|                 0.15%|
|tnds_20260726_merged.zip |            6|            558|                 0.04%|

What survives in October 2025 is local and regional operators — Ember, Berrys,
Green Line, Centaur, Redwing. The national network is simply absent. Left
alone this would show up as a real-looking decline in road service of a few
tenths of a percent, for a reason that is purely archival.

BODS publishes that national network as a standalone Coach dataset in
TransXChange, on the same dates as the bus feeds. Converted and trimmed to the
window the pipeline keeps, the October 2025 snapshot gives 292 coach routes and
11,269 journeys — National Express 207, Flixbus 61, Scottish Citylink 17,
Park's of Hamilton 3, Megabus 2 — and the October 2024 one 278 routes and
16,595 journeys. None of those operators appear in the TNDS snapshots at all:
the "National Express" in TNDS is National Express West Midlands and Coventry,
which are local bus operations. The two sources are genuinely disjoint, which
is what makes it safe to sum them when summing two overlapping feeds is exactly
what caused the defect above.

From 2024 the pipeline therefore takes coach from BODS and drops route type 200
from the TNDS feed, so coach comes from one source per year. That places the
source break at 2023/24 rather than letting coach fade out across 2025 and
2026. Coach is well under 1% of scheduled service throughout, so this changes
no conclusion in this report; it matters because
`../build/R/public_transport_frequency.R` folds coach into bus, where a
vanishing source would read as a falling one.

## Conclusions

1. **The report's central findings hold.** Bus service outside London fell
   heavily between 2006-08 and 2023, rural areas fell further than urban ones,
   and London remains in a completely different position from the rest of the
   country.

2. **The magnitude does not hold.** The rebuilt conversion puts the fall in
   urban areas outside London at -33% rather than
   -47%, and rural at -29% rather than
   -49%. "Roughly a third" is a better description than "roughly
   a half". The published headline numbers of 48% and 52% should not be
   repeated from this data without re-derivation.

3. **The London claim reverses in sign.** "Almost constant level of bus
   provision" becomes a fall of -4% away from the Underground
   and -14% near it. The comparison between London and everywhere
   else is untouched, and it is that comparison, not London's own trend, that
   the report's argument depends on.

4. **Individual local authorities should not be named from this data.** Only
   6 of the worst-hit twenty survive the rebuild. The
   authority-level rankings are not stable enough to carry the weight the
   published Table 4 put on them.

5. **The baseline years and the end-point years moved for different reasons.**
   The TransXChange conversion work accounts for a 5-9% fall in the years drawn
   from TransXChange. The much larger fall in the 2004-2011 baseline is
   deduplication — 28% of the departures in the 2006 archive are a journey it
   describes more than once, because NPTDR is compiled per administrative area
   and lists a cross-boundary service in each. The published decline was
   measured from a baseline inflated by that duplication.

6. **The NPTDR-era deduplication is the one step still unvalidated on its own
   data.** It is validated on modern feeds against printed timetables, and the
   mechanism is credible, but no NPTDR-era route has been checked. Doing so
   would settle how much of the published decline was real. That is the obvious
   next piece of work.

## Caveats

- **Scheduled service, not service delivered.** Everything here comes from
  published timetables. Cancellations and reliability are not in the data.
- **The 2014-2017 years have known gaps**, London most of all. Both pipelines
  have them and the published method interpolates across them.
- **Regional levels are not comparable with the published ones**, only
  percentage changes; the published regional series was counted over whole
  authority areas.
- **The previous-pipeline column is the November 2025 rerun**, not the run that
  produced the published figures.

## Reproducing this

```
Rscript scripts/foe_comparison/run_foe_comparison.R        # ~1 hour
Rscript scripts/foe_comparison/add_raw_trends.R
# the measurements behind section 6
Rscript scripts/foe_comparison/compare_feed_service_days.R  # 2006 2008 2010 2018 2023
Rscript scripts/foe_comparison/dedup_rate.R                 # one feed per run
Rscript scripts/foe_comparison/coach_coverage.R
Rscript scripts/foe_comparison/explore_bods_coach.R 20251006
cd reports && Rscript -e 'knitr::knit("foe_bus_decline_comparison.Rmd", "foe_bus_decline_comparison.md")'
```

Standalone by design; none of it is part of the targets pipeline. Knitting from
inside `reports/` keeps the figure links relative to it, and `knitr::knit`
rather than `rmarkdown::render` avoids the pandoc dependency, matching the
other reports in this folder.
