# Everything that is not a bus



Bus is 97% of the journeys in this pipeline and the whole of the question the
pipeline was built to answer, so every other validation stage here is
hard-filtered to `route_type == 3` — `R/comparison.R:212`, `R/lsoa_gap.R:43`,
`R/route_match.R:169` — and `reports/near_duplicate_journeys.md` scopes its
deduplication rule to "buses only" on purpose.

The cost of that became clear in September 2026, when three defects were found
in quick succession. Two of them were invisible to a bus-only check by
construction, and had been in the published outputs for months:

1. **Duplicate published copies of Underground lines.** TfL files one line
   into TNDS as several TransXChange documents with overlapping validity.
   UK2GTFS blanked any `LineName` longer than six characters to pass a
   validation check, and `gtfs_deduplicate()` keys an unnamed route on its own
   `route_id` — so 93% of metro trips could not be grouped with their own
   duplicates. Leytonstone read 96.8 trips per hour in 2021 against 55 in
   neighbouring years.
2. **`gtfs_merge()` numbered `file_id` per table**, so a feed with no
   `calendar_dates` shifted every later feed's cancellations onto the
   preceding feed's services. This one hit *bus* hardest, and was still missed,
   because nothing compared a merged feed against the regions that went into
   it.
3. **The NAPTAN join ran after the mode rules**, silently disabling the
   thirteen rules that identify a system by its stops' names. The Docklands
   Light Railway came out as heavy rail in half the series.

This report is the standing check for that blind spot. It is deliberately not
"the same tests with a different filter": it asks the questions whose absence
let those three through.

Coach (`route_type` 200) is included even though it is a road mode. The
sources disagree about where coach belongs, and `load_pt_frequency()` in the
`build` repo folds it back into bus — so a defect in coach lands inside the
bus figures, where no bus check will look for it.


Table: Feeds audited

|side | feeds| years|
|:----|-----:|-----:|
|bus  |    24|    21|
|rail |     9|     9|

## 1. Does every system carry the same mode in every feed?

This is the test that found defect 3, and it is the one to run first after any
change to a converter. A system is identified the way
`UK2GTFS::standard_mode_overrides()` identifies it — at least 80% of a route's
distinct stops matching that system's NAPTAN name pattern — and the route's
*actual* `route_type` is reported beside it. Identification is by stop name
rather than operator code because operator codes are not stable between
archives: NPTDR reuses them across eras, and `CAB` means something different
before the cable car opened in 2012.

A system with more than one mode across the series means the published metro,
tram and rail totals are not comparable between years.


Table: Modes each system is given, across every feed

|system                      |modes | n_modes| feeds|
|:---------------------------|:-----|-------:|-----:|
|Birmingham Air-Rail Link    |tram  |       1|    11|
|Blackpool Tramway           |tram  |       1|    16|
|Croydon Tramlink            |tram  |       1|     5|
|Docklands Light Railway     |metro |       1|    14|
|Edinburgh Trams             |tram  |       1|    13|
|Gatwick Airport shuttle     |tram  |       1|    16|
|Glasgow Subway              |metro |       1|    20|
|Heritage and minor railways |rail  |       1|    19|
|London Underground          |metro |       1|    14|
|Manchester Metrolink        |tram  |       1|    21|
|Midland Metro               |tram  |       1|    20|
|Nottingham Express Transit  |tram  |       1|    16|
|Sheffield Supertram         |tram  |       1|     5|
|Tyne and Wear Metro         |metro |       1|    16|

**14 systems, every one of them consistent.** No system is filed under two different modes anywhere in the series.



Trips per system and year, for the systems the mode rules name. Read down a
column rather than across a row: a system's *mode* should never change, but its
trip count reflects what the archive for that year happens to contain.


Table: Trips per system per year, bus-side feeds

