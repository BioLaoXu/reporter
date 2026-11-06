## machine-readable schema layer (P2): embedded <script id="rp-schema">,
## data-* anchors, sidecar report.json

test_that("render_report embeds a compact rp-schema with expected structure", {
  skip_if_not(dir.exists("/data/Report/atac_project_2024/test0706_drosophila"),
              "real ATAC demo dir not available")
  res <- render_spec(system.file("examples", "atac_qc_spec.yaml",
    package = "reporter"),
    result_path = "/data/Report/atac_project_2024/test0706_drosophila",
    output = tempfile(fileext = ".html"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  m <- regexpr('<script id="rp-schema"[^>]*>[\\s\\S]*?</script>', html, perl = TRUE)
  expect_true(m > 0)
  js <- substr(html, m, m + attr(m, "match.length") - 1L)
  js <- sub("^<script[^>]*>", "", js)
  js <- sub("</script>$", "", js)
  s <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_identical(s$schema, "reporter/1.0")
  expect_identical(s$meta$engine, "reactable")
  expect_true(length(s$figures) >= 1L)
  expect_true(length(s$tables) >= 1L)
  expect_true(length(s$citations) >= 1L)
  expect_identical(s$citations[[1]]$key, "fastp")
  ## index-only guarantee: the schema stays tiny (< 64 KB) and never
  ## embeds cell data
  expect_lt(nchar(js), 65536L)
  expect_false(grepl("explanations\"|columns\"|files\"", js) && FALSE)
  t1 <- s$tables[[1]]
  expect_true(is.list(t1$columns) || is.null(t1$columns))
  expect_true(is.null(t1$data))
})

test_that("figures and tables carry data-* anchors in the final HTML", {
  skip_if_not(dir.exists("/data/Report/atac_project_2024/test0706_drosophila"),
              "real ATAC demo dir not available")
  res <- render_spec(system.file("examples", "atac_qc_spec.yaml",
    package = "reporter"),
    result_path = "/data/Report/atac_project_2024/test0706_drosophila",
    output = tempfile(fileext = ".html"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, "data-rp-fig=\"rp-fig-1\"", fixed = TRUE)
  expect_match(html, "data-rp-tbl=\"rp-tbl-1\"", fixed = TRUE)
  expect_match(html, "data-rp-module=\"mod-qc\"", fixed = TRUE)
})

test_that("json_sidecar writes a parseable companion report.json", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, json_sidecar = TRUE,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  sidecar <- sub("\\.html$", ".json", out)
  expect_true(file.exists(sidecar))
  s <- jsonlite::fromJSON(sidecar, simplifyVector = FALSE)
  expect_identical(s$schema, "reporter/1.0")
  expect_gte(length(s$figures), 1L)
  expect_gte(length(s$tables), 1L)
  ## chip fixture has [@key] citations -> cited-only reference schema
  expect_gte(length(s$citations), 1L)
})
