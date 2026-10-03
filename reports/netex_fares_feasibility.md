# Can we map how far £5 takes you? The BODS NeTEx fares data assessed

A feasibility assessment of the BODS NeTEx fares archive for building
per-LSOA maps of travel reachable on a fixed fare budget. Written against the
26 July 2026 snapshot, with `UK2GTFS`'s NeTEx functions, October 2026.

Everything below is measured on this machine's data. Where a figure comes from
a sample rather than the whole archive, the sample is named and sized.

---

## The short answer

**The fares data is in better shape than expected, and the £5/£10/£20 framing
is the wrong question.** Three findings decide it:

1. **A single bus fare almost never costs more than £5.** Of 156,283 adult
   single-trip prices measured, **93.7% are £5 or less, 99.7% are £10 or less,
   and 100% are £20 or less**; the median is £3.00 and the single commonest
   price is exactly £3.00 (26% of all adult singles — the national fare cap
   showing through). A £10 map and a £20 map of single bus fares would be the
   same map, and both would be nearly the same as a map with no fare limit at
   all. What stops you travelling further on a bus is **time and
   connectivity, not money.**

2. **Where money does bind, it is because of legs, not distance.** There is no
   general through-ticketing: a two-bus journey costs two fares. So a £5
   budget is better understood as "about two boardings" than as a distance.
   That is a real and interesting constraint, and the data supports it — but
   it needs a fare-aware router, not a fares table.

3. **The dependency on BODS TransXChange is avoidable, and should be
   avoided.** NeTEx fares are keyed on National Operator Code. A
   TNDS-derived GTFS carries the NOC as its `agency_id`; the DfT's BODS GTFS
   does not (it uses synthetic `OP…` codes). Matching fares to **TNDS** rather
   than to BODS TransXChange gives **1.5× more bus service with fares
   attached** — 651,494 trips against 437,041. On that base, **69.2% of
   bus-served LSOAs have at least one fares-publishing operator and 55.3% are
   fully covered** — but the uncovered 30.8% is concentrated in London, the
   West Midlands, Glasgow, Cardiff and Merseyside, so it is a map with large
   holes rather than a patchy one.

So: feasible, for a defined subset, with important gaps — but worth
reframing before building.

---

## 1. What we actually hold

The archive is at `OpenBusData/Fares/` on the data drive: **22 snapshots from
29 January 2021 to 26 July 2026**, growing from 306 MB to 2.6 GB.

| | |
|---|---|
| Snapshots | 22 (2021-01-29 → 2026-07-26) |
| July 2026 archive, as shipped | 2.6 GB |
| Top-level entries | 799 — 559 nested `.zip`, 240 loose `.xml` |
| **Fully extracted on disk** | **38 GB of XML** |
| **NeTEx XML files** | **149,761** |
| Publishing organisations | 335 |
| Distinct operator NOCs | **436** |

Note the expansion ratio: the archive is nested, so the 2.6 GB download
becomes **38 GB** once the 559 inner zips are unpacked. Anyone planning to
work with this needs to budget disk accordingly, and a per-publisher sample
(§3) avoids most of it.

The structure is `<Organisation name>_<BODS id>/<dataset>.zip`, and the
organisations are **parent groups** — "Stagecoach Group", "Go-Ahead Group plc",
"Arriva UK Bus", "Transport for Greater Manchester". The NOCs that matter for
matching are inside the files, not in the folder names, so the folder
listing alone understates coverage badly. (Matching GTFS agencies to publisher
*names* gives 12.4% of TNDS bus trips; matching on NOCs inside the files gives
47.7%.)

**Parsing is not a problem.** `UK2GTFS::netex_read_fares_multiple()` parsed a
random 6,000 files with **zero failures** in 3.07 minutes on 14 cores. The
whole July 2026 archive would take roughly 75 minutes.

### What one file contains

One file is one (line × product × passenger type). A Nottingham City Transport
day pass, for example:

```
meta   : operator_noc NCTR, line_public_code "1", product_type periodPass,
         user_type adult, fare_kind flat, currency GBP, valid_from 2026-06-21
zones  : 113 rows mapping zone_id -> stop_id (NaPTAN ATCO codes)
fares  : from_zone, to_zone, amount
prices : price_group -> amount
```

The `zones` table is the geographic key: it ties a fare zone to a set of
real NaPTAN stops, which is what makes a map possible at all.

### Composition of the corpus

From the 6,000-file random sample:

