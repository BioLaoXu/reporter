test_that("figure_block inlines local images as data URIs", {
  png <- write_fixture_png(file.path(tempdir(), "f1.png"))
  fig <- figure_block(src = png, number = 1L, title = "Cap",
    caption = "Figure 1")
  txt <- as.character(fig)
  expect_match(txt, "data:image/png;base64,")
  expect_match(txt, "Figure 1")
  expect_match(txt, "class=\"rp-fig\"")
})

test_that("figure_block tolerates missing files but can be strict", {
  fig <- figure_block(src = tempfile("missing"), title = "x")
  expect_match(as.character(fig), "data:image/gif;base64,")
  expect_error(
    figure_block(src = tempfile("missing"), title = "x", missing_ok = FALSE),
    "not found")
})

test_that("gallery renders panes, items and a search box", {
  tmp <- make_chip_fixture()
  imgs <- c(a = file.path(tmp, "1.QC/Plot/IP1.Quality.png"),
            b = file.path(tmp, "1.QC/Plot/IP2.Quality.png"))
  g <- as.character(gallery(imgs, title = "QC gallery"))
  expect_match(g, "rp-gallery-pane active")
  expect_match(g, "rp-gallery-item")
  expect_match(g, "rp-gallery-search")
  expect_match(g, "QC gallery")
})

test_that("callout variants and kv_table", {
  expect_match(as.character(callout("watch out", type = "warning", title = "T")),
    "rp-callout-warning")
  expect_error(callout("x", type = "nope"), "should be one of")
  kv <- as.character(kv_table(list(Species = "Human", N = "3")))
  expect_match(kv, "<table[^>]*class=\"rp-kv\"")
  expect_match(kv, "Species")
})

test_that("text_block concatenates prose and splits paragraphs", {
  t <- as.character(text_block("line one.", "line two.\n\nline three."))
  expect_match(t, "line one\\.")
  expect_equal(length(gregexpr("rp-text", t)[[1L]]), 2L)
})

test_that("table_block accepts data frames and passthrough widgets", {
  tb <- as.character(table_block(data.frame(a = 1:2), number = 1L,
    title = "demo"))
  expect_match(tb, "Table 1")
  expect_match(tb, "rp-badge-tbl")
  tb2 <- table_block("a widget should pass through")
  expect_true(inherits(tb2, c("shiny.tag.list")))
})

test_that("empty_block, details_block, file_path_note", {
  expect_match(as.character(empty_block("nothing here")), "rp-empty")
  expect_match(as.character(details_block("content", "click me")),
    "<details")
  expect_match(as.character(file_path_note("/a/b")), "rp-filepath")
})

test_that("data_table builds a reactable with package defaults", {
  w <- data_table(data.frame(a = 1:3, b = c("x", "y", "z")),
    truncate = "b")
  expect_s3_class(w, "reactable")
  cols <- render_cols("a")
  expect_named(cols, "a")
  expect_match(as.character(tippy_cell("long text")), "rp-tippy-cell")
})