|sys                         | 2004| 2005| 2006|  2007|  2008|  2009|  2010|  2011| 2014| 2015|  2016| 2017|  2018|  2019|  2020|  2021|  2022|  2023|  2024|  2025|  2026|
|:---------------------------|----:|----:|----:|-----:|-----:|-----:|-----:|-----:|----:|----:|-----:|----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|
|Birmingham Air-Rail Link    |    0|    0|    0|     0|     0|     0|     0|     0|    0|    0|  8740| 9986|  6239|  3747|  3747|  3747|  3747|  3747|  3786|  3786|  3786|
|Blackpool Tramway           |    0|    0|    0|   925|   966|  1139|   906|   368|  784|    0|  1294| 1290|   476|   568|     0|   744|   402|   402|   479|   740|   416|
|Croydon Tramlink            |    0|    0|    0|  1518|  1789|  1709|  1734|  1747|    0|    0|     0|    0|     0|     0|     0|     0|     0|     0|     0|     0|     0|
|Docklands Light Railway     |    0|    0|    0|  3541|  3628|  3586|  3763|  4149|    0|    0|     0|    0| 10235| 15573|  3684|  6375| 12270| 10709|  5014| 14683|  9588|
|Edinburgh Trams             |    0|    0|    0|     0|     0|     0|     0|     0| 1260| 1260|  1260| 1124|   562|   852|   152|   846|   830|   885|   885|   893|   893|
|Gatwick Airport shuttle     |    0|    0|    0|     0|   492|     0|  1476|   492| 9504| 8520|  9504| 8520|  2460|  4260|  1968|   492|   492|   492|   492|   492|   984|
|Glasgow Subway              |    0|  505|  505|   507|   498|   498|   498|   498|  992| 1984|  1984| 1984|   992|   992|   992|  1740|  1740|  1740|   870|   870|   870|
|Heritage and minor railways |    0|    0|   32|    26|    39|   169|   328|   115|  286|  421|   490|  370|   588|   322|   141|    28|   134|   138|   240|   304|   230|
|London Underground          |    0|    0|    0| 26272| 24579| 24574| 24172| 29206|    0|    0|     0|    0| 81644| 85854| 65051| 45625| 67133| 78589| 55718| 62701| 55865|
|Manchester Metrolink        |  758|  236| 1914|  1911|  1356|  1675|  1920|  2693| 6166| 7882| 10090| 8822|  5902|  6561|  2902|  5221|  4033|  5683| 15225| 28648|  5642|
|Midland Metro               |    0|  705|  706|   706|   658|   658|   658|   658| 2608| 1580|  1498| 1632|  1037|   677|   522|   631|  2174|   622|   693|   718|   752|
|Nottingham Express Transit  |    0|    0|    0|     0|     0|  1373|  1381|  1903| 7208| 5370|  9688| 8760|  4323|  4789|  3426|  3890|  3891|  4242|  5344|  3822|  6556|
|Sheffield Supertram         |    0|    0|    0|  2652|  2652|  2651|  2644|  2638|    0|    0|     0|    0|     0|     0|     0|     0|     0|     0|     0|     0|     0|
|Tyne and Wear Metro         |    0|    0|    0|     0|     0|  1108|  1108|  1351| 2240| 3761|  3241| 2232|  3154|  3286|  4495|  2353|  4451|  3536|  1645|  1015|  2307|

## 2. Is any line published as more than one live copy?

The defect that started this work. For each line and each date inside the
counting window: how many journeys all live copies claim between them,
against how many the single largest copy claims alone. The difference is
service that exists only because the same timetable was published twice.

Counting per date matters. A superseded copy with a short calendar is
legitimate on the dates its replacement does not cover, and taking the largest
copy rather than the first stops a genuine mid-window timetable change being
scored as duplication. A feed-level count gets 2019 wrong in the other
direction: that year's copies are cancelled by exception on weekdays but not
on Saturdays, so a weekday-only check sees nothing at all.

