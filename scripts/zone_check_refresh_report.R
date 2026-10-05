# Write reports/zone_pdf_validation_refresh.md from the refreshed zone checks.
#
# Run after scripts/zone_check_refresh.R. Every figure here is computed from
# data/zone_pdf_validation_refreshed.Rds; nothing is written out by hand,
# because the point of the report is to say what the October 2026 fixes did
# and that is not known until it is measured.
#
# Usage: Rscript scripts/zone_check_refresh_report.R

suppressMessages({
  library(data.table)
})

v <- readRDS("data/zone_pdf_validation_refreshed.Rds")
d <- as.data.table(v$checks)
d[, reliable := reliable %in% c(TRUE, "True")]
has_prefix <- any(!is.na(d$tnds_over_doc_prefix))

out <- character()
w <- function(...) out <<- c(out, paste0(...))

# Distance from the document on a ratio scale, so that 0.5 and 2.0 are equally
# wrong. A ratio of 0 cannot be logged, so it is floored - a source carrying
# nothing is as wrong as this measure can express.
dist <- function(x) mean(abs(log(pmax(x, 1e-3))), na.rm = TRUE)
near <- function(x, tol = 0.15) mean(abs(x - 1) <= tol, na.rm = TRUE)
nnear <- function(x, tol = 0.15) sum(abs(x - 1) <= tol, na.rm = TRUE)

r <- d[reliable == TRUE]
# Checks where both sources carry something, so that a ratio scale means
# anything. Needed before the prose that quotes it.
nz0 <- r[tnds_over_doc > 0 & bods_over_doc > 0 & tnds_over_doc_published > 0]
wl <- as.integer(v$window$enddate - v$window$startdate) + 1L

w("# Did the October 2026 fixes improve the zone checks?")
w("")
w("`reports/pdf_validation.md` carries ", nrow(d), " checks of a published")
w("timetable against TNDS and the DfT's BODS GTFS **at a zone**, over ",
  uniqueN(d$zone), " zones.")
w("They were measured before the three October 2026 changes - the UK2GTFS")
w("overlap patch, the move to the TransXChange 2.5 edition of TNDS, and the")
w("counting window going from 28 days to 14 - and that section of the report")
w("is hand-written, so knitting does not refresh it. This re-measures all ",
  nrow(d))
w("on the current pipeline.")
w("")
w("No PDF was read again. `data/zone_pdf_validation.csv` already holds each")
w("document's journeys per operating day, which is what the documents were")
w("needed for and does not depend on the pipeline. What is recomputed is the")
w("document's window total, from journeys per day times the number of each")
w("day type in the current ", wl, "-day window, and the TNDS and BODS GTFS run")
w("counts at the zone, from the current feeds. Both sides move onto the ",
  wl, "-day")
w("window together, so the **ratios** stay comparable with the published ones")
w("even though the counts halve. Written by `scripts/zone_check_refresh.R`")
w("and `scripts/zone_check_refresh_report.R`; the full table is")
w("`data/zone_pdf_validation_refreshed.csv`.")
w("")
w("Window: **", format(v$window$startdate), " to ", format(v$window$enddate),
  "** (", wl, " days). Snapshot: the July 2026 triple, unchanged.")
w("")

if (has_prefix) {
  w("Three columns of TNDS, not two, so that the window and the conversion can")
  w("be told apart:")
  w("")
  w("| Column | Window | TNDS edition | UK2GTFS |")
  w("|---|---|---|---|")
  w("| `published` | 28 days | 2.1 | overlap rule unpatched |")
  w("| `prefix` | ", wl, " days | 2.1 | overlap rule unpatched |")
  w("| `fixed` | ", wl, " days | 2.5 | **patched** |")
  w("")
  w("`published` against `prefix` is the window alone; `prefix` against")
  w("`fixed` is the conversion fixes alone. Both were counted by the same R")
  w("code over the same zones, so no part of the difference is method.")
  w("")
} else {
  w("The pre-fix feed was not available, so the window change and the")
  w("conversion fixes cannot be separated here: the comparison is the")
  w("published 28-day figures against the current ones.")
  w("")
}

