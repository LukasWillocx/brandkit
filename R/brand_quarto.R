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
brand_quarto_setup <- function(mode = c("light", "dark")) {
  mode <- match.arg(mode)
  ensure_cache()

  cols <- brand_colors(mode)

  # Store active mode so brand_plotly() auto-detects
  brand_env$active_mode <- mode

  # Set ggplot2 theme for this mode
  ggplot2::theme_set(theme_brand(mode = mode))

  # Set default discrete scales
  pal <- brand_pal_discrete(mode = mode)
  options(
    ggplot2.discrete.colour = pal,
    ggplot2.discrete.fill   = pal
  )

  # Set knitr device background to match brand — eliminates white
  # canvas bleeding through plot margins. Also register a hook to
  # set base R par() colours before each chunk so barplot, hist,
  # etc. follow the brand.
  if (requireNamespace("knitr", quietly = TRUE)) {
    knitr::opts_chunk$set(
      dev.args = list(bg = cols$background)
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
  ext_src_dir  <- system.file("quarto/typst/_extensions/brandkit", package = "brandkit")
  ext_dest_dir <- file.path(path, "_extensions", "brandkit")

  if (nzchar(ext_src_dir)) {
    if (!dir.exists(ext_dest_dir)) dir.create(ext_dest_dir, recursive = TRUE)

    # _extension.yml is generated, not copied, so it can embed a
    # brand-derived code-block corner radius for the typst template
    ext_yml_dest <- file.path(ext_dest_dir, "_extension.yml")
    if (!file.exists(ext_yml_dest) || overwrite) {
      write_extension_yml_for_quarto(ext_yml_dest)
      copied <- c(copied, ext_yml_dest)
      message("Wrote _extensions/brandkit/_extension.yml")
    }

    for (f in setdiff(list.files(ext_src_dir), "_extension.yml")) {
      src  <- file.path(ext_src_dir, f)
      dest <- file.path(ext_dest_dir, f)
      if (!file.exists(dest) || overwrite) {
        file.copy(src, dest, overwrite = overwrite)
        copied <- c(copied, dest)
        message("Copied _extensions/brandkit/", f)
      }
    }
  } else {
    warning("brandkit Typst extension not found in package installation.")
  }

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

  message(
    "_brand.yml already exists and is Quarto-compatible ",
    "(use overwrite = TRUE to regenerate)"
  )
  NULL
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

write_extension_yml_for_quarto <- function(dest) {
  radius <- css_rem_to_typst_em(brand_env$theme_vars[["border-radius"]])

  typst_fmt <- list(
    template = "template.typ",
    `template-partials` = list(
      "typst-template.typ", "typst-show.typ",
      "numbering.typ", "definitions.typ",
      "page.typ", "notes.typ", "biblio.typ"
    ),
    margin = list(x = "2.5cm", y = "2.5cm"),
    # width is also the size used inline inside the title banner
    # (page.typ) when a title is present; location/padding-* only
    # apply to the plain corner-mark fallback used when there's no
    # title (and so no banner) — see page.typ.
    logo = list(
      location = "right-top",
      width = "0.5in",
      `padding-right` = "0.5in",
      `padding-top` = "0.25in"
    ),
    `code-radius` = radius
  )

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
  fontsize <- css_length_to_typst_pt(brand_env$typography$base$size)
  if (!is.null(fontsize)) {
    typst_fmt$fontsize <- fontsize
  }

  cfg <- list(
    title = "brandkit Typst Report",
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
css_length_to_typst_pt <- function(css_length, fallback = NULL) {
  if (is.null(css_length) || !nzchar(css_length)) return(fallback)
  m <- regmatches(css_length, regexec("^([0-9.]+)(rem|em|px|pt)$", css_length))[[1]]
  if (length(m) != 3) return(fallback)
  num  <- as.numeric(m[2])
  pt <- switch(m[3],
    pt  = num,
    px  = num * 0.75,
    rem = num * 12,
    em  = num * 12,
    NA_real_
  )
  if (is.na(pt)) return(fallback)
  paste0(round(pt, 2), "pt")
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
  if (!is.null(cfg$typography)) out$typography  <- cfg$typography

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