**Read `measurable` before `pct`.** The measure groups copies of a line by its
name, so it assumes one `route_id` is one published timetable. That holds for
TransXChange but not for ATCO-CIF: NPTDR gives every metro route a blank
`route_long_name` and splits one line across hundreds of `route_id`s carrying a
few trips each — 920 routes under 18 line codes in 2007, 136 of them District
line. Grouping those by name reported 79% of Underground service as duplicated
when none of it was. Unnamed routes are therefore keyed individually and can
never be grouped, exactly as `gtfs_deduplicate()` treats them, and
`measurable` reports how much of each mode's service sits on routes the measure
can see. **`pct = 0` with `measurable = 0` means "cannot tell", not "no
duplication".** The NPTDR years are almost entirely unmeasurable this way; what
protects them is `gtfs_deduplicate()`'s exact-itinerary matching, which does not
depend on names.


Table: Phantom trip-days by mode and year

| year|mode        | trip_days| phantom|  pct| lines| lines_affected| measurable|
|----:|:-----------|---------:|-------:|----:|-----:|--------------:|----------:|
| 2004|coach       |        80|       0|  0.0|     8|              0|        0.0|
| 2004|ferry       |     15362|       0|  0.0|    33|              0|        0.0|
| 2004|metro       |      3312|      72|  2.2|    74|              2|      100.0|
| 2004|rail        |    993654|     291|  0.0| 43241|             54|      100.0|
| 2004|tram        |     32008|       0|  0.0|   107|              0|        0.0|
| 2005|air         |     32990|       0|  0.0|  1033|              0|        0.0|
| 2005|coach       |    150594|       0|  0.0|   906|              0|        0.0|
| 2005|ferry       |     41066|       0|  0.0|   228|              0|        0.0|
| 2005|metro       |      4820|       0|  0.0|     8|              0|        0.0|
| 2005|rail        |    722526|      12|  0.0| 44799|              2|      100.0|
| 2005|tram        |     32008|       0|  0.0|   130|              0|        0.0|
| 2006|air         |      7926|       0|  0.0|  1006|              0|        0.0|
| 2006|coach       |    220211|       0|  0.0|  1575|              0|        0.0|
| 2006|ferry       |     59640|       0|  0.0|   210|              0|        0.0|
| 2006|metro       |      7979|       0|  0.0|    64|              0|        0.0|
| 2006|rail        |    722754|       0|  0.0| 46420|              0|      100.0|
| 2006|tram        |     49554|       0|  0.0|   145|              0|        0.0|
| 2007|air         |      9160|       0|  0.0|  1020|              0|        0.0|
| 2007|coach       |    222394|       0|  0.0|  1797|              0|        0.0|
| 2007|ferry       |     65509|       0|  0.0|   263|              0|        0.0|
| 2007|metro       |    148570|       0|  0.0|   864|              0|        0.0|
| 2007|rail        |    672300|      10|  0.0| 46057|              2|      100.0|
| 2007|tram        |     70740|       0|  0.0|   227|              0|        0.0|
| 2008|air         |     10376|       0|  0.0|  1030|              0|        0.0|
| 2008|coach       |    171134|       0|  0.0|  1340|              0|        0.0|
| 2008|ferry       |     72464|       0|  0.0|   289|              0|        0.0|
| 2008|metro       |    147578|       0|  0.0|   982|              0|        0.0|
| 2008|rail        |    691276|       2|  0.0| 48248|              1|       99.9|
| 2008|tram        |     68794|       0|  0.0|   213|              0|        0.0|
| 2009|air         |     20312|       0|  0.0|  1037|              0|        0.0|
| 2009|coach       |    120512|       0|  0.0|  1166|              0|        0.0|
| 2009|ferry       |     72937|       0|  0.0|   281|              0|        0.0|
| 2009|metro       |    158755|       0|  0.0|  1001|              0|        0.0|
| 2009|rail        |    711050|      22|  0.0| 49929|              4|       99.9|
| 2009|tram        |     62857|       0|  0.0|   215|              0|        0.0|
| 2010|coach       |    115829|       0|  0.0|  1140|              0|        0.0|
| 2010|ferry       |     74036|       0|  0.0|   299|              0|        0.0|
| 2010|metro       |    147993|       0|  0.0|   984|              0|        0.0|
| 2010|rail        |    742030|       0|  0.0| 52363|              0|       99.8|
| 2010|tram        |     70587|       0|  0.0|   232|              0|        0.0|
| 2011|coach       |    153924|       0|  0.0|  1332|              0|        0.0|
| 2011|ferry       |     64019|       0|  0.0|  2927|              0|       25.5|
| 2011|metro       |    157312|       0|  0.0|  1128|              0|        0.1|
| 2011|rail        |    731832|      14|  0.0| 52745|              3|       99.9|
| 2011|tram        |     78132|       0|  0.0|   246|              0|        0.0|
| 2014|air         |        40|      20| 50.0|     1|              1|      100.0|
| 2014|coach       |     20881|    4193| 20.1|    89|             24|      100.0|
| 2014|ferry       |     27170|    9407| 34.6|    80|             63|      100.0|
| 2014|metro       |     10772|    2474| 23.0|     4|              1|      100.0|
| 2014|rail        |       314|      52| 16.6|     4|              2|      100.0|
| 2014|tram        |     61572|   13210| 21.5|    15|             10|      100.0|
| 2015|coach       |     23026|    3820| 16.6|    84|             21|      100.0|
| 2015|ferry       |     47619|    8308| 17.4|   102|             60|      100.0|
| 2015|metro       |     15466|    7302| 47.2|    10|              4|      100.0|
| 2015|rail        |       921|      49|  5.3|    10|              2|      100.0|
| 2015|tram        |     59578|    3599|  6.0|    15|              4|      100.0|
| 2016|coach       |     24900|       0|  0.0|    86|              0|      100.0|
| 2016|ferry       |     49431|       0|  0.0|   101|              0|      100.0|
| 2016|metro       |     15967|     234|  1.5|    10|              3|      100.0|
| 2016|rail        |       912|       0|  0.0|     9|              0|      100.0|
| 2016|tram        |     67832|       0|  0.0|    21|              0|      100.0|
| 2017|coach       |     23292|       0|  0.0|   110|              0|      100.0|
| 2017|ferry       |     49588|     154|  0.3|   106|              1|      100.0|
| 2017|metro       |     15336|      10|  0.1|    13|              2|      100.0|
| 2017|rail        |       873|       0|  0.0|     9|              0|      100.0|
| 2017|tram        |     66454|       0|  0.0|    17|              0|      100.0|
| 2018|aerial lift |      3940|       0|  0.0|     1|              0|      100.0|
| 2018|coach       |     54465|       0|  0.0|   282|              0|      100.0|
| 2018|ferry       |     59961|     140|  0.2|   126|              1|      100.0|
| 2018|metro       |    164162|    2460|  1.5|    16|              1|      100.0|
| 2018|rail        |      1300|       0|  0.0|    11|              0|      100.0|
| 2018|tram        |     76748|       0|  0.0|    19|              0|      100.0|
| 2019|aerial lift |      3940|       0|  0.0|     1|              0|      100.0|
| 2019|coach       |     54528|       0|  0.0|   273|              0|      100.0|
| 2019|ferry       |     55061|       0|  0.0|   111|              0|      100.0|
| 2019|metro       |    203843|   41679| 20.4|    18|              8|      100.0|
| 2019|rail        |       604|       0|  0.0|     6|              0|      100.0|
| 2019|tram        |     78322|       0|  0.0|    18|              0|      100.0|
| 2020|aerial lift |      3364|       0|  0.0|     1|              0|      100.0|
| 2020|coach       |      8180|       0|  0.0|    78|              0|      100.0|
| 2020|ferry       |     40061|       0|  0.0|    76|              0|      100.0|
| 2020|metro       |    145288|    2385|  1.6|    15|              2|      100.0|
| 2020|rail        |       240|       0|  0.0|     2|              0|      100.0|
| 2020|tram        |     60876|       0|  0.0|    16|              0|      100.0|
| 2021|aerial lift |      4084|       0|  0.0|     1|              0|      100.0|
| 2021|coach       |     32812|       0|  0.0|   167|              0|      100.0|
| 2021|ferry       |     48228|     140|  0.3|    97|              1|      100.0|
| 2021|metro       |    164952|   14514|  8.8|    17|              7|      100.0|
| 2021|rail        |       188|       0|  0.0|     5|              0|      100.0|
| 2021|tram        |     77756|       0|  0.0|    18|              0|      100.0|
| 2022|aerial lift |      4084|       0|  0.0|     1|              0|      100.0|
| 2022|coach       |     37640|       0|  0.0|   163|              0|      100.0|
| 2022|ferry       |     45163|       0|  0.0|    93|              0|      100.0|
| 2022|metro       |    171600|   11189|  6.5|    18|              5|      100.0|
| 2022|rail        |        94|       0|  0.0|     2|              0|      100.0|
| 2022|tram        |     74588|       0|  0.0|    17|              0|      100.0|
| 2023|aerial lift |      4180|       0|  0.0|     1|              0|      100.0|
| 2023|coach       |     46840|     280|  0.6|   187|              3|      100.0|
| 2023|ferry       |     44714|       0|  0.0|    91|              0|      100.0|
| 2023|metro       |    164682|    5046|  3.1|    18|              4|      100.0|
| 2023|rail        |        22|       0|  0.0|     2|              0|      100.0|
| 2023|tram        |     83754|       0|  0.0|    19|              0|      100.0|
| 2024|aerial lift |      3940|       0|  0.0|     1|              0|      100.0|
| 2024|coach       |    110532|       0|  0.0|   223|              0|      100.0|
| 2024|coach       |     45446|     910|  2.0|   192|              1|      100.0|
| 2024|ferry       |     49695|       0|  0.0|   104|              0|      100.0|
| 2024|metro       |    154528|    1026|  0.7|    15|              2|      100.0|
| 2024|rail        |       540|       0|  0.0|     6|              0|      100.0|
| 2024|tram        |     88351|       0|  0.0|    35|              0|      100.0|
| 2025|aerial lift |      3556|       0|  0.0|     1|              0|      100.0|
| 2025|coach       |     74138|       0|  0.0|   212|              0|      100.0|
| 2025|coach       |      4724|       0|  0.0|    16|              0|      100.0|
| 2025|ferry       |     46694|       0|  0.0|   106|              0|      100.0|
| 2025|metro       |    173486|   24499| 14.1|    15|              9|      100.0|
| 2025|rail        |       904|       0|  0.0|     8|              0|      100.0|
| 2025|tram        |     86186|       0|  0.0|    21|              0|      100.0|
| 2026|aerial lift |      3556|       0|  0.0|     1|              0|      100.0|
| 2026|coach       |     92474|    1456|  1.6|   210|              2|      100.0|
| 2026|coach       |      1932|       0|  0.0|     5|              0|      100.0|
| 2026|ferry       |     49786|       0|  0.0|   106|              0|      100.0|
| 2026|metro       |    175470|   25377| 14.5|    15|              7|      100.0|
| 2026|rail        |       632|       0|  0.0|     9|              0|      100.0|
| 2026|tram        |     69926|    4709|  6.7|    22|              1|      100.0|

