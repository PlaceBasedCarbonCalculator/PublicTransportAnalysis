# Validating the converted feeds against published timetables.
#
# The multi-year comparison (R/comparison.R) can say the three sources
# disagree; only a published timetable says which is right. This checks
# individual routes in all three sources against the PDFs in
# data/example_timetables, over the current snapshot (validation_snapshot()),
# because published timetables are obtainable for today and rarely for the
# past.
#
# Routes are resolved by public number plus an operator pattern, never by
# route_id: ids are assigned per snapshot and differ between the three feeds.

#' Routes with a published timetable, and how to read each one
#'
#' `format` selects the reader in R/pdf_timetable.R:
#'   tfl   - TfL running schedule, one row per vehicle journey (`node` names
#'           the timing point counted)
#'   column- passenger timetable, one column per journey (`stop_regex` names
#'           the row counted, `directions` separates the two directions)
#'
#' `expect` is the journeys-per-operating-day the document implies, where it
#' can be read off unambiguously; NA where the document abbreviates in a way
#' that cannot be resolved (see the 142).
#'
#' Two different stop patterns, doing two different jobs:
#'   `stop_regex`      matches the reference stop's row *label in the document*
#'   `stop_name_regex` matches the same stop's `stop_name` *in the feeds*, and
#'                     is what confines the comparison to routes that actually
#'                     serve it - see feed_route_departures(). It need not be
#'                     unique nationally, only within a candidate route, so the
#'                     distinctive part of the name is enough and is preferred:
#'                     NaPTAN writes Fife Leisure Park as plain "Leisure Park"
#'                     and Costock Main Street as plain "Main Street".
#'
#' Where a `note` quotes a TNDS-versus-BODS-GTFS figure, that figure is the
#' **selection rationale**: it comes from the February 2026 comparison window,
#' which is what these routes were picked from, and not from the window this
#' validation counts over. The comparison has since moved to the July snapshot
#' and February was dropped (see comparison_snapshots()), so those numbers should
#' be read as "this is why the route is here", never as a current measurement.
#' The current measurement is the `Ratio` column of the validation report, which
#' is computed from the feeds this function is run against.
validation_routes <- function() {
  list(
    list(key = "279", short_name = "279", operator = "Arriva London",
         format = "tfl", node = "AD803",
         files = c(MT = "Schedule_279-MT.pdf", Fr = "Schedule_279-Fr.pdf",
                   Sa = "Schedule_279-Sa.pdf", Su = "Schedule_279-Su.pdf"),
         note = "TfL running schedule; every journey listed"),

    list(key = "69", short_name = "69",
         operator = "Blue Triangle|Go.?Ahead London",
         format = "tfl", node = "AA501",
         files = c(MT = "Schedule_69-MT.pdf", Fr = "Schedule_69-Fr.pdf",
                   Sa = "Schedule_69-Sa.pdf", Su = "Schedule_69-Su.pdf",
                   MTNt = "Schedule_69-MTNt.pdf", FrNt = "Schedule_69-FrNt.pdf",
                   SaNt = "Schedule_69-SaNt.pdf", SuNt = "Schedule_69-SuNt.pdf"),
         combine = c(MTNt = "MT", FrNt = "Fr", SaNt = "Sa", SuNt = "Su"),
         note = paste("day and night schedules combine to one operating day;",
                      "these are the May 2026 contract schedules, so they",
                      "match the current snapshot this is counted against")),
    # TfL also issues route 69 as schooldays/school-holiday variants
    # (MoSc/MoHo, TWTSc/TWTHo, FrSc/FrHo) and as bank holiday, Good Friday,
    # Christmas Eve, Boxing Day and New Year schedules. None is wired in,
    # for two measured reasons: the schooldays and school-holiday schedules
    # carry an identical number of journeys at AA501 (273 either way), so
    # they cannot test the ServicedOrganisation handling. The bank holiday
    # schedules do differ - Bh is 191 against 233 for a normal Monday to
    # Thursday - and 31 August now falls inside the `bankhol` window, so
    # they are testable in principle. What is still missing is the
    # comparison: feed_route_departures() totals a whole 28-day window, in
    # which one substituted day is well inside the noise. Using them needs
    # per-date counts rather than another document.

    list(key = "A1", short_name = "A1", operator = "First Bristol",
         format = "column",
         file = "EFA01__0000979_TP.pdf",
         stop_regex = "^Bristol Airport, Public Transport Interchange",
         stop_name_regex = "Public Transport Interchange",
         directions = c(
           out = "Bristol Airport - Bristol Temple Meads - Bristol Bus Station",
           back = "Bristol Bus Station - Bristol Temple Meads - Bristol Airport"),
         note = "National PTI; all times explicit; Sunday table printed twice"),

    list(key = "21", short_name = "21", operator = "First Bristol",
         format = "column",
         file = "EFA01__0000b3a_TP.pdf",
         stop_regex = "^Newbridge, Newbridge P&R",
         stop_name_regex = "Newbridge P&R",
         directions = c(out = "Newbridge Park & Ride - Bath Centre",
                        back = "Bath Centre - Newbridge Park & Ride"),
         note = "valid from 06/04/2026, so current for this snapshot"),

    list(key = "1_1A", short_name = c("1", "1A"),
         operator = "Stagecoach.*(North West|Cumbria)",
         format = "column",
         file = "CNL 0625 1 1A WEB.pdf",
         # The two directions do not leave from the same stand, and the
         # document capitalises the word differently in each: "Lancaster Bus
         # Station stand 17 dep" outbound, "Lancaster Bus Station Stand 8 dep"
         # inbound. Matching only stand 17 read the outbound tables and
         # silently reported nothing at all for the inbound, halving the route.
         # "dep" is left unanchored so it also matches the "depart" the Sunday
         # tables use, while still excluding the "arr"/"arrive" rows.
         stop_regex = "Lancaster Bus Station [Ss]tand (17|8) dep",
         # NaPTAN has no "Lancaster Bus Station": the stands are named after the
         # street, "Common Garden Street". Matching the document's own wording
         # matched nothing, so this fell back to counting all eight candidate
         # route_ids - Preston - Longridge, Chester - Liverpool, Furness,
         # Whitehaven - and read 3.46x the document.
         stop_name_regex = "Common Garden",
         directions = c(
           to_heysham = "Lancaster University . Bus Station . Morecambe . Heysham",
           to_university = "Heysham . Morecambe . Bus Station . Lancaster University"),
         note = paste("frequent periods abbreviated as minutes past each hour",
                      "and expanded; carries university term-time and",
                      "holiday-only journeys, so it exercises the",
                      "ServicedOrganisation handling directly")),

    # Greater Manchester. The 143 and 111 carry the largest TNDS-versus-BODS
    # gap in the whole comparison (143: 24,158 against 336). Both are summer
    # editions, which for once is what is wanted: 19 July - 29 August 2026
    # contains the validation window entirely.
    list(key = "111", short_name = "111", operator = "Bee Network|Metroline",
         format = "column", file = "111_26-SC-0230_Summer.pdf",
         stop_regex = "^Southern Cemetery, Bus Station",
         stop_name_regex = "Southern Cemetery",
         directions = NULL,
         note = paste("summer edition covering the window; the frequent",
                      "period is abbreviated in-column and this page mixes",
                      "a 12-minute and a 15-minute block")),

    list(key = "143", short_name = "143", operator = "Bee Network|Metroline",
         format = "column", file = "143_26-SC-0248_Summer.pdf",
         stop_regex = "^West Didsbury, Central Road",
         stop_name_regex = "Central Road",
         directions = NULL,
         note = "summer edition covering the window; 10-minute headway block"),

    # Scotland. These replace the unusable Lothian documents: the SPT
    # generator prints every time explicitly, so no expansion is needed.
    # Several routes share one table, hence routes_in_table/count_routes.
    list(key = "G1", short_name = c("1", "1A"),
         operator = "First Glasgow|Greater Glasgow",
         format = "column",
         files = c(MF = "timetable_1-1A-1C-1E.pdf",
                   Sa = "timetable_1-1A-1C-1E_saturday.pdf",
                   Su = "timetable_1-1A-1C-1E_sunday.pdf"),
         stop_regex = "^Clydebank, Chalmers St",
         stop_name_regex = "Chalmers Street",
         directions = NULL,
         routes_in_table = c("1", "1A", "1C", "1E"),
         count_routes = c("1", "1A"),
         note = paste("both directions are printed without any direction",
                      "heading - the stop order simply reverses partway -",
                      "so this counts departures at one stop across both")),

    list(key = "X85", short_name = c("X85", "X87"),
         operator = "First Glasgow|Greater Glasgow",
         format = "column",
         files = c(MF = "timetable_X85-X87.pdf",
                   Sa = "timetable_X85-X87_saturday.pdf",
                   Su = "timetable_X85-X87_sunday.pdf"),
         stop_regex = "^Kirkintilloch, Catherine St",
         stop_name_regex = "Catherine Street",
         directions = NULL,
         routes_in_table = c("X85", "X87"),
         note = "two routes in one table, both counted"),

    list(key = "F38", short_name = "38", operator = "First|Midland Bluebird",
         format = "column", file = "38-timetable-20250915-5aa561fc.pdf",
         stop_regex = "^Larbert Viaduct",
         stop_name_regex = "Viaduct",
         directions = NULL,
         note = paste("Falkirk-Stirling; the 'then every 15 mins until'",
                      "legend is stacked one word per stop row inside the",
                      "table, which is why it needs positional reading")),

    list(key = "SF2A", short_name = "2A", operator = "Stagecoach",
         format = "column", file = "ESCOT_Fife_Service_2A_Timetable.pdf",
         stop_regex = "^Fife Leisure Park",
         stop_name_regex = "Leisure Park",
         directions = NULL,
         note = "Dunfermline circular; minutes-past-the-hour abbreviation"),

    list(key = "SF34", short_name = c("34", "34A", "34B"),
         operator = "Stagecoach",
         format = "column",
         file = "ESCOT_Fife_Service_34_34A_34B_Timetable.pdf",
         stop_regex = "^Chapel Roundabout",
         stop_name_regex = "Chapel Roundabout",
         directions = NULL,
         routes_in_table = c("34", "34A", "34B"),
         note = "Kirkcaldy circular; three routes in one table"),

    list(key = "SF90", short_name = c("90A", "90B", "91A"),
         operator = "Stagecoach",
         format = "column", file = "ESCOT_Special_Fife_90_91.pdf",
         stop_regex = "^David Russell Apts",
         stop_name_regex = "David Russell",
         directions = NULL,
         routes_in_table = c("90A", "90B", "91A"),
         note = "St Andrews circular; three routes in one table"),

    list(key = "SFX24", short_name = c("X24", "X27"),
         operator = "Stagecoach",
         format = "column", file = "ESCOT_Special_X24_X27.pdf",
         # The label's word order is not stable across the document's fourteen
         # pages: most read "Glenrothes Bus Station Dep", one reads "Dep
         # Glenrothes Bus Station", and anchoring on the first form dropped that
         # page's departures.
         stop_regex = "Glenrothes Bus Station Dep|Dep Glenrothes Bus Station",
         stop_name_regex = "Glenrothes Bus Station",
         directions = NULL,
         routes_in_table = c("X24", "X27"),
         note = paste("Fife-Glasgow limited stop; tests longer-distance",
                      "services. Saturday is still flagged unreliable: the",
                      "abbreviated block closes on the following page, so the",
                      "run of minute cells that ends the row has nothing to",
                      "bound it and is not expanded")),

    # Wales. TNDS is effectively the only source with real coverage there,
    # so until now nothing independent checked it.
    list(key = "CDF1", short_name = "1", operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "1-timetable-20260719-78437e73.pdf",
         stop_regex = "^Leckwith Close",
         stop_name_regex = "Leckwith Close",
         directions = NULL,
         note = "city circle, commencing 19/07/2026 so current for the window"),

    list(key = "CDF24", short_name = "24", operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "24-timetable-20260719-baf4da5e.pdf",
         stop_regex = "^Three Elms",
         stop_name_regex = "Three Elms",
         directions = NULL,
         note = "commencing 19/07/2026; minutes-past-the-hour abbreviation"),

    list(key = "CDF608", short_name = "608",
         operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "608-timetable-20230903-be43cf29.pdf",
         stop_regex = "^Channel View Road",
         stop_name_regex = "Channel View",
         directions = NULL,
         note = paste("schooldays-only school service, one journey each way,",
                      "and it reads zero in both sources. That is the right",
                      "answer, not a gap: the counting window is inside the",
                      "summer holidays. The other reading - that the service",
                      "has been withdrawn since the 2023 edition of this",
                      "document - is ruled out, since bustimes.org still lists",
                      "Cardiff Bus's 608 James Street to Fitzalan School as",
                      "running (checked 2026-07-30). Keep it as the control",
                      "for a school service correctly absent")),

    list(key = "CDF62", short_name = c("62", "63", "64"),
         operator = "Cardiff Bus|Bws Caerdydd",
         format = "column", file = "62-timetable-20260412-d4fd5ee2.pdf",
         stop_regex = "^Llandaff Fields",
         stop_name_regex = "Llandaff Fields",
         directions = NULL,
         routes_in_table = c("62", "63", "64"),
         note = paste("valid from 12/04/2026; three routes in one table.",
                      "Counted at Llandaff Fields because it is the only",
                      "stop named identically in both directions - the",
                      "inbound tables call the outbound's Black Lion stop",
                      "something else. Carries a 'Sundays & public holidays'",
                      "table, so it also covers the 31 August holiday")),

    # Kinchbus published only artwork as PDF - no text layer at all - so
    # this one comes from a Word extract instead.
    list(key = "KB9", short_name = "9", operator = "Kinchbus|trentbarton",
         format = "docx", file = "Kinchbus 9.docx",
         stop_regex = "^Costock Main Street",
         stop_name_regex = "Main Street",
         note = paste("Loughborough-Nottingham. One Monday-to-Saturday table",
                      "carries both day types, marked per journey: NS runs",
                      "Monday to Friday only, S on Saturdays only, unmarked",
                      "on both, so it is read once per day type. Also",
                      "publishes a separate Sunday & Bank Holiday Monday",
                      "table - the only bank holiday reference in the set")),

    # Matched on BOTH names because the two sources number it differently and
    # only one of them carries a long name at all: TNDS calls the line "all"
    # with long name "Derby - Allestree", the DfT's GTFS calls it "TA" and
    # leaves route_long_name empty - as it does for all 12,822 of its routes.
    # Matching on the long name alone therefore found this service in TNDS and
    # nothing in the GTFS, which read as a coverage gap (4,184 against 0) when
    # the GTFS does carry it. bustimes.org corroborates: it renders the service
    # as "TA - the allestree" from "trentbarton/Bus Open Data Service (BODS)".
    list(key = "TBALL", short_name = c("TA", "all"),
         long_name_regex = "allestree",
         operator = "trentbarton|Kinchbus|Wellglade",
         format = "docx", file = "Kinchbus allestree .docx",
         stop_regex = "^Kedleston Road University",
         stop_name_regex = "Kedleston Road",
         note = paste("trentbarton Derby-Allestree, from a Word extract:",
                      "the six PDFs of this timetable have no text layer at",
                      "all. The document names no route number - its 'Bus",
                      "No' column is blank - so it is matched on the line",
                      "names the feeds use ('all' in TNDS, 'TA' in the GTFS)",
                      "as well as on the long name.",
                      "Monday-Friday includes journeys marked 'F - Fridays",
                      "only', so that figure is the Friday service level and",
                      "slightly overstates Monday to Thursday. Carries a",
                      "Sunday & Bank Holiday Monday table")),

    # Routes chosen from the February 2026 comparison because TNDS and BODS
    # GTFS disagreed on them, so a document decides which is right. Three groups:
    # services TNDS carries and BODS GTFS does not (727, 59, 400), services
    # where TNDS is about twice BODS GTFS (125, 320, X38), and one where the
    # route number alone is ambiguous nationally (57/59/59a Barnsley, which is
    # a different 59 from Aberdeen's).
    list(key = "BB727", short_name = "727", operator = "Stagecoach Bluebird",
         format = "column", file = "0426 Service 727.pdf",
         stop_regex = "^P&J Live Arena",
         # No stop_name_regex: NaPTAN has no "P&J Live Arena", "Bucksburn
         # Police Station" or "Northfield Terminus", so there is nothing to
         # confine this with. Harmless here - "Stagecoach Bluebird" plus 727 is
         # already specific, unlike the bare "Stagecoach" patterns.
         directions = NULL,
         note = paste("Aberdeen Airport - Stonehaven. Selected because TNDS",
                      "carried it and BODS GTFS did not (4,439 journeys",
                      "against 0), so this tests whether that coverage is",
                      "real. Counted at P&J Live Arena, which appears in both",
                      "directions' tables; every time is explicit")),

    list(key = "BB59", short_name = "59", operator = "Stagecoach Bluebird",
         format = "column", file = "0426 Service 59.pdf",
         stop_regex = "^Aberdeen Royal Infirmary",
         stop_name_regex = "Aberdeen Royal Infirmary",
         directions = NULL,
         note = paste("Northfield - Balnagask, selected as also TNDS-only",
                      "(4,156 against 0). Aberdeen Royal Infirmary is",
                      "mid-route and appears in both directions")),

    list(key = "OX400", short_name = "400", operator = "Oxford Bus",
         format = "column", file = "400-timetable-20260222-8b0bfa70.pdf",
         stop_regex = "^Wheatley Ambrose Rise",
         stop_name_regex = "Ambrose Rise",
         directions = NULL,
         note = paste("Thame - Oxford, selected as TNDS-only (4,460 against",
                      "0). This",
                      "generator prints the row label to the *right* of the",
                      "times, which is why the label is matched with the",
                      "leading cells stripped")),

    list(key = "SC125", short_name = "125", operator = "Stagecoach",
         format = "column", file = "C&L 125 0526 WEB.pdf",
         stop_regex = "^Bolton Interchange",
         stop_name_regex = "Bolton Interchange",
         directions = NULL,
         note = paste("Preston - Bolton. Selected because TNDS read 1.83x",
                      "BODS GTFS (9,322 against 5,091) with BODS TransXChange",
                      "siding with GTFS, making TNDS the one to doubt")),

    # TNDS files this under "Arriva Merseyside" where the DfT's GTFS says
    # "Arriva North West", and holds it as three route_ids - St Helens Bus
    # Station - Wigan twice (282 trips each) plus Chalon Way West - Wigan (264)
    # - against one in the GTFS. That is the 1.96x, visible in the route table
    # before any counting.
    list(key = "AN320", short_name = "320",
         operator = "Arriva Merseyside|Arriva North West",
         format = "column", file = "20-320-19Jul26.pdf",
         stop_regex = "^St Helens Temporary Bus Hub",
         # NaPTAN does not carry the word "Temporary"; left unset rather than
         # matched loosely on "Bus Hub", which is five unrelated stops.
         #
         # This document puts its two routes on separate pages, each headed
         # with its own number, rather than in one table with a column header
         # row - so routes_in_table/count_routes has nothing to work on and
         # silently counted both routes' journeys against the 320. The page
         # heading behaves exactly like a direction title, so it is matched as
         # one and count_directions keeps only the 320's pages.
         directions = c(r20 = "^20 Earlestown", r320 = "^320 St Helens"),
         count_directions = "r320",
         note = paste("St Helens - Wigan. Selected because TNDS read 1.96x",
                      "BODS GTFS (6,228 against 3,176), which the route table",
                      "traces to TNDS holding three route_ids against one.",
                      "Routes 20 and 320 are printed on",
                      "separate pages of one document; only the 320's pages",
                      "are counted. Saturday prints its row labels to the",
                      "right of the times")),

    list(key = "TBX38", short_name = "X38", operator = "trentbarton|Trent Barton",
         format = "docx", file = "Trentbarton X38.docx",
         stop_regex = "^Derby, Victoria Street",
         note = paste("Derby - Burton. Selected because TNDS read 1.98x BODS",
                      "GTFS (8,144 against 4,116). From a Word extract, and the least",
                      "trustworthy of this batch: reading it at Burton High",
                      "Street returns 4 journeys for a Saturday against 113",
                      "for a weekday, so the reader is not handling all",
                      "twelve of its tables. Derby, Victoria Street reads",
                      "with a plausible shape; treat with caution and check",
                      "Continuous before using it")),

    list(key = "SY57", short_name = c("57", "59", "59A"),
         operator = "Stagecoach Yorkshire",
         format = "column", file = "57 59 59a Barnsley - Royston.pdf",
         stop_regex = "^Barnsley Interchange A13",
         stop_name_regex = "Barnsley Interchange",
         directions = NULL,
         routes_in_table = c("57", "59", "59a"),
         note = paste("Barnsley - Royston. The first document here to print",
                      "its times as '07:05' rather than '0705', which the",
                      "reader could not see at all: with no token looking",
                      "like a time, every data row was classified as a",
                      "heading and nothing was read")),

    list(key = "142", short_name = "142", operator = "Bee Network|Metroline",
         format = "column",
         file = "142_26-SC-0249_Summer.pdf",
         stop_regex = "^East Didsbury, Parrs Wood",
         stop_name_regex = "Parrs Wood",
         directions = NULL,
         skip = TRUE,
         note = paste("SUMMER timetable (19 Jul - 29 Aug 2026): covers this",
                      "snapshot, but merges route 42 journeys into the same",
                      "table, so the count is not attributable to route 142")),

    # Lothian: poppler takes ten minutes or more per document, so these two
    # dominate the runtime of this target. They are the only Scottish
    # validation available, which is worth the wait.
    # Direction titles are matched on the route number and the terminus named
    # first, not on the full "A to B" phrase: reading these documents as
    # positioned words reorders it to "Airport City Centre to".
    list(key = "L100", short_name = "100", operator = "Lothian",
         format = "column", file = "r100-260222.pdf",
         stop_regex = "^Edinburgh Airport",
         stop_name_regex = "^Airport$",
         directions = c(from_airport = "^100 Airport",
                        to_airport = "^100 City Centre"),
         note = paste("NOT USABLE YET. The frequent-service period is a",
                      "separate mini-table whose closing time sits on a",
                      "different baseline from its opening time, so the block",
                      "is not detected and the count omits it entirely. Also",
                      "note the legend reads 'up to every 10 mins', which is",
                      "a ceiling rather than a timetable. Needs a reader that",
                      "assigns cells in two dimensions instead of by text",
                      "row.")),

    list(key = "L26", short_name = "26", operator = "Lothian",
         format = "column", file = "r26-260222.pdf",
         stop_regex = "^Clerwood",
         directions = c(to_seton = "^26 Clerwood",
                        to_clerwood = "^26 Seton Sands"),
         note = paste("NOT USABLE YET, same reason as the 100. Saturday also",
                      "runs over two pages as 'Saturdays continued'.")),

    # Collected 2026-07-30 for the two ends of the zone-level disagreement in
    # lsoa_disagreement.md: Birmingham, where TNDS reads about twice BODS GTFS
    # on services both carry, and Bristol, where BODS GTFS reads several times
    # TNDS. Both editions are current for the counting window.
    #
    # These are the documents that made tt_year_tokens() necessary: National
    # Express prints "Monday to Friday ... From 19th July 2026" on one line,
    # and the bare "2026" parsed as 20:26, so the row was read as data, no day
    # heading was ever recognised and the whole document returned nothing.
    list(key = "NX6", short_name = "6",
         operator = "National Express|NX ?Bus|West Midlands",
         format = "column", file = "nxbus_6.pdf",
         stop_regex = "^Birmingham Moor St",
         stop_name_regex = "Moor Street",
         directions = NULL,
         note = paste("Solihull - Birmingham, edition from 19 July 2026.",
                      "Frequent-period block expanded. Counted at Birmingham",
                      "Moor Street Queensway, the city end of the route")),

    list(key = "NX50", short_name = "50",
         operator = "National Express|NX ?Bus|West Midlands",
         format = "column", file = "nxbus_50.pdf",
         stop_regex = "^Birmingham Moor Street",
         stop_name_regex = "Moor Street",
         directions = NULL,
         note = paste("Druids Heath - Birmingham, edition from 19 July 2026.",
                      "Frequent-period block expanded")),

    list(key = "BR43", short_name = "43", operator = "First",
         format = "column", file = "Bristol 43.pdf",
         stop_regex = "^City Centre, The Centre",
         stop_name_regex = "The Centre",
         directions = NULL,
         note = paste("Imperial Park - Cadbury Heath via Bristol city centre.",
                      "Every time explicit, nothing to expand. Counted at The",
                      "Centre, which is inside the zones where BODS GTFS most",
                      "exceeds TNDS")),

    list(key = "BR24", short_name = "24", operator = "First",
         format = "column", file = "Brisol 24--A4_timetable_Web_0.pdf",
         stop_regex = "^City Centre",
         stop_name_regex = "The Centre",
         directions = NULL,
         note = paste("Southmead Hospital - Ashton Gate via the city centre.",
                      "Every time explicit"))
    # Not wired in: 'Bristol 75 76.pdf' prints two routes in one table and the
    # reader reads them as one (371 Monday-Friday journeys for what should be
    # two services), so it needs routes_in_table and a header row the generator
    # does not provide; 'Bristol service 1 2.pdf' and both 'Bristol M1' files
    # return no rows at all, having no day-type heading the reader can find.
  )
}

