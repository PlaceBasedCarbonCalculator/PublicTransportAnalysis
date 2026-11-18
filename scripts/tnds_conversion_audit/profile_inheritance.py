"""How often do journeys depend on profile inheritance or other features the
literature review (reports/TNDS_vs_BODS_report.md) says converters get wrong?

Per file, counts VehicleJourneys that
  - have no OperatingProfile of their own (inherit),
  - inherit a JourneyPattern-level OperatingProfile (jp_inherit) and whether
    its days differ from the Service profile (jp_days_differ),
  - inherit a Service-level BankHolidayOperation (svc_bh_inherit),
    SpecialDaysOperation (svc_sd_inherit) or ServicedOrganisationDayType
    (svc_so_inherit),
  - have no profile at any level (no_profile),
  - use AllBankHolidays in DaysOfNonOperation (allbh_nonop),
  - carry StartDeadRun/EndDeadRun (deadrun) with a ShortWorking (short_working).

usage: python -I profile_inheritance.py <tnds snapshot dir | bods archive zip> <out.csv>
"""
import csv, io, os, sys, zipfile
import xml.etree.ElementTree as ET
from concurrent.futures import ProcessPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txc_index import walk

NS = '{http://www.transxchange.org.uk/}'


def days_of(prof):
    if prof is None:
        return None
    rdt = prof.find(NS + 'RegularDayType')
    if rdt is None:
        return ''
    if rdt.find(NS + 'HolidaysOnly') is not None:
        return 'HolidaysOnly'
    dow = rdt.find(NS + 'DaysOfWeek')
    return ' '.join(sorted(c.tag.replace(NS, '') for c in dow)) if dow is not None else ''


def row(src, cont, name, data):
    r = dict(source=src, container=cont, file=name, n_vj=0, inherit=0, jp_inherit=0,
             jp_days_differ=0, svc_bh_inherit=0, svc_sd_inherit=0, svc_so_inherit=0,
             no_profile=0, allbh_nonop=0, deadrun=0, short_working=0, svc_code='', noc='')
    root = ET.fromstring(data)
    svc = root.find(f'{NS}Services/{NS}Service')
    if svc is None:
        return r
    r['svc_code'] = (svc.findtext(NS + 'ServiceCode') or '').strip()
    op = root.find(f'{NS}Operators/*')
    if op is not None:
        r['noc'] = (op.findtext(NS + 'NationalOperatorCode') or op.findtext(NS + 'OperatorCode') or '').strip()
    sprof = svc.find(NS + 'OperatingProfile')
    sdays = days_of(sprof)
    jp_prof = {}
    for jp in svc.iter(NS + 'JourneyPattern'):
        p = jp.find(NS + 'OperatingProfile')
        if p is not None:
            jp_prof[jp.get('id')] = p
    for vj in root.iter(NS + 'VehicleJourney'):
        r['n_vj'] += 1
        own = vj.find(NS + 'OperatingProfile')
        if vj.find(NS + 'StartDeadRun') is not None or vj.find(NS + 'EndDeadRun') is not None:
            r['deadrun'] += 1
            if vj.find(f'.//{NS}ShortWorking') is not None:
                r['short_working'] += 1
        eff = own
        if own is None:
            r['inherit'] += 1
            jpr = vj.findtext(NS + 'JourneyPatternRef')
            if jpr in jp_prof:
                r['jp_inherit'] += 1
                eff = jp_prof[jpr]
                if days_of(eff) != sdays:
                    r['jp_days_differ'] += 1
            elif sprof is not None:
                eff = sprof
                if sprof.find(NS + 'BankHolidayOperation') is not None:
                    r['svc_bh_inherit'] += 1
                if sprof.find(NS + 'SpecialDaysOperation') is not None:
                    r['svc_sd_inherit'] += 1
                if sprof.find(NS + 'ServicedOrganisationDayType') is not None:
                    r['svc_so_inherit'] += 1
            else:
                r['no_profile'] += 1
        if eff is not None and eff.find(f'{NS}BankHolidayOperation/{NS}DaysOfNonOperation/{NS}AllBankHolidays') is not None:
            r['allbh_nonop'] += 1
    return r


def do_zip(args):
    path, member, src = args
    z = zipfile.ZipFile(path)
    if member is None:
        items = walk(z, os.path.basename(path))
    elif member.lower().endswith('.zip'):
        items = walk(zipfile.ZipFile(io.BytesIO(z.read(member))), member)
    else:
        items = [(member.split('/')[0], member, z.read(member))]
    out = []
    for cont, name, data in items:
        try:
            out.append(row(src, cont, name, data))
        except Exception as e:
            out.append(dict(source=src, container=cont, file=name, svc_code='ERROR:' + str(e)[:40]))
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
    with ProcessPoolExecutor(24) as ex:
        for r in ex.map(do_zip, jobs, chunksize=4):
            rows.extend(r)
    keys = ['source', 'container', 'file', 'noc', 'svc_code', 'n_vj', 'inherit', 'jp_inherit',
            'jp_days_differ', 'svc_bh_inherit', 'svc_sd_inherit', 'svc_so_inherit', 'no_profile',
            'allbh_nonop', 'deadrun', 'short_working']
    with open(out_csv, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, keys, extrasaction='ignore')
        w.writeheader()
        w.writerows(rows)
    tot = {k: sum(int(r.get(k) or 0) for r in rows) for k in keys[5:]}
    print(len(rows), 'files', tot)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
