

# Validating the sources against published timetables

The multi-year comparison in `bus_source_comparison.md` can say that TNDS,
BODS TransXChange and BODS GTFS disagree; only an operator's own published
timetable says which of them is right. This checks individual routes against
the documents in `data/example_timetables/`.

Published timetables are easy to obtain for the current week and hard to
obtain for the past, so this uses a **current snapshot** rather than one of
the historic comparison snapshots.

Two sources, not three. BODS TransXChange is excluded here: the multi-year
comparison already establishes that a fraction of the operator-published
files fail to convert, so it carries a coverage gap the other two do not, and
checking it against the PDFs would re-measure that gap rather than say
anything new about TNDS or the DfT's GTFS.


|Item               |Value                                                             |
|:------------------|:-----------------------------------------------------------------|
|Snapshot extracted |2026-07-26                                                        |
|Counting windows   |main: 2026-07-27 to 2026-08-23; bankhol: 2026-08-10 to 2026-09-06 |
|TNDS               |gtfs/tnds_20260726_merged.zip                                     |
|BODS GTFS          |OpenBusData/GTFS/20260726/itm_all_gtfs.zip                        |

The window opens on the first Monday on or after the extraction date. The
DfT's GTFS carries no history — every calendar in it starts on the extraction
date — so a window opening earlier would silently understate that source, as
it did in the February 2026 comparison.

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



**Unreliable: SFX24, L100, L26 ** - a frequent-service abbreviation in these documents was not expanded, so the counts are far too low. See the notes below.

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
|111    |bankhol |      3816| 2409|0.63  |
|111    |main    |      3900| 3900|1.00  |
|142    |bankhol |      5224| 3782|0.72  |
|142    |main    |      5436| 6208|1.14  |
|143    |bankhol |      5207| 3259|0.63  |
|143    |main    |      5288| 5288|1.00  |
|1_1A   |bankhol |      4347| 2793|0.64  |
|1_1A   |main    |      4524| 4524|1.00  |
|21     |bankhol |      6330| 2026|0.32  |
|21     |main    |      5816| 3296|0.57  |
|279    |bankhol |     18510| 5096|0.28  |
|279    |main    |     18492| 8284|0.45  |
|69     |bankhol |      6619| 4072|0.62  |
|69     |main    |      6664| 6668|1.00  |
|A1     |bankhol |      9463| 4229|0.45  |
|A1     |main    |      7804| 6916|0.89  |
|AN320  |bankhol |      2768| 1738|0.63  |
|AN320  |main    |      2816| 2816|1.00  |
|BB59   |bankhol |      2640| 1684|0.64  |
|BB59   |main    |      2640| 2640|1.00  |
|BB727  |bankhol |      3649| 2325|0.64  |
|BB727  |main    |      3649| 3649|1.00  |
|CDF1   |bankhol |       508|  323|0.64  |
|CDF1   |main    |       508|  508|1.00  |
|CDF24  |bankhol |       675|  410|0.61  |
|CDF24  |main    |       664|  664|1.00  |
|CDF608 |bankhol |         0|    0|—     |
|CDF608 |main    |         0|    0|—     |
|CDF62  |bankhol |       524| 1258|2.40  |
|CDF62  |main    |       524| 2024|3.86  |
|F38    |bankhol |      3048| 1878|0.62  |
|F38    |main    |      3048| 3048|1.00  |
|G1     |bankhol |      1138| 1138|1.00  |
|G1     |main    |      3394| 3394|1.00  |
|KB9    |bankhol |      1316|  838|0.64  |
|KB9    |main    |      1352| 1352|1.00  |
|L100   |bankhol |      8024| 4876|0.61  |
|L100   |main    |      8024| 8024|1.00  |
|L26    |bankhol |      5460| 3345|0.61  |
|L26    |main    |      5460| 5460|1.00  |
|OX400  |bankhol |      4424| 2762|0.62  |
|OX400  |main    |      4492| 4492|1.00  |
|SC125  |bankhol |      4303| 5532|1.29  |
|SC125  |main    |      4428| 8856|2.00  |
|SF2A   |bankhol |       956|  644|0.67  |
|SF2A   |main    |       956| 1000|1.05  |
|SF34   |bankhol |      2400| 1656|0.69  |
|SF34   |main    |      2400| 2628|1.09  |
|SF90   |bankhol |      1688| 1084|0.64  |
|SF90   |main    |      1688| 1688|1.00  |
|SFX24  |bankhol |      2764| 1766|0.64  |
|SFX24  |main    |      2764| 2764|1.00  |
|SY57   |bankhol |      2679| 1699|0.63  |
|SY57   |main    |      2744| 2744|1.00  |
|TBALL  |bankhol |      2050| 2578|1.26  |
|TBALL  |main    |      2092| 4184|2.00  |
|TBX38  |bankhol |      2612| 4956|1.90  |
|TBX38  |main    |      2680| 8040|3.00  |
|X85    |bankhol |       672|  672|1.00  |
|X85    |main    |      2027| 2027|1.00  |

