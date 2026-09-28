# What changed in the September 2026 rebuild

Every timetable in this repository was reconverted between 19 and 25 September
2026, and every output rebuilt, after three defects were found in the
conversion chain. This report says what moved, why, and what a reader should
now treat differently.

The short answer: **the bus series is more trustworthy than it was, the metro
series is materially different and now correct, and the tram and rail series
have changed definition.** Two of the three defects were present in the
previously published outputs; the third was introduced and caught during this
work, before publication.

| | old | new | |
|---|---|---|---|
| Outputs | `backups/pre_metro_fixes_2026-09-11/` | `data/` | |
| Feeds | `backups/gtfs_pre_metro_fixes/` (12 GB) | `gtfs/` | |
| Reports | `reports/archive/2026-09-11_pre_metro_fixes/` | `reports/` | |
| Code | UK2GTFS at `0b9408a` | UK2GTFS at `5b0cfa5` | |

Headline measure throughout is `tph_Wed_Afternoon Peak` — trips per hour,
Wednesday, 15:00–17:59 — summed over all zones. Reproduce any table here with
`Rscript scripts/metro_duplicates/compare_rebuild.R`.

---

## 1. The three defects

**A — Duplicate published copies of Underground lines.** TfL files one
Underground line into TNDS as several TransXChange documents with distinct
`ServiceCode`s and overlapping validity. Each became its own GTFS route.
`gtfs_deduplicate()` could not group them, for two independent reasons: it
keys an unnamed route on its own `route_id`, and UK2GTFS blanked any
`LineName` longer than six characters to pass a validation check — which
deletes `Central`, `Piccadilly` and `Bakerloo` but leaves `Circle`. The result
was that **93% of metro trips were exempt from deduplication**. Present in the
published outputs.

**B — `gtfs_merge()` numbered `file_id` per table, not per feed.** The
identifier was assigned `1..n` over only the feeds containing each table, so a
feed missing one table shifted every later feed's numbering for that table
alone. The NCSD coach archive carries no `calendar_dates` and sits fourth of
twelve, so eight regions had their cancellations applied to the *preceding*
region's services. Present in the published outputs, and the largest single
correction in this rebuild. **This mattered most for bus**, and it went unnoticed
for months because nothing compared a merged feed against the regions that went
into it.

**C — The NAPTAN join ran after the mode rules.** A conversion speedup moved
the join out of the per-file loop, correctly, but placed it after
`apply_standard_modes()`. Thirteen of the eighteen mode rules match on a stop's
name, and stop names do not exist until that join runs, so all thirteen
silently matched nothing. Introduced 19 September, caught 22 September,
**never published**. It is described here because it explains why intermediate
builds disagreed, and because the reason it survived a full pipeline run is
worth knowing: a rule that matches no route is indistinguishable from a rule
that had nothing to correct.

---

## 2. Bus: defect B, and it is a real correction

Nationally the bus series barely moves, which understates what happened
underneath.

| Year | old | new | Δ | zones unchanged |
|---|---|---|---|---|
| 2018 | 1,221,814 | 1,215,810 | −0.5% | 60.1% |
| 2019 | 1,181,697 | 1,189,688 | +0.7% | 52.5% |
| 2020 | 926,504 | 943,029 | +1.8% | 79.5% |
| 2021 | 1,038,053 | 1,062,317 | +2.3% | 50.2% |
| 2022 | 1,017,082 | 1,021,333 | +0.4% | 64.3% |
| 2023 | 994,214 | 992,367 | −0.2% | 98.7% |
| 2024 | 1,012,466 | 1,010,590 | −0.2% | 98.8% |
| 2025 | 1,023,645 | 1,022,088 | −0.2% | 99.1% |
| 2004–2017 | | | ≤0.2% | ≥99.4% |

Half the zones in 2019 and 2021 changed, in both directions, while the national
total moved by under 1%. That is the signature of defect B: cancellations were
not created or destroyed, they were **moved to the right region**. Journeys
wrongly cancelled in one region came back; journeys wrongly spared in another
went away.

The scale of the underlying error is much larger than the national totals
suggest. Cancelled Wednesday trip-days in each merged snapshot:

