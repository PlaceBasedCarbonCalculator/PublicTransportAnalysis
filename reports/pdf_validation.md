

# Validating the sources against published timetables

The multi-year comparison in `bus_source_comparison.md` can say that TNDS,
BODS TransXChange and BODS GTFS disagree; only an operator's own published
timetable says which of them is right. This checks individual routes against
the documents in `data/example_timetables/`.

Published timetables are easy to obtain for the current week and hard to
obtain for the past, so this uses a **current snapshot** rather than one of
the historic comparison snapshots.

Two sources, not three. BODS TransXChange is excluded here because it is not an
independent answer to the question a document settles: it is the same
operator-published data the DfT's GTFS is made from, differing mainly in which
revision of each dataset survives de-duplication and in who converted it. What a
PDF can adjudicate is TNDS against the DfT's rendering; adding a third column
derived from the same upstream files as the second would not break a tie.
Converting the 1.7 GB change archive also costs hours. The multi-year comparison
covers all three; this does not.


|Item               |Value                                                             |
|:------------------|:-----------------------------------------------------------------|
|Snapshot extracted |2026-07-26                                                        |
|Counting windows   |main: 2026-07-27 to 2026-08-23; bankhol: 2026-08-10 to 2026-09-06 |
|TNDS               |gtfs/tnds_20260726_merged.zip                                     |
|BODS GTFS          |OpenBusData/GTFS/20260726/itm_all_gtfs.zip                        |

The window opens on the first Monday on or after the extraction date. The
DfT's GTFS carries no history — every calendar in it starts on the extraction
date — so a window opening earlier would silently understate that source.

## Journeys per operating day, published against each source

`Published` is the number of journeys the document prints for one operating
day at the reference stop. Where a document abbreviates a frequent-service
period the block is expanded before counting, and the row is flagged:

* **Expanded** — the count includes journeys recovered from an abbreviation
  such as "at these minutes past each hour until" or "and every 10 mins
  until". These are exact: the printed pattern determines the departures.
* **Upper bound** — the abbreviation was qualified, as in Lothian's "**up
  to** every 10 mins until". The true service is at most this frequent, so
  the expansion is a ceiling and a source counting fewer journeys is not
  necessarily wrong.
* **Reliable** — `FALSE` where any of three checks failed. **Rows marked
  unreliable must not be read as ground truth.** The checks all guard the
  same failure: not a reader that stops, but one that quietly returns a
  plausible subset of the day.
    * the document advertises a frequent-service period and nothing was
      expanded from it — the explicit times either side still parse, so the
      figure looks reasonable while most of the service is missing;
    * a lone two-digit cell appeared with nothing on the page to say whether
      it means a headway or a minute past the hour, readings that differ by
      a factor of several;
    * **Continuous** below is `FALSE`.
* **Continuous** — whether the departures read for a day have a plausible
  shape. A single gap that dwarfs the rest of the day's spacing means a
  block was missed, usually because its heading or stop label is written
  differently from the others. The Fife 34 reads as running 06:10–10:10 and
  then nothing until 18:31.

Where several routes share one printed table — Glasgow's "Service No.: 1 1C
1A 1C …", Fife's bare "91A 91A 90A …" — each column is attributed to its
route from the header row and only the routes being counted are kept.
Without that, another route's journeys are credited to this one, which is
what made the Manchester 142 unusable.


