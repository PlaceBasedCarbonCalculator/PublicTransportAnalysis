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
becomes its own GTFS route, and `gtfs_deduplicate()` is structurally unable to
compare them.** Between 3.7% and 28.6% of London Underground trip-days in each
counting window are a duplicate copy. The equivalent figure for bus never
exceeds 1.0%.

Everything below is measured.
`Rscript scripts/metro_duplicates/run_metro_duplicates.R` regenerates every
table in this report and saves them to `data/metro_duplicates.Rds`. It takes
about forty minutes, nearly all of it reading `stop_times` out of the eight
merged TNDS feeds, and it changes nothing else.

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
coordinates. Agency `TW`, "Tyne & Wear Metro" (976 trips), and one stray Great
Northern route account for the other 22 of the feed's 47 metro stops, on the
same footing.

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
|2014–2017|Bus Archive carries **no London Underground whatsoever**. The metro series is Tyne & Wear only: 172 zones and ~2,500 total tph against ~80,000 either side. E01004440 has no metro row in these years at all.|
|2018–2025|LUL as metro; **DLR as rail** (`route_type = 2`) — the opposite of 2007–2011.|

So the metro series has a 97% hole in 2014–2017, a mode reclassification of the
DLR at 2011/2018, and a mode misclassification of the Underground in 2004. A
2004–2025 metro trend built from these files measures the sources, not the
service.

`README.md:295` and `:297` (the CIF claim) and `README.md:144-145`, `:296` and
`:302` (which still describe 2024/25 bus as "BODS GTFS + TNDS", changed in
`61ae149`) are all stale and should be corrected alongside.

---

## 5. How to fix it

### Fix A — stop deleting long line names

`UK2GTFS/R/transxchange_export.R:324-325`. The truncation exists "to pass
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

### Fix B — a duplicate rule for fixed-track modes

Two trips of the same operator and line that leave the same first stop at the
same time on the same date are the same train. On a metro or heavy rail line
that is physically guaranteed in a way it is not on a road, so the journey
signature can be relaxed from *every call* to *the two termini and their times*
without the risk that makes a time tolerance unsafe for buses.

The prototype in `scripts/metro_duplicates/metro_duplicates.R`
(`fixed_track_duplicates()`) groups on operator plus normalised
`route_long_name`, signs each trip with
`(first stop_id, first departure_time, last stop_id, last arrival_time)`, and
leaves `gtfs_deduplicate()`'s date test completely unchanged — copies are
ranked most-used-calendar first, and one is removed only where every date it
runs is also run by a copy that is kept. The superseded timetable covering the
first days of a window is therefore never removed.

Measured on the Underground, at Leytonstone:

|Year|LU trips in feed|Removed|%|Wed tph before → after|Sat tph before → after|
|---:|---:|---:|---:|:---|:---|
|2018|82,612|1,464|1.8|53.0 → 53.0|53.3 → 53.3|
|2019|85,854|19,750|23.0|53.0 → 53.0|120.0 → **54.3**|
|2020|66,019|317|0.5|47.5 → 47.5|47.5 → 47.5|
|**2021**|51,702|16,891|32.7|93.3 → **55.1**|106.7 → **59.0**|
|2022|71,020|13,306|18.7|53.3 → 53.3|53.3 → 53.3|
|2023|79,150|5,013|6.3|49.7 → 49.7|53.3 → 53.3|
|2024|62,419|6,139|9.8|42.0 → 42.0|42.0 → 42.0|
|**2025**|64,387|20,147|31.3|99.3 → **57.7**|90.7 → **48.7**|

**The five unaffected years are the control.** In 2018, 2020, 2022, 2023 and
2024 the rule fires elsewhere on the network — 18.7% of Underground trips in
2022 — and leaves Leytonstone at exactly the figure it started on, on both
days. The two spike years land back on the 50s where the single-copy years sit.

