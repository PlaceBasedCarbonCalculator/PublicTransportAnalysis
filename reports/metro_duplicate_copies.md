# The Underground, published twice: why metro frequency spikes in single years

Leytonstone sits on the Central line and on nothing else. In
`data/trips_per_lsoa21_22_by_mode_*.Rds`, LSOA **E01004440** reports metro
frequency in the afternoon peak of 42 to 55 trips per hour in most years — and
**96.8 in 2021** and **101.3 in 2025**.

|Year|`tph_Wed_Afternoon Peak`|`tph_Sat_Afternoon Peak`|`routes_Afternoon Peak`|
|---:|-----------------------:|-----------------------:|----------------------:|
|2007–2009|53.7|48.0|50|
|2010|54.0|48.0|48|
|2011|54.0|48.0|47|
|2014–2017|*no metro row at all*|||
|2018|55.0|52.7|2|
|2019|55.0|**118.5**|3|
|2020|49.0|47.0|2|
|**2021**|**96.8**|**105.3**|3|
|2022|55.3|52.7|1|
|2023|50.7|52.7|1|
|2024|42.0|42.0|1|
|**2025**|**101.3**|**93.3**|2|

Nothing happened to the Central line in October 2021 or October 2025. The
extra trains are in the feed, not on the track, and the same defect is in every
year of the series — it is simply larger in some years and on some days than
others. 2019 is the clearest warning: the weekday figure is untouched and the
**Saturday figure is more than doubled**, so a weekday-only check sees nothing
wrong.

**The cause is that TfL publishes one Underground line into TNDS as several
TransXChange files with different `ServiceCode`s and overlapping validity, each
becomes its own GTFS route, the import filter built to reconcile them is
defeated by typos in the descriptions it groups on, and `gtfs_deduplicate()` is
then structurally unable to compare what survives.** Between 3.7% and 28.6% of London Underground trip-days in each
counting window are a duplicate copy. The equivalent figure for bus never
exceeds 1.0%.

Everything below is measured, by two scripts that change nothing else.
`Rscript scripts/metro_duplicates/run_metro_duplicates.R` measures the defect
as the published feeds carry it and writes `data/metro_duplicates.Rds` — every
table in sections 1 to 5. `Rscript scripts/metro_duplicates/verify_fixes.R`
measures the fixes and writes `data/metro_fix_checks.Rds` — every table in
section 6, plus the bus-unchanged check in Fix B and the operator breakdown in
4.1. Each takes roughly half an hour, nearly all of it reading `stop_times`
out of the merged TNDS feeds.

---

## 1. What the feed holds

The October 2021 TNDS London region (`TransXChange/data_20211012/L.zip`)
contains **four Central line files**, created within 35 seconds of each other,
all `LineName = Central`, all `Mode = underground`, all operator `OId_LUL`, all
`RevisionNumber = 3`, all `Modification = "new"`:

|File|`ServiceCode`|`OperatingPeriod`|
|:---|:------------|:----------------|
|`tfl_1-CEN-_-y05-2235112.xml`|`1-CEN-_-y05-2235112`|2021-10-09 → 2021-12-23|
|`tfl_1-CEN-_-y05-2235230.xml`|`1-CEN-_-y05-2235230`|2021-10-09 → 2021-10-14|
|`tfl_1-CEN-_-y05-2506119.xml`|`1-CEN-_-y05-2506119`|2021-10-09 → 2021-12-17|
|`tfl_1-CEN-_-y05-2506121.xml`|`1-CEN-_-y05-2506121`|2021-10-15 → 2021-12-23|

The trailing number is a TfL timetable identifier. These are successive
versions of the Central line timetable, all shipped in one snapshot. Nothing in
the file marks one as superseding another: the `ServiceCode`s differ, so the
`RevisionNumber` mechanism — which only orders revisions *of the same
`ServiceCode`* — cannot connect them.

### The import filter should have caught this, and a typo stopped it

UK2GTFS already has machinery built for this exact pattern.
`txc_filter_files(resolve_overlaps = TRUE)` groups files by
`NationalOperatorCode` + `Description` + the lines they publish — precisely
because, in its own words, "Transport for London mints a new ServiceCode each
time, so the two are invisible to any check keyed on the code" — and then
closes the earlier file's operating period the day before its successor starts.
This pipeline uses it: `convert_tnds_snapshot()` converts every TNDS region
with `filter_duplicate_files = TRUE` (`R/convert.R:348`).

The identity key is compared as an exact string
(`UK2GTFS/R/txc_filter_files.R:306-318`). TfL's descriptions do not match each
other:

|Year|Surviving route|`route_desc` as published|
|---:|---:|:---|
|2019|1654|West Ruislip/Ealing Broadway - Liverpool Street - **Hainault/Woodford/Epping**|
||1659|Ealing Broadway/West **Ruilsip** - Liverpool Street - Epping/Hainault/Woodford|
||1660|Ealing Broadway/West Ruislip - Liverpool Street - Epping/Hainault/Woodford|
|2021|1656|Ealing **Broaddway**/West Ruislip - Liverpool Street - Epping/Hainault/Woodford|
||1659|Ealing Broadway/West Ruislip - Liverpool Street - Epping/Hainault/Woodford|
|2025|1952|Ealing Broadway/West Ruislip - Liverpool Street - Epping/Hainault/Woodford|
||1953|Ealing Broadway/West **Ruilsip** - Liverpool Street - Epping/Hainault/Woodford|

**Every surviving pair is separated by a typo** — "Broaddway", "Ruilsip" — or,
in 2019, by the same places listed in a different order. One transposed letter
puts a file in a group of its own, where it has nothing to overlap with.

The filter is working on the files it can group. October 2021 has four Central
line files and only three routes with any trips: within the three that spell
the description identically, one had its period closed to 9–14 October and one
was emptied entirely. The fourth — the one spelling it "Broaddway" — came
through untouched, and it is one of the two copies that double the count.

This is not a stale conversion. The grouping was added to UK2GTFS on
2026-08-02 and these feeds were built on 2026-08-04.

