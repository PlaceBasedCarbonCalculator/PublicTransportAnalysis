# Zone-level PDF validation

The scripts behind the section "The zones where TNDS and BODS GTFS disagree
most" in `reports/pdf_validation.md`. They check the 60 zones of
`reports/lsoa_disagreement.md` against operators' published timetables.
Python, not R: they read `data/lsoa_disagreement_2026.Rds` with the `rdata`
package and need neither the feeds nor the targets pipeline.

Requirements: Python 3 with `pandas`, `pdfplumber`, `rdata` and `shapely`;
`pdftotext` and `tesseract` (OCR, for the Metrobus scans); Node with
Playwright (only to download the National Express West Midlands PDFs).
Set `ZPV_WORK` to a scratch directory for downloads and intermediate tables.

## Collecting the documents

All the documents used are already in `data/example_timetables/`. To collect
them again:

| Operator | Where | How |
|---|---|---|
| Reading Buses, East Yorkshire, Brighton & Hove, Bluestar, Metrobus, Redline | `passenger-line-assets.s3.eu-west-1.amazonaws.com` (listable, keeps every edition) | `s3list.py <operator prefixes> > s3keys.txt`, then `pick.py` picks the latest edition on or before the window start |
| First Bus (Essex, Portsmouth, Wessex, South West Wales) | `firstbus.co.uk/api/timetables/pdf?opco=N&service=S&day=mf\|sa\|su&print=pdf` | current edition only; service codes are listed on each region's timetables pages |
| National Express West Midlands | `timetables-embed.nxbus.co.uk/<code>` | `node nxdl.js <service slug> <out.pdf>` clicks the whole-week PDF button; current edition only |
| Lothian | `lothianbuses.com/wp-content/uploads/...` | the file name dates the edition (`03_26e02r22` = 22 Feb 2026) |
| TfL | running schedules already in the folder | — |

The zone polygons come from the ONS (LSOA 2021) and Scottish Government
(Data Zone 2022) ArcGIS services, and the stops from the NaPTAN API; `geo/`
in the work directory holds them, and `review.py` assigns stops to zones.

## Running

```
python3 compute.py      # passenger timetables: one row per (document, route, zone)
python3 london.py       # TfL running schedules
python3 crawley.py      # Metrobus, from OCR text in $ZPV_WORK/ocr/
python3 section.py      # checks, zone summaries, data/zone_pdf_validation.csv
python3 write_section.py  # the report section, to $ZPV_WORK/section.md
```

`ttread.py` is the column reader: it groups printed times into journey
columns, expands "then every N minutes" and "at these minutes past the hour"
blocks, drops school-day-only columns, and separates routes that share a
table. `verdict.py` is a Python port of `gap_verdict()` in `R/lsoa_gap.R`,
used only to label the zones; it reproduces the report's tally exactly.
