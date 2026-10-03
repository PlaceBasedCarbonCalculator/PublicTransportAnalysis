# Why TNDS and BODS disagree, traced to the raw data

`reports/lsoa_disagreement.md` shows where the two bus timetable sources
disagree and attempts to say which one is wrong. It stops at the feeds. This
goes behind them, into the TransXChange files the feeds are built from, to
answer three questions the zone-level work could only frame:

1. **Why do duplicate journeys survive `gtfs_deduplicate()`?** Does the
   function need improving, and how much would improving it recover?
2. **Why do services stop part-way through the counting window in TNDS but
   not in the DfT's BODS GTFS?** Is `UK2GTFS` mis-converting them, and what
   does it tell us about how long a snapshot is valid for?
3. **Why are services missing from TNDS?** Are they removed in conversion, or
   genuinely absent from the raw data?

The short answers: the deduplication defect is real but small; the mid-window
dropout is not a conversion error at all but a property of TNDS that biases
every published year; and services *are* being destroyed in conversion, by a
`ServiceCode` collision in `UK2GTFS` that costs 3.3% of one region and whole
route networks in individual towns. That collision has since been fixed and
the fix verified against every region. Along the way one verdict in the LSOA
report turns out to be the wrong way round.

Everything here is measured. Nothing is inferred from file names.

## The experiment that makes this answerable

Three renderings of British bus timetables are available, and the third is
what makes cause separable from effect:

| Source | What it is | Converter |
|---|---|---|
| **TNDS** | Traveline's weekly snapshot of currently-lodged registrations | `UK2GTFS` |
| **BODS TransXChange** | The DfT's change archive, as lodged | `UK2GTFS` |
| **BODS GTFS** | The same archive as the row above | the DfT's own |

Rows 2 and 3 are the *same underlying data* rendered by *different
converters*; rows 1 and 2 are *different data* through the *same* converter.
So a difference that appears between 2 and 3 is the converter, and one that
appears between 1 and 2 is the data.

Counted over the 2026 window (27 July – 23 August) on plain LSOA boundaries:

| Source | Bus trip-runs | vs BODS GTFS |
|---|---:|---:|
| TNDS | 190,990,151 | 0.94 |
| BODS TransXChange via `UK2GTFS` | 75,347,306 | **0.37** |
| BODS GTFS | 203,021,824 | 1.00 |

That 0.37 is stable across all five comparison years (−61.8% to −63.8%), so it
is structural rather than a bad snapshot. Most of it is deliberate — see
"the registration overlap", below — but it is the single largest unexplained
quantity in this whole comparison and it is not yet fully accounted for.

## 1. Duplicates that survive deduplication

### The mechanism: two minutes of layover

In the Chelmsford cluster (LSOA E01034091), 21,185 of BODS GTFS's 66,571
counted trip-days are the same journey twice — 31.8%, against 0.79%
nationally. Two of those trips, taken at random from the largest group:

| | trip A | trip B |
|---|---|---|
| `route_id` | 122094 (X30) | 122094 (X30) |
| `service_id` | 1863 | 1863 |
| stops | 29 | 29 |
| departure, stop 1 | 03:55:00 | 03:55:00 |
| **arrival, stop 1** | **03:53:00** | **03:51:00** |
| every later arrival, departure, `pickup_type`, `drop_off_type` | identical | identical |

They differ in one value: how long the bus is recorded as standing at its
origin before it departs. `gtfs_deduplicate()` builds its journey signature
from `(stop_id, arrival_time, departure_time, pickup_type, drop_off_type)` at
every call, so a two-minute difference in layover makes these two different
journeys and both are kept. Nothing a passenger could observe differs between
them.

Two other candidate explanations were tested and rejected. `block_id` is not
the cause — `match_block = FALSE` is already the default and the field is
excluded. The date-redundancy test is not the cause either; it is correct, and
with an identical `service_id` it would have removed the copy had the
signature matched.

### How much would fixing it recover? Not much

Removable extra trips, counting only copies that share a `service_id` so that
the date-redundancy test is satisfied by construction and nothing is counted
that could leave a date with less service:

| Journey signature | BODS GTFS | % | TNDS | % |
|---|---:|---:|---:|---:|
| `stop + arrival + departure + pickup/drop-off` (current) | 7,673 | 0.522% | 12,026 | 0.815% |
| drop `arrival_time` | 9,692 | 0.659% | 12,040 | 0.816% |
| drop times at the first call as well | 9,694 | 0.660% | 12,042 | 0.816% |
| **recovered by ignoring `arrival_time`** | **2,019** | **0.137%** | **14** | **0.001%** |