`transxchange2gtfs()` creates one GTFS route per `ServiceCode`, so
`gtfs/tnds_20211012_merged.zip` carries four Central line routes. Narrowed to
the dates their vehicle journeys actually run, inside the 2021 counting window
(2021-10-11 → 2021-11-07):

|`route_id`|Wednesday trips|Calendar|Live days in window|
|---:|---:|:---|---:|
|1656|1,055|2021-10-15 → 2021-11-26|24|
|1659|1,055|2021-10-15 → 2021-11-26|24|
|1657|1,055|2021-10-09 → 2021-10-14|4|
|1658|0|—|0|

**1656 and 1659 are the same line, over the same dates, with the same number of
trips.** 1657 is the superseded 9–14 October timetable and is entirely correct
— it covers the first four days of the window, which 1656 and 1659 do not.

Count Central line departures at `9400ZZLULYS1`/`YS2` (Leytonstone
Underground, both platforms) in the 15:00–17:59 band, on each of the four
Wednesdays and four Saturdays of each year's window, and the published figures
fall out:

|Year|Wednesday, by route|tph|Saturday, by route|tph|
|---:|:---|---:|:---|---:|
|2018|1939(636)|53.0|1939(640)|53.3|
|2019|1659(636)|53.0|1654(640) + 1659(640) + 1660(160)|**120.0**|
|2020|1434(480) + 1698(90)|47.5|1434(480) + 1698(90)|47.5|
|**2021**|1656(480) + 1659(480) + 1657(160)|**93.3**|1656(640) + 1659(640)|**106.7**|
|2022|1566(640)|53.3|1566(640)|53.3|
|2023|1567(596)|49.7|1567(640)|53.3|
|2024|1880(504)|42.0|1880(504)|42.0|
|**2025**|1952(596) + 1953(596)|**99.3**|1952(544) + 1953(544)|**90.7**|

These sit within a trip or two per hour of the published figures, in either
direction, for two reasons that cancel unevenly: the counted zone is the LSOA
*plus a 500 m buffer* and so picks up a little more, while a trip is counted
once per zone however many of its stops fall inside it and so a train calling
at both Leytonstone platforms is counted twice here and once there. On
Wednesdays the published `runs_Afternoon Peak` is 660 against 636 in 2018,
1,162 against 1,120 in 2021 and 1,216 against 1,192 in 2025.

The decomposition is what matters, and it is unambiguous: **wherever the line
resolves to more than one route with overlapping dates, the figure is inflated
in proportion.**

Note 2021 Wednesday. Three routes contribute, but they are not three copies:
1657 supplies the single Wednesday of 13 October on its own, and 1656 and 1659
double the other three. The result is 7 Wednesdays' worth of service counted
over 4 Wednesdays — 1.75×, and 53.3 × 1.75 = 93.3.

### Why 2019 hides on weekdays

The 2019 snapshot has two Central line routes both live across the whole
window, so it should be doubled throughout. Its weekday figure is not. The
difference is `calendar_dates.txt`: the exceptions cancel the extra copy on
weekdays and leave it on Saturdays. Expanding `calendar.txt` alone gets this
year wrong in both directions, which is why the script uses UK2GTFS's own
`service_operating_dates()` rather than a second implementation.

The practical consequence is that **this defect cannot be found by checking a
weekday**, and any future test of it has to cover all seven days.

---

## 2. Why `gtfs_deduplicate()` does not remove them

`UK2GTFS::gtfs_deduplicate()` is run on every feed this pipeline counts
(`R/frequency.R:46-57`), and it is mode-agnostic — `route_type` is part of its
route key, so metro trips are compared against metro trips exactly as buses
are. On the 2021 Underground subset it removes 467 trips of 51,702 (0.9%).
Two independent things stop it doing more.

### Cause A — an unnamed route cannot be grouped with anything

`UK2GTFS/R/gtfs_deduplicate.R:425-428`:

```r
short <- pick("route_short_name")
# an unnamed route cannot be grouped by name, so it stands alone
short[is.na(short) | !nzchar(short)] <-
  paste0("\rroute_id\r", cand$route_id[is.na(short) | !nzchar(short)])
```

This is a sound default: a route with no public number cannot be matched to
another route by name, and inventing a match would be reckless. But it means a
blank `route_short_name` is an **exemption from deduplication** — routes 1656
and 1659 are keyed on their own `route_id`s, land in different groups, and are
never compared, however identical they are.

Underground routes are unnamed because of
`UK2GTFS/R/transxchange_export.R:324-325`:

```r
routes$route_short_name <- ifelse(nchar(routes$route_short_name) > 6,
                                  gsub(" ", "", routes$route_short_name),
                                  routes$route_short_name)
routes$route_short_name[nchar(routes$route_short_name) > 6] <- "" # Remove long names to pass validation check
```

Any `LineName` longer than six characters is deleted. For bus route numbers
that is harmless. For the Underground it deletes `Central`, `Piccadilly`,
`Metropolitan`, `Bakerloo`, `Victoria`, `Northern`, `District`, `Jubilee`,
`Hammersmith & City` and `Waterloo & City`, and spares exactly one Underground
line: `Circle`, which is six characters. That is why `Circle` is the only named
Underground route in any of these feeds.

Percentage of each mode's trips sitting on a route with no
`route_short_name` — that is, exempt from deduplication — in every TNDS
snapshot this pipeline counts:

|Mode|2018|2019|2020|2021|2022|2023|2024|2025|
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
|**1 metro**|**90.5**|**92.0**|**87.9**|**93.5**|**90.6**|**93.1**|**94.8**|**93.3**|
|4 ferry|58.6|57.1|51.9|48.2|54.8|64.2|50.5|32.9|
|0 tram|20.3|58.1|45.2|28.8|21.6|25.7|49.7|67.2|
|2 rail|11.0|7.0|16.3|11.5|6.7|8.6|15.6|7.0|
|200 coach|12.4|30.6|15.3|0.5|0.5|0.7|0.5|0.0|
|**3 bus**|6.2|9.2|5.8|**0.6**|1.4|1.3|1.9|**0.6**|

Deduplication effectively does not apply to metro, in any year. It very nearly
fully applies to bus from 2021 onwards.