![plot of chunk phantom_chart](figures/nonbus-phantom_chart-1.png)

The lines carrying the most duplication, whatever mode they are in:


Table: Most duplicated lines

| year|mode  |line                                           | trip_days| phantom|  pct|
|----:|:-----|:----------------------------------------------|---------:|-------:|----:|
| 2019|metro |broadway ealing station upminster              |     33208|   15535| 46.8|
| 2019|metro |5 cockfosters heathrow terminal                |     22046|   10542| 47.8|
| 2019|metro |aldgate amersham                               |     19755|    9720| 49.2|
| 2026|metro |aldgate amersham station                       |     19233|    9237| 48.0|
| 2025|metro |bank lewisham station                          |     29148|    8038| 27.6|
| 2015|metro |circle glasgow outer                           |      9464|    7206| 76.1|
| 2025|metro |aldgate amersham station                       |     17146|    7150| 41.7|
| 2026|metro |epping ruislip west                            |     20054|    5842| 29.1|
| 2021|metro |broadway ealing station upminster              |     22870|    5509| 24.1|
| 2026|tram  |beckenham junction station stop tram wimbledon |     14277|    4709| 33.0|
| 2022|metro |bank lewisham station                          |     29480|    4672| 15.8|
| 2025|metro |5 cockfosters heathrow station terminal        |     15569|    4520| 29.0|
| 2019|metro |epping ruislip west                            |     17743|    3636| 20.5|
| 2023|metro |broadway ealing station station upminster      |     20599|    3254| 15.8|
| 2022|metro |5 cockfosters heathrow terminal                |     14713|    3121| 21.2|
| 2021|metro |aldgate amersham                               |     13120|    3014| 23.0|
| 2026|metro |bank lewisham station                          |     24066|    2952| 12.3|
| 2025|metro |broadway ealing station station upminster      |     17032|    2862| 16.8|
| 2022|metro |broadway ealing station station upminster      |     19980|    2635| 13.2|
| 2026|metro |stanmore station station stratford             |     15410|    2613| 17.0|
| 2021|metro |bank lewisham station                          |     21888|    2475| 11.3|
| 2014|metro |circle glasgow outer                           |      4732|    2474| 52.3|
| 2018|metro |bank lewisham station                          |     26186|    2460|  9.4|
| 2014|tram  |ashton eccles lyne under                       |      4396|    2216| 50.4|
| 2026|metro |broadway ealing station station upminster      |     16032|    1880| 11.7|

