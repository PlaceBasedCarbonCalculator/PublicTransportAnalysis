"""Write the new pdf_validation section and its data file."""
import paths
import math, collections
import pandas as pd
import assemble, gen_report as G

SP = paths.WORK
REPO = paths.REPO

AREA_ORDER = ['Birmingham city centre', 'Black Country', 'Chelmsford', 'Weymouth', 'Reading',
              'Crawley and Gatwick', 'Hull', 'Portsmouth', 'Edinburgh', 'North-east London',
              'Kingston, Sunbury and Epsom', 'Preston and Chorley', 'Brighton', 'Aylesbury',
              'Southampton', 'Swansea']


def r2(x):
    return '—' if x is None or (isinstance(x, float) and math.isnan(x)) else f'{x:.2f}'


def n0(x):
    return '—' if x is None or (isinstance(x, float) and math.isnan(x)) else f'{x:,.0f}'


def tally(df):
    t = collections.Counter()
    for v in df.verdict:
        if v in ('TNDS right', 'BODS GTFS absent'):
            t['TNDS'] += 1
        elif v in ('BODS GTFS right', 'TNDS absent'):
            t['BODS'] += 1
        elif v == 'both agree':
            t['both'] += 1
        elif 'TNDS closer' in v or v == 'BODS GTFS absent; TNDS off':
            t['neither_T'] += 1
        else:
            t['neither_B'] += 1
    return t


def area_table(rel):
    rows = []
    for ar in AREA_ORDER:
        d = rel[rel.area == ar]
        if d.empty:
            continue
        t = tally(d)
        tm = d.t_ratio.median(); bm = d.b_ratio.median()
        rows.append(dict(area=ar, zones=d.zone.nunique(), routes=len(d),
                         t=tm, b=bm, tn=t['TNDS'], bo=t['BODS'], ne=t['neither_T'] + t['neither_B'],
                         eds=', '.join(sorted(set(d.edition_status)))))
    df = pd.DataFrame(rows)
    return G.md_table(df, ['area', 'zones', 'routes', lambda r: r2(r.t), lambda r: r2(r.b), 'tn', 'bo', 'ne', 'eds'],
                      ['Area', 'Zones', 'Checks', 'TNDS ÷ doc (median)', 'BODS GTFS ÷ doc (median)',
                       'TNDS right', 'BODS GTFS right', 'Neither', 'Editions'],
                      [':--', '--:', '--:', '--:', '--:', '--:', '--:', '--:', ':--']), df


def route_table(c):
    d = c.copy()
    d['ord'] = d.area.map({a: i for i, a in enumerate(AREA_ORDER)})
    d = d.sort_values(['ord', 'locality', 'route'])
    return G.md_table(d, ['zone', 'locality', 'route', 'edition_status', lambda r: n0(r.pdf), lambda r: n0(r.tnds),
                          lambda r: n0(r.bods), lambda r: r2(r.t_ratio), lambda r: r2(r.b_ratio),
                          lambda r: r.verdict + ('' if r.reliable else ' (unreliable reading)')
                          + ('' if r.basis == 'counted at the zone' else ' †')],
                      ['Zone', 'Locality', 'Route', 'Edition', 'Document', 'TNDS', 'BODS GTFS', 'TNDS ÷ doc',
                       'BODS ÷ doc', 'Verdict'],
                      [':--', ':--', ':--', ':--', '--:', '--:', '--:', '--:', '--:', ':--'])


def zone_table(rel, zv):
    rows = []
    for z, d in rel.groupby('zone'):
        t = tally(d)
        cov = d.gap_route.sum() / max(abs(zv[z]['gap']), 1)
        # the zone's own reading: who the document sides with, weighted by how
        # much of the zone's disagreement each route carries
        w = collections.Counter()
        for _, r in d.iterrows():
            v = r.verdict
            k = ('TNDS' if v in ('TNDS right', 'BODS GTFS absent') else
                 'BODS GTFS' if v in ('BODS GTFS right', 'TNDS absent') else
                 'TNDS (closer)' if ('TNDS closer' in v or v == 'BODS GTFS absent; TNDS off') else 'BODS GTFS (closer)')
            w[k] += r.gap_route
        side = max(w, key=w.get)
        rows.append(dict(zone=z, loc=zv[z]['locality'], gap=zv[z]['gap'], lv=zv[z]['verdict'], n=len(d),
                         share=min(cov, 9.99), side=side))
    df = pd.DataFrame(rows).sort_values('gap')
    return G.md_table(df, ['zone', 'loc', lambda r: n0(r.gap), 'lv', 'n', lambda r: f'{r.share:.0%}', 'side'],
                      ['Zone', 'Locality', 'Difference', 'Verdict in lsoa_disagreement.md', 'Routes checked',
                       "Checked routes' difference ÷ zone's", 'Document sides with'],
                      [':--', ':--', '--:', ':--', '--:', '--:', ':--']), df


def documents_table(c):
    d = c[c.basis == 'counted at the zone'].copy()
    src = {'National Express West Midlands': 'nxbus.co.uk timetable PDFs (generated on download)',
           'Reading Buses': 'operator PDFs, passenger-line-assets archive', 'East Yorkshire': 'operator PDFs, passenger-line-assets archive',
           'Brighton & Hove': 'operator PDFs, passenger-line-assets archive', 'Bluestar': 'operator PDFs, passenger-line-assets archive',
           'Redline': 'operator PDFs, passenger-line-assets archive', 'Metrobus': 'operator PDFs, passenger-line-assets archive (scanned; read by OCR)',
           'First Bus': 'firstbus.co.uk timetable PDFs', 'Lothian': 'lothianbuses.com timing sheets',
           'TfL contract': 'TfL running schedules (already in the folder)', 'Stagecoach': 'operator PDF (already in the folder)'}
    rows = []
    for op, x in d.groupby('operator'):
        rows.append(dict(op=op, src=src.get(op, ''), n=x.doc.nunique(), eds=', '.join(sorted(set(x.edition_status)))))
    return G.md_table(pd.DataFrame(rows), ['op', 'src', 'n', 'eds'], ['Operator', 'Source', 'Documents', 'Editions'],
                      [':--', ':--', '--:', ':--'])


if __name__ == '__main__':
    from verdict import zone_verdicts
    zv = zone_verdicts()
    a = assemble.main()
    c, rel = G.build(a)
    c.to_pickle(SP + 'checks.pkl')
    out = c.copy()
    out['days'] = out['days'].astype(str)
    cols = ['zone', 'locality', 'area', 'route', 'operator', 'document', 'edition', 'edition_status', 'basis',
            'days', 'pdf', 'tnds', 'bods', 't_ratio', 'b_ratio', 'verdict', 'reliable', 'zone_verdict']
    out[cols].rename(columns={'pdf': 'document_window', 't_ratio': 'tnds_over_doc', 'b_ratio': 'bods_over_doc',
                              'days': 'document_journeys_per_day', 'zone_verdict': 'lsoa_verdict'}) \
        .to_csv(REPO + 'data/zone_pdf_validation.csv', index=False)
    at, adf = area_table(rel)
    zt, zdf = zone_table(rel, zv)
    print(documents_table(c)); print(); print(at); print(); print(zt)
    print(tally(rel), len(rel), rel.zone.nunique())
    adf.to_pickle(SP + 'area.pkl'); zdf.to_pickle(SP + 'zones.pkl')
    open(SP + 'route_table.md', 'w').write(route_table(c))
    open(SP + 'area_table.md', 'w').write(at)
    open(SP + 'zone_table.md', 'w').write(zt)
    open(SP + 'docs_table.md', 'w').write(documents_table(c))
