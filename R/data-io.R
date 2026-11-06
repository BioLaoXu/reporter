#' Read a result table (csv/tsv/txt/xlsx/xls/gz)
#'
#' Unified reader for bioinformatics result tables:
#'
#' * **xlsx/xls** delegate to [OXM::readFile()] — the in-house unified
#'   Excel reader (no separate openxlsx plumbing here);
#' * **text tables** (csv/tsv/txt/`.gz`) go through
#'   [data.table::fread()] with **delimiter auto-detection** when `sep`
#'   is not given (more robust than extension-based guessing).
#'
#' On top of the readers this wrapper adds the report-friendly
#' semantics the modules rely on:
#'
#' * missing/empty/unreadable files return `NULL` (with a message)
#'   instead of stopping, so modules can fall back to [empty_block()];
#' * optional `nrows` fast path (sliced after read);
#' * optional `new_names` column renaming.
#'
#' @param file character(1). Path to the table file.
#' @param sep character(1) or `NULL`. Field separator for text tables;
#'   `NULL` (default) auto-detects.
#' @param header logical(1). First row is a header.
#' @param excel logical(1). Force xlsx reading regardless of extension
#'   (defaults to `TRUE` for `.xlsx`/`.xls` files).
#' @param nrows integer(1). Return at most the first `nrows` rows;
#'   `Inf` reads all.
#' @param new_names character vector. Optional replacement column
#'   names (must match the number of columns).
#' @return A data frame, or `NULL` when the file is unreadable/empty.
#' @seealso [auto_find()], [OXM::readFile()]
#' @export
#'
#' @examples
#' \dontshow{
#' tf <- tempfile(fileext = ".csv")
#' write.csv(data.frame(a = 1:3, b = c("x", "y", "z")), tf, row.names = FALSE)
#' }
#' df <- read_result_table(tf)
#' dim(df)
read_result_table <- function(file, sep = NULL, header = TRUE,
                              excel = grepl("\\.(xlsx|xls)$", file,
                                            ignore.case = TRUE),
                              nrows = Inf, new_names = NULL) {
  file <- rp_char1(file)
  if (is.null(file) || !file.exists(file) || file.size(file) == 0) {
    message("reporter: table file missing or empty: ", file %||% "<NULL>")
    return(NULL)
  }
  dat <- tryCatch(
    {
      if (isTRUE(excel)) {
        ## Excel: prefer the OXM unified reader (readFile). NOTE: OXM's
        ## NAMESPACE registers S3 methods on ggplot2 generics and its
        ## namespace load fails in some host sessions (e.g. under
        ## testthat) — upstream issue, not fixable here. When that
        ## happens we silently fall back to openxlsx so xlsx reading
        ## never depends on OXM's load state.
        dt <- tryCatch({
          x <- OXM::readFile(filePath = file, sheet = 1L)
          as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
        }, error = function(e) {
          openxlsx::read.xlsx(file, rowNames = FALSE)
        })
        if (!is.infinite(nrows) && nrow(dt) > nrows) {
          dt <- utils::head(dt, nrows)
        }
        dt
      } else {
        ## text -> fread with delimiter auto-detection
        as.data.frame(data.table::fread(
          file, sep = if (is.null(sep)) "auto" else sep,
          header = header, showProgress = FALSE,
          nrows = if (is.infinite(nrows)) -1L else nrows,
          stringsAsFactors = FALSE, check.names = FALSE
        ))
      }
    },
    error = function(e) {
      message("reporter: failed to read table '", file, "': ",
              conditionMessage(e))
      NULL
    }
  )
  if (is.null(dat) || nrow(dat) == 0L || ncol(dat) == 0L) return(NULL)
  if (!isFALSE(new_names) && !is.null(new_names) &&
      length(new_names) == ncol(dat)) {
    names(dat) <- as.character(new_names)
  }
  dat
}

#' Auto-discover result files by pattern
#'
#' Migration of the legacy `AutoFind()`: recursively lists files under
#' `search_path` matching `*<format_str>`, optionally filtered by a
#' key (`strict` controls anchored vs. fuzzy matching, against either
#' the file base name or its parent directory name), drops empty files
#' and returns a **named list** whose names are the sample labels
#' derived from the file name.
#'
#' @param search_path character(1). Directory to scan.
#' @param format_str character(1). File extension / pattern fragment,
#'   e.g. `".png"`, `".tsv"`.
#' @param gap character(1). Regex splitting the base name; the first
#'   piece becomes the sample label (legacy default `"\\."`).
#' @param in_base logical(1). Derive sample labels and apply the key
#'   against base names.
#' @param in_dirname logical(1). Alternative to `in_base`: derive
#'   labels from the parent directory base name.
#' @param key character(1). Key word used for filtering.
#' @param recursive logical(1). Scan recursively.
#' @param strict logical(1). `TRUE` anchors the key at the start
#'   (`^key`); `FALSE` matches anywhere.
#' @return Named list of file paths (names = sample labels); an empty
#'   list when nothing matches.
#' @export
#'
#' @examples
#' tf <- tempfile(fileext = ".png"); writeLines("fake", tf)
#' auto_find(tempdir(), ".png")
auto_find <- function(search_path, format_str = ".rds", gap = "\\.",
                      in_base = TRUE, in_dirname = FALSE, key = "xxx",
                      recursive = TRUE, strict = FALSE) {
  search_path <- rp_char1(search_path)
  ## NOTE: key="" is a valid sentinel meaning "match everything"; only
  ## NULL/NA fall back to the legacy default. rp_char1() would clobber
  ## the empty string, hence the explicit handling here.
  key <- if (is.null(key) || (length(key) == 1L && is.na(key))) "xxx"
    else as.character(key)[1L]
  gap <- rp_char1(gap) %||% "\\."
  format_str <- rp_char1(format_str) %||% ".rds"
  if (is.null(search_path) || !dir.exists(search_path)) {
    warning("reporter: auto_find path does not exist: ", search_path)
    return(list())
  }
  candidates <- sort(list.files(
    path = search_path,
    pattern = paste0(".*", format_str),
    full.names = TRUE, recursive = recursive, ignore.case = TRUE
  ))
  if (isTRUE(strict)) {
    if (isTRUE(in_base)) {
      keep <- grepl(paste0("^", key), basename(candidates))
    } else if (isTRUE(in_dirname)) {
      keep <- grepl(paste0("^", key), basename(dirname(candidates)))
    } else {
      keep <- rep(TRUE, length(candidates))
    }
  } else {
    keep <- grepl(key, candidates, ignore.case = FALSE)
  }
  candidates <- candidates[keep]
  if (length(candidates) == 0L) return(list())

  ## drop empty files (legacy behaviour)
  candidates <- candidates[vapply(candidates, function(x) {
    file.size(x) > 0
  }, logical(1L))]

  labels <- NULL
  if (isTRUE(in_base)) {
    labels <- vapply(basename(candidates), function(x) {
      unlist(strsplit(x, split = gap))[1L]
    }, character(1L), USE.NAMES = FALSE)
  } else if (isTRUE(in_dirname)) {
    labels <- vapply(candidates, function(x) {
      unlist(strsplit(basename(dirname(x)), split = gap))[1L]
    }, character(1L), USE.NAMES = FALSE)
  }
  if (is.null(labels)) return(list())

  out <- as.list(candidates)
  names(out) <- labels
  out
}
