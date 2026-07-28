# Reading published timetables (PDF) into comparable departure times.
#
# Three document families appear in data/example_timetables:
#
#  1. TfL running schedules ("Schedule_<route>-<daytype>.pdf") - one row per
#     vehicle journey, a column per timing point. The strongest reference we
#     have: every journey is listed, including garage runs.
#  2. National PTI passenger timetables ("EFA01__*.pdf") - one column per
#     journey, a row per stop, all times explicit.
#  3. Operator passenger timetables (Stagecoach, Bee Network, Lothian) - the
#     same column layout, but frequent-service periods are abbreviated, either
#     as "then at these minutes past each hour until" (a repeating minute
#     pattern) or "and every N mins until" (a stated headway). Those blocks
#     are expanded here; see expand_headway_block().
#
# Everything returns departure times in minutes since midnight, with journeys
# running past midnight normalised onto the previous service day (+24h), which
# is how the schedules write them.

MINS_PER_DAY <- 24L * 60L

#' Clock time to minutes since midnight
#'
#' Accepts "HHMM" (published timetables) and "HH:MM[:SS]" (GTFS). Values below
#' 04:00 are treated as belonging to the previous service day.
tt_minutes <- function(x, wrap = TRUE) {
  x <- trimws(as.character(x))
  m <- ifelse(grepl(":", x, fixed = TRUE),
              as.integer(sub("^(\\d+):.*$", "\\1", x)) * 60L +
                as.integer(sub("^\\d+:(\\d+).*$", "\\1", x)),
              as.integer(substr(x, 1, 2)) * 60L +
                as.integer(substr(x, 3, 4)))
  if (wrap) m <- ifelse(!is.na(m) & m < 4L * 60L, m + MINS_PER_DAY, m)
  m
}

tt_format <- function(m) sprintf("%02d:%02d", m %/% 60L, m %% 60L)

#' Expand an abbreviated frequent-service block into individual departures
#'
#' Published timetables collapse a repeating period into one printed column,
#' bracketed by the last explicit departure before it and the first after it.
#' Two dialects occur:
#'
#'  * `minutes`: the minutes past each hour the service departs, e.g.
#'    c(44, 54, 4, 14, 24, 34) for a ten-minute service. The pattern repeats
#'    every hour.
#'  * `headway`: a stated interval in minutes, e.g. "every 10 mins".
#'
#' Either way the expansion is every departure strictly between `prev` and
#' `next_`, so the printed columns on each side are not double counted.
#'
#' @param prev,next_ bracketing departures, minutes since midnight
#' @param minutes integer vector of minutes past the hour, or NULL
#' @param headway interval in minutes, or NULL
#' @return integer vector of departures, minutes since midnight
expand_headway_block <- function(prev, next_, minutes = NULL, headway = NULL) {
  if (is.na(prev) || is.na(next_) || next_ <= prev) return(integer(0))

  if (!is.null(headway) && !is.na(headway) && headway > 0) {
    # The bracketing times can be closer together than the headway, which
    # happens wherever a legend column sits between two adjacent journeys.
    if (prev + headway > next_ - 1L) return(integer(0))
    out <- seq(prev + headway, next_ - 1L, by = headway)
    return(as.integer(out))
  }

  if (is.null(minutes) || !length(minutes)) return(integer(0))
  minutes <- sort(unique(as.integer(minutes) %% 60L))
  hours <- (prev %/% 60L):((next_ %/% 60L) + 1L)
  out <- sort(as.integer(outer(hours * 60L, minutes, `+`)))
  out[out > prev & out < next_]
}

