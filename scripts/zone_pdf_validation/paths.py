"""Where the scripts read and write. REPO is the repository root; WORK is a
scratch directory holding the downloads (nx/, first/, lothian/, passenger/,
ocr/, geo/) and intermediate tables, set with ZPV_WORK."""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')) + '/'
WORK = os.environ.get('ZPV_WORK', os.path.join(REPO, 'zpv_work')).rstrip('/') + '/'

# The counting window, and the number of each day type inside it. One
# definition, because the scripts that scale a printed timetable up to the
# window (compute.py) and the ones that label and report it (assemble.py,
# write_section.py) have to agree, and they silently did not when the window
# changed: compute.py carried 4 of each weekday written out as constants.
#
# It mirrors study_window() in R/config.R - study_weeks() whole weeks from the
# Monday of the reference date's week - and must be changed with it. Two weeks
# since October 2026; it was four until then, and every figure in
# data/zone_pdf_validation.csv and in the zone section of
# reports/pdf_validation.md was measured over four.
import datetime as _dt

WIN0, WIN1 = '2026-07-27', '2026-08-09'


def _daycounts(a=WIN0, b=WIN1):
    d0 = _dt.date.fromisoformat(a)
    d1 = _dt.date.fromisoformat(b)
    n = [0] * 7
    d = d0
    while d <= d1:
        n[d.weekday()] += 1
        d += _dt.timedelta(days=1)
    return {'MT': sum(n[0:4]), 'Fr': n[4], 'MF': sum(n[0:5]),
            'Sa': n[5], 'Su': n[6], 'SuBh': n[6], 'MS': sum(n[0:6])}


WINDOW = _daycounts()