The two windows are **not** comparable for TNDS, and the table shows why. A TNDS snapshot is trimmed to the snapshot date plus or minus 31 days by `convert_tnds_snapshot()`, so the 2026-07-26 feed ends on **2026-08-26** - 11 days before the `bankhol` window closes on 2026-09-06. Those 11 days are empty in TNDS by construction, which predicts a second-window count of 17/28 = **0.607** of a full one. Measured: the TNDS `bankhol` divided by `main` ratio has a median of 0.617 and sits between 0.608 and 0.644 for 27 of the 29 routes, against a median of 1.000 for BODS GTFS. The apparent collapse of TNDS in the second window is therefore an artefact of the conversion trim, not a property of the source, and **the `bankhol` TNDS column must not be read as a service level**.

The exceptions are informative. `G1` and `X85` fall below half in *both* sources by the same factor, so those are a real change in the timetable rather than the artefact. Both are First Glasgow, and the drop falls where a Scottish summer timetable would end.

The bank-holiday references the second window was built for — the Cardiff 62's
"Sundays & public holidays" table and Kinchbus's "Sunday & Bank Holiday
Monday" table — therefore cannot be tested against TNDS until the conversion
trim is widened past the end of that window.


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
|CDF1   |TRUE      |TRUE  |
|CDF24  |TRUE      |TRUE  |
|CDF608 |FALSE     |FALSE |
|CDF62  |TRUE      |TRUE  |
|F38    |TRUE      |TRUE  |
|G1     |FALSE     |FALSE |
|KB9    |TRUE      |TRUE  |
|L100   |FALSE     |TRUE  |
|L26    |FALSE     |FALSE |
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
|CDF1   |6532264                 |13953                       |
|CDF24  |6532298                 |13985                       |
|CDF608 |                        |14484                       |
|CDF62  |6532448                 |13868+13984+14063           |
|F38    |1059786                 |6324                        |
|G1     |3841+6662               |6299+6326                   |
|KB9    |4560                    |711                         |
|L100   |1059145                 |6598                        |
|L26    |139008                  |6139+6140+6141              |
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
registration, and the exact ratios of 2.00 and 3.00 follow directly from it —
TNDS is wrong and BODS GTFS is right. For SC125 and CDF62 the `route_id`s
carry genuinely distinct trips, so their excess is a real disagreement that
duplicate publication does not explain; SC125's ratio of exactly 2.00 with
disjoint patterns points instead at the two sources modelling directions
differently, which would need a direction-level breakdown to confirm and is
not established here.

## Notes on each document

Figures quoted *inside* these notes come from the February 2026 comparison that
motivated each document's selection, not from this snapshot — the BB727 note
says so explicitly, and the others share its origin. Where a note disagrees
with the Window totals table above, the table is the measurement: the Wigan
`AN320`, for instance, is noted as TNDS reading 1.96× BODS GTFS, but on this
July snapshot the two sources agree exactly.


