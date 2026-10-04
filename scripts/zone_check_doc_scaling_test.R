# Does the R port of the document scaling agree with the Python it replaces?
#
# scripts/zone_check_refresh.R has to scale each published timetable's
# journeys per operating day up to the counting window, and it has to do it
# the same way scripts/zone_pdf_validation/compute.py did, or the refreshed
# ratios are not comparable with the published ones and the whole comparison
# is meaningless.
#
# The test is exact and needs nothing but the committed CSV: given that
# section's own 28-day window, the port must reproduce all 201 of its
# `document_window` values to the unit. It is worth having because the obvious
# implementation - sum journeys times day count over every day type present -
# passes on 200 of the 201 and fails on Reading's route 500, whose document
# yields both an "MF" and an "MS" label for the same weekday service.
#
# Usage: Rscript scripts/zone_check_doc_scaling_test.R

suppressMessages(library(data.table))

# Take doc_window() and day_counts() from the script itself rather than
# copying them, so this cannot pass against a stale copy. zone_check_refresh.R
# runs its analysis at top level, so it is parsed and only the two function
# definitions are evaluated.
exprs <- parse("scripts/zone_check_refresh.R")
env <- new.env(parent = globalenv())
for (e in exprs) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) &&
      is.name(e[[2]]) && as.character(e[[2]]) %in%
        c("doc_window", "day_counts")) {
    eval(e, envir = env)
  }
}
stopifnot(is.function(env$doc_window), is.function(env$day_counts))

old <- as.data.table(read.csv("data/zone_pdf_validation.csv",
                              stringsAsFactors = FALSE))

# The window the published section was measured over: 28 days from Monday
# 27 July 2026.
win28 <- list(startdate = as.Date("2026-07-27"),
              enddate = as.Date("2026-08-23"))
dc28 <- env$day_counts(win28)
cat("28-day counts:", paste(names(dc28), dc28, sep = "=", collapse = " "), "\n")

old[, mine := env$doc_window(document_journeys_per_day, dc28)]
old[, theirs := as.numeric(document_window)]
bad <- old[is.na(mine) != is.na(theirs) | abs(mine - theirs) > 0.5]

cat("checks:", nrow(old), " reproduced:", nrow(old) - nrow(bad), "\n")
if (nrow(bad)) {
  cat("\nFAIL - these do not match compute.py:\n")
  print(bad[, list(zone, route, document_journeys_per_day, theirs, mine)],
        nrows = 40)
  quit(status = 1)
}
cat("PASS: every published document_window reproduced exactly\n")

# And the property the refresh relies on: halving the window must not change
# the ratios by anything other than the day counts, so each document's total
# should fall to between a half and two thirds. (Not exactly a half: a 28-day
# window has four of each weekday and a 14-day window two, so the weekday and
# weekend parts scale together - but MT/Fr documents mix 16:4 against 8:2,
# which is the same ratio, while an MS document picks up Saturday twice over
# in neither. The band is the check that nothing is scaling oddly.)
win14 <- list(startdate = as.Date("2026-07-27"),
              enddate = as.Date("2026-08-09"))
old[, new14 := env$doc_window(document_journeys_per_day,
                              env$day_counts(win14))]
r <- old$new14 / old$theirs
cat(sprintf("14-day/28-day document totals: min %.4f, max %.4f, median %.4f\n",
            min(r, na.rm = TRUE), max(r, na.rm = TRUE),
            median(r, na.rm = TRUE)))
if (min(r, na.rm = TRUE) < 0.49 || max(r, na.rm = TRUE) > 0.68) {
  cat("FAIL: a document total scaled outside the expected band\n")
  quit(status = 1)
}
cat("PASS: all document totals scale into the expected band\n")
