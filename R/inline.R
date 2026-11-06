#' Inline all assets into a single HTML file
#'
#' Converts an HTML file that references local `lib/` assets (as
#' produced by [htmltools::save_html()]) into a fully self-contained
#' single HTML file:
#'
#' - `<script src="lib/...">` tags are replaced by inline `<script>`
#'   blocks (contents escaped so a literal `</script>` inside a bundle
#'   cannot break the page);
#' - `<link rel="stylesheet" href="lib/...">` tags are replaced by
#'   inline `<style>` blocks;
#' - `url(...)` references inside inlined CSS (fonts, images) are
#'   themselves base64 encoded relative to the CSS file location;
#' - `sourceMappingURL` comments are stripped to avoid console noise;
#' - a UTF-8 charset meta tag is guaranteed.
#'
#' The result is verified: any remaining local `src=`/`href=` reference
#' pointing under `libdir` triggers a warning, so a broken standalone
#' build can never pass unnoticed.
#'
#' @param input character(1). Path to the source HTML (with a `libdir`
#'   next to it).
#' @param output character(1). Path for the self-contained HTML.
#' @param libdir character(1). Directory holding the referenced assets
#'   (as used by [htmltools::save_html()]).
#' @param overwrite logical(1). Overwrite an existing `output`.
#' @return `output` invisibly.
#' @seealso [render_report()]
#' @export
#'
#' @examples
#' \donttest{
#' p <- tagList(tags$head(tags$meta(charset = "UTF-8")),
#'   tags$body(tags$h2("hello"), reactable::reactable(mtcars[1:4, ])))
#' d <- file.path(tempdir(), "rp-inline"); dir.create(d, recursive = TRUE)
#' f <- file.path(d, "index.html")
#' htmltools::save_html(p, f, libdir = "lib")
#' inline_html(f, file.path(d, "single.html"), file.path(d, "lib"))
#' }
inline_html <- function(input, output, libdir, overwrite = TRUE) {
  input <- as.character(input)[1L]
  output <- as.character(output)[1L]
  libdir <- as.character(libdir)[1L]
  stopifnot(file.exists(input), dir.exists(libdir))
  if (file.exists(output) && !isTRUE(overwrite)) {
    stop("reporter: output exists and overwrite = FALSE: ", output, call. = FALSE)
  }
  out_dir <- dirname(output)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  html <- rp_read_text(input)

  ## ---- inline <script src="lib/..."> --------------------------------
  html <- rp_replace_matches(
    html, '<script[^>]*src="(lib/[^"]+)"[^>]*>[[:space:]]*</script>',
    function(m) {
      file <- file.path(libdir, sub("^lib/", "",
        sub('.*src="([^"]+)".*', "\\1", m)))
      if (!file.exists(file)) return(m) # verify step will warn
      paste0(
        "<script>\n",
        rp_escape_inline_js(rp_strip_map_comments(rp_read_text(file))),
        "\n</script>"
      )
    }
  )

  ## ---- inline <link href="lib/..."> ---------------------------------
  html <- rp_replace_matches(
    html, '<link[^>]*href="(lib/[^"]+)"[^>]*>',
    function(m) {
      file <- file.path(libdir, sub("^lib/", "",
        sub('.*href="([^"]+)".*', "\\1", m)))
      if (!file.exists(file)) return(m)
      css <- rp_inline_css_urls(
        rp_strip_map_comments(rp_read_text(file)), dirname(file)
      )
      paste0("<style>\n", css, "\n</style>")
    }
  )

  ## ---- guarantee charset meta ---------------------------------------
  if (!grepl("<meta[^>]*charset", html, ignore.case = TRUE)) {
    html <- sub("(<title>)", "<meta charset=\"UTF-8\"/>\\1", html)
  }

  ## ---- verify no local lib references remain ------------------------
  leftover <- unique(unlist(regmatches(
    html, gregexpr('(src|href)="lib/[^"]+"', html)
  )))
  if (length(leftover)) {
    warning(
      "reporter: standalone verification failed, un-inlined references:\n",
      paste(leftover, collapse = "\n"),
      call. = FALSE
    )
  }

  writeLines(html, output, useBytes = TRUE)
  invisible(output)
}

#' Replace regex matches of a single string with per-match function output
#'
#' Base R's [gsub()] only substitutes fixed replacement strings; this
#' helper applies a function to each matched substring and splices the
#' results back (via [regmatches()<-], which handles shifted offsets).
#'
#' @param html character(1). Subject text.
#' @param pattern character(1). Regular expression (see [gregexpr()]).
#' @param resolver function(character(1)) -> character(1) mapping a full
#'   match to its replacement.
#' @return character(1) with all matches replaced.
#' @noRd
rp_replace_matches <- function(html, pattern, resolver, perl = FALSE) {
  m <- gregexpr(pattern, html, perl = perl)
  if (identical(as.integer(m[[1L]]), -1L)) return(html)
  full <- regmatches(html, m)[[1L]]
  repl <- vapply(
    full, function(s) {
      out <- as.character(resolver(s))[1L]
      if (is.na(out)) s else out
    },
    character(1L), USE.NAMES = FALSE
  )
  regmatches(html, m) <- list(repl)
  html
}

#' Base64-encode url() references inside CSS text (internal)
#'
#' @param css character(1). CSS content.
#' @param css_dir character(1). Directory the CSS file lives in; url()
#'   references are resolved against it.
#' @return character(1) CSS with local url() references replaced by
#'   data URIs. Remote/http references are left untouched.
#' @noRd
rp_inline_css_urls <- function(css, css_dir) {
  m <- gregexpr("url\\((['\"]?)([^'\")]+)\\1\\)", css)
  if (identical(as.integer(m[[1L]]), -1L)) return(css)
  refs <- regmatches(css, m)[[1L]]
  urls <- sub("url\\((['\"]?)([^'\")]+)\\1\\)", "\\2", refs)
  keep <- !grepl("^(data:|https?://|#)", urls) &
    file.exists(file.path(css_dir, urls))
  for (i in which(keep)) {
    f <- normalizePath(file.path(css_dir, urls[i]), mustWork = FALSE)
    css <- gsub(refs[i],
      paste0("url(", xfun::base64_uri(f), ")"),
      css, fixed = TRUE
    )
  }
  css
}