#' Locate "every N mins" legends and the column each one governs
#'
#' The frequent-service legend is not prose beside the table, it is printed
#' *inside* it, occupying the column where the omitted journeys would have
#' been. Two arrangements occur, and both must be recognised by position
#' rather than by reading the page as text:
#'
#'  * stacked vertically down the column, one word per stop row - Falkirk's
#'    38 prints "then / every / 15 / mins / until" against five consecutive
#'    stops, so the number and the word "mins" are on different rows;
#'  * side by side on the same row - Bee Network prints "12 mins" together,
#'    with "and" / "every" / "until" on the rows above and below.
#'
#' Reading the page as lines therefore never recovers the phrase, which is
#' why `tt_page_headway()` alone is not enough. It matters more than it
#' sounds: one Bee Network page carries a 12-minute block and a 15-minute
#' block, so a single page-level headway would be wrong for one of them.
#'
#' A legend is a number token paired with a "min(s)" token either immediately
#' to its right on the same row, or directly below it in the same column.
#' Requiring the pairing keeps ordinary two-digit timetable cells - the
#' minutes-past-the-hour dialect - from being read as headways.
#'
#' @param p a page's word boxes, as data.table(x, y, width, text)
#' @return data.table(x, y, headway, upper_bound), one row per legend
tt_headway_legends <- function(p) {
  empty <- data.table::data.table(x = integer(0), y = integer(0),
                                  headway = integer(0),
                                  upper_bound = logical(0))
  if (!nrow(p)) return(empty)
  num <- p[grepl("^\\d{1,3}$", text)]
  mins <- p[grepl("^mins?\\.?$|^minutes$", text, ignore.case = TRUE)]
  if (!nrow(num) || !nrow(mins)) return(empty)

  out <- list()
  for (i in seq_len(nrow(num))) {
    same_row <- mins[abs(y - num$y[i]) <= 3 &
                       x >= num$x[i] & x - (num$x[i] + num$width[i]) <= 15]
    below <- mins[y > num$y[i] & y - num$y[i] <= 30 &
                    abs(x - num$x[i]) <= 20]
    if (!nrow(same_row) && !nrow(below)) next
    # "up to every 10 mins" is a ceiling, not a timetable; the qualifier sits
    # in the same column a row or two above the number.
    up <- p[grepl("^up$", text, ignore.case = TRUE) &
              abs(x - num$x[i]) <= 60 & abs(y - num$y[i]) <= 60]
    out[[length(out) + 1L]] <- data.table::data.table(
      x = num$x[i], y = num$y[i], headway = as.integer(num$text[i]),
      upper_bound = nrow(up) > 0)
  }
  if (!length(out)) return(empty)
  data.table::rbindlist(out)
}

#' The route number each table column belongs to
#'
#' Several documents print more than one route in a single table, with a
#' header row naming the route for each column: Glasgow's "Service No.: 1 1C
#' 1A 1C ..." and Fife's bare "91A 91A 90A 91A ...". Counting every column
#' would then attribute another route's journeys to this one, which is how
#' the Manchester 142 became unusable.
#'
#' A row is a header when at least two of its tokens are one of the route
#' codes the table carries and none of them is a departure time. The header
#' is reissued on every page, so it is tracked as the reader walks.
#'
#' @param tokens a row's word boxes
#' @param routes route codes appearing as column headings
#' @return data.table(x, route) or NULL if this row is not a header
tt_route_header <- function(tokens, routes) {
  if (is.null(routes) || !nrow(tokens)) return(NULL)
  if (any(grepl("^\\d{4}$", tokens$text))) return(NULL)
  hit <- toupper(tokens$text) %in% toupper(routes)
  if (sum(hit) < 2L) return(NULL)
  data.table::data.table(x = tokens$x[hit], route = tokens$text[hit])
}

#' Keep only the cells belonging to the routes being counted
#'
#' Each cell is assigned to the nearest column heading. `tol` guards against
#' assigning a cell to a heading it is nowhere near, which would happen if a
#' row were misread as a header.
tt_filter_routes <- function(cells, header, count_routes, tol = 25) {
  if (is.null(header) || is.null(count_routes) || !nrow(cells)) return(cells)
  near <- vapply(cells$x, function(xx) {
    d <- abs(header$x - xx)
    if (min(d) > tol) NA_character_ else header$route[which.min(d)]
  }, character(1))
  cells[!is.na(near) & toupper(near) %in% toupper(count_routes)]
}

