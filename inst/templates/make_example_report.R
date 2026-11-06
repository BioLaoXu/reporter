#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Regenerate the example reports under examples/ from a synthetic result
# tree. Useful as a visual reference and for smoke-testing the package
# after changes:
#
#   Rscript inst/templates/make_example_report.R
# ---------------------------------------------------------------------------

local({
  rp_lib <- Sys.getenv("REPORTER_LIBRARY",
    "/data/InHousePackages/reporter/library")
  if (dir.exists(rp_lib) && !rp_lib %in% .libPaths()) {
    .libPaths(c(rp_lib, .libPaths()))
  }
})

pkg_root <- local({
  ## resolve the package root from this script's location
  s <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  f <- if (length(s)) sub("^--file=", "", s[[1L]]) else "inst/templates/make_example_report.R"
  normalizePath(file.path(dirname(f), "..", ".."))
})

library(reporter)

## demo data generator lives with the example assets (inst/examples/)
source(system.file("examples", "make_chip_fixture.R", package = "reporter"))

out_dir <- file.path(pkg_root, "examples")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## NOTE: each report gets a FRESH context — figure/table counters live in
## the ctx, so reusing one ctx across renders would keep incrementing
## numbering across files.
fx <- make_chip_fixture(diff = TRUE)
new_ctx <- function(type = "1", project = "ChIP-seq Demo (2 groups)",
                    code = "DEMO-2026-001") {
  report_context(fx, species = "Homo_sapiens", project = project,
                 code = code, type = type)
}
build <- function(ctx) {
  do.call(add_module, c(list(report = create_report(ctx)),
                        chip_report_modules()))
}

## 1) white-label, diff group (type = 1), classic skin
render_report(build(new_ctx()), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_blank.html"),
  theme = reporter_theme(preset = "blank", primary = "#0D6E8C"),
  title = "ChIP-seq Analysis Report")

## 1b) v2 editorial skin (flat, print-inspired) — same content
render_report(build(new_ctx()), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_v2.html"),
  theme = reporter_theme(preset = "blank", primary = "#0D6E8C",
                         style = "v2"),
  title = "ChIP-seq Analysis Report")

## 1c) card skin (Illumina-DRAGEN inspired) — same content
render_report(build(new_ctx()), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_card.html"),
  theme = reporter_theme(preset = "blank", primary = "#0D6E8C",
                         style = "card"),
  title = "ChIP-seq Analysis Report")

## 1d) sci editorial skin (报告优化.md v2.0 design contract)
render_report(build(new_ctx()), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_sci.html"),
  theme = reporter_theme(preset = "blank", style = "sci"),
  title = "ChIP-seq Analysis Report")

## 1e) sci_v1 standalone template (extracted from sp20260727007.html)
render_report(build(new_ctx()),
  output = file.path(out_dir, "chip_demo_sci_v1.html"),
  theme = reporter_theme(preset = "blank", style = "sci_v1"),
  title = "ChIP-seq Analysis Report", print_html = TRUE)

## 2) smzy brand skin
render_report(build(new_ctx()), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_smzy.html"),
  theme = reporter_theme(preset = "smzy"),
  title = "ChIP-seq 分析报告")

## 3) single group (type = 0) — diff modules auto-skipped
render_report(build(new_ctx(type = "0", project = "ChIP-seq Demo (one group)",
                            code = "DEMO-2026-002")), print_html = TRUE,
  output = file.path(out_dir, "chip_demo_onegroup.html"),
  theme = reporter_theme(preset = "blank", primary = "#2B6CB0"),
  title = "ChIP-seq Analysis Report")

cat("Examples written to:", out_dir, "\n")
