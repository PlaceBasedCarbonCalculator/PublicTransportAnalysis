# Render reports/route_subset_audit.Rmd to .md (run from the repo root)
rmarkdown::render("reports/route_subset_audit.Rmd", output_file = "route_subset_audit.md",
                  output_dir = "reports", knit_root_dir = normalizePath("reports"), quiet = TRUE)
cat("reports/route_subset_audit.md\n")