## 3. Which routes are exempt from deduplication?

`route_short_name` is the field `gtfs_deduplicate()` groups candidate routes
on. An unnamed route is keyed on its own `route_id`, so it can never share a
group with its own duplicate — a blank name is an exemption from
deduplication.

**This table should be all zeros, and that is the test.** It is the direct
regression check on the fix that stopped UK2GTFS deleting long line names:
`transxchange_export.R` used to blank any `LineName` over six characters to
pass a validation check, which removed `Central`, `Piccadilly` and
`Bakerloo` while leaving `Circle` — the only named Underground route in the old
feeds. Measured on `tnds_20211012` either side of the fix:

| mode | trips on unnamed routes, before | after |
|---|---|---|
| metro | **93.5%** | 0% |
| ferry | 48.2% | 0% |
| tram | 28.8% | 0% |
| rail | 11.5% | 0% |
| bus | 0.6% | 0% |

A non-zero cell below means the truncation has returned, and with it the
exemption that let one Underground line be counted twice.


Table: % of trips on routes with no route_short_name

|mode        | 2004| 2005| 2006| 2007| 2008| 2009| 2010| 2011| 2014| 2015| 2016| 2017| 2018| 2019| 2020| 2021| 2022| 2023| 2024| 2025| 2026|
|:-----------|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|
|aerial lift |   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|air         |   NA|    0|    0|    0|    0|    0|   NA|   NA|    0|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|   NA|
|bus         |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|coach       |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|ferry       |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|metro       |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|rail        |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|
|tram        |    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|    0|