#' Group PDF word boxes into table columns by x position
#'
#' @param x numeric vector of token x positions
#' @param tol maximum gap within a column, in points
tt_columns <- function(x, tol = 12) {
  o <- order(x)
  s <- x[o]
  grp <- cumsum(c(1L, diff(s) > tol))
  out <- integer(length(x))
  out[o] <- grp
  out
}

#' Read a column-layout passenger timetable
#'
#' Rows are stops, columns are journeys. Walks the document in reading order
#' tracking the current direction and day-type heading, and returns the
#' departures printed on the reference stop's row, with abbreviated blocks
#' expanded.
#'
#' Headings and direction titles are recognised as lines carrying the pattern
#' and no four-digit time, which keeps a stop called "Sunderland Road" from
#' being read as a Sunday heading.
#'
#' @param path PDF path
#' @param stop_regex regex matching the reference stop's row label
#' @param direction_patterns named regexes identifying the direction titles;
#'   the same stop is usually printed in both directions, so this is what
#'   separates them. NULL treats the document as one direction.
#' @param day_patterns named regexes identifying the day-type headings.
#'   Word order is not reliable: reading a PDF as positioned words rather than
#'   as laid-out text can reorder a phrase, and Lothian's "Mondays to Fridays"
#'   comes back as "Mondays Fridays to". The defaults therefore match the two
#'   day names with anything between them rather than the literal phrase.
#' @return list(times = data.table(direction, daytype, block, minutes,
#'   expanded, upper_bound), expanded = logical)
read_column_timetable <- function(path,
                                  stop_regex,
                                  direction_patterns = NULL,
                                  routes_in_table = NULL,
                                  count_routes = NULL,
                                  day_patterns = c(
                                    MF = "(?i)monday.*friday|friday.*monday",
                                    Sa = "(?i)saturday",
                                    Su = "(?i)sunday")) {
  pages <- pdftools::pdf_data(path, font_info = FALSE)

  # Which abbreviation dialect this publisher uses is a property of the
  # document, not of the page: the Stagecoach 1/1A prints the legend on
  # nine of its ten pages, and deciding page by page would leave the tenth
  # unable to tell a headway from a minute past the hour.
  #
  # Tested on tokens, because the words are stacked one per stop row inside
  # the table and so are never adjacent as text. Only the minute-pattern
  # dialect uses these pairs; the headway dialect says "and every 12 mins
  # until" and none of them.
  all_tok <- tolower(trimws(unlist(lapply(pages, function(p) p$text))))
  minute_dialect <- (any(all_tok == "past") && any(all_tok == "hour")) ||
    (any(all_tok == "these") && any(all_tok == "times")) ||
    # A document that never says "every" states no headway anywhere, so any
    # abbreviation in it must be a minute pattern. Cardiff's 62 abbreviates
    # with a bare "then at ... until" and a single cell reading "02", which
    # is a plausible minute past the hour and an absurd headway.
    !any(all_tok == "every")

  out <- list()
  expanded_any <- FALSE
  legend_seen <- FALSE
  ambiguous_any <- FALSE
  day <- NA_character_
  direction <- if (is.null(direction_patterns)) "all" else NA_character_
  block <- 0L
  header <- NULL

  for (pi in seq_along(pages)) {
    p <- data.table::as.data.table(pages[[pi]])
    if (!nrow(p)) next
    # Tokens carry the layout's tab padding ("and\t\t"), which defeats any
    # exact match on a legend word.
    p[, text := trimws(text)]
    p <- p[text != ""]
    if (!nrow(p)) next
    data.table::setorder(p, y, x)
    p[, row := cumsum(c(1L, diff(y) > 3L))]
    lines <- p[, list(txt = paste(text, collapse = " "),
                      ntime = sum(grepl("^\\d{4}$", text))), by = row]
    legends <- tt_headway_legends(p)
    hw <- tt_page_headway(lines$txt)
    if (!is.na(hw$headway) || nrow(legends)) legend_seen <- TRUE
    # Stagecoach and Fife spell out that their abbreviation is a repeating
    # minute pattern, so a single two-digit cell is not ambiguous there.

    for (r in lines$row) {
      tokens <- p[row == r]
      data.table::setorder(tokens, x)
      txt <- lines$txt[lines$row == r]

      # A heading carries no departure times. The test counts *tokens* that
      # are four digits rather than searching the joined line, so that a
      # heading like "Mondays to Fridays ... Commencing Date: 19/07/2026"
      # is not mistaken for data on the strength of the year.
      if (lines$ntime[lines$row == r] == 0L) {
        hdr <- tt_route_header(tokens, routes_in_table)
        if (!is.null(hdr)) header <- hdr
        if (!is.null(direction_patterns)) {
          hit <- names(direction_patterns)[
            vapply(direction_patterns, function(re) grepl(re, txt), logical(1))]
          if (length(hit)) direction <- hit[1]
        }
        hit <- names(day_patterns)[
          vapply(day_patterns, function(re) grepl(re, txt), logical(1))]
        if (length(hit)) {
          day <- hit[1]
          block <- block + 1L
        }
        next
      }

      if (!grepl(stop_regex, txt) || is.na(day) || is.na(direction)) next

      num <- tokens[grepl("^\\d{2}$|^\\d{4}$", text)]
      num <- tt_filter_routes(num, header, count_routes)
      if (!nrow(num)) next

      res <- tt_expand_row(num$text, num$x, num$x + num$width,
                           legends = legends, row_y = num$y[1],
                           headway = hw$headway,
                           minute_dialect = minute_dialect)
      if (isTRUE(res$expanded)) expanded_any <- TRUE
      if (isTRUE(res$ambiguous)) ambiguous_any <- TRUE
      if (length(res$minutes)) {
        out[[length(out) + 1L]] <- data.table::data.table(
          page = pi, direction = direction, daytype = day, block = block,
          minutes = res$minutes, expanded = res$expanded,
          upper_bound = res$upper_bound)
      }
    }
  }

  times <- if (length(out)) data.table::rbindlist(out) else
    data.table::data.table(page = integer(0), direction = character(0),
                           daytype = character(0), block = integer(0),
                           minutes = integer(0), expanded = logical(0),
                           upper_bound = logical(0))

  # A document that advertises a frequent-service period but from which
  # nothing was expanded has been misread: the abbreviation is there and its
  # journeys are missing. That is the failure mode to catch, because the
  # remaining explicit times still parse and the result looks plausible -
  # Lothian's route 100 reads as 20 departures a day when the airport service
  # alone runs every ten minutes all day.
  #
  # `ambiguous` catches the other way of getting it wrong: a lone two-digit
  # cell with no legend to say what it means. "15" could be a quarter-hourly
  # service or a single journey at a quarter past, and the two readings
  # differ by a factor of four.
  list(times = times, expanded = expanded_any,
       legend_seen = legend_seen, ambiguous = ambiguous_any,
       reliable = !(legend_seen && !expanded_any) && !ambiguous_any)
}

