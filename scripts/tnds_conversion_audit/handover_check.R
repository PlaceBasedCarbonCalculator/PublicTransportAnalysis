# What the operator-handover rule in txc_overlap_plan() does to a set of files.
#
# Runs txc_filter_files() from a UK2GTFS source tree over every file under a
# directory (handover_candidates.py), capturing the metadata its rule 4 sees,
# and plans rule 4 twice: as written, and with the stop lists removed, which
# switches the handover pass off. Files whose period differs between the two
# are the handover rule's doing; each is listed with the other operator's file
# that starts the day after it is closed.
#
# usage: Rscript handover_check.R <UK2GTFS source> <dir> <out csv> [date]
args <- commandArgs(trailingOnly = TRUE)
options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
suppressMessages(devtools::load_all(args[1], quiet = TRUE))
date <- as.Date(if (length(args) > 3) args[4] else Sys.Date())
files <- list.files(args[2], pattern = "[.]xml$", recursive = TRUE, full.names = TRUE)
ns <- asNamespace("UK2GTFS")
orig <- get("txc_overlap_plan", ns)
captured <- new.env()
wrap <- function(meta) {
  captured$meta <- meta
  orig(meta)
}
unlockBinding("txc_overlap_plan", ns)
assign("txc_overlap_plan", wrap, ns)
invisible(txc_filter_files(files, date = date, ncores = 10, out_dir = tempfile()))
meta <- captured$meta
with_rule <- orig(meta)
m2 <- meta; m2$Stops <- NULL
without <- orig(m2)
d <- which(with_rule$new_end != without$new_end | with_rule$drop != without$drop)
out <- data.frame(file = basename(meta$file[d]), noc = meta$NOC[d], lines = meta$Lines[d],
                  start = meta$StartDate[d], end = meta$EndDate[d],
                  new_end = with_rule$new_end[d], dropped = with_rule$drop[d])
hp <- attr(with_rule, "handover_pairs")
out$taken_over_by <- vapply(d, function(i) {
  k <- match(hp$by[hp$closed == meta$file[i]], meta$file)
  paste(paste0(meta$NOC[k], ":", basename(meta$file[k])), collapse = " ; ")
}, "")
write.csv(out, args[3], row.names = FALSE)
cat("files", length(files), "handover closures", nrow(out), "\n")
print(table(paste(out$noc, "->", sub(":.*", "", out$taken_over_by))))