#' Departures per operating day implied by a route's published timetable
#'
#' @return data.table(key, daytype, direction, journeys, expanded)
published_departures <- function(spec, dir = "data/example_timetables") {
  if (identical(spec$format, "tfl")) {
    out <- data.table::rbindlist(lapply(names(spec$files), function(dt) {
      v <- read_tfl_schedule(file.path(dir, spec$files[[dt]]), node = spec$node)
      data.table::data.table(file_daytype = dt, direction = "all",
                             minutes = list(v))
    }))
    # TfL issues the night portion of a 24-hour route as its own schedule
    # (route 69's MTNt, FrNt, ...). One operating day is the day schedule plus
    # its night schedule, so they are combined before counting.
    out[, daytype := if (is.null(spec$combine)) file_daytype else
      ifelse(file_daytype %in% names(spec$combine),
             spec$combine[file_daytype], file_daytype)]
    return(out[, list(journeys = length(unlist(minutes)), expanded = FALSE,
                      upper_bound = FALSE, reliable = TRUE,
                      minutes = list(sort(unlist(minutes)))),
               by = list(daytype, direction)])
  }

  # Several routes are published as one document per day type.
  files <- if (!is.null(spec$files)) spec$files else c(all = spec$file)
  res <- if (identical(spec$format, "docx")) {
    lapply(files, function(f)
      read_docx_timetable(file.path(dir, f), stop_regex = spec$stop_regex))
  } else lapply(files, function(f)
    read_column_timetable(file.path(dir, f),
                          stop_regex = spec$stop_regex,
                          direction_patterns = spec$directions,
                          routes_in_table = spec$routes_in_table,
                          count_routes = spec$count_routes %||% spec$short_name,
                          day_patterns = spec$day_patterns %||%
                            eval(formals(read_column_timetable)$day_patterns)))
  times <- data.table::rbindlist(lapply(seq_along(res), function(i) {
    t <- res[[i]]$times
    if (nrow(t)) t[, block := block + i * 1000L]
    t
  }))
  reliable <- all(vapply(res, function(x) isTRUE(x$reliable), logical(1)))
  times <- tt_dedupe_repeated_blocks(times)
  # Where a document covers several routes on separate pages, the page heading
  # is matched as a direction and only the wanted ones are kept. Filtering here
  # rather than in the reader keeps the reliability checks looking at the whole
  # document, which is what they are about.
  if (!is.null(spec$count_directions) && nrow(times))
    times <- times[direction %in% spec$count_directions]
  if (!nrow(times)) {
    return(data.table::data.table(daytype = character(0), direction = character(0),
                                  journeys = integer(0), expanded = logical(0),
                                  upper_bound = logical(0), reliable = logical(0),
                                  minutes = list()))
  }
  out <- times[, list(journeys = .N, expanded = any(expanded),
                      upper_bound = any(upper_bound),
                      minutes = list(sort(minutes))),
               by = list(daytype, direction)]
  out[, continuous := vapply(minutes, tt_no_hole, logical(1))]
  out[, reliable := reliable & continuous]
  out[]
}

