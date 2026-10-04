"""Compose the new pdf_validation section from the checks and tables."""
import paths
import collections, math
import pandas as pd
import section as S

SP = paths.WORK
c = pd.read_pickle(SP + 'checks.pkl')
rel = c[c.reliable]
zdf = pd.read_pickle(SP + 'zones.pkl')
t = S.tally(rel)
N = len(rel); NZ = rel.zone.nunique(); NDOC = c[c.basis == 'counted at the zone'].doc.nunique()
NUNREL = int((~c.reliable).sum())
n_ext = int((rel.basis != 'counted at the zone').sum())


def med(area, col):
    return rel[rel.area == area][col].median()


def cnt(area, cond):
    d = rel[rel.area == area]
    return int(cond(d).sum()), len(d)


def within(d, col, tol=0.15):
    return ((d[col] - 1).abs() <= tol)


side = collections.Counter(zdf.side)
gap_by_side = zdf.assign(g=zdf.gap.abs()).groupby(zdf.side.str.replace(' (closer)', '', regex=False)).g.sum()
tot_gap = zdf.gap.abs().sum()

# How the document reading lines up with the zone verdicts of lsoa_disagreement.md
xt = collections.Counter()
for _, r in zdf.iterrows():
    s = r.side.replace(' (closer)', '')
    lv = r.lv
    if lv in ('journeys missing from TNDS', 'TNDS calendars cut short', 'absent from TNDS'):
        xt['TNDS blamed, doc agrees' if s == 'BODS GTFS' else 'TNDS blamed, doc disagrees'] += 1
    elif lv in ('journeys missing from BODS GTFS', 'absent from BODS GTFS'):
        xt['BODS blamed, doc agrees' if s == 'TNDS' else 'BODS blamed, doc disagrees'] += 1
    else:
        xt['unresolved -> ' + r.side] += 1

bh = rel[rel.area.isin(['Birmingham city centre', 'Black Country'])]
bh_t = int(within(bh, 't_ratio').sum()); bh_b_lo, bh_b_hi = bh.b_ratio.quantile(0.1), bh.b_ratio.quantile(0.9)
summer = rel[(rel.area == 'Birmingham city centre') & (rel.edition_status == 'in force') & (rel.route != '50')]
ch = rel[rel.area.isin(['Chelmsford', 'Weymouth'])]
rd = rel[rel.area == 'Reading']; rd_b = int(within(rd, 'b_ratio').sum())
hu = rel[rel.area == 'Hull']; hu_b = int(within(hu, 'b_ratio', 0.05).sum())
po = rel[rel.area == 'Portsmouth']; po_t = int(within(po, 't_ratio', 0.02).sum())
ed = rel[rel.area == 'Edinburgh']; ed_t = int(within(ed, 't_ratio').sum())
ne = rel[rel.area == 'North-east London']
ks = rel[rel.area == 'Kingston, Sunbury and Epsom']
cr = rel[rel.area == 'Crawley and Gatwick']
pc = rel[rel.area == 'Preston and Chorley']


def rng(d, col):
    return f'{d[col].min():.2f}–{d[col].max():.2f}'


docs_md = open(SP + 'docs_table.md').read()
area_md = open(SP + 'area_table.md').read()
zone_md = open(SP + 'zone_table.md').read()
route_md = open(SP + 'route_table.md').read()

cr_text = ''
if len(cr):
    cr_text = f"""
**Crawley and Gatwick: TNDS is missing the town network, and BODS GTFS is the
source to believe.** TNDS counts nothing for {int((cr.tnds == 0).sum())} of the
{len(cr)} Metrobus route-and-zone checks; BODS GTFS reads a median
{cr.b_ratio.median():.2f} of the documents — 1.00–1.08 on routes 3, 10, 200 and 400,
and 1.3–1.9 on the 2 and the 100, where the OCR reading is the likelier to
have dropped journeys. The documents are scans with no
text layer and were read by OCR, so these are the least precise counts in the
section, but an absence is not a matter of precision: the service exists, and
`lsoa_disagreement.md`'s "journeys missing from TNDS" stands.
"""

