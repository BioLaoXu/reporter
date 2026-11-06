## spec compiler: yaml -> modules, citation superscripts, empty guards

test_that("render_spec builds qc layer with citations from yaml", {
  res <- render_spec(system.file("examples", "atac_qc_spec.yaml",
    package = "reporter"),
    result_path = "/data/Report/atac_project_2024/test0706_drosophila",
    output = tempfile(fileext = ".html"), quiet = TRUE)
  expect_true(all(c("mod-qc", "mod-references") %in% res$modules))
  expect_length(res$errors, 0L)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, "rp-cite", fixed = TRUE)          # citation sups
  expect_match(html, "测序序列统计与质控", fixed = TRUE)  # layer title
  expect_match(html, "rp-steps", fixed = TRUE)          # numbered steps
  expect_false(grepl("\\[@fastp\\]", html))             # markers replaced
})

test_that("citations resolve known keys and flag unknown", {
  km <- c(fastp = 1L, hisat2 = 2L)
  out <- citations("基于fastp[@fastp]与 [@hisat2；@nope] 处理", km)
  expect_match(out, "href=\"#ref-1\"", fixed = TRUE)
  expect_match(out, "[2]", fixed = TRUE)
  expect_match(out, "rp-cite-missing", fixed = TRUE)
  expect_match(out, "nope", fixed = TRUE)
  ## text without markers passes through untouched
  expect_identical(citations("no markers here", km), "no markers here")
})

test_that("references layer shows only cited entries when only_cited", {
  res <- render_spec(system.file("examples", "atac_qc_spec.yaml",
    package = "reporter"),
    result_path = "/data/Report/atac_project_2024/test0706_drosophila",
    output = tempfile(fileext = ".html"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  ## fastp cited -> renumbered to [1]; unrelated bib entries dropped
  expect_match(html, "id=\"ref-1\"", fixed = TRUE)
  expect_false(grepl("id=\"ref-2\"", html, fixed = TRUE))
  expect_false(grepl("VIRmiRNA", html, fixed = TRUE))
})

test_that("explanation table fills unmatched columns with 待更新", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  ctx$.rp_set_module("mod-x")
  dt <- data.frame(SampleName = "s1", TotallyNewCol = 1)
  out <- ctx$data_table(dt, title = "t")
  html <- paste(as.character(as.list(out)), collapse = "\n")
  expect_match(html, "rp-details", fixed = TRUE)     # attached (1 matched)
  expect_match(html, "待更新", fixed = TRUE)          # unmatched col filled
})