|Route  |Day type |Direction     | Published|Expanded |Upper bound |Continuous |Reliable |
|:------|:--------|:-------------|---------:|:--------|:-----------|:----------|:--------|
|279    |MT       |all           |       318|FALSE    |FALSE       |NA         |TRUE     |
|279    |Fr       |all           |       318|FALSE    |FALSE       |NA         |TRUE     |
|279    |Sa       |all           |       263|FALSE    |FALSE       |NA         |TRUE     |
|279    |Su       |all           |       218|FALSE    |FALSE       |NA         |TRUE     |
|69     |MT       |all           |       246|FALSE    |FALSE       |NA         |TRUE     |
|69     |Fr       |all           |       246|FALSE    |FALSE       |NA         |TRUE     |
|69     |Sa       |all           |       235|FALSE    |FALSE       |NA         |TRUE     |
|69     |Su       |all           |       202|FALSE    |FALSE       |NA         |TRUE     |
|A1     |MF       |back          |       129|FALSE    |FALSE       |TRUE       |TRUE     |
|A1     |Sa       |back          |       112|FALSE    |FALSE       |TRUE       |TRUE     |
|A1     |Su       |back          |       112|FALSE    |FALSE       |TRUE       |TRUE     |
|A1     |MF       |out           |       128|FALSE    |FALSE       |TRUE       |TRUE     |
|A1     |Sa       |out           |       110|FALSE    |FALSE       |TRUE       |TRUE     |
|A1     |Su       |out           |       110|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |MF       |back          |        63|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |Sa       |back          |        63|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |Su       |back          |        34|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |MF       |out           |        63|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |Sa       |out           |        63|FALSE    |FALSE       |TRUE       |TRUE     |
|21     |Su       |out           |        34|FALSE    |FALSE       |TRUE       |TRUE     |
|1_1A   |MF       |to_heysham    |        89|TRUE     |FALSE       |TRUE       |TRUE     |
|1_1A   |Sa       |to_heysham    |        91|TRUE     |FALSE       |TRUE       |TRUE     |
|1_1A   |Su       |to_heysham    |        47|TRUE     |FALSE       |TRUE       |TRUE     |
|1_1A   |MF       |to_university |        85|TRUE     |FALSE       |TRUE       |TRUE     |
|1_1A   |Sa       |to_university |        16|TRUE     |FALSE       |TRUE       |TRUE     |
|1_1A   |Su       |to_university |        40|TRUE     |FALSE       |TRUE       |TRUE     |
|111    |MF       |all           |       155|TRUE     |FALSE       |TRUE       |TRUE     |
|111    |Sa       |all           |       147|TRUE     |FALSE       |TRUE       |TRUE     |
|111    |Su       |all           |        71|TRUE     |FALSE       |TRUE       |TRUE     |
|143    |MF       |all           |       209|TRUE     |FALSE       |TRUE       |TRUE     |
|143    |Sa       |all           |       175|TRUE     |FALSE       |TRUE       |TRUE     |
|143    |Su       |all           |       124|FALSE    |FALSE       |TRUE       |TRUE     |
|G1     |MF       |all           |       198|FALSE    |FALSE       |TRUE       |TRUE     |
|G1     |Sa       |all           |       148|FALSE    |FALSE       |TRUE       |TRUE     |
|G1     |Su       |all           |        89|FALSE    |FALSE       |TRUE       |TRUE     |
|X85    |MF       |all           |        58|FALSE    |FALSE       |TRUE       |TRUE     |
|X85    |Sa       |all           |        54|FALSE    |FALSE       |TRUE       |TRUE     |
|X85    |Su       |all           |        32|FALSE    |FALSE       |TRUE       |TRUE     |
|F38    |MF       |all           |        59|TRUE     |FALSE       |TRUE       |TRUE     |
|F38    |Sa       |all           |        54|TRUE     |FALSE       |TRUE       |TRUE     |
|F38    |Su       |all           |        32|TRUE     |FALSE       |TRUE       |TRUE     |
|SF2A   |MF       |all           |        24|TRUE     |FALSE       |TRUE       |TRUE     |
|SF2A   |Sa       |all           |        22|TRUE     |FALSE       |TRUE       |TRUE     |
|SF34   |MF       |all           |        49|TRUE     |FALSE       |TRUE       |TRUE     |
|SF34   |Sa       |all           |        29|TRUE     |FALSE       |TRUE       |TRUE     |
|SF34   |Su       |all           |        16|TRUE     |FALSE       |TRUE       |TRUE     |
|SF90   |MF       |all           |        52|TRUE     |FALSE       |TRUE       |TRUE     |
|SF90   |Sa       |all           |        78|TRUE     |FALSE       |TRUE       |TRUE     |
|SF90   |Su       |all           |        28|TRUE     |FALSE       |TRUE       |TRUE     |
|SFX24  |MF       |all           |        32|TRUE     |FALSE       |TRUE       |TRUE     |
|SFX24  |Sa       |all           |        18|FALSE    |FALSE       |FALSE      |FALSE    |
|SFX24  |Su       |all           |        23|TRUE     |FALSE       |TRUE       |TRUE     |
|CDF1   |MF       |all           |        23|FALSE    |FALSE       |TRUE       |TRUE     |
|CDF24  |MF       |all           |        27|TRUE     |FALSE       |TRUE       |TRUE     |
|CDF24  |Sa       |all           |        25|TRUE     |FALSE       |TRUE       |TRUE     |
|CDF24  |Su       |all           |        11|FALSE    |FALSE       |TRUE       |TRUE     |
|CDF608 |MF       |all           |         2|FALSE    |FALSE       |TRUE       |TRUE     |
|CDF62  |MF       |all           |        82|TRUE     |FALSE       |TRUE       |TRUE     |
|CDF62  |Sa       |all           |        76|TRUE     |FALSE       |TRUE       |TRUE     |
|CDF62  |Su       |all           |         9|TRUE     |FALSE       |TRUE       |TRUE     |
|KB9    |MF       |all           |        54|TRUE     |FALSE       |TRUE       |TRUE     |
|KB9    |Sa       |all           |        50|TRUE     |FALSE       |TRUE       |TRUE     |
|KB9    |SuBh     |all           |        18|TRUE     |FALSE       |TRUE       |TRUE     |
|TBALL  |MF       |all           |       150|TRUE     |FALSE       |TRUE       |TRUE     |
|TBALL  |Sa       |all           |       107|TRUE     |FALSE       |TRUE       |TRUE     |
|TBALL  |SuBh     |all           |        78|TRUE     |FALSE       |TRUE       |TRUE     |
|BB727  |MF       |all           |       136|FALSE    |FALSE       |TRUE       |TRUE     |
|BB727  |Sa       |all           |       125|TRUE     |FALSE       |TRUE       |TRUE     |
|BB727  |Su       |all           |       103|TRUE     |FALSE       |TRUE       |TRUE     |
|BB59   |MF       |all           |       148|TRUE     |FALSE       |TRUE       |TRUE     |
|BB59   |Sa       |all           |        60|TRUE     |FALSE       |TRUE       |TRUE     |
|BB59   |Su       |all           |        53|TRUE     |FALSE       |TRUE       |TRUE     |
|OX400  |MF       |all           |       159|TRUE     |FALSE       |TRUE       |TRUE     |
|OX400  |Sa       |all           |       122|TRUE     |FALSE       |TRUE       |TRUE     |
|OX400  |Su       |all           |        68|TRUE     |FALSE       |TRUE       |TRUE     |
|SC125  |MF       |all           |       162|TRUE     |FALSE       |TRUE       |TRUE     |
|SC125  |Sa       |all           |       110|TRUE     |FALSE       |TRUE       |TRUE     |
|SC125  |Su       |all           |        52|FALSE    |FALSE       |TRUE       |TRUE     |
|AN320  |MF       |r320          |        97|FALSE    |FALSE       |TRUE       |TRUE     |
|AN320  |Sa       |r320          |        92|TRUE     |FALSE       |TRUE       |TRUE     |
|AN320  |Su       |r320          |        62|TRUE     |FALSE       |TRUE       |TRUE     |
|TBX38  |MF       |all           |        57|FALSE    |FALSE       |TRUE       |TRUE     |
|TBX38  |Sa       |all           |        52|FALSE    |FALSE       |TRUE       |TRUE     |
|TBX38  |SuBh     |all           |        18|FALSE    |FALSE       |TRUE       |TRUE     |
|SY57   |MF       |all           |       109|FALSE    |FALSE       |TRUE       |TRUE     |
|SY57   |Sa       |all           |        97|FALSE    |FALSE       |TRUE       |TRUE     |
|SY57   |Su       |all           |        44|FALSE    |FALSE       |TRUE       |TRUE     |
|L100   |MF       |from_airport  |        21|FALSE    |FALSE       |FALSE      |FALSE    |
|L100   |Sa       |from_airport  |        21|FALSE    |FALSE       |FALSE      |FALSE    |
|L100   |Su       |from_airport  |        21|FALSE    |FALSE       |FALSE      |FALSE    |
|L100   |MF       |to_airport    |        14|FALSE    |FALSE       |FALSE      |FALSE    |
|L100   |Sa       |to_airport    |        14|FALSE    |FALSE       |FALSE      |FALSE    |
|L100   |Su       |to_airport    |        14|FALSE    |FALSE       |FALSE      |FALSE    |
|L26    |MF       |to_clerwood   |        47|TRUE     |FALSE       |FALSE      |FALSE    |
|L26    |Sa       |to_clerwood   |        41|TRUE     |FALSE       |FALSE      |FALSE    |
|L26    |Su       |to_clerwood   |        50|TRUE     |FALSE       |FALSE      |FALSE    |
|L26    |MF       |to_seton      |        45|TRUE     |FALSE       |FALSE      |FALSE    |
|L26    |Sa       |to_seton      |        48|FALSE    |FALSE       |FALSE      |FALSE    |
|L26    |Su       |to_seton      |        45|TRUE     |FALSE       |FALSE      |FALSE    |
|NX6    |MF       |all           |       193|TRUE     |FALSE       |TRUE       |TRUE     |
|NX6    |Sa       |all           |       174|TRUE     |FALSE       |TRUE       |TRUE     |
|NX6    |Su       |all           |       114|FALSE    |FALSE       |TRUE       |TRUE     |
|NX50   |MF       |all           |       224|TRUE     |FALSE       |FALSE      |FALSE    |
|NX50   |Sa       |all           |       216|TRUE     |FALSE       |FALSE      |FALSE    |
|NX50   |Su       |all           |       180|TRUE     |FALSE       |TRUE       |TRUE     |
|BR43   |MF       |all           |       188|FALSE    |FALSE       |TRUE       |TRUE     |
|BR43   |Sa       |all           |       146|FALSE    |FALSE       |TRUE       |TRUE     |
|BR43   |Su       |all           |        90|FALSE    |FALSE       |TRUE       |TRUE     |
|BR24   |MF       |all           |       122|FALSE    |FALSE       |TRUE       |TRUE     |
|BR24   |Sa       |all           |        95|FALSE    |FALSE       |TRUE       |TRUE     |
|BR24   |Su       |all           |        57|FALSE    |FALSE       |TRUE       |TRUE     |



