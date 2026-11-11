# --------------------------------------------------------------------------
# brandkit: brand_quarto.R
# Quarto integration: render-time setup + project scaffolding.
# --------------------------------------------------------------------------

#' Set Up brandkit for Quarto Rendering
#'
#' Call this in your Quarto document's setup chunk. It sets the ggplot2
#' theme, default scales, and knitr device background to match the
#' brand and mode. This replaces the need for any per-plot theming.
#'
#' @param mode `"light"` (default) or `"dark"`. Match this to your
#'   document's `brand-mode` setting.
#' @param transparent Logical. `TRUE` (default) draws plots on a
#'   transparent background, so they take on the colour of whatever they
#'   sit on (the page, a poster card); `FALSE` fills them with the brand's
#'   background colour. Applies to the ggplot2 theme and to the knitr
#'   device, which is what base graphics are drawn on.
#' @param adaptive Logical. Set `TRUE` in an HTML document with a light/dark
#'   toggle to make its plots follow the toggle. Every figure is then drawn
#'   twice, once per colour mode, and the page shows the one that matches;
#'   [brand_plotly()] does the same with a widget for each. Nothing in the
#'   document's chunks changes. The cost is a second render of every plot
#'   chunk, and the dark files must stay beside the page, so it does not
#'   work with `embed-resources: true`. The document's own `mode` is then
#'   always light. Default `FALSE`.
#' @param shiny Logical. Set `TRUE` in a document with `server: shiny`
#'   (such as the [create_brand_quarto_dashboard()] dashboard). Plots are
#'   then drawn by Shiny, live, so they can follow the page's light/dark
#'   toggle: this switches on thematic, which gives each `renderPlot()` the
#'   colours, fonts and background of the card it sits on, redrawn when the
#'   mode changes, and discrete colour and fill scales take the brand's
#'   light or dark palette to match. `mode` and `transparent` no longer matter then; the page
#'   decides. Default `FALSE`.
#'
#' @return Invisible `NULL`. Called for side effects.
#'
#' @examples
#' \dontrun{
#' # In a Quarto setup chunk:
#' library(brandkit)
#' brand_quarto_setup()           # light mode (default)
#' brand_quarto_setup("dark")     # for brand-mode: dark documents
#' brand_quarto_setup(adaptive = TRUE) # HTML pages with a dark-mode toggle
#' brand_quarto_setup(shiny = TRUE) # server: shiny documents
#' }
#'
#' @export
brand_quarto_setup <- function(mode = c("light", "dark"), transparent = TRUE,
                               adaptive = FALSE, shiny = FALSE) {
  mode <- match.arg(mode)
  if (isTRUE(adaptive)) mode <- "light"
  ensure_cache()

  cols <- brand_colors(mode)

  # Store active mode so brand_plotly() auto-detects
  brand_env$active_mode <- mode
  brand_env$transparent <- transparent
  brand_env$adaptive    <- FALSE

  # Set ggplot2 theme for this mode
  ggplot2::theme_set(theme_brand(mode = mode, transparent = transparent))

  # Set default discrete scales
  pal <- brand_pal_discrete(mode = mode)
  options(
    ggplot2.discrete.colour = pal,
    ggplot2.discrete.fill   = pal
  )

  # Live plots are drawn by Shiny's own devices, not knitr's, so the device
  # background and par() hook below have nothing to act on. Worse, the par()
  # hook opens a device at render time, where thematic has no output to read
  # colours from and warns.
  if (isTRUE(shiny)) {
    activate_thematic_shiny(mode)
    return(invisible(NULL))
  }

  # Set the knitr device background. It has to be set explicitly either
  # way: left alone the device paints white, which bleeds through the
  # plot margins as a pale frame. Transparent hands the margins to the
  # container; otherwise they are painted the brand background. Also
  # register a hook to set base R par() colours before each chunk so
  # barplot, hist, etc. follow the brand.
  if (requireNamespace("knitr", quietly = TRUE)) {
    knitr::opts_chunk$set(
      dev.args = list(bg = if (isTRUE(transparent)) "transparent" else cols$background)
    )

    # Hook sets par() before each chunk's graphics device. The colour is
    # read when the hook runs rather than when it is registered, so a chunk
    # drawn for the other mode (see `adaptive`) gets that mode's text colour.
    knitr::knit_hooks$set(brandkit_par = function(before, options, envir) {
      if (before) {
        fg <- brand_colors(brand_env$active_mode %||% "light")$foreground
        par(
          col.main = fg, col.sub = fg, col.lab = fg,
          col.axis = fg, fg = fg
        )
      }
    })
    knitr::opts_chunk$set(brandkit_par = TRUE)
  }

  if (isTRUE(adaptive)) setup_adaptive()

  invisible(NULL)
}