text = f"""## The zones where TNDS and BODS GTFS disagree most

`lsoa_disagreement.md` ranks the 60 zones where the choice between TNDS and the
DfT's BODS GTFS changes the answer most, and tries to say from the two feeds
alone which of them is wrong. It could only do that for half of them, and one of
its largest verdicts was later reversed. This section brings the operators' own
timetables to those zones instead: for the routes that carry each zone's
disagreement, how many journeys does the published timetable say pass through
the zone in the same counting window, and which feed is nearer that number?

### What was collected

{NDOC} documents covering the routes in {NZ} of the 60 zones, all now in
`data/example_timetables/`. They were collected for the routes that carry most
of each zone's difference: the search started from every route whose two
counts differ by 1,000 trip-runs or more in one of the zones, and for the
operators carrying many of them most of their routes into those zones were
collected.

{docs_md}

Where the operator keeps old editions, the edition in force for the window
(27 July – 23 August 2026) was used: Reading Buses, East Yorkshire, Brighton &
Hove, Bluestar, Metrobus and Redline all publish through a shared asset store
that keeps every revision, and Lothian dates its timing sheets in the file
name. National Express West Midlands and First publish only the current
edition, so most of their documents are the **autumn editions (30 August – 27
September 2026)**, a month or two after the window; the four NXWM routes
already in the folder from August (6, 14, 50, 74) are the summer edition and
are used for those. A later edition can differ from the window's by a few
journeys an hour; it cannot account for a factor of two, which is the size of
most of what follows.

Some documents could not be had. Stagecoach and Arriva sit behind a browser
check that the collection environment cannot pass, and TfL's own site refuses
it, so Chester, Leven and the TfL routes without a schedule already in the
folder (Wandsworth, Harrow, Southall, the City, Hackney) are not checked here;
trentbarton's PDFs for Derby and Burton have no text layer and were not read;
Darlington was not attempted.

### How the check works

* **The unit is the zone, not the route.** For each route the document is read
  at a timing point inside the zone — or, where the zone has none (Edinburgh's
  Salisbury Place and Drylaw, Southampton's Atherley Road), the adjacent one on
  the same corridor — counting every journey in either direction that calls
  there. That is the same quantity `lsoa_disagreement.md` counts: a vehicle
  journey touching the zone, once, however many of its stops it calls at.
* **Day types to window totals**: the window holds 16 Mondays–Thursdays, 4
  Fridays, 4 Saturdays and 4 Sundays and no English bank holiday, and it lies in
  the English and Welsh school holidays, so school-day-only journeys (First's
  `SCH`/`SD` columns) are dropped and TfL's non-schoolday schedules used.
* **Abbreviated periods are expanded** — "then every 10 minutes until",
  "at these minutes past each hour" — and a reading where an abbreviation could
  not be expanded is marked unreliable and left out of every count below
  ({NUNREL} rows). NXWM's "every 10 minutes **or less**" and Reading's "**up to**
  every 9 mins" are expanded at the printed headway, so those counts are a
  floor and a ceiling respectively.
* **One check per zone and route.** Where a route's TNDS and BODS GTFS counts
  in a second zone match its counts in the checked zone to within 2%, the same
  journeys pass both, so the check is carried over ({n_ext} of the {N} checks,
  marked † below).
* **A source is right when it is within 15% of the document.** Beyond that,
  the nearer of the two on a ratio scale (a reading of 0.5 is as far off as
  2.0) is recorded as closer, not right.

### What the documents say

Across {N} zone-and-route checks in {NZ} zones, the document matches **TNDS in
{t['TNDS']}** (including routes BODS GTFS does not carry) and **BODS GTFS in
{t['BODS']}** (including routes TNDS does not carry); in {t['neither_T'] + t['neither_B']}
neither source is within 15%, TNDS being the nearer in {t['neither_T']} and BODS
GTFS in {t['neither_B']}.

That headline hides the real result, which is that **the answer is decided by
place, almost without exception**: within an area one source is right on
nearly every route and the other wrong by the same factor on nearly every
route, because each mechanism is an operator's or a region's publishing
pattern rather than a property of individual timetables.

{area_md}

**Birmingham and the Black Country: TNDS is right, and BODS GTFS counts most
weekday buses twice.** TNDS is within 15% of the document on {bh_t} of the
{len(bh)} National Express West Midlands checks; BODS GTFS reads between
{bh_b_lo:.2f} and {bh_b_hi:.2f} of it on nine in ten of them. The summer-edition
routes other than the 50, whose documents were in force for the window, show
it most cleanly:
TNDS {rng(summer, 't_ratio')} of the document, BODS GTFS {rng(summer, 'b_ratio')}.
This is the overlapping Monday–Friday and Monday–Thursday/Friday calendars that
`lsoa_disagreement.md` measured on route 74, now confirmed against the
operator's own timetables in {len(bh)} checks; and NXWM's own autumn timetables are printed as
separate Monday–Thursday and Friday tables, the split that BODS GTFS turns into
a second copy of the week. Route 50 is the one exception: both sources read
about twice and three times the document at Moor Street, and why is not
established.

**Chelmsford and Weymouth: neither source is right, in opposite directions.**
TNDS reads {rng(ch, 't_ratio')} of the First Essex and First Wessex documents
(median {ch.t_ratio.median():.2f}) — its registrations stop after six days of the
twenty-eight — and BODS GTFS reads {rng(ch, 'b_ratio')} (median {ch.b_ratio.median():.2f}).
The BODS GTFS excess is larger than the 26–34% of duplicated journeys
`lsoa_disagreement.md` traced to `gtfs_deduplicate()` keeping copies that differ
only in arrival time at the first stop, so something else is inflating these
zones as well. These documents are September editions; the size of the
factors, not the exact ratios, is the finding. These are the zones that report
left "unresolved" because both feeds are wrong, and the documents agree with it.

**Reading: BODS GTFS is right, and TNDS counts one week of four.** BODS GTFS is
within 15% on {rd_b} of the {len(rd)} Reading Buses checks (median
{rd.b_ratio.median():.2f}), with documents in force for the window; TNDS reads a
median {rd.t_ratio.median():.2f}, the registrations ending on 2 August. This is the
one "TNDS calendars cut short" verdict, confirmed.

**Hull: BODS GTFS is right, TNDS is missing East Yorkshire.** TNDS carries none
of the {len(hu)} East Yorkshire routes checked at Hull Interchange except the
X46; BODS GTFS matches the documents to within 5% on
{hu_b} of {len(hu)}, and exactly on several. The zone was "unresolved".
{cr_text}
**Portsmouth: TNDS is right, and BODS GTFS overcounts.** TNDS matches First's
documents to the journey on {po_t} of {len(po)} checks (ratio 0.98–1.00);
BODS GTFS reads {rng(po[po.bods > 0], 'b_ratio')}. The zone verdict "journeys
missing from TNDS" is the wrong way round.

**Edinburgh: TNDS is right, and BODS GTFS carries half the service.** TNDS is
within 15% of Lothian's timing sheets on {ed_t} of {len(ed)} checks, exactly on
three; BODS GTFS reads {rng(ed, 'b_ratio')}, half or a little under on every
route. "Journeys missing from BODS GTFS" stands, and it is a uniform halving
rather than missing routes.

**North-east London: BODS GTFS is right, and TNDS counts every bus twice.**
Against TfL's running schedules BODS GTFS reads {rng(ne, 'b_ratio')} and TNDS
{rng(ne, 't_ratio')} on routes 20, 167, 215, 275 and 462. This is the exact-2.00
group of `lsoa_disagreement.md` — duplicate TNDS registrations — and the zones it
labelled "journeys missing from BODS GTFS" (Hainault Grove, Audleigh Place,
Loughton Station) are the wrong way round.

**Kingston, Sunbury and Epsom: TNDS is right, and BODS GTFS reads two to four
times the schedules.** TNDS {rng(ks, 't_ratio')}, BODS GTFS {rng(ks, 'b_ratio')}
on routes 216, 235 and 406 — the second London pattern, in the opposite
direction from the first. "Journeys missing from TNDS" is overturned.

**Preston and Chorley: neither, BODS GTFS nearer.** The 125 reads TNDS
{rng(pc, 't_ratio')} and BODS GTFS {rng(pc, 'b_ratio')} of the document at both
bus stations — the duplicate Stagecoach registration in TNDS found earlier in
this report, now seen at zone level.

**The rest are mixed, and mostly about coverage.** In Brighton, BODS GTFS lacks
routes 50, 12A and 18, which TNDS carries (50 to the journey), while TNDS lacks
the 20, which BODS GTFS carries to within 2%; on the shared routes BODS GTFS is
nearer. In Aylesbury, BODS GTFS carries none of Redline's 4, 130 and 300 and
TNDS reads 0.84–0.89 of them. In Swansea TNDS matches First Cymru's 4 and X6
and BODS GTFS has neither, as Welsh services need not appear in it. In
Southampton, read at Central Station for want of a timing point in the zone,
BODS GTFS matches Bluestar's 17 and reads the 18 half again high, while TNDS
reads 1.8–2.5 of both.

### What that means for the zone verdicts

Weighting each checked route by how much of its zone's difference it carries,
the documents find **TNDS right in {side['TNDS']} zones and BODS GTFS right in
{side['BODS GTFS']}**; in the other {side['TNDS (closer)'] + side['BODS GTFS (closer)']}
neither source is right, BODS GTFS being the nearer in {side['BODS GTFS (closer)']}
(Chelmsford, Weymouth, Preston, Chorley, Southampton) and TNDS in
{side['TNDS (closer)']}. By size, the zones where TNDS is right or nearer hold
{gap_by_side.get('TNDS', 0) / tot_gap:.0%} of the checked zones' combined difference and
those where BODS GTFS is hold {gap_by_side.get('BODS GTFS', 0) / tot_gap:.0%}.

Set against the verdicts in `lsoa_disagreement.md`:

* of the zones it blamed on **TNDS**, the documents agree in
  {xt['TNDS blamed, doc agrees']} and disagree in {xt['TNDS blamed, doc disagrees']} —
  every disagreement being a zone where BODS GTFS publishes more journeys than
  run (Birmingham, Portsmouth, Sunbury Cross, Epsom);
* of those it blamed on **BODS GTFS**, they agree in {xt['BODS blamed, doc agrees']}
  and disagree in {xt['BODS blamed, doc disagrees']} — the disagreements being
  TNDS's own duplicate registrations (north-east London, Chorley, Southampton);
* of the **unresolved** zones checked, the documents settle
  {xt['unresolved -> TNDS']} for TNDS (the Black Country bus stations, Kingston,
  Swansea) and {xt['unresolved -> BODS GTFS']} for BODS GTFS (Hull, Walthamstow
  and Woodford, Brighton's North Street), and confirm that in
  {xt['unresolved -> BODS GTFS (closer)'] + xt['unresolved -> TNDS (closer)']} more
  both sources are wrong at once — which is what "unresolved" was meant to say.

So the arithmetic in that report — journeys against operating days — reliably
finds *where* the feeds disagree and *what kind* of disagreement it is, but
"journeys missing from" one source is as often a duplicate in the other. The
caution already in that report — that a flat daily profile with a
journey-count gap should send the reader to the registrations before deciding
which source is short — is borne out: ten of the fifteen checked zones it
blamed on TNDS are the other way round.

{zone_md}

### Every check

`Edition`: *in force* is the edition valid for the window; *later edition*
started after it; *TfL schedule* is a TfL running schedule current in July
2026. † marks a check carried over from another zone with the same journeys.
The same table, with the per-day counts and the document file names, is in
`data/zone_pdf_validation.csv`.

{route_md}

### Limits

* A later edition is not the window's timetable. For NXWM and First the ratios
  are evidence of factors of two and four, not of exact agreement; where an
  in-force edition exists (NXWM 6, 14, 74) it agrees with the later one to
  within a few per cent.
* The reference timing point stands for the zone. Where the zone has no timing
  point of its own, the adjacent one on the same road is used, and a journey
  that turns off between them would be miscounted.
* Readings are mechanical, with expansion of abbreviated periods. The reader
  was checked against the route-level counts earlier in this report (NXWM 14
  and 6: within two journeys a day) and by hand on a few documents (First's
  C1, Reading's 5 and 17); readings it could not complete are excluded rather
  than estimated. The Metrobus documents are scans read by OCR.
* The zones not checked are mostly those whose operators could not be reached
  (Stagecoach, Arriva) and the London routes without a TfL schedule in the
  folder; the scripts that collected and read everything here
  are in `scripts/zone_pdf_validation/`.
"""
open(SP + 'section.md', 'w').write(text)
print(xt, side, len(text))
