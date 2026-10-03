import paths
import math, rdata, pandas as pd, numpy as np
def zone_verdicts():
    d = rdata.read_rds(paths.REPO + 'data/lsoa_disagreement_2026.Rds', default_encoding='utf8')
    t = d['top'].copy()
    t = t.merge(d['duplication'], on='zone_id', how='left', suffixes=('', '_dup'))
    def safe(a, b): return a / b if b and b > 0 and not pd.isna(b) else np.nan
    out = {}
    for _, r in t.iterrows():
        g = lambda k: (0 if pd.isna(r.get(k, np.nan)) else r.get(k))
        trip_ratio = safe(r.trips_tnds, r.trips_bods)
        dpt = safe(safe(r.runs_tnds, r.trips_tnds), safe(r.runs_bods, r.trips_bods))
        gap = r.gap
        dup = safe(g('dup_runs_tnds'), abs(gap)) if gap > 0 else safe(g('dup_runs_bods_gtfs'), abs(gap)) if gap < 0 else np.nan
        lr = lambda x: np.nan if pd.isna(x) or x <= 0 else abs(math.log(x))
        lt, ld = lr(trip_ratio), lr(dpt)
        dom = lambda a, b: not pd.isna(a) and not pd.isna(b) and a >= 2.5 * b
        short = lambda x: not pd.isna(x) and x <= 0.7
        over = lambda x: not pd.isna(x) and x >= 1.43
        cut_t = g('days_full_tnds') < g('days_full_bods_gtfs'); cut_b = g('days_full_bods_gtfs') < g('days_full_tnds')
        if r.runs_tnds == 0: v = 'absent from TNDS'
        elif r.runs_bods == 0: v = 'absent from BODS GTFS'
        elif not pd.isna(dup) and dup >= 0.5 and gap < 0: v = 'BODS GTFS counts one bus twice'
        elif not pd.isna(dup) and dup >= 0.5 and gap > 0: v = 'TNDS counts one bus twice'
        elif dom(ld, lt) and short(dpt) and cut_t: v = 'TNDS calendars cut short'
        elif dom(ld, lt) and over(dpt) and cut_b: v = 'BODS GTFS calendars cut short'
        elif dom(lt, ld) and short(trip_ratio): v = 'journeys missing from TNDS'
        elif dom(lt, ld) and over(trip_ratio): v = 'journeys missing from BODS GTFS'
        else: v = 'unresolved'
        out[r.zone_id] = dict(verdict=v, locality=r.locality, gap=r.gap, runs_tnds=r.runs_tnds, runs_bods=r.runs_bods, country=r.country)
    return out
if __name__ == '__main__':
    v = zone_verdicts()
    import collections; print(collections.Counter(x['verdict'] for x in v.values()))
    for z in ['E01033620','E01034091','E01033415','E01031575','E01004513','E01017032']: print(z, v[z])
