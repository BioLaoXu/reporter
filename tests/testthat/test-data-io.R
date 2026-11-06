test_that("read_result_table reads csv/tsv/xlsx/gz and returns NULL on missing", {
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(a = 1:3, b = c("x", "y", "z")), csv,
    row.names = FALSE)
  ## text path: delimiter auto-detection (no sep given)
  dt <- read_result_table(csv)
  expect_s3_class(dt, "data.frame")
  expect_equal(nrow(dt), 3L)

  ## tsv auto-detected too
  tsv <- tempfile(fileext = ".txt")
  writeLines(c("a\tb", "1\tx", "2\ty"), tsv)
  expect_equal(nrow(read_result_table(tsv)), 2L)

  ## gz-compressed text
  gz <- tempfile(fileext = ".csv.gz")
  con <- gzfile(gz, "w")
  writeLines(c("a,b", "1,x", "2,y"), con); close(con)
  expect_equal(nrow(read_result_table(gz)), 2L)

  ## xlsx path delegates to OXM::readFile
  skip_if_not_installed("openxlsx")
  xlsx <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(data.frame(a = 1:2), xlsx)
  expect_equal(nrow(read_result_table(xlsx)), 2L)

  ## failure semantics
  expect_null(read_result_table(tempfile("missing")))
  expect_null(read_result_table(tempfile("empty")))

  ## renaming + nrows slicing
  dt2 <- read_result_table(csv, new_names = c("A", "B"))
  expect_named(dt2, c("A", "B"))
  expect_equal(nrow(read_result_table(csv, nrows = 2L)), 2L)
})

test_that("auto_find returns named lists and drops empty files", {
  tmp <- make_chip_fixture()
  imgs <- auto_find(file.path(tmp, "1.QC/Plot"), format_str = ".png",
    key = "Quality")
  expect_length(imgs, 2L)
  expect_identical(names(imgs), c("IP1", "IP2"))
  expect_length(auto_find(file.path(tmp, "nothere"), ".png"), 0L)
})

test_that("reference metadata flows through ctx meta (no xlsx lookup)", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, species = "Homo_sapiens",
    ref_version = "GRCh38.98", fasta_db = "Ensembl", gtf_db = "Ensembl 98")
  expect_equal(ctx$meta$ref_version, "GRCh38.98")
  expect_equal(ctx$meta$fasta_db, "Ensembl")
  ## modules only read meta; default is NA not "Unknow"
  ctx2 <- report_context(tmp)
  expect_true(is.na(ctx2$meta$ref_version))
})

test_that("table_explain resolves bundled sheets and filters columns", {
  out <- table_explain("QC", colns = c("SampleName", "RawReads"))
  expect_false(is.null(out))
  txt <- as.character(out)
  expect_match(txt, "rp-details")
})