|Route  |Operator                                 |Skipped |Note                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:------|:----------------------------------------|:-------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|279    |Arriva London                            |FALSE   |TfL running schedule; every journey listed                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|69     |Blue Triangle&#124;Go.?Ahead London      |FALSE   |day and night schedules combine to one operating day; these are the May 2026 contract schedules, so they match a current snapshot but not the February one                                                                                                                                                                                                                                                                                                                                     |
|A1     |First Bristol                            |FALSE   |National PTI; all times explicit; Sunday table printed twice                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|21     |First Bristol                            |FALSE   |valid from 06/04/2026, so current for this snapshot                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|1_1A   |Stagecoach.*(North West&#124;Cumbria)    |FALSE   |frequent periods abbreviated as minutes past each hour and expanded; carries university term-time and holiday-only journeys, so it exercises the ServicedOrganisation handling directly                                                                                                                                                                                                                                                                                                        |
|111    |Bee Network&#124;Metroline               |FALSE   |summer edition covering the window; the frequent period is abbreviated in-column and this page mixes a 12-minute and a 15-minute block                                                                                                                                                                                                                                                                                                                                                         |
|143    |Bee Network&#124;Metroline               |FALSE   |summer edition covering the window; 10-minute headway block                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|G1     |First Glasgow&#124;Greater Glasgow       |FALSE   |both directions are printed without any direction heading - the stop order simply reverses partway - so this counts departures at one stop across both                                                                                                                                                                                                                                                                                                                                         |
|X85    |First Glasgow&#124;Greater Glasgow       |FALSE   |two routes in one table, both counted                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
|F38    |First&#124;Midland Bluebird              |FALSE   |Falkirk-Stirling; the 'then every 15 mins until' legend is stacked one word per stop row inside the table, which is why it needs positional reading                                                                                                                                                                                                                                                                                                                                            |
|SF2A   |Stagecoach                               |FALSE   |Dunfermline circular; minutes-past-the-hour abbreviation                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|SF34   |Stagecoach                               |FALSE   |Kirkcaldy circular; three routes in one table                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|SF90   |Stagecoach                               |FALSE   |St Andrews circular; three routes in one table                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|SFX24  |Stagecoach                               |FALSE   |Fife-Glasgow limited stop; tests longer-distance services. Saturday is still flagged unreliable: the abbreviated block closes on the following page, so the run of minute cells that ends the row has nothing to bound it and is not expanded                                                                                                                                                                                                                                                  |
|CDF1   |Cardiff Bus&#124;Bws Caerdydd            |FALSE   |city circle, commencing 19/07/2026 so current for the window                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|CDF24  |Cardiff Bus&#124;Bws Caerdydd            |FALSE   |commencing 19/07/2026; minutes-past-the-hour abbreviation                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|CDF608 |Cardiff Bus&#124;Bws Caerdydd            |FALSE   |schooldays-only school service, one journey each way. The edition is from 2023, so a zero in the feeds may mean the service has gone rather than that the conversion lost it - and in a school-holiday window it should correctly not run at all                                                                                                                                                                                                                                               |
|CDF62  |Cardiff Bus&#124;Bws Caerdydd            |FALSE   |valid from 12/04/2026; three routes in one table. Counted at Llandaff Fields because it is the only stop named identically in both directions - the inbound tables call the outbound's Black Lion stop something else. Carries a 'Sundays & public holidays' table, so it also covers the 31 August holiday                                                                                                                                                                                    |
|KB9    |Kinchbus&#124;trentbarton                |FALSE   |Loughborough-Nottingham. One Monday-to-Saturday table carries both day types, marked per journey: NS runs Monday to Friday only, S on Saturdays only, unmarked on both, so it is read once per day type. Also publishes a separate Sunday & Bank Holiday Monday table - the only bank holiday reference in the set                                                                                                                                                                             |
|TBALL  |trentbarton&#124;Kinchbus&#124;Wellglade |FALSE   |trentbarton Derby-Allestree, from a Word extract: the six PDFs of this timetable have no text layer at all. The document names no route number - its 'Bus No' column is blank - so it is matched on the line names the feeds use ('all' in TNDS, 'TA' in the GTFS) as well as on the long name. Monday-Friday includes journeys marked 'F - Fridays only', so that figure is the Friday service level and slightly overstates Monday to Thursday. Carries a Sunday & Bank Holiday Monday table |
|BB727  |Stagecoach Bluebird                      |FALSE   |Aberdeen Airport - Stonehaven. TNDS carries this and BODS GTFS does not (4,439 journeys against 0 in the February window), so this tests whether that coverage is real. Counted at P&J Live Arena, which appears in both directions' tables; every time is explicit                                                                                                                                                                                                                            |
|BB59   |Stagecoach Bluebird                      |FALSE   |Northfield - Balnagask, also TNDS-only (4,156 against 0). Aberdeen Royal Infirmary is mid-route and appears in both directions                                                                                                                                                                                                                                                                                                                                                                 |
|OX400  |Oxford Bus                               |FALSE   |Thame - Oxford, TNDS-only (4,460 against 0). This generator prints the row label to the *right* of the times, which is why the label is matched with the leading cells stripped                                                                                                                                                                                                                                                                                                                |
|SC125  |Stagecoach                               |FALSE   |Preston - Bolton. TNDS reads 1.83x BODS GTFS (9,322 against 5,091) with BODS TransXChange siding with GTFS, so TNDS is the one to doubt                                                                                                                                                                                                                                                                                                                                                        |
|AN320  |Arriva Merseyside&#124;Arriva North West |FALSE   |St Helens - Wigan. TNDS reads 1.96x BODS GTFS (6,228 against 3,176). Routes 20 and 320 are printed on separate pages of one document; only the 320's pages are counted. Saturday prints its row labels to the right of the times                                                                                                                                                                                                                                                               |
|TBX38  |trentbarton&#124;Trent Barton            |FALSE   |Derby - Burton. TNDS reads 1.98x BODS GTFS (8,144 against 4,116). From a Word extract, and the least trustworthy of this batch: reading it at Burton High Street returns 4 journeys for a Saturday against 113 for a weekday, so the reader is not handling all twelve of its tables. Derby, Victoria Street reads with a plausible shape; treat with caution and check Continuous before using it                                                                                             |
|SY57   |Stagecoach Yorkshire                     |FALSE   |Barnsley - Royston. The first document here to print its times as '07:05' rather than '0705', which the reader could not see at all: with no token looking like a time, every data row was classified as a heading and nothing was read                                                                                                                                                                                                                                                        |
|142    |Bee Network&#124;Metroline               |TRUE    |SUMMER timetable (19 Jul - 29 Aug 2026): covers this snapshot, but merges route 42 journeys into the same table, so the count is not attributable to route 142                                                                                                                                                                                                                                                                                                                                 |
|L100   |Lothian                                  |FALSE   |NOT USABLE YET. The frequent-service period is a separate mini-table whose closing time sits on a different baseline from its opening time, so the block is not detected and the count omits it entirely. Also note the legend reads 'up to every 10 mins', which is a ceiling rather than a timetable. Needs a reader that assigns cells in two dimensions instead of by text row.                                                                                                            |
|L26    |Lothian                                  |FALSE   |NOT USABLE YET, same reason as the 100. Saturday also runs over two pages as 'Saturdays continued'.                                                                                                                                                                                                                                                                                                                                                                                            |
