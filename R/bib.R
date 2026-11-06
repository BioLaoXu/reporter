#' Parse a BibTeX file
#'
#' Minimal dependency-free BibTeX reader good enough for reference lists
#' in analysis reports: handles the common entry types
#' (`@article`, `@book`, `@inproceedings`, `@misc`, `@software`, ...) and
#' the standard fields (`title`, `author`, `journal`/`booktitle`, `year`,
#' `volume`, `number`, `pages`, `doi`, `url`, `note`), including
#' multi-line field values with balanced braces.
#'
#' @param path character(1). Path to a `.bib` file.
#' @return A data frame with one row per entry and columns `key`,
#'   `type`, `author`, `title`, `journal`, `year`, `volume`, `number`,
#'   `pages`, `doi`, `url` (missing fields are `NA`), plus `raw`
#'   character with the untouched entry text.
#' @seealso [reference_list()]
#' @export
#'
#' @examples
#' \donttest{
#' bib <- read_bib(system.file("extdata", "references.bib", package = "reporter"))
#' nrow(bib)
#' }
read_bib <- function(path) {
  path <- rp_char1(path)
  if (is.null(path)) {
    message("reporter: bib path is empty/NA")
    return(NULL)
  }
  if (!file.exists(path)) {
    message("reporter: bib file not found: ", path)
    return(NULL)
  }
  lines <- trimws(readLines(path, warn = FALSE))  # strips CRLF residue
  lines <- lines[nzchar(lines)]

  entries <- list()
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    m <- regmatches(lines[i],
      regexec("^[[:space:]]*@[[:space:]]*([A-Za-z]+)[[:space:]]*\\{[[:space:]]*([^,[:space:]]*)[[:space:]]*,[[:space:]]*$", lines[i]))[[1L]]
    if (length(m) == 3L) {
      etype <- tolower(m[2L])
      ekey <- m[3L]
      body <- character()
      depth <- 1L
      i <- i + 1L
      while (i <= n) {
        body <- c(body, lines[i])
        depth <- depth +
          lengths(regmatches(lines[i], gregexpr("\\{", lines[i]))) -
          lengths(regmatches(lines[i], gregexpr("\\}", lines[i])))
        if (depth <= 0L) break
        i <- i + 1L
      }
      fields <- rp_parse_bib_fields(body)
      vals <- list(
        key = ekey, type = etype,
        author = fields$author, title = fields$title,
        journal = fields$journal %||% fields$booktitle,
        year = fields$year, volume = fields$volume,
        number = fields$number, pages = fields$pages,
        doi = fields$doi, url = fields$url
      )
      ## missing fields become NA so every row has the same 11 columns
      vals <- lapply(vals, function(v) {
        if (is.null(v) || length(v) == 0L || is.na(v)) NA_character_
        else as.character(v)[1L]
      })
      entries[[length(entries) + 1L]] <- as.data.frame(
        vals, stringsAsFactors = FALSE)
    }
    i <- i + 1L
  }
  if (!length(entries)) return(NULL)
  out <- do.call(rbind, entries)
  rownames(out) <- NULL
  out
}

## internal: extract field = {value} pairs from the lines of one entry,
## honoring balanced braces inside values and joining continuation lines
rp_parse_bib_fields <- function(lines) {
  txt <- paste(lines, collapse = "\n")
  fields <- list()
  m <- gregexpr("[A-Za-z][A-Za-z0-9_-]*\\s*=\\s*\\{", txt)
  if (identical(as.integer(m[[1L]]), -1L)) return(fields)
  starts <- as.integer(m[[1L]])
  mlen <- attr(m[[1L]], "match.length")
  labels <- regmatches(txt, m)[[1L]]
  nch <- nchar(txt)
  for (k in seq_along(starts)) {
    open_at <- starts[k] + mlen[k] - 1L  # at "{"
    name <- tolower(trimws(sub("[[:space:]]*=[[:space:]]*\\{$", "", labels[k])))
    depth <- 1L           # the opening brace at open_at is already counted
    pos <- open_at + 1L
    while (pos <= nch) {
      ch <- substr(txt, pos, pos)
      if (ch == "{") depth <- depth + 1L
      else if (ch == "}") {
        depth <- depth - 1L
        if (depth == 0L) break
      }
      pos <- pos + 1L
    }
    val <- substr(txt, open_at + 1L, pos - 1L)
    val <- gsub("\\s+", " ", trimws(val))
    fields[[name]] <- val
  }
  fields
}

#' Render a numbered reference list
#'
#' Formats a BibTeX entry table (from [read_bib()]) as an ordered
#' reference list: authors (year). title. journal volume(number). pages.
#' with a DOI/URL link when available.
#'
#' @param bib A data frame from [read_bib()].
#' @return A `htmltools` tag object (`<ol class="rp-refs">`).
#' @seealso [read_bib()], [mod_references()]
#' @export
reference_list <- function(bib) {
  ## defensive: nothing to render -> an empty (but valid) list block
  if (is.null(bib) || !is.data.frame(bib) || nrow(bib) == 0L) {
    return(tags$ol(class = "rp-refs"))
  }
  fmt_authors <- function(a) {
    if (is.na(a) || !nzchar(a)) return("")
    a <- gsub("[[:space:]]+and[[:space:]]+", ", ", a, ignore.case = TRUE)
    a <- gsub("[{}]", "", a)
    a
  }
  fmt_entry <- function(r) {
    parts <- character()
    if (nzchar(fmt_authors(r$author))) {
      parts <- c(parts, paste0(fmt_authors(r$author), "."))
    }
    if (!is.na(r$year) && nzchar(r$year)) parts <- c(parts, paste0("(", r$year, ")"))
    if (!is.na(r$title) && nzchar(r$title)) {
      parts <- c(parts, paste0(gsub("[{}]", "", r$title), "."))
    }
    tail_bits <- character()
    if (!is.na(r$journal) && nzchar(r$journal)) {
      tail_bits <- c(tail_bits, gsub("[{}]", "", r$journal))
    }
    vol <- ""
    if (!is.na(r$volume) && nzchar(r$volume)) {
      vol <- r$volume
      if (!is.na(r$number) && nzchar(r$number)) vol <- paste0(vol, "(", r$number, ")")
      tail_bits <- c(tail_bits, vol)
    }
    if (!is.na(r$pages) && nzchar(r$pages)) tail_bits <- c(tail_bits, r$pages)
    if (length(tail_bits)) parts <- c(parts, paste(tail_bits, collapse = " "))
    txt <- paste(parts, collapse = " ")
    link <- if (!is.na(r$doi) && nzchar(r$doi)) {
      paste0(' <a class="rp-ref-doi" href="https://doi.org/', r$doi,
             '" target="_blank" rel="noopener">doi:', r$doi, "</a>")
    } else if (!is.na(r$url) && nzchar(r$url)) {
      paste0(' <a class="rp-ref-doi" href="', r$url,
             '" target="_blank" rel="noopener">link</a>')
    } else {
      ""
    }
    htmltools::HTML(paste0(htmltools::htmlEscape(txt), link))
  }
  htmltools::tags$ol(
    class = "rp-refs",
    lapply(seq_len(nrow(bib)), function(i) {
      htmltools::tags$li(class = "rp-ref", id = paste0("ref-", i),
        fmt_entry(bib[i, ]))
    })
  )
}