#' Drop timetable blocks the generator printed more than once
#'
#' The National PTI generator repeats whole day-type tables: the A1 and the 21
#' both print their Sunday tables twice, the second copy running on from the
#' first without an intervening heading, so it is not always a separate block.
#'
#' Two passes: drop any block whose departures duplicate an earlier block of
#' the same direction and day type, then, for what remains, halve any
#' (direction, day type) in which every departure appears exactly twice. The
#' second test is deliberately strict - a single shared minute between two
#' journeys would break it - because halving a genuinely doubled service would
#' be a serious error.
#'
#' @param times the `times` element of read_column_timetable()
#' @param min_distinct minimum distinct departures before halving is considered
tt_dedupe_repeated_blocks <- function(times, min_distinct = 8L) {
  if (!nrow(times)) return(times)

  key <- times[, list(sig = paste(sort(minutes), collapse = ",")),
               by = list(direction, daytype, block)]
  key[, dup := duplicated(paste(direction, daytype, sig))]
  keep <- key[dup == FALSE, list(direction, daytype, block)]
  times <- merge(times, keep, by = c("direction", "daytype", "block"))

  times[, {
    tab <- table(minutes)
    if (length(tab) >= min_distinct && all(tab == 2L)) {
      .SD[!duplicated(minutes)]
    } else .SD
  }, by = list(direction, daytype)]
}