**Unreliable: SFX24, L100, L26, NX50 ** - a frequent-service abbreviation in these documents was not expanded, so the counts are far too low. See the notes below.

## Window totals

Journeys counted over the whole window, per source. These are directly
comparable with the `Published` figures above only after multiplying by the
number of each day type in the window; `Ratio` is TNDS ÷ BODS GTFS, which
needs no such conversion and is where the two sources can be seen to disagree.

A route is located by its public number, its operator, and the stop the
document counts. The stop is what makes the comparison like-for-like. A bus
number is unique only within a town and the operator patterns have to stay
loose, because the sources name the same operator differently - TNDS files the
St Helens 320 under "Arriva Merseyside" where the DfT's GTFS says "Arriva North
West". Number plus operator alone therefore collected eighteen `route_id`s for
the Fife 2A (Oxford, Gloucester, Sheffield, Skegness among them) and nine for
the Falkirk 38 across seven First subsidiaries. Both sources were inflated
equally, so they agreed with each other and diverged wildly from the document -
which reads as a shared converter problem rather than the measurement error it
was. `Stop matched` below is `FALSE` where the reference stop could not be
found in that feed and the count fell back to every same-numbered route of a
matching operator; those rows are the loose comparison and should be read with
that in mind.


|Route  |Window  | bods_gtfs| tnds|Ratio |
|:------|:-------|---------:|----:|:-----|
|111    |bankhol |      3816| 3747|0.98  |
|111    |main    |      3900| 3900|1.00  |
|142    |bankhol |      5224| 5982|1.15  |
|142    |main    |      5436| 6208|1.14  |
|143    |bankhol |      5207| 5083|0.98  |
|143    |main    |      5288| 5288|1.00  |
|1_1A   |bankhol |      4347| 4347|1.00  |
|1_1A   |main    |      4524| 4524|1.00  |
|21     |bankhol |      6330| 3170|0.50  |
|21     |main    |      5816| 3296|0.57  |
|279    |bankhol |     18510| 8184|0.44  |
|279    |main    |     18492| 8284|0.45  |
|69     |bankhol |      6619| 6619|1.00  |
|69     |main    |      6664| 6664|1.00  |
|A1     |bankhol |      9463| 6659|0.70  |
|A1     |main    |      7804| 6916|0.89  |
|AN320  |bankhol |      2768| 2706|0.98  |
|AN320  |main    |      2816| 2816|1.00  |
|BB59   |bankhol |      2640| 2744|1.04  |
|BB59   |main    |      2640| 2640|1.00  |
|BB727  |bankhol |      3645| 3788|1.04  |
|BB727  |main    |      3645| 3645|1.00  |
|BR24   |bankhol |      6129| 3037|0.50  |
|BR24   |main    |      5592| 3164|0.57  |
|BR43   |bankhol |      2374| 1874|0.79  |
|BR43   |main    |      1908| 1908|1.00  |
|CDF1   |bankhol |       508|  508|1.00  |
|CDF1   |main    |       508|  508|1.00  |
|CDF24  |bankhol |       675|  675|1.00  |
|CDF24  |main    |       664|  664|1.00  |
|CDF608 |bankhol |         0|    0|—     |
|CDF608 |main    |         0|    0|—     |
|CDF62  |bankhol |       524| 2044|3.90  |
|CDF62  |main    |       524| 2024|3.86  |
|F38    |bankhol |      3048| 3048|1.00  |
|F38    |main    |      3048| 3048|1.00  |
|G1     |bankhol |      1138| 1138|1.00  |
|G1     |main    |      3394| 3394|1.00  |
|KB9    |bankhol |      1316| 1316|1.00  |
|KB9    |main    |      1352| 1352|1.00  |
|L100   |bankhol |      8024| 8024|1.00  |
|L100   |main    |      8024| 8024|1.00  |
|L26    |bankhol |      5460| 5460|1.00  |
|L26    |main    |      5460| 5460|1.00  |
|NX50   |bankhol |     15350| 8429|0.55  |
|NX50   |main    |     15848| 8688|0.55  |
|NX6    |bankhol |     10753| 5284|0.49  |
|NX6    |main    |     11104| 5284|0.48  |
|OX400  |bankhol |      4424| 4424|1.00  |
|OX400  |main    |      4492| 4492|1.00  |
|SC125  |bankhol |      4303| 8547|1.99  |
|SC125  |main    |      4428| 8856|2.00  |
|SF2A   |bankhol |       572|  572|1.00  |
|SF2A   |main    |       572|  572|1.00  |
|SF34   |bankhol |      1488| 1488|1.00  |
|SF34   |main    |      1488| 1488|1.00  |
|SF90   |bankhol |      1048| 1048|1.00  |
|SF90   |main    |      1048| 1048|1.00  |
|SFX24  |bankhol |      1740| 1740|1.00  |
|SFX24  |main    |      1740| 1740|1.00  |
|SY57   |bankhol |      2679| 2679|1.00  |
|SY57   |main    |      2744| 2744|1.00  |
|TBALL  |bankhol |      2050| 2131|1.04  |
|TBALL  |main    |      2092| 2092|1.00  |
|TBX38  |bankhol |      2612| 5292|2.03  |
|TBX38  |main    |      2680| 5360|2.00  |
|X85    |bankhol |       672|  672|1.00  |
|X85    |main    |      2027| 2027|1.00  |

