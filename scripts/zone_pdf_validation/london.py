import paths
import pandas as pd, tfl
from review import runs
E = paths.REPO + 'data/example_timetables/'
WST = ['AYB01', 'AU833', 'J3133']
L = [  # route, zone, nodes, {day: (file, days in window)}
 ('275', 'E01004397', WST, {'MF': ('Schedule_275-MF.pdf', 20), 'Sa': ('Schedule_275-Sa.pdf', 4), 'Su': ('Schedule_275-Su.pdf', 4)}),
 ('20', 'E01004397', WST, {'MT': ('Schedule_20-MF.pdf', 16), 'Fr': ('Schedule_20-Fr.pdf', 4), 'Sa': ('Schedule_20-Sa.pdf', 4), 'Su': ('Schedule_20-Su.pdf', 4)}),
 ('20', 'E01021782', ['AVZ08'], {'MT': ('Schedule_20-MF.pdf', 16), 'Fr': ('Schedule_20-Fr.pdf', 4), 'Sa': ('Schedule_20-Sa.pdf', 4), 'Su': ('Schedule_20-Su.pdf', 4)}),
 ('215', 'E01004397', WST, {'MT': ('Schedule_215-MF.pdf', 16), 'Fr': ('Schedule_215-Fr.pdf', 4), 'Sa': ('Schedule_215-Sa.pdf', 4), 'Su': ('Schedule_215-Su.pdf', 4)}),
 ('216', 'E01002968', ['AK118', 'J6418', 'AK104'], {'MF': ('Schedule_216-MFHo.pdf', 20), 'Sa': ('Schedule_216-Sa.pdf', 4), 'Su': ('Schedule_216-Su.pdf', 4)}),
 ('216', 'E01030751', ['A4Z03', 'A4Z17'], {'MF': ('Schedule_216-MFHo.pdf', 20), 'Sa': ('Schedule_216-Sa.pdf', 4), 'Su': ('Schedule_216-Su.pdf', 4)}),
 ('235', 'E01030751', ['A4Z03', 'A4Z17'], {'MF': ('Schedule_235-MF.pdf', 20), 'Sa': ('Schedule_235-Sa.pdf', 4), 'Su': ('Schedule_235-Su.pdf', 4)}),
 ('406', 'E01002968', ['AK118', 'J6418', 'AK104'], {'MF': ('Schedule_406-MFHo.pdf', 20), 'Sa': ('Schedule_406-Sa.pdf', 4), 'Su': ('Schedule_406-Su.pdf', 4)}),
 ('406', 'E01034290', ['AZN10', 'AZN05'], {'MF': ('Schedule_406-MFHo.pdf', 20), 'Sa': ('Schedule_406-Sa.pdf', 4), 'Su': ('Schedule_406-Su.pdf', 4)}),
 ('462', 'E01021767', ['ASZ21', 'J4458'], {'MF': ('Schedule_462-MF.pdf', 20), 'Sa': ('Schedule_462-Sa.pdf', 4), 'Su': ('Schedule_462-Su.pdf', 4)}),
 ('167', 'E01021782', ['AVZ08', 'J8108'], {'MF': ('Schedule_167-MF.pdf', 20), 'Sa': ('Schedule_167-Sa.pdf', 4), 'Su': ('Schedule_167-Su.pdf', 4)}),
]
rows = []
for route, zone, nodes, files in L:
    days, tot = {}, 0
    for d, (f, n) in files.items():
        h, a = tfl.trips(E + f, nodes)
        days[d] = h; tot += h * n
    src = runs[(runs.zone_id == zone) & (runs.name == route)]
    tn, bo = float(src.tnds.sum()), float(src.bods_gtfs.sum())
    rows.append(dict(doc='TfL schedule ' + route, route=route, zone=zone, operator='TfL contract',
                     days=days, pdf=tot, tnds=tn, bods=bo, t_ratio=round(tn / tot, 2), b_ratio=round(bo / tot, 2),
                     files=[f for f, n in files.values()], reliable=True))
    print(route, zone, days, tot, tn, bo, rows[-1]['t_ratio'], rows[-1]['b_ratio'], flush=True)
pd.DataFrame(rows).to_pickle('london.pkl')
