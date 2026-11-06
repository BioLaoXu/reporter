#' Internal helpers for the reporter package
#'
#' These functions are not exported and are intended for internal use
#' within reporter only.
#'
#' @name reporter-internal
#' @keywords internal
#' @importFrom htmltools tagList tags HTML css
NULL

#' NULL-default operator (rlang convention)
#'
#' Returns `lhs` when it is not `NULL`, otherwise `rhs`. Imported semantics
#' kept local so modules can rely on it without importing rlang in user code.
#'
#' @param lhs Any object.
#' @param rhs Any object used as fallback.
#' @return `lhs` if not `NULL`, else `rhs`.
#' @noRd
`%||%` <- function(lhs, rhs) {
  if (is.null(lhs)) rhs else lhs
}

#' Make a slug-safe HTML id from free text
#'
#' Converts arbitrary section titles into stable, URL-safe anchor ids by
#' keeping CJK/word characters, replacing separators with hyphens and
#' hashing the original text to guarantee uniqueness.
#'
#' @param x character(1) or character vector of free text.
#' @param prefix character(1) optional id prefix.
#' @param n_hash integer(1) number of hash characters to append for uniqueness.
#' @return character vector of slug ids, same length as `x`.
#' @noRd
rp_slug <- function(x, prefix = NULL, n_hash = 6L) {
  x <- as.character(x)
  if (length(x) == 0L) return(character(0L))
  out <- vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) s <- "sec"
    s <- tolower(s)
    ## keep letters (incl. CJK), digits; collapse everything else
    s <- gsub("[^\\p{L}\\p{N}]+", "-", s, perl = TRUE)
    s <- gsub("^-+|-+$", "", s)
    if (!nzchar(s)) s <- "sec"
    s
  }, character(1L), USE.NAMES = FALSE)
  hash <- vapply(x, function(s) {
    substr(digest_like(s), 1L, n_hash)
  }, character(1L), USE.NAMES = FALSE)
  out <- paste0(out, "-", hash)
  if (!is.null(prefix)) out <- paste0(prefix, out)
  out
}

#' Tiny deterministic string hash (no digest dependency)
#'
#' FNV-1a style hash rendered as hex, used only for id uniqueness. Not
#' cryptographically secure and does not need to be.
#'
#' @param s character(1) input string.
#' @return character(1) hex hash.
#' @noRd
digest_like <- function(s) {
  s <- enc2utf8(as.character(s)[1L])
  ## FNV-1a over raw bytes, kept in [0, 2^31-1) so bitwXor stays in
  ## R's integer range (locale independent), rendered as 8 hex chars
  h <- 2166136261  # > 2^31: kept double on purpose (int range would overflow)
  for (b in as.integer(charToRaw(s))) {
    h <- bitwXor(h %% 2147483647L, b)
    h <- (h * 16777619) %% 2147483647L
  }
  sprintf("%08x", h)
}

#' Encode an image file as a base64 data URI
#'
#' Wraps [xfun::base64_uri()] with existence/type checks and a graceful
#' placeholder so a missing figure never breaks a whole report.
#'
#' @param path character(1) path to an image file (png/jpg/svg/gif...).
#' @param placeholder logical(1) when TRUE (default) a missing file yields
#'   a transparent 1x1 png data URI instead of an error.
#' @return character(1) `data:` URI string.
#' @noRd
rp_data_uri <- function(path, placeholder = TRUE) {
  path <- as.character(path)[1L]
  if (!file.exists(path) || file.size(path) == 0) {
    if (!isTRUE(placeholder)) {
      stop("Image file not found or empty: ", path, call. = FALSE)
    }
    ## 1x1 transparent GIF
    return(paste0(
      "data:image/gif;base64,",
      "R0lGODlhAQABAIAAAAAAAP///yH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=="
    ))
  }
  ## compression layer: large rasters are downscaled and re-encoded as
  ## WebP when {magick} is available (typically 70-80% smaller); any
  ## failure falls back to the original file untouched
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("png", "jpg", "jpeg") &&
      requireNamespace("magick", quietly = TRUE)) {
    webp <- tryCatch({
      img <- magick::image_read(path)
      info <- magick::image_info(img)
      if (!is.null(info$width) && info$width > 1360) {
        img <- magick::image_scale(img, "1360x")
      }
      tmp <- tempfile(fileext = ".webp")
      magick::image_write(img, tmp, format = "webp", quality = 84)
      if (file.size(tmp) < file.size(path)) tmp else {
        unlink(tmp); NULL
      }
    }, error = function(e) NULL, warning = function(w) NULL)
    if (!is.null(webp) && file.exists(webp)) {
      uri <- xfun::base64_uri(webp)
      unlink(webp)
      return(uri)
    }
  }
  xfun::base64_uri(path)
}

