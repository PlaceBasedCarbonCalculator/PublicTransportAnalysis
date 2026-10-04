"""Independent TransXChange journey counter.

For a set of TransXChange files, how many vehicle-journey runs call at any of a
set of stops on each date of a window. Written from the TransXChange schema,
not from UK2GTFS, so that the two can be compared.

Calendar rules (TransXChange 2.1/2.4):
  * OperatingProfile from the VehicleJourney, else the JourneyPattern, else the
    Service.
  * RegularDayType/DaysOfWeek, or HolidaysOnly (runs only on the holidays of
    the serviced organisations named, or on bank holidays).
  * SpecialDaysOperation: DaysOfOperation adds dates, DaysOfNonOperation
    removes them.
  * ServicedOrganisationDayType: DaysOfOperation/WorkingDays = term only,
    DaysOfNonOperation/WorkingDays = not in term, DaysOfOperation/Holidays =
    holidays only, DaysOfNonOperation/Holidays = not in holidays.
  * BankHolidayOperation is applied for the bank holidays passed in.
  * The service's OperatingPeriod bounds everything.
"""
import datetime as dt
import re, zipfile, io, collections
import xml.etree.ElementTree as ET

DOW = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
GROUPS = {'MondayToFriday': {0, 1, 2, 3, 4}, 'MondayToSaturday': {0, 1, 2, 3, 4, 5},
          'MondayToSunday': set(range(7)), 'Weekend': {5, 6}}
for i, d in enumerate(DOW):
    GROUPS[d] = {i}
    GROUPS['Not' + d] = set(range(7)) - {i}


def strip(el):
    for e in el.iter():
        if isinstance(e.tag, str) and '}' in e.tag:
            e.tag = e.tag.split('}', 1)[1]
    return el


def d(s):
    return dt.date.fromisoformat(s[:10]) if s else None


def ranges(el):
    out = []
    if el is None:
        return out
    for r in el.iter('DateRange'):
        a, b = d(r.findtext('StartDate')), d(r.findtext('EndDate'))
        out.append((a, b or a))
    return out


def in_ranges(day, rs):
    return any(a <= day <= b for a, b in rs)


class Profile:
    def __init__(self, op, sorgs):
        self.days = None          # set of weekdays, or None if not given
        self.holidays_only = False
        self.add, self.remove = [], []
        self.so = []              # (operation, kind, org)
        self.bh_op, self.bh_nonop = set(), set()
        if op is None:
            return
        rdt = op.find('RegularDayType')
        if rdt is not None:
            dw = rdt.find('DaysOfWeek')
            if dw is not None:
                self.days = set()
                for c in dw:
                    self.days |= GROUPS.get(c.tag, set())
            if rdt.find('HolidaysOnly') is not None:
                self.holidays_only = True
                self.days = set()
        sdo = op.find('SpecialDaysOperation')
        if sdo is not None:
            self.add = ranges(sdo.find('DaysOfOperation'))
            self.remove = ranges(sdo.find('DaysOfNonOperation'))
        sodt = op.find('ServicedOrganisationDayType')
        if sodt is not None:
            for opk in ('DaysOfOperation', 'DaysOfNonOperation'):
                x = sodt.find(opk)
                if x is None:
                    continue
                for kind in ('WorkingDays', 'Holidays'):
                    for k in x.findall(kind):
                        for ref in k.iter('ServicedOrganisationRef'):
                            self.so.append((opk, kind, sorgs.get(ref.text, {'WorkingDays': [], 'Holidays': []})))
        bho = op.find('BankHolidayOperation')
        if bho is not None:
            for opk, tgt in (('DaysOfOperation', self.bh_op), ('DaysOfNonOperation', self.bh_nonop)):
                x = bho.find(opk)
                if x is not None:
                    for c in x:
                        tgt.add(c.tag)

    def runs(self, day, bank):
        """bank: dict date -> set of bank holiday element names that fall on it"""
        if in_ranges(day, self.remove):
            return False
        if in_ranges(day, self.add):
            return True
        bh = bank.get(day, set())
        if bh:
            if bh & self.bh_nonop or 'AllBankHolidays' in self.bh_nonop:
                return False
            if bh & self.bh_op or 'AllBankHolidays' in self.bh_op:
                return True
        ok = (self.days is None or day.weekday() in self.days)
        if self.holidays_only:
            ok = any(in_ranges(day, org['Holidays']) for _, _, org in self.so)
        for opk, kind, org in self.so:
            inside = in_ranges(day, org[kind])
            if opk == 'DaysOfOperation' and not self.holidays_only:
                ok = ok and inside
            elif opk == 'DaysOfNonOperation':
                ok = ok and not inside
        return ok