## 4. Is the same service counted from two feeds at once?

From 2018 each year sums a bus feed and a rail feed. `sum_feeds()` adds their
counts, so any service in both is counted twice. Matching stop ids cannot
detect it — TNDS uses ATCO codes and the rail CIF uses TIPLOCs — but the zone
join is spatial, so a double count lands in whichever zone holds the station.

Identification here is by `route_type` and **agency name**, not by stop-name
pattern. The patterns in `standard_mode_overrides()` are NAPTAN names
("Bank DLR Station"); the rail CIF names its stops from TIPLOCs and matches
none of them, so a stop-pattern check on a rail feed finds nothing and cannot
tell "no overlap" from "cannot see" — the first version of this section
silently reported the former. The CIF does name its operators plainly, so that
is what is used.

`drop_route_types = 1` on the rail feed is the fix already in
`year_sources()`; `dropped` records whether it was applied for that year.


Table: Tram and metro service inside each year's rail feed

| year|agency_name               |mode  | routes| trips|dropped |
|----:|:-------------------------|:-----|------:|-----:|:-------|
| 2018|London Underground        |metro |     41|  4009|TRUE    |
| 2018|Tyne & Wear Metro         |metro |     13|  1410|TRUE    |
| 2019|London Underground        |metro |     30|  2721|TRUE    |
| 2019|Tyne & Wear Metro         |metro |     24|  1011|TRUE    |
| 2020|London Underground        |metro |     49|  5798|TRUE    |
| 2020|Tyne & Wear Metro         |metro |     18|  1400|TRUE    |
| 2021|London Underground        |metro |     41|  1901|TRUE    |
| 2021|Tyne & Wear Metro         |metro |     15|   967|TRUE    |
| 2022|London Underground        |metro |     42|  4608|TRUE    |
| 2022|Tyne & Wear Metro         |metro |     10|   936|TRUE    |
| 2022|West Midlands Trains      |metro |      1|     1|TRUE    |
| 2023|London Underground        |metro |     32|  4297|TRUE    |
| 2023|Tyne & Wear Metro         |metro |     17|   975|TRUE    |
| 2024|London Underground        |metro |     36|  5723|TRUE    |
| 2024|Nexus (Tyne & Wear Metro) |metro |     13|   972|TRUE    |
| 2024|Great Northern            |metro |      1|     1|TRUE    |
| 2025|London Underground        |metro |     31|  6092|TRUE    |
| 2025|Nexus (Tyne & Wear Metro) |metro |     14|   966|TRUE    |
| 2026|London Underground        |metro |     47|  4780|TRUE    |
| 2026|Nexus (Tyne & Wear Metro) |metro |     16|  1496|TRUE    |

