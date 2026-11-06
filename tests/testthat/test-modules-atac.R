## ATAC module set tests. make_atac_fixture() (inst/examples/) builds
## the REAL ATAC_V3 output layout: QC/, Map/ and ATAC/{Quality,IPEval,
## Peaks,DiffPeaks,Similarity,Network}. Stage gating is asserted per
## directory presence.

test_that("atac_report_modules gates on ATAC stage directories", {
  tmp <- make_atac_fixture()
  ctx <- report_context(tmp, species = "Drosophila", type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), atac_report_modules()))
  res <- render_report(report, output = tempfile(fileext = ".html"),
    theme = reporter_theme(preset = "blank", style = "v2"),
    title = "ATAC demo", quiet = TRUE)
  expect_true(all(c("mod-overview", "mod-qc", "mod-mapping",
    "mod-peak", "mod-motif", "mod-signal",
    "mod-references") %in% res$modules))
  expect_false("mod-atacqc" %in% res$modules)    # ATAC/IPEval absent
  expect_false("mod-network" %in% res$modules)   # ATAC/Network absent
  expect_false("mod-quality" %in% res$modules)   # ATAC/Quality absent
  expect_length(res$errors, 0L)
})

test_that("atac qc module builds KPIs from ATAC QC summaries", {
  tmp <- make_atac_fixture()
  ctx <- report_context(tmp, type = "1")
  m <- mod_atac_qc()
  ctx$.rp_set_module("mod-atac-qc")
  out <- m$render(ctx)
  html <- paste(as.character(as.list(out)), collapse = "\n")
  expect_match(html, "rp-kpi-row", fixed = TRUE)
  expect_match(html, "rp-details", fixed = TRUE)  # auto table explanation
})

test_that("atac mapping module renders stats and png gallery", {
  tmp <- make_atac_fixture()
  ctx <- report_context(tmp, type = "1")
  m <- mod_atac_mapping()
  ctx$.rp_set_module("mod-atac-mapping")
  out <- m$render(ctx)
  html <- paste(as.character(as.list(out)), collapse = "\n")
  expect_match(html, "mapping.stats.txt", fixed = TRUE)
  ## gallery degrades to a plain figure when the dir holds a single png
  expect_true(grepl("rp-gallery", html, fixed = TRUE) ||
              grepl("rp-fig-img", html, fixed = TRUE))
})