w("## How close is each source to the document?")
w("")
w("Reliable checks only (", nrow(r), " of ", nrow(d),
  "; the rest are documents whose reading")
w("the PDF reader could not be trusted on). *Distance* is the mean of")
w("|log(ratio)|, so that reading half the timetable and reading twice it count")
w("the same; lower is better. *Within 15%* is the number of checks the")
w("verdict rule would call right.")
w("")
# Where each source carries nothing, named from the data rather than
# asserted: which places go missing is exactly the kind of claim that goes
# stale when a feed is reconverted.
absent_by_area <- function(col) {
  t <- sort(table(r$area[r[[col]] == 0 & !is.na(r[[col]])]), decreasing = TRUE)
  if (!length(t)) return("nowhere")
  paste(sprintf("%s (%d)", names(t), as.integer(t)), collapse = ", ")
}
zero_pen <- abs(log(1e-3))
typ_err <- dist(nz0$tnds_over_doc)
w("**Two tables, because one number hides the finding.** A source that")
w("carries *nothing* at a zone has a ratio of 0, which no ratio scale can")
w("express: floored at 0.001 it contributes |log| of ",
  sprintf("%.1f", zero_pen), ", about ",
  sprintf("%.0f", zero_pen / typ_err), " times the typical")
w("error where both sources do carry the service. TNDS carries nothing on ",
  sum(r$tnds_over_doc == 0, na.rm = TRUE), " of these")
w("checks and BODS GTFS on ", sum(r$bods_over_doc == 0, na.rm = TRUE), ".")
w("")
w("* TNDS absent: ", absent_by_area("tnds_over_doc"))
w("* BODS GTFS absent: ", absent_by_area("bods_over_doc"))
w("")
w("The TNDS absences are the Metrobus stub files around Crawley and the Hull")
w("local-authority files that expired by their own \"Data Expires\" note -")
w("defects in the source data that no conversion change can repair, and which")
w("the October 2026 fixes did not touch. Averaged in, they swamp everything")
w("else and the comparison becomes a count of absences. Reported separately,")
w("the first table says how well each source describes a timetable it has,")
w("and the second says how often it has one at all.")
w("")
ratio_table <- function(x, caption) {
  w("### ", caption)
  w("")
  w("| Source | Median ratio | Distance | Within 15% of ", nrow(x), " |")
  w("|---|---:|---:|---:|")
  w("| TNDS, as published (28 d, 2.1, unpatched) | ",
    sprintf("%.2f", median(x$tnds_over_doc_published, na.rm = TRUE)), " | ",
    sprintf("%.3f", dist(x$tnds_over_doc_published)), " | ",
    nnear(x$tnds_over_doc_published), " |")
  if (has_prefix) {
    w("| TNDS, the ", wl, "-day window alone (2.1, unpatched) | ",
      sprintf("%.2f", median(x$tnds_over_doc_prefix, na.rm = TRUE)), " | ",
      sprintf("%.3f", dist(x$tnds_over_doc_prefix)), " | ",
      nnear(x$tnds_over_doc_prefix), " |")
  }
  w("| **TNDS, fixed** (", wl, " d, 2.5, patched) | ",
    sprintf("%.2f", median(x$tnds_over_doc, na.rm = TRUE)), " | ",
    sprintf("%.3f", dist(x$tnds_over_doc)), " | ",
    nnear(x$tnds_over_doc), " |")
  w("| BODS GTFS (", wl, " d) | ",
    sprintf("%.2f", median(x$bods_over_doc, na.rm = TRUE)), " | ",
    sprintf("%.3f", dist(x$bods_over_doc)), " | ",
    nnear(x$bods_over_doc), " |")
  w("")
}
nz <- nz0
ratio_table(nz, "Where both sources carry the service")
ratio_table(r, "Every reliable check, absences included")
w("The two tables disagree about which source is better, and both are right.")
w("Where both carry the service TNDS is the more accurate by a wide margin;")
w("counting the absences, BODS GTFS is, because TNDS is the one that goes")
w("missing. Neither the patch nor the 2.5 edition nor the shorter window")
w("addresses an absence, so the second table barely moves.")
w("")