Bus is not perfectly clean: 6–9% of bus trips in 2018–2020 sat on unnamed
routes too, and were exempt for the same reason. It did those years little harm
— duplication among them is under 1% (section 3) — but it is the same
mechanism, and it is worth knowing that the bus series' immunity is recent
rather than structural.

### Cause B — the copies are near-identical, not identical

Force the grouping on (`match_route = "none"`, which compares itineraries
alone) and deduplication removes 28.8% of the 2021 Underground subset instead
of 0.9%. It still does not fix Leytonstone: 93.3 tph becomes **71.6**, against
a correct 53.3.

The reason is that the two copies are stopping-pattern variants of the same
trains rather than byte-identical descriptions of them. Comparing the journey
signatures of routes 1656 and 1659 — 2,880 trips each, 2,794 distinct full
signatures in 1656:

|Signature|Shared|Only in 1656|Only in 1659|
|:---|---:|---:|---:|
|Every call: stop, arrival, departure (what `gtfs_deduplicate()` compares)|1,654|1,140|1,138|
|First stop + first departure + last stop + last arrival|**2,509**|163|159|
|Stop sequence alone|53|23|23|

Pair the trips on their origin stop and departure time and the differences are
visible: one copy calls at East Acton where the other runs through, and the
intermediate times shift by a minute or two. Same train, two working
timetables — the same class of difference that
`reports/near_duplicate_journeys.md` measured on buses, and which no exact
matcher can see.

**So restoring the line names is necessary but not sufficient.** Both causes
have to be addressed.

---

## 3. How far it reaches

For each line and each date in the counting window, count the trips of every
copy that is live and treat everything above the largest single copy as
duplication. This understates — where copies differ in size it charges nothing
for the smaller ones — but it is directly comparable across modes and years.

### London Underground, by year

|Year|LU trip-days in window|Phantom|%|Lines affected|
|---:|---:|---:|---:|:---|
|2018|261,610|25,924|9.9|4 of 10|
|2019|337,030|96,504|**28.6**|8 of 10|
|2020|234,368|8,728|3.7|3 of 10|
|2021|300,476|74,999|**25.0**|7 of 10|
|2022|275,021|40,152|14.6|5 of 10|
|2023|242,538|11,447|4.7|3 of 10|
|2024|279,516|49,816|17.8|2 of 10|
|2025|286,983|49,054|17.1|7 of 12|

**No year is clean.** The best is 2020 at 3.7%, on a July snapshot carrying a
reduced pandemic timetable. The "lines" denominator is the number of distinct
`route_long_name` values with service inside that year's window, so it drifts
as TfL changes destination strings and as branches come and go; 2025 splits
into twelve rather than ten for that reason.

### By line and year

Percentage of each line's trip-days that are a duplicate copy. This is the
table that explains spikes appearing on different lines in different years:

|Line (as `route_long_name` gives it)|2018|2019|2020|2021|2022|2023|2024|2025|
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
|Ealing Broadway – Upminster (District)|19|55|19|**60**|29|25|18|12|
|Amersham – Aldgate (Metropolitan)|5|**51**|0|13|**51**|0|0|26|
|Heathrow T5 – Cockfosters (Piccadilly)|0|**50**|3|9|12|0|0|28|
|**West Ruislip – Epping (Central)**|0|24|0|**46**|0|0|0|**50**|
|Morden – High Barnet (Northern)|30|6|0|0|0|3|**50**|0|
|Barking – Barking (H&C / Circle)|0|15|17|6|15|3|0|15|
|Elephant & Castle – Harrow & Wealdstone (Bakerloo)|0|0|0|5|15|0|0|0|
|Stanmore – Stratford (Jubilee)|0|6|0|6|0|0|0|0|
|Brixton – Walthamstow Central (Victoria)|0|6|0|0|0|0|0|0|
|Waterloo – Bank (W&C)|0|0|0|0|0|0|0|9|

(The two extra name variants that appear in 2025 only — "Elephant & Castle –
Queen's Park" and "Hammersmith (H&C and Circle Lines) – Upminster" — sit at 0%
and 3% and are omitted.)

The Central line rows at 46 and 50 are the Leytonstone spikes. The District
line is affected in every single year. Anyone reading a metro trend for an LSOA
on the Metropolitan line will see a jump in 2019 and 2022; on the Northern
line, in 2024; on the Piccadilly line, in 2019 and 2025.

### By mode — why the bus work never found this

Same measure, all modes and all years — percentage of trip-days that are a
duplicate copy:

|Mode|2018|2019|2020|2021|2022|2023|2024|2025|
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
|**1 metro**|**9.5**|**27.7**|**3.6**|**22.8**|**13.3**|**4.3**|**16.6**|**15.8**|
|2 rail|4.0|4.5|0.0|5.0|7.5|0.0|0.0|14.3|
|4 ferry|0.8|0.3|0.0|0.2|0.0|0.0|0.0|0.0|
|**3 bus**|**0.7**|**0.7**|**1.0**|**0.2**|**0.9**|**0.4**|**0.6**|**0.3**|
|0 tram|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|
|200 coach|0.0|0.0|0.0|0.0|0.0|0.3|0.0|0.0|

The metro row here covers every metro operator — London Underground, Nexus and
the Gatwick inter-terminal shuttle — which is why it sits below the
Underground-only figures in the table above.

Two rows in that table were left unexplained when it was written, and section
6.2 now explains both. The **rail** row is not heavy rail: every phantom rail
trip-day in all eight years is the Docklands Light Railway, which TNDS files
as `route_type = 2` — so it is this same defect, same publisher, under a
different mode. The **tram** row of zeroes is real but not permanent: the
February 2026 snapshot shows 2.7%, so tram is exposed in the same way and
simply happened to be clean in these eight snapshots.

Bus is one to two orders of magnitude cleaner than metro, and every piece of
validation work this repo has done is bus-only by construction:

- `R/comparison.R:212`, `R/lsoa_gap.R:43` and `R/route_match.R:169` all filter
  to `route_type == 3` before doing anything.
- `reports/near_duplicate_journeys.md:188-213` proposes a near-duplicate rule
  whose sixth condition is "Buses only", explicitly excluding the Underground,
  the trams and the DLR — on the correct grounds that a *time tolerance* cannot
  distinguish a duplicate registration from the next train. That report was
  right to exclude them from that rule, and the exclusion has meant nobody
  looked at metro since.
