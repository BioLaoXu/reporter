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
  ## header tooltips are static HTML under the lite engine
  ctx$meta$engine <- "lite"
  out2 <- ctx$data_table(read_result_table(
    file.path(ctx$meta$result_path, "QC", "Summary", "Filtered.Summary.txt"),
    sep = "\t"), title = "QC", explain_sheet = "QC")
  h2 <- paste(as.character(as.list(out2)), collapse = "\n")
  expect_match(h2, 'title="', fixed = TRUE)
  expect_false(grepl("rp-col-help", h2, fixed = TRUE))
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
