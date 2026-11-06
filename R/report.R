#' Define a report module
#'
#' A module is the unit of report composition: a plain function that
#' receives the report context and returns a [htmltools::tagList()].
#' Modules declare their prerequisites declaratively — `required_dirs`
#' (sub-directories of the result directory that must exist) and an
#' optional `when` predicate — and the framework decides at render time
#' whether a module applies, wraps it in a numbered section, registers
#' its subsections in the TOC and converts any error into an in-report
#' placeholder instead of aborting the whole report.
#'
#' @param id character(1). Short unique module identifier (slug), used
#'   for the anchor id `mod-<id>` and the TOC.
#' @param title character(1). Human-readable module title.
#' @param render function(ctx). The module body; must return a
#'   [htmltools::tagList()] or tag object.
#' @param required_dirs character vector. Sub-directories (relative to
#'   the context `result_path`) that must all exist for the module to be
#'   enabled. Replaces the legacy `res_tree_dt` directory probing.
#' @param when function(ctx) or `NULL`. Extra predicate; the module is
#'   rendered only when it evaluates to `TRUE`.
#' @return An object of class `reporter_module`.
#' @seealso [create_report()], [render_report()]
#' @export
#'
#' @examples
#' mod_intro <- module(
#'   id = "intro", title = "Project Overview",
#'   render = function(ctx) {
#'     ctx$subsection("Project information")
#'     ctx$note("This module is a minimal example.")
#'   }
#' )
module <- function(id, title, render,
                   required_dirs = character(0),
                   when = NULL) {
  rp_check_chr(id, 1L, allow_null = FALSE, arg = "id")
  rp_check_chr(title, 1L, allow_null = FALSE, arg = "title")
  if (!is.function(render)) {
    stop("`render` must be a function(ctx) returning a tagList", call. = FALSE)
  }
  if (length(required_dirs)) {
    rp_check_chr(required_dirs, length(required_dirs),
      allow_null = FALSE, arg = "required_dirs"
    )
  }
  structure(
    list(
      id = id,
      title = title,
      render = render,
      required_dirs = if (is.null(required_dirs)) character(0) else required_dirs,
      when = when
    ),
    class = "reporter_module"
  )
}

#' @export
print.reporter_module <- function(x, ...) {
  cat("<reporter_module> '", x$id, "': ", x$title, "\n", sep = "")
  if (length(x$required_dirs)) {
    cat("  requires:", paste(x$required_dirs, collapse = ", "), "\n")
  }
  invisible(x)
}

#' Create a report from a context
#'
#' Instantiates the composition object holding the context and the
#' (initially empty) module registry.
#'
#' @param ctx A `reporter_ctx` from [report_context()].
#' @return An object of class `reporter_report`.
#' @seealso [report_context()], [add_module()]
#' @export
create_report <- function(ctx) {
  if (!inherits(ctx, "reporter_ctx")) {
    stop("`ctx` must be created by reporter::report_context()", call. = FALSE)
  }
  structure(
    list(ctx = ctx, modules = list()),
    class = "reporter_report"
  )
}

#' @export
print.reporter_report <- function(x, ...) {
  cat("<reporter_report> with", length(x$modules), "module(s)\n")
  invisible(x)
}

#' Add modules to a report
#'
#' Appends one or more [module()] definitions to a report. Bare
#' functions are also accepted and wrapped automatically (id derived
#' from the function name); prefer [module()] for proper titles.
#'
#' @param report A `reporter_report` from [create_report()].
#' @param ... Objects of class `reporter_module`, or bare
#'   `function(ctx)`s.
#' @return The modified `report` (invisibly), enabling pipe chains via
#'   `|>`.
#' @seealso [module()]
#' @export
#'
#' @examples
#' ctx <- report_context(tempdir())
#' mod <- module("intro", "Introduction", function(ctx) ctx$note("hi"))
#' report <- create_report(ctx) |> add_module(mod)
add_module <- function(report, ...) {
  if (!inherits(report, "reporter_report")) {
    stop("`report` must be created by reporter::create_report()", call. = FALSE)
  }
  mods <- list(...)
  for (m in mods) {
    if (inherits(m, "reporter_module")) {
      report$modules[[length(report$modules) + 1L]] <- m
    } else if (is.function(m)) {
      nm <- tryCatch(
        deparse(substitute(m))[[1L]],
        error = function(e) "module"
      )
      report$modules[[length(report$modules) + 1L]] <- module(
        id = rp_slug(nm, prefix = "mod-"), title = nm, render = m
      )
    } else {
      stop("reporter: add_module expects module() objects or functions, got: ",
           class(m)[1L], call. = FALSE)
    }
  }
  invisible(report)
}