- Every PDF validation is against bus running schedules
  (`reports/route_279_pdf_validation.md`, `reports/route_validation_69_A1_142.md`).
- `README.md:315` already says "mode composition is only trustworthy for bus".
  This report is the measurement behind that sentence.

---

## 4. Two more metro defects found on the way

### 4.1 Metro is counted from two feeds at once, 2018–2025

`run_year()` (`R/frequency.R:111-117`) counts the bus feed and the rail feed
separately and adds them by `zone_id × route_type`. `drop_route_types` is only
ever set to `200`, for coach. The comment at `R/config.R:64-69` states the rule
this relies on:

> Only ever list more than one `bus` feed for a year when the feeds cover
> *disjoint* parts of the network. `sum_feeds()` adds their counts […] nothing
> downstream can tell that two feeds describe the same journey.

The bus/rail pair is assumed disjoint. `README.md:295` records the assumption
explicitly — that London Underground is not in the CIF feed and metro coverage
depends on TNDS. **It is in the CIF feed, in every year:**

|Year|Rail feed|Agency `LT` routes|Trips|
|---:|:---|---:|---:|
|2018|`rail_atoc_2018-10-16.zip`|41|4,009|
|2019|`rail_atoc_2019-08-31.zip`|30|2,721|
|2020|`rail_atoc_2020-11-26.zip`|49|5,798|
|2021|`rail_atoc_2021-10-09.zip`|41|1,901|
|2022|`rail_atoc_2022-11-02.zip`|42|4,604|
|2023|`rail_atoc_2023-11-01.zip`|32|4,297|
|2024|`rail_atoc_2024-10-05.zip`|36|5,723|
|2025|`rail_rdp_20251006.zip`|31|6,092|

In 2024 those 5,723 trips call at 25 stations, every one with valid
coordinates. Agency `TW`, "Tyne & Wear Metro", accounts for the other 22 of the
feed's 47 metro stops on the same footing, and it is not incidental — the CIF
feed carries between 936 and 1,410 Tyne and Wear trips in **every** year:

|Year|2018|2019|2020|2021|2022|2023|2024|2025|
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
|`LT` London Underground|4,009|2,721|5,798|1,901|4,604|4,297|5,723|6,092|
|`TW` Tyne and Wear Metro|1,410|1,011|1,400|967|936|975|976|966|

So the double count is of both networks, not one. TNDS carries both in full and
carries more of each — 62,419 `LUL` and 1,400 `NXMT` trips in the 2024 snapshot
against 5,723 and 976 in the CIF — which is why TNDS is the copy kept. Two
strays make up the remainder of the feed's metro: one London Midland route in
2022 and one Great Northern route in 2024, of **one trip each**, which Fix D
drops along with the rest. That is the whole cost of the fix on the heavy-rail
side, and it is not measurable.

The London Underground stations are the sections the network shares with, or
interfaces with, the national railway:

|Section|Stations in the CIF feed|
|:---|:---|
|Bakerloo, Queen's Park – Harrow & Wealdstone|Queens Park, Kensal Green, Willesden Junction LL, Harlesden, Stonebridge Park, Wembley Central, North Wembley, South Kenton, Kenton, Harrow & Wealdstone|
|District, Richmond branch|Richmond NLL, Kew Gardens, Gunnersbury, Turnham Green|
|District, east|Barking, Dagenham East, Upminster|
|Other|Earls Court, Barons Court, Hammersmith, Kensington High Street, Tower Hill, Elephant & Castle, Paddington Bakerloo, London Road Depot|

The stop ids cannot collide — TIPLOC here (`HROWDC`, `GNRSBRY`) against ATCO in
TNDS (`9400ZZLU…`) — so no deduplication could ever match them, but the join to
zones is spatial, so what matters is that the coordinates put them in the same
LSOA. **The service at those 25 stations is added twice in the metro totals for
every year from 2018 to 2025.** This is the same class of error as the 2024/25
bus double-count fixed in `61ae149`.

It is small next to the duplicate-copy defect — 5,723 trips against 62,419
Underground trips in the 2024 TNDS feed — and it is not the cause of the Leytonstone
spike, which is not one of the 25. But it is a real, separate inflation, and it
is concentrated exactly on the interchange stations where an accessibility
measure matters most.

### 4.2 The metro series has era breaks that make it non-comparable

Not a bug in the counting, but anyone plotting metro over time needs it. From
reading the converted feeds:

|Years|What the metro series actually is|
|:---|:---|
|2004|London Underground is present but coded `route_type = 3` — **it is inside the bus totals**. `nptdr.R:778-784` converts with `clean_route_type(guess_bus = TRUE)`, so an unrecognised vehicle type becomes bus. The metro figures for this year are trams.|
|2005–2006|No London Underground and no DLR at all. Metro is trams only.|
|2007–2011|Full: LUL as metro, and **DLR as metro** (`route_type = 1`), plus tram operators.|
|2014–2017|Mostly Tyne & Wear and the Glasgow Subway: 172 zones and ~2,500 total tph against ~80,000 either side, and E01004440 has no metro row in any of these years. But **2016 is not empty of London Underground** — it carries 66 LUL routes and 6,778 trips, and 2017 carries a vestigial 4 routes and 8 trips. Those trips were previously counted as **bus**; the reattribution is exact, bus falling by the same 6,778. Only one stop in the 2016 archive is named "Underground Station", so the stop-name rules cannot see it — the operator-code rule on agency `LUL` is what finds it. The same Glasgow Subway service is also described as 64 routes in 2014, 128 in 2015 and 4 in 2016 and 2017, with 2014 holding half the journeys of the other three years.|
|2018–2025|LUL as metro; **DLR as rail** (`route_type = 2`) — the opposite of 2007–2011.|

So the metro series has a near-total hole in 2014–2017, a mode
reclassification of the DLR at 2011/2018, and a mode misclassification of the
Underground in 2004. A 2004–2025 metro trend built from these files measures
the sources, not the service.

