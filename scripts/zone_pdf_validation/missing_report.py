"""reports/missing_timetables.md: the documents the zone check could not get."""
import paths
import json, collections, html
import pandas as pd

SP = paths.WORK
REPO = paths.REPO
m = json.load(open(SP + 'missing.json'))
ops = json.load(open(SP + 'ops.json'))
svc_op = ops.pop('_svc')

# Operators and areas that bustimes could not resolve from the zone's stops,
# named from the feeds' own route descriptions and the area's operators.
MANUAL = {
 ('E01004513', None): ('TfL', 'Wandsworth (Mapleton Road)'),
 ('E01002968', 'K3'): ('TfL', ''), ('E01033620', '7'): ('unknown', ''),
 ('E01033620', '16'): ('National Express West Midlands', ''),
 ('E01009757', '1'): ('unknown', ''), ('E01009757', '6'): ('unknown', ''),
 ('E01034313', '1'): ('unknown', ''), ('E01034313', '3'): ('unknown', ''),
 ('E01035376', '4'): ('unknown (Chester)', ''), ('E01035378', '4'): ('unknown (Chester)', ''),
 ('E01032930', '4'): ('unknown (Chester)', ''),
 ('S01016759', 'X58'): ('Stagecoach East Scotland', ''), ('S01016759', 'X61'): ('Stagecoach East Scotland', ''),
 ('E01013453', 'vil'): ('trentbarton (villager)', ''), ('E01029428', 'vil'): ('trentbarton (villager)', ''),
 ('E01032896', 'vil'): ('trentbarton (villager)', ''), ('E01034256', 'vil'): ('trentbarton (villager)', ''),
 ('E01034256', 'SWI'): ('trentbarton (swift)', ''), ('E01034256', '2'): ('unknown (Derby)', ''),
 ('E01032896', '8'): ('unknown (Burton)', ''), ('E01033415', 'TVP'): ('Reading Buses (Thames Valley Park)', ''),
 ('E01033415', '15a'): ('Reading Buses', ''), ('E01033140', '702'): ('unknown (Chelmsford)', ''),
 ('E01034092', '702'): ('unknown (Chelmsford)', ''), ('E01034092', '47'): ('unknown (Chelmsford)', ''),
}
TFL_OPS = {'London Central', 'Metroline Travel', 'Transport UK', 'Stagecoach London', 'First Bus London',
           'Arriva London', 'London General'}

rows = []
for x in m:
    if x['services']:
        sl = x['services'][0][0]
        title = html.unescape(x['services'][0][1])
        op = title.split(' – ')[-1]
        # Chester's route 1 is two services; the zone table's description says Wrexham - Chester
        for s2, t2 in x['services']:
            if 'Wrexham' in t2 and 'Wrexham' in (x['long_name'] or ''):
                sl, title, op = s2, html.unescape(t2), html.unescape(t2).split(' – ')[-1]
        link = f'https://bustimes.org/services/{sl}'
    else:
        k = (x['zone'], x['route']) if (x['zone'], x['route']) in MANUAL else (x['zone'], None)
        op = MANUAL.get(k, ('unknown', ''))[0]
        link = f"https://bustimes.org/search?q={x['route']}"
    if op in TFL_OPS or op == 'TfL':
        group = 'TfL'
    elif op.startswith('Stagecoach') or op.startswith('Arriva') or 'Blackburn' in op:
        group = 'blocked'
    elif op.startswith('trentbarton'):
        group = 'trentbarton'
    elif op == 'National Express West Midlands':
        group = 'NXWM'
    elif op in ('Diamond Bus', 'Diamond Bus East Midlands', 'Vision Bus'):
        group = 'other'
    else:
        group = 'unidentified'
    rows.append(dict(group=group, zone=x['zone'], locality=x['locality'], route=x['route'], op=op,
                     gap=x['gap'], tnds=x['tnds'], bods=x['bods'], link=link, desc=x['long_name'] or ''))
d = pd.DataFrame(rows)
# Held already, in a document shared with another route; their gap here is the
# reader's (the zone has no timing point of its own), not a missing document.
HELD = {('NXWM', 'X8'), ('NXWM', '97A'), ('NXWM', '8'), ('unidentified', '4a'), ('unidentified', '50a')}
d = d[~d.apply(lambda r: (r.group, r.route) in HELD, axis=1)]
d.loc[d.route.isin(['TVP', '15a']), 'group'] = 'other'


def agg(g):
    out = []
    for (route, op), x in g.groupby(['route', 'op'], sort=False):
        out.append(dict(route=route, op=op, places='; '.join(sorted(set(x.locality))),
                        zones=', '.join(sorted(set(x.zone))), gap=x.gap.max(), link=x.link.iloc[0]))
    return pd.DataFrame(out).sort_values('gap', ascending=False)


def table(g, extra=None):
    a = agg(g)
    lines = ['|Route|Operator|Where (zones)|Largest zone difference|Service page|' + ('|'.join(extra[0]) + '|' if extra else ''),
             '|:--|:--|:--|--:|:--|' + (':--|' * len(extra[0]) if extra else '')]
    for _, r in a.iterrows():
        ex = '|'.join(f(r) for f in extra[1]) + '|' if extra else ''
        lines.append(f"|{r.route}|{r.op}|{r.places} ({r.zones})|{r.gap:,.0f}|[bustimes]({r.link})|{ex}")
    return '\n'.join(lines), len(a)


