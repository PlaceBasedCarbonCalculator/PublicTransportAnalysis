"""Where the scripts read and write. REPO is the repository root; WORK is a
scratch directory holding the downloads (nx/, first/, lothian/, passenger/,
ocr/, geo/) and intermediate tables, set with ZPV_WORK."""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')) + '/'
WORK = os.environ.get('ZPV_WORK', os.path.join(REPO, 'zpv_work')).rstrip('/') + '/'