#' Turn one printed stop row into departures, expanding abbreviated blocks
#'
#' A run of two-digit cells between two four-digit times is an abbreviated
#' block. Which dialect it is follows from its width:
#'
#'  * several cells - the minutes past each hour the service departs
#'    (Stagecoach: "then at these mins past each hour until"), repeating hourly
#'  * a single cell - the headway itself, the surrounding legend reading
#'    "and every 10 mins until" (Bee Network) or "up to every 10 mins until"
#'    (Lothian). `headway` carries the number found in that legend, which is
#'    the same value, and is used in preference.
#'
#' A third case has no cell at all. Where the legend occupies the column,
#' the reference stop's row holds a legend *word* rather than a number
#' ("and", "until"), so the abbreviated period shows up only as a horizontal
#' gap between two printed times. It is recovered by looking for a legend
#' whose column falls inside that gap.
#'
#' @param cells character vector of cell contents, left to right
#' @param x,xend their horizontal extent
#' @param legends tt_headway_legends() for the page
#' @param row_y this row's vertical position, used to keep a legend from
#'   being applied to a different day type's table further down the page
#' @param headway page-level fallback headway, or NA
#' @param minute_dialect TRUE where the page says its abbreviation is a
#'   minute pattern ("at these minutes past each hour"), which settles what a
#'   lone two-digit cell means
tt_expand_row <- function(cells, x, xend = NULL, legends = NULL,
                          row_y = NA_integer_, headway = NA_integer_,
                          minute_dialect = FALSE) {
  ord <- order(x)
  cells <- cells[ord]
  xs <- x[ord]
  xe <- if (is.null(xend)) xs else xend[ord]
  is_time <- grepl("^\\d{4}$", cells)
  is_min <- grepl("^\\d{2}$", cells)

  times <- rep(NA_integer_, length(cells))
  times[is_time] <- tt_minutes(cells[is_time])

  # The legend governing the column between xlo and xhi, if any.
  find_legend <- function(xlo, xhi) {
    if (is.null(legends) || !nrow(legends)) return(NULL)
    hit <- legends[x >= xlo - 2 & x <= xhi + 2]
    if (!is.na(row_y)) hit <- hit[abs(y - row_y) <= 60]
    if (!nrow(hit)) NULL else as.list(hit[1])
  }

  out <- integer(0)
  expanded <- FALSE
  ambiguous <- FALSE
  upper <- FALSE
  last_xe <- NA_integer_
  gap_done <- FALSE
  i <- 1L
  n <- length(cells)
  while (i <= n) {
    if (is_time[i]) {
      prev <- if (length(out)) out[length(out)] else NA_integer_
      if (!is.na(prev) && !is.na(last_xe) && !gap_done) {
        lg <- find_legend(last_xe, xs[i])
        if (!is.null(lg)) {
          blk <- expand_headway_block(prev, times[i], headway = lg$headway)
          if (length(blk)) {
            expanded <- TRUE
            upper <- upper || isTRUE(lg$upper_bound)
            out <- c(out, blk)
          }
        }
      }
      out <- c(out, times[i])
      last_xe <- xe[i]
      gap_done <- FALSE
      i <- i + 1L
      next
    }
    if (is_min[i]) {
      j <- i
      while (j <= n && is_min[j]) j <- j + 1L
      prev <- if (length(out)) out[length(out)] else NA_integer_
      # The block is closed by the next printed *time*, which need not be
      # the next cell: a legend word or an empty spacer column often sits
      # between them, and taking that cell would leave the block unbounded
      # and silently unexpanded.
      jj <- j
      while (jj <= n && !is_time[jj]) jj <- jj + 1L
      nxt <- if (jj <= n) times[jj] else NA_integer_
      run <- as.integer(cells[i:(j - 1L)])
      lg <- find_legend(xs[i], xe[j - 1L])
      hw <- if (!is.null(lg)) lg$headway else headway
      block <- if (length(run) == 1L && !is.na(hw)) {
        if (!is.null(lg)) upper <- upper || isTRUE(lg$upper_bound)
        expand_headway_block(prev, nxt, headway = hw)
      } else if (length(run) == 1L && !minute_dialect) {
        # One cell, and nothing on the page to say whether it is a headway
        # or a minute past the hour. Guessing wrong is a factor-of-several
        # error, so it is expanded as a minute pattern and flagged.
        ambiguous <- TRUE
        expand_headway_block(prev, nxt, minutes = run)
      } else {
        expand_headway_block(prev, nxt, minutes = run)
      }
      if (length(block)) expanded <- TRUE
      out <- c(out, block)
      last_xe <- xe[j - 1L]
      gap_done <- TRUE
      i <- j
      next
    }
    i <- i + 1L
  }
  list(minutes = sort(unique(out[!is.na(out)])), expanded = expanded,
       upper_bound = upper, ambiguous = ambiguous)
}