The 2014–2017 entry above was corrected in September 2026 and then corrected
back. The original statement — that the Bus Archive carries no London
Underground whatsoever — is right. The intervening version claimed 2016 and 2017
carry 66 and 4 Underground routes; those routes exist and were indeed moved out
of the bus totals, but agency `LUL` in the Bus Archive is **Lancashire United
Ltd**, and they are buses around Preston and Burnley. The bus total falling by
exactly as much as metro rose was read as confirmation, when it was the
symptom. Both readings were checked against the same operator code and neither
looked at the operator's name until later.

The unevenness in how the Glasgow Subway is described across the same four
years turned out not to be an archive quirk either: the Subway, the DLR and
Sheffield Supertram are published twice from 2015 to 2023, once against
station-level NAPTAN codes and once against platform codes, so every train is
counted twice.

Two of those three are now closed by Fix F, which gives every source one set
of mode rules: the DLR is metro in both eras, and the 2004 Underground is out
of the bus totals. The 2014–2017 hole is a gap in the Bus Archive itself and
cannot be closed – it is documented in `README.md` and accepted. The table
above therefore describes the feeds **as they were read for this report**,
before Fix F; a feed reconverted with the current package carries different
`route_type`s, and section 5's Fix F table says exactly which.

`README.md:295` and `:297` (the CIF claim) and `README.md:144-145`, `:296` and
`:302` (which still describe 2024/25 bus as "BODS GTFS + TNDS", changed in
`61ae149`) are all stale and should be corrected alongside.

---

## 5. How to fix it

### Fix A — stop deleting long line names — **done**

Implemented in UK2GTFS on branch `keep-long-line-names` (`9946294`). The rule
moved to `clean_route_short_name()` next to `clean_route_type()`, with a unit
test; the blanking is gone and the abbreviations and space removal are
unchanged, so no route that already carried a name gets a different one. The
converted feeds still have to be rebuilt for it to reach any output.

`UK2GTFS/R/transxchange_export.R:324-325`. The truncation existed "to pass
validation check", but the GTFS specification sets no length limit on
`route_short_name`; the relevant guidance is a best-practice note that short
names *should* be short, and it is advisory. Keep the `LineName` as published,
or at minimum keep it when the mode is not bus.

This restores route identity for metro, tram and ferry — the three modes where
most trips currently sit on unnamed routes — and it is a prerequisite for any
name-based grouping. On its own it moves Leytonstone 2021 from 93.3 to about
71.6 tph. It does not finish the job.

Note that changing this changes `route_short_name` in every converted feed, so
it invalidates every conversion. It is a rebuild-the-world change and should go
in with anything else that touches conversion.

### Fix B — a duplicate rule for fixed-track modes — **done**

Implemented as `gtfs_deduplicate(fixed_track = c(0, 1, 2))` on UK2GTFS branch
`fixed-track-duplicates`, with six tests. Two trips of the same operator and
line that leave the same terminus at the same minute of the same day and reach
the same terminus at the same minute are the same train. On fixed track that is
physically guaranteed in a way it is not on a road, so the journey signature is
relaxed from *every call* to *the two termini and their times*. Buses are not in
the default: a bus route's own vehicles do run a minute apart, and the same
relaxation there would delete real service.

Everything else is unchanged — the route grouping, the trip attributes, and
above all the operating-date test, so nothing is removed that would leave a
date with less service. A trip with no time at one of its ends is not relaxed,
because it has nothing to be relaxed to.

Measured on the Underground at Leytonstone, with `route_short_name` restored as
Fix A now restores it, at each stage:

|Year|LU trips|After exact|After fixed track|Wed tph: published → exact → fixed track|Sat tph|
|---:|---:|---:|---:|:---|:---|
|2018|82,612|80,841|80,510|53.0 → 53.0 → 53.0|53.3 → 53.3 → 53.3|
|2019|85,854|68,380|62,807|53.0 → 53.0 → 53.0|120.0 → 55.3 → **54.3**|
|2020|66,019|65,683|65,504|47.5 → 47.5 → 47.5|47.5 → 47.5 → 47.5|
|**2021**|51,702|36,800|34,434|93.3 → 71.6 → **55.1**|106.7 → 78.0 → **59.0**|
|2022|71,020|41,823|41,032|53.3 → 53.3 → 53.3|53.3 → 53.3 → 53.3|
|2023|79,150|47,590|46,658|49.7 → 49.7 → 49.7|53.3 → 53.3 → 53.3|
|2024|62,419|41,950|38,639|42.0 → 42.0 → 42.0|42.0 → 42.0 → 42.0|
|**2025**|64,387|46,922|43,483|99.3 → 99.3 → **57.7**|90.7 → 90.7 → **48.7**|

Three things to read out of that table.

**Fix A does most of the work.** Restoring the line names lets the *exact* test
see duplicates it could never reach before — 41% of Underground trips in 2022,
33% in 2024. The relaxation adds between 0.3% and 6.5% on top.

**Fix B does the decisive part.** In 2025 the exact test removes 27% of
Underground trips nationally and *nothing at all* at Leytonstone: the two
Central line copies differ at a call, so 99.3 tph stays 99.3. Only the relaxed
signature reaches them. 2021 gets two thirds of the way on Fix A and the rest
on Fix B.

**The five unaffected years are the control.** In 2018, 2020, 2022, 2023 and
2024 the rule fires elsewhere on the network and leaves Leytonstone at exactly
the figure it started on, on both days.

**Bus behaviour is unchanged, measured rather than argued.** The verification
this section originally promised has been run: `gtfs_deduplicate()` on four
converted feeds with `fixed_track = c(0, 1, 2)` against `fixed_track =
integer(0)`, which is exactly the old behaviour.

|Feed|Bus trips|Removed, old|Removed, new|Only old|Only new|
|:---|---:|---:|---:|---:|---:|
|`tnds_20211012/L`|379,271|2,209|2,209|0|0|
|`tnds_20241004/L`|390,650|2,469|2,469|0|0|
|`tnds_20241004/NW`|103,500|172|172|0|0|
|`tnds_20251003/L`|375,713|238|238|0|0|

