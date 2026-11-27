---
title: "Where is the stop? Stop locations in TNDS, BODS and NaPTAN, November 2026"
output: md_document
---



# Where is the stop? Stop locations in TNDS, BODS and NaPTAN

Until version 0.4.1, UK2GTFS took every stop's position from NaPTAN. The
pipeline's NaPTAN copy (the `naptan` target) was downloaded on 2 August 2026
and is never refreshed. A stop opened since then had no position, and
`gtfs_clean()` silently deleted the stop and every call at it, even though the
TransXChange file often says exactly where the stop is. That is how SL12's
Ferry Lane stop in Rainham, with 520 calls a fortnight in its TfL file,
vanished from the 18 November conversion
([red stops](stop_disagreement_cities.md)).

UK2GTFS 0.4.1 adds a `stop_locations` argument to `transxchange2gtfs()`:

| Option | Position used |
|---|---|
| `"naptan_fill"` (the new default) | NaPTAN; the file's own position where NaPTAN lacks the stop |
| `"naptan"` | NaPTAN only (the old behaviour) |
| `"txc"` | the file's position only |
| `"txc_fill"` | the file's position; NaPTAN where the file gives none |

A stop that several files locate takes the median of their positions. Every
conversion now reports how many stops each source located. `gtfs_clean()`
also now says how many stops and calls it drops for having no position.

Whether the file's position can be trusted depends on the files: do they give
positions at all, and do those positions agree with NaPTAN? This report
measures both, for every file in:

- both TNDS editions of 18 November (TransXChange 2.1 and 2.5);
- the BODS TransXChange archive of 18 November;
- the BODS Coach feed of 18 November.

`scripts/stop_locations/txc_stop_points.py` reads each file's `<StopPoints>`.
A stop is declared in one of two ways:

- as a reference to NaPTAN (`<AnnotatedStopPointRef>`), which may carry a
  `<Location>`;
- as a full definition (`<StopPoint>` with an `<AtcoCode>` and a
  `<Place><Location>`).

The script also records which stops the timetable actually calls at. Positions
are compared with the full NaPTAN register downloaded on 19 November, which
holds 435,833 stops. Of these,
388,173 are active and
47,659 inactive.

## Summary

- **Whether a file gives positions depends on who wrote it.**
  - In BODS, 62% of files place every stop, writing the
    position into the reference itself in WGS84, and 37%
    place none. The ones that place none are mostly the big groups' exports:
    every First file and all but a handful of Stagecoach's and National
    Express West Midlands'. So 48% of
    the stops BODS calls at have a file position.
  - In TNDS only two kinds of publisher define stops in full: Transport for
    London (every file) and a minority of the North West and Yorkshire
    suppliers. That is about 11% of the stops TNDS calls at.
  - Every other stop is a bare reference, and only NaPTAN can place it.
- **Where TNDS gives a position, it is NaPTAN's.**
  - The median distance from NaPTAN is 0 m.
  - 95% of TfL's definitions are within 5 m.
  - None of the 115,000 TNDS definitions is more than 1 km away.
- **BODS positions are close to NaPTAN, but not identical, and a few are
  wrong.**
  - The median distance is 1.4 m and
    95% are within 20 m.
  - 1.7% are more than 50 m away and
    0.02% more than 1 km. The worst,
    Monmouth Clinic, is placed 373 km away.
  - Because a few are wildly wrong, the file's position should fill gaps,
    not override NaPTAN. That is why the default is `"naptan_fill"`, not
    `"txc"`.
- **Filling from the files rescues some stops; a fresh NaPTAN rescues more.**
  - Of the 318,910 stops the TNDS 2.5 timetables call
    at, 465 are missing from the
    pipeline's NaPTAN copy, and the file locates
    43 of them.
  - 264 of
    them are in the current NaPTAN.
  - For BODS the figures are 729 missing,
    305 located by the file, and
    269
    in the current NaPTAN.
  - So `naptan_fill` and a refreshed NaPTAN copy are complements, not
    alternatives.

## Do the files give stop positions?


Table: Files by how they declare their stops and whether they give positions