Both windows are now inside what the conversion keeps. `convert_tnds_snapshot()` trims to the snapshot date plus or minus 45 days, so the 2026-07-26 feed runs to **2026-09-09**, 3 days past the close of the `bankhol` window on 2026-09-06. An earlier 31-day trim stopped short of this window and made every TNDS count in it a fixed 17/28 of the first window's, which is no longer the case: the TNDS `bankhol` divided by `main` ratio has a median of 0.987 across 33 routes against 1.000 for BODS GTFS.

What is left is a genuine property of a snapshot rather than of the conversion: the second window reaches six weeks past the extraction date, so a registration that expires in between is carried by the DfT's future-dated files and not by TNDS. Read the second window as *service as registered on the snapshot date, projected six weeks forward*, and see the snapshot-expiry section of `bus_source_comparison.md` for its size.

`G1` and `X85` fall below half in *both* sources by the same factor, so those are a real change in the timetable rather than anything to do with the trim. Both are First Glasgow, and the drop falls where a Scottish summer timetable would end.

The second window exists for two bank-holiday references — the Cardiff 62's
"Sundays & public holidays" table and Kinchbus's "Sunday & Bank Holiday
Monday" table. With the trim widened past the end of that window, both are
testable against TNDS for the first time.

### Coverage the DfT feed has since gained


Table: Routes selected because BODS GTFS carried nothing for them

|Route |  TNDS| BODS GTFS|Ratio |Verdict     |
|:-----|-----:|---------:|:-----|:-----------|
|BB59  | 2,640|     2,640|1.00  |now carried |
|BB727 | 3,645|     3,645|1.00  |now carried |
|OX400 | 4,492|     4,492|1.00  |now carried |

**3 of these 3 routes are now in the DfT's GTFS, at exactly the TNDS level.** Each was collected because that feed carried nothing at all for it in February 2026, so this is a coverage gap that has closed rather than persisted. Two things follow: the February figures inside the notes must not be read as current, and a coverage difference measured on one snapshot cannot be assumed to hold on another — which is a caution that applies to the year-by-year comparison as much as to this report.

## Which source does the document agree with?

The two tables above compare the sources with each other and with a single
operating day. This one compares each source with the **document's own implied
window total**: each printed day type multiplied by how many days of that type
the window contains, summed. That is the measurement the rest of this report
exists to make, and it says which source is right rather than only that they
differ.

Only the first window, and only routes whose printed tables cover a whole week
(`MF`+`Sa`+`Su`, or `MT`+`Fr`+`Sa`+`Su`) — a route with no Sunday table cannot
be compared against a feed total that includes Sundays. `SuBh` is counted as
Sundays alone: the bank holiday it also covers falls in the second window.

**Read the Edition column first.** A ratio away from 1 says something about a
source only when the document describes the same service the snapshot holds.
Operators leave superseded timetables on their websites, and several of these
documents predate the snapshot by a year or more: where a stale document and
both sources disagree by the same factor, the network changed, and neither
source is at fault. The date is the printed validity statement from the first
page ("From 31 August 2025", "Valid from Monday 24th November 2025"), or failing
that an unambiguous `yyyymmdd` in the file name — a convention this set can
check rather than assume, since the two Cardiff documents named `-20260719-`
also print "19/07/2026" on the page. Blank means neither was found, or the
document is a Word extract rather than a PDF.