#' Set Up a Quarto HTML Project
#'
#' Copies `_brand.yml`, the "drift" stylesheet and an example HTML report
#' into a Quarto project directory. After running this, Quarto
#' auto-detects `_brand.yml` and applies it to HTML formats. The report is
#' in the same "drift" look as the poster ([create_brand_quarto_poster()]),
#' the print PDF ([create_brand_quarto_print_pdf()]) and the Shiny starter
#' app: the title as plain type with the logo above it, soft corner
#' ornaments behind the page, and tables that follow the brand, all drawn
#' from `_brand.yml` and following the light/dark toggle.
#'
#' For a revealjs slide deck, see [create_brand_quarto_slides()]. For a
#' PDF starting point rendered via Quarto's Typst engine, see
#' [create_brand_quarto_pdf()] and [create_brand_quarto_print_pdf()].
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param examples Logical. Copy the example `report.qmd`? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`drift.scss`}{The look, built from the brand's own Sass
#'     variables and compiled once per colour mode. It is divided into
#'     shared rules (tables), document rules (the masthead, headings and
#'     footer of a report) and dashboard rules, which a report simply never
#'     matches. Layered after brand in the Quarto theme.}
#'   \item{`_ornaments.html`}{The two corner ornaments
#'     ([brand_ornaments_tag()]), included after the page body. They are
#'     filled with the page's CSS colour variables rather than the brand's
#'     hex values, so the file never goes stale when the brand changes and
#'     follows the dark-mode toggle.}
#'   \item{`report.qmd`}{Sample HTML report on R's built-in `airquality`
#'     data (if `examples = TRUE`), whose masthead and footer divs pull
#'     title/subtitle/author/date from the YAML header via
#'     `\{\{< meta ... >\}\}`.}
#' }
#'
#' In your `.qmd` YAML header, reference the files like this:
#' ```yaml
#' format:
#'   html:
#'     theme:
#'       light: [brand, drift.scss]
#'       dark: [brand, drift.scss]
#'     include-after-body: _ornaments.html
#' ```
#'
#' The nested `light:`/`dark:` form is what gives readers a working
#' light/dark toggle — Quarto compiles a Bootstrap stylesheet per mode
#' from `_brand.yml`'s `color:`/`color-dark:` entries and the toggle swaps
#' between them. The flat `theme: [brand, drift.scss]` form still shows
#' a toggle but only switches syntax highlighting, leaving the Bootstrap
#' layer light. Plots are static images baked in at render time, so on
#' their own they would not follow the toggle; `report.qmd` calls
#' `brand_quarto_setup(adaptive = TRUE)`, which draws each figure in both
#' modes and shows the one that matches (see [brand_quarto_setup()]).
#'
#' For ggplot2 theming, just add `library(brandkit)` in a setup chunk —
#' the auto-applied theme and scales handle the rest.
#'
#' If `path` already has a `_brand.yml` in the Shiny/bslib format (with
#' `color-dark:`/`theme:` keys — what [configure_brand()] writes unless
#' its output-format toggle is set to Quarto), it is converted to the
#' Quarto-compatible format regardless of `overwrite` —
#' Quarto's own renderer rejects those bslib-only keys outright, so a
#' leftover bslib-format file always needs fixing. An already
#' Quarto-compatible `_brand.yml` is left alone unless `overwrite = TRUE`.
#'
#' If the cached brand references a logo whose file can't actually be
#' found (e.g. a stale cache pointing at a different project), the
#' `logo:` section is omitted from the written `_brand.yml` rather than
#' pointing at a file that will never be copied.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @export
create_brand_quarto_html <- function(path = ".", examples = TRUE, overwrite = FALSE) {

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- drift.scss + the corner ornaments ---
  copied <- c(copied, copy_drift_assets(path, overwrite))

  # --- Example report ---
  if (examples) {
    copied <- c(copied, copy_template(
      "quarto/report.qmd", file.path(path, "report.qmd"), overwrite
    ))
  }

  copy_brand_assets(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  theme: [brand, drift.scss]')
  message('Then add library(brandkit) in a setup chunk for ggplot2 theming.')

  invisible(copied)
}


#' Set Up a Quarto Revealjs Slides Project
#'
#' Copies `_brand.yml`, the "drift" stylesheet and an example revealjs
#' presentation into a Quarto project directory. After running this,
#' Quarto auto-detects `_brand.yml` and applies it to the revealjs
#' format. The deck is in the same "drift" look as the poster
#' ([create_brand_quarto_poster()]), the HTML report
#' ([create_brand_quarto_html()]) and the Shiny starter app: a plain,
#' left-aligned title slide with no panel, headings in the brand's primary
#' colour, and soft corner ornaments behind every slide.
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param examples Logical. Copy the example `slides.qmd`? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`drift.scss`}{The look, layered after brand in the Quarto
#'     theme. It is the same file the HTML report and dashboard use; the
#'     slide rules are its Slides section.}
#'   \item{`_ornaments.html`}{The two corner ornaments
#'     ([brand_ornaments_tag()]), included after the slides with
#'     `include-after-body:`. They are drawn in the brand colours of the
#'     deck's mode, so a `brand-mode: dark` deck gets the dark ones.}
#'   \item{`slides.qmd`}{Sample revealjs presentation on R's built-in
#'     `airquality` data (if `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, reference the files like this:
#' ```yaml
#' format:
#'   revealjs:
#'     theme: [brand, drift.scss]
#'     include-after-body: _ornaments.html
#'     logo: medium
#' ```
#'
#' For dark mode slides, add `brand-mode: dark` and call
#' `brand_quarto_setup("dark")` in the setup chunk. For plotly in slides,
#' always pass fixed dimensions: `brand_plotly(p, width = 1000, height = 600)`.
#'
#' If `path` already has a `_brand.yml` in the Shiny/bslib format (with
#' `color-dark:`/`theme:` keys — what [configure_brand()] writes unless
#' its output-format toggle is set to Quarto), it is converted to the
#' Quarto-compatible format regardless of `overwrite` —
#' Quarto's own renderer rejects those bslib-only keys outright, so a
#' leftover bslib-format file always needs fixing. An already
#' Quarto-compatible `_brand.yml` is left alone unless `overwrite = TRUE`.
#'
#' If the cached brand references a logo whose file can't actually be
#' found (e.g. a stale cache pointing at a different project), the
#' `logo:` section is omitted from the written `_brand.yml` rather than
#' pointing at a file that will never be copied.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @export
create_brand_quarto_slides <- function(path = ".", examples = TRUE, overwrite = FALSE) {

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- drift.scss + the corner ornaments ---
  copied <- c(copied, copy_drift_assets(path, overwrite))

  # --- Example slides ---
  if (examples) {
    # Drop the `logo: medium` line entirely when no logo is configured
    # — left in place, revealjs still tries to render a logo image
    # that doesn't exist, showing a broken-image icon in its corner
    # instead of just omitting it.
    no_logo <- function(lines) {
      if (length(brand_env$logo) > 0) return(lines)
      lines[!grepl("^\\s*logo:\\s*medium\\s*$", lines)]
    }
    copied <- c(copied, copy_template(
      "quarto/slides.qmd", file.path(path, "slides.qmd"), overwrite,
      transform = no_logo
    ))
  }

  copy_brand_assets(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  theme: [brand, drift.scss]')
  message('Then add library(brandkit) and brand_quarto_setup() in a setup chunk.')

  invisible(copied)
}


#' Set Up a Quarto Shiny Dashboard Project
#'
#' Copies `_brand.yml`, the "drift" stylesheet, and an example
#' `dashboard.qmd` into a Quarto project directory, configured to render
#' to Quarto's `dashboard` format with a Shiny runtime. The result is a
#' small dashboard of R's built-in `airquality` data (daily New York air
#' quality, 1973) — a row of value boxes over two charts and a table,
#' filtered by month and temperature in the sidebar — in the same "drift" look as the
#' poster ([create_brand_quarto_poster()]) and the Shiny starter app
#' ([create_brand_shiny_app()]): soft corner ornaments behind the page,
#' the title as plain type, and tinted cards under a solid header. It has
#' a light/dark toggle, which the plots follow.
#'
#' This is the Quarto counterpart to [create_brand_shiny_dashboard()].
#' The two produce a similar layout by different routes: this one lays
#' the dashboard out in Quarto markdown and takes its ggplot2 theming
#' from a single [brand_quarto_setup()] call, while the Shiny version
#' builds the same structure in `bslib` and takes its theming from
#' [brand_page_navbar()]. Prefer this one when the dashboard sits
#' alongside other Quarto documents; prefer the Shiny one when it needs
#' to grow into a full application.
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param examples Logical. Copy the example `dashboard.qmd`? Default
#'   `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand),
#'     in the Quarto-compatible format.}
#'   \item{`drift.scss`}{The look, about a hundred lines of Sass built
#'     from the brand's own variables. Quarto compiles it once per colour
#'     mode, so the same file serves light and dark. Edit it to retune the
#'     cards, the title or the sidebar.}
#'   \item{`_ornaments.html`}{The two corner ornaments
#'     ([brand_ornaments_tag()]), included after the page body. They are
#'     filled with the page's CSS colour variables rather than the brand's
#'     hex values, so the file never goes stale when the brand changes and
#'     follows the dark-mode toggle.}
#'   \item{`dashboard.qmd`}{Sample Shiny dashboard (if `examples = TRUE`).
#'     One chart is a static ggplot, the other an interactive
#'     [brand_plotly()] widget.}
#' }
#'
#' The dark-mode toggle comes from giving the document one theme per mode
#' (`theme: light: ... dark: ...`), which is how `dashboard.qmd` declares
#' it. Plots are drawn live by Shiny, so `brand_quarto_setup(shiny = TRUE)`
#' lets thematic redraw them in the card's colours when the mode changes. The
#' plotly chart follows it too: inside a Shiny render [brand_plotly()] reads
#' the card's background, so it needs no `mode`.
#'
#' The sample needs the \pkg{plotly} package. It is optional for brandkit,
#' so this function reports it if it is missing rather than leaving you to
#' hit the error when the dashboard starts.
#'
#' Because the document declares `server: shiny`, it is served rather than
#' rendered to a static file:
#' ```
#' quarto serve dashboard.qmd
#' ```
#' Rendering it with `quarto render` produces the supporting files but
#' not a runnable page — that needs a Shiny-capable server. This requires
#' Quarto >= 1.4 (the `dashboard` format) and the \pkg{shiny} package.
#'
#' If `path` already has a `_brand.yml` in the Shiny/bslib format (with
#' `color-dark:`/`theme:` keys — what [configure_brand()] writes unless
#' its output-format toggle is set to Quarto), it is converted to the
#' Quarto-compatible format regardless of `overwrite` — Quarto's own
#' renderer rejects those bslib-only keys outright, so a leftover
#' bslib-format file always needs fixing. An already Quarto-compatible
#' `_brand.yml` is left alone unless `overwrite = TRUE`.
#'
#' If the cached brand references a logo whose file can't actually be
#' found (e.g. a stale cache pointing at a different project), the
#' `logo:` section is omitted from the written `_brand.yml` rather than
#' pointing at a file that will never be copied.
#'
#' @return Invisibly returns a character vector of copied file paths.
#'
#' @examples
#' \dontrun{
#' create_brand_quarto_dashboard(path = "my-dashboard")
#' # then, in a terminal:  quarto serve my-dashboard/dashboard.qmd
#' }
#'
#' @export
create_brand_quarto_dashboard <- function(path = ".", examples = TRUE,
                                          overwrite = FALSE) {

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- drift.scss + the corner ornaments ---
  copied <- c(copied, copy_drift_assets(path, overwrite))

  # --- Example dashboard ---
  if (examples) {
    copied <- c(copied, copy_template(
      "quarto/dashboard.qmd", file.path(path, "dashboard.qmd"), overwrite
    ))
  }

  copy_brand_assets(path, overwrite)

  message("\nDone. Serve the dashboard with:")
  message("  quarto serve ", file.path(path, "dashboard.qmd"))

  invisible(copied)
}


#' Set Up a Quarto Typst PDF Project
#'
#' Copies `_brand.yml`, a branded Typst format extension, and an example
#' report into a Quarto project directory, configured to render to PDF
#' via Quarto's Typst engine. Quarto's own `_brand.yml` integration
#' already applies brand colours and fonts to headings, links, and body
#' text in Typst output — but not to code, so the `_extensions/brandkit/`
#' extension this function installs closes that gap: fenced code blocks
#' pick up the brand's configured monospace font, keep the syntax colours
#' of the highlighting theme, and sit in a box tinted with the brand's
#' primary colour (the same tint the HTML templates give code), and the
#' text size of blocks and inline code is matched to the surrounding body
#' text (Typst has no root-relative unit equivalent to CSS `rem`, so this
#' is resolved to an absolute length rather than left to compound). Inline
#' code spans stay in the body font, because a monospace face looks
#' oversized beside the text around it even at the same size, and get a
#' colour of their own — a blend of the brand's secondary accent and
#' foreground colour — so they stand out in running text. (A small pandoc
#' filter, `inline-code.lua`, sets them as plain text; the highlighter
#' otherwise gives inline code and fenced blocks the same element, which
#' no styling rule can tell apart.) The extension also layers a full-bleed title banner on top — a
#' diagonal-stripe field (Linux Mint wallpaper style, drawn as Typst
#' polygons, no image asset) that runs primary-coloured behind the
#' title/subtitle and switches to secondary-coloured stripes past an
#' angled seam — plus coloured headings, a coloured footer, and a
#' code-block corner radius matching the brand's configured
#' border-radius, none of which the default Typst article template
#' provides on its own.
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param examples Logical. Copy an example `.qmd` report? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`_extensions/brandkit/`}{A Quarto Typst format extension
#'     (`_extension.yml` generated with a brand-derived code-block radius
#'     and an absolute base font size; `template.typ`, `typst-template.typ`,
#'     `typst-show.typ`, `page.typ`, and Quarto's own supporting partials)
#'     that adds a full-bleed diagonal-stripe title banner (with the logo,
#'     if configured, placed inline in it), coloured headings, a coloured
#'     footer, and brand-matched code styling (the monospace font and a
#'     primary-tinted box for fenced blocks, the body font and a
#'     secondary/foreground colour blend for inline code, a body-matched
#'     size for both; `inline-code.lua` is the filter behind this) on top of
#'     Quarto's default Typst article template. When there's no title,
#'     the banner is skipped and the logo falls back to a plain
#'     page-corner mark instead.}
#'   \item{`report-pdf.qmd`}{Sample Typst PDF report (if `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, use the extension's format:
#' ```yaml
#' format:
#'   brandkit-typst:
#'     toc: true
#' ```
#'
#' Render with `quarto render report-pdf.qmd` to produce a PDF. Requires
#' Quarto >= 1.8 (brand.yml support for the Typst format); Quarto bundles
#' the Typst compiler itself, so no separate Typst installation is needed.
#'
#' If `path` already has a `_brand.yml` in the Shiny/bslib format (with
#' `color-dark:`/`theme:` keys — what [configure_brand()] writes unless
#' its output-format toggle is set to Quarto), it is converted to the
#' Quarto-compatible format regardless of `overwrite` —
#' Quarto's own renderer rejects those bslib-only keys outright, so a
#' leftover bslib-format file always needs fixing. An already
#' Quarto-compatible `_brand.yml` is left alone unless `overwrite = TRUE`.
#'
#' If the cached brand references a logo whose file can't actually be
#' found (e.g. a stale cache pointing at a different project), the
#' `logo:` section is omitted from the written `_brand.yml` rather than
#' pointing at a file that will never be copied.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @export
create_brand_quarto_pdf <- function(path = ".", examples = TRUE, overwrite = FALSE) {

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- _extensions/brandkit/ (Typst format extension) ---
  copied <- c(copied, copy_typst_extension(path, "brandkit",
                                           banner_inset = FALSE,
                                           overwrite = overwrite))

  # --- Example report ---
  if (examples) {
    copied <- c(copied, copy_template(
      "quarto/pdf-report.qmd", file.path(path, "report-pdf.qmd"), overwrite
    ))
  }

  copy_brand_assets(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  format: brandkit-typst')
  message('Then run `quarto render report-pdf.qmd` to produce a branded PDF.')

  invisible(copied)
}


# --------------------------------------------------------------------------
# Ensure a Quarto-compatible _brand.yml exists at path/_brand.yml.
#
# configure_brand() writes the bslib/Shiny format (color-dark:, theme:
# keys) unless told otherwise, and Quarto's own renderer schema rejects
# those outright. A plain existence check isn't enough here — a bslib file
# needs to be converted regardless of `overwrite`, or every render breaks
# with a "readAndValidateYamlFromFile" error from Quarto itself. Only an
# already-Quarto-compatible file is left alone unless overwrite = TRUE.
# --------------------------------------------------------------------------

write_brand_yml_for_quarto <- function(path, overwrite = FALSE) {
  brand_dest <- file.path(path, "_brand.yml")

  needs_conversion <- file.exists(brand_dest) &&
    !is_quarto_compatible_brand_yml(brand_dest)

  if (!file.exists(brand_dest) || overwrite || needs_conversion) {
    write_quarto_brand_yml(brand_dest)
    if (needs_conversion && !overwrite) {
      message(
        "Converted _brand.yml to Quarto-compatible format (it was in the ",
        "Shiny/bslib format \u2014 color-dark:/theme: \u2014 which Quarto's ",
        "renderer rejects)"
      )
    } else {
      message("Wrote _brand.yml (Quarto-compatible)")
    }
    return(brand_dest)
  }

  # A file that's already Quarto-compatible is otherwise left alone, but
  # one written before font styles/weights were declared still renders
  # without bold or italic faces in Typst. Patch just the
  # typography.fonts entries in place rather than regenerating from the
  # cache, so a project whose _brand.yml has been hand-edited since keeps
  # those edits.
  if (patch_brand_yml_font_faces(brand_dest)) {
    message(
      "Added explicit Google font styles/weights to _brand.yml \u2014 without ",
      "them Quarto fetches only the upright 400 face, so **bold** and ",
      "*italic* both render unstyled in Typst/PDF output"
    )
    return(brand_dest)
  }

  message(
    "_brand.yml already exists and is Quarto-compatible ",
    "(use overwrite = TRUE to regenerate)"
  )
  NULL
}

# Returns TRUE if the file was rewritten, FALSE if it already declared
# its faces (or has no typography to patch).
patch_brand_yml_font_faces <- function(path) {
  cfg <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
  if (is.null(cfg$typography)) return(FALSE)

  patched <- with_google_font_faces(cfg$typography)
  if (identical(patched, cfg$typography)) return(FALSE)

  cfg$typography <- patched
  yaml::write_yaml(cfg, path)
  TRUE
}

is_quarto_compatible_brand_yml <- function(path) {
  cfg <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
  if (is.null(cfg)) return(FALSE)
  is.null(cfg[["color-dark"]]) && is.null(cfg[["theme"]])
}


# --------------------------------------------------------------------------
# Convert a bslib-format brand config to the Quarto-compatible one.
# Drops bslib-only keys (theme:, color-dark:), folds dark colours into
# Quarto 1.8's nested light/dark format, and re-homes the theme: Bootstrap
# variables under defaults: bootstrap: defaults:, which is brand.yml's own
# (schema-valid) channel for the same Sass variables.
#
# `brand_dir` is the directory the resulting _brand.yml will live in — used
# to check that a referenced logo file actually exists there. `keep_logo`
# overrides that check for callers that know a logo is about to be written
# alongside (the configurator), and also suppresses the advisory message.
# --------------------------------------------------------------------------

quarto_brand_cfg <- function(cfg,
                             brand_dir = dirname(brand_env$path),
                             keep_logo = NULL) {
  dk  <- cfg[["color-dark"]]

  # Build Quarto-compatible color section
  # Quarto 1.8+ supports: primary: { light: "#x", dark: "#y" }
  qcolor <- list()
  for (k in brand_color_keys) {
    light_val <- cfg$color[[k]]
    dark_val  <- if (!is.null(dk)) dk[[k]] else NULL

    if (!is.null(light_val) && !is.null(dark_val)) {
      qcolor[[k]] <- list(light = light_val, dark = dark_val)
    } else if (!is.null(light_val)) {
      qcolor[[k]] <- light_val
    }
  }

  # Preserve palette if present
  if (!is.null(cfg$color$palette)) {
    qcolor$palette <- cfg$color$palette
  }

  # Build output structure — only Quarto-supported keys
  out <- list()
  if (!is.null(cfg$meta))       out$meta       <- cfg$meta
  out$logo <- convert_logo(cfg, brand_dir, keep_logo)
  if (length(qcolor))           out$color      <- qcolor
  # Normalised on the way out rather than trusted as-is: this is the one
  # chokepoint every Quarto-bound brand passes through, including files
  # written by hand or by an older brandkit, and a Google font entry
  # without weight: leaves Typst with no bold face at all.
  if (!is.null(cfg$typography)) out$typography  <- with_google_font_faces(cfg$typography)

  # theme: is bslib-only and rejected by Quarto's schema, but the very
  # same Bootstrap variables are legal under defaults: bootstrap:
  # defaults: — so carry them across rather than dropping them. This is
  # what keeps the configured border-radius reaching both Quarto's HTML
  # output and the Typst extension (see write_extension_yml_for_quarto()).
  bs_defaults <- cfg$theme %||% cfg$defaults$bootstrap$defaults
  if (length(bs_defaults)) {
    out$defaults <- list(bootstrap = list(defaults = bs_defaults))
  }

  out
}

write_quarto_brand_yml <- function(dest,
                                   cfg = brand_env$raw,
                                   brand_dir = dirname(brand_env$path),
                                   keep_logo = NULL) {
  yaml::write_yaml(quarto_brand_cfg(cfg, brand_dir, keep_logo), dest)
}


#' Set Up a Print-Friendly Quarto Typst PDF Project
#'
#' The "drift" sibling of [create_brand_quarto_pdf()], and the one to use
#' when the document will be printed. Everything about the two formats is
#' the same — the same code styling, coloured headings, coloured footer,
#' type ramp and brand integration, from the same shared template files —
#' except for how the title is drawn.
#'
#' [create_brand_quarto_pdf()] draws a diagonal-stripe banner full-bleed,
#' spanning the whole physical page width from the page background. That
#' looks right on screen but needs a printer that can bleed: on an
#' ordinary office or home printer the panel either clips at the
#' unprintable edge or leaves a white hairline frame around itself, and it
#' lays down a full page-width solid that can show through lighter stock.
#' This function instead opens with a plain masthead — the title in the
#' brand's primary colour, the subtitle beneath it, a short rule and the
#' author and date, with the logo on the right — and frames the first page
#' with the pair of soft corner ornaments the poster
#' ([create_brand_quarto_poster()]) and the HTML report
#' ([create_brand_quarto_html()]) use (see [brand_ornament()]). No ink
#' crosses the margin, there is no solid panel, and the ornaments are drawn
#' at a low opacity, so the header area uses a small fraction of the
#' striped banner's ink.
#'
#' Both formats install into separate extension directories and can
#' coexist in one project, so you can render the same document either
#' way by changing its `format:` key.
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param examples Logical. Copy an example `.qmd` report? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`_extensions/brandkit-print/`}{A Quarto Typst format extension
#'     contributing `brandkit-print-typst`. It installs the same template
#'     partials as [create_brand_quarto_pdf()]; its generated
#'     `_extension.yml` sets `drift`, which selects the plain masthead and
#'     the ornament background in `page.typ`, and `banner-inset`, which
#'     makes `typst-template.typ` emit the masthead into the flow. It also
#'     holds the two generated ornaments, `drift-top-right.svg` and
#'     `drift-bottom-left.svg`, which are drawn in the brand's colours at
#'     scaffold time — re-run with `overwrite = TRUE` after changing the
#'     brand.}
#'   \item{`report-print.qmd`}{Sample report on R's built-in `airquality`
#'     data (if `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, use the extension's format:
#' ```yaml
#' format:
#'   brandkit-print-typst:
#'     toc: false
#' ```
#'
#' The ornaments are drawn on the first page only: a title page framed and
#' the pages after it plain, which also keeps ink off pages that are all
#' text and figures. In `page.typ` it is a single `if` to repeat them on
#' every page. The running footer (rule, title and page number) likewise
#' starts on page two, so the title page is left clean.
#'
#' Because the masthead is flow content rather than a fixed-height page
#' background, it grows with its own content — a long title simply wraps
#' instead of being clipped.
#'
#' The no-title case: with no title there is no masthead, and no
#' ornaments either, so a logo falls back to a plain page-corner mark.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @seealso [create_brand_quarto_pdf()] for the full-bleed striped variant.
#' @export
create_brand_quarto_print_pdf <- function(path = ".", examples = TRUE,
                                          overwrite = FALSE) {

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- _extensions/brandkit-print/ (Typst format extension) ---
  copied <- c(copied, copy_typst_extension(path, "brandkit-print",
                                           banner_inset = TRUE,
                                           drift = TRUE,
                                           overwrite = overwrite))

  # --- Example report ---
  if (examples) {
    copied <- c(copied, copy_template(
      "quarto/print-report.qmd", file.path(path, "report-print.qmd"), overwrite
    ))
  }

  copy_brand_assets(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  format: brandkit-print-typst')
  message('Then run `quarto render report-print.qmd` to produce a branded PDF.')

  invisible(copied)
}


#' Set Up a Quarto Typst Conference Poster Project
#'
#' The poster sibling of [create_brand_quarto_pdf()]: a single landscape
#' sheet, rendered to PDF through Quarto's Typst engine, sharing the
#' report formats' template partials and therefore their brand-derived
#' colours, code styling and type ramp, all still inferred from
#' `_brand.yml`. Its look is its own: instead of the reports' striped
#' title panel, the sheet is framed by soft geometric corner ornaments
#' (see [brand_ornament()]) and the title is plain type on the page.
#'
#' The poster differs from the reports in five ways, all of which follow
#' from it being one big sheet rather than a sequence of small ones:
#' \itemize{
#'   \item The sheet is framed by a pair of soft corner ornaments,
#'     top-right and bottom-left, drawn behind the content in the brand's
#'     colours as SVG. They are written into the extension at scaffold
#'     time, so re-run with `overwrite = TRUE` after changing the brand.
#'   \item The page is landscape at `paper` size, unnumbered, and the
#'     body runs in `columns` balanced columns with the masthead
#'     spanning the full measure above them.
#'   \item Every level-2 (`##`) section becomes a card — a tinted panel
#'     with a primary-coloured header bar and the brand's own corner
#'     radius. Cards do not split across columns.
#'   \item The whole type ramp is scaled up for the paper size (see
#'     Details), so body copy is legible at arm's length and the title
#'     across a room.
#'   \item There is no running footer. An optional standing band, set
#'     flush right with no rule, can carry affiliations, funding or a
#'     URL — see `poster-footer` below.
#' }
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param paper Paper size, one of `"a0"` (default), `"a1"`, `"a2"`,
#'   `"a3"`, `"a4"`. Always rendered landscape. This is a scaffold-time
#'   choice rather than a document-level one because the type ramp is
#'   scaled from it — see Details.
#' @param columns Number of body columns. Default `3`. Overridable per
#'   document from the `.qmd` YAML.
#' @param examples Logical. Copy an example poster `.qmd`? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`_extensions/brandkit-poster/`}{A Quarto Typst format
#'     extension contributing `brandkit-poster-typst`. It installs the
#'     same template partials as [create_brand_quarto_pdf()], plus
#'     `poster.lua`; its generated `_extension.yml` sets the paper size,
#'     column count and type scale. It also holds the two generated
#'     corner ornaments, `drift-top-right.svg` and
#'     `drift-bottom-left.svg`.}
#'   \item{`poster.qmd`}{Sample poster on R's built-in `airquality` data (if
#'     `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, use the extension's format:
#' ```yaml
#' format:
#'   brandkit-poster-typst:
#'     columns: 3
#' poster-footer: "Dept. of Everything · you@example.org"
#' ```
#'
#' # Type scale
#'
#' Body text is sized from the column it has to fill rather than from
#' the sheet: a line wants about 70 characters, so the size follows from
#' the measure that `paper` and `columns` between them produce. A0
#' landscape at three columns gives a 13-inch measure and about 36pt
#' type; the same sheet at four columns gives about 26pt. Under that
#' sits a floor from the other constraint, viewing distance — 24pt on
#' A0, scaled down by the square root of the sheet's linear size — so
#' that a narrow-columned layout cannot set type too small to read
#' standing in front of it. The masthead takes a further 1.6x on top of
#' whichever wins, because it is the part read from across a hall
#' rather than at the measure.
#'
#' The size is applied as a multiple of the brand's own
#' `typography.base.size`, which is also what the masthead, logo and
#' banner clearance scale by. The body size itself is geometric: a
#' brand's base size sets what counts as 1x, it does not make the
#' poster's text larger or smaller.
#'
#' Both arguments are scaffold-time because the result is baked into the
#' extension. Setting `papersize:` or `columns:` in the document YAML
#' changes the layout but *not* the type sized for it — re-run this
#' function instead.
#'
#' # Sections and overflow
#'
#' `poster.lua` groups each `##` section and everything under it into a
#' card. Mark a heading `## Something {.plain}` to opt that section out
#' and let it run free in the column; `#` headings are above the
#' grouping and close any open card.
#'
#' A poster is a fixed-size sheet and Typst will not shrink content to
#' fit it: too much material spills onto a second page, and a single
#' card taller than one column does the same. Both are content
#' problems — cut, or drop to `columns = 4` — rather than something the
#' template can resolve.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @seealso [create_brand_quarto_pdf()] and
#'   [create_brand_quarto_print_pdf()] for the report formats this
#'   shares its design and template partials with.
#' @export
create_brand_quarto_poster <- function(path = ".", paper = "a0", columns = 3,
                                       examples = TRUE, overwrite = FALSE) {

  paper <- tolower(as.character(paper)[1])
  if (!paper %in% names(poster_paper_mm)) {
    stop("`paper` must be one of ",
         paste(sQuote(names(poster_paper_mm)), collapse = ", "),
         ", not ", sQuote(paper), ".", call. = FALSE)
  }
  if (!is.numeric(columns) || length(columns) != 1 || columns < 1 ||
      columns != as.integer(columns)) {
    stop("`columns` must be a single positive whole number.", call. = FALSE)
  }
  columns <- as.integer(columns)

  path <- scaffold_dir(path)

  # --- _brand.yml (Quarto-compatible) ---
  copied <- write_brand_yml_for_quarto(path, overwrite)

  # --- _extensions/brandkit-poster/ (Typst format extension) ---
  # banner_inset = TRUE alongside poster: it is what makes the masthead
  # flow content handed to article() rather than something drawn into the
  # page background. See write_extension_yml_for_quarto().
  copied <- c(copied, copy_typst_extension(
    path, "brandkit-poster",
    banner_inset = TRUE,
    overwrite = overwrite,
    poster = list(paper = paper, columns = columns)
  ))

  # --- Example poster ---
  if (examples) {
    copied <- c(copied, copy_template(
      "quarto/poster.qmd", file.path(path, "poster.qmd"), overwrite
    ))
  }

  copy_brand_assets(path, overwrite)

  base_pt <- css_length_pt_num(brand_env$typography$base$size) %||% 12
  message("\nDone. In your .qmd YAML, use:")
  message('  format: brandkit-poster-typst')
  message("Paper: ", toupper(paper), " landscape, ", columns, " columns, ",
          "body text ",
          round(base_pt * poster_type_scale(paper, columns, base_pt), 1),
          "pt.")
  message('Then run `quarto render poster.qmd` to produce a branded poster.')

  invisible(copied)
}