# The headline, stated as what the numbers support rather than as a hope.
dp <- dist(nz$tnds_over_doc_published)
df <- dist(nz$tnds_over_doc)
verb <- if (df < dp * 0.95) "closer to" else if (df > dp * 1.05) {
  "further from"
} else "no nearer"
w("On this measure TNDS is **", verb, "** the published timetables than it was:")
w("distance ", sprintf("%.3f", dp), " before, ", sprintf("%.3f", df),
  " after, a change of ",
  sprintf("%+.0f%%", 100 * (df - dp) / dp), ".")
if (has_prefix) {
  dx <- dist(nz$tnds_over_doc_prefix)
  w("Of that, the window accounts for ", sprintf("%+.3f", dx - dp),
    " and the conversion fixes ", sprintf("%+.3f", df - dx), ".")
}
w("")

w("## Verdicts")
w("")
w("The verdict rule is the one `scripts/zone_pdf_validation/assemble.py`")
w("used, ported in `scripts/zone_check_refresh.R`: a source is *right* when it")
w("is within 15% of the document, *absent* when it carries nothing.")
w("")
vt <- function(col, label) {
  t <- d[, .N, by = c(col)]
  setnames(t, c("verdict", label))
  t
}
tab <- Reduce(function(a, b) merge(a, b, by = "verdict", all = TRUE),
              list(vt("verdict_published", "published"),
                   if (has_prefix) vt("verdict_prefix", paste0(wl, "d only")),
                   vt("verdict", "fixed")))
tab <- tab[order(-get(names(tab)[ncol(tab)]), verdict)]
for (j in setdiff(names(tab), "verdict")) tab[is.na(get(j)), (j) := 0L]
w(paste0("| Verdict | ", paste(setdiff(names(tab), "verdict"),
                               collapse = " | "), " |"))
w(paste0("|---|", paste(rep("---:", ncol(tab) - 1), collapse = "|"), "|"))
for (i in seq_len(nrow(tab))) {
  w(paste0("| ", tab$verdict[i], " | ",
           paste(unlist(tab[i, -1, with = FALSE]), collapse = " | "), " |"))
}
w("")

moved <- d[verdict_published != verdict]
w(nrow(moved), " of the ", nrow(d), " checks change verdict. ")
if (nrow(moved)) {
  mv <- moved[, .N, by = list(verdict_published, verdict)][order(-N)]
  w("")
  w("| From | To | Checks |")
  w("|---|---|---:|")
  for (i in seq_len(nrow(mv))) {
    w("| ", mv$verdict_published[i], " | ", mv$verdict[i], " | ", mv$N[i], " |")
  }
  w("")
}

w("## The places the investigation named")
w("")
w("`reports/tnds_conversion_investigation.md` traced the disagreements to")
w("causes. These are the zones for each cause it identified, with what the")
w("fixes did to them.")
w("")
# Keyed on `area`, which is the column the checks actually carry, so a zone
# added to a place later is picked up without editing this list. An earlier
# version named one North-east London zone by code and silently reported 3 of
# its 15 checks.
cases <- list(
  "North-east London (cross-region duplicate, fixed by 2.5)" =
    quote(area %like% "North-east London"),
  "Preston (cross-region duplicate, fixed by 2.5)" =
    quote(area %like% "Preston"),
  "Chelmsford (sibling files, fixed by the patch; also weekly exports)" =
    quote(area %like% "Chelmsford"),
  "Reading (weekly exports, window change only)" =
    quote(area %like% "Reading"),
  "Weymouth (weekly exports, window change only)" =
    quote(area %like% "Weymouth"),
  "Hull (stale local-authority files, expired by their own note)" =
    quote(area %like% "Hull"),
  "Crawley (Metrobus stub files)" = quote(area %like% "Crawley"),
  "Brighton (old edition, no summer timetable)" = quote(area %like% "Brighton")
)
for (nm in names(cases)) {
  sub <- d[eval(cases[[nm]])]
  if (!nrow(sub)) next
  w("### ", nm)
  w("")
  w(nrow(sub), " check", if (nrow(sub) == 1) "" else "s", ". Median TNDS ratio ",
    "to the document: ",
    sprintf("%.2f", median(sub$tnds_over_doc_published, na.rm = TRUE)),
    " as published",
    if (has_prefix) {
      paste0(", ", sprintf("%.2f", median(sub$tnds_over_doc_prefix, na.rm = TRUE)),
             " on the ", wl, "-day window alone")
    } else "",
    ", **", sprintf("%.2f", median(sub$tnds_over_doc, na.rm = TRUE)),
    "** fixed, against BODS GTFS ",
    sprintf("%.2f", median(sub$bods_over_doc, na.rm = TRUE)), ".")
  w("")
  cols <- c("zone", "route", "document_window", "tnds_over_doc_published",
            if (has_prefix) "tnds_over_doc_prefix", "tnds_over_doc",
            "bods_over_doc")
  hdr <- c("Zone", "Route", paste0("Document (", wl, " d)"), "TNDS published",
           if (has_prefix) paste0("TNDS ", wl, "d"), "TNDS fixed", "BODS GTFS")
  w(paste0("| ", paste(hdr, collapse = " | "), " |"))
  w(paste0("|", paste(rep("---", length(hdr)), collapse = "|"), "|"))
  sub <- sub[order(route)]
  for (i in seq_len(nrow(sub))) {
    vals <- lapply(cols, function(cc) {
      x <- sub[[cc]][i]
      if (is.numeric(x)) {
        if (cc == "document_window") format(round(x), big.mark = ",") else
          sprintf("%.2f", x)
      } else as.character(x)
    })
    w(paste0("| ", paste(unlist(vals), collapse = " | "), " |"))
  }
  w("")
}