**Ignoring `arrival_time` recovers 2,019 trips in BODS GTFS — 0.137% — and
fourteen in TNDS.** The defect is real and worth fixing: it is a free
correctness gain with no plausible false positive, since two journeys of one
service that depart every stop at the same minute are the same bus. But it
does not solve the duplication problem, and it is almost entirely a property
of one feed.

That asymmetry is itself informative. `UK2GTFS` computes arrival times when it
converts, so two publications of one journey come out with the same ones; the
DfT's exporter preserves whatever layover each TransXChange file declared, and
two files describing one journey rarely agree on it to the minute. The
signature is strict enough to be defeated by a field that only one of the two
pipelines varies.

### Why it cannot: the duplication that matters is upstream

The large duplication is not between copies that share a `service_id`. It is
between two *registrations* of one service, and their journey times differ by
minutes, so no exact-signature test can ever match them. Birmingham route 74
is the clean example, and it is the subject of section 3.

The practical consequence is important for anyone trying to produce a correct
count: **once a feed is in GTFS, the information needed to reconcile
overlapping registrations has already been lost.** `service_id` 90 and 3194
are just two calendars; nothing in the GTFS says they are the same registered
service published twice. Reconciliation has to happen on the TransXChange,
where `ServiceCode`, `RevisionNumber` and `OperatingPeriod` still exist —
which is exactly what `txc_filter_files()` is for, and why the TransXChange
route through `UK2GTFS` produces a lower and more defensible figure than the
DfT's direct GTFS export.

## 2. Services that stop mid-window

### It is not a conversion error

Reading Buses (LSOA E01033415, the "TNDS calendars cut short" case) in the raw
TNDS snapshot of 26 July 2026, read straight out of the XML:

| Operating period | Files | Vehicle journeys |
|---|---:|---:|
| 2026-06-15 → 2026-07-19 | 57 | 6,252 |
| 2026-07-13 → 2026-07-19 | 1 | 156 |
| 2026-07-20 → **2026-08-02** | 57 | 6,186 |

Every Reading Buses registration in the snapshot ends on or before 2 August.
There is no successor. The file names say so without being parsed —
`RDG 200726-020826_SER1.xml`. The window runs to 23 August, so 21 of its 28
days have no Reading Buses data **because the data does not exist in that
snapshot**. `UK2GTFS` reproduces the operating periods exactly; seven days of
twenty-eight is 0.25, which is precisely the ratio 39 of that zone's 48 shared
services show.

### What it means about validity periods

This is the general lesson, and it is about what the two sources *are*:

- **TNDS is a snapshot with no forward horizon.** It carries the
  registrations lodged with Traveline as at its build date. Operators who
  publish in short blocks — Reading Buses uses roughly five-week blocks — run
  out shortly after the snapshot, and their successor simply is not in the
  file yet.
- **BODS is a change archive with a long one.** Its files are forward-dated:
  the 2026 GTFS runs to 2027-08-02 against TNDS's 2026-09-09, and only 6.2% of
  its journeys expire inside the window against TNDS's 18.1%.

So a TNDS snapshot is only fully valid for a window much shorter than the 28
days this pipeline counts over.

### It reaches the published outputs

Bus trips live on each Wednesday of each year's own counting window — like for
like, so the weekday pattern cannot be mistaken for decay:

| Year | Wed 1 | Wed 2 | Wed 3 | Wed 4 | Change |
|---|---:|---:|---:|---:|---:|
| 2018 | 453,613 | 453,018 | 446,469 | 452,090 | −0.3% |
| 2019 | 446,298 | 444,998 | 442,904 | 441,230 | −1.1% |
| 2020 | 337,752 | 338,908 | 338,650 | 337,225 | −0.2% |
| **2021** | 407,687 | 402,576 | 373,293 | 366,130 | **−10.2%** |
| 2022 | 387,575 | 378,022 | 376,677 | 375,967 | −3.0% |
| 2023 | 370,359 | 371,338 | 365,408 | 359,605 | −2.9% |
| 2024 | 383,929 | 385,109 | 382,255 | 368,721 | −4.0% |
| 2025 | 395,380 | 394,942 | 391,103 | 383,591 | −3.0% |
| 2026 | 379,537 | 373,815 | 373,121 | 366,252 | −3.5% |

