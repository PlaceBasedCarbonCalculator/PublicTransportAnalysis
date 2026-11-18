"""Files with no OperatingProfile anywhere, and files whose journeys skip a
stop marked "pass" while leaving other activities unstated.

usage: python -I no_profile.py <tnds snapshot dir | bods archive zip>
"""
import io, os, re, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txc_index import walk

def scan(z, prefix):
    for cont, name, data in walk(z, prefix):
        s = data.decode('utf-8', 'ignore')
        nvj = len(re.findall(r'<VehicleJourney[ >]', s))
        if not nvj:
            continue
        nop = '<OperatingProfile' not in s
        pas = '<Activity>pass</Activity>' in s
        yield cont, name, nvj, nop, pas

inp = sys.argv[1]
n = vj = 0
if os.path.isdir(inp):
    d = os.path.join(inp, 'TNDSV2.5')
    srcs = [(zipfile.ZipFile(os.path.join(d, f)), f) for f in sorted(os.listdir(d)) if f.endswith('.zip') and f != 'iom.zip']
else:
    srcs = [(zipfile.ZipFile(inp), os.path.basename(inp))]
tot = pas_n = 0
for z, p in srcs:
    for cont, name, nvj, nop, pas in scan(z, p):
        tot += 1; pas_n += pas
        if nop:
            n += 1; vj += nvj
            print('NO PROFILE', cont[:50], name[-60:], nvj)
print(f'files {tot}; with no OperatingProfile {n} ({vj} journeys); using pass {pas_n}')
