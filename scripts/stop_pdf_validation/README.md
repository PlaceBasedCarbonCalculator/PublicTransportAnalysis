# Stop-level PDF validation

The documents behind the section "The stops where TNDS and BODS GTFS disagree
most" in `reports/pdf_validation.md`. That section is built by the pipeline
(`stop_pdf` target, `R/stop_pdf_validation.R`); these scripts only collect and
read the documents, which are a fixed input.

```
python -I scripts/stop_pdf_validation/read_docs.py          # -> data/stop_pdf_documents.csv
python -I scripts/stop_pdf_validation/read_docs.py --show HULL   # check one place's readings
```

Rerun `read_docs.py` when a document is added to `data/example_timetables/`
(add it to `READS`) or a reading place changes (`HUBS`). It reuses the column
reader of the zone checks (`../zone_pdf_validation/ttread.py`) and carries
over their zone readings from `data/zone_pdf_validation.csv`. Needs Python 3
with `pdfplumber`, and `pdftotext`.

## Where the documents came from (November 2026)

The counting window is 27 July – 9 August 2026. Few operators keep an edition
once it has ended, so the source decides whether the edition in force can be
had at all.

| Operator | Source | Editions |
|---|---|---|
| Brighton & Hove, Metrobus, East Yorkshire, Go North East, Central Connect, Hedingham, Compass, Transdev Keighley | `passenger-line-assets.s3.eu-west-1.amazonaws.com`, listable: `../zone_pdf_validation/s3list.py <prefixes>` then `pick_s3.py s3keys.txt` | every edition; the picker takes the latest on or before the window start and reports any starting inside it |
| First (Essex opco 7, South Yorkshire opco 23) | `firstbus.co.uk/api/timetables/pdf?opco=N&service=CODE&day=mf\|sa\|su&print=pdf`; `first_dl.sh` tries `ROUTE` and `ROUTE-FE` | current only. The API takes `&date=YYYY-MM-DD`, but returns "does not run on this day" for an edition that has ended |
| National Express West Midlands | now `westmidlandsbus.co.uk`; `node nxdl.js <slug> <out.pdf>` with Playwright (`PW_CHROMIUM` may point at a Chromium already installed) | current only (1 November 2026). The 6, 50 and 74 summer editions were collected in July |
| Stagecoach | `tis-kml-stagecoach.s3.amazonaws.com/PdfTimetables/<code>.pdf`, codes like `XGAO013`/`XGCO015` (not listable) | current only. Older editions sit at unguessable `stagecoachbus.com/media-library/...` paths |
| Arriva | no PDFs; the service page (`arrivabus.co.uk/services/<code>`) loads `/_ajax/lines/timetable/<code>?date=&direction=`, saved whole by `arriva_dl.py` into `data/example_timetables/arriva/` (a Tuesday, Saturday and Sunday, both directions) and read row by row, columns split by their service header | current only: a July date returns "no timetables available" |
| Tyne and Wear (Nexus) | `nexus.org.uk` now redirects to `travelnortheast.uk`, a JavaScript journey planner with no static PDF links | — |

The Internet Archive was tried for July captures (it holds some First API
PDFs from June–August 2026, e.g. `opco=24`, with `&date=` in the URL) but was
offline throughout; it is the first place to look for the missing July
editions.

bustimes.org lists the services at each case stop and links their operators,
which is how routes were matched to service codes. It is not used as a
referee: it is built from the same operator TransXChange as BODS and shows
only current and future dates.
