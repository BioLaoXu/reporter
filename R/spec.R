## ---------------------------------------------------------------------
## Declarative report specification (YAML -> modules)
## ---------------------------------------------------------------------
## A spec file lets a pipeline author "adapt once, call forever": the
## report structure, narrative text, tables, figures, KPIs and citation
## superscripts are all declared in YAML — no R code required. Compiled
## by render_spec() into the same module machinery as hand-written sets,
## so gating / numbering / inlining / theming all come for free.
##
## Minimal shape (full field reference: docs/功能速查.md §14):
##
##   title: "ATAC-seq 分析报告"
##   style: v2
##   theme: {preset: smzy, primary: "#0D6E8C", extra_variables: {...},
##           extra_css: css/my.css}
##   result: /default/result/dir       # CLI --result overrides
##   references: {bib: lib/Paper/ref.bib}
##   layers:
##     - id: qc
##       title: 测序序列统计与质控
##       required_dir: 1.QC
##       when_type: "1"
##       intro: ["引导段落……", steps: [步骤1, 步骤2]]
##       blocks:
##         - text: "……（支持 **加粗** 与 [@key] 文献角标）"
##         - table: {file: Summary/Filtered.Summary.txt, title: ...,
##                   join: Summary/Raw.Reads.txt, explain: QC,
##                   path_note: ..., lead: ..., desc: ...}
##         - figure: {dir: Plot, pattern: ".*Quality.*", title: ...,
##                    lead: ..., desc: ..., width: "70%", path_note: ...}
##         - kpi: {table: Filtered.Summary.txt,
##                 metrics: [{col: CleanQ30, label: "Clean Q30", ok: 90, warn: 80}]}
##       notes: [...]                   # 尾注段落

#' Load and validate a report specification (YAML)
#'
#' @param spec character(1). Path to the YAML spec file.
#' @return The parsed spec as a list (attribute `spec_dir` = file dir,
#'   used to resolve relative paths).
#' @export
load_spec <- function(spec) {
  spec <- rp_char1(spec)
  if (is.null(spec) || !file.exists(spec)) {
    stop("reporter: spec file not found: ", spec %||% "<NULL>", call. = FALSE)
  }
  sp <- yaml::read_yaml(spec)
  if (is.null(sp$layers) || length(sp$layers) == 0L) {
    stop("reporter: spec has no `layers`", call. = FALSE)
  }
  attr(sp, "spec_dir") <- dirname(normalizePath(spec, mustWork = FALSE))
  sp
}

## internal: resolve a spec-relative path (spec dir -> package project)
rp_spec_path <- function(sp, p) {
  p <- rp_char1(p)
  if (is.null(p)) return(NULL)
  if (grepl("^(/|[A-Za-z]:[/\\\\])", p)) return(p)
  spec_dir <- attr(sp, "spec_dir")
  file.path(spec_dir, p)
}

## internal: inline markdown -> HTML (bold / italic / code only, zero deps)
rp_inline_md <- function(x) {
  x <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", x)
  x <- gsub("(?<!\\*)\\*([^*]+)\\*(?!\\*)", "<em>\\1</em>", x, perl = TRUE)
  x <- gsub("`([^`]+)`", "<code>\\1</code>", x)
  x
}