| Snapshot | NCSD gap | old | new | Δ |
|---|---|---|---|---|
| 2018 | yes | 363,136 | 238,394 | −34.4% |
| 2019 | yes | 791,092 | 117,961 | **−85.1%** |
| 2020 | yes | 291,382 | 131,938 | −54.7% |
| 2021 | yes | 570,860 | 344,639 | −39.6% |
| 2022 | yes | 654,537 | 445,794 | −31.9% |
| 2023 | yes | 353,829 | 353,806 | −0.0% |
| 2024 | no | 442,514 | 442,453 | −0.0% |
| 2025 | no | 421,313 | 421,243 | −0.0% |

The 2019 feed was carrying **673,000 cancelled bus trip-days that should not
have existed** — nearly seven times the true figure. Most of those cancellations
landed on services that would not have run in the counting window anyway, which
is why the published figure moved by only +0.7%; but the ones that did land on
live services moved individual zones by up to 44 trips per hour.

**2023 is genuinely unaffected despite having the same NCSD gap.** The obvious
explanation is wrong: `convert_tnds_snapshot()` lists regions with
`list.files()`, so NCSD is always fourth of twelve in every snapshot. The gap
was reachable and did not bite. The probable mechanism is that `gtfs_merge()`
only renumbers `service_id`s when they collide between feeds, and `file_id` is
consumed only by that renumbering — so a snapshot whose regions happen not to
collide never reaches the defect. That is offered as the likely reason, not as
a finding: it has not been tested against the old build, and since the fix is
now proven on all nine snapshots the question is historical.

**How the fix is verified.** A merge redistributes cancellations; it cannot
create them. So cancelled trip-days summed over the regional feeds must equal
cancelled trip-days in the merged feed. That invariant needs no reference data
and it now holds exactly, on **all nine snapshots across all seven days of the
week**. Before the fix, 2018 gave 238,394 against 391,769.
Run `Rscript scripts/metro_duplicates/check_fileid_fix.R`.

---

## 3. Metro: defect A, and the spikes are gone

The zone that started the investigation, E01004440 (Leytonstone, Central line):

| Year | 2007 | 2008 | 2009 | 2010 | 2011 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| old | 53.7 | 53.7 | 53.7 | 54.0 | 54.0 | 55.0 | 55.0 | 49.0 | **96.8** | 55.3 | 50.7 | 42.0 | **101.3** |
| new | 53.7 | 53.7 | 53.7 | 54.0 | 54.0 | 55.0 | 55.0 | 49.0 | **55.3** | 55.3 | 50.7 | 42.0 | **50.7** |

Both spikes removed; **all eleven other years unchanged to the decimal**, and
rail and bus at that zone unchanged in all thirteen years. A fix that moved
only the two years known to be wrong is the strongest available evidence that
it is a fix and not a re-weighting.

Splitting the same count by platform shows why the old figures were not merely
high but impossible:

| Year | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|
| eastbound | 26.3 | 26.3 | 23.5 | 26.3 | 26.3 | 24.3 | 21.0 | 24.3 |
| westbound | 26.7 | 26.7 | 24.0 | 27.0 | 27.0 | 25.3 | 21.0 | 25.3 |

Roughly even in both directions, about a 2.2-minute headway. The old 2021 and
2025 figures implied a train every 75 seconds per platform, which no
Underground line runs.

---

## 4. Tram and rail: the definition changed

These are the movements most likely to be mistaken for errors, so they are
stated plainly: **tram and rail fall in every year from 2018, and metro
absorbs what they lose.** This is not a change in service. Three systems were
filed under the wrong mode by their publishers and have been moved:

| System | published as | now | why |
|---|---|---|---|
| Docklands Light Railway | heavy rail (TNDS) | metro | it is a light metro |
| Glasgow Subway | tram (TNDS) | metro | it is an underground metro |
| Gatwick Airport shuttle | metro (TNDS) | tram | an inter-terminal people mover |
| Heritage railways | tram / rail / bus / metro, varying | rail | one mode, consistently |

| Year | tram | rail | metro |
|---|---|---|---|
| 2018 | −21.6% | −9.6% | +12.2% |
| 2019 | −24.2% | −9.3% | −2.5% |
| 2020 | −34.8% | −9.6% | +14.0% |
| 2021 | −26.2% | −8.5% | −7.9% |
| 2022 | −28.8% | −9.8% | +6.6% |
| 2023 | −26.3% | −11.0% | +11.2% |
| 2024 | −14.4% | −10.6% | −8.4% |
| 2025 | −14.3% | −7.8% | −6.2% |