Every year from 2021 loses service across its own window; 2018–2020 do not.
A year's published figure is therefore biased low by roughly half its decay,
and — because the bias is not constant — **year-on-year comparisons inherit the
difference**. 2021 is understated against 2018–2020 by something of the order
of 5%, which is the same magnitude as the changes those comparisons report.

This is not visible nationally in the TNDS-versus-BODS ratio, which runs 0.933
on day 1 and 0.921 on day 28: BODS decays slightly too, and operators whose
registrations run long mask those whose do not. It is only visible against the
feed's own first week.

## 3. Services missing from TNDS

Three different things wear this label, and they have opposite answers.

### (a) Conversion is not losing them

West Midlands, raw against converted:

| | Files | Vehicle journeys |
|---|---:|---:|
| Raw TNDS XML | 1,267 | 109,681 |
| Kept by `txc_filter_files()` | 1,267 | 109,681 |
| **Converted GTFS trips** | 1,264 routes | **109,673** |

A ratio of **0.9999**. Where the file filter does not fire, `UK2GTFS` converts
TransXChange essentially losslessly.

### (b) But in other regions the filter destroys real service

Crawley and Gatwick (LSOAs E01031585, E01031575) are the LSOA report's
clearest "journeys missing from TNDS" case: the Metrobus town network is in
BODS and absent from TNDS. It is *not* absent from the raw data. All 73
Metrobus files in the South East are live in the window, open-ended, and
include the town routes:

| Line | `ServiceCode` | Raw journeys | In converted feed |
|---|---|---:|---|
| 1 | `1` | 209 | **no** |
| 10 | `10` | 165 | **no** |
| 100 | `100` | 63 | **no** |
| 2 | `2` | 37 | **no** |
| 21 | `21` | 28 | **no** |
| 3 | `3,603` | 24 | yes (24 trips) |
| 4 | `4,5` | 23 | yes (23 trips) |
| 5 | `4,5` | 26 | yes (26 trips) |
| 20 | `20` | 24 | yes (24 trips) |
| 400 | `400` | 12 | yes (12 trips) |

The lines that survive convert with their journey counts intact. The ones that
vanish are destroyed by `txc_filter_files()`, and the reason is a key that is
not unique. Rule 2 does `split(meta, meta$ServiceCode)` and keeps, per
`ServiceCode`, only the file with the most recent start date on or before the
reference date. **A `ServiceCode` is only unique within an operator.** Five
different operators in the South East publish a service with `ServiceCode`
`1`:

| File | Operator | Line | Start date | Journeys |
|---|---|---|---|---:|
| `bucks_RRTR_1_1_1_1.xml` | RRTR | 1 | 2025-11-03 | 57 |
| `square_GOCH_1_1.xml` | GOCH | 1 | 2023-07-31 | 26 |
| `square_HAMS_1_1.xml` | HAMS | 1 | 2024-11-04 | 3 |
| `square_HDBC_1_1.xml` | HDBC | 1 | 2015-11-22 | 2 |
| **`square_METR_1_1.xml`** | **METR** | 1 | 2025-02-01 | **209** |

RRTR started most recently, so RRTR's service is kept and the other four —
including Metrobus's 209 journeys — are discarded as "superseded revisions" of
a service they have nothing to do with. The twelve Metrobus files dropped are
exactly the ones with short numeric codes: 98, 1, 10, 93, 100, 281, 2, 21, 32,
318, 690, 695, between them **876 of Metrobus's 2,892 journeys, 30%**.

### How much the collision costs, and how much is legitimate

The filter removes a great deal that it *should* remove — genuinely superseded
revisions — so the bug has to be separated from the intended behaviour. The
fix was applied to `UK2GTFS` and the real function run twice over every TNDS
region, once at the committed version and once patched, so what follows is the
behaviour of the code rather than a simulation of it:

| Region | Journeys kept, current key | Journeys recovered | Files recovered | % of region | Newly dropped |
|---|---:|---:|---:|---:|---:|
| **SE** | 168,905 | **5,529** | 152 | **3.27%** | 0 |
| EM | 86,615 | 711 | 10 | 0.82% | 0 |
| W | 55,506 | 299 | 14 | 0.54% | 0 |
| Y | 88,480 | 419 | 19 | 0.47% | 0 |
| EA | 20,534 | 0 | 0 | 0.00% | 0 |
| L | 487,597 | 0 | 0 | 0.00% | 0 |
| NE | 63,854 | 0 | 0 | 0.00% | 0 |
| NW | 152,462 | 0 | 0 | 0.00% | 0 |
| S | 153,416 | 0 | 0 | 0.00% | 0 |
| SW | 145,810 | 0 | 0 | 0.00% | 0 |
| WM | 109,675 | 0 | 0 | 0.00% | 0 |
| **National** | **1,532,854** | **6,958** | **195** | **0.454%** | **0** |