#' Replace `[@key]` citation markers with superscript anchors
#'
#' Citation keys are resolved against the reference registry built from
#' the spec's `.bib` file (order = bib file order = the numbering of the
#' references layer). Multiple keys in one marker (`[@a; @b]`) collapse
#' into a single superscript `[1,3]`. Unknown keys render as a red
#' `[?key]` badge and are reported — a lost citation can never pass
#' silently.
#'
#' @param text character(1). Narrative text (may contain inline markdown).
#' @param keymap named integer vector: bib key -> reference number.
#' @param missing character vector, updated by reference: keys not found.
#' @return character(1) HTML text.
#' @export
citations <- function(text, keymap, missing = NULL) {
  text <- rp_char1(text)
  if (is.null(text)) return(text)
  ## NOTE: perl = TRUE is mandatory — TRE does not support backslash
  ## escapes inside bracket expressions, the marker would never match
  m <- gregexpr("\\[@[^\\]]+\\]", text, perl = TRUE)
  if (identical(as.integer(m[[1L]]), -1L)) return(text)
  one <- function(marker) {
    keys <- trimws(strsplit(gsub("^\\[@\\s*", "", gsub("\\]$", "", marker)),
      "[;,；，]")[[1L]])
    keys <- sub('^@', '', keys)          # multi-cite shorthand [@a; @b]
    keys <- keys[nzchar(keys)]
    if (!length(keys)) return(marker)
    ## exact set operations: R character indexing turns missing names
    ## into <NA>, losing the key text (would render "[?NA]")
    known <- keys[keys %in% names(keymap)]
    unknown <- setdiff(keys, known)
    cite <- if (length(known)) {
      nums <- as.integer(keymap[known])
      paste0("<sup class=\"rp-cite\"><a href=\"#ref-",
        nums[1L], "\">[", paste(nums, collapse = ","), "]</a></sup>")
    } else {
      '<sup class="rp-cite rp-cite-missing">[?]</sup>'
    }
    if (length(unknown)) {
      cite <- paste0(cite, '<sup class="rp-cite rp-cite-missing">[?',
        paste(unknown, collapse = ", "), "]</sup>")
    }
    cite
  }
  markers <- regmatches(text, m)[[1L]]
  repl <- vapply(markers, one, character(1L), USE.NAMES = FALSE)
  regmatches(text, m) <- list(repl)
  text
}

