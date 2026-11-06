#' Command-line interface
#'
#' Parameterized entry point mirroring the legacy `Report.R` scripts
#' (species/project/code/result/outhtml/type/logo/company/phonenum) so a
#' pipeline can switch by replacing one Rscript invocation. Designed to
#' be called from the bundled template `inst/templates/run_report.R`
#' via `Rscript`.
#'
#' Exit-code semantics (fixing the legacy defect where errors were
#' swallowed and the run still reported success): render completes
#' with zero failed modules → status 0; any module failed → status 1;
#' fatal (bad arguments, no module rendered) → status 2 with an error
#' message on stderr.
#'
#' @param args character vector. Defaults to
#'   [commandArgs(trailingOnly = TRUE)].
#' @param do_quit logical(1). Actually quit the R process with the
#'   resulting status (default TRUE when running as a script); FALSE
#'   returns the render result for testing.
#' @return Invisibly, the [render_report()] result (when
#'   `do_quit = FALSE`).
#' @seealso [run_report_template()], [chip_report_modules()]
#' @export
report_cli <- function(args = commandArgs(trailingOnly = TRUE),
                       do_quit = TRUE) {
  option_list <- list(
    optparse::make_option(c("-S", "--species"), type = "character",
      default = "Homo_sapiens",
      help = "Species key, e.g. Homo_sapiens / Mus_musculus"),
    optparse::make_option(c("-P", "--project"), type = "character",
      default = NA_character_,
      help = "Project name"),
    optparse::make_option(c("-C", "--code"), type = "character",
      default = NA_character_, help = "Project code / order number"),
    optparse::make_option(c("-R", "--result"), type = "character",
      default = NULL,
      help = "Analysis result directory to scan"),
    optparse::make_option(c("-O", "--outhtml"), type = "character",
      default = "report", help = "Output html path (no extension needed)"),
    optparse::make_option(c("-T", "--type"), type = "character",
      default = "1",
      help = "Branch type: 1 = with replicate/diff groups, 0 = single group"),
    optparse::make_option(c("--logo"), type = "character", default = "smzy",
      help = "Brand preset: smzy / jinyu / blank / default"),
    optparse::make_option(c("--company"), type = "character", default = "",
      help = "Company name (overrides the brand preset)"),
    optparse::make_option(c("--phonenum"), type = "character", default = "",
      help = "Service phone (overrides the brand preset)"),
    optparse::make_option(c("--modules"), type = "character", default = "chip",
      help = "Module set: chip | m6a"),
    optparse::make_option(c("--style"), type = "character", default = "classic",
      help = "Visual style: classic | v2 | card"),
    optparse::make_option(c("--engine"), type = "character", default = "reactable",
      help = "Table rendering engine: reactable | lite"),
    optparse::make_option(c("--title"), type = "character", default = NA_character_,
      help = "Report title (default: '<project> analysis report')"),
    optparse::make_option(c("--lang"), type = "character", default = "en",
      help = "Caption language: en | zh"),
    optparse::make_option(c("--no-standalone"), dest = "no_standalone",
      action = "store_true", default = FALSE,
      help = "Write multi-file output instead of a single html"),
    optparse::make_option(c("-q", "--quiet"), action = "store_true",
      default = FALSE, help = "Suppress progress messages")
  )
  parser <- optparse::OptionParser(
    option_list = option_list,
    prog = "Rscript run_report.R",
    usage = "Rscript run_report.R [options]"
  )
  opt <- optparse::parse_args(parser, args = args,
    positional_arguments = FALSE)

  status <- tryCatch(
    {
      if (is.null(opt$result)) {
        stop("--result is required; see --help", call. = FALSE)
      }
      ctx <- report_context(
        result_path = opt$result,
        species = opt$species,
        project = opt$project,
        code = opt$code,
        company = opt$company,
        phonenum = opt$phonenum,
        logo = opt$logo,
        type = opt$type,
        caption_lang = match.arg(opt$lang, c("en", "zh"))
      )
      modules <- switch(opt$modules,
        chip = chip_report_modules(),
        m6a = m6a_report_modules(),
        atac = atac_report_modules(),
        stop("unknown module set: ", opt$modules,
             " (expected 'chip' | 'm6a' | 'atac')", call. = FALSE)
      )
      report <- create_report(ctx)
      report <- do.call(add_module, c(list(report = report), modules))
      out <- opt$outhtml
      if (!grepl("\\.html$", out)) out <- paste0(out, ".html")
      title <- if (is.na(opt$title) || !nzchar(opt$title)) {
        paste0(opt$project %||% "Analysis", " analysis report")
      } else opt$title
      res <- render_report(
        report, output = out,
        theme = reporter_theme(
          preset = opt$logo, company = opt$company, phonenum = opt$phonenum,
          style = match.arg(opt$style, c("classic", "v2")),
          caption_lang = match.arg(opt$lang, c("en", "zh"))),
        standalone = !isTRUE(opt$no_standalone),
        title = title,
        quiet = opt$quiet,
        engine = match.arg(opt$engine, c("reactable", "lite"))
      )
      if (length(res$errors) > 0L) 1L else 0L
    },
    error = function(e) {
      message("reporter: FATAL - ", conditionMessage(e))
      2L
    }
  )

  if (isTRUE(do_quit)) {
    quit(status = status)
  }
  invisible(status)
}

#' Path of the bundled CLI template
#'
#' Returns the location of `inst/templates/run_report.R` so pipelines
#' can copy or invoke it directly.
#'
#' @return character(1) absolute file path.
#' @export
run_report_template <- function() {
  system.file("templates", "run_report.R", package = "reporter")
}