Identical trip-for-trip on 1.25 million bus trips, and on ferry too. `Only old`
is zero on every mode in every feed, so the relaxation is strictly additive: it
never stops removing something the old rule removed. The reason is structural —
the route grouping key contains `route_type`, so a bus can never share a group
with a fixed-track route — but it is now checked as well as reasoned.

**The residual is the date test refusing to overreach, not an error.**
Decomposing what survives at Leytonstone:

|Year|Day|Route|Kept|Dropped|
|---:|:---|---:|---:|---:|
|2021|Sat|1656|640|0|
|2021|Sat|1659|68|572|
|2025|Sat|1952|544|0|
|2025|Sat|1953|40|504|

In each year the surviving primary copy is *exactly* right on its own — 640
departures is 53.3 tph, the single-copy baseline — and the excess is a handful
of trips in the second copy that the **unchanged operating-date test** declines
to remove, because each runs on a date the kept copy does not cover. Removing
them would leave those dates with less service than the feed claims, which is
the one thing `gtfs_deduplicate()` is built never to do. The residual is
therefore Fix B being deliberately conservative, and it is 5.7 tph in 2021 and
3.3 tph in 2025.

2025 Saturday landing *below* the 53.3 baseline is not a residual at all: route
1952's own Saturday timetable is 544 departures, 45.3 tph. The July 2026 TNDS
snapshot, which carries no Central line duplication whatever, gives Leytonstone
the same 544 departures and the same 45.3 tph. The Saturday service really did
thin; the 53.3 baseline had stopped applying.

**The removal rate was never larger than the defect — that was a denominator
error.** This section originally cautioned that the rule removed more trips than
the phantom estimate and that this needed explaining before adoption. It does
not. "Trips removed" counts rows in `trips.txt`; "phantom" counts trip-*days*
inside the counting window. On one denominator:

|Year|Removed, % of trips|Removed, % of trip-days|Phantom estimate|
|---:|---:|---:|---:|
|2018|2.0|**0.9**|9.9|
|2019|29.2|**17.2**|28.6|
|2020|0.6|**0.1**|3.7|
|2021|35.7|**20.3**|25.0|
|2022|28.1|**9.1**|14.6|
|2023|14.1|**2.1**|4.7|
|2024|16.9|**15.5**|17.8|
|2025|33.8|**13.7**|17.1|

The rule removes **less than the phantom estimate in every one of the eight
years**. Duplicate copies carry short calendars, so they weigh far less in
trip-days than in trips, and the date test then declines some of them outright.
The caution is resolved, in the conservative direction.

### Fix C — make the import filter's identity key survive a typo — **done**

Implemented in `txc_filter_files()` on UK2GTFS branch `fixed-track-duplicates`
(`e3088e4`), both parts below, with four tests. On the four October 2021
Central line files it now yields three non-overlapping periods (9–14 Oct,
15 Oct–17 Dec, 18–23 Dec) where before two full copies of the line survived
across the counting window.

**This was the cheapest fix and the one that should have come first.** Section 1 shows
that `txc_filter_files()` already resolves exactly these overlaps and is
defeated by one transposed letter in the `Description` it groups on. Removing
the copies at import is better than removing them afterwards: it keeps the
version actually in force on each date, it works on declared identity rather
than on journey times, and it needs no relaxation of what "the same journey"
means.

Two changes, in increasing order of ambition:

1. **Normalise the `Description` before keying on it** — case, punctuation and
   runs of whitespace — and treat two descriptions as one when they are the
   same multiset of place names in a different order. That alone would have
   grouped all three years' Central line files. It is the same problem
   `operator_key()` solved for agency names in `gtfs_deduplicate.R:193`, and
   the same shape of answer.
2. **Fall back to a looser key when the description is unreliable.** For an
   operator publishing one line under one `LineName`, `NationalOperatorCode` +
   `LineName` identifies the service without the description at all. The
   description exists in the key to separate "line 436 in London from line 436
   in Hereford", which is a bus problem; a rail or metro operator running a
   named line does not need it.

Either change is confined to `txc_filter_files()`, is testable against the four
October 2021 Central line files directly, and cannot affect a feed whose
descriptions already agree.

### Fix C2 — carry the TransXChange `ServiceCode` into the GTFS — **done**

Implemented in `transxchange_export()` (`e3088e4`): every route's `route_desc`
now ends with a `[ServiceCode: ...]` suffix, appended after the existing step
that blanks a description identical to the route's long name.

Writing the `ServiceCode` into the GTFS — `routes.route_desc`, or a
non-standard column — would let copies of one line be identified explicitly in
the converted feed rather than inferred from names and times, and would make
Fixes A and B verifiable rather than plausible. It is worth doing whatever
happens to Fix C, because it is what lets anyone check afterwards which
published file a route came from.

### Fix D — stop summing metro from two feeds — **done**

`drop_route_types = 1` is now set on every rail feed in `year_sources()`
(`R/config.R`), 2018–2025, using the mechanism already there for coach and
applied in `R/frequency.R:77-82`. TNDS is the source kept: it carries the whole
of both the Underground and the Tyne and Wear Metro, where the CIF feed carries
only the sections shared with the national railway. Checked before making the
change — Nexus is in the TNDS feed in every year from 2018 to 2025, so no
metro is lost by dropping it from the rail side.

### Fix E — say what the metro series is — **done**

`README.md` gains a "The metro series has era breaks" table covering all three
eras, and the stale claims are corrected: the source table said the Underground
was not in the CIF feed, and both it and the window table still described
2024/25 bus as "BODS GTFS + TNDS", which stopped being true in `61ae149`.

The 2014–2017 London gap is documented and accepted rather than suppressed,
on the grounds that it is a known hole in the Bus Archive rather than something
this pipeline can repair.

### Fix F — sort the NPTDR trams from the metros — **done**

Not in the original list, and needed once the era breaks were written down.
`nptdr2gtfs()` now reclassifies light rail from the NaPTAN names of the stops
each route serves (`UK2GTFS::standard_mode_overrides()`), because NPTDR's "METRO"
vehicle type is a catch-all — it covers the Underground, the Glasgow Subway,
every British tramway, the airport people movers and a long tail of heritage
railways alike — and its operator codes are not stable between archives:
Manchester Metrolink appears as 1973, 1976, 2001, 2016 and 2024 in successive
years, and some of those codes carry ordinary bus routes as well.