## internal: assemble one layer as a module (closes over the spec layer)
spec_layer_module <- function(layer, sp) {
  id <- rp_char1(layer$id) %||% rp_slug(layer$title, "layer-")
  title <- rp_char1(layer$title) %||% id
  req <- rp_char1(layer$required_dir)
  when_type <- rp_char1(layer$when_type)
  show_number <- layer$show_number %||% 10L

  intro <- layer$intro
  steps <- NULL
  paras <- NULL
  if (!rp_is_empty(intro)) {
    if (is.list(intro) && !is.null(names(intro))) {
      steps <- intro$steps
      paras <- intro$paras %||%
        intro[setdiff(names(intro), "steps")]
    } else {
      paras <- intro
    }
  }

  blocks <- layer$blocks
  if (!is.null(blocks) && !is.list(blocks)) blocks <- list(blocks)

  render <- function(ctx) {
    ## ---- intro: paragraphs + numbered steps -------------------------
    head_parts <- list()
    if (length(paras)) {
      head_parts <- c(head_parts, lapply(paras, function(p) {
        text_block(HTML(rp_inline_md(rp_char1(p))))
      }))
    }
    if (length(steps) > 0L) {
      head_parts <- c(head_parts, list(
        tags$ol(class = "rp-steps",
          lapply(steps, function(s) {
            tags$li(HTML(rp_inline_md(s)))
          }))
      ))
    }
    ## ---- blocks in declared order -----------------------------------
    body <- lapply(seq_along(blocks), function(i) {
      b <- blocks[[i]]
      what <- names(b)[1L]
      ## text 的载荷是字符串；table/figure/kpi 的载荷是子 list（解一层）
      fld <- if (!identical(what, "text") && is.list(b[[what]])) b[[what]] else b
      lead <- rp_char1(fld$lead)
      desc <- rp_char1(fld$desc)
      path_note <- rp_char1(fld$path_note)
      content <- NULL
      if (identical(what, "text")) {
        content <- text_block(HTML(rp_inline_md(
          rp_char1(b$text))))
      } else if (identical(what, "table")) {
        rel_dir <- rp_char1(layer$dir)
        f <- rp_char1(fld$file)
        f_path <- if (is.null(f)) NULL else
          file.path(ctx$meta$result_path, rel_dir %||% "", f)
        main <- read_result_table(f_path, sep = rp_char1(fld$sep))
        if (!is.null(rp_char1(fld$join))) {
          j <- read_result_table(file.path(ctx$meta$result_path,
            rel_dir %||% "", fld$join), sep = rp_char1(fld$sep))
          if (!is.null(main) && !is.null(j)) {
            main <- merge(main, j,
              by = intersect(names(main), names(j))[1L], all = TRUE)
          }
        }
        content <- if (is.null(main)) {
          empty_block(paste0("未找到表格：", f_path %||% f %||% ""))
        } else {
          ctx$data_table(main, title = rp_char1(fld$title) %||% f,
            truncate = names(main),
            explain = !is.null(rp_char1(fld$explain)),
            explain_sheet = rp_char1(fld$explain),
            source = c(f_path, if (!is.null(rp_char1(fld$join)))
              file.path(ctx$meta$result_path, rel_dir %||% "", fld$join)))
        }
      } else if (identical(what, "figure")) {
        fig_dir <- rp_char1(fld$dir)
        fig_dir <- if (is.null(fig_dir)) rp_char1(layer$dir)
          else if (is.null(rp_char1(layer$dir))) fig_dir
          else file.path(rp_char1(layer$dir), fig_dir)
        imgs <- ctx$find(rp_char1(fld$pattern) %||% ".*\\.png$",
          dir = fig_dir, recursive = TRUE, key = "")
        ## drop non-raster hits (PDF twins of the PNGs etc.)
        imgs <- imgs[grepl("\\.(png|jpe?g|webp|svg|gif)$",
          as.character(imgs), ignore.case = TRUE, perl = TRUE)]
        content <- if (!length(imgs)) {
          empty_block(paste0("未找到匹配的图：", fld$pattern %||% "*.png"))
        } else if (length(imgs) == 1L) {
          ctx$figure(unlist(imgs)[[1L]], title = rp_char1(fld$title),
            width = rp_char1(fld$width))
        } else {
          names(imgs) <- tools::file_path_sans_ext(basename(unlist(imgs)))
          ctx$gallery(imgs, title = rp_char1(fld$title))
        }
      } else if (identical(what, "kpi")) {
        rel_dir <- rp_char1(layer$dir)
        dt <- read_result_table(file.path(ctx$meta$result_path,
          rel_dir %||% "", rp_char1(fld$table)), sep = rp_char1(fld$sep))
        if (is.null(dt)) return(empty_block("KPI 数据表缺失"))
        items <- lapply(fld$metrics, function(m) {
          col <- rp_char1(m$col)
          if (is.null(col) || !col %in% names(dt)) return(NULL)
          v <- rp_pct_mean(dt[[col]])
          kpi(sprintf("%.1f%%", v), rp_char1(m$label) %||% col,
              if (is.na(v)) "neutral"
              else if (v >= (m$ok %||% Inf)) "ok"
              else if (v >= (m$warn %||% -Inf)) "warn" else "bad")
        })
        content <- kpi_row(items)
      }
      if (is.null(content)) return(NULL)
      tagList(
        if (!is.null(lead)) {
          text_block(HTML(rp_inline_md(rp_char1(lead))))
        },
        content,
        if (!is.null(desc)) {
          tags$p(class = "rp-fig-desc",
                 HTML(rp_inline_md(rp_char1(desc))))
        },
        if (!is.null(path_note)) file_path_note(path_note)
      )
    })
    tail_parts <- if (length(layer$notes)) {
      lapply(layer$notes, function(n) {
        text_block(HTML(rp_inline_md(rp_char1(n))))
      })
    } else list()
    do.call(tagList, c(head_parts, body, tail_parts))
  }

  module(
    id = id, title = title,
    required_dirs = if (is.null(req)) character(0) else req,
    when = if (!is.null(when_type)) {
      function(ctx) identical(as.character(ctx$meta$type), when_type)
    },
    render = render
  )
}