|Route |Edition     |Months old | Document implies|  TNDS|TNDS ÷ doc | BODS GTFS|BODS ÷ doc |Reliable |Stop matched |
|:-----|:-----------|:----------|----------------:|-----:|:----------|---------:|:----------|:--------|:------------|
|BR43  |31 Aug 2025 |11         |            4,704| 1,908|0.41       |     1,908|0.41       |TRUE     |TRUE         |
|TBALL |            |           |            3,740| 2,092|0.56       |     2,092|0.56       |TRUE     |FALSE        |
|G1    |28 Sep 2025 |10         |            4,908| 3,394|0.69       |     3,394|0.69       |TRUE     |FALSE        |
|SF90  |18 Aug 2025 |11         |            1,464| 1,048|0.72       |     1,048|0.72       |TRUE     |TRUE         |
|BB59  |25 May 2026 |2          |            3,412| 2,640|0.77       |     2,640|0.77       |TRUE     |TRUE         |
|CDF24 |19 Jul 2026 |0          |              684|   664|0.97       |       664|0.97       |TRUE     |TRUE         |
|111   |            |           |            3,972| 3,900|0.98       |     3,900|0.98       |TRUE     |TRUE         |
|143   |            |           |            5,376| 5,288|0.98       |     5,288|0.98       |TRUE     |TRUE         |
|69    |            |           |            6,668| 6,664|1.00       |     6,664|1.00       |TRUE     |FALSE        |
|21    |06 Apr 2026 |4          |            3,296| 3,296|1.00       |     5,816|1.76       |TRUE     |TRUE         |
|279   |            |           |            8,284| 8,284|1.00       |    18,492|2.23       |TRUE     |FALSE        |
|A1    |31 Aug 2025 |11         |            6,916| 6,916|1.00       |     7,804|1.13       |TRUE     |TRUE         |
|KB9   |            |           |            1,352| 1,352|1.00       |     1,352|1.00       |TRUE     |TRUE         |
|SY57  |            |           |            2,744| 2,744|1.00       |     2,744|1.00       |TRUE     |TRUE         |
|BB727 |25 May 2026 |2          |            3,632| 3,645|1.00       |     3,645|1.00       |TRUE     |FALSE        |
|CDF62 |12 Apr 2026 |3          |            1,980| 2,024|1.02       |       524|0.26       |TRUE     |TRUE         |
|BR24  |03 Sep 2023 |35         |            3,048| 3,164|1.04       |     5,592|1.83       |TRUE     |TRUE         |
|NX6   |19 Jul 2026 |0          |            5,012| 5,284|1.05       |    11,104|2.22       |TRUE     |TRUE         |
|1_1A  |            |           |            4,256| 4,524|1.06       |     4,524|1.06       |TRUE     |TRUE         |
|AN320 |19 Jul 2026 |0          |            2,556| 2,816|1.10       |     2,816|1.10       |TRUE     |FALSE        |
|OX400 |22 Feb 2026 |5          |            3,940| 4,492|1.14       |     4,492|1.14       |TRUE     |TRUE         |
|SF34  |19 Aug 2024 |23         |            1,160| 1,488|1.28       |     1,488|1.28       |TRUE     |TRUE         |
|X85   |20 Apr 2025 |15         |            1,504| 2,027|1.35       |     2,027|1.35       |TRUE     |FALSE        |
|NX50  |19 Jul 2026 |0          |            6,064| 8,688|1.43       |    15,848|2.61       |FALSE    |FALSE        |
|F38   |15 Sep 2025 |10         |            1,524| 3,048|2.00       |     3,048|2.00       |TRUE     |TRUE         |
|L26   |            |           |            2,576| 5,460|2.12       |     5,460|2.12       |FALSE    |FALSE        |
|SFX24 |24 Nov 2025 |8          |              804| 1,740|2.16       |     1,740|2.16       |FALSE    |TRUE         |
|SC125 |            |           |            3,888| 8,856|2.28       |     4,428|1.14       |TRUE     |TRUE         |
|TBX38 |            |           |            1,420| 5,360|3.77       |     2,680|1.89       |TRUE     |FALSE        |
|L100  |            |           |              980| 8,024|8.19       |     8,024|8.19       |FALSE    |FALSE        |

Across the 26 routes with a whole week of readable tables, TNDS is within 10% of the document for **14** of them and the DfT's GTFS for **8**. Median ratio to the document: TNDS 1.00, BODS GTFS 1.03.

Routes where **TNDS** is more than 25% from the document: `TBX38` (3.77), `SC125` (2.28), `F38` (2.00), `BR43` (0.41), `TBALL` (0.56), `X85` (1.35), `G1` (0.69), `SF90` (0.72), `SF34` (1.28).

Routes where **BODS GTFS** is more than 25% from the document: `279` (2.23), `NX6` (2.22), `F38` (2.00), `TBX38` (1.89), `BR24` (1.83), `21` (1.76), `CDF62` (0.26), `BR43` (0.41), `TBALL` (0.56), `X85` (1.35), `G1` (0.69), `SF90` (0.72), `SF34` (1.28).

**Stale documents, not source problems:** `F38` (2.00), `BR43` (0.41), `X85` (1.35), `G1` (0.69), `SF90` (0.72), `SF34` (1.28). Both sources agree with *each other* to within 10% and diverge from the document by the same factor, and each of these documents predates the snapshot by more than six months (`BR43` 11 months, `G1` 10 months, `SF90` 11 months, `SF34` 23 months, `X85` 15 months, `F38` 10 months). The service changed after the timetable was printed; neither feed is at fault.

**Read these as document-reading problems:** `TBALL` (0.56). The two sources agree with each other and diverge from the document by the same factor, but the document is current (or states no edition), so what to doubt is the reading of it. A ratio near 2.00 in this group is the signature of a table that prints one direction where the feeds count both.

Cases the document settles:

* `21` — the document implies 3,296 journeys; TNDS 3,296 (1.00), BODS GTFS 5,816 (1.76). **TNDS is right** (edition 06 Apr 2026, 4 months before the window).
* `279` — the document implies 8,284 journeys; TNDS 8,284 (1.00), BODS GTFS 18,492 (2.23). **TNDS is right** (edition not stated).
* `CDF62` — the document implies 1,980 journeys; TNDS 2,024 (1.02), BODS GTFS 524 (0.26). **TNDS is right** (edition 12 Apr 2026, 3 months before the window).
* `BR24` — the document implies 3,048 journeys; TNDS 3,164 (1.04), BODS GTFS 5,592 (1.83). **TNDS is right** (edition 03 Sep 2023, 35 months before the window).
* `NX6` — the document implies 5,012 journeys; TNDS 5,284 (1.05), BODS GTFS 11,104 (2.22). **TNDS is right** (edition 19 Jul 2026, 0 months before the window).