A route is reassigned only where at least 80% of its stops belong to one
system, a threshold a bus passing a tram stop never reaches, and `LUL` is
matched on its operator code as well because it runs nothing else and not all
its stop names are marked. Measured on the archives: **78 London Underground
routes move out of the bus totals in 2004, but they carry only 596 trips**
(see 6.5 — the 2004 archive barely holds the Underground at all), and Manchester Metrolink, Midland
Metro, Sheffield Supertram, Nottingham Express Transit, Croydon Tramlink and
the Blackpool Tramway all move from metro to tram across 2004–2011 —
including Sheffield Supertram, which the source files as a *bus* in most years.

One set of rules is now applied to **every** source — TransXChange (TNDS,
BODS), NPTDR and the rail CIF — so that a `route_type` means the same thing
whichever feed a year came from:

|Category|`route_type`|Systems|
|:---|:---|:---|
|Heritage and minor railways|**rail (2)**|Bluebell, Swanage, Strathspey, Spa Valley, Ravenglass and Eskdale, South Devon, Paignton and Dartmouth, Bo'ness and Kinneil, Keith and Dufftown, Leadhills and Wanlockhead, Mull, South Tynedale, Lakeside and Haverthwaite, Weardale, Romney Hythe and Dymchurch|
|Metro|**metro (1)**|London Underground, Tyne and Wear Metro, Glasgow Subway, Docklands Light Railway|
|Airport links|**tram (0)**|Birmingham Air-Rail Link, Gatwick inter-terminal shuttle, Luton DART|
|Tramways|**tram (0)**|Manchester Metrolink, Midland/West Midlands Metro, Sheffield Supertram, Nottingham Express Transit, Croydon Tramlink, Blackpool Tramway, Edinburgh Trams|
|Aerial cable car|**gondola (6)**|London Cable Car (`CAB`, formerly Emirates Air Line, `EAL`)|

The sources needed it in different places. Measured on the feeds:

|Source|What changes|
|:---|:---|
|TNDS 2018|DLR 2–>1 (10,235 trips), Glasgow Subway 0–>1 (992), four heritage railways 0–>2|
|TNDS 2021|DLR 2–>1 (6,375), Glasgow Subway 0–>1 (1,740), Gatwick 1–>0 (492), Emirates Air Line 2–>6 (834), two heritage railways–>2|
|TNDS 2025|DLR 2–>1 (14,683), Luton DART 2–>0 (1,760), London Cable Car 2–>6 (1,016), Glasgow Subway 0–>1 (870), Gatwick 1–>0 (492), four heritage railways–>2|
|NPTDR 2004–2011|78 Underground routes out of **bus** in 2004, but only 596 trips (see 6.5); six tramways and both people movers to tram; the DLR stays metro; eleven heritage railways to rail|
|Rail CIF|nothing — it carries only the Underground and the Tyne and Wear Metro, both already metro|
|BODS Coach|nothing|

Six systems cannot be recognised from their stop names and are matched on
their operator code instead: `LUL`, because not all Underground stop names are
marked ("Wembley Park" carries no suffix); `BHX`, because the Air-Rail Link has
two stops and one of them is a mainline station; `WRLY`, the Weardale Railway,
whose stops are named as ordinary rail stations; `DART`, the Luton DART, whose
two stops are "Luton Airport DART Station" and "Luton Airport Parkway Rail
Station", so only half of them name the system and the 80% threshold can never
be met; and `CAB` and `EAL`, the London cable car, whose stops are called
"Greenwich Peninsula" and "Royal Docks" and name nothing at all.

**Luton DART and the cable car were found after the rest of this section was
written**, by asking what else TNDS files as heavy rail. The answer, in the
October 2025 snapshot, is the DLR (14,683 trips), the Luton DART (1,760), the
London Cable Car (1,016) and six heritage railways. The DART is an airport
people mover exactly like the Birmingham and Gatwick shuttles, so the agreed
rule makes it a tram. The cable car is the one system the agreed rules do not
describe - it is not an airport link, a tramway, a metro or a railway - and it
takes the GTFS mode that fits, aerial lift (6). Both were sitting in the
**rail** totals in every year they appear. The cable car needs two rows because
its operator code follows its sponsor: `EAL` in 2018 and 2021, `CAB` from 2023.
Neither can be caught by stop name, and the near-misses matter - `DHF`
(Dartmouth Higher Ferry), `DP` (Dartmouth Steam Railway), `DT` (Dartline
Coaches) and `EASD` (Essex & Suffolk DaRT) all sit in the same feeds and none
of them moves. Measured: `EAL` 2 to 6 (834 trips) in 2021; `DART` 2 to 0
(1,760) and `CAB` 2 to 6 (1,016) in 2025.

Nothing else is reclassified. A route moves only when at least 80% of the stops
it calls at belong to one system, so a bus passing a tram stop is untouched,
and across every feed tested not one bus operator changed mode. The Dartmouth
Steam Railway keeps its ferry routes as ferries and its bus route as a bus
while its railway becomes rail, which is the case that shows why the rule keys
on stops rather than on operators.

---

## 6. What was checked afterwards, and what is still not known

Everything in this section was open when the fixes were written. Most of it has
since been measured; what remains is listed at the end.

### 6.1 The spikes are now falsified externally, not just internally

The original claim here was that no Underground frequency in this pipeline had
ever been checked against anything outside it, so ~53 tph was inference. That is
still true of the *baseline*. It is no longer true of the *spikes*.

Splitting the Leytonstone count by platform separates the two directions
— the two stops are the eastbound and westbound platforms of one station, and
they agree to within 1 tph in every year, which is itself a check that nothing
is being double-counted on one side only:

|Year|`9400ZZLULYS1`|`9400ZZLULYS2`|Copies|
|---:|---:|---:|:---|
|2018|26.3|26.7|one|
|2019|26.3|26.7|one (Wed)|
|2020|23.5|24.0|one|
|**2021**|**46.1**|**47.2**|two|
|2022|26.3|27.0|one|
|2023|24.3|25.3|one|
|2024|21.0|21.0|one|
|**2025**|**48.7**|**50.7**|two|