def parse(xml_bytes):
    root = strip(ET.fromstring(xml_bytes))
    sorgs = {}
    for so in root.iter('ServicedOrganisation'):
        sorgs[so.findtext('OrganisationCode')] = {'WorkingDays': ranges(so.find('WorkingDays')),
                                                  'Holidays': ranges(so.find('Holidays'))}
    sections = {}
    for jps in root.iter('JourneyPatternSection'):
        stops = []
        for tl in jps.findall('JourneyPatternTimingLink'):
            for side in ('From', 'To'):
                s = tl.find(side)
                if s is not None and s.findtext('StopPointRef'):
                    stops.append(s.findtext('StopPointRef'))
        sections[jps.get('id')] = stops
    services = []
    for svc in root.iter('Service'):
        code = svc.findtext('ServiceCode')
        op = svc.find('OperatingPeriod')
        start = d(op.findtext('StartDate')) if op is not None else None
        end = d(op.findtext('EndDate')) if op is not None else None
        sprof = svc.find('OperatingProfile')
        lines = {l.get('id'): l.findtext('LineName') for l in svc.iter('Line')}
        jps = {}
        for jp in svc.iter('JourneyPattern'):
            st = []
            for r in jp.findall('JourneyPatternSectionRefs'):
                st += sections.get(r.text, [])
            jps[jp.get('id')] = (st, jp.find('OperatingProfile'))
        services.append(dict(code=code, start=start, end=end, prof=sprof, lines=lines, jps=jps))
    vjs = []
    by_code = {}
    for vj in root.iter('VehicleJourney'):
        by_code[vj.findtext('VehicleJourneyCode')] = vj
    for vj in root.iter('VehicleJourney'):
        jpref = vj.findtext('JourneyPatternRef')
        base = vj
        if jpref is None and vj.findtext('VehicleJourneyRef'):
            base = by_code.get(vj.findtext('VehicleJourneyRef'), vj)
            jpref = base.findtext('JourneyPatternRef')
        vjs.append(dict(code=vj.findtext('VehicleJourneyCode'), svc=vj.findtext('ServiceRef'),
                        line=vj.findtext('LineRef'), jp=jpref, dep=vj.findtext('DepartureTime'),
                        prof=vj.find('OperatingProfile') if vj.find('OperatingProfile') is not None else base.find('OperatingProfile')))
    return services, vjs, sorgs


def count(xml_bytes, stops, days, bank=None, keep=None):
    """Runs per date of journeys calling at any of `stops`.
    Returns (per-date Counter, list of (line, dep, n_days)) ."""
    bank = bank or {}
    services, vjs, sorgs = parse(xml_bytes)
    svc = {s['code']: s for s in services}
    per = collections.Counter()
    detail = []
    for v in vjs:
        s = svc.get(v['svc']) or (services[0] if services else None)
        if s is None:
            continue
        line = s['lines'].get(v['line'], v['line'])
        if keep and line not in keep:
            continue
        st, jprof = s['jps'].get(v['jp'], ([], None))
        if stops is not None and not set(st) & stops:
            continue
        pel = v['prof'] if v['prof'] is not None else (jprof if jprof is not None else s['prof'])
        p = Profile(pel, sorgs)
        n = 0
        for day in days:
            if s['start'] and day < s['start']:
                continue
            if s['end'] and day > s['end']:
                continue
            if p.runs(day, bank):
                per[day] += 1
                n += 1
        detail.append((line, v['dep'], n))
    return per, detail


def window(a='2026-07-27', b='2026-08-23'):
    a, b = d(a), d(b)
    return [a + dt.timedelta(i) for i in range((b - a).days + 1)]


def zip_members(zp, pattern):
    z = zipfile.ZipFile(zp)
    rx = re.compile(pattern)
    for n in z.namelist():
        if rx.search(n):
            yield n, z.read(n)