It does not land exactly. Against a single-copy baseline of 53.3 on both days,
2021 Saturday comes out 11% high and 2025 Saturday 9% low. That is a residual
worth understanding before this is trusted, not a rounding error.

Three cautions before this is adopted:

1. The "removed" column counts trips in the whole feed, while section 3's
   phantom percentages count trip-days inside the 28-day window. They are not
   the same denominator and should not be read against each other: 2021 is
   32.7% here against 25.0% there, 2019 23.0% against 28.6%. The two ought to
   be put on one footing before either is quoted as the size of the problem.
2. It should be gated behind a new `gtfs_deduplicate()` argument and applied to
   `route_type` 0, 1 and 2 only, so bus behaviour is provably unchanged. The
   verification for that is a trip-for-trip comparison of bus removals on
   `tnds_20241004_merged.zip` before and after.
3. Grouping on `route_long_name` is a stand-in for line identity and a poor
   one — it is the origin and destination strings, which drift between
   snapshots and are shared by branches. With Fix A the `route_short_name`
   would carry the line name properly, and with Fix C the `ServiceCode` would
   carry it exactly; either is a better key than this.

### Fix C — carry the TransXChange `ServiceCode` into the GTFS

The root cause is that four files describing one line arrive with no marker
saying they are versions of each other. Writing the `ServiceCode` into the GTFS
— `routes.route_desc`, or a non-standard column — would let copies of one line
be identified explicitly rather than inferred from names and times, and would
make Fixes A and B verifiable rather than plausible. It would also open the
better long-term option: resolving the supersession at import, keeping the
version actually in force on each date, instead of removing duplicates after
the fact.

### Fix D — stop summing metro from two feeds

Add `drop_route_types = 1` to the rail feed in `year_sources()`
(`R/config.R:120-180`) for 2018–2025, using the mechanism already there for
coach at `:167` and `:177` and applied in `R/frequency.R:77-82`. TNDS is the
source to keep: it carries the whole Underground, where the CIF feed carries 25
stations of it. Correct `README.md:295`, `:297`, `:144-145`, `:296` and `:302`
at the same time.

### Fix E — say what the metro series is

Document the era breaks in `README.md`, and consider suppressing metro for
2004–2006 and 2014–2017 rather than publishing a trams-only or Tyne & Wear-only
series under a "metro" label. A missing value is easier to read correctly than
a 97% undercount.

---

## 6. What is still not known

**No Underground frequency in this pipeline has ever been checked against a
published TfL timetable.** The "correct" Leytonstone answer of roughly 53 tph
used throughout this report is inferred from the years where the line resolves
to a single copy — 2018, 2022 and 2023 — and from the internal consistency of
the 2007–2011 NPTDR series at 53.7. It is plausible (about 26 trains an hour in
each direction in the peak) but it is not verified against a working timetable
the way the 279, the 69, the A1 and the 142 were.

2024 is a single copy too, and sits at 42.0 rather than 53. On the evidence
here that is a real timetable difference — 126 Central line departures in the
peak against 160 — and not a defect. But it is worth saying that this report
establishes which years are *inflated*, not which years are *right*.

Until that is done, Fix B's outputs cannot be called correct, only consistent.
A like-for-like Underground validation — one line, one station, one published
timetable — is the obvious next piece of work, and it would settle Fix B's
open question in section 5 as a side effect.

Three further things this report does not establish:

- **Tram and rail.** Rail shows 5.0% and 14.3% phantom trip-days in 2021 and
  2025, and two thirds of tram trips in the 2025 feed sit on unnamed routes.
  Neither has been investigated; both are exposed to Cause A in the same way.
- **Whether the duplication is stable within a year.** Everything here is
  measured on the 28-day counting window each year actually uses. A different
  snapshot of the same year could carry a different number of copies.
- **The downstream effect.** `../build` folds coach into bus and passes metro
  through unchanged (`build/R/public_transport_frequency.R:64-66`), so these
  figures reach the published outputs as they are, but the size of the effect
  on any headline measure has not been computed.
