import paths
import glob, os, re
import pandas as pd
import ocrcount
from review import runs

SP = paths.WORK
ROWS = {'E01031585': r'Crawley Bus Station', 'E01031575': r'North\s*Terminal',
        'E01031583': r'Manor Royal'}
C = [('10', ['E01031575', 'E01031585', 'E01031583']), ('100', ['E01031575', 'E01031585', 'E01031583']),
     ('20', ['E01031575', 'E01031585', 'E01031583']), ('3', ['E01031575', 'E01031585', 'E01031583']),
     ('200', ['E01031575', 'E01031583']), ('2', ['E01031585']), ('4', ['E01031575', 'E01031585']),
     ('5', ['E01031575', 'E01031585']), ('400', ['E01031575', 'E01031585', 'E01031583'])]
DOC = {'4': '4', '5': '4'}   # one document carries both


def run():
    rows = []
    for route, zones in C:
        r = DOC.get(route, route)
        fs = sorted(glob.glob(SP + f'ocr/metrobus_MB_{r}-timetable-*.txt'))
        fs = [f for f in fs if not re.search(r'-\d+\.txt$', f)]
        if route == '400':
            fs = [f for f in fs if '20250927' in f]   # in force to 7 Aug; the 8 Aug edition is noted separately
        if not fs:
            print('no OCR for', route); continue
        txt = open(fs[0]).read()
        key = 'P_' + os.path.basename(fs[0])[:-4]
        ed = re.search(r'-(\d{8})-', fs[0]).group(1)
        for z in zones:
            d = ocrcount.count(txt, ROWS[z])
            tot = 20 * d.get('MF', 0) + 4 * d.get('Sa', 0) + 4 * d.get('Su', 0)
            src = runs[(runs.zone_id == z) & (runs.name == route)]
            tn, bo = float(src.tnds.sum()), float(src.bods_gtfs.sum())
            if bo == 0 and tn == 0:
                continue
            rows.append(dict(doc=key, route=route, zone=z, operator='Metrobus', edition=f'{ed[:4]}-{ed[4:6]}-{ed[6:]}',
                             days=d, pdf=tot, tnds=tn, bods=bo,
                             t_ratio=round(tn / tot, 2) if tot else None, b_ratio=round(bo / tot, 2) if tot else None,
                             quals=['OCR'], rows=[ROWS[z]], reliable=bool(tot) and all(k in d for k in ('MF', 'Sa')) and route not in ('4', '5')))
            print(route, z, d, tot, tn, bo, rows[-1]['t_ratio'], rows[-1]['b_ratio'])
    df = pd.DataFrame(rows)
    df.to_pickle(SP + 'crawley.pkl')
    return df


if __name__ == '__main__':
    run()
