"""Header scan of every TransXChange file in a TNDS region zip."""
import zipfile, re, sys, pickle, os, collections
pat = {k: re.compile(v) for k, v in {
    'sc': r'<ServiceCode>([^<]+)</ServiceCode>', 'line': r'<LineName>([^<]+)</LineName>',
    'noc': r'<NationalOperatorCode>([^<]+)</NationalOperatorCode>',
    'opstart': r'<OperatingPeriod>\s*<StartDate>([^<]+)</StartDate>', 'opend': r'<OperatingPeriod>\s*<StartDate>[^<]+</StartDate>\s*<EndDate>([^<]+)</EndDate>',
    'created': r'CreationDateTime="([^"]+)"', 'modified': r'ModificationDateTime="([^"]+)"', 'rev': r'RevisionNumber="([^"]+)"',
    'schema': r'SchemaVersion="([^"]+)"', 'desc': r'<Description>([^<]+)</Description>'}.items()}
EXP = re.compile(r'<DaysOfNonOperation>\s*<DateRange>\s*<StartDate>([^<]+)</StartDate>\s*<EndDate>([^<]+)</EndDate>\s*(?:<Note>([^<]*)</Note>)?')
def scan(zp):
    rows = []
    z = zipfile.ZipFile(zp)
    def walk(z, prefix=''):
        for n in z.namelist():
            if n.lower().endswith('.zip'):
                import io
                walk(zipfile.ZipFile(io.BytesIO(z.read(n))), prefix + n + '/')
            elif n.lower().endswith('.xml'):
                s = z.read(n).decode('utf8', 'ignore')
                r = {'file': prefix + n, 'size': len(s)}
                for k, p in pat.items():
                    m = p.findall(s)
                    r[k] = sorted(set(m)) if k in ('sc', 'line', 'noc') else (m[0] if m else None)
                r['vj'] = s.count('<VehicleJourney>') + s.count('<VehicleJourney ')
                nonop = collections.Counter((a, b, (c or '')[:40]) for a, b, c in EXP.findall(s))
                r['nonop_far'] = sorted([(a, b, c, n) for (a, b, c), n in nonop.items() if b >= '2027'])
                rows.append(r)
    walk(z)
    return rows
if __name__ == '__main__':
    ver, reg = sys.argv[1], sys.argv[2]
    rows = scan(f'tnds/{ver}/{reg}.zip')
    os.makedirs('tnds/scan', exist_ok=True)
    pickle.dump(rows, open(f'tnds/scan/{ver}_{reg}.pkl', 'wb'))
    print(ver, reg, len(rows))
