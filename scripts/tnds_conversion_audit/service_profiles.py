"""Files whose service-level OperatingProfile has no regular days
(HolidaysOnly, or no RegularDayType), counted with how many of their
journeys carry no profile of their own and so inherit it.

usage: python -I service_profiles.py <tnds snapshot dir | bods archive zip>
"""
import os, re, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txc_index import walk
inp = sys.argv[1]
if os.path.isdir(inp):
    d = os.path.join(inp, 'TNDSV2.5')
    srcs = [(zipfile.ZipFile(os.path.join(d, f)), f) for f in sorted(os.listdir(d)) if f.endswith('.zip') and f != 'iom.zip']
else:
    srcs = [(zipfile.ZipFile(inp), os.path.basename(inp))]
n = vj = 0
for z, p in srcs:
    for cont, name, data in walk(z, p):
        s = data.decode('utf-8', 'ignore')
        m = re.search(r'<Service[ >].*?<OperatingPeriod>.*?</OperatingPeriod>\s*<OperatingProfile>(.*?)</OperatingProfile>', s, re.S)
        if not m:
            continue
        prof = m.group(1)
        if '<HolidaysOnly' in prof or '<RegularDayType' not in prof:
            vjs = re.findall(r'<VehicleJourney[ >].*?</VehicleJourney>', s, re.S)
            bare = sum(1 for v in vjs if '<OperatingProfile' not in v)
            if bare:
                n += 1; vj += bare
print(f'files with a no-regular-days service profile inherited by journeys: {n} ({vj} journeys)')
