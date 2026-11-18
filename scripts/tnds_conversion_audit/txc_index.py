"""Index every TransXChange file in a TNDS snapshot or a BODS archive.

One row per file: where it came from, operator code(s), line names,
ServiceCode, operating period, creation/modification stamps, revision,
journey count, mode, and whether it uses ServicedOrganisation calendars.
Nested zips (BODS) are walked. Read with regexes, not a parser, because the
point is speed over ~40,000 files; fields are taken from the first <Service>.

usage: python -I txc_index.py <tnds snapshot dir | bods archive zip> <out.csv>
"""
import csv, io, os, re, sys, zipfile
from concurrent.futures import ProcessPoolExecutor

RX = {k: re.compile(v, re.S) for k, v in {
    'noc': r'<NationalOperatorCode>([^<]+)',
    'opcode': r'<OperatorCode>([^<]+)',
    'svc': r'<Service[ >].*?<ServiceCode>([^<]+)',
    'period': r'<Service[ >].*?<OperatingPeriod>(.*?)</OperatingPeriod>',
    'mode': r'<Service[ >].*?<Mode>([^<]+)',
    'line': r'<LineName>([^<]+)',
    'opshort': r'<OperatorShortName>([^<]*)',
    'optrade': r'<TradingName>([^<]*)',
    'create': r'CreationDateTime="([^"]+)"',
    'modify': r'ModificationDateTime="([^"]+)"',
    'rev': r'RevisionNumber="([^"]+)"',
    'start': r'<StartDate>([^<]+)',
    'end': r'<EndDate>([^<]+)',
}.items()}


def row(src, container, name, data):
    s = data.decode('utf-8', 'ignore')
    g = lambda k, t=s: (RX[k].search(t).group(1).strip() if RX[k].search(t) else '')
    per = g('period')
    return dict(source=src, container=container, file=name,
                # NXWM's TNDS files carry only an OperatorCode
                noc=';'.join(sorted(set(RX['noc'].findall(s)) or
                                    set('OC:' + x for x in RX['opcode'].findall(s)))),
                lines=';'.join(sorted(set(x.strip() for x in RX['line'].findall(s)))),
                # the name UK2GTFS writes as agency_name: OperatorShortName, else TradingName
                opname=';'.join(sorted(set(x.strip() for x in RX['opshort'].findall(s) if x.strip()) or
                                       set(x.strip() for x in RX['optrade'].findall(s) if x.strip()))),
                service_code=g('svc'), mode=g('mode'),
                start=g('start', per), end=g('end', per),
                created=g('create')[:19], modified=g('modify')[:19], revision=g('rev'),
                n_vj=len(re.findall(r'<VehicleJourney[ >]', s)),
                serviced_org=int('<ServicedOrganisationDayType>' in s),
                holidays_only=int('<HolidaysOnly' in s))


def walk(z, prefix):
    for n in z.namelist():
        if n.lower().endswith('.zip'):
            yield from walk(zipfile.ZipFile(io.BytesIO(z.read(n))), prefix + '!' + n)
        elif n.lower().endswith('.xml'):
            yield prefix, n, z.read(n)


def do_zip(args):
    path, member, src = args
    z = zipfile.ZipFile(path)
    out = []
    if member is None:
        items = walk(z, os.path.basename(path))
    elif member.lower().endswith('.zip'):
        items = walk(zipfile.ZipFile(io.BytesIO(z.read(member))), member)
    else:
        items = [(member.split('/')[0], member, z.read(member))]
    for cont, name, data in items:
        try:
            out.append(row(src, cont, name, data))
        except Exception as e:  # keep going; record the failure
            out.append(dict(source=src, container=cont, file=name, mode='ERROR:' + str(e)[:50]))
    return out


def main(inp, out_csv):
    if os.path.isdir(inp):
        d = os.path.join(inp, 'TNDSV2.5') if os.path.isdir(os.path.join(inp, 'TNDSV2.5')) else inp
        jobs = [(os.path.join(d, f), None, 'tnds') for f in sorted(os.listdir(d))
                if f.lower().endswith('.zip') and f.lower() != 'iom.zip']
    else:
        z = zipfile.ZipFile(inp)
        jobs = [(inp, n, 'bods') for n in z.namelist() if n.lower().endswith(('.zip', '.xml'))]
    rows = []
    with ProcessPoolExecutor(12) as ex:
        for r in ex.map(do_zip, jobs, chunksize=4):
            rows.extend(r)
    keys = ['source', 'container', 'file', 'noc', 'lines', 'opname', 'service_code', 'mode', 'start', 'end',
            'created', 'modified', 'revision', 'n_vj', 'serviced_org', 'holidays_only']
    with open(out_csv, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, keys)
        w.writeheader()
        w.writerows(rows)
    print(len(rows), 'files ->', out_csv)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