#' Does a day's reading have a hole in it?
#'
#' The failure that matters is not a reader that crashes but one that quietly
#' returns a plausible subset - a whole block of the day missed because its
#' heading, its stop label or its abbreviation was written differently. It
#' shows up as an implausible gap between consecutive departures: the Fife 34
#' reads as running 06:10-10:10 and then nothing until 18:31.
#'
#' The test is deliberately loose, because genuinely sparse services exist
#' and a false alarm costs a usable reference. It only fires when a single
#' gap dwarfs the rest of the day's spacing.
tt_no_hole <- function(m, floor_mins = 150, factor = 8) {
  m <- sort(unique(m))
  if (length(m) < 6) return(TRUE)
  g <- diff(m)
  max(g) <= max(floor_mins, factor * stats::median(g))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Journeys operating on each date of the window, for one route in one feed
#'
#' Routes are located by public number and operator, and every matching
#' route_id is summed: a source that splits one service across several ids
#' (TNDS holds the Manchester 142 under three) must still be compared as one.
#'
#' Route number plus operator is not by itself specific enough. A bus number is
#' only unique within a town, and the agency patterns have to stay loose because
#' the sources name the same operator differently - TNDS calls Stagecoach's Fife
#' operation "Stagecoach East Scotland" where the timetable says "Stagecoach",
#' and holds Lancaster's route 1 under both "Stagecoach North West" and
#' "Stagecoach Cumbria and Lancashire". Matching on `"Stagecoach"` and `"2A"`
#' therefore collected eighteen route_ids: Oxford - Kidlington, Gloucester -
#' Upton St Leonards, Sheffield - Barnsley and thirteen more alongside the
#' Dunfermline circular that was wanted. Every one of those journeys was
#' counted against a Fife timetable, in both sources equally, which is why the
#' two sources agreed with each other and diverged wildly from the document.
#'
#' `stop_name_regex` resolves it. The published figure counts departures at one
#' named stop, so the comparable feed figure is trips that call there - and a
#' Gloucester 2A calls at no stop named "Fife Leisure Park". A stop name that is
#' hopelessly ambiguous nationally ("Leisure Park" matches thirty stops) becomes
#' unique once intersected with a candidate route's own stops. This also makes
#' the two figures measure the same thing: before, `Published` counted one stop
#' and the feed columns counted whole routes.
#'
#' @param stop_name_regex regex matching the reference stop's name in the feed's
#'   stops.txt. NULL, or a name no candidate route calls at, falls back to
#'   counting every trip of the matched routes; `stop_matched` reports which
#'   happened, because the fallback is the loose comparison described above.
#' @return list(route_ids, runs, runs_at_stop, runs_all_stops, stop_matched)
feed_route_departures <- function(gtfs, short_name, operator, win,
                                  long_name_regex = NULL,
                                  stop_name_regex = NULL) {
  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  agency <- data.table::as.data.table(as.data.frame(gtfs$agency))
  routes[, route_id := as.character(route_id)]
  if ("agency_id" %in% names(routes) && "agency_id" %in% names(agency)) {
    routes <- merge(routes,
                    unique(agency[, list(agency_id = as.character(agency_id),
                                         agency_name = as.character(agency_name))],
                           by = "agency_id"),
                    by.x = "agency_id", by.y = "agency_id", all.x = TRUE)
  } else {
    routes[, agency_name := NA_character_]
  }
  # Some operators brand rather than number, so a spec may have to match on the
  # long name - but only TNDS carries one. Every route in the DfT's GTFS has
  # route_long_name empty (12,822 of 12,822 in the July 2026 feed), so a
  # long-name match silently returns nothing there and the route reads as
  # missing. Any spec relying on long_name_regex needs a short name too.
  by_short <- if (is.null(short_name)) rep(FALSE, nrow(routes)) else
    toupper(trimws(routes$route_short_name)) %in% toupper(short_name)
  by_long <- if (is.null(long_name_regex)) rep(FALSE, nrow(routes)) else
    grepl(long_name_regex, routes$route_long_name, ignore.case = TRUE)
  keep <- (by_short | by_long) &
    grepl(operator, routes$agency_name, ignore.case = TRUE)
  ids <- routes$route_id[which(keep)]
  if (!length(ids)) {
    return(list(route_ids = character(0), runs = 0L, runs_at_stop = 0L,
                runs_all_stops = 0L, stop_matched = FALSE))
  }

  trimmed <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                                      enddate = win$enddate)
  runs <- trip_runs_in_window(trimmed)
  trips <- data.table::as.data.table(as.data.frame(trimmed$trips))
  trips[, `:=`(trip_id = as.character(trip_id), route_id = as.character(route_id))]
  trips <- trips[route_id %in% ids, list(trip_id, route_id)]
  runs_all <- sum(runs[trip_id %in% trips$trip_id]$runs)

  at_stop <- NULL
  if (!is.null(stop_name_regex)) {
    stops <- data.table::as.data.table(as.data.frame(gtfs$stops))
    sids <- stops[grepl(stop_name_regex, stop_name, ignore.case = TRUE),
                  as.character(stop_id)]
    if (length(sids)) {
      st <- data.table::as.data.table(as.data.frame(trimmed$stop_times))
      st <- st[as.character(stop_id) %in% sids,
               list(trip_id = as.character(trip_id))]
      hit <- trips[trip_id %in% unique(st$trip_id)]
      if (nrow(hit)) at_stop <- hit
    }
  }

  if (is.null(at_stop)) {
    return(list(route_ids = ids, runs = runs_all, runs_at_stop = runs_all,
                runs_all_stops = runs_all, stop_matched = FALSE))
  }
  # Only routes that actually reach the reference stop are the document's
  # subject; report those rather than every same-numbered route in Britain.
  #
  # `runs` counts every trip of those routes, not only the trips that call at
  # the stop. Restricting to calling trips looks like the exact analogue of the
  # published figure, but it assumes both directions call at a stop of that
  # name, and measurement says otherwise: Cardiff's 62 is counted at Llandaff
  # Fields precisely because that is the only stop named identically in both
  # directions, yet the feeds hold a single stop_id there on the outbound side,
  # so the calling-trip count is 0.53 of the document against 1.02 for the
  # route. Filtering by route loses none of the point of this - the Gloucester
  # 2A still goes, because its route never reaches Fife (SF2A 8,648 -> 1,000)
  # and London's 143 still goes (9,992 -> 5,288). `runs_at_stop` is kept
  # alongside so the stricter reading stays visible.
  keep_ids <- sort(unique(at_stop$route_id))
  list(route_ids = keep_ids,
       runs = sum(runs[trip_id %in% trips[route_id %in% keep_ids]$trip_id]$runs),
       runs_at_stop = sum(runs[trip_id %in% at_stop$trip_id]$runs),
       runs_all_stops = runs_all, stop_matched = TRUE)
}