tfl_t, n_tfl = table(d[d.group == 'TfL'], (['TfL timetable'], [lambda r: f'[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/{r.route}/)']))
SITE = {k: (v[1][0] if v[1] else '') for k, v in ops.items()}
OP_SITE = {v[0]: (v[1][0] if v[1] else '') for k, v in ops.items()}
OP_SITE.setdefault('Stagecoach East Scotland', 'https://www.stagecoachbus.com')
bl_t, n_bl = table(d[d.group == 'blocked'], (['Operator site'], [lambda r: f'[{r.op}]({OP_SITE.get(r.op, "")})' if OP_SITE.get(r.op) else '']))
nx_t, n_nx = table(d[d.group == 'NXWM'])
tb_t, n_tb = table(d[d.group == 'trentbarton'])
ot_t, n_ot = table(d[d.group == 'other'])
un_t, n_un = table(d[d.group == 'unidentified'])

text = f"""# Timetables the zone check could not get

`pdf_validation.md` checks the 60 zones of `lsoa_disagreement.md` against
operators' published timetables. This is the list of documents it needed and
could not collect automatically, with links, so they can be fetched by hand
and dropped into `data/example_timetables/`. Each entry is a route that
carries 1,000 trip-runs or more of a zone's TNDS-versus-BODS GTFS difference
and has no checked document yet. Routes already checked in another zone of the
same area are left out.

**What to fetch.** The edition in force for the counting window, **27 July –
23 August 2026**, if the operator still has it; otherwise the current one
(say which in the file name). A whole week — Monday–Friday (or Monday–Thursday
and Friday), Saturday and Sunday — and, where the operator prints schooldays and
school holidays separately, the **school-holiday** version, since the window
falls in the summer holidays. For TfL routes, the running schedules in the
same form as the `Schedule_<route>-<day>.pdf` files already in the folder.

Service pages are on bustimes.org, which names the operator and links to its
site; the operator links are the ones bustimes gives. Where a route could not
be matched to a service at the zone's stops, the link is a bustimes search.

## 1. TfL running schedules ({n_tfl} routes)

TfL's website and its open-data bucket refuse requests from the environment
the collection ran in. The schedules for 20, 167, 215, 216, 235, 275, 406
and 462 were already in the folder and are checked; these are the rest. They
cover Wandsworth (Mapleton Road), Southall, Harrow, the City (Barbican),
Hackney (Moulins Road), Kingston, Epsom, Sunbury and Loughton.

TfL publishes them as bus route schedules
(<https://tfl.gov.uk/corporate/publications-and-reports/bus-schedules>, from a
web search; not opened from here). Needed day types: `MF` (or `MFHo` where
there is a schools/holidays split), `Sa`, `Su`, plus `Fr` where it exists.

{tfl_t}

## 2. Operators behind a browser check ({n_bl} routes)

Stagecoach, Arriva and Transdev serve their sites through a challenge page
that needs a host this environment's network policy blocks, so nothing could
be fetched from them. These cover Chester, Portsmouth's Stagecoach routes,
Preston and Leven.

{bl_t}

## 3. National Express West Midlands routes not collected ({n_nx} routes)

These were not collected. The 16 (Birmingham – Hamstead) page has no
timetable widget, and the 530 download failed; the rest were not on the NXWM
service list that was crawled. The PDFs come from each route's page on
<https://nxbus.co.uk/west-midlands/services-timetables>, with the "Download
timetable PDF" button in the embedded timetable. They are the current edition
only. The summer edition (from 19 July 2026), which is what the window needs,
can't be got from the site any more: if you have copies of the summer
editions, those would be better still.

{nx_t}

## 4. trentbarton, Derby – Burton ({n_tb} routes)

trentbarton's PDFs have no text layer. The Word extracts already in the folder
(`Trentbarton X38.docx` and others) are the format that reads. For
villager, swift and the X38, a Word or text extract of the timetable is what
is needed.

{tb_t}

## 5. Other operators ({n_ot} routes)

Diamond Bus's site is reachable. The PDFs for its **40, 42 and 9** were
downloaded while this list was compiled and are now in the folder
(`diamond_40-wednesburytimetable-310526.pdf`, `diamond_h42-timetable-310825.pdf`,
`diamond_9-airway_timetable_091125.pdf`), but **they have not been read yet**.
The 31 and 32 pages
(<https://www.diamondbuses.com/bus-services/wm/wm31-walsall/>,
<https://www.diamondbuses.com/bus-services/wm/wm32-walsall/>) offer only a
print view, not a PDF. Vision Bus's 45 has an
on-screen timetable and no PDF that could be found
(<https://www.visionbus.co.uk/route?service=45>). Reading Buses' Thames Valley
Park (TVP) and 15a are not in the operator's PDF archive at all.

{ot_t}

## 6. Routes whose operator could not be identified ({n_un} routes)

No service with this number was found at the zone's stops on bustimes. That
usually means a route that has since been renumbered or withdrawn, or a
number the feeds use differently from the operator.

{un_t}

## 7. Earlier editions that would firm up existing checks

Not missing, but the checks they support would be stronger with them.
National Express West Midlands and First (Essex, Portsmouth, Wessex) publish
only the current timetable, so most of their checks use editions from 30
August – 27 September 2026, after the window. The summer editions would
replace them:

* NXWM summer timetables "from 19th July 2026" for every route in
  `data/zone_pdf_validation.csv` marked `later edition`;
* First Essex (Chelmsford C1–C10, X10, X30, 170, 333, 336, 351, 700), First
  Portsmouth (1, 2, 3, 7, 8, X3) and First Wessex (Weymouth 1, 2, 4, 8, 10)
  editions valid on 27 July 2026. The current ones say "Valid from 31/08/2026"
  or later.

The Wayback Machine (`web.archive.org`) may hold them, but it is also blocked
from the collection environment.
"""
open(REPO + 'reports/missing_timetables.md', 'w').write(text)
print(d.group.value_counts())
