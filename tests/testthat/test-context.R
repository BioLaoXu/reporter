test_that("report_context basics: meta, options, validation", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, species = "Homo_sapiens", project = "P1",
    code = "C1", company = "ACME", phonenum = "123",
    logo = "smzy", type = "1",
    options = list(show_number = 5))
  expect_s3_class(ctx, "reporter_ctx", exact = TRUE)
  expect_equal(ctx$meta$species, "Homo_sapiens")
  expect_equal(ctx$meta$options$show_number, 5)
  expect_equal(ctx$meta$caption_lang, "en")
  expect_error(report_context(tempfile("no-such-dir-")),
    class = "simpleError")
})

test_that("counters advance independently and produce captions", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp)
  expect_equal(ctx$counter_fig(), 0L)
  expect_equal(ctx$counter_tbl(), 0L)

  f1 <- ctx$figure(file.path(tmp, "1.QC/Plot/IP1.Quality.png"),
    title = "T1")
  f2 <- ctx$figure(file.path(tmp, "1.QC/Plot/IP1.Quality.png"),
    title = "T2")
  t1 <- ctx$data_table(data.frame(a = 1:2), title = "D1")
  expect_match(as.character(f1), "Figure 1")
  expect_match(as.character(f2), "Figure 2")
  expect_false(grepl("Figure 2", as.character(f1)))
  expect_match(as.character(t1), "Table 1")
  expect_equal(ctx$counter_fig(), 2L)
  expect_equal(ctx$counter_tbl(), 1L)
})

test_that("zh caption language is honoured", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, caption_lang = "zh")
  f <- ctx$figure(file.path(tmp, "1.QC/Plot/IP1.Quality.png"), title = "x")
  expect_match(as.character(f), "图 1")
})

test_that("subsection registers a TOC entry with current module", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp)
  ctx$.rp_set_module("mod-x")
  h <- ctx$subsection("Peak Calling")
  entries <- ctx$.rp_toc_entries()
  expect_length(entries, 1L)
  expect_equal(entries[[1]]$module, "mod-x")
  expect_equal(entries[[1]]$title, "Peak Calling")
  expect_true(nzchar(entries[[1]]$id))
  expect_match(as.character(h), 'id="sec-')
})

test_that("ctx$find scopes auto_find to the result path", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp)
  imgs <- ctx$find(".png", dir = "1.QC/Plot", key = "Quality")
  expect_length(imgs, 2L)
  expect_true(all(basename(unlist(imgs)) %in%
    c("IP1.Quality.png", "IP2.Quality.png")))
  expect_identical(names(imgs), c("IP1", "IP2"))
})

test_that("callout shortcuts map to semantic types", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp)
  expect_match(as.character(ctx$note("n")), "rp-callout-note")
  expect_match(as.character(ctx$warning("w")), "rp-callout-warning")
  expect_match(as.character(ctx$tip("t")), "rp-callout-tip")
})