#' Check every route with a published timetable against validation_sources()
#'
#' Writes data/pdf_validation.Rds and returns its path.
validate_published_timetables <- function(zones_path, ..., cfg = load_cfg()) {
  spec <- validation_snapshot()
  wins <- lapply(validation_windows(), study_window)
  for (nm in names(wins))
    message("Validation window ", nm, ": ", wins[[nm]]$startdate, " to ",
            wins[[nm]]$enddate)

  routes <- validation_routes()
  published <- lapply(routes, function(r) {
    if (isTRUE(r$skip)) return(NULL)
    out <- try(published_departures(r), silent = TRUE)
    if (inherits(out, "try-error")) {
      warning("could not read the timetable for ", r$key, ": ",
              conditionMessage(attr(out, "condition")))
      return(NULL)
    }
    out[, key := r$key][]
  })
  names(published) <- vapply(routes, `[[`, "", "key")

  feeds <- list()
  for (src in validation_sources()) {
    message("Reading ", src)
    gtfs <- read_feed(spec[[src]], cfg)
    gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
    feeds[[src]] <- data.table::rbindlist(lapply(names(wins), function(wn) {
      data.table::rbindlist(lapply(routes, function(r) {
        f <- feed_route_departures(gtfs, r$short_name, r$operator, wins[[wn]],
                                   long_name_regex = r$long_name_regex,
                                   stop_name_regex = r$stop_name_regex)
        # setDT(list(...)) rather than data.table(...): data.table() reserves
        # `key` for the sort key, so data.table(key = r$key, ...) tries to key
        # the table by a column named "279" instead of creating a key column.
        data.table::setDT(list(key = r$key, source = src, window = wn,
                               route_ids = paste(f$route_ids, collapse = "+"),
                               runs = f$runs,
                               runs_at_stop = f$runs_at_stop,
                               runs_all_stops = f$runs_all_stops,
                               stop_matched = f$stop_matched))
      }))
    }))
    rm(gtfs); gc()
  }

  out <- list(snapshot = spec, window = wins,
              routes = routes,
              published = published,
              feeds = data.table::rbindlist(feeds))
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(cfg$out_dir, "pdf_validation.Rds")
  saveRDS(out, path)
  path
}

#' Knit the validation report to markdown
render_validation_report <- function(validation_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$validation_path <- normalizePath(validation_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "pdf_validation.Rmd", output = "pdf_validation.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "pdf_validation.md")
}
