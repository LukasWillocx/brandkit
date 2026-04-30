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

  # Set ggplot2 theme for this mode
  ggplot2::theme_set(theme_brand(mode = mode))

  # Set default discrete scales
  options(
    ggplot2.discrete.colour = function(...) scale_color_brand_d(..., mode = mode),
    ggplot2.discrete.fill   = function(...) scale_fill_brand_d(..., mode = mode)
  )

  # Set knitr device background to match brand — eliminates white
  # canvas bleeding through plot margins.
  if (requireNamespace("knitr", quietly = TRUE)) {
    knitr::opts_chunk$set(
      dev.args = list(bg = cols$background)
    )
  }

  invisible(NULL)
}


#' Set Up brandkit for a Quarto Project
#'
#' Copies `_brand.yml`, custom SCSS overrides, and optionally example
#' documents into a Quarto project directory. After running this, Quarto
#' auto-detects `_brand.yml` and applies it to HTML, dashboard, revealjs,
#' and typst formats. The SCSS file layers additional polish on top.
#'
#' @param path Project directory. Defaults to the current working directory.
#' @param examples Logical. Copy example `.qmd` files (report + slides)?
#'   Default `TRUE`.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache (your configured brand).}
#'   \item{`brandkit.scss`}{Custom SCSS overrides for cards, tables,
#'     scrollbars, and nav components — layered after brand in the
#'     Quarto theme.}
#'   \item{`example.qmd`}{Sample HTML report (if `examples = TRUE`).}
#'   \item{`slides.qmd`}{Sample revealjs presentation (if `examples = TRUE`).}
#' }
#'
#' In your `.qmd` YAML header, reference the SCSS like this:
#' ```yaml
#' format:
#'   html:
#'     theme: [brand, brandkit.scss]
#' ```
#'
#' For ggplot2 theming, just add `library(brandkit)` in a setup chunk —
#' the auto-applied theme and scales handle the rest.
#'
#' @return Invisibly returns a character vector of copied file paths.
#' @export
use_brand_quarto <- function(path = ".", examples = TRUE, overwrite = FALSE) {

  ensure_cache()
  path <- normalizePath(path, mustWork = TRUE)

  copied <- character(0)

  # --- _brand.yml (Quarto-compatible) ---
  brand_dest <- file.path(path, "_brand.yml")
  if (!file.exists(brand_dest) || overwrite) {
    write_quarto_brand_yml(brand_dest)
    copied <- c(copied, brand_dest)
    message("Wrote _brand.yml (Quarto-compatible)")
  } else {
    message("_brand.yml already exists (use overwrite = TRUE to replace)")
  }

  # --- brandkit.scss ---
  scss_src  <- system.file("quarto/brandkit.scss", package = "brandkit")
  scss_dest <- file.path(path, "brandkit.scss")
  if (nzchar(scss_src) && (!file.exists(scss_dest) || overwrite)) {
    file.copy(scss_src, scss_dest, overwrite = overwrite)
    copied <- c(copied, scss_dest)
    message("Copied brandkit.scss")
  }

  # --- Example files ---
  if (examples) {
    for (qmd in c("example.qmd", "slides.qmd")) {
      src  <- system.file(file.path("quarto", qmd), package = "brandkit")
      dest <- file.path(path, qmd)
      if (nzchar(src) && (!file.exists(dest) || overwrite)) {
        file.copy(src, dest, overwrite = overwrite)
        copied <- c(copied, dest)
        message("Copied ", qmd)
      }
    }
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  message("\nDone. In your .qmd YAML, use:")
  message('  theme: [brand, brandkit.scss]')
  message('Then add library(brandkit) in a setup chunk for ggplot2 theming.')

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
# Write a Quarto-compatible _brand.yml
# Strips bslib-specific keys (theme:, color-dark:) and converts dark
# colours to Quarto 1.8's nested light/dark format.
# --------------------------------------------------------------------------

write_quarto_brand_yml <- function(dest) {
  cfg <- brand_env$raw
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
  if (!is.null(cfg$logo))       out$logo       <- cfg$logo
  if (length(qcolor))           out$color      <- qcolor
  if (!is.null(cfg$typography)) out$typography  <- cfg$typography

  yaml::write_yaml(out, dest)
}
