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
#'
#' @return Invisible `NULL`. Called for side effects.
#'
#' @examples
#' \dontrun{
#' # In a Quarto setup chunk:
#' library(brandkit)
#' brand_quarto_setup()           # light mode (default)
#' brand_quarto_setup("dark")     # for brand-mode: dark documents
#' }
#'
#' @export
brand_quarto_setup <- function(mode = c("light", "dark"), transparent = TRUE) {
  mode <- match.arg(mode)
  ensure_cache()

  cols <- brand_colors(mode)

  # Store active mode so brand_plotly() auto-detects
  brand_env$active_mode <- mode

  # Set ggplot2 theme for this mode
  ggplot2::theme_set(theme_brand(mode = mode, transparent = transparent))

  # Set default discrete scales
  pal <- brand_pal_discrete(mode = mode)
  options(
    ggplot2.discrete.colour = pal,
    ggplot2.discrete.fill   = pal
  )

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

    # Hook sets par() before each chunk's graphics device
    fg <- cols$foreground
    bg <- cols$background
    knitr::knit_hooks$set(brandkit_par = function(before, options, envir) {
      if (before) {
        par(
          col.main = fg, col.sub = fg, col.lab = fg,
          col.axis = fg, fg = fg
        )
      }
    })
    knitr::opts_chunk$set(brandkit_par = TRUE)
  }

  invisible(NULL)
}


