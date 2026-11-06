test_that("load_explanations builds a flat registry with ambiguity tracking", {
  reg <- load_explanations()
  expect_gt(length(reg), 0L)
  expect_true("SampleName" %in% names(reg))
  expect_s3_class(reg$SampleName, "data.frame")
  expect_true(all(c("sheet", "explanation") %in% names(reg$SampleName)))
})

test_that("explain_table resolves unambiguous columns and pins sheets", {
  reg <- load_explanations()
  dt <- data.frame(SampleName = "s1", RawReads = 100)
  auto <- explain_table(names(dt), reg)
  if (!is.null(auto)) {
    expect_true(all(c("表格列名", "解释") %in% names(auto)))
  }
  ## sheet pinning resolves even ambiguous columns
  pinned <- explain_table(c("SampleName", "TotalReads"), reg, sheet = "QC")
  expect_s3_class(pinned, "data.frame")
  expect_setequal(pinned[["表格列名"]], c("SampleName", "TotalReads"))
  ## unknown columns -> NULL
  expect_null(explain_table(c("NoSuchCol"), reg))
})

test_that("ctx$data_table auto-attaches the explanation details block", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  qc_dir <- file.path(tmp, "1.QC")
  raw <- read_result_table(file.path(qc_dir, "Raw.Reads.txt"), sep = "\t")
  ctx$.rp_set_module("mod-qc")
  out <- ctx$data_table(raw, title = "QC stats", explain_sheet = "QC")
  html <- paste(as.character(as.list(out)), collapse = "\n")
  expect_match(html, "rp-details", fixed = TRUE)
  expect_match(html, "表格解释", fixed = TRUE)
  ## opt-out works
  out2 <- ctx$data_table(raw, title = "QC stats", explain = FALSE)
  html2 <- paste(as.character(as.list(out2)), collapse = "\n")
  expect_false(grepl("rp-details", html2, fixed = TRUE))
})

test_that("read_bib parses the bundled reference library", {
  bib <- read_bib(system.file("extdata", "references.bib",
    package = "reporter"))
  expect_s3_class(bib, "data.frame")
  expect_gt(nrow(bib), 10L)
  expect_true(all(c("key", "author", "title", "journal") %in% names(bib)))
  expect_true(any(!is.na(bib$year)))
})

test_that("reference_list renders numbered entries with doi links", {
  bib <- data.frame(
    key = "k1", type = "article",
    author = " Bartel, D. P.  and  Others, A. ", title = "Metazoan {MicroRNAs}",
    journal = "Cell", year = "2018", volume = "173", number = "1",
    pages = "20", doi = "10.1016/j.cell.2018.01.001", url = NA_character_,
    stringsAsFactors = FALSE)
  html <- as.character(reference_list(bib))
  expect_match(html, "rp-refs", fixed = TRUE)
  expect_match(html, "Bartel, D. P., Others, A.", fixed = TRUE)
  expect_match(html, "Metazoan MicroRNAs", fixed = TRUE)
  expect_match(html, "doi.org/10.1016", fixed = TRUE)
})

test_that("mod_references auto-loads the bundled bib and gates on file", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  m <- mod_references()
  ctx$.rp_set_module("mod-references")
  out <- m$render(ctx)
  html <- paste(as.character(as.list(out)), collapse = "\n")
  expect_match(html, "rp-refs", fixed = TRUE)
  expect_gt(length(gregexpr("rp-ref\\b", html)[[1]]), 5L)

  ## per-project bib overrides the bundled one
  writeLines(c(
    "@article{proj1,",
    "  title={Project specific reference},",
    "  author={Doe, J.},",
    "  journal={Journal of Demo},",
    "  year={2026},",
    "}"
  ), file.path(tmp, "references.bib"))
  out2 <- m$render(ctx)
  html2 <- paste(as.character(as.list(out2)), collapse = "\n")
  expect_match(html2, "Project specific reference", fixed = TRUE)
})