Metro moves in both directions because two effects act on it at once: it
**gains** the DLR and the Subway, and **loses** the duplicate Underground
copies of defect A. Which dominates depends on how much duplication that
year's snapshot carried. 2021 and 2025 were the two worst years for
duplication, so metro falls; 2020 and 2023 had little, so metro rises.

A new mode also appears: **`route_type` 6, aerial lift — 240 tph in every year
from 2018.** That is the London Cable Car, previously filed as heavy rail.

The check that these are now consistent: every one of the **14 named systems
carries exactly one mode across all 20 feeds**, where four did not before. Run
`Rscript scripts/metro_duplicates/mode_consistency.R`. This is the single most
useful regression test in the repository, and it is now a pipeline stage —
see [`non_bus_modes.md`](non_bus_modes.md).

---

## 5. Changes that were not predicted

Everything above was expected. These were not, and each is stated with its
size so a reader can judge it.

**5.1 Bus Archive 2016 does not contain London Underground — it contains
Lancashire United Ltd.** *This section replaces an earlier version of itself
that got the finding backwards; the correction is recorded rather than quietly
swapped, because the mistake is instructive.*

66 routes and 6,778 trips moved out of **bus** and into **metro**, and bus fell
by the matching 1,968 tph, so the reattribution balances. The earlier version
read that balance as confirmation that the Underground had been found hiding in
the bus totals. It is the opposite. Agency `LUL` in `busarchive_2016` carries
`agency_name` **"Lancashire United Ltd"**, its route short names are `152`,
`X41`, `6`, `7`, `22`, `SHS`, and its long names are of the form
`Preston City Centre, Preston - Burnley`. They are buses in Lancashire, and the
operator-code rule on `LUL` relabelled all 66 as metro. `busarchive_2017`
carries 4 more routes and 8 trips of the same.

Not one of those 66 routes calls at a stop named "Underground Station", which
is what makes the collision detectable, and is now the basis of the guard in
`apply_standard_modes()`: an operator rule that also carries a stop pattern
stands down unless at least one of that operator's routes calls at a stop the
pattern matches. Measured across every feed, real Underground routes clear that
test at 93.6–100%, so nothing that should fire stops firing.

Consequences for this report: metro 2016 rises 2,545 → 9,391 tph and 172 → 500
zones, of which roughly **+4,887 is correct** (Tyne and Wear Metro moving from
tram to metro, which it should always have been) and **+1,968 is wrong**. The
claim elsewhere in this report that no new issues were introduced does not hold
for 2016 and 2017 metro. The `sources` column cannot fix this, because the Bus
Archive and TNDS both run through the TransXChange converter.

**5.2 The Glasgow Subway is published twice, at two NAPTAN granularities.**
*Also a correction: an earlier version of this section noted the Subway being
"64 routes in 2014, 128 in 2015" and set it aside as a property of the archive.
It is a defect, and it reaches the published figures.*

NAPTAN gives each Subway station a station-level code and a code per platform —
`9400ZZGLBUC`, `9400ZZGLBUC1`, `9400ZZGLBUC2` — and the feeds from 2015 to 2023
carry the timetable against both. In `tnds_20231101` the weekday service holds
**748 trips for a timetable of 374**: 374 calling only at station-level codes,
374 only at platform codes, none mixing. Trips `740135` and `740136` both leave
Ibrox at 06:27 and call at the same fifteen stations in the same order,
differing only in whether the ids carry the platform suffix.

Published effect at Glasgow zone **S01016967**, metro, Wednesday afternoon
peak:

| Years | Subway stop records per station | tph |
|---|---|---|
| 2005–2014 | 1 | 360 |
| **2015–2023** | **3** | **720** |
| 2024–2025 | 2 | 360 |

It ends in 2024 because NAPTAN stopped issuing the station-level code, so in
the series it reads as a service change rather than a defect. The same
mechanism affects the **Docklands Light Railway** and **Sheffield Supertram**;
in `tnds_20231101` seventeen stations qualify, covering 2,188 metro trips and
681 tram trips.

Nothing keyed on `stop_id` can see this — not a duplicate-itinerary test, not a
first-and-last-stop test, and not a count of trips, because the trips really
are distinct rows. `gtfs_deduplicate()` now canonicalises a platform code to
its station code when building the journey signature, and only when the feed
holds both and they carry the same name.

Consequence, unchanged from the earlier version and reinforced: **the metro
series should not be read as one continuous measure across 2004–2025.**