| Dimension | Breakdown |
|---|---|
| `fare_kind` | flat 3,280 (54.7%), zonal 2,720 (45.3%) |
| `product_type` | singleTrip 2,333, periodPass 1,917, dayReturnTrip 1,091, other 537, dayPass 65, periodReturnTrip 21 |
| `trip_type` | single 2,612, multiple 1,648, returnOut 628, return 488 |
| `user_type` | adult 3,042, child 1,542, youngPerson 733, anyone 438, student 95, senior 66, schoolPupil 37, disabled 9 |

Usability for a distance-varying fare:

| Property | Share of files |
|---|---|
| At least one priced fare | 94.4% |
| A zone → stop map | 95.5% |
| **Point-to-point fares (`from_zone` *and* `to_zone`) *and* a zone map** | **39.2%** |

That last row is the usable subset: about two files in five carry a fare that
varies with where you board and alight *and* enough geography to place it.
The rest are flat fares and passes, which are still useful — a flat fare is
trivially mappable — but carry no distance information.

---

## 2. The finding that reframes the question

156,283 adult single-trip prices, from the same 6,000-file sample:

| Percentile | 5% | 25% | 50% | 75% | 90% | 95% | 99% | max |
|---|---|---|---|---|---|---|---|---|
| Adult single | £1.00 | £2.40 | **£3.00** | £3.80 | £5.00 | £5.10 | £8.50 | £24.00 |

Cumulative share of adult single fares at or below a budget:

| Budget | £2 | £3 | **£5** | **£10** | **£20** |
|---|---|---|---|---|---|
| Share of fares | 16.0% | 69.4% | **93.7%** | **99.7%** | **100%** |

The commonest prices are £3.00 (40,381 of 156,283 = 25.8%), £2.50 (19,614)
and £5.00 (14,315). The spike at exactly £3.00 is the English national bus
fare cap appearing in the data; it compresses almost the whole distribution
below £5.

Zonal products do carry real distance variation — median £3.00, maximum £24.00
— against flat products at median £2.30, maximum £16.50. But the variation
lives in a narrow band, and above £5 there is almost nothing left to
distinguish.

**What follows for the deliverable.** "How far can I get for £5 on one bus" is,
to within 6%, "how far can I get on one bus". That map needs no fares data —
it is a single-leg isochrone, and this repository already holds the
timetables to build it. The fares data earns its place only in the versions of
the question where money actually binds:

- **Multi-leg budgets.** With no through-ticketing, £5 buys roughly two
  boardings and £10 roughly three. A map of "how far on two fares" is a
  genuinely different map from "how far in 60 minutes", and it is the version
  worth building.
- **The long-distance tail.** The ~6% of singles above £5 are interurban and
  express services, where the £5/£10/£20 distinction is real.
- **Rail.** Rail fares scale with distance over a far wider range, and £5 to
  £20 is a meaningful spread. Rail is where this question has its natural
  home — and rail is not in this archive (see §5).

---

## 3. Operator and area coverage

Every `noc:` reference in all 149,761 files was extracted, giving **436
distinct NOCs** appearing in the fares data. (An operator-stratified sample of
3,041 files covering 558 of the 559 nested archives had found 429 of those
436 — so sampling by publisher recovers coverage almost exactly, which is
worth knowing before anyone pays for a full parse.) Joining those NOCs to each
feed's bus `agency_id`:

| Base feed | Bus agencies | With fares | Bus trips covered | Bus routes covered |
|---|---|---|---|---|
| **TNDS 2026-07** | 731 | 270 (36.9%) | **48.3%** | 62.7% |
| **BODS TransXChange 2026-07** | 442 | 339 (76.7%) | **92.8%** | 90.8% |

The two rows look contradictory and are not. BODS TransXChange is *nearly
fully* covered by fares, because the operators who comply with BODS publish
both; but that archive holds only 470,867 bus trips against TNDS's 1,350,071.
In absolute terms:

| Base feed | Bus trips | …with a fares publisher |
|---|---|---|
| TNDS | 1,350,071 | **651,494** |
| BODS TransXChange | 470,867 | 437,041 |

**So the concern about BODS TransXChange's missing routes is well founded but
points the other way.** The fact that it is missing much of the network is a
reason *not* to build fares on it. Matching the same fares to TNDS attaches
them to 1.5× more service. Nothing in `UK2GTFS`'s NeTEx functions requires the
BODS TransXChange feed specifically — `netex_match_routes()` takes any GTFS
object — so this is a free choice.

### Coverage by LSOA, which is what the deliverable needs

Joining all 316,597 TNDS bus stops to the plain LSOA21/DZ22 polygons and
asking, per zone, whether its bus stops are served by fares-publishing
operators:

| | Zones | Share of bus-served zones |
|---|---|---|
| Zones with any bus stop | 40,754 of 43,064 | — |
| **At least one fares-publishing operator** | **28,188** | **69.2%** |
| **Every bus stop served only by fares publishers** | **22,521** | **55.3%** |
| No fares at all | 12,566 | 30.8% |