#' Headway stated in a page's frequent-service legend
#'
#' Matches "every 10 mins", "and every 10 minutes until", "up to every 10
#' mins until". Returns the interval and whether it was qualified by "up to",
#' which makes the expansion an upper bound rather than an exact count.
tt_page_headway <- function(txt) {
  flat <- gsub("\\s+", " ", paste(txt, collapse = " "))
  m <- regmatches(flat, regexpr("(up to )?every\\s+\\d+\\s*min", flat,
                                ignore.case = TRUE))
  if (!length(m)) return(list(headway = NA_integer_, upper_bound = FALSE))
  list(headway = as.integer(regmatches(m, regexpr("\\d+", m))),
       upper_bound = grepl("up to", m, ignore.case = TRUE))
}

#' Read a timetable supplied as a Word document
#'
#' Some operators publish only artwork: trentbarton's and Kinchbus's PDFs
#' carry no text layer at all, not even word boxes, so nothing short of OCR
#' will read them. A Word extract of the same timetable is far better than
#' the PDF ever was, because the table is already cells - no column
#' clustering, no baseline guessing.
#'
#' The layout still has to be reconstructed. Stop names and departure times
#' live in *separate, adjacent tables* aligned by row index, times are
#' twelve-hour with the am/pm in a header row, and the frequent-service
#' legend runs down a middle column exactly as it does in the PDFs.
#'
#' @param path .docx path
#' @param stop_regex regex matching the reference stop's name
#' Kinchbus publishes one "Monday to Saturday" table covering both day
#' types, distinguished by a note against each journey: `NS` runs Monday to
#' Friday only, `S` on Saturdays only, and an unmarked journey runs on both.
#' A table like that is split back into a Monday-Friday and a Saturday
#' reading rather than reported as one figure, since the feeds hold them as
#' separate services.
#'
#' @param path .docx path
#' @param stop_regex regex matching the reference stop's name
#' @param day_patterns as read_column_timetable(). `SuBh` must precede `Su`,
#'   since "Sunday & Bank Holiday Monday" matches both and the bank holiday
#'   is the point of it.
read_docx_timetable <- function(path, stop_regex,
                                day_patterns = c(
                                  SuBh = "(?i)sunday.*bank holiday",
                                  MSa = "(?i)monday.*saturday",
                                  MF = "(?i)monday.*friday|friday.*monday",
                                  Sa = "(?i)saturday",
                                  Su = "(?i)sunday")) {
  td <- tempfile()
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  utils::unzip(path, exdir = td)
  doc <- xml2::read_xml(file.path(td, "word", "document.xml"))
  ns <- xml2::xml_ns(doc)
  body <- xml2::xml_find_first(doc, ".//w:body", ns)
  kids <- xml2::xml_children(body)

  # Word pads cells with non-breaking spaces, which trimws() leaves in place
  # and which then defeat any anchored match on a stop name.
  clean <- function(x) trimws(gsub("[   ]", " ", x))
  tbl_rows <- function(tb) {
    lapply(xml2::xml_find_all(tb, "./w:tr", ns), function(r)
      clean(xml2::xml_text(xml2::xml_find_all(r, "./w:tc", ns))))
  }
  # Two times in a row is enough. The Sunday table is mostly abbreviation -
  # "8.45 | then | 45 | | 4.45" - so a stricter test classifies it as a
  # table of stop names and silently drops the whole day.
  is_times <- function(rows) {
    sum(vapply(rows, function(r) sum(grepl("^\\d{1,2}\\.\\d{2}$", r)) >= 2,
               logical(1))) >= 2
  }

  out <- list()
  expanded_any <- FALSE
  day <- NA_character_
  block <- 0L
  stops <- NULL

  for (k in kids) {
    nm <- xml2::xml_name(k)
    if (nm == "p") {
      txt <- trimws(xml2::xml_text(k))
      if (!nzchar(txt)) next
      # The key explaining the notes ("NS = Monday to Friday only, S =
      # Saturdays only") names day types without being a heading for one.
      if (grepl("=", txt, fixed = TRUE)) next
      hit <- names(day_patterns)[
        vapply(day_patterns, function(re) grepl(re, txt), logical(1))]
      if (length(hit)) {
        day <- hit[1]
        block <- block + 1L
      }
      next
    }
    if (nm != "tbl") next
    rows <- tbl_rows(k)
    if (!length(rows)) next
    if (!is_times(rows)) { stops <- rows; next }
    if (is.null(stops) || is.na(day)) next

    # am/pm and the journey notes are header rows; carry the meridiem
    # forward across the blank cells the legend column leaves behind.
    hdr <- Find(function(r) any(grepl("^(am|pm)$", r, ignore.case = TRUE)),
                rows)
    notes <- Find(function(r) any(nzchar(r)) &&
                    all(!grepl("^\\d{1,2}\\.\\d{2}$", r)) &&
                    any(grepl("^N?S$", r)), rows)
    mer <- if (is.null(hdr)) character(0) else tolower(hdr)
    if (length(mer)) {
      for (i in seq_along(mer)) {
        if (!mer[i] %in% c("am", "pm")) mer[i] <- if (i > 1) mer[i - 1] else ""
      }
    }

    # A Monday-to-Saturday table is read twice, once per day type, keeping
    # the journeys that run on that day.
    variants <- if (identical(day, "MSa")) {
      list(MF = "^S$", Sa = "^NS$")
    } else stats::setNames(list(NULL), day)

    for (i in seq_along(rows)) {
      nmst <- if (i <= length(stops)) stops[[i]] else character(0)
      nmst <- nmst[nzchar(nmst)]
      if (!length(nmst) || !grepl(stop_regex, nmst[1])) next
      cells <- rows[[i]]
      canon <- tt_docx_canonical(cells, mer)

      for (v in seq_along(variants)) {
        drop <- variants[[v]]
        keep <- rep(TRUE, length(canon))
        if (!is.null(drop) && !is.null(notes)) {
          n <- notes[seq_along(canon)]
          keep <- is.na(n) | !grepl(drop, n)
        }
        res <- tt_expand_row(canon[keep], seq_along(canon[keep]) * 10L,
                             minute_dialect = TRUE)
        if (isTRUE(res$expanded)) expanded_any <- TRUE
        if (length(res$minutes)) {
          out[[length(out) + 1L]] <- data.table::data.table(
            page = 1L, direction = "all", daytype = names(variants)[v],
            block = block * 10L + v,
            minutes = res$minutes, expanded = res$expanded,
            upper_bound = FALSE)
        }
      }
    }
  }

  times <- if (length(out)) data.table::rbindlist(out) else
    data.table::data.table(page = integer(0), direction = character(0),
                           daytype = character(0), block = integer(0),
                           minutes = integer(0), expanded = logical(0),
                           upper_bound = logical(0))
  list(times = times, expanded = expanded_any, legend_seen = TRUE,
       ambiguous = FALSE, reliable = TRUE)
}