#' Set Up a Quarto HTML Project
#'
#' Copies `_brand.yml`, custom SCSS overrides, and an example HTML report
#' into a Quarto project directory. After running this, Quarto
#' auto-detects `_brand.yml` and applies it to HTML and dashboard
#' formats. The SCSS file layers additional polish on top, including a
#' full-bleed title banner drawing the same diagonal-stripe field as the
#' Typst PDF template's ([create_brand_quarto_pdf()]) — a flat
#' primary-coloured field behind the logo, title, subtitle, and
#' author/date, switching to secondary-coloured stripes past an angled
#' seam — but centred and mirrored rather than left-anchored, since an
#' HTML page has no fixed width to anchor an asymmetric composition to.
#'
#' For a revealjs slide deck, see [create_brand_quarto_slides()]. For a
#' PDF starting point rendered via Quarto's Typst engine, see
#' [create_brand_quarto_pdf()].
#'
#' @param path Project directory. Defaults to the current working directory.
#' @param examples Logical. Copy the example `report.qmd`? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`brandkit.scss`}{Custom SCSS overrides for the title banner and
#'     footer, plus cards, tables, scrollbars, and nav components —
#'     layered after brand in the Quarto theme. The banner's geometry is
#'     exposed as `--brand-banner-*` custom properties at the top of the
#'     `.brand-banner` rule if you want to retune it.}
#'   \item{`report.qmd`}{Sample HTML report (if `examples = TRUE`), whose
#'     banner and footer divs pull title/subtitle/author/date from the
#'     YAML header via `\{\{< meta ... >\}\}`.}
#' }
#'
#' In your `.qmd` YAML header, reference the SCSS like this:
#' ```yaml
#' format:
#'   html:
#'     theme:
#'       light: [brand, brandkit.scss]
#'       dark: [brand, brandkit.scss]
#' ```
#'
#' The nested `light:`/`dark:` form is what gives readers a working
#' light/dark toggle — Quarto compiles a Bootstrap stylesheet per mode
#' from `_brand.yml`'s `color:`/`color-dark:` entries and the toggle swaps
#' between them. The flat `theme: [brand, brandkit.scss]` form still shows
#' a toggle but only switches syntax highlighting, leaving the Bootstrap
#' layer light. Plots can't follow the toggle either way: they're static
#' images baked in at render time in whichever mode you pass to
#' [brand_quarto_setup()].
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

  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- brandkit.scss ---
  scss_src  <- system.file("quarto/brandkit.scss", package = "brandkit")
  scss_dest <- file.path(path, "brandkit.scss")
  if (nzchar(scss_src) && (!file.exists(scss_dest) || overwrite)) {
    file.copy(scss_src, scss_dest, overwrite = overwrite)
    copied <- c(copied, scss_dest)
    message("Copied brandkit.scss")
  }

  # --- Example report ---
  if (examples) {
    src  <- system.file("quarto/report.qmd", package = "brandkit")
    dest <- file.path(path, "report.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied report.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  theme: [brand, brandkit.scss]')
  message('Then add library(brandkit) in a setup chunk for ggplot2 theming.')

  invisible(copied)
}


#' Set Up a Quarto Revealjs Slides Project
#'
#' Copies `_brand.yml`, custom SCSS overrides, and an example revealjs
#' presentation into a Quarto project directory. After running this,
#' Quarto auto-detects `_brand.yml` and applies it to the revealjs
#' format. The SCSS file layers additional polish (logo sizing, nav
#' pills, scrollbars) on top.
#'
#' @param path Project directory. Defaults to the current working directory.
#' @param examples Logical. Copy the example `slides.qmd`? Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`brandkit.scss`}{Custom SCSS overrides — layered after brand in
#'     the Quarto theme.}
#'   \item{`slides.qmd`}{Sample revealjs presentation (if `examples = TRUE`).
#'     Its title slide background is written as a literal hex colour —
#'     the brand's primary colour darkened — computed at copy time so
#'     the deck's white title/subtitle/author/date text stays legible
#'     regardless of the brand's actual primary colour.}
#' }
#'
#' In your `.qmd` YAML header, reference the SCSS like this:
#' ```yaml
#' format:
#'   revealjs:
#'     theme: [brand, brandkit.scss]
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

  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- brandkit.scss ---
  scss_src  <- system.file("quarto/brandkit.scss", package = "brandkit")
  scss_dest <- file.path(path, "brandkit.scss")
  if (nzchar(scss_src) && (!file.exists(scss_dest) || overwrite)) {
    file.copy(scss_src, scss_dest, overwrite = overwrite)
    copied <- c(copied, scss_dest)
    message("Copied brandkit.scss")
  }

  # --- Example slides ---
  if (examples) {
    src  <- system.file("quarto/slides.qmd", package = "brandkit")
    dest <- file.path(path, "slides.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      # Substitute a literal, pre-darkened hex colour for the title
      # slide background — passing a CSS color-mix()/var() expression
      # through revealjs's data-background-color attribute depends on
      # its own JS accepting arbitrary CSS functions there, which isn't
      # reliable; a plain hex value has no such uncertainty.
      lines <- readLines(src, warn = FALSE)
      lines <- gsub(
        "__BRANDKIT_TITLE_BG__", title_slide_bg_color(), lines,
        fixed = TRUE
      )
      # Drop the `logo: medium` line entirely when no logo is configured
      # — left in place, revealjs still tries to render a logo image
      # that doesn't exist, showing a broken-image icon in its corner
      # instead of just omitting it.
      if (length(brand_env$logo) == 0) {
        lines <- lines[!grepl("^\\s*logo:\\s*medium\\s*$", lines)]
      }
      writeLines(lines, dest)
      copied <- c(copied, dest)
      message("Copied slides.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  theme: [brand, brandkit.scss]')
  message('Then add library(brandkit) and brand_quarto_setup() in a setup chunk.')

  invisible(copied)
}


#' Set Up a Quarto Shiny Dashboard Project
#'
#' Copies `_brand.yml`, the brandkit SCSS overrides, and an example
#' `dashboard.qmd` into a Quarto project directory, configured to render
#' to Quarto's `dashboard` format with a Shiny runtime. The result is a
#' KPI dashboard — a row of value boxes over filtered charts and a table
#' — driven by sidebar inputs.
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
#'   \item{`brandkit.scss`}{The same SCSS overrides the HTML report
#'     scaffold uses — layered after brand in the theme. Its title-banner
#'     rules are inert in a dashboard (there is no banner div to match),
#'     but its card, table, scrollbar, and nav styling all apply.}
#'   \item{`dashboard.qmd`}{Sample Shiny dashboard (if `examples = TRUE`).}
#' }
#'
#' Because the document declares `server: shiny`, it is served rather
#' than rendered to a static file:
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

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    message("Created directory: ", path)
  }
  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- brandkit.scss ---
  scss_src  <- system.file("quarto/brandkit.scss", package = "brandkit")
  scss_dest <- file.path(path, "brandkit.scss")
  if (nzchar(scss_src) && (!file.exists(scss_dest) || overwrite)) {
    file.copy(scss_src, scss_dest, overwrite = overwrite)
    copied <- c(copied, scss_dest)
    message("Copied brandkit.scss")
  }

  # --- Example dashboard ---
  if (examples) {
    src  <- system.file("quarto/dashboard.qmd", package = "brandkit")
    dest <- file.path(path, "dashboard.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied dashboard.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

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
#' extension this function installs closes that gap: both inline code
#' spans and fenced code blocks pick up the brand's configured monospace
#' font, sized to match the surrounding body text (Typst has no
#' root-relative unit equivalent to CSS `rem`, so this is resolved to an
#' absolute length rather than left to compound), and inline code spans
#' additionally get a colour of their own — a blend of the brand's
#' secondary accent and foreground colour — so they stand out in running
#' text. The extension also layers a full-bleed title banner on top — a
#' diagonal-stripe field (Linux Mint wallpaper style, drawn as Typst
#' polygons, no image asset) that runs primary-coloured behind the
#' title/subtitle and switches to secondary-coloured stripes past an
#' angled seam — plus coloured headings, a coloured footer, and a
#' code-block corner radius matching the brand's configured
#' border-radius, none of which the default Typst article template
#' provides on its own.
#'
#' @param path Project directory. Defaults to the current working directory.
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
#'     footer, and brand-matched code styling (monospace font and body-
#'     matched size for inline code and fenced blocks alike, plus a
#'     secondary/foreground colour blend on inline code) on top of
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

  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- _extensions/brandkit/ (Typst format extension) ---
  copied <- c(copied, copy_typst_extension(path, "brandkit",
                                           banner_inset = FALSE,
                                           overwrite = overwrite))

  # --- Example report ---
  if (examples) {
    src  <- system.file("quarto/pdf-report.qmd", package = "brandkit")
    dest <- file.path(path, "report-pdf.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied report-pdf.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  format: brandkit-typst')
  message('Then run `quarto render report-pdf.qmd` to produce a branded PDF.')

  invisible(copied)
}


# --------------------------------------------------------------------------
# Copy local font files referenced in _brand.yml
# --------------------------------------------------------------------------

copy_brand_fonts <- function(dest_dir, overwrite = FALSE) {
  fonts_raw <- brand_env$fonts$raw
  if (length(fonts_raw) == 0) return(invisible(NULL))

  brand_dir <- dirname(brand_env$path)

  for (fdef in fonts_raw) {
    if ((fdef$source %||% "file") != "file") next
    files <- fdef$files %||% list()

    for (f in files) {
      src <- file.path(brand_dir, f$path)
      if (!file.exists(src)) next

      # Preserve relative path structure (e.g. fonts/MyFont.ttf)
      dest <- file.path(dest_dir, f$path)
      dest_subdir <- dirname(dest)
      if (!dir.exists(dest_subdir)) dir.create(dest_subdir, recursive = TRUE)

      if (!file.exists(dest) || overwrite) {
        file.copy(src, dest, overwrite = overwrite)
        message("Copied font: ", f$path)
      }
    }
  }
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
        "Shiny/bslib format — color-dark:/theme: — which Quarto's ",
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
      "Added explicit Google font styles/weights to _brand.yml — without ",
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
# Write the brandkit-typst extension's _extension.yml
#
# Generated rather than copied so it can embed a brand-derived code-block
# corner radius: the brand's border-radius lives in a Bootstrap Sass
# variable (theme: in bslib's format, defaults: bootstrap: defaults: in
# Quarto's — see quarto_brand_cfg()), and Typst output goes nowhere near
# the Sass pipeline, so there is no other channel for it to reach the
# typst template. Format-level keys under
# contributes: formats: typst: become pandoc template variables like any
# other format option (the same mechanism that makes `margin:` below
# reach the template), so `code-radius` here is readable in definitions.typ
# as $code-radius$.
# --------------------------------------------------------------------------

write_extension_yml_for_quarto <- function(dest, banner_inset = FALSE,
                                           poster = NULL) {
  radius <- css_rem_to_typst_em(brand_env$theme_vars[["border-radius"]])

  # The poster's whole type ramp — body, headings, code, masthead — is
  # driven by the single scale factor computed here, because every one
  # of those is already expressed relative to `fontsize` (see the
  # comment on it below, and the `show raw` rules in
  # typst-template.typ). Scaling that one absolute value is therefore
  # the only place a paper size has to be accounted for.
  # Falls back to 12pt (1rem at a browser's default) when the brand
  # declares no base size, matching the rem conversion in
  # css_length_pt_num() — so a brand without typography still gets a
  # poster sized for its columns rather than one sized for a letter page.
  base_pt <- css_length_pt_num(brand_env$typography$base$size) %||% 12
  type_scale <- if (is.null(poster)) {
    1
  } else {
    poster_type_scale(poster$paper, poster$columns, base_pt)
  }

  typst_fmt <- list(
    template = "template.typ",
    `template-partials` = list(
      "typst-template.typ", "typst-show.typ",
      "numbering.typ", "definitions.typ",
      "page.typ", "notes.typ", "biblio.typ"
    ),
    margin = if (is.null(poster)) {
      list(x = "2.5cm", y = "2.5cm")
    } else {
      # poster_type_scale() measures the columns against this same
      # value — see its comment on the two duplicated constants.
      list(x = paste0(poster_margin_in, "in"),
           y = paste0(poster_margin_in, "in"))
    },
    # width is also the size used inline inside the title banner
    # (page.typ) when a title is present; location/padding-* only
    # apply to the plain corner-mark fallback used when there's no
    # title (and so no banner) — see page.typ.
    logo = list(
      location = "right-top",
      # Scaled with the masthead it sits in rather than with the body
      # text (hence the same 1.6 the banner ramp uses): a logo sized
      # against 31pt body copy would be a stamp beside an 80pt title.
      width = if (is.null(poster)) {
        "0.5in"
      } else {
        paste0(round(0.5 * type_scale * 1.6, 2), "in")
      },
      `padding-right` = "0.5in",
      `padding-top` = "0.25in"
    ),
    `code-radius` = radius
  )

  # Selects the inset (print) banner in page.typ and typst-template.typ.
  # Written only when TRUE: pandoc's $if()$ tests presence, and a key set
  # to a literal `false` still reads as present and would switch the
  # layout on for the full-bleed extension too.
  #
  # The poster sets it as well, though it no longer draws the striped
  # panel: the flag is what makes typst-show.typ hand the masthead to
  # article() as flow content, which article() then floats across the
  # columns. page.typ's `poster` branch builds that masthead.
  if (isTRUE(banner_inset)) {
    typst_fmt$`banner-inset` <- TRUE
  }

  if (!is.null(poster)) {
    typst_fmt$papersize <- poster$paper
    typst_fmt$poster <- TRUE
    typst_fmt$`poster-scale` <- type_scale
    # The corner ornaments page.typ draws as the page background. Quarto
    # copies format-resources next to the rendered document, which is
    # what lets page.typ name them without a path: the compiled .typ sits
    # beside the document, wherever in the project that is, whereas the
    # extension directory is only a fixed distance away for documents at
    # the project root.
    typst_fmt$`format-resources` <- as.list(poster_ornament_files)
    # Read by typst-show.typ as the *flow* column count, not Typst page
    # columns — page.typ's poster branch pins those to 1. Overridable
    # per document from the .qmd YAML like any other format option.
    typst_fmt$columns <- poster$columns
    # Groups each level-2 section into a card panel; see poster.lua.
    typst_fmt$filters <- list("poster.lua")
  }

  # An explicit absolute `fontsize:` here takes the $if(fontsize)$ branch
  # in typst-show.typ, pre-empting the $elseif(brand.typography.base.size)$
  # fallback entirely. That fallback matters because Quarto's own rem-to-
  # typst conversion for brand.typography.base.size doesn't compute an
  # absolute length — it just renames the unit (Typst warns "brand.
  # typography.base.size in rem units, changing to em"), leaving the
  # article() template's `fontsize` parameter holding a *relative* Typst
  # em value. That's fine the first time it's consumed (`set text(size:
  # fontsize)` at the top of article(), scaling once off Typst's own
  # baseline) but toxic anywhere it gets reused afterward — e.g. the
  # `show raw: set text(size: fontsize)` rule that pins code text to the
  # body size — because by then the ambient size is already scaled by
  # that same relative factor, so reapplying it compounds
  # multiplicatively instead of matching. Resolving to an absolute pt
  # value here, once, keeps every later reuse of `fontsize` exact.
  fontsize <- css_length_to_typst_pt(brand_env$typography$base$size,
                                     scale = type_scale)
  if (!is.null(fontsize)) {
    typst_fmt$fontsize <- fontsize
  }

  cfg <- list(
    title = if (is.null(poster)) {
      "brandkit Typst Report"
    } else {
      "brandkit Typst Poster"
    },
    author = "brandkit",
    version = "1.0.0",
    `quarto-required` = ">=1.8.0",
    contributes = list(formats = list(typst = typst_fmt))
  )

  yaml::write_yaml(cfg, dest)
}

# Convert a CSS-style base font size (rem/em/px/pt) to an absolute Typst
# length in pt. Unlike css_rem_to_typst_em() below (which deliberately
# keeps border-radius relative to the current text size, in the same
# spirit as CSS rem), a *font size* must resolve to an absolute value —
# see the comment above its call site in write_extension_yml_for_quarto()
# for why a relative unit compounds when reused for code text sizing.
# rem/em are both treated as relative to a 16px root (1rem = 16px =
# 12pt), matching typical browser defaults; unrecognised units fall back
# to NULL so the caller leaves Quarto's own (relative) handling in place
# rather than silently producing a wrong absolute value.
css_length_to_typst_pt <- function(css_length, fallback = NULL, scale = 1) {
  pt <- css_length_pt_num(css_length)
  if (is.null(pt)) return(fallback)
  paste0(round(pt * scale, 2), "pt")
}

# The numeric half of the above, split out because the poster's type
# scale needs the brand's base size as a number to divide by, not as a
# formatted Typst length.
css_length_pt_num <- function(css_length) {
  if (is.null(css_length) || !nzchar(css_length)) return(NULL)
  m <- regmatches(css_length, regexec("^([0-9.]+)(rem|em|px|pt)$", css_length))[[1]]
  if (length(m) != 3) return(NULL)
  num <- as.numeric(m[2])
  pt <- switch(m[3],
    pt  = num,
    px  = num * 0.75,
    rem = num * 12,
    em  = num * 12,
    NA_real_
  )
  if (is.na(pt)) NULL else pt
}


# --------------------------------------------------------------------------
# Poster type scale: how much larger everything gets on a big sheet.
#
# The tempting model — scale type with the paper — is wrong twice over.
# A0 is four times A4 by linear dimension, and a 14.4pt brand base
# multiplied by four is a 58pt slide, not a poster; reading distance
# does not grow with the sheet, because poster body copy is still read
# from arm's length and only the title has to carry across a hall. But
# damping that factor to taste is just as wrong in the other direction,
# because it ignores what actually constrains the size: the measure.
#
# So the size is derived from the column it has to fill. A line wants
# roughly 70 characters; a character in a text face averages about
# 0.37em; so the body size is the column width divided by those two.
# On A0 landscape at three columns that is a ~13in measure and ~36pt
# type — larger than the 24-32pt usually quoted for A0, because that
# figure assumes the portrait sheet and its much narrower columns. Ask
# for four columns instead and the same arithmetic returns ~26pt, right
# back in the quoted band. That is the point of deriving it rather than
# tabulating it: `paper` and `columns` both move it, correctly, without
# a second constant to keep in sync.
#
# The measure is not the only constraint, though, and on its own it
# fails in one direction: ask for four columns on A1 and it returns
# ~18pt, which sets a beautiful 70-character line that nobody standing
# in front of the poster can read. So there is a floor underneath it,
# from the other constraint — viewing distance, which tracks the sheet
# rather than the column. That is anchored at the 24pt conventionally
# quoted for A0 and taken down by the square root of the sheet's linear
# scale from there. Whichever of the two wants larger type wins, so a
# wide measure raises the size and a narrow one can only take it down as
# far as the sheet allows.
#
# The result is returned as a multiple of the brand's base size rather
# than as an absolute, because the masthead ramp, the banner clearance
# and the logo all scale by that same factor (see page.typ). The body
# size itself is geometric — a brand's own base size does not make a
# poster's text bigger or smaller, it only sets what counts as 1x — and
# the clamp bites only for brands well outside the usual 9-16pt range.
#
# Two constants below are duplicated from the layout and have to move
# with it: `margin` is what write_extension_yml_for_quarto() writes into
# the extension for a poster, and `gutter` is the `set columns(gutter:)`
# in page.typ's poster branch. Getting either wrong misjudges the
# measure and so the size — visible on screen, not a render failure.
# --------------------------------------------------------------------------

poster_paper_mm <- list(
  a0 = c(841, 1189), a1 = c(594, 841), a2 = c(420, 594),
  a3 = c(297, 420),  a4 = c(210, 297)
)

poster_margin_in <- 1.5
poster_gutter_frac <- 0.05

# Characters per line to aim for, and the average width of one in ems.
# 0.37 is measured rather than assumed — it is what Inter at this size
# actually sets to in the rendered poster; the classic 0.5em figure is
# for monospace and overestimates a text face by a third.
poster_target_chars <- 70
poster_char_em <- 0.37

# The viewing-distance floor, anchored on A0 and taken down from there
# by the square root of the sheet's linear scale: 24pt on A0, ~20pt on
# A1, ~17pt on A2.
poster_floor_pt_a0 <- 24

poster_type_scale <- function(paper, columns, base_pt = 12) {
  dims <- poster_paper_mm[[tolower(paper %||% "a0")]] %||% poster_paper_mm$a0

  # Landscape, so the sheet's long edge is its width.
  text_w_in <- max(dims) / 25.4 - 2 * poster_margin_in
  gutter_in <- poster_gutter_frac * text_w_in
  col_w_pt  <- (text_w_in - (columns - 1) * gutter_in) / columns * 72
  measure_pt <- col_w_pt / (poster_target_chars * poster_char_em)

  # Relative to A0 rather than to A4, so the anchor above reads as the
  # size it actually is on the sheet it was chosen for.
  sheet_ratio <- sqrt(prod(dims)) / sqrt(prod(poster_paper_mm$a0))
  floor_pt <- poster_floor_pt_a0 * sqrt(sheet_ratio)

  round(max(1, min(4, max(measure_pt, floor_pt) / base_pt)), 3)
}

# Convert a bslib border-radius (e.g. "0.75rem") to a typst-native length.
# Typst has no "rem" unit; "em" is the closest equivalent (relative to
# current text size, same spirit as CSS rem being relative to root size).
css_rem_to_typst_em <- function(css_length, fallback = "0.3em") {
  if (is.null(css_length) || !nzchar(css_length)) return(fallback)
  num <- suppressWarnings(as.numeric(sub("rem$", "", css_length)))
  if (is.na(num)) return(fallback)
  paste0(num, "em")
}

# Darkened hex colour for the revealjs title slide background — dark
# enough that the slide's white title/subtitle/author/date text (set in
# brandkit.scss) stays legible regardless of how light the brand's own
# primary colour is.
title_slide_bg_color <- function() {
  primary <- brand_env$colors$primary %||% "#2c3e50"
  tryCatch(
    unname(colorspace::darken(primary, amount = 0.4)),
    error = function(e) primary
  )
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
  color_keys <- c("primary", "secondary", "success", "danger",
                  "warning", "info", "light", "dark",
                  "foreground", "background")

  qcolor <- list()
  for (k in color_keys) {
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
  # Only reference a logo if its file(s) will actually be copied
  # alongside this _brand.yml — otherwise a stale or cross-project cache
  # can produce a scaffold that references a logo Quarto can never find.
  if (!is.null(cfg$logo)) {
    if (keep_logo %||% logo_files_exist(cfg$logo, brand_dir)) {
      out$logo <- cfg$logo
    } else if (is.null(keep_logo)) {
      message(
        "Note: the cached brand references a logo, but its file could ",
        "not be found — omitting logo: from _brand.yml. Run ",
        "configure_brand() in this project (or copy the logo file in ",
        "manually) if you want a logo here."
      )
    }
  }
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


# --------------------------------------------------------------------------
# Check whether a brand.yml logo: section's referenced file(s) actually
# exist relative to the currently cached _brand.yml's directory.
# --------------------------------------------------------------------------

logo_files_exist <- function(logo, brand_dir = dirname(brand_env$path)) {
  if (length(logo) == 0) return(FALSE)

  paths <- if (is.character(logo)) {
    logo
  } else {
    unique(unlist(lapply(logo[c("small", "medium", "large")], function(x) {
      if (is.character(x)) x else if (is.list(x)) c(x$light, x$dark)
    })))
  }
  paths <- paths[!is.null(paths)]
  if (length(paths) == 0) return(FALSE)

  all(file.exists(file.path(brand_dir, paths)))
}


# --------------------------------------------------------------------------
# Copy logo files referenced in _brand.yml
# --------------------------------------------------------------------------

copy_brand_logo <- function(dest_dir, overwrite = FALSE) {
  logo <- brand_env$logo
  if (length(logo) == 0) return(invisible(NULL))

  brand_dir <- dirname(brand_env$path)

  # Collect all logo paths (small, medium, large, or bare string)
  paths <- if (is.character(logo)) {
    logo
  } else {
    unique(unlist(lapply(logo[c("small", "medium", "large")], function(x) {
      if (is.character(x)) x else if (is.list(x)) c(x$light, x$dark)
    })))
  }
  paths <- paths[!is.null(paths)]

  for (p in paths) {
    src <- file.path(brand_dir, p)
    if (!file.exists(src)) next

    dest <- file.path(dest_dir, p)
    dest_subdir <- dirname(dest)
    if (!dir.exists(dest_subdir)) dir.create(dest_subdir, recursive = TRUE)

    if (!file.exists(dest) || overwrite) {
      file.copy(src, dest, overwrite = overwrite)
      message("Copied logo: ", p)
    }
  }
}


# --------------------------------------------------------------------------
# Copy the Typst format extension into path/_extensions/<ext_name>/
#
# Both PDF variants install the *same* .typ partials — the banner, the
# code styling, the footer and the type ramp are shared, and the two
# layouts differ only by the `banner-inset` switch the generated
# _extension.yml sets (see write_extension_yml_for_quarto(), and the
# $if(banner-inset)$ branches in page.typ and typst-template.typ). Keeping
# one copy of the templates is the whole point: a fix to the banner or the
# code styling has to reach both formats, and duplicating the partials per
# format is how those quietly drift apart.
#
# The directory name is what Quarto derives the format name from, so
# `brandkit` gives `format: brandkit-typst` and `brandkit-print` gives
# `format: brandkit-print-typst`. Both can coexist in one project.
# --------------------------------------------------------------------------

copy_typst_extension <- function(path, ext_name, banner_inset, overwrite,
                                 poster = NULL) {
  copied <- character(0)

  ext_src_dir  <- system.file("quarto/typst/_extensions/brandkit", package = "brandkit")
  if (!nzchar(ext_src_dir)) {
    warning("brandkit Typst extension not found in package installation.")
    return(copied)
  }

  ext_dest_dir <- file.path(path, "_extensions", ext_name)
  if (!dir.exists(ext_dest_dir)) dir.create(ext_dest_dir, recursive = TRUE)

  # _extension.yml is generated, not copied, so it can embed a
  # brand-derived code-block corner radius, an absolute base font size,
  # and the banner-layout switch
  ext_yml_dest <- file.path(ext_dest_dir, "_extension.yml")
  if (!file.exists(ext_yml_dest) || overwrite) {
    write_extension_yml_for_quarto(ext_yml_dest, banner_inset = banner_inset,
                                   poster = poster)
    copied <- c(copied, ext_yml_dest)
    message("Wrote _extensions/", ext_name, "/_extension.yml")
  }

  # The corner ornaments are generated like _extension.yml, and for the
  # same reason: they are drawn in the brand's colours, which only the
  # R side knows. Poster only; the report formats keep the striped banner.
  if (!is.null(poster)) {
    orn_dest <- file.path(ext_dest_dir, poster_ornament_files)
    if (overwrite || !all(file.exists(orn_dest))) {
      write_poster_ornaments(ext_dest_dir)
      copied <- c(copied, orn_dest)
      message("Wrote _extensions/", ext_name, "/ ", paste(poster_ornament_files, collapse = ", "))
    }
  }

  # The card-grouping filter is only ever declared by the poster's
  # _extension.yml, so copying it into a report extension would leave a
  # file that never runs — skipped rather than shipped as dead weight.
  skip <- c("_extension.yml", if (is.null(poster)) "poster.lua")

  for (f in setdiff(list.files(ext_src_dir), skip)) {
    src  <- file.path(ext_src_dir, f)
    dest <- file.path(ext_dest_dir, f)
    if (!file.exists(dest) || overwrite) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied _extensions/", ext_name, "/", f)
    }
  }

  copied
}


#' Set Up a Print-Friendly Quarto Typst PDF Project
#'
#' The print-oriented sibling of [create_brand_quarto_pdf()]. Everything
#' about the two formats is the same — the same code styling, coloured
#' headings, coloured footer, type ramp and brand integration, from the
#' same shared template files — except for how the title banner is drawn.
#'
#' [create_brand_quarto_pdf()] draws the diagonal-stripe banner
#' full-bleed, spanning the whole physical page width from the page
#' background. That looks right on screen but needs a printer that can
#' bleed: on an ordinary office or home printer the panel either clips at
#' the unprintable edge or leaves a white hairline frame around itself,
#' and it lays down a full page-width solid that can show through lighter
#' stock. This function instead insets the panel to the text measure and
#' emits it as ordinary flow content, so no ink crosses the margin and
#' the header area uses roughly a third less coverage.
#'
#' Both formats install into separate extension directories and can
#' coexist in one project, so you can render the same document either
#' way by changing its `format:` key.
#'
#' @param path Project directory. Defaults to the current working directory.
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
#'     `_extension.yml` sets `banner-inset`, which selects the inset
#'     panel in `page.typ` and makes `typst-template.typ` emit the banner
#'     into the flow rather than reserving space for a background-drawn
#'     one.}
#'   \item{`report-print.qmd`}{Sample report (if `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, use the extension's format:
#' ```yaml
#' format:
#'   brandkit-print-typst:
#'     toc: true
#' ```
#'
#' Because the panel is flow content rather than a fixed-height page
#' background, it grows with its own content — a title long enough to
#' overrun the full-bleed banner simply makes this one taller instead of
#' being clipped.
#'
#' The no-title case is unchanged from the full-bleed format: with no
#' title there is no banner, and the logo falls back to a plain
#' page-corner mark.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @seealso [create_brand_quarto_pdf()] for the full-bleed screen variant.
#' @export
create_brand_quarto_print_pdf <- function(path = ".", examples = TRUE,
                                          overwrite = FALSE) {

  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- _extensions/brandkit-print/ (Typst format extension) ---
  copied <- c(copied, copy_typst_extension(path, "brandkit-print",
                                           banner_inset = TRUE,
                                           overwrite = overwrite))

  # --- Example report ---
  if (examples) {
    src  <- system.file("quarto/print-report.qmd", package = "brandkit")
    dest <- file.path(path, "report-print.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied report-print.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

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
#' @param path Project directory. Defaults to the current working directory.
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
#'   \item{`poster.qmd`}{Sample poster (if `examples = TRUE`).}
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

  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- write_brand_yml_for_quarto(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

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
    src  <- system.file("quarto/poster.qmd", package = "brandkit")
    dest <- file.path(path, "poster.qmd")
    if (nzchar(src) && (!file.exists(dest) || overwrite)) {
      file.copy(src, dest, overwrite = overwrite)
      copied <- c(copied, dest)
      message("Copied poster.qmd")
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

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