#' Render a report from a declarative YAML specification
#'
#' Compiles the spec's `layers` into modules (one per layer, gated on
#' `required_dir`), resolves citation superscripts against the spec's
#' `.bib` file, appends the references layer, and renders through the
#' standard pipeline (theme, numbering, single-file inlining).
#'
#' @param spec character(1). Path to the YAML spec file.
#' @param result_path character(1). Result directory; overrides the
#'   spec's `result` field.
#' @param output,title,standalone,quiet passed to [render_report()].
#' @param theme Optional [reporter_theme()]; built from the spec's
#'   `theme` block when omitted.
#' @return The `reporter_render` result.
#' @export
render_spec <- function(spec, result_path = NULL, output = "report.html",
                        title = NULL, standalone = TRUE, theme = NULL,
                        quiet = FALSE, engine = NULL) {
  sp <- load_spec(spec)
  spec_dir <- attr(sp, "spec_dir")
  result_path <- rp_char1(result_path) %||% rp_char1(sp$result)
  if (is.null(result_path)) {
    stop("reporter: no result directory (pass result_path or set `result`)",
      call. = FALSE)
  }

  ## ---- citation keymap from the spec bib ----------------------------
  bib_path <- rp_char1(sp$references$bib)
  if (!is.null(bib_path)) {
    cand <- c(rp_spec_path(sp, bib_path),
      file.path(result_path, bib_path))
    bib_path <- cand[file.exists(cand)][1L]
  }
  keymap <- integer(0L)
  if (!is.null(bib_path) && file.exists(bib_path)) {
    bib <- read_bib(bib_path)
    if (!is.null(bib) && nrow(bib) > 0L) {
      keymap <- stats::setNames(seq_len(nrow(bib)), bib$key)
    }
  }

  ## ---- theme from spec ----------------------------------------------
  th <- theme %||% {
    t <- sp$theme %||% list()
    ev <- t$extra_variables %||% list()
    reporter_theme(
      preset = rp_char1(t$preset) %||% "blank",
      primary = rp_char1(t$primary),
      style = rp_char1(t$style) %||% "classic",
      company = rp_char1(t$company),
      phonenum = rp_char1(t$phonenum),
      extra_variables = as.list(ev)
    )
  }

  ctx <- report_context(result_path,
    species = rp_char1(sp$species),
    project = rp_char1(sp$project),
    code = rp_char1(sp$code),
    type = rp_char1(sp$type) %||% "1",
    caption_lang = rp_char1(sp$caption_lang) %||% "en",
    ref_version = rp_char1(sp$ref_version),
    logo = rp_char1(sp$logo) %||% "blank")

  ## citations shown in the references layer: all keys cited anywhere in
  ## the spec narrative (only when references.only_cited is TRUE)
  only_keys <- NULL
  if (isTRUE(sp$references$only_cited)) {
    spec_text <- paste(unlist(sp$layers), collapse = " ")
    markers <- regmatches(spec_text,
      gregexpr("\\[@[^\\]]+\\]", spec_text, perl = TRUE))[[1L]]
    if (length(markers) > 0L) {
      keys <- trimws(unlist(strsplit(gsub("\\[@|\\]", "", markers),
        "[;,；，]")))
      keys <- sub("^@", "", keys)
      only_keys <- unique(keys[nzchar(keys)])
    }
  }

  report <- create_report(ctx)
  report <- do.call(add_module, c(list(report = report),
    lapply(sp$layers, function(l) spec_layer_module(l, sp))))
  if (!is.null(bib_path) && file.exists(bib_path)) {
    report <- add_module(report,
      mod_references(bib_file = bib_path, only_keys = only_keys))
  }
  render_report(report, output = output, theme = th,
    standalone = standalone,
    title = title %||% rp_char1(sp$title) %||% "Analysis Report",
    quiet = quiet, engine = engine %||% rp_char1(sp$engine))
}