**0 of 20 rows are NOT excluded by `drop_route_types`** — every one of these is dropped before counting, so none is double counted.

## 5. When is each mode actually in the series?

Not a defect — a comparability trap, and the one most likely to mislead a
reader of the published outputs. A mode that vanishes for a block of years, or
moves by an order of magnitude between adjacent years, is showing which
archive that year came from and not a change in service.


Table: National afternoon-peak tph by mode and year (bus excluded)

|mode        |  2004|  2005|  2006|  2007|  2008|  2009|  2010|  2011| 2014| 2015|  2016|  2017|  2018|  2019|  2020|  2021|  2022|  2023|  2024|  2025|
|:-----------|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|----:|----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|
|tram        |  4847|  5659|  5584|  8863|  8797|  7683|  8679|  9198| 8408| 8199| 10367| 10529| 13201| 13669|  9168| 12391| 11939| 13693| 13977| 14121|
|metro       |    63|  2433|  3713| 71508| 70707| 72089| 71349| 71862| 4978| 4992|  4977|  4803| 80000| 90324| 67018| 78489| 79796| 79028| 77448| 76993|
|rail        | 47384| 51421| 52031| 52166| 52867| 52761| 58738| 58817|    3|   15|    17|    16| 63201| 65004| 57809| 58437| 60804| 62772| 62537| 63979|
|ferry       |   150|   461|   635|  1105|  1503|  1286|  1299|  1254|  450|  774|   823|   864|  1655|  1615|  1051|  1497|  1285|  1234|  1339|  1242|
|aerial lift |     0|     0|     0|     0|     0|     0|     0|     0|    0|    0|     0|     0|   240|   240|   240|   240|   240|   240|   240|   240|
|coach       |     0|  5432| 11730| 16961|  8740|  4235|  3558|  5564| 5136| 4976|  4762|  4319|  7606|  6789|  1320|  3814|  4179|  5072|  4381|  4274|
|air         |     0|   174|    67|   107|   117|   147|     0|     0|    1|    0|     0|     0|     0|     0|     0|     0|     0|     0|     0|     0|

