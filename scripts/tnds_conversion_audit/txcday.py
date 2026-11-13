"""Count the vehicle journeys a raw TransXChange file runs on given dates.

An independent reading of the TransXChange operating rules, written from the
schema rather than from UK2GTFS, so that its counts can be set against the
converted GTFS: where the two agree the converter is faithful to the file,
and a disagreement with a published timetable is in the data; where they
differ the converter is suspect.

Rules applied, in order, for a journey on date d:
  * the Service OperatingPeriod must contain d;
  * the journey's OperatingProfile (else its JourneyPattern's, else the
    Service's) gives the regular days: DaysOfWeek (Monday..Sunday,
    MondayToFriday, MondayToSaturday, MondayToSunday, Weekend, NotSaturday,
    NotSunday ...) or HolidaysOnly;
  * SpecialDaysOperation DaysOfNonOperation date ranges exclude d, and
    DaysOfOperation date ranges include it whatever the weekday;
  * ServicedOrganisationDayType: DaysOfOperation WorkingDays/Holidays of an
    organisation restrict the journey to those dates; DaysOfNonOperation of
    them exclude them;
  * BankHolidayOperation: DaysOfNonOperation of a named holiday excludes
    its date, DaysOfOperation adds it. Only the holidays passed in `bankhols`
    are known.

usage (as a module): runs_on(xml_bytes, dates) -> {line: {date: n}}
"""
import datetime as dt
import re
import xml.etree.ElementTree as ET

NS = {'t': 'http://www.transxchange.org.uk/'}
WD = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
GROUPS = {
    'MondayToFriday': {0, 1, 2, 3, 4}, 'MondayToSaturday': {0, 1, 2, 3, 4, 5},
    'MondayToSunday': set(range(7)), 'Weekend': {5, 6}, 'NotSaturday': {0, 1, 2, 3, 4, 6},
    'NotSunday': set(range(6)),
}


def _d(s):
    return dt.date.fromisoformat(s[:10]) if s else None


def _ranges(node, path):
    out = []
    for r in node.findall(path, NS):
        s = _d(r.findtext('t:StartDate', None, NS))
        e = _d(r.findtext('t:EndDate', None, NS)) or s
        out.append((s, e))
    return out


def _in(d, ranges):
    return any(s <= d <= e for s, e in ranges if s)


class Profile:
    def __init__(self, op):
        self.days = set()
        self.holidays_only = False
        self.op_ranges, self.nonop_ranges = [], []
        self.so_op, self.so_nonop = [], []        # (kind, org ref)
        self.bh_op, self.bh_nonop = set(), set()
        if op is None:
            return
        rdt = op.find('t:RegularDayType', NS)
        if rdt is not None:
            if rdt.find('t:HolidaysOnly', NS) is not None:
                self.holidays_only = True
            dow = rdt.find('t:DaysOfWeek', NS)
            if dow is not None:
                for c in dow:
                    tag = c.tag.split('}')[1]
                    if tag in WD:
                        self.days.add(WD.index(tag))
                    elif tag in GROUPS:
                        self.days |= GROUPS[tag]
        sdo = op.find('t:SpecialDaysOperation', NS)
        if sdo is not None:
            self.op_ranges = _ranges(sdo, 't:DaysOfOperation/t:DateRange')
            self.nonop_ranges = _ranges(sdo, 't:DaysOfNonOperation/t:DateRange')
        so = op.find('t:ServicedOrganisationDayType', NS)
        if so is not None:
            for which, lst in (('DaysOfOperation', self.so_op), ('DaysOfNonOperation', self.so_nonop)):
                for kind in ('WorkingDays', 'Holidays'):
                    for ref in so.findall('t:%s/t:%s/t:ServicedOrganisationRef' % (which, kind), NS):
                        lst.append((kind, ref.text))
        bh = op.find('t:BankHolidayOperation', NS)
        if bh is not None:
            for which, st in (('DaysOfOperation', self.bh_op), ('DaysOfNonOperation', self.bh_nonop)):
                n = bh.find('t:' + which, NS)
                if n is not None:
                    st |= {c.tag.split('}')[1] for c in n}

    def empty(self):
        return not (self.days or self.holidays_only or self.op_ranges)


def _org_days(orgs, ref, kind, d):
    """Whether d is one of an organisation's working days or holidays. An
    organisation that lists only its WorkingDays (North Lincs College, in a
    Stagecoach Hull file) has holidays on every other date, and the reverse."""
    o = orgs.get(ref, {})
    wd, hol = o.get('WorkingDays', []), o.get('Holidays', [])
    if kind == 'WorkingDays':
        return _in(d, wd) if wd else (bool(hol) and not _in(d, hol))
    return _in(d, hol) if hol else (bool(wd) and not _in(d, wd))


def runs(prof, d, orgs, bankhols):
    hol = [k for k, v in bankhols.items() if v == d]
    if any(h in prof.bh_nonop or 'AllBankHolidays' in prof.bh_nonop for h in hol):
        return False
    if _in(d, prof.nonop_ranges):
        return False
    if _in(d, prof.op_ranges):
        return True
    if any(h in prof.bh_op or 'AllBankHolidays' in prof.bh_op for h in hol):
        return True
    if prof.holidays_only:
        return False
    if d.weekday() not in prof.days:
        return False
    for kind, ref in prof.so_nonop:
        if _org_days(orgs, ref, kind, d):
            return False
    if prof.so_op:
        return any(_org_days(orgs, ref, kind, d) for kind, ref in prof.so_op)
    return True


def runs_on(xml, dates, bankhols=None):
    bankhols = bankhols or {}
    root = ET.fromstring(xml)
    orgs = {}
    for so in root.findall('.//t:ServicedOrganisations/t:ServicedOrganisation', NS):
        code = so.findtext('t:OrganisationCode', None, NS)
        orgs[code] = {'WorkingDays': _ranges(so, 't:WorkingDays/t:DateRange'),
                      'Holidays': _ranges(so, 't:Holidays/t:DateRange')}
    out = {}
    for svc in root.findall('.//t:Services/t:Service', NS):
        ps = _d(svc.findtext('t:OperatingPeriod/t:StartDate', None, NS))
        pe = _d(svc.findtext('t:OperatingPeriod/t:EndDate', None, NS)) or dt.date(2100, 1, 1)
        sprof = Profile(svc.find('t:OperatingProfile', NS))
        lines = {l.get('id'): l.findtext('t:LineName', None, NS)
                 for l in svc.findall('t:Lines/t:Line', NS)}
        jps = {}
        for jp in svc.findall('t:StandardService/t:JourneyPattern', NS):
            jps[jp.get('id')] = jp.find('t:OperatingProfile', NS)
        scode = svc.findtext('t:ServiceCode', None, NS)
        for vj in root.findall('.//t:VehicleJourneys/t:VehicleJourney', NS):
            if vj.findtext('t:ServiceRef', None, NS) != scode:
                continue
            op = vj.find('t:OperatingProfile', NS)
            if op is None:
                op = jps.get(vj.findtext('t:JourneyPatternRef', None, NS))
            prof = Profile(op) if op is not None else sprof
            line = lines.get(vj.findtext('t:LineRef', None, NS), '?')
            for d in dates:
                if ps <= d <= pe and runs(prof, d, orgs, bankhols):
                    out.setdefault(line, {}).setdefault(d, 0)
                    out[line][d] += 1
    return out