So the collision costs **0.454% of TNDS nationally** and **3.27% of the South
East**. An earlier draft of this report put those at 0.48% and 3.43% from a
standalone simulation of rules 1 to 3; the implementation recovers slightly
less, and these are the numbers to use. For comparison, the filter as a whole
removes 10.3% of the South East and 15.6% of Scotland; the great majority of
that is correct, and only the 3.3 points above are the bug.

**Nothing that the old key kept is dropped by the new one** — zero files in
every region, which is not luck: a finer key can only split a group, and each
sub-group then keeps its own operative version. Of the 195 files that now
survive rules 1 to 3, rule 4 removes exactly **one** as a genuine duplicate
registration, so these are overwhelmingly real services rather than
resurrected copies.

Seven of eleven regions are untouched, because the damage depends on a
publishing convention: West Midlands codes look like `33-74-S-y11-46` and
collide with nothing, while the South East's "square" publisher uses bare
route numbers. Those seven are exactly the seven that an independent scan of
all 17,345 file headers found to contain no `ServiceCode` shared between
operators — two methods agreeing. 101 `ServiceCode`s in the South East are
used by more than one operator, 16 in Yorkshire, 13 in Wales and 6 in the East
Midlands; 137 in all, covering 399 files and 20,371 journeys.

**The fix**, now applied: key rules 1 to 3 on the operator as well as the
`ServiceCode`. The operator is taken as the whole set of
`NationalOperatorCode` values a file declares, sorted — not the first one
listed — so that a jointly registered service is not split by the order its
file happens to list its operators in. Rule 4, the overlap resolution,
deliberately keeps using the first code alone: being lenient there costs a
surviving duplicate, whereas being lenient in rules 1 to 3 costs real service.
Three tests were added to `test_txc_filter.R`; the first fails on the
committed code, and the other two pass on it, so they are regression guards
rather than restatements of the fix.

Half a percent nationally is not what makes this worth fixing. What makes it
worth fixing is that it does not fall evenly: it removes **whole route
networks from whole towns**, as it does to Metrobus at Crawley, where 30% of
one operator's service and five of its town routes disappear. A national
average conceals exactly the kind of local error that a zone-level analysis is
built to find — and did find, and attributed to the wrong cause.

#### What the fix does not reach

Operators reuse codes among their *own* services too, and the operator key
cannot see that. South East `ServiceCode` 9 is published twice by Arriva Kent
and Surrey on the same licence: `square_AKSS_9_9.xml` is Grove Green to
Maidstone with 72 journeys from 2024-02-18, and `square_AKSS_9_9_1.xml` is
Grain to the Hundred of Hoo Academy with 4 journeys from 2025-04-27. Two
different routes, one code, one operator. That pair survives the new key only
by accident — the second file omits its `NationalOperatorCode` altogether, so
the two key apart anyway.