#' Internal: decide whether a module applies
#'
#' @param mod A `reporter_module`.
#' @param ctx A `reporter_ctx`.
#' @return character(1) `NA` when the module applies, otherwise a reason
#'   string ("missing directories ..." or "when() returned FALSE").
#' @noRd
rp_module_skip_reason <- function(mod, ctx) {
  if (length(mod$required_dirs)) {
    missing <- mod$required_dirs[!vapply(mod$required_dirs, function(d) {
      dir.exists(file.path(ctx$meta$result_path, d))
    }, logical(1L))]
    if (length(missing)) {
      return(paste0("missing directories: ", paste(missing, collapse = ", ")))
    }
  }
  if (is.function(mod$when)) {
    ok <- tryCatch(isTRUE(mod$when(ctx)), error = function(e) FALSE)
    if (!ok) return("when() predicate returned FALSE")
  }
  NA_character_
}




#' Render a report
#'
#' Executes all applicable modules against the report context and
#' writes the final HTML report to disk.
#'
#' @details
#' Pipeline per module: directory/predicate gating → isolated
#' [tryCatch()] evaluation → success (content) or failure (in-report
#' danger callout, error recorded). Afterwards the page skeleton is
#' assembled (navbar, sidebar TOC, cover, sections, footer), saved via
#' [htmltools::save_html()] and — when `standalone = TRUE` — collapsed
#' into a **single self-contained HTML file** by [inline_html()]: every
#' stylesheet/script is inlined and all images were already base64
#' encoded at creation time. With `standalone = FALSE` the report is
#' written as `output` plus a `report_assets/` directory.
#'
#' Failures never silently vanish: the return value carries `$errors`
#' and `$skipped`, and the CLI layer exits non-zero when a module failed
#' (fixing a legacy defect where errors were swallowed).
#'
#' @param report A `reporter_report` from [create_report()].
#' @param output character(1). Output HTML path.
#' @param theme A `reporter_theme` from [reporter_theme()]; when
#'   missing, derived from the context (`logo`, `company`, `phonenum`).
#' @param standalone logical(1). Single-file output (default) vs
#'   multi-file (HTML + assets directory).
#' @param title character(1). Report title; defaults to
#'   `"<project> Analysis Report"`.
#' @param only character vector. Optional subset of module ids to render
#'   — the debugging fast path ("only render the module I am working
#'   on").
#' @param quiet logical(1). Suppress progress messages.
#' @param render_only_missing logical(1). (Reserved, ignored.)
#' @return Invisibly, a list with elements `output`, `errors` (list of
#'   `list(id, title, message)`), `skipped` (list of
#'   `list(id, reason)`), `modules` (rendered module ids) and `size`
#'   (output file size in bytes), of class `reporter_render`.
#' @seealso [create_report()], [module()], [inline_html()]
#' @export
#'
#' @examples
#' \donttest{
#' ctx <- report_context(tempdir(), project = "Demo")
#' report <- create_report(ctx) |>
#'   add_module(module("intro", "Introduction",
#'     function(ctx) ctx$note("Hello report")))
#' out <- tempfile(fileext = ".html")
#' res <- render_report(report, output = out, title = "Demo Report")
#' if (file.exists(out)) message("rendered: ", res$output)
#' }
render_report <- function(report, output = "report.html",
                          theme = NULL, standalone = TRUE,
                          title = NULL, only = NULL, quiet = FALSE, json_sidecar = FALSE) {
  if (!inherits(report, "reporter_report")) {
    stop("`report` must be created by reporter::create_report()", call. = FALSE)
  }
  ctx <- report$ctx
  output <- rp_char1(output)
  if (is.null(output)) {
    stop("`output` must be a non-empty file path", call. = FALSE)
  }
  if (!is.null(only)) {
    only <- only[!is.na(only) & nzchar(only)]
  }
  if (!is.null(only) && length(only)) {
    keep <- vapply(report$modules, function(m) m$id %in% only, logical(1L))
    report$modules <- report$modules[keep]
    if (!any(keep)) {
      stop("reporter: no module matched `only` (available: ",
        paste(vapply(report$modules, function(m) m$id, character(1L)),
          collapse = ", "),
        ")", call. = FALSE
      )
    }
  } else {
    only <- NULL
  }

  default_preset <- if (ctx$meta$logo %in% c("smzy", "jinyu", "blank", "default")) {
    ctx$meta$logo
  } else {
    "default"
  }
  theme <- theme %||% reporter_theme(
    preset = default_preset,
    company = ctx$meta$company,
    phonenum = ctx$meta$phonenum
  )
  if (!inherits(theme, "reporter_theme")) {
    stop("`theme` must be created by reporter::reporter_theme()", call. = FALSE)
  }
  ## context caption language wins when explicitly set at theme level too
  if (!identical(ctx$meta$caption_lang, theme$caption_lang)) {
    ctx$meta$caption_lang <- theme$caption_lang
  }

  title <- title %||% paste(
    trimws(ifelse(is.na(ctx$meta$project), "", ctx$meta$project)),
    "Analysis Report"
  )

  errors <- list()
  skipped <- list()
  rendered <- list()

  for (mod in report$modules) {
    reason <- rp_module_skip_reason(mod, ctx)
    if (!is.na(reason)) {
      if (!quiet) message("reporter: skip module '", mod$id, "' (", reason, ")")
      skipped[[length(skipped) + 1L]] <- list(id = mod$id, reason = reason)
      next
    }
    ctx$.rp_set_module(paste0("mod-", mod$id))
    content <- tryCatch(
      {
        out <- mod$render(ctx)
        if (is.null(out)) tagList() else out
      },
      error = function(e) {
        errors[[length(errors) + 1L]] <<- list(
          id = mod$id, title = mod$title, message = conditionMessage(e)
        )
        NULL
      }
    )
    if (is.null(content)) {
      content <- rp_error_block(
        mod$title,
        errors[[length(errors)]]$message
      )
    }
    rendered[[length(rendered) + 1L]] <- list(
      id = paste0("mod-", mod$id), title = mod$title, content = content
    )
    if (!quiet) message("reporter: rendered module '", mod$id, "'")
  }



  if (length(rendered) == 0L) {
    stop("reporter: no module was rendered — nothing to write", call. = FALSE)
  }

  cited_bib <- NULL
  ## ---- citations: superscripts + cited-only reference list ----------
  bib_file <- ctx$.rp_bib_file
  if (!is.null(bib_file) && file.exists(bib_file)) {
    htmls <- lapply(rendered, function(r) {
      paste(as.character(r$content), collapse = "\n")
    })
    spec_text <- paste(unlist(htmls), collapse = " ")
    markers <- regmatches(spec_text,
      gregexpr("\\[@[^\\]]+\\]", spec_text, perl = TRUE))[[1L]]
    cited_keys <- character(0L)
    if (length(markers) > 0L) {
      keys <- trimws(unlist(strsplit(
        gsub("\\[@|\\]", "", markers), "[;,；，]")))
      keys <- sub("^@", "", keys)
      cited_keys <- unique(keys[nzchar(keys)])
    }
    bib <- read_bib(bib_file)
    if (!is.null(bib) && length(cited_keys)) {
      keep <- bib$key %in% cited_keys
      if (any(keep)) bib <- bib[keep, , drop = FALSE]   # cited-only view
      cited_bib <- bib
    }
    if (!is.null(bib) && nrow(bib) > 0L) {
      keymap <- stats::setNames(seq_len(nrow(bib)), as.character(bib$key))
      htmls <- lapply(htmls, function(h) citations(h, keymap))
      if (length(cited_keys)) {
        ## rebuild the references list from the cited subset so the
        ## numbering matches the superscripts exactly
        new_ol <- as.character(reference_list(bib))
        i_refs <- which(vapply(htmls, function(h) {
          grepl('<ol class="rp-refs">', h, fixed = TRUE)
        }, logical(1L)))
        for (i in i_refs) {
          htmls[[i]] <- rp_replace_matches(htmls[[i]],
            '<ol class="rp-refs">[\\s\\S]*?</ol>',
            function(m) new_ol, perl = TRUE)
        }
      }
      for (i in seq_along(rendered)) {
        rendered[[i]]$content <- HTML(htmls[i][[1L]])
      }
    }
  }
  ## ---- machine-readable schema (P2) ---------------------------------
  ## index layer only: meta/module list/figure & table registry
  ## entries/cited references. Cell data and image pixels are NEVER
  ## embedded here.
  schema <- list(
    `schema` = "reporter/1.0",
    meta = list(
      title = title,
      project = ctx$meta$project,
      code = ctx$meta$code,
      species = ctx$meta$species,
      ref_version = ctx$meta$ref_version,
      type = ctx$meta$type,
      engine = "reactable",
      generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      reporter_version = as.character(utils::packageVersion("reporter"))
    ),
    modules = lapply(seq_along(rendered), function(i) {
      list(id = rendered[[i]]$id, title = rendered[[i]]$title, order = i)
    }),
    figures = ctx$.rp_schema_entries()$figures,
    tables = ctx$.rp_schema_entries()$tables,
    data_root = ctx$meta$result_path
  )
  if (!is.null(cited_bib) && nrow(cited_bib) > 0L) {
    schema$citations <- lapply(seq_len(nrow(cited_bib)), function(i) {
      list(key = as.character(cited_bib$key[i]), number = i,
           doi = if (is.na(cited_bib$doi[i])) "" else
             as.character(cited_bib$doi[i]))
    })
  }
  schema_json <- jsonlite::toJSON(schema, auto_unbox = TRUE,
    null = "null", na = "null")

  toc_entries <- ctx$.rp_toc_entries()
  toc_groups <- lapply(rendered, function(r) {
    secs <- toc_entries[vapply(toc_entries, function(e) {
      identical(e$module, r$id) && e$level == 3L
    }, logical(1L))]
    list(id = r$id, title = r$title,
         sections = lapply(secs, function(e) list(id = e$id, title = e$title)))
  })

  module_links <- lapply(rendered, function(r) list(id = r$id, title = r$title))
  navbar <- rp_navbar(title, ctx$meta, theme$brand, module_links)
  toc <- rp_toc(toc_groups)
  content <- tagList(lapply(rendered, function(r) {
    rp_module_section(r$id, r$title, r$content)
  }))
  footer <- rp_footer(ctx$meta, theme$brand, theme, length(errors))
  page <- rp_page(title, navbar, toc, content, footer, theme, schema_json = schema_json)

  ## ---- write --------------------------------------------------------
  output <- as.character(output)[1L]
  out_dir <- dirname(output)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  if (isTRUE(standalone)) {
    tmp_dir <- file.path(tempdir(), paste0("reporter-", digest_like(Sys.time())))
    dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
    tmp_html <- file.path(tmp_dir, "index.html")
    htmltools::save_html(page, tmp_html, libdir = "lib", background = "white")
    inline_html(tmp_html, output, libdir = file.path(tmp_dir, "lib"))
    unlink(tmp_dir, recursive = TRUE)
  } else {
    assets_name <- "report_assets"
    htmltools::save_html(page, output, libdir = assets_name, background = "white")
  }
  if (isTRUE(json_sidecar)) {
    sidecar <- sub("\\.html$", ".json", output)
    writeLines(jsonlite::toJSON(schema, pretty = TRUE, auto_unbox = TRUE,
      null = "null", na = "null"), sidecar, useBytes = TRUE)
  }

  if (!quiet) {
    message("reporter: report written: ", normalizePath(output),
            " (", round(file.size(output) / 1024 / 1024, 1), " MB)")
  }

  structure(
    list(
      output = normalizePath(output),
      errors = errors,
      skipped = skipped,
      modules = vapply(rendered, function(r) r$id, character(1L)),
      counters = ctx$.rp_counters(),
      size = file.size(output)
    ),
    class = "reporter_render"
  )
}

#' @export
print.reporter_render <- function(x, ...) {
  cat("<reporter_render> ", x$output, "\n", sep = "")
  cat("  modules:", length(x$modules), " errors:", length(x$errors),
      " skipped:", length(x$skipped), "\n")
  cat("  figures:", x$counters[["fig"]], " tables:", x$counters[["tbl"]], "\n")
  cat("  size:", round(x$size / 1024 / 1024, 2), "MB\n")
  invisible(x)
}