![plot of chunk series_chart](figures/nonbus-series_chart-1.png)

The breaks a reader needs to know about, each measured from the table above:

- **2004** — the Underground is inside the *bus* totals. `nptdr.R` converts
  that year with `clean_route_type(guess_bus = TRUE)`.
- **2004–2006** — four tram systems sat in the *metro* totals, because the
  stop-name patterns were written from the 2006 and later archives and these
  years name the same stops differently or not at all. Manchester Metrolink
  (2004, 2005), Sheffield Supertram (2004–2006), Nottingham Express Transit
  (2004) and the Blackpool Tramway (2005, 2006). Sheffield in 2005 and
  Nottingham in 2004 are each split across metro *and* bus in the same archive,
  with both halves calling at the same tram stops. Now corrected by rules keyed
  directly on the operator codes in these specific archives, which is safe only
  because NPTDR ended in 2011 and will not be republished. Blackpool needed no
  correction in 2004, because the tramway is **not in that archive**: neither
  terminus appears (no stop named "Fleetwood Ferry" or "Starr Gate", against 1
  and 4 in 2005), no route calls predominantly at a tram stop, and the whole
  Blackpool area carries 167 stops against 1,050 in 2005. That is a coverage
  gap, not a misclassification, and it means the 2004 metro total was never
  inflated by Blackpool.
- **2005–2006** — no Underground and no Docklands Light Railway at all.
- **2012–2013** — no data of any kind; the archive does not exist.
- **2014–2017** — the Bus Archive era. The metro series here is Tyne and Wear
  and the Glasgow Subway, and no London Underground in any of the four years.
  An earlier version of this report said 2016 carried 66 Underground routes and
  6,778 trips: those routes exist, but agency `LUL` in that archive is
  **Lancashire United Ltd**, not London Underground, and they are buses around
  Preston and Burnley that the operator-code rule relabelled as metro. The
  guard now in `apply_standard_modes()` stops that.
- **2015–2023, all sources** — the Glasgow Subway, the Docklands Light Railway
  and Sheffield Supertram are each published twice, once against station-level
  NAPTAN codes and once against platform codes, so every train is counted
  twice. It shows up as the Subway being 64 routes in 2014 and 128 in 2015, and
  as a Glasgow zone reporting 720 tph where the true figure is 360. It stops in
  2024 only because NAPTAN stopped issuing the station-level code. None of that
  is a service change.
- **2018 onwards** — TNDS plus the rail CIF, with the Underground and the DLR
  both present and both metro.

Because of the 2014–2017 block in particular, the metro series should not be
read as a single continuous measure across 2004–2025.

## 6. What this report does not cover

- **No external validation of non-bus frequency.** The bus series has been
  checked against operators' published timetables journey-for-journey
  (`route_279_pdf_validation.md`, `route_validation_69_A1_142.md`). Nothing
  equivalent exists for any fixed-track mode. The Leytonstone figure of
  ~55 trips per hour is consistent across eight snapshots and plausible for
  the Central line, but it has never been checked against a TfL timetable.
- **Ferry and air are reported but not examined.** Both are small enough that
  a defect in them would not move the published totals, and neither has a
  duplicate-copy mechanism of the kind found in metro.
- **Trolleybus (`route_type` 11) appears in no feed** in this series. It is
  kept in the mode list so that a source which starts using it is noticed
  rather than silently mapped elsewhere.
- **The phantom measure is an estimate of duplication, not a correction.** It
  says how much service is claimed more than once; it does not say which copy
  a deduplicator should keep. `gtfs_deduplicate(fixed_track = )` does that,
  and its own effect is reported in `metro_duplicate_copies.md`.


---

Generated 2026-10-06 11:31 from `data/non_bus_audit.Rds` by the `non_bus_report` target.
