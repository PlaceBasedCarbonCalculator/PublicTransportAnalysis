Route subset audit: which TransXChange files should be converted
================

- [1. Why a subset](#1-why-a-subset)
- [2. The seed: 12,565 route groups across three
  feeds](#2-the-seed-12565-route-groups-across-three-feeds)
- [3. The working subset](#3-the-working-subset)
- [4. Before and after, route by
  route](#4-before-and-after-route-by-route)
- [5. What the files showed, and the
  rules](#5-what-the-files-showed-and-the-rules)
- [6. How the DfT builds BODS GTFS (bods-integrated-data, commit
  b35a847f, 30 Oct
  2026)](#6-how-the-dft-builds-bods-gtfs-bods-integrated-data-commit-b35a847f-30-oct-2026)
- [7. What remains data-limited](#7-what-remains-data-limited)
- [8. The full run](#8-the-full-run)

Written 2026-11-16; full run 2026-11-18. Method:
`scripts/route_subset_audit/` (seed, extract, harness, readings,
comparison); plan in the session notes. Day: Tuesday 17 November 2026;
snapshot 11 November 2026 for both TransXChange sources; the DfT’s BODS
GTFS of the same date.

## 1. Why a subset

Seven rounds of fixes to `txc_filter_files()` were each measured by a
ten-hour rebuild of the November feeds, and the PDF and LSOA reports
moved only modestly per round. The national kept-file listing diff found
every regression; the reports did not. So the loop was changed: pick the
routes where the sources disagree, pull every TransXChange file of the
operators behind them (the filter compares files within an operator and
line, so a whole operator keeps its decisions unchanged), and run
filter, conversion and counting on that subset in under an hour per
build.

## 2. The seed: 12,565 route groups across three feeds

Routes were matched across TNDS, BODS TransXChange (both converted by
UK2GTFS with the round-6b filter) and the DfT’s BODS GTFS by operator
identity (NOC register) and line, with a stop-overlap fallback for
routes the feeds name differently. Each got a class from the two UK2GTFS
conversions first, then BODS GTFS:

| class | routes | trips_tnds | trips_bods_txc | trips_bods_gtfs |
|:---|---:|---:|---:|---:|
| agree | 7,269 | 192,411 | 192,317 | 192,585 |
| not in BODS TXC; BODS GTFS carries TNDS (L/S/W) | 2,153 | 102,400 | 0 | 102,397 |
| bods absent: no file in force | 1,197 | 45,922 | 0 | 2,273 |
| tnds absent: no file in force | 686 | 0 | 8,310 | 7,921 |
| agree; bods gtfs high (dft duplicates) | 574 | 21,116 | 21,154 | 90,669 |
| bods txc low: raw smaller | 164 | 5,578 | 2,550 | 2,548 |
| tnds low: filter candidate | 159 | 2,100 | 4,053 | 3,979 |
| tnds low: raw smaller | 146 | 4,450 | 8,737 | 9,531 |
| bods txc low: filter candidate | 119 | 4,919 | 1,604 | 4,692 |
| agree; bods gtfs low | 59 | 1,221 | 1,199 | 28 |
| bods txc low: raw smaller but BODS GTFS has it | 39 | 1,600 | 219 | 1,654 |

BODS GTFS is never the reference on its own: it carries TNDS for London,
Scotland and Wales and duplicates versions elsewhere (section 6).

## 3. The working subset

| operator | gap | candidate_routes | ease | bods_files | tnds_files | nocs |
|:---|---:|---:|---:|---:|---:|:---|
| Metrobus | 1892 | 41 | 3 | 414 | 114 | METR |
| Bee Network | 814 | 11 | 1 | 2167 | 909 | BNDB\|BNFM\|BNGN\|BNML\|BNSM\|BNVB |
| West Midlands Bus | 339 | 8 | 1 | 558 | 224 | OC:WMB\|TEX\|TEXP\|TNXB\|WMB\|WMBL |
| LONDON UNITED BUSWAYS LIMITED | 315 | 3 | 3 | 108 | 52 | CC\|LU\|LUTD |
| ARRIVA North East | 225 | 6 | 2 | 303 | 64 | ANEA\|ANUM |
| Stagecoach South Wales | 176 | 7 | 3 | 127 | 187 | ANSL\|HRRS\|NADT\|PRTH\|SSWL |
| Rotala Preston Bus | 167 | 3 | 2 | 87 | 34 | PBLT\|RSTY\|VISB |
| Dartline Coaches | 151 | 2 | 1 | 41 | 20 | DT\|DTCO |
| Arriva Kent and Surrey | 137 | 4 | 2 | 307 | 69 | AKSS |
| Redline | 109 | 6 | 1 | 42 | 22 | RLNE |
| Border Buses | 105 | 7 | 1 | 13 | 26 | BORD\|PERY\|WBWK |
| Hodgsons | 92 | 10 | 1 | 98 | 34 | HDGS |
| Gateshead Central taxis | 91 | 4 | 1 | 146 | 37 | GHCT |
| Banga Buses | 85 | 1 | 1 | 17 | 4 | BAN\|BANG |
| more Bus | 80 | 4 | 3 | 319 | 268 | BLUS\|SQ\|SVCT\|TDTR\|WD\|WDBC |
| Grant Palmer | 59 | 1 | 1 | 6 | 22 | GPLM |
| Stagecoach Cumbria and Lancashire | 57 | 3 | 3 | 148 | 264 | MNGN\|MNHT\|MNSC\|MNWB\|SCMY |
| Diamond Bus | 51 | 5 | 2 | 359 | 180 | DIA\|DIAM\|MDCL\|TEXP\|WNGS |
| First Berkshire | 50 | 1 | 3 | 15 | 10 | FTVA\|RRAR |
| Centrebus | 50 | 4 | 1 | 304 | 50 | CBBH\|CBNL |
| D & G Bus | 48 | 4 | 3 | 252 | 168 | DAGC\|DGC\|FPOT |
| Kempsford Transport | 38 | 3 | 1 | 10 | 4 | KEMT |
| Select Bus Services | 36 | 3 | 1 | 54 | 24 | SBS\|SLBS |
| First | 34 | 5 | 3 | 125 | 112 | FECS |
| Red Eagle | 31 | 4 | 1 | 91 | 56 | REDE |
| Diamond Bus (West Midlands) | 31 | 15 | 2 | 278 | 132 | DIAM\|WNGS |
| Stagecoach Midlands | 29 | 3 | 3 | 390 | 472 | SCNH |
| FALCON COACHES | 26 | 1 | 2 | 192 | 78 | EB\|FALC\|FB\|LU\|LUTD\|QULN |
| Brylaine Travel | 25 | 3 | 1 | 34 | 32 | BRYL |
| Salisbury Reds | 21 | 1 | 3 | 48 | 61 | SWWD |
| Chaserider | 6 | 1 | 1 | 66 | 27 | CRD\|CRDR |
| Swindons Bus Company | 3 | 2 | 1 | 89 | 58 | TDTR\|TT |
| Bluestar | 1 | 1 | 3 | 158 | 173 | BLUS\|SQ\|WD\|WDBC |

176 candidate routes and 2,042 control routes (same operators, sources
agree) from 34 operators; 10,585 TransXChange files (18 GB) from the two
November archives.

## 4. Before and after, route by route

Departures on Tuesday 17 November 2026 at each route’s reference stop
(its busiest stop), in the TNDS and BODS TransXChange conversions of
each build, against the printed timetable where one was read. `pdf_MF`
is the Monday-Friday count at that stop from the operator’s document in
force on the day (Stagecoach: whole-route journeys, their documents list
journeys as rows).

| operator | line | pdf_MF | r6b_ref_tnds | r6b_ref_bods | r7d_ref_tnds | r7d_ref_bods | r8b_ref_tnds | r8b_ref_bods | r8e_ref_tnds | r8e_ref_bods | r8j_ref_tnds | r8j_ref_bods | r8o_ref_tnds | r8o_ref_bods | ref_bods_gtfs | auto_verdict | seed_class |
|:---|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---|:---|
| ARRIVA North East | 13A | NA | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 39 |  | bods txc low: filter candidate |
| ARRIVA North East | 13B | NA | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 78 | 39 | 39 |  | bods txc low: filter candidate |
| ARRIVA North East | 4 | 40 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | tnds high; bods high | bods txc low: filter candidate |
| ARRIVA North East | X4 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | 49 | tnds ok; bods ok | tnds low: filter candidate |
| ARRIVA North East | X4A | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | tnds ok; bods ok | tnds low: filter candidate |
| ARRIVA North East | X93 | 56 | 32 | 56 | 32 | 56 | 32 | 56 | 32 | 56 | 32 | 56 | 32 | 56 | 56 | tnds low; bods ok | tnds low: filter candidate |
| Arriva Kent and Surrey | 101 | 152 | 0 | 71 | 0 | 152 | 0 | 152 | 0 | 152 | 0 | 152 | 0 | 152 | 152 | tnds low; bods ok | bods txc low: filter candidate |
| Arriva Kent and Surrey | 146 | 23 | 50 | 46 | 50 | 46 | 50 | 46 | 50 | 46 | 50 | 46 | 50 | 46 | 46 | tnds high; bods high | bods txc low: filter candidate |
| Arriva Kent and Surrey | 176 | 48 | 39 | 48 | 39 | 48 | 39 | 48 | 39 | 48 | 39 | 48 | 39 | 48 | 48 | tnds low; bods ok | tnds low: filter candidate |
| Arriva Kent and Surrey | 71 | 48 | 68 | 48 | 68 | 48 | 68 | 48 | 68 | 48 | 68 | 48 | 68 | 48 | 48 | tnds high; bods ok | bods txc low: filter candidate |
| Banga Buses | 530 | 70 | 70 | 155 | 70 | 68 | 70 | 68 | 70 | 68 | 70 | 68 | 70 | 68 | 143 | tnds ok; bods ok | tnds low: filter candidate |
| Bee Network | 101 | NA | 128 | 0 | 128 | 128 | 128 | 128 | 128 | 128 | 128 | 128 | 128 | 128 | 128 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 111 | NA | 77 | 0 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 | 77 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 143 | NA | 226 | 45 | 226 | 226 | 226 | 226 | 226 | 226 | 226 | 226 | 226 | 226 | 226 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 51 | NA | 7 | 0 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 |  | bods txc low: filter candidate |
| Bee Network | 789 | NA | 1 | 2 | 1 | 2 | 1 | 2 | 1 | 2 | 1 | 2 | 1 | 2 | 1 |  | tnds low: filter candidate |
| Bee Network | 817 | NA | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 1 |  | tnds low: filter candidate |
| Bee Network | 85 | NA | 61 | 0 | 61 | 61 | 61 | 61 | 61 | 61 | 61 | 61 | 61 | 61 | 61 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 85A | NA | 33 | 0 | 33 | 33 | 33 | 33 | 33 | 33 | 33 | 33 | 33 | 33 | 33 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 861 | NA | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 |  | bods txc low: filter candidate |
| Bee Network | 869 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | bods txc low: filter candidate |
| Bee Network | 869 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 |  | tnds low: filter candidate |
| Bee Network | 926 | NA | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 |  | bods txc low: raw smaller but BODS GTFS has it |
| Bee Network | 953 | NA | 1 | 3 | 1 | 3 | 1 | 3 | 1 | 3 | 1 | 3 | 1 | 3 | 2 |  | tnds low: filter candidate |
| Bee Network | 954 | NA | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 4 |  | tnds low: filter candidate |
| Bee Network | 954 | NA | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 | 4 | 2 |  | bods txc low: filter candidate |
| Bluestar | 425 | NA | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 2 |  | bods txc low: filter candidate |
| Border Buses | 235 | NA | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 |  | bods txc low: filter candidate |
| Border Buses | 253 | NA | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 | 0 | 16 |  | bods txc low: filter candidate |
| Border Buses | 267 | 14 | 12 | 20 | 12 | 20 | 12 | 20 | 12 | 20 | 12 | 20 | 12 | 20 | 10 | tnds ok; bods high | bods txc low: filter candidate |
| Border Buses | 32 | 13 | 7 | 0 | 7 | 0 | 7 | 0 | 7 | 0 | 7 | 0 | 7 | 0 | 7 | tnds low; bods low | bods txc low: filter candidate |
| Border Buses | 60 | 33 | 26 | 0 | 26 | 0 | 26 | 0 | 26 | 0 | 26 | 0 | 26 | 0 | 0 | tnds low; bods low | bods txc low: filter candidate |
| Border Buses | 67 | 36 | 31 | 0 | 31 | 0 | 31 | 0 | 31 | 0 | 31 | 0 | 31 | 0 | 31 | tnds ok; bods low | bods txc low: filter candidate |
| Brylaine Travel | B5 | NA | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 21 |  | tnds low: filter candidate |
| Brylaine Travel | B5A | NA | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |  | tnds low: filter candidate |
| Brylaine Travel | B5X | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | tnds low: filter candidate |
| Centrebus | 22E | NA | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 10 |  | bods txc low: filter candidate |
| Centrebus | 24 | NA | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 |  | tnds low: filter candidate |
| Centrebus | 81 | NA | 20 | 10 | 20 | 10 | 20 | 10 | 20 | 10 | 20 | 10 | 20 | 10 | 10 |  | bods txc low: filter candidate |
| Centrebus | HC2 | NA | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 |  | tnds low: filter candidate |
| Chaserider | 827 | NA | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 14 |  | tnds low: filter candidate |
| D & G Bus | 102 | NA | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 |  | tnds low: filter candidate |
| D & G Bus | 340 | NA | 11 | 20 | 11 | 20 | 11 | 20 | 11 | 20 | 11 | 20 | 11 | 20 | 20 |  | tnds low: filter candidate |
| D & G Bus | 93 | NA | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 | 19 |  | tnds low: filter candidate |
| Dartline Coaches | PR1 | NA | 117 | 234 | 117 | 234 | 117 | 117 | 117 | 117 | 117 | 117 | 117 | 117 | 234 |  | tnds low: filter candidate |
| Dartline Coaches | PR1A | NA | 34 | 68 | 34 | 68 | 34 | 34 | 34 | 34 | 34 | 34 | 34 | 34 | 51 |  | tnds low: filter candidate |
| Diamond Bus | 24 | NA | 5 | 8 | 5 | 8 | 5 | 8 | 5 | 8 | 5 | 8 | 5 | 8 | 8 |  | tnds low: filter candidate |
| Diamond Bus | 247 | 24 | 13 | 15 | 13 | 15 | 13 | 15 | 13 | 15 | 13 | 15 | 13 | 15 | 15 | tnds low; bods low | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 149S | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 202S | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 210 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 247A | NA | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 3 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 247S | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 292S | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 703 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 704 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 705 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 706 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 707 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 708 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | 709 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | S15 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Diamond Bus (West Midlands) | S77 | NA | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| FALCON COACHES | 467 | NA | 0 | 14 | 0 | 14 | 0 | 14 | 0 | 14 | 0 | 14 | 0 | 14 | 41 |  | tnds low: filter candidate |
| First | 116 | 8 | 8 | 18 | 8 | 18 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 13 | tnds ok; bods ok | tnds low: filter candidate |
| First | 64 | 26 | 26 | 52 | 26 | 52 | 26 | 26 | 26 | 26 | 26 | 26 | 26 | 26 | 33 | tnds ok; bods ok | tnds low: filter candidate |
| First | 70 | 18 | 18 | 37 | 18 | 37 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 22 | tnds ok; bods ok | tnds low: filter candidate |
| First | 73 | 15 | 15 | 32 | 15 | 32 | 15 | 15 | 15 | 15 | 15 | 15 | 15 | 15 | 20 | tnds ok; bods ok | tnds low: filter candidate |
| First | 88 | 37 | 37 | 76 | 37 | 76 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 46 | tnds ok; bods ok | tnds low: filter candidate |
| First Berkshire | 7 | 101 | 101 | 182 | 101 | 182 | 101 | 101 | 101 | 101 | 101 | 101 | 101 | 101 | 167 | tnds ok; bods ok | tnds low: filter candidate |
| Gateshead Central taxis | 19 | NA | 55 | 0 | 55 | 0 | 55 | 0 | 55 | 0 | 55 | 0 | 55 | 0 | 0 |  | bods txc low: filter candidate |
| Gateshead Central taxis | R3 | NA | 17 | 0 | 17 | 0 | 17 | 0 | 17 | 17 | 17 | 17 | 17 | 17 | 17 |  | bods txc low: filter candidate |
| Gateshead Central taxis | R4 | NA | 17 | 0 | 17 | 0 | 17 | 0 | 17 | 17 | 17 | 17 | 17 | 17 | 17 |  | bods txc low: filter candidate |
| Gateshead Central taxis | TB29 | NA | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 12 |  | tnds low: filter candidate |
| Grant Palmer | JO | NA | 61 | 2 | 61 | 2 | 61 | 2 | 61 | 2 | 61 | 2 | 61 | 2 | 2 |  | bods txc low: filter candidate |
| Hodgsons | 17 | NA | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 22 |  | tnds low: filter candidate |
| Hodgsons | 29 | NA | 10 | 16 | 10 | 16 | 10 | 14 | 10 | 14 | 10 | 14 | 10 | 14 | 12 |  | tnds low: filter candidate |
| Hodgsons | 60 | NA | 0 | 2 | 0 | 2 | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 1 |  | tnds low: filter candidate |
| Hodgsons | 60A | NA | 0 | 4 | 0 | 4 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 2 |  | tnds low: filter candidate |
| Hodgsons | 72 | NA | 12 | 15 | 12 | 15 | 12 | 15 | 12 | 15 | 12 | 15 | 12 | 15 | 12 |  | tnds low: filter candidate |
| Hodgsons | 79 | NA | 9 | 30 | 9 | 30 | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 19 |  | tnds low: filter candidate |
| Hodgsons | 81 | NA | 11 | 17 | 11 | 17 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 11 | 17 |  | tnds low: filter candidate |
| Hodgsons | 87 | NA | 26 | 6 | 26 | 6 | 26 | 6 | 26 | 29 | 26 | 29 | 26 | 29 | 29 |  | bods txc low: raw smaller but BODS GTFS has it |
| Hodgsons | 879 | NA | 2 | 6 | 2 | 3 | 2 | 3 | 2 | 6 | 2 | 3 | 2 | 3 | 6 |  | tnds low: filter candidate |
| Hodgsons | 89 | NA | 10 | 20 | 10 | 20 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 20 |  | tnds low: filter candidate |
| Kempsford Transport | 768 | NA | 10 | 20 | 10 | 20 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 |  | tnds low: filter candidate |
| Kempsford Transport | K2 | NA | 20 | 40 | 20 | 40 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 40 |  | tnds low: filter candidate |
| Kempsford Transport | X91 | NA | 8 | 16 | 8 | 16 | 8 | 16 | 8 | 16 | 8 | 16 | 8 | 8 | 8 |  | tnds low: filter candidate |
| LONDON UNITED BUSWAYS LIMITED | 117 | NA | 106 | 212 | 106 | 212 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 222 |  | tnds low: filter candidate |
| LONDON UNITED BUSWAYS LIMITED | 406 | NA | 52 | 0 | 52 | 52 | 52 | 52 | 52 | 52 | 52 | 52 | 52 | 52 | 154 |  | bods txc low: filter candidate |
| LONDON UNITED BUSWAYS LIMITED | 411 | NA | 119 | 225 | 119 | 225 | 119 | 119 | 119 | 119 | 119 | 119 | 119 | 119 | 225 |  | tnds low: filter candidate |
| Metrobus | 1 | NA | 82 | 0 | 82 | 82 | 82 | 82 | 82 | 82 | 82 | 82 | 82 | 82 | 82 |  | bods txc low: filter candidate |
| Metrobus | 10 | NA | 268 | 0 | 268 | 268 | 268 | 268 | 268 | 268 | 268 | 268 | 268 | 268 | 268 |  | bods txc low: filter candidate |
| Metrobus | 100 | NA | 141 | 0 | 141 | 141 | 141 | 141 | 141 | 141 | 141 | 141 | 141 | 141 | 141 |  | bods txc low: filter candidate |
| Metrobus | 2 | NA | 144 | 1 | 144 | 144 | 144 | 144 | 144 | 144 | 144 | 144 | 144 | 144 | 144 |  | bods txc low: filter candidate |
| Metrobus | 20 | NA | 118 | 0 | 118 | 118 | 118 | 118 | 118 | 118 | 118 | 118 | 118 | 118 | 118 |  | bods txc low: filter candidate |
| Metrobus | 200 | NA | 84 | 0 | 84 | 84 | 84 | 84 | 84 | 84 | 84 | 84 | 84 | 84 | 84 |  | bods txc low: filter candidate |
| Metrobus | 21 | NA | 13 | 0 | 13 | 0 | 13 | 0 | 13 | 13 | 13 | 13 | 13 | 13 | 13 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 22 | NA | 11 | 1 | 11 | 1 | 11 | 1 | 11 | 11 | 11 | 11 | 11 | 11 | 11 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 23 | NA | 56 | 3 | 56 | 0 | 56 | 0 | 56 | 56 | 56 | 56 | 56 | 56 | 56 |  | bods txc low: filter candidate |
| Metrobus | 231 | NA | 7 | 2 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 | 7 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 236 | NA | 7 | 1 | 7 | 1 | 7 | 1 | 7 | 7 | 7 | 7 | 7 | 7 | 7 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 23X | NA | 8 | 0 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 271 | NA | 20 | 2 | 20 | 0 | 20 | 0 | 20 | 20 | 20 | 20 | 20 | 20 | 20 |  | bods txc low: filter candidate |
| Metrobus | 273 | NA | 28 | 0 | 28 | 14 | 28 | 14 | 28 | 14 | 28 | 14 | 28 | 14 | 14 |  | bods txc low: filter candidate |
| Metrobus | 281 | NA | 22 | 4 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 | 22 |  | bods txc low: filter candidate |
| Metrobus | 291 | NA | 37 | 5 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 37 | 37 |  | bods txc low: filter candidate |
| Metrobus | 3 | NA | 106 | 1 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 106 | 106 |  | bods txc low: filter candidate |
| Metrobus | 318 | NA | 8 | 1 | 8 | 1 | 8 | 1 | 8 | 8 | 8 | 8 | 8 | 8 | 8 |  | bods txc low: filter candidate |
| Metrobus | 4 | NA | 64 | 0 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 400 | NA | 59 | 2 | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 59 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 409 | NA | 27 | 5 | 27 | 5 | 27 | 5 | 27 | 27 | 27 | 27 | 27 | 27 | 27 |  | bods txc low: filter candidate |
| Metrobus | 410 | NA | 50 | 4 | 50 | 4 | 50 | 4 | 50 | 50 | 50 | 50 | 50 | 50 | 50 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 411 | NA | 13 | 5 | 13 | 5 | 13 | 5 | 13 | 13 | 13 | 13 | 13 | 13 | 13 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 420 | NA | 21 | 0 | 21 | 0 | 21 | 0 | 21 | 21 | 21 | 21 | 21 | 21 | 21 |  | bods txc low: filter candidate |
| Metrobus | 424 | NA | 23 | 4 | 23 | 4 | 23 | 4 | 23 | 23 | 23 | 23 | 23 | 23 | 23 |  | bods txc low: filter candidate |
| Metrobus | 460 | NA | 45 | 3 | 45 | 0 | 45 | 0 | 45 | 45 | 45 | 45 | 45 | 45 | 45 |  | bods txc low: filter candidate |
| Metrobus | 480 | NA | 40 | 0 | 40 | 0 | 40 | 0 | 40 | 40 | 40 | 40 | 40 | 40 | 40 |  | bods txc low: filter candidate |
| Metrobus | 485 | NA | 4 | 0 | 4 | 0 | 4 | 0 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |  | bods txc low: filter candidate |
| Metrobus | 5 | NA | 64 | 0 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 500 | 18 | 18 | 0 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | tnds ok; bods ok | bods txc low: filter candidate |
| Metrobus | 51 | NA | 5 | 0 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 594 | NA | 11 | 1 | 11 | 1 | 11 | 1 | 11 | 11 | 11 | 11 | 11 | 11 | 11 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 595 | NA | 8 | 0 | 8 | 0 | 8 | 0 | 8 | 8 | 8 | 8 | 8 | 8 | 8 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 61 | NA | 13 | 0 | 13 | 13 | 13 | 13 | 13 | 13 | 13 | 13 | 13 | 13 | 13 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 65 | NA | 27 | 1 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 71 | NA | 16 | 0 | 16 | 16 | 16 | 16 | 16 | 16 | 16 | 16 | 16 | 16 | 16 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 820 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 84 | NA | 12 | 0 | 12 | 0 | 12 | 0 | 12 | 0 | 12 | 0 | 12 | 0 | 12 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | 93 | NA | 27 | 2 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 | 27 |  | bods txc low: filter candidate |
| Metrobus | 98 | NA | 91 | 11 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 |  | bods txc low: raw smaller but BODS GTFS has it |
| Metrobus | E10 | NA | 62 | 0 | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 62 |  | bods txc low: filter candidate |
| Red Eagle | 361 | 46 | 27 | 46 | 27 | 46 | 27 | 46 | 27 | 46 | 27 | 46 | 27 | 46 | 46 | tnds low; bods ok | tnds low: filter candidate |
| Red Eagle | 88 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 10 | 12 | 12 | tnds low; bods ok | tnds low: filter candidate |
| Red Eagle | 885 | 1 | 2 | 2 | 2 | 0 | 2 | 0 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | tnds high; bods high | tnds low: filter candidate |
| Red Eagle | W20 | 9 | 9 | 17 | 9 | 17 | 9 | 17 | 9 | 17 | 9 | 17 | 9 | 17 | 17 | tnds ok; bods high | tnds low: filter candidate |
| Redline | 12 | NA | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 3 | 0 | 0 |  | bods txc low: filter candidate |
| Redline | 130B | 127 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 0 | tnds low; bods low | bods txc low: filter candidate |
| Redline | 130D | 4 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 0 | tnds low; bods low | bods txc low: filter candidate |
| Redline | 130M | 127 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 0 | tnds low; bods low | bods txc low: filter candidate |
| Redline | 300M | 127 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 2 | 0 | 0 | tnds low; bods low | bods txc low: filter candidate |
| Redline | X20 | NA | 98 | 0 | 98 | 0 | 98 | 0 | 98 | 0 | 98 | 0 | 98 | 0 | 0 |  | bods txc low: filter candidate |
| Rotala Preston Bus | 31 | 20 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | tnds high; bods high | tnds low: filter candidate |
| Rotala Preston Bus | 35 | 164 | 84 | 164 | 84 | 164 | 84 | 164 | 84 | 164 | 84 | 164 | 84 | 164 | 164 | tnds low; bods ok | tnds low: filter candidate |
| Rotala Preston Bus | 8 | 73 | 61 | 120 | 61 | 120 | 61 | 120 | 61 | 120 | 61 | 120 | 61 | 120 | 120 | tnds low; bods high | tnds low: filter candidate |
| Salisbury Reds | 37 | NA | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 | 20 |  | tnds low: filter candidate |
| Select Bus Services | 23 | NA | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 5 | 10 | 10 |  | bods txc low: filter candidate |
| Select Bus Services | 8 | NA | 26 | 49 | 26 | 49 | 26 | 49 | 26 | 49 | 26 | 49 | 26 | 49 | 49 |  | tnds low: filter candidate |
| Select Bus Services | 8A | NA | 13 | 24 | 13 | 24 | 13 | 24 | 13 | 24 | 13 | 24 | 13 | 24 | 24 |  | tnds low: filter candidate |
| Southern Vectis | 206 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | tnds low: filter candidate |
| Southern Vectis | 211 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | tnds low: filter candidate |
| Southern Vectis | 39 | NA | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 |  | tnds low: filter candidate |
| Southern Vectis | 71 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | tnds low: filter candidate |
| Stagecoach Cumbria and Lancashire | 125 | NA | 159 | 0 | 159 | 0 | 159 | 0 | 159 | 0 | 159 | 0 | 159 | 0 | 159 |  | tnds low: filter candidate |
| Stagecoach Cumbria and Lancashire | 2A | NA | 35 | 0 | 35 | 0 | 35 | 0 | 35 | 0 | 35 | 0 | 35 | 0 | 0 |  | bods txc low: filter candidate |
| Stagecoach Cumbria and Lancashire | 31 | NA | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 | 113 |  | bods txc low: filter candidate |
| Stagecoach Cumbria and Lancashire | 31A | NA | 28 | 14 | 28 | 14 | 28 | 14 | 28 | 14 | 14 | 14 | 14 | 14 | 14 |  | bods txc low: filter candidate |
| Stagecoach Cumbria and Lancashire | 33 | NA | 48 | 24 | 48 | 24 | 48 | 24 | 48 | 24 | 24 | 24 | 24 | 24 | 24 |  | bods txc low: filter candidate |
| Stagecoach Midlands | 84 | NA | 48 | 16 | 48 | 16 | 48 | 16 | 16 | 16 | 16 | 16 | 16 | 16 | 28 |  | bods txc low: raw smaller but BODS GTFS has it |
| Stagecoach Midlands | 85 | NA | 63 | 21 | 63 | 21 | 63 | 21 | 21 | 21 | 21 | 21 | 21 | 21 | 24 |  | bods txc low: raw smaller but BODS GTFS has it |
| Stagecoach Midlands | 8A | NA | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 | 29 |  | bods txc low: filter candidate |
| Stagecoach South Wales | 26 | NA | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 | 30 |  | bods txc low: filter candidate |
| Swindons Bus Company | 155 | NA | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 2 |  | bods txc low: filter candidate |
| Swindons Bus Company | X76 | NA | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |  | tnds low: filter candidate |
| West Midlands Bus | 10 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 147 | 419 | tnds ok; bods ok | bods txc low: filter candidate |
| West Midlands Bus | 10A | NA | 76 | 38 | 76 | 38 | 76 | 38 | 76 | 38 | 76 | 38 | 76 | 38 | 108 |  | bods txc low: filter candidate |
| West Midlands Bus | 18 | NA | 25 | 14 | 25 | 14 | 25 | 14 | 25 | 14 | 25 | 14 | 25 | 14 | 0 |  | bods txc low: filter candidate |
| West Midlands Bus | 59 | 262 | 321 | 281 | 321 | 281 | 321 | 281 | 321 | 281 | 321 | 281 | 321 | 281 | 843 | tnds high; bods ok | bods txc low: filter candidate |
| West Midlands Bus | 61 | NA | 359 | 180 | 359 | 180 | 359 | 180 | 359 | 180 | 359 | 180 | 359 | 180 | 360 |  | bods txc low: filter candidate |
| West Midlands Bus | 63 | NA | 373 | 187 | 373 | 187 | 373 | 187 | 373 | 187 | 373 | 187 | 373 | 187 | 374 |  | bods txc low: filter candidate |
| West Midlands Bus | 814 | NA | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 4 |  | bods txc low: filter candidate |
| West Midlands Bus | 829 | NA | 4 | 1 | 4 | 1 | 4 | 1 | 4 | 1 | 4 | 1 | 4 | 1 | 3 |  | bods txc low: filter candidate |
| more Bus | 22 | 57 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 | tnds ok; bods ok | tnds low: filter candidate |
| more Bus | 32 | NA | 0 | 10 | 0 | 10 | 0 | 10 | 0 | 10 | 0 | 10 | 0 | 10 | 10 |  | tnds low: filter candidate |
| more Bus | 33 | 41 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | 18 | tnds low; bods low | tnds low: filter candidate |
| more Bus | X6 | 28 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | tnds ok; bods ok | tnds low: filter candidate |

| build | TNDS = BODS TXC (15%) | TNDS matches PDF | BODS TXC matches PDF | routes with a PDF |
|:---|---:|---:|---:|---:|
| r6b | 33 | 16 | 12 | 37 |
| r7d | 62 | 16 | 15 | 37 |
| r8b | 77 | 16 | 21 | 37 |
| r8e | 99 | 16 | 21 | 37 |
| r8j | 101 | 16 | 21 | 37 |
| r8o | 102 | 16 | 21 | 37 |

Controls: of 2,042 routes where the sources agreed under round 6b, 85
disagree under r8o.

## 5. What the files showed, and the rules

Each disagreeing route was traced to the files each source kept
(`scripts/route_subset_audit/show_files.py`,
`scratchpad diag/trace2.R`). Round 8 changed `txc_filter_files()` in
fifteen steps (8a-8o), each with a fixture test that fails on the build
before it; everything else the traces found is data, not filter. Steps
8f-8o were found by the national kept-file listing, the subset rerun or
the full rebuild after a change: 8f repairs two regressions of 8a and
8c, 8h one of 8f, 8i two of 8c and 8e, 8j one of 8b and one of round 7,
8k-8l extend 8j, 8m repairs one of 8b, and 8n and 8o are older faults
the same check turned up.

**Round 8a - a file is on one side of a school calendar only if all of
it is.** The filter records, per file, which side of a
ServicedOrganisation calendar it runs on, so that a term-time and a
holiday version of one timetable are both kept. It took the side from
any journey. First Norfolk & Suffolk publishes each edition of a route
as the whole timetable plus a few calendar-bound extras: route 64’s
edition from 25 October had four holiday-only extras, its successor from
1 November some term-only ones. The two looked like opposite sides,
neither replaced the other, and every Ipswich journey of routes 63, 64
and 65 ran twice (BODS TXC 52 departures at the reference stop against
31 in the timetable). Calendar tokens are now recorded only when every
journey is bound to the calendar (`txc_all_journeys_bound()`).

**Round 8b - files sharing an operator and ServiceCode are compared as
one registration.** Files were grouped by operator, normalised
description and line set, and a pair sharing few journeys was treated as
siblings. Four routes in the subset ran twice because of that:

| Route | What separated the two files | Effect |
|----|----|----|
| London United 117, 411 (BODS) | description retyped; December 2025 edition fully retimed (3% shared) | 2023 timetable ran beside the 2025 one |
| Dartline PR1, PR1A (BODS) | Dartline’s files have no description; the second export does | every journey twice |
| Kempsford K2 (BODS) | revision 3 retimes revision 2 from the same start date (0% shared) | both revisions ran |
| First Berkshire 7 (BODS) | line set 7, 7X against 7 | 18 October edition ran beside 1 November’s |

Files sharing operator and ServiceCode are now grouped as well, provided
they publish a line in common (Arriva Cymru’s code “12/X12” covers two
routes). Within such a group a pair that fails the shared-journeys test
is still treated as versions when the files come from different exports
(modification time more than an hour apart, or a different revision) and
the smaller has at least half the journeys of the larger. The export
test keeps siblings written together apart (Stirling UL, 41 ms); the
size test keeps supplements apart (Hodgsons 87, 26 journeys and 6; Red
Eagle W20, 15 and 2). The stale-version rule gained the same shared-line
test. The identical-period tie-break now compares revision numbers as
numbers.

**Round 8c - the parts of a split registration are not editions of each
other.** West Midlands Bus publishes ServiceCode PD2093720:4 as two
files per edition, “WA” (lines 8 and 9, 147 journeys) and “WN” (line 9,
250), written minutes apart but with their own revision numbers. The 8b
export test read different revisions as different exports, so the 15
November WA was taken for a retimed edition of the 1 November WN and
both WA files - the Inner Circle - were dropped. The export test now
prefers the modification time (more than an hour apart) and falls back
on the revision only without one; and a file with a sibling in its own
export is compared as a retimed edition only with a file publishing the
same lines.

**Round 8d - one creation time does not make two files siblings, and
excluded dates tell week variants apart.** Equal creation times with
different ServiceCodes were read as siblings of one export. But TNDS
keeps the registration’s creation time through every edition: Stagecoach
Midlands’ route 85 is three open-ended editions (WM_SC_SCNH_85_1, \_4_A,
\_3_A, all created 8 December 2021, modified September, October and
November 2026), every journey shared, and all three ran - 63 departures
at Coventry against 21 in BODS. Equal creation times now mean siblings
only within one export or where the journeys differ. Separately,
Metrobus files route 23 as one weekday file running only the week of 19
October, one running every other week, and a school-extras file, sharing
code, line, period, weekdays and nearly every journey; they differ only
in the service’s DaysOfNonOperation date ranges. The filter now reads
those ranges and a file running on under half the other’s dates is a
variant beside it, not a version of it (`txc_dates_shared()`). That
restored fourteen Metrobus routes that BODS TransXChange had at 0.

**Round 8e - a much smaller file is not a successor.** Hodgsons’ 87N is
the six evening journeys of route 87 from 20 November 2024, beside the
26-journey weekday file from two days before that carries the same
evening times. The versions test passed on the small file’s journeys and
closing the weekday file deleted its 20 daytime journeys. A file with
under half the journeys of the one before does not replace it - as for
the retimed and stale rules - and the stale rule now also needs its
successor from another export (Hodgsons writes the Saturday and evening
files in one).

**Round 8f - two regressions the national listing found.** (1) 8a’s
all-journeys test removed the calendar side from morebus U3’s term and
holiday files (Bournemouth University, from 2 November 2026): the
holiday file carries 112 Christmas journeys on MondayToSunday excluded
from every date but one, the term file three that run only a few weeks.
Neither was “wholly bound”, so both lost their side and the
identical-period tie-break deleted the holiday file (174 journeys). A
journey excluded from at least half the file’s period now counts as
bound - dated extras, not a whole timetable. First 64’s plain journeys
carry no such ranges, so 8a still holds. (2) 8c’s switch to modification
times made Yorkshire Coastliner’s 31X - Easingwold-Kirkbymoorside (14
October 2025) and Easingwold-York (15 October), one ServiceCode, one
stop of 88 in common - look like an edition and its retiming, and
Kirkbymoorside was deleted. A retimed edition must now run over the same
stops (half their union, the measure the handover and stale rules use).

**Round 8g - editions renamed and recoded are still compared.**
Stagecoach Merseyside’s route 33 is NW_SC_SCMY_33_2 (“Maghull Station -
Maghull Station”, August 2026) and NW_SC_SCMY_33_1 (“Maghull - Maghull”,
October), both open-ended with every journey the same. Neither
description nor ServiceCode matched, so the two were never compared and
both ran (48 departures against BODS’s 24; 31 and 31A likewise). Files
sharing operator, creation time and line set now form a group too; 8d’s
rule then separates siblings of one export from editions across exports.

**Round 8h - the stops a route calls at, not the stops a file lists.**
8f compared the StopPoints each file declares. Hodgsons’ 2024 BODS
exports declare every stop the operator served: 160 for route 79, which
calls at 50, and 28 for route 60, which calls at 8. Against the 2026
editions (43 and 21 declared) the overlap fell below half, the old
exports stopped being editions, and the subset rerun showed route 79
back at 20 departures for TNDS’s 9 (60 and 60A doubled likewise). The
test now uses the stops the journey patterns call at, where the editions
agree (40 of 53 for route 79, 8 of 8 for 60 and 60A); 31X’s two files
still share 1 of 88. The same change keeps EYMS’s Castle Howard - Malton
file for route 81 open past 19 December: 8e took the York - Castle
Howard edition starting 20 December, 3 shared stops of 92, for its
successor and would have ended the Malton section with it.

**Round 8i - a later, newer file is the next edition, however short.**
The BODS listing showed First’s weekly editions running side by side
over Christmas. First Somerset files route 4 as one registration in
weekly editions: 13 December (41 journeys, revision 858), Christmas week
(20, revision 859) and New Year (33, revision 860, five minutes after
Christmas). Two guards stopped them chaining: 8e’s small-successor rule
(Christmas has under half the journeys of the week before, so it was
taken for a supplement like Hodgsons’ 87N) and 8c’s one-hour export
window (Christmas and New Year were taken for parts of one export). A
file that starts later and is also the newer, by modification time or
else by revision, is now from a later export, and the small-successor
guard applies only within one export, which is where 87N sits (revision
45, one modification time). The same guard had stopped West Midlands
Bus’s X21/X22 term/weekend split from 8e on (term file 217 journeys to
528), and BODS ran both files in full: 221 X21 trips on the check day
against 112 (TNDS 109). It also lets Hodgsons’ current three-file export
of school route 879 close the 2021 upload it replaces (BODS 6 departures
at the reference stop, the same double count as BODS GTFS, down to 3;
TNDS 2).

**Round 8j - two faults the control routes showed.** Of the 2,042 routes
where the sources agreed under round 6b, the ones that stopped agreeing
were checked file by file. (1) West Midlands Bus files school route
705/788 as two parts of one export with one period, “WA” (five journeys,
lines 705 and 788) and “WB” (two, 705); WB’s 07:54 passed the versions
test against WA’s 07:55 and the identical-period tie-break deleted WA
and line 788 with it (BODS 4 departures for 1, and 2 for 0, from round
8b). A repeated upload carries the whole timetable, so within one export
a file under half the size of the other no longer replaces it. (2)
National Express West Midlands’ route 96 ran beside West Midlands Bus’s
from 1 November (BODS 99 departures at Chelmsley for 66). NX published
an open-ended file from 30 August and a last edition for 25-31 October;
rules 2 and 3 set the ended edition aside, as they must for
trentbarton’s half-term weeks, and West Midlands Bus retimed the route
at the takeover (61 of 100 departure times kept), so the handover rule’s
versions test failed. A kept file now records the end of any later,
newer edition of its registration that has ended, and the handover rule
accepts that end, the day before the new operator starts, in place of
the timetable match; the stop and day tests still apply. The other
control changes are corrections: First Berkshire 7X is not in First’s
timetable from 2 November and its registration’s November edition drops
it (BODS 0; TNDS’s 45 is a per-line file nothing supersedes, and BODS
GTFS repeats it), and Gateshead’s PR1 weekday file, wrongly dropped in
round 8b, is back (94, as BODS GTFS).

**Rounds 8k and 8l - the rest of the 1 November takeover.** The 8j
change sat inside the handover rule, which pairs files with exactly the
same lines, so it closed route 96 and nothing else. West Midlands Bus
took over National Express’s Birmingham and Coventry routes on 1
November with different line sets: NX’s 11A/11C became West Midlands
Bus’s 11A/11S and 11C, NX’s 66 became 66/66A, Coventry’s 20/20A/20B
became 20/20A, and 22 became 22/22A. The announced handover is now a
separate pass: a kept file whose registration has an ended last edition,
and which is still running after that end, is closed there if files from
another operator start the next day, share a line with it, and between
them cover at least half its stops and all its days. 8l adds that each
of those successor files must itself run largely over the old route
(half the stops of the smaller file): First Worcestershire’s 20/20A/20B
also starts on 1 November and shares the line numbers, but runs in
Worcester. In the national listing for the November 2026 BODS archive
the pass closes five more NX files on 31 October - 11A/11C (weekday and
weekend), 66, Coventry 20/20A/20B and 22, 3,883 journeys between them -
and changes nothing in TNDS.

**Round 8m - two depots’ documents for one route.** The national
before-and-after check of the full rebuild (8i against 6b) moved one PDF
route the wrong way: First Essex 3, Chelmsford - Southend, BODS TXC from
0.85 of the timetable to 0.40. Both of First Essex’s Chelmsford and
Hadleigh depots work the route and each publishes its own document for
the whole of it under the one registration (PF0000599:376): interleaved
times, the same stops, separate creation dates (7 and 29 September 2021)
and separate revision series (697-726 and 413-420), both re-issued for
December, Christmas and New Year. The retimed-edition test of round 8
(same registration, another export, comparable size, same stops) took
each depot’s file for an edition of the other’s, and the
identical-period tie-break dropped Chelmsford’s. A document that a new
one replaces is not edited again once the new one appears; a depot’s
document is kept up beside the other. Files whose documents each have at
least two editions in the registration, written over overlapping spans,
are no longer retimed editions of each other.

**Round 8n - line names in any case.** The same national check (every
file the November 2026 BODS listing dropped between round 7c and round
8l, 191 files) found the First Essex depot files and nothing else wrong.
All the other drops were checked: First’s 25 October editions and NX’s
half-term weeks, superseded as intended; old Hodgsons, Hawkes 891, John
Dix 2025 and PC Coaches 49 editions replaced by current ones; Blueworks’
X70F, whose one journey is in X70; Kempsford’s 768, whose July file and
September file carry the same weekday times. It also showed Kempsford’s
K2 still keeping two of its three editions: the July file names the line
“k2” and the later two “K2”, so they shared no line and were never
compared (38 journeys a day for 19). Line names are now compared in
upper case.

**Round 8o - a takeover copy dated before the takeover.** The files the
same listing newly kept since round 7c were checked too. Most are
National Express editions that rule 2’s round-7 fix restored and that
now end on 31 October or 14 November, as they should. But for routes 9,
11/11A, 52 and others West Midlands Bus published copies of NX’s
timetables on 21 October dated from NX’s own start, 30 August, with the
same journeys (448, 374, 342). The handover rule skips two files that
start on the same day, and the announced-handover pass of 8k wanted a
successor starting the day after NX’s last edition ended, so both
operators’ copies ran from 30 August to 14 November. The pass now also
accepts another operator’s file dated earlier if it carries the outgoing
timetable (the versions test, and at least half of the outgoing file’s
journeys in it), and starts that file at the takeover. Another operator
already running its own journeys on the route - a joint service - fails
the journey test and is left alone.

**Measurement fixes.** The reference-stop lookup is now case-insensitive
(BODS writes Hodgsons’ 13004000A as 13004000a, which showed as 0
departures). First’s timetables mark school-day and school-holiday
columns with SD/SH codes on a line below the service numbers; the reader
(`first_reader.py`) now reads those and counts a school day, which
brought the six First routes from “unreliable” to exact agreement with
both feeds.

**Not filter faults.**

- *Welsh independents.* TNDS Wales carries Phil Anslow, Harris Coaches,
  Adventure Travel and Thomas of Rhondda; BODS carries none of their
  files. Their routes 1, 6, C16, C18, X1 and 173 share numbers and
  streets with Stagecoach’s, and the seed’s stop-overlap match joined
  them. TNDS was not double-counting. The seed now refuses a
  stop-overlap match between two operators the NOC register identifies
  as different.
- *Per-day-type files.* Red Eagle W20 and Select 8 publish a weekday and
  a Saturday file of one timetable; both are rightly kept. Their gaps
  between TNDS and BODS are in the data.
- *Preston Bus 35 and 8.* Each source keeps the right files; BODS
  publishes three day-type files, TNDS one. The difference is in the
  journeys.

## 6. How the DfT builds BODS GTFS (bods-integrated-data, commit b35a847f, 30 Oct 2026)

Read from the source (`src/functions/txc-processor`,
`gtfs-timetables-generator`, `tnds-txc-retriever`, `bods-txc-retriever`,
`shared/schema/dates.schema.ts`).

**Inputs.** The BODS bulk archive and the BODS coach archive, every
file; every TNDS zip except NCSD (coach now comes from BODS). A TNDS
service is processed only if its zip is L, S or W (London, Scotland,
Wales) or its mode is coach, ferry, metro, tram or underground. English
TNDS bus is never read.

**No file versioning.** Every service in every file is loaded unless its
`EndDate` is before today; there is no `StartDate` test, so future-dated
files load too, and nothing chooses between versions of the same
registration. The only deduplication is at the end, in SQL:
`DISTINCT ON (route_id, service_id, ticket_machine_journey_code, direction, origin_stop_ref, destination_stop_ref, departure_time) ORDER BY revision_number DESC`.
Two versions of a timetable with different calendars have different
`service_id`s and both survive; two files whose `Line` ids differ get
two routes and both survive. That is the 3.7% of duplicate runs measured
earlier, and the 2-3x counts for National Express West Midlands and
First Berkshire 7 in section 4.

**TNDS against BODS.** The route key is NOC + LineName. A TNDS service
whose NOC + LineName already exists from a BODS file is skipped as a
duplicate - only if the BODS file was processed first, and only on that
exact key. Where London files carry a different NOC in TNDS and BODS
both load, which is the London doubling.

**Calendars.** Start = max(StartDate, today), end = min(EndDate, start +
9 months): the feed never says what ran before the build date. A journey
with no operating profile at any level runs Monday to Sunday. Serviced
organisation working days are read from every matching organisation,
holidays only from the first (`.find`).

**Bank holidays.** `AllHolidaysExceptChristmas` includes St Andrew’s Day
(fixed 30 November) and `AllBankHolidays` includes that group, for every
service in Great Britain. So any English or Welsh service that declares
`<DaysOfNonOperation><AllBankHolidays/>` is cancelled on 30 November -
the ~37,000-trip St Andrew’s Day drop, mostly London.

**Modes.** `Mode` is mapped to `route_type` as written (bus 3, coach
200, ferry 4, metro/underground 1, rail 2, tram 0; anything else bus).
Nothing corrects a file that files a heritage railway as tram or the DLR
as rail.

**For us.** BODS GTFS England bus is BODS TransXChange with no version
selection: an upper bound, not a reference. Its London, Scotland and
Wales bus is TNDS, so a TNDS vs BODS GTFS agreement there says nothing
about the data. The DfT “merge” is not a comparison of services: it is
BODS first, TNDS only where BODS has no route on the same NOC + line,
and only for L/S/W and non-bus modes.

## 7. What remains data-limited

These routes still disagree after round 8o, and in each case the files
were read and the difference is in what the publishers put in them.

| Route | TNDS / BODS TXC | Cause |
|----|----|----|
| Stagecoach 125 (Cumbria) | 159 / 0 | Filed under SCMY in TNDS and SCCU in BODS; the full pipeline finds 159 in each. A route-matching gap, not a filter one. |
| West Midlands Bus 61, 63 | 359 / 180, 373 / 187 | One TNDS file holds a Monday-Friday and a Monday-Thursday set of the same day that share only 35 journeys; both run. No PDF is readable (National Express prints each timetable twice). |
| Red Eagle W20, 361, 88 | 9 / 17, 27 / 46, 10 / 12 | Each source keeps the right files. The timetable sides with TNDS on W20 (9) and with BODS on 361 (46) and 88 (12): neither source is complete. |
| Select 8, 8A, 23 | about 1 : 2 | Weekday and Saturday files both rightly kept; BODS carries journeys TNDS does not. No timetable read. |
| Rotala Preston 35, 8 | 84 / 164, 61 / 120 | BODS publishes three day-type files, TNDS one; the journeys differ. The PDF sides with BODS on 35 (164) and with neither on 8 (73). |
| Arriva North East X93 | 32 / 56 | BODS publishes three registrations (PB0002717387, 88, 89; 254 journeys a week), TNDS one file of 94; the timetable (56) sides with BODS. |
| Arriva North East 13A/13B, Arriva Kent 71 | 78 / 39, 68 / 48 | Different journeys in the source files; no filter decision touches them. The timetable sides with BODS on 71 (48). |
| Border Buses, Redline, Gateshead 19, Grant Palmer JO | TNDS only | BODS carries no current file for these services. |
| Diamond (West Midlands) school routes, more Bus 32 | BODS only | TNDS carries no file. |
| Centrebus 81 | 20 / 10 | BODS’s only file (CBNL_81A, line 81) has 10 journeys; TNDS’s Leicestershire file has 80 over the week. |
| D&G 340 | 11 / 20 | BODS: an 18-journey weekday file plus two school-day extras from 7 November; TNDS: one Transport for West Midlands file of 21 journeys for the whole week. |
| Hodgsons 29, 72 | 10 / 14, 12 / 15 | BODS still carries a July 2023 export with no revision or modification time (“Hodgsons Coach Operator 29 2023-07-12”), open-ended, beside the current files; nothing in it says it was replaced. |

Chaserider 827 and Falcon 467 appear in the comparison table but their
operators were not in the extract (NOCs CHAS and FALC); the counts shown
are other operators’ routes with the same number, so they are not
evidence either way.

These are the routes where combining TNDS and BODS could add something -
but per the plan, merging waits until TNDS is handled as well as it can
be.

## 8. The full run

Round 8o was checked nationally before it was installed: every BODS and
TNDS file kept on 11 November, listed by the round-8l and round-8o
builds and compared in both directions. 73 BODS files changed and every
one was expected: 64 National Express / West Midlands Bus pairs (NX’s
August editions now end on 31 October, WMB’s backdated copies start on 1
November), First Essex 3’s Chelmsford November and December editions
kept again, the lower-case Kempsford “k2” and “x91” copies dropped with
the revision-3 K2 and X91 files still kept, and one X31 file whose name
hash changed. TNDS did not change.

UK2GTFS was then installed and the five validation targets rebuilt (TNDS
26 July, TNDS and the BODS TransXChange archive of 11 November; 12
hours, 18 November). Against round 6b, the build this audit started
from, and round 8i, the last full rebuild:

| Check | r6b | r8i | final (8o) |
|----|----|----|----|
| November case-stop readings in force | 78 | 78 | 78 |
| TNDS within 15% of the timetable | 61 | 61 | 61 |
| BODS TransXChange (UK2GTFS) within 15% | 58 | 59 | 59 |
| BODS GTFS (DfT) within 15% | 41 | 41 | 41 |
| Median error, TNDS / BODS TXC / BODS GTFS | 5.5 / 5.5 / 12.9% | same | same |
| July case-stop readings in force; TNDS / BODS GTFS within 15% | 19; 5 / 9 | same | same |
| LSOAs where TNDS and BODS GTFS agree exactly (of 40,808) | 20,709 | 20,694 | 20,694 |

Two readings changed between r6b and the final build, both in BODS
TransXChange: Metrobus 100 (0.32 to 1.36 of the timetable) and 200 (0.30
to 1.08), now equal to TNDS. First Essex 3 fell to 0.40 in r8i (round 8b
dropped the Chelmsford depot’s document) and is back at 0.85 with round
8m, as in r6b and in the other two feeds. West Midlands Bus X21 and X22,
0.70-0.74 in BODS TransXChange in the first November check, are within
15% in every build from round 8i.

The case stops barely move because the filter faults this audit found
are mostly on routes without a readable timetable; the subset table in
§4 is where they show (TNDS and BODS TransXChange agreeing on 2,059
reference stops of 2,218, candidates and controls). The LSOA count
compares TNDS with the DfT’s BODS GTFS, which §6 shows is wrong in
places, so the 15 fewer exact agreements are not by themselves a loss of
accuracy; the TNDS July changes behind them were made by rounds 8a-8i
and reviewed file by file in the national listings.

The rest of the series (about 40 hours) still carries the old filter and
has not been rebuilt.