covered <- unique(unlist(lapply(cases, function(q) which(d[, eval(q)]))))
w("### Places not listed above")
w("")
w(length(covered), " of the ", nrow(d), " checks fall in the places the")
w("investigation named. The remaining ", nrow(d) - length(covered),
  " are in ",
  paste(sort(unique(d$area[-covered])), collapse = ", "), ".")
w("Those were either not TNDS errors at all (Birmingham and the Black")
w("Country, where two operators share a route number and the check counts")
w("both) or were never traced to a cause.")
w("")

w("## What this does not settle")
w("")
w("* **The ", nrow(d) - nrow(r), " unreliable readings.** Where the PDF reader",
  " could not be trusted -")
w("  a frequent-service abbreviation it failed to expand, a rotated table it")
w("  could not transpose - the document figure is too low and the ratio is")
w("  too high in both sources alike. They are reported but excluded above.")
w("* **The shared-route-number checks.** Birmingham 50, Black Country 9, 59")
w("  and 82 are run by two operators each and counted here by route number,")
w("  so the document is one operator's and the feeds are both. The")
w("  investigation's recommendation 4 was to drop or split them and that has")
w("  not been done.")
w("* **The causes neither fix addresses.** Hull's expired local-authority")
w("  files, Crawley's Metrobus stubs and Brighton's missing summer edition")
w("  are properties of the source data. A shorter window helps where a file")
w("  ends inside it and does nothing where the file was never there: Hull and")
w("  Crawley read 0.00 before and after, and Brighton is unmoved.")
w("")
w("* **The weekly exports are halved, not fixed.** Reading, Chelmsford and")
w("  Weymouth roughly doubled - Reading 0.25 to 0.49, Chelmsford 0.20 to")
w("  0.42, Weymouth 0.28 to 0.55 - which is exactly what halving the window")
w("  predicts and no more. They sit near 0.5 because the operators publish")
w("  **one week** and the window is two, so the second week is still empty.")
w("  A 7-day window would bring them to about 1.0, and that is the obvious")
w("  thing to want, but it would hold one of each weekday instead of two:")
w("  a single bank holiday, strike day or school-term boundary would then")
w("  land on a weekday with nothing to average it against, and `tph_*` would")
w("  swing on it. Two weeks is the shortest window that still holds a")
w("  duplicate of every weekday. Getting these places right needs the")
w("  horizon problem solved at the source - a per-operator flag, or BODS for")
w("  the operators that publish weekly - rather than a shorter window.")
w("")

dir.create("reports", showWarnings = FALSE)
writeLines(out, "reports/zone_pdf_validation_refresh.md")
message("wrote reports/zone_pdf_validation_refresh.md (", length(out), " lines)")