The distribution is strongly bimodal — the median zone is *fully* covered and
the lower quartile is *entirely* uncovered — because coverage is an operator
property and most zones are served by one or two operators. So a national map
would have about **a third of its area blank**, in large contiguous blocks
(London, the West Midlands conurbation, Glasgow, Cardiff, Merseyside) rather
than scattered noise. That is the honest headline on coverage: it is not a
patchy map, it is a map with holes where several of the largest urban
populations live.

### Who is missing

The largest TNDS bus operators with no NeTEx fares publisher:

| NOC | Operator | Routes | Trips |
|---|---|---|---|
| NXB | National Express West Midlands | 284 | 64,032 |
| ML | Metroline Travel | 100 | 51,826 |
| MN | Arriva London North | 69 | 46,925 |
| LG | London General Transport Services | 74 | 39,528 |
| IF | East London Bus & Coach | 82 | 38,121 |
| LC | London Central Bus Company | 63 | 33,925 |
| CX | Transport UK | 52 | 26,804 |
| CBUS | Cardiff Bus | 61 | 26,008 |
| BNML | Bee Network (Metroline) | 261 | 25,196 |
| LU | London United Busways | 53 | 25,035 |
| FGLA | First Glasgow | 93 | 20,597 |
| SL | Arriva London South | 33 | 18,481 |

Two patterns dominate. **London** accounts for seven of the twelve: TfL sets
and publishes bus fares itself and they are not in BODS NeTEx. (Conceptually
London is the easy case — a flat £1.75 bus fare with daily capping — but the
data is not here.) **National Express West Midlands** is the single largest
absence, and it is also the operator at the centre of the double-counting
problem documented in `lsoa_disagreement.md` — so the West Midlands is poorly
served on both fares and timetable.

---

## 4. Matching, and where it fails

`UK2GTFS::netex_match_routes()` matches in two stages: exact on
(line number, operator NOC), then falling back to **line number alone**,
taking the first route that matches.

The fallback is dangerous nationally. Route "1" exists in hundreds of places.
Tested end to end on Nottingham — all 523 NeTEx files whose path names NCTR,
covering NOCs NCTR, TBTN and BRTB, 94 lines — against the real national TNDS
feed:

| | |
|---|---|
| Files matched to a GTFS route | 489 of 523 (**93.5%**) |
| Lines matched | 87 of 96 |
| Files skipped (no match) | 34 |
| Matched to a route outside the three NOCs in the file set | **49 of 489** |

So about one in ten matches landed on another operator's route of the same
number. On a national build that error would be much larger. Any production
use should disable the line-number fallback and accept the lower match rate,
or restrict matching to a region at a time.

There is a second, quieter matching problem: **the NOC in NeTEx and the
`agency_id` in a TNDS-derived GTFS are not always the same string.** Go-Ahead
London publishes as `LGEN` where TNDS carries `LG`; Arriva West Midlands
publishes `AMNO`; Go South Coast uses `BLUS`, `TDTR`, `WDBC`, `SVCT`, `SWWD`,
`UNIL`. In the 6,000-file sample, **49 of 199 NOCs had no matching TNDS bus
`agency_id`** and were real GB bus operators. A NOC crosswalk is needed; it
does not exist in the repo.

---

## 5. What is missing, and how much it matters

Ordered by how much it would hurt a £5 map.

**Rail, and therefore most long-distance travel for money.** Not in BODS
NeTEx at all. It *is* available separately and we hold it: `fares.zip` in each
Rail Data Portal snapshot (**six snapshots, 2025-02 to 2026-05**, ~46 MB each,
RJFAF flat files), plus an older ATOC `RJFAF017.ZIP` from 2019. `UK2GTFS` has
`atoc_fares_read()`, `nrdp_fares()` and `gtfs_add_railfares()` for them. Two
obstacles: the rail feed is keyed on **TIPLOC** while the bus data is keyed on
**ATCO**, so stops cannot be joined directly — and the stop-identity defect
documented in `lsoa_disagreement.md` (§"Ferry, and a stop-identity defect")
shows that even within the bus data one `stop_id` can resolve to two places.

**London, Underground, metro and tram.** Absent from both archives. This is
where a fare budget is most visibly binding for the most people, and it is the
largest single hole.

**Anything before 2021.** The fares archive starts 2021-01-29. The frequency
series in this repository runs 2004–2025, so fares can only ever be attached
to its last few years. A historical "£5 reachability" series is not possible.