|Source            |Stops declared as          |Positions          |Files  |Share |
|:-----------------|:--------------------------|:------------------|:------|:-----|
|BODS Coach        |AnnotatedStopPointRef      |no stop located    |245    |64.0% |
|BODS Coach        |both                       |some stops located |138    |36.0% |
|BODS TransXChange |AnnotatedStopPointRef      |every stop located |13,605 |61.6% |
|BODS TransXChange |AnnotatedStopPointRef      |no stop located    |8,188  |37.1% |
|BODS TransXChange |AnnotatedStopPointRef      |some stops located |301    |1.4%  |
|BODS TransXChange |both                       |some stops located |3      |0.0%  |
|BODS TransXChange |none                       |no stops declared  |1      |0.0%  |
|TNDS 2.1          |AnnotatedStopPointRef      |no stop located    |15,438 |89.5% |
|TNDS 2.1          |full StopPoint definitions |every stop located |1,814  |10.5% |
|TNDS 2.1          |both                       |some stops located |2      |0.0%  |
|TNDS 2.5          |AnnotatedStopPointRef      |no stop located    |15,206 |89.3% |
|TNDS 2.5          |full StopPoint definitions |every stop located |1,812  |10.6% |
|TNDS 2.5          |both                       |some stops located |1      |0.0%  |


Table: TNDS 2.5 by supplier (file-name prefix, or region where there is none)

|Publisher      |Files |Full definitions |Stops with a position |
|:--------------|:-----|:----------------|:---------------------|
|nw             |2,274 |16%              |16%                   |
|s (unprefixed) |1,953 |0%               |0%                    |
|swe            |1,242 |0%               |0%                    |
|sw             |907   |0%               |0%                    |
|se             |851   |0%               |0%                    |
|tfl            |840   |100%             |100%                  |
|square         |789   |0%               |0%                    |
|svr            |717   |85%              |85%                   |
|ne             |706   |0%               |0%                    |
|wm             |672   |0%               |0%                    |
|s              |638   |0%               |0%                    |
|w (unprefixed) |577   |0%               |0%                    |
|em             |550   |0%               |0%                    |
|twm            |491   |0%               |0%                    |
|y              |479   |0%               |0%                    |
|w              |389   |0%               |0%                    |
|essex          |336   |0%               |0%                    |
|cen            |331   |0%               |0%                    |
|y (unprefixed) |228   |0%               |0%                    |
|suf            |220   |0%               |0%                    |

In TNDS the position comes with the supplier, not the region:

- Transport for London defines every stop of every file in full.
- Yorkshire's `SVR` files do the same.
- The North West's files are mixed.
- Everyone else (Traveline's regional suppliers, the "square" BODS-derived
  files, Scotland, Wales) writes bare references.

BODS splits by operator group, not by region:

- Arriva, Go-Ahead and most independents give a position for every stop.
- First (every file), Stagecoach and National Express West Midlands (all but
  a handful of files) give none.
- Independents are mixed: about a fifth of the other operators' files give
  no positions.

So a new stop on a First or Stagecoach route cannot be placed from BODS
either.

## Do the positions agree with NaPTAN?


Table: Distance from each file's stop position to the current NaPTAN position (one row per stop per file)

|Source            |Stop definitions | Median (m)| 95th percentile (m)|Over 50 m |Over 250 m |Over 1 km |
|:-----------------|:----------------|----------:|-------------------:|:---------|:----------|:---------|
|BODS TransXChange |1,179,640        |        1.4|                20.3|1.71%     |0.058%     |0.016%    |
|TNDS 2.1          |115,788          |        0.0|                 0.0|0.36%     |0.011%     |0.000%    |
|TNDS 2.5          |115,457          |        0.0|                 0.0|0.36%     |0.011%     |0.000%    |


Table: The same, by publisher (BODS: by dataset) for publishers with at least 5,000 stop definitions