#' Empty-input detector (defensive programming helper)
#'
#' TRUE for `NULL`, zero-length objects, and character inputs that are
#' all `NA` or blank — the shapes "empty input" takes in practice.
#'
#' @param x Any object.
#' @return logical(1).
#' @noRd
rp_is_empty <- function(x) {
  if (is.null(x)) return(TRUE)
  if (length(x) == 0L) return(TRUE)
  if (is.character(x)) return(all(is.na(x) | !nzchar(x)))
  FALSE
}

#' First usable scalar string, or NULL
#'
#' Coerces `x` to character, drops `NA`/blank entries and returns the
#' first remaining element; `NULL` when nothing usable (missing-argument
#' safe).
#'
#' @param x Any object.
#' @return character(1) or `NULL`.
#' @noRd
rp_char1 <- function(x) {
  if (rp_is_empty(x)) return(NULL)
  v <- as.character(x)
  v <- v[!is.na(v) & nzchar(v)]
  if (length(v) == 0L) NULL else v[[1L]]
}

#' Data-frame usability check for table primitives
#'
#' TRUE only when `d` is a data frame / matrix with at least one row and
#' one column — everything else counts as "empty input" for the table
#' primitives.
#'
#' @param d object to check.
#' @return logical(1).
#' @noRd
rp_df_usable <- function(d) {
  if (!is.data.frame(d) && !is.matrix(d)) return(FALSE)
  !is.null(d) && nrow(d) > 0L && ncol(d) > 0L
}

#' Assert scalar-ish arguments used by exported functions
#'
#' Lightweight defensive helper: checks that `x` is a character of length
#' `n` (or NULL when allowed).
#'
#' @param x object to check.
#' @param n integer(1) expected length.
#' @param allow_null logical(1) whether NULL is acceptable.
#' @param arg character(1) argument name for error messages.
#' @return `x` invisibly.
#' @noRd
rp_check_chr <- function(x, n = 1L, allow_null = TRUE, arg = deparse(substitute(x))) {
  if (is.null(x)) {
    if (isTRUE(allow_null)) return(invisible(x))
    stop("`", arg, "` must not be NULL", call. = FALSE)
  }
  if (!is.character(x) || length(x) != n) {
    stop(sprintf("`%s` must be a character of length %d", arg, n), call. = FALSE)
  }
  invisible(x)
}

#' Read a text file to a single string (UTF-8 safe)
#'
#' @param path character(1) file path.
#' @return character(1) file content.
#' @noRd
rp_read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Escape `</` inside inline script content
#'
#' Prevents a literal `</script>` sequence inside inlined JS from closing
#' the surrounding tag prematurely.
#'
#' @param x character(1) JavaScript source.
#' @return character(1) escaped source.
#' @noRd
rp_escape_inline_js <- function(x) {
  gsub("</", "<\\/", x, fixed = TRUE)
}

#' Strip sourceMappingURL/ sourceMap comments from inlined assets
#'
#' @param x character(1) css or js content.
#' @return character(1) content without map comments.
#' @noRd
rp_strip_map_comments <- function(x) {
  x <- gsub("//# sourceMappingURL=.*", "", x)
  gsub("/\\*# sourceMappingURL=.*?\\*/", "", x)
}

## internal: absolute paths -> paths relative to the result root (for the
## machine-readable schema). Non-matching paths are returned unchanged so
## externally provided files stay usable.
rp_rel_paths <- function(paths, root) {
  paths <- as.character(paths)
  paths <- paths[!is.na(paths) & nzchar(paths)]
  if (!length(paths) || is.null(root) || is.na(root)) return(paths)
  root_n <- sub("/+$", "", root)
  out <- vapply(paths, function(p) {
    if (startsWith(p, root_n)) {
      rel <- substring(p, nchar(root_n) + 1L)
      sub("^/+", "", rel)
    } else p
  }, character(1L), USE.NAMES = FALSE)
  out
}
