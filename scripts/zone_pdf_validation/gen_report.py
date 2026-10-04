import paths
import math, collections
import pandas as pd
import assemble

SP = paths.WORK
REPO = paths.REPO

AREA = {
 'E01033620': 'Birmingham city centre', 'E01033617': 'Birmingham city centre', 'E01033561': 'Birmingham city centre',
 'E01033615': 'Birmingham city centre', 'E01034947': 'Birmingham city centre', 'E01010125': 'Birmingham city centre',
 'E01034313': 'Black Country', 'E01010102': 'Black Country', 'E01010106': 'Black Country', 'E01010368': 'Black Country',
 'E01009757': 'Black Country',
 'E01034091': 'Chelmsford', 'E01034092': 'Chelmsford', 'E01033140': 'Chelmsford', 'E01021592': 'Chelmsford',
 'E01021587': 'Chelmsford', 'E01021542': 'Chelmsford',
 'E01033415': 'Reading', 'E01033420': 'Reading',
 'E01031575': 'Crawley and Gatwick', 'E01031585': 'Crawley and Gatwick', 'E01031583': 'Crawley and Gatwick',
 'E01017032': 'Portsmouth', 'E01017034': 'Portsmouth', 'E01020554': 'Weymouth', 'E01033104': 'Hull',
 'E01016952': 'Brighton', 'E01016969': 'Brighton', 'E01017191': 'Southampton', 'E01032955': 'Aylesbury',
 'S01014636': 'Edinburgh', 'S01014958': 'Edinburgh', 'W01001955': 'Swansea',
 'E01004397': 'North-east London', 'E01021782': 'North-east London', 'E01021767': 'North-east London',
 'E01002968': 'Kingston, Sunbury and Epsom', 'E01030751': 'Kingston, Sunbury and Epsom',
 'E01034290': 'Kingston, Sunbury and Epsom',
 'E01003670': 'North-east London', 'E01003750': 'North-east London', 'E01004377': 'North-east London',
 'E01021766': 'North-east London', 'E01003673': 'North-east London',
 'E01024940': 'Preston and Chorley', 'E01033223': 'Preston and Chorley',
}
ED_RANK = {'in force': 0, 'TfL schedule': 0, 'in force to 7 Aug': 1, 'starts mid-window': 2, 'not stated': 3, 'later edition': 4}


def fmt(x, d=0):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return '—'
    return f'{x:,.{d}f}'


def checks(a):
    """One row per zone and route: the edition in force for the window where
    there is one, then the reliable reading."""
    a = a.copy()
    a['rank'] = a.edition_status.map(ED_RANK).fillna(5) + (~a.reliable) * 10
    return a.sort_values('rank').groupby(['zone', 'route'], as_index=False).first()


def md_table(df, cols, heads, align):
    out = ['|' + '|'.join(heads) + '|', '|' + '|'.join(align) + '|']
    for _, r in df.iterrows():
        out.append('|' + '|'.join(str(c(r)) if callable(c) else str(r[c]) for c in cols) + '|')
    return '\n'.join(out)


def build(a):
    """Checks, plus the same check carried to every other zone where both
    sources count the route within 2% of the reference zone: the same journeys
    pass both, so the document's count applies unchanged."""
    from review import runs
    from verdict import zone_verdicts
    zv = zone_verdicts()
    c = checks(a)
    c['basis'] = 'counted at the zone'
    have = set(zip(c.zone, c.route))
    extra = []
    for _, r in c[c.reliable].iterrows():
        if not r.tnds or not r.bods:
            continue
        m = runs[(runs.name == r.route) & (runs.zone_id != r.zone) & runs.zone_id.isin(list(zv))]
        for _, o in m.iterrows():
            if (o.zone_id, r.route) in have:
                continue
            if abs(o.tnds - r.tnds) <= 0.02 * r.tnds and abs(o.bods_gtfs - r.bods) <= 0.02 * r.bods:
                x = r.copy()
                x['zone'], x['tnds'], x['bods'] = o.zone_id, o.tnds, o.bods_gtfs
                x['t_ratio'], x['b_ratio'] = round(o.tnds / r.pdf, 2), round(o.bods_gtfs / r.pdf, 2)
                x['locality'] = zv[o.zone_id]['locality']
                x['zone_verdict'] = zv[o.zone_id]['verdict']
                x['zone_gap'] = zv[o.zone_id]['gap']
                x['verdict'] = assemble.verdict(x['t_ratio'], x['b_ratio'])
                x['basis'] = 'same journeys as ' + r.zone
                extra.append(x)
                have.add((o.zone_id, r.route))
    c = pd.concat([c, pd.DataFrame(extra)], ignore_index=True)
    c['area'] = c.zone.map(AREA)
    c['gap_route'] = (c.tnds - c.bods).abs()
    rel = c[c.reliable]
    return c, rel


if __name__ == '__main__':
    a = assemble.main()
    c, rel = build(a)
    print(len(a), len(c), len(rel))
    print(rel.verdict.value_counts())
    print(rel.groupby('area').agg(n=('route', 'size'), t=('t_ratio', 'median'), b=('b_ratio', 'median')))
