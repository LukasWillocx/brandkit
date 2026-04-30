# --------------------------------------------------------------------------
# brandkit: brand_fonts.R
# Font registration driven entirely by _brand.yml typography section.
# --------------------------------------------------------------------------

#' Register Brand Fonts for Plotting
#'
#' Reads font definitions from the brand cache and registers them via
#' sysfonts/showtext. Called automatically in `.onLoad` when both
#' packages are available.
#'
#' @param font_dir Directory containing `.ttf`/`.otf` files. Defaults to
#'   `inst/fonts` inside the package, or the directory containing
#'   `_brand.yml` if fonts use relative paths.
#'
#' @return Invisible `NULL`. Called for side effects.
#' @export
brand_register_fonts <- function(font_dir = NULL) {

  if (!requireNamespace("sysfonts", quietly = TRUE) ||
      !requireNamespace("showtext", quietly = TRUE)) {
    return(invisible(NULL))
  }

  ensure_cache()
  fonts_raw <- brand_env$fonts$raw
  if (length(fonts_raw) == 0) return(invisible(NULL))

  # Resolve base directory for font file paths
  base_dir <- font_dir %||% dirname(brand_env$path)

  for (fdef in fonts_raw) {
    family <- fdef$family
    if (is.null(family)) next

    source <- fdef$source %||% "file"

    if (source == "google") {
      tryCatch(
        sysfonts::font_add_google(family, family),
        error = function(e) {
          message("brandkit: could not load Google Font '", family, "': ", e$message)
        }
      )
    } else {
      # Local font files — collect weights
      files <- fdef$files %||% list()
      regular <- bold <- italic <- bolditalic <- NULL

      for (f in files) {
        path <- file.path(base_dir, f$path)
        if (!file.exists(path)) {
          # Try inst/fonts fallback
          path <- system.file("fonts", basename(f$path), package = "brandkit")
        }
        if (!file.exists(path)) next

        style  <- f$style  %||% "normal"
        weight <- as.integer(f$weight %||% 400)

        if (weight <= 400 && style == "normal")      regular    <- path
        if (weight >= 700 && style == "normal")      bold       <- path
        if (weight <= 400 && style == "italic")       italic     <- path
        if (weight >= 700 && style == "italic")       bolditalic <- path
      }

      if (!is.null(regular)) {
        tryCatch(
          sysfonts::font_add(
            family   = family,
            regular  = regular,
            bold     = bold       %||% regular,
            italic   = italic     %||% regular,
            bolditalic = bolditalic %||% bold %||% regular
          ),
          error = function(e) {
            message("brandkit: could not register font '", family, "': ", e$message)
          }
        )
      }
    }
  }

  showtext::showtext_auto()
  invisible(NULL)
}