**Concessionary travel.** Free bus travel for those over state pension age is
not representable as a fare, and `user_type` carries only 66 `senior` files in
6,000. Any £5 map is implicitly a map for a fare-paying adult, and would be
wrong for a large share of actual bus passengers.

**Caps and capping.** The data holds the *products* (day passes, period
passes) but not the rules by which contactless or smartcard travel is capped
daily or weekly. For a budget question this matters: £5 with daily capping
buys unlimited travel in many networks.

**Transfers.** `gtfs_add_fares_v2()` writes no `fare_transfer_rules`, so a
multi-leg journey costs the sum of its legs with no discount. That is roughly
right for Britain outside the capped networks, but it is an assumption, not
data.

### The GTFS representation ceiling

This one is worth stating precisely, because it decides the build. Running
both writers on the same Nottingham input, against the national TNDS feed:

| GTFS Fares **v1** | |
|---|---|
| `fare_attributes` | 279 |
| `fare_rules` | 56,345 |
| Stops given a `zone_id` | **2,027** |
| Stops whose zone assignment **collided and was discarded** | **9,389** |

| GTFS Fares **v2** | |
|---|---|
| `areas` | 5,556 |
| `stop_areas` | 5,581 |
| `fare_products` | 27 |
| `fare_leg_rules` | **219,240** |

GTFS Fares v1 allows **one `zone_id` per stop**. A stop served by several
routes, or by both directions of one route, belongs to several fare zones, so
v1 keeps the first and throws the rest away — 9,389 collisions against 2,027
surviving assignments, **for a single city with three operators**. Nationally
v1 is unusable. Fares v2 has `stop_areas` as a many-to-many table and does not
have this problem, which is why it produced 219,240 priced origin-destination
rules for Nottingham alone.

The cost of v2 is routing support: it is a newer specification and far fewer
routers implement it than implement v1.

---

## 6. So how would you actually build it?

A staged plan, cheapest first, each stage independently useful.

**Stage 1 — build the map the data already supports, and name it honestly.**
A single-leg bus isochrone per LSOA, from the TNDS GTFS, with no fares at all.
Given §2, this *is* the £5 map to within 6%, and the £10 and £20 maps are the
same again. This needs nothing new and would answer most of the underlying
question.

**Stage 2 — a leg-budget map.** "How far on one fare, two fares, three
fares", using the measured fare distribution to convert £5/£10/£20 into a
number of boardings per area. This keeps the money framing, uses the fares
data where it is strongest (the price level, which is well measured) and
avoids depending on the 39.2% of files with point-to-point geometry.

**Stage 3 — genuine fare-aware routing, regionally.** TNDS GTFS +
`gtfs_add_fares_v2()` + a router that reads Fares v2 (or a custom fare
calculator in `r5r`). Do it for one city-region first, with the line-number
fallback disabled, and validate against published fare tables the way
`pdf_validation.md` validates timetables. Nottingham is the natural pilot: a
clean single-operator core, 93.5% match rate and 219,240 leg rules already
demonstrated.

**Stage 4 — rail.** Only worth attempting once the TIPLOC↔ATCO stop-identity
problem is solved, because that is a prerequisite for any multi-modal fare
journey and is not a fares problem at all.

### What would have to be built that does not exist

- A **NOC crosswalk** between NeTEx `operator_noc` and GTFS `agency_id`
  (49 of 199 sampled NOCs do not match).
- A **fares extraction target** in `_targets.R` — none of this is in the
  pipeline today.
- A **fare validation report**, on the model of `pdf_validation.md`:
  published fare tables are the only external check on whether any of this is
  right, and no such check exists yet.
- A decision on **whose fare** the map shows (adult cash, adult contactless,
  concessionary), which changes the answer more than any of the technical
  choices above.

---

## 7. What is not established

- **Coverage is measured by operator, not by route.** An operator publishing
  fares for *some* of its lines counts as covered. The true route-level
  coverage is lower than the 47.7% of TNDS bus trips quoted, and has not been
  measured.
- **The full archive has not been parsed.** All structural figures come from a
  6,000-file random sample and a 3,041-file operator-stratified sample, out of
  149,761 files. Zero parse failures in 6,000 is strong evidence the rest
  would parse, but the composition percentages carry sampling error.
- **The fare-cap interpretation of the £3.00 spike is inference.** The spike
  is measured; attributing it to the national cap is reasoning from its
  size and exactness, not from anything in the data.
- **No fare has been validated against a published source.** Everything here
  describes what the feed says, not whether it is true. The timetable work in
  this repository found real errors in feeds that looked internally
  consistent, and there is no reason to assume fares are cleaner.
- **Whether any router in use here reads GTFS Fares v2** has not been tested.
  The v2 tables were produced; nothing consumed them.