The Central line runs 27–34 tph in one direction in the peak, and 34 tph is the
most it has ever achieved; Leytonstone is where the eastern branches diverge, so
it sees the full core service. The single-copy years land at 21–27 tph per
direction, inside that range. The spike years demand **46–51 tph per
direction** — above anything the line has ever signalled, and in 2021 on a
pandemic-reduced timetable. That is physically impossible, so the spikes are
refuted rather than merely suspected.

What this does **not** establish is that 53.3 is the right answer. It is
consistent with the published service, corroborated by the 2007–2011 NPTDR
series at 53.7 from an entirely different source and format, and it is what the
single-copy years give — but it has not been checked departure by departure
against a working TfL timetable the way the 279, the 69, the A1 and the 142
were. That remains the honest limit: this report establishes which years are
*inflated*, and now that the inflated figures are *impossible*, but not that the
clean years are exactly right.

2024 is a single copy and sits at 42.0 rather than 53. On the evidence here that
is a real timetable difference, not a defect.

### 6.2 Tram and rail: answered, and the rail answer was the same defect

Both were listed as uninvestigated. Measured across all eight years:

**Tram has no duplication at all** — zero phantom trip-days in every year
2018–2025, despite two thirds of 2025 tram trips sitting on unnamed routes. The
exposure to Cause A is real; nothing is actually duplicated. That is not a
permanent property: the February 2026 snapshot shows 2.7% tram phantom
trip-days, so the eight zeroes are the snapshots this report happened to use,
not immunity.

**Every phantom rail trip-day in TNDS is the Docklands Light Railway.** One
line, "Bank – Lewisham", in all eight years:

|Year|2018|2019|2020|2021|2022|2023|2024|2025|
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
|DLR phantom trip-days, %|4.9|5.2|0|6.0|8.6|0|0|**19.8**|

There is no heavy-rail duplication in TNDS whatsoever. TNDS carries almost no
heavy rail — in the October 2025 snapshot `route_type = 2` is the DLR (14,683
trips), the Luton DART (1,760), the London Cable Car (1,016) and six heritage
railways — which is why the DLR dominates the mode. So this was never a second
defect: it is the same publisher, the same mechanism and the same fix, wearing a
different `route_type`. Fix F now files the DLR as metro, so from the next
reconversion the number leaves the rail series and joins the metro one.

### 6.3 The duplication is a property of the snapshot, not of the year

This was open because every figure here is measured on the one 28-day window
each year uses. The repo holds two TNDS snapshots of 2026, five months apart,
which settles it:

|Line|Feb 2026|Jul 2026|
|:---|---:|---:|
|Ealing Broadway – Upminster (District)|19.5%|**34.8%**|
|Amersham – Aldgate (Metropolitan)|30.9%|29.9%|
|Morden – High Barnet (Northern)|19.2%|**0%**|
|Heathrow T5 – Cockfosters (Piccadilly)|20.0%|6.7%|
|West Ruislip – Epping (Central)|11.7%|**0%**|
|**London Underground overall**|**12.6%**, 8 of 13 lines|**9.3%**, 3 of 12 lines|
|Leytonstone, Saturday|54.2 tph|45.3 tph|

Only the Metropolitan is duplicated in both. Two snapshots of the same year
differ by 9 tph at the same station. **The per-line table in section 3 therefore
describes the snapshot, not the year**, and the sentence "the spikes land on
different lines in different years" should be read as "on different lines in
different snapshots" — which is a stronger statement of the same point, because
it means nothing about the real timetable is driving which line is affected.

### 6.4 The downstream effect, bounded

`../build` folds coach into bus and passes metro through unchanged
(`build/R/public_transport_frequency.R:64-66`), so these figures reach the
published outputs as they are. From the published outputs themselves:

* metro appears in **1,409–1,458 LSOAs** out of ~42,900, i.e. 3.4% of zones
* metro is **5.7–7.3%** of national afternoon-peak tph, 2018–2025

Combining that share with the phantom rates puts the national all-mode
overcount at roughly **1–2% of afternoon-peak tph** in the worst years (2019
— 1.9%, 2021 — 1.7%). Small nationally; concentrated locally. On the 1,440
metro zones the metro figure itself is inflated by up to 28%, and at an
individual station by up to 90%. The same table shows the 2014–2017 hole
plainly: 172 zones and ~2,500 tph against ~1,430 zones and ~80,000 either side.

This is an upper-bound estimate from the inflation rates, not a measured
before-and-after. The measured figure needs the rebuild below.

### 6.5 The 2004 Underground correction is real but negligible

This report claimed Fix F moves "87 London Underground routes out of the bus
totals in 2004", which reads as though it repairs the 2004 metro series. It
does not, and the rebuild showed why.

|Archive|Stops named as Underground stations|`LUL` routes|`LUL` trips|
|:---|---:|---:|---:|
|NPTDR 2004|**5**|78|**596**|
|NPTDR 2010|507|838|24,177|
|NPTDR 2011|510|971|29,210|

78 routes did move, so the claim is literally true, but they carry 596 trips
against 24,177 in 2010. National metro for 2004 rose by 63 tph (1.4%) and bus
fell by 48. **The 2004 NPTDR archive barely contains the London Underground at
all**, and the stop-name rule cannot reach what is not there; the operator
code is what caught these 78. So the era-break table in 4.2 stands as written:
the 2004 metro figures are still essentially trams, before and after Fix F.

Only the size of the correction was overstated; the direction and the
mechanism were right.

### 6.6 What is still not known

* **A like-for-like Underground validation.** One line, one station, one
  published TfL timetable, compared departure by departure. 6.1 rules the spikes
  out but does not rule the baseline in.
* **The measured downstream effect.** 6.4 bounds it; only a reconversion gives
  the real number.
* **Whether the fixes interact at national scale.** Fixes A, B, C and F have
  each been measured alone, and on regional feeds together, but no national feed
  has been converted end to end with all of them.
* **Nothing in any output has changed yet.** Every feed in `gtfs/` predates all
  seven fixes. Until a full reconversion runs, this report describes the defect
  and the remedy, not the numbers the pipeline currently publishes.