|Source            |Publisher                                |Definitions | Median (m)| 95th percentile (m)|Over 50 m |Over 1 km |
|:-----------------|:----------------------------------------|:-----------|----------:|-------------------:|:---------|:---------|
|BODS TransXChange |21646_129305_2026-11-03_16-01-58_current |113,073     |        5.1|                51.1|5.07%     |0.005%    |
|BODS TransXChange |13322_129842_2026-11-11_16-01-12_current |95,943      |        2.8|                 7.2|0.56%     |0.000%    |
|BODS TransXChange |17472_130212_2026-11-17_16-03-53_current |69,616      |        1.8|                 2.3|0.57%     |0.000%    |
|BODS TransXChange |25491_128769_2026-10-27_16-12-40         |66,238      |        0.1|                24.1|1.33%     |0.000%    |
|BODS TransXChange |14928_129776_2026-11-10_16-01-19_current |55,785      |        1.7|                 2.2|0.09%     |0.000%    |
|BODS TransXChange |15884_129367_2026-11-04_16-01-18_current |44,086      |        0.2|                 5.1|0.50%     |0.020%    |
|BODS TransXChange |22530_126443_2026-09-21_15-06-21_current |39,767      |        0.1|                23.2|1.35%     |0.000%    |
|BODS TransXChange |22531_130031_2026-11-13_16-03-24_current |39,167      |        0.2|                17.3|1.16%     |0.000%    |
|BODS TransXChange |17163_130137_2026-11-16_16-01-41_current |34,527      |        0.4|                 0.6|0.18%     |0.000%    |
|BODS TransXChange |22537_129841_2026-11-11_16-01-09_current |31,077      |        0.1|                48.0|4.82%     |0.026%    |
|BODS TransXChange |Archive_0H8ulAd                          |28,826      |        0.5|                 3.2|0.55%     |0.035%    |
|BODS TransXChange |22533_129420_2026-11-05_04-02-17_current |28,462      |        2.0|                17.6|2.61%     |0.000%    |
|BODS TransXChange |12739_129477_2026-11-05_16-05-40_current |28,285      |        1.7|                 2.3|0.24%     |0.000%    |
|BODS TransXChange |15954_129840_2026-11-11_16-01-05_current |27,953      |        0.2|                32.8|2.06%     |0.000%    |
|BODS TransXChange |15766_129916_2026-11-12_04-03-49_current |26,108      |        0.2|                29.6|2.53%     |0.000%    |
|BODS TransXChange |25493_129071_2026-10-31_04-07-35         |25,974      |        0.2|                13.6|1.70%     |0.108%    |
|BODS TransXChange |15438_130216_2026-11-17_16-07-15_current |25,120      |        0.4|                 8.7|1.20%     |0.096%    |
|BODS TransXChange |12769_128561_2026-10-23_15-02-22_current |22,472      |        1.7|                 2.2|0.39%     |0.000%    |
|BODS TransXChange |16467_130217_2026-11-17_16-02-43_current |21,991      |        0.3|                 2.4|0.02%     |0.000%    |
|BODS TransXChange |15761_129372_2026-11-04_16-02-46_current |20,676      |        0.2|                14.1|1.93%     |0.000%    |
|BODS TransXChange |15913_129482_2026-11-05_16-06-37         |20,170      |        0.2|                29.3|2.48%     |0.000%    |
|BODS TransXChange |13493_129768_2026-11-10_16-01-07_current |18,883      |        5.0|                57.9|6.06%     |0.429%    |
|BODS TransXChange |15654_129421_2026-11-05_04-02-18_current |17,218      |        2.2|                 2.2|0.02%     |0.000%    |
|BODS TransXChange |15796_129486_2026-11-05_16-07-50_current |15,232      |        0.1|                 2.0|1.63%     |0.000%    |
|BODS TransXChange |Archive_FbCjAZ1                          |11,947      |        0.2|                 3.1|0.96%     |0.000%    |


Table: The stops whose file position is furthest from NaPTAN

|Source            |Stop         |Name                 | Distance (km)|NaPTAN status |
|:-----------------|:------------|:--------------------|-------------:|:-------------|
|BODS TransXChange |5330AWB31322 |Monmouth Clinic      |         372.7|active        |
|BODS TransXChange |0500HAWEA009 |Pinner Lane          |          31.6|active        |
|BODS TransXChange |2500LA00196  |Concourse            |          15.7|active        |
|BODS TransXChange |450032528    |Dewsbury Bus Station |          13.2|active        |
|BODS TransXChange |1500IM1547   |Lower Rd             |           9.7|active        |
|BODS TransXChange |069000014355 |Sankey Forum         |           6.8|active        |
|BODS TransXChange |069000022590 |M6 Bridge            |           6.7|active        |

The positions TNDS gives are NaPTAN's, to the metre. They are useful for a
stop NaPTAN has since dropped or not yet added, and never contradict it.

BODS positions come from each operator's own data:

- They mostly sit within a few metres of NaPTAN. Where they don't, this report
  does not establish whether the operator or NaPTAN is out of date.
- The few kilometre-scale differences are plainly errors.

Either way, a BODS position should not be preferred where NaPTAN has the
stop.