#' Twelve-hour "6.05" plus a column's am/pm to the "HHMM" the reader expects
#'
#' Minute-pattern cells ("15", "45") are passed through untouched, since a
#' minute past the hour has no meridiem.
tt_docx_canonical <- function(cells, mer) {
  vapply(seq_along(cells), function(i) {
    x <- cells[i]
    if (grepl("^\\d{2}$", x)) return(x)
    if (!grepl("^\\d{1,2}\\.\\d{2}$", x)) return("")
    h <- as.integer(sub("\\..*$", "", x))
    m <- as.integer(sub("^.*\\.", "", x))
    pm <- length(mer) >= i && identical(mer[i], "pm")
    if (pm && h != 12L) h <- h + 12L
    if (!pm && h == 12L) h <- 0L
    sprintf("%02d%02d", h, m)
  }, character(1))
}

#' Read a TfL running schedule
#'
#' One row per vehicle journey; columns are timing points, named by transit
#' node code in the header. Returns the departures at `node`.
read_tfl_schedule <- function(path, node) {
  pages <- pdftools::pdf_data(path, font_info = FALSE)
  res <- lapply(seq_along(pages), function(i) tt_tfl_page(pages[[i]], i, node))
  res <- data.table::rbindlist(Filter(Negate(is.null), res))
  if (!nrow(res)) return(integer(0))
  # a journey can pass the node more than once; keep its first departure
  data.table::setorder(res, page, trip, minutes)
  res <- res[, list(minutes = minutes[1]), by = list(page, trip)]
  sort(res$minutes)
}