A ratio near 1.00 is strong evidence and a ratio far from it is a lead, not a
verdict: the document may print a different edition from the one the snapshot
carries, and `Reliable = FALSE` rows are excluded from the prose above precisely
because their published figure cannot be trusted. `Stop matched = FALSE` means
the reference stop was not found in one of the feeds, so the count is of every
same-numbered route of a matching operator and will be too high.

### The Bristol 21: what the DfT feed's excess actually is

The clearest of these cases is worth following to its cause, because both
sources match the reference stop, so nothing about the measurement is loose.

*The figures in this subsection were measured directly on the DfT feed named in
the table at the top of this report, over the first window, on 2026-07-30. They
are quoted rather than computed here because this report is built from the
route-level validation data and not from the feed itself; `lsoa_disagreement.md`
computes the national duplication figure as part of its own pipeline, so that is
the copy that stays current.*

First Bristol's 21 is `route_id` 3700 in the DfT's GTFS. Over the first window
that route_id carries **5,816 trip-days**. Reducing every trip to the set of
(stop, departure time) pairs it makes, and counting distinct (journey, date)
pairs rather than trips, leaves **3,296** — the other 2,520 are the same bus
described twice on the same day. The document implies 3,296 and TNDS counts
3,296.

So the whole of the 1.76× excess is duplicate publication, and removing it
reproduces the published timetable exactly. The same pattern, with the same
numbers, appears on `route_id` 5320 (service 31), which suggests one duplicated
dataset rather than a per-route accident.

Duplication is not confined to those. Measured across the whole 2026-07-26 DfT
feed over this window, **380,264 of 10,301,615 counted bus runs (3.69%)** are the
same journey on the same day — 74,965 of them published under two different
`route_id`s and 305,299 under one. It is concentrated rather than spread:
several `route_id`s are duplicated in their entirety.

A caution about how that is measured, because the obvious version of the test is
wrong. Comparing trips by their (stop, time) signature alone, without regard to
date, returns 41.5% of runs — more than ten times the real figure. GTFS models a
school-term journey and its holiday twin as two trips with identical times and
*complementary* calendars, which is correct modelling and not duplication. Only
trips that run the same journey on the same **date** are counted here.

The `279` row is not resolved by this. Its two Arriva London `route_id`s contain
no same-day duplicates at all, and one of them (10984339, 8,284 runs) matches the
document and TNDS exactly while the other adds 10,208 more. Since the reference
stop is not found for that route in either feed, its counts include every
same-numbered Arriva route, so the row cannot be pushed further here.


Table: Stop matched: was the reference stop found?

|Route  |bods_gtfs |tnds  |
|:------|:---------|:-----|
|111    |TRUE      |TRUE  |
|142    |TRUE      |TRUE  |
|143    |TRUE      |TRUE  |
|1_1A   |TRUE      |TRUE  |
|21     |TRUE      |TRUE  |
|279    |FALSE     |FALSE |
|69     |FALSE     |FALSE |
|A1     |TRUE      |TRUE  |
|AN320  |FALSE     |FALSE |
|BB59   |TRUE      |TRUE  |
|BB727  |FALSE     |FALSE |
|BR24   |TRUE      |TRUE  |
|BR43   |TRUE      |TRUE  |
|CDF1   |TRUE      |TRUE  |
|CDF24  |TRUE      |TRUE  |
|CDF608 |FALSE     |FALSE |
|CDF62  |TRUE      |TRUE  |
|F38    |TRUE      |TRUE  |
|G1     |FALSE     |FALSE |
|KB9    |TRUE      |TRUE  |
|L100   |FALSE     |TRUE  |
|L26    |FALSE     |FALSE |
|NX50   |FALSE     |FALSE |
|NX6    |TRUE      |TRUE  |
|OX400  |TRUE      |TRUE  |
|SC125  |TRUE      |TRUE  |
|SF2A   |TRUE      |TRUE  |
|SF34   |TRUE      |TRUE  |
|SF90   |TRUE      |TRUE  |
|SFX24  |TRUE      |TRUE  |
|SY57   |TRUE      |TRUE  |
|TBALL  |FALSE     |FALSE |
|TBX38  |FALSE     |FALSE |
|X85    |FALSE     |FALSE |


Table: route_id(s) matched in each source

|Route  |bods_gtfs               |tnds                        |
|:------|:-----------------------|:---------------------------|
|111    |9130                    |4227                        |
|142    |70659                   |4039+4445                   |
|143    |70660                   |4235                        |
|1_1A   |131260+86042            |4101+4313                   |
|21     |3700                    |12785                       |
|279    |10984339+10003          |2163                        |
|69     |10423702                |2495                        |
|A1     |32450                   |11671                       |
|AN320  |58864                   |4049+3931+3934              |
|BB59   |3718578                 |6586                        |
|BB727  |3718621                 |6146                        |
|BR24   |5364                    |11637                       |
|BR43   |101947                  |11641                       |
|CDF1   |6532264                 |13953                       |
|CDF24  |6532298                 |13985                       |
|CDF608 |                        |14484                       |
|CDF62  |6532448                 |13868+13984+14063           |
|F38    |1059786                 |6324                        |
|G1     |3841+6662               |6299+6326                   |
|KB9    |4560                    |711                         |
|L100   |1059145                 |6598                        |
|L26    |139008                  |6139+6140+6141              |
|NX50   |13213                   |14626+14679                 |
|NX6    |128640                  |14610                       |
|OX400  |98976                   |9235                        |
|SC125  |8154118                 |3825+3827                   |
|SF2A   |2580074                 |7118                        |
|SF34   |2580093+2580098         |6969+6990                   |
|SF90   |2580214+2580215+2580218 |7557+7621+7844              |
|SFX24  |2580353+2580355         |6533+6579                   |
|SY57   |1334797+133577+8703     |15957+16212+16309           |
|TBALL  |11864                   |788+789                     |
|TBX38  |36865                   |903+904+929+930+15093+15163 |
|X85    |11921457+11921459       |6458+6482                   |