## One stop, several positions


Table: Stops whose definitions in different files disagree with each other

|Source            |Stops defined by more than one file |Spread over 50 m |Over 250 m |Over 1 km |
|:-----------------|:-----------------------------------|:----------------|:----------|:---------|
|BODS Coach        |28                                  |0                |0          |0         |
|BODS TransXChange |109,859                             |509              |25         |5         |
|TNDS 2.1          |21,805                              |0                |0          |0         |
|TNDS 2.5          |21,788                              |0                |0          |0         |

UK2GTFS takes the median of a stop's file positions, so one stray definition
among several does not move it. This matters only for the stops it fills
(those NaPTAN lacks). Where NaPTAN has the stop, the file positions are not
used under `"naptan_fill"`.

## Stops the timetables use that NaPTAN does not have


Table: Stops the timetables call at, against the two NaPTAN copies

|Source            |Stops called at |With a file position |Missing from the pipeline NaPTAN (2 Aug) |... of which the file locates |Missing from current NaPTAN (19 Nov) |... of which the file locates |In NaPTAN but inactive |
|:-----------------|:---------------|:--------------------|:----------------------------------------|:-----------------------------|:------------------------------------|:-----------------------------|:----------------------|
|BODS TransXChange |249,670         |48%                  |729                                      |305                           |460                                  |160                           |880                    |
|TNDS 2.1          |319,169         |11%                  |473                                      |43                            |204                                  |118                           |529                    |
|TNDS 2.5          |318,910         |11%                  |465                                      |43                            |201                                  |118                           |509                    |
|BODS Coach        |1,549           |3%                   |88                                       |51                            |86                                   |51                            |3                      |

The pipeline's NaPTAN copy includes UK2GTFS's own `naptan_missing` additions.
That is why a few stops are missing from the current register but not from
the copy.

A stop missing from the copy has no position under the old behaviour. Under
`"naptan_fill"` it has one if the file gives one. In TNDS that is mostly the
London stops, because TfL is the one large publisher that defines its stops;
elsewhere in TNDS a new stop can only be placed by a newer NaPTAN.

NaPTAN marks 509 stops called at in TNDS 2.5,
and 880 in BODS, as inactive. They still have
positions, so they are converted. Whether a timetable calling at an inactive
stop is right is a separate question this report does not answer.

## What `naptan_fill` did in the November conversions


Table: Stop positions in the 18 November conversions with stop_locations = "naptan_fill" (calls over the conversion window, before date trimming)

|Conversion        |Stops from NaPTAN |Stops from the files |Calls kept by the fill |Stops with no position |Calls still lost |
|:-----------------|:-----------------|:--------------------|:----------------------|:----------------------|:----------------|
|BODS Coach        |1,451             |41                   |2,504                  |37                     |1,270            |
|BODS TransXChange |248,100           |337                  |7,166                  |410                    |17,225           |
|TNDS 2.1          |333,866           |43                   |15,373                 |438                    |28,708           |
|TNDS 2.5          |327,656           |43                   |15,373                 |427                    |28,454           |
|TNDS blend        |328,028           |43                   |15,373                 |427                    |28,454           |



In TNDS 2.5 the fill placed 43 stops,
all in London and Yorkshire, and kept 15,373
calls. 427 stops and
28,454 calls are still lost, because their
files give no position. In BODS TransXChange the fill placed
337 stops and kept
7,166 calls;
410 stops are still lost. A refreshed NaPTAN would place most of the
remainder (see the table above).



For comparison, the DfT's BODS GTFS places its stops within
0.35 m of NaPTAN at the median, and
0.016% are more than 50 m away. That is far closer than
the operators' own files, so it appears to take its positions from NaPTAN.

## Recommendations

1. **Keep `"naptan_fill"` as the UK2GTFS default.** It changes nothing where
   NaPTAN has the stop, and it keeps the calls that were silently lost where
   NaPTAN does not.
2. **Refresh the pipeline's NaPTAN copy as part of the next series rebuild,
   and date it.** Most TNDS files give no position, so for them only a newer
   NaPTAN helps. The frozen copy should match the snapshots it converts:
   historic snapshots want an older register, not a newer one, because stops
   are deleted as well as added.
3. **Do not use `"txc"` or `"txc_fill"` for BODS.** A handful of operator
   positions are kilometres out. For TNDS the two give the same answer as
   NaPTAN wherever both exist.