Measured as files that rules 2 and 3 delete while publishing a line number
nothing else in their group publishes, this residual is **23 files and 1,002
journeys (0.06%)** after the fix, against 35 files and 1,190 journeys before
it, concentrated in Wales (913 journeys, Arriva Cymru's per-depot files) and
the South East. It is a lower bound, since a file can be wrongly deleted
without taking a whole line number with it.

Extending the key to the description would catch these, and would be the wrong
trade: publishers retype the description with every re-registration — the very
reason `normalise_description()` exists — so a description in the key would
stop genuine supersession being detected and put duplicates back into the
feed. Left as a known limitation.

### (c) And sometimes the service is not missing — the other source has it twice

Birmingham (LSOA E01033620) is the largest single disagreement in the whole
LSOA analysis, and the LSOA report calls it "journeys missing from TNDS". That
verdict is the wrong way round.

Route 74, at stop `43000955906`, on Wednesday 5 August 2026:

| | TNDS | BODS GTFS |
|---|---:|---:|
| Calls at the stop | 210 | **419** |
| Distinct departure times | 201 | 304 |
| Times with more than one departure | 4% | **34%** |
| `service_id`s involved | 1 | **2** |

BODS GTFS carries `route_id` 6860 under two calendars covering identical
dates:

| `service_id` | Days | Dates | Trips |
|---|---|---|---:|
| 90 | Mon–**Fri** | 2026-07-26 → 2027-04-26 | 417 |
| 3194 | Mon–**Thu** | 2026-07-26 → 2027-04-26 | 419 |

At 14:04 the feed has three departures from one stop. The two services share
only 103 of 535 itineraries exactly, so they are two *registrations* of one
timetable rather than clean copies — which is why `gtfs_deduplicate()` cannot
touch them, and why the LSOA report's duplicate measure, which requires an
exact match, reports Birmingham at only 0.9%.

That pair is not the whole story, and the test that showed it is worth
recording because it failed. If services 90 and 3194 were the only overlap,
Friday — when 3194 does not run — should have fallen back to the TNDS level.
It does not:

| Date | Day | TNDS | BODS GTFS | Ratio |
|---|---|---:|---:|---:|
| 2026-08-03 | Mon | 210 | 419 | 2.00 |
| 2026-08-04 | Tue | 210 | 419 | 2.00 |
| 2026-08-05 | Wed | 210 | 419 | 2.00 |
| 2026-08-06 | Thu | 210 | 419 | 2.00 |
| 2026-08-07 | **Fri** | 210 | **421** | **2.00** |
| 2026-08-08 | Sat | 184 | 249 | 1.35 |
| 2026-08-09 | Sun | 136 | 208 | 1.53 |

So the duplication is not one stray calendar. Listing every service that
contributes a call at that stop settles it:

| Day | TNDS, `route_id` 13607 | BODS GTFS, `route_id` 6860 |
|---|---|---|
| Wed | `1978` 209 + `1971` 1 = **210** | `90` 210 + `3194` 209 = **419** |
| Fri | `1978` 209 + `1971` 1 = **210** | `1863` 211 + `90` 210 = **421** |
| Sat | `1963` 183 + `1971` 1 = **184** | `367` 249 = **249** |

**Each BODS service on its own carries a whole day's timetable.** Service 90
contributes 210 calls, 3194 contributes 209, 1863 contributes 211 — and TNDS's
entire Wednesday is 210. BODS pairs two of them on every weekday, swapping
3194 for 1863 on Friday, which is why the Friday prediction failed: the
duplicate partner changes rather than disappearing. One feed is describing
each bus twice, and the other is not.

Saturday is a different fault in the same feed. There BODS runs a single
service, 367, so nothing is paired — yet it holds 249 calls against TNDS's 184,
and **65 of its 180 distinct departure times carry more than one departure**.
That is duplication *inside* one registration rather than between two.

The two TransXChange renderings agree with each other and disagree with the
DfT's GTFS, which is the signature of the GTFS being the odd one out: TNDS
134,556 trip-runs in that zone, BODS TransXChange via `UK2GTFS` 126,768, BODS
GTFS 208,620. `txc_filter_files()`'s overlap resolution removes one of the two
registrations; the DfT's export keeps both.

## What this means for a definitive count

No single source gives one. They fail in different directions and the failures
are now identified well enough to say what a correct count would require.

1. **Reconcile overlapping registrations on the TransXChange, not the GTFS.**
   The identity needed — `ServiceCode`, `RevisionNumber`, `OperatingPeriod`,
   operator — exists only before conversion. Any GTFS-level deduplication is
   working with the evidence already destroyed. This is the single biggest
   determinant of the answer, and it is why the DfT's GTFS counts more than
   either TransXChange rendering.
2. **Fix the `ServiceCode` collision first — done.** Keyed on code alone, the
   reconciliation that should be the strength of the TransXChange route was
   also silently deleting unrelated operators' services — 3.27% of the South
   East, and whole route networks in individual towns. Rules 1 to 3 are now
   keyed on the operator as well, which recovers 6,958 journeys and drops
   nothing, and that was a precondition for trusting the route recommended in
   point 1.
3. **Match the counting window to the source's validity.** A 28-day window
   from a TNDS snapshot runs past some operators' registration horizon. Either
   shorten the window, or take the window from a source with a forward horizon
   and accept that it describes a timetable that had not yet started.
4. **Loosen the journey signature where it is safe.** Ignoring `arrival_time`
   is a free correctness gain, worth 0.137% of a feed. It is not the answer to
   duplication but there is no reason to leave it.
5. **Validate against published timetables.** Only `pdf_validation.md` and the
   route-level validation reports settle a case from outside the feeds, and
   they cover a handful of services. Every conclusion above about *which*
   source is right rests on internal consistency between three renderings. The
   Preston–Bolton 125 is the one case where a published document decides it,
   and it decided against TNDS.

### Which source to count from, on this evidence

The honest ordering is uncomfortable, because the two sources fail at opposite
ends and neither failure is small where it occurs.

**For a level** — how much bus service a place has — the TransXChange route is
the better baseline *in the places where overlapping registrations occur*, but
the national qualifier this section used to carry has now been measured and
does not hold.

The collision is fixed (October 2026) and the national ratio has moved from
0.94 to **0.95**. The overlapping-registration error has been counted: it is
**1.80%** of BODS GTFS's bus trip-days against **1.26%** of TNDS's, so it
accounts for roughly half a percentage point of the remaining 5.4% gap, not
the bulk of it. The earlier wording — that the 0.94 ratio "should not be read
as TNDS being 6% short until that is counted" — was too generous to TNDS. It
is now counted, and most of the gap *is* TNDS being short: principally its
lack of a forward horizon (18.0% of its bus journeys stop before the 28-day
window closes, against 6.2% in the DfT's GTFS) and residual missing
registrations such as the eight Metrobus services still absent from Crawley
and Gatwick after the fix.

Where overlapping registrations *do* bite they dominate, and the West Midlands
is the clear case: 64% of the disagreement in seven zones of the national top
fifteen. So the ordering is regional rather than national — prefer TNDS in the
West Midlands and the other operators listed in `lsoa_disagreement.md`, prefer
the DfT's GTFS where the question is whether a service exists at all.

**For a trend** — how service changed between years — the risk is the
opposite. TNDS's within-window decay varies from −0.3% to −10.2% between
years, so the measurement error moves with the year being measured. A
comparison between 2018 and 2021 inherits roughly five points of that
difference before any real change is counted. Where a trend matters, either
measure every year over a window short enough that no registrations expire, or
correct each year by its own first-week level.

**Neither** should be used as a national total without the caveat that a
journey crossing several zones is counted in each, which is a property of the
zone counting rather than of the sources.

## What is not established

- **The BODS TransXChange deficit of 63% is not fully accounted for.** Part is
  the deliberate overlap reconciliation of section 1, part is London (absent
  from that archive entirely), and part is the `ServiceCode` collision of
  section 3(b) acting on the same archive. The split between those three has
  not been measured.
- ~~**Whether the Birmingham pattern generalises.**~~ **Measured, October
  2026 — see `lsoa_disagreement.md`, "The West Midlands cluster".** The
  mechanism is an overlapping pair of weekday calendars on one date span: a
  Monday–Friday `service_id` alongside a Monday–Thursday one and a Friday-only
  one, so every weekday is published twice. It holds across National Express
  West Midlands routes 6, 14, 74 and 97, not just the 74, which is why all 46
  services shared at the Birmingham stop clusters read 1.6–2.1 times higher in
  BODS GTFS. Removing the redundant calendars closes **64% of the
  disagreement** in the seven West Midlands zones among the national top
  fifteen (285,099 runs to 103,674).

  The national answer, though, is **no — it does not generalise enough to
  change the baseline**, and the guess above was wrong in two ways. Nationally
  the pattern covers 385 of BODS GTFS's 12,331 bus routes (3.1%), holding 7.7%
  of its bus trip-days, and the redundant trip-days are **1.80%** of its bus
  total. And TNDS has the same pattern, on more routes (798) though less
  volume: **1.26%**. The net effect is about half a percentage point of the
  5.4% national gap. So "BODS counts more" does *not* become "BODS counts
  twice" nationally; it does in the West Midlands, because National Express
  West Midlands alone contributes 43 routes and 244,864 trip-days of it and
  those routes converge on the stop clusters that top the zone table. The
  concentration, not the national share, is what makes it decisive.
- **Why Saturday differs.** On Saturday BODS runs one service and still shows
  65 of 180 times doubled. Duplication inside a single registration is a third
  mechanism, distinct from the two this report traces, and it is not explained
  here.
- **Whether the other high-duplication zones share the Chelmsford cause.**
  Only E01034091 was checked trip by trip.
- **Which of the two Birmingham registrations is the real timetable.** The
  argument here is that two cannot both be, not that TNDS picked the right
  one.