Where a source lists several `route_id`s for one route they are summed: a
source that splits one service across several ids must still be compared as
one service. Several ids is in itself worth noting, since it is how duplicate
publication shows up.

Several ids is not *by itself* evidence of duplication, though, and the four
routes where TNDS reads well above BODS GTFS divide cleanly on that point. For
each of them every trip was reduced to the sorted set of its (stop, departure
time) pairs, and those signatures compared across the route's TNDS `route_id`s
(measured on `tnds_20260726_merged.zip`):

| Route | TNDS ÷ GTFS | TNDS `route_id`s | Trip patterns shared between ids | Reading |
|:------|------------:|-----------------:|:---------------------------------|:--------|
| TBALL | 2.00 | 2 | **148 of 148** | the same timetable published twice |
| TBX38 | 3.00 | 6 | **363 of 688**, as three identical pairs | three registrations, each published twice |
| SC125 | 2.00 | 2 | **0 of 731** | not duplication |
| CDF62 | 3.86 | 3 | **0 of 147** | not duplication |

For TBALL and TBX38 the TNDS excess is therefore an artefact of duplicate
registration: the exact ratios of 2.00 and 3.00 follow directly from publishing
one timetable twice and one three times over, so **TNDS is overcounting them**.

That is as far as the trip-pattern evidence goes, and it is worth being precise
about what it does *not* establish. Compared with the documents in the section
below, TBALL's doubled TNDS figure lands nearer the document (1.12) than BODS
GTFS does (0.56), and TBX38 exceeds it in both sources. Two things make that row
unsafe to adjudicate rather than a contradiction: the reference stop is not found
in either feed for these routes, so both counts are of every same-numbered route
of a matching operator, and both documents are Word extracts whose readers are
the least trustworthy in the set (TBALL's Monday–Friday column includes
Fridays-only journeys, so its implied total is itself an overestimate). The
duplication in TNDS is established; that BODS GTFS is therefore *correct* for
these two is not.

For SC125 and CDF62 the `route_id`s carry genuinely distinct trips, so their
excess is a real disagreement that duplicate publication does not explain. The
documents settle CDF62 outright — TNDS reads 1.02 of the Cardiff 62's published
timetable and BODS GTFS 0.26, so the missing service is in BODS GTFS, which is
what England-only statutory coverage predicts for a Cardiff Bus service. SC125's
ratio of exactly 2.00 with disjoint patterns is not settled: TNDS reads 2.28 of
the document against BODS GTFS's 1.14, so on that evidence TNDS is the
overcounting one, but the mechanism — two sources modelling directions
differently is the obvious candidate — would need a direction-level breakdown to
confirm and is not established here.

## Notes on each document

Figures quoted *inside* these notes are **selection rationale**, not
measurements: they come from the February 2026 comparison window that these
documents were picked from. That window has since been dropped from the
comparison (its TNDS side is distorted by registrations expiring inside it), and
in any case it is not the window counted here. Where a note disagrees with the
Window totals table above, **the table is the measurement** — the Wigan `AN320`
is noted as TNDS reading 1.96× BODS GTFS, but on this July snapshot the two
sources agree exactly.