tt_tfl_page <- function(page, page_no, node) {
  p <- data.table::as.data.table(page)
  if (!nrow(p)) return(NULL)
  dep <- p[text == "Dep."]
  if (nrow(dep) < 5) return(NULL)
  dep <- dep[y == max(y)][order(x)]
  colx <- dep$x

  above <- p[y < min(dep$y) - 5]
  n_codes <- above[, list(n = sum(grepl("^[A-Z][A-Z0-9]{4}$", text))), by = y]
  cand <- n_codes[n >= length(colx) - 2]
  if (!nrow(cand)) return(NULL)
  nodes <- above[y == cand[which.max(y)]$y][order(x)]
  nearest <- function(xx) which.min(abs(colx - xx))
  colnodes <- rep(NA_character_, length(colx))
  colnodes[vapply(nodes$x, nearest, integer(1))] <- nodes$text

  want <- which(colnodes == node)
  if (!length(want)) return(NULL)

  rows <- p[y > max(dep$y)]
  data.table::rbindlist(lapply(sort(unique(rows$y)), function(yy) {
    r <- rows[y == yy][order(x)]
    if (!grepl("^\\d{1,4}$", r$text[1]) || r$x[1] > 110) return(NULL)
    tm <- r[grepl("^\\d{4}$", text) & x > 205]
    if (!nrow(tm)) return(NULL)
    ci <- vapply(tm$x, nearest, integer(1))
    keep <- ci %in% want
    if (!any(keep)) return(NULL)
    data.table::data.table(page = page_no, trip = as.integer(r$text[1]),
                           minutes = tt_minutes(tm$text[keep]))
  }))
}