**5.3 The unzoned bucket grew in the NPTDR years.** Stops that fall outside
every zone are carried as `zone_id = NA`. In 2004–2011 that bucket rose from
12–23 tph to 60–352 tph. It is 3 to 5 rows per year and at most **0.044% of
the national total**, and `load_pt_frequency()` in the `build` repo drops
`NA` zones before anything downstream sees them. Recorded for completeness;
no action.

**5.4 The converter-uniformity rebuild moved three zones.** The four snapshots
converted before the speedup (2018, 2019, 2020, 2024) were rebuilt so the
whole series comes from one converter. The predicted effect was nil. Measured:
**2018, 2020, 2024 and all twelve non-rebuilt control years came back
bit-for-bit identical**; 2019 moved in three zone-modes —

| Zone | mode | old | new | Δ |
|---|---|---|---|---|
| E01025991 | bus | 12.33 | 14.33 | +2.00 |
| E01025998 | bus | 6.67 | 8.67 | +2.00 |
| E01033567 | coach | 1.33 | 0.00 | −1.33 |

— a national effect of **+2.67 tph on 1,369,704, two ten-thousandths of one
percent**. The cause is known: the newer converter keeps about 0.2 m more
coordinate precision on `naptan_replace` stops, and that was enough to move a
Cambridgeshire stop across an LSOA boundary. Nothing was created or lost; two
neighbouring zones exchanged a few journeys.

---

## 6. What is still not established

- **No non-bus frequency has been validated against a published timetable.**
  The bus series has been checked journey-for-journey against operators'
  printed schedules (`route_279_pdf_validation.md`,
  `route_validation_69_A1_142.md`). Nothing equivalent exists for metro, tram,
  rail or ferry. Leytonstone at ~55 tph is consistent across eight snapshots
  and plausible for the Central line, but it has never been checked against a
  TfL timetable, and "consistent" is not "correct".
- **The 2004–2017 metro series remains non-comparable**, for the archive
  reasons in 5.1 and 5.2 and the era breaks in
  [`non_bus_modes.md`](non_bus_modes.md#5-when-is-each-mode-actually-in-the-series).
  It is published rather than suppressed, but it should not be plotted as a
  trend.
- **Why 2023 escaped defect B** is unexplained; see section 2.
- **The BODS TransXChange series is still mixed-version** with respect to the
  converter's own history, an issue predating this rebuild and unrelated to
  defects A–C.

---

## 7. Provenance

Three rebuilds, **102 hours of compute, 0 errored targets**:

| Run | Scope | Wall time |
|---|---|---|
| `rebuild_fileid_fix.R` | all sources, defects A and B | 45h 47m |
| `rebuild_mode_order_fix.R` | 16 TXC conversions + downstream, defect C | 45h 47m |
| `rebuild_converter_uniformity.R` | the 4 pre-speedup snapshots | 10h 33m |

Verification harnesses, all passing on the final data:

| Script | Checks |
|---|---|
| `check_fileid_fix.R` | cancelled trip-days conserved across every merge |
| `mode_consistency.R` | no system carries two modes |
| `compare_rebuild.R` | every year and mode, old against new |
| `verify_fixes.R` | platform split, phantom copies, bus left untouched |

UK2GTFS changes, on branch `fixed-track-duplicates`:

| Commit | |
|---|---|
| `0b9408a` | identify fixed-track journeys by their termini |
| `e3088e4` | group re-registrations that were retyped |
| `2fa5a99` | give NPTDR light rail the modes TNDS uses |
| `9631b22` | one set of mode rules for every source |
| `66dab03` | restore the filter docs; file the DART and the cable car |
| `1e06562` | **make `file_id` identify the feed** (defect B) |
| `8f29e6e` | stop a mode rule firing on a source its system predates |
| `5b0cfa5` | **name the stops before applying the mode rules** (defect C) |

Each carries a regression test. Two are worth singling out, because both
defects were the silent kind:

- `test_gtfs_merge_file_id.R` gives every input feed the **same** `service_id`,
  as independently converted regional feeds really do. An earlier version of
  this test used distinct ids and **passed on the broken code**, because the
  renumbering path that consumes `file_id` was never entered.
- `test_txc_mode_after_naptan.R` asserts the *ordering* rather than a mode, and
  `apply_standard_modes()` now warns when handed a feed with no stop names. Not
  being able to tell "no route needed correcting" from "no rule could run" is
  what let defect C through a full pipeline run.