|Route  |Operator                                         |Skipped |Note                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:------|:------------------------------------------------|:-------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|279    |Arriva London                                    |FALSE   |TfL running schedule; every journey listed                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|69     |Blue Triangle&#124;Go.?Ahead London              |FALSE   |day and night schedules combine to one operating day; these are the May 2026 contract schedules, so they match the current snapshot this is counted against                                                                                                                                                                                                                                                                                                                                    |
|A1     |First Bristol                                    |FALSE   |National PTI; all times explicit; Sunday table printed twice                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|21     |First Bristol                                    |FALSE   |valid from 06/04/2026, so current for this snapshot                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|1_1A   |Stagecoach.*(North West&#124;Cumbria)            |FALSE   |frequent periods abbreviated as minutes past each hour and expanded; carries university term-time and holiday-only journeys, so it exercises the ServicedOrganisation handling directly                                                                                                                                                                                                                                                                                                        |
|111    |Bee Network&#124;Metroline                       |FALSE   |summer edition covering the window; the frequent period is abbreviated in-column and this page mixes a 12-minute and a 15-minute block                                                                                                                                                                                                                                                                                                                                                         |
|143    |Bee Network&#124;Metroline                       |FALSE   |summer edition covering the window; 10-minute headway block                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|G1     |First Glasgow&#124;Greater Glasgow               |FALSE   |both directions are printed without any direction heading - the stop order simply reverses partway - so this counts departures at one stop across both                                                                                                                                                                                                                                                                                                                                         |
|X85    |First Glasgow&#124;Greater Glasgow               |FALSE   |two routes in one table, both counted                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
|F38    |First&#124;Midland Bluebird                      |FALSE   |Falkirk-Stirling; the 'then every 15 mins until' legend is stacked one word per stop row inside the table, which is why it needs positional reading                                                                                                                                                                                                                                                                                                                                            |
|SF2A   |Stagecoach                                       |FALSE   |Dunfermline circular; minutes-past-the-hour abbreviation                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|SF34   |Stagecoach                                       |FALSE   |Kirkcaldy circular; three routes in one table                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|SF90   |Stagecoach                                       |FALSE   |St Andrews circular; three routes in one table                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|SFX24  |Stagecoach                                       |FALSE   |Fife-Glasgow limited stop; tests longer-distance services. Saturday is still flagged unreliable: the abbreviated block closes on the following page, so the run of minute cells that ends the row has nothing to bound it and is not expanded                                                                                                                                                                                                                                                  |
|CDF1   |Cardiff Bus&#124;Bws Caerdydd                    |FALSE   |city circle, commencing 19/07/2026 so current for the window                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|CDF24  |Cardiff Bus&#124;Bws Caerdydd                    |FALSE   |commencing 19/07/2026; minutes-past-the-hour abbreviation                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|CDF608 |Cardiff Bus&#124;Bws Caerdydd                    |FALSE   |schooldays-only school service, one journey each way, and it reads zero in both sources. That is the right answer, not a gap: the counting window is inside the summer holidays. The other reading - that the service has been withdrawn since the 2023 edition of this document - is ruled out, since bustimes.org still lists Cardiff Bus's 608 James Street to Fitzalan School as running (checked 2026-07-30). Keep it as the control for a school service correctly absent                |
|CDF62  |Cardiff Bus&#124;Bws Caerdydd                    |FALSE   |valid from 12/04/2026; three routes in one table. Counted at Llandaff Fields because it is the only stop named identically in both directions - the inbound tables call the outbound's Black Lion stop something else. Carries a 'Sundays & public holidays' table, so it also covers the 31 August holiday                                                                                                                                                                                    |
|KB9    |Kinchbus&#124;trentbarton                        |FALSE   |Loughborough-Nottingham. One Monday-to-Saturday table carries both day types, marked per journey: NS runs Monday to Friday only, S on Saturdays only, unmarked on both, so it is read once per day type. Also publishes a separate Sunday & Bank Holiday Monday table - the only bank holiday reference in the set                                                                                                                                                                             |
|TBALL  |trentbarton&#124;Kinchbus&#124;Wellglade         |FALSE   |trentbarton Derby-Allestree, from a Word extract: the six PDFs of this timetable have no text layer at all. The document names no route number - its 'Bus No' column is blank - so it is matched on the line names the feeds use ('all' in TNDS, 'TA' in the GTFS) as well as on the long name. Monday-Friday includes journeys marked 'F - Fridays only', so that figure is the Friday service level and slightly overstates Monday to Thursday. Carries a Sunday & Bank Holiday Monday table |
|BB727  |Stagecoach Bluebird                              |FALSE   |Aberdeen Airport - Stonehaven. Selected because TNDS carried it and BODS GTFS did not (4,439 journeys against 0), so this tests whether that coverage is real. Counted at P&J Live Arena, which appears in both directions' tables; every time is explicit                                                                                                                                                                                                                                     |
|BB59   |Stagecoach Bluebird                              |FALSE   |Northfield - Balnagask, selected as also TNDS-only (4,156 against 0). Aberdeen Royal Infirmary is mid-route and appears in both directions                                                                                                                                                                                                                                                                                                                                                     |
|OX400  |Oxford Bus                                       |FALSE   |Thame - Oxford, selected as TNDS-only (4,460 against 0). This generator prints the row label to the *right* of the times, which is why the label is matched with the leading cells stripped                                                                                                                                                                                                                                                                                                    |
|SC125  |Stagecoach                                       |FALSE   |Preston - Bolton. Selected because TNDS read 1.83x BODS GTFS (9,322 against 5,091) with BODS TransXChange siding with GTFS, making TNDS the one to doubt                                                                                                                                                                                                                                                                                                                                       |
|AN320  |Arriva Merseyside&#124;Arriva North West         |FALSE   |St Helens - Wigan. Selected because TNDS read 1.96x BODS GTFS (6,228 against 3,176), which the route table traces to TNDS holding three route_ids against one. Routes 20 and 320 are printed on separate pages of one document; only the 320's pages are counted. Saturday prints its row labels to the right of the times                                                                                                                                                                     |
|TBX38  |trentbarton&#124;Trent Barton                    |FALSE   |Derby - Burton. Selected because TNDS read 1.98x BODS GTFS (8,144 against 4,116). From a Word extract, and the least trustworthy of this batch: reading it at Burton High Street returns 4 journeys for a Saturday against 113 for a weekday, so the reader is not handling all twelve of its tables. Derby, Victoria Street reads with a plausible shape; treat with caution and check Continuous before using it                                                                             |
|SY57   |Stagecoach Yorkshire                             |FALSE   |Barnsley - Royston. The first document here to print its times as '07:05' rather than '0705', which the reader could not see at all: with no token looking like a time, every data row was classified as a heading and nothing was read                                                                                                                                                                                                                                                        |
|142    |Bee Network&#124;Metroline                       |TRUE    |SUMMER timetable (19 Jul - 29 Aug 2026): covers this snapshot, but merges route 42 journeys into the same table, so the count is not attributable to route 142                                                                                                                                                                                                                                                                                                                                 |
|L100   |Lothian                                          |FALSE   |NOT USABLE YET. The frequent-service period is a separate mini-table whose closing time sits on a different baseline from its opening time, so the block is not detected and the count omits it entirely. Also note the legend reads 'up to every 10 mins', which is a ceiling rather than a timetable. Needs a reader that assigns cells in two dimensions instead of by text row.                                                                                                            |
|L26    |Lothian                                          |FALSE   |NOT USABLE YET, same reason as the 100. Saturday also runs over two pages as 'Saturdays continued'.                                                                                                                                                                                                                                                                                                                                                                                            |
|NX6    |National Express&#124;NX ?Bus&#124;West Midlands |FALSE   |Solihull - Birmingham, edition from 19 July 2026. Frequent-period block expanded. Counted at Birmingham Moor Street Queensway, the city end of the route                                                                                                                                                                                                                                                                                                                                       |
|NX50   |National Express&#124;NX ?Bus&#124;West Midlands |FALSE   |Druids Heath - Birmingham, edition from 19 July 2026. Frequent-period block expanded                                                                                                                                                                                                                                                                                                                                                                                                           |
|BR43   |First                                            |FALSE   |Imperial Park - Cadbury Heath via Bristol city centre. Every time explicit, nothing to expand. Counted at The Centre, which is inside the zones where BODS GTFS most exceeds TNDS                                                                                                                                                                                                                                                                                                              |
|BR24   |First                                            |FALSE   |Southmead Hospital - Ashton Gate via the city centre. Every time explicit                                                                                                                                                                                                                                                                                                                                                                                                                      |
