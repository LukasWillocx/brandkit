# --------------------------------------------------------------------------
# brandkit: brand_shiny.R
# Shiny app scaffolding — one template per brand_page_*() wrapper.
# --------------------------------------------------------------------------

#' Set Up a Branded Shiny App
#'
#' Scaffolds a minimal single-file Shiny app built on
#' [brand_page_sidebar()] — a sidebar of inputs, a plot, a palette
#' preview, and a summary panel, with no theming code in it. Use this as
#' the starting point for a new branded app.
#'
#' For a KPI dashboard on [brand_page_navbar()], see
#' [create_brand_shiny_dashboard()]. For a leaflet/plotly geospatial app
#' on [brand_page_fluid()], see [create_brand_shiny_map()].
#'
#' @param path Project directory. Defaults to the current working
#'   directory. Created if it doesn't exist.
#' @param overwrite Logical. Overwrite existing files? Default `FALSE`.
#'
#' @details
#' This function copies the following into `path`:
#' \describe{
#'   \item{`_brand.yml`}{From the brandkit cache, in the bslib format
#'     (see *Brand format* below).}
#'   \item{`app.R`}{The app template.}
#' }
#' Local font files and logo files referenced by the brand are copied
#' alongside, preserving their relative paths.
#'
#' Unlike the Quarto scaffolds, nothing else needs copying: the
#' `brand_page_*()` wrappers pull brandkit's widget CSS overrides,
#' dark-mode CSS, and the dark-mode toggle in at runtime, so there is no
#' stylesheet to place in the project.
#'
#' @section Brand format:
#' This is the mirror image of what [create_brand_quarto_html()] and
#' friends do. Quarto 1.8 wants light/dark colours nested under each
#' colour key (`primary: {light: ..., dark: ...}`); bslib rejects that
#' outright — `bslib::bs_theme(brand = )` errors with "`color.primary`
#' must be a single string or `NULL`, not a list" — and wants a flat
#' `color:` section with dark values in a separate `color-dark:` section.
#'
#' So if `path` already holds a `_brand.yml` in the Quarto format, it is
#' converted to the bslib format regardless of `overwrite`, since a
#' leftover Quarto-format file always needs fixing before the app will
#' start. An already-bslib-compatible `_brand.yml` is left alone unless
#' `overwrite = TRUE`.
#'
#' Bootstrap variables (border radius and so on) are written under
#' `defaults: bootstrap: defaults:` rather than the `theme:` key that
#' [configure_brand()] writes. Both are read back by brandkit itself, but
#' only the former is read by bslib — a `theme:` section is silently
#' ignored by `bs_theme(brand = )`, so a border radius configured there
#' never reaches the app.
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
#' create_brand_shiny_app(path = "my-app")
#' shiny::runApp("my-app")
#' }
#'
#' @export
create_brand_shiny_app <- function(path = ".", overwrite = FALSE) {
  scaffold_shiny_app(
    path      = path,
    template  = "app-starter.R",
    overwrite = overwrite,
    packages  = character(0)
  )
}


#' Set Up a Branded Shiny Dashboard
#'
#' Scaffolds a single-file KPI dashboard built on [brand_page_navbar()]:
#' a row of `bslib::value_box()` tiles, revenue and product-mix charts, a
#' trends tab, and a DT data table — all driven by sample data you
#' replace with your own.
#'
#' @inheritParams create_brand_shiny_app
#'
#' @details
#' Copies `_brand.yml` (bslib format), `app.R`, and any local font and
#' logo files, exactly as [create_brand_shiny_app()] does — see its
#' documentation for how the brand file is written and converted.
#'
#' The template uses the \pkg{DT} package for its data table. DT is a
#' suggested dependency of brandkit, so it may not be installed; this
#' function says so rather than leaving you to hit the error at app
#' start. DT tables are styled in both light and dark mode by brandkit's
#' CSS overrides, so the template passes no theming arguments to
#' `datatable()`.
#'
#' @return Invisibly returns a character vector of copied file paths.
#'
#' @examples
#' \dontrun{
#' create_brand_shiny_dashboard(path = "my-dashboard")
#' shiny::runApp("my-dashboard")
#' }
#'
#' @export
create_brand_shiny_dashboard <- function(path = ".", overwrite = FALSE) {
  scaffold_shiny_app(
    path      = path,
    template  = "app-dashboard.R",
    overwrite = overwrite,
    packages  = "DT"
  )
}


#' Set Up a Branded Shiny Map App
#'
#' Scaffolds a single-file geospatial app built on [brand_page_fluid()]:
#' a leaflet map with brand-coloured markers, filter controls, a
#' histogram, and an interactive plotly scatter.
#'
#' @inheritParams create_brand_shiny_app
#'
#' @details
#' Copies `_brand.yml` (bslib format), `app.R`, and any local font and
#' logo files, exactly as [create_brand_shiny_app()] does — see its
#' documentation for how the brand file is written and converted.
#'
#' Leaflet and plotly both render outside Bootstrap's reach, so neither
#' picks up the theme on its own. The template shows the two helpers that
#' bridge that gap: [brand_pal_seq()] supplying the colour ramp to
#' `leaflet::colorNumeric()`, and [brand_plotly()] re-applying brand
#' colours and fonts after `ggplotly()` strips them. Both take a `mode`
#' argument, wired here to [brand_dark_mode()] so they follow the
#' dark-mode toggle; the map's tile layer switches with it too.
#'
#' The template needs the \pkg{leaflet} and \pkg{plotly} packages. Both
#' are optional for brandkit, so this function reports any that are
#' missing rather than leaving you to hit the error at app start.
#'
#' @return Invisibly returns a character vector of copied file paths.
#'
#' @examples
#' \dontrun{
#' create_brand_shiny_map(path = "my-map-app")
#' shiny::runApp("my-map-app")
#' }
#'
#' @export
create_brand_shiny_map <- function(path = ".", overwrite = FALSE) {
  scaffold_shiny_app(
    path      = path,
    template  = "app-map.R",
    overwrite = overwrite,
    packages  = c("leaflet", "plotly")
  )
}


# --------------------------------------------------------------------------
# Internal: shared scaffolding worker
#
# Every Shiny template lands as app.R, so `shiny::runApp(path)` works on
# the result without further argument.
# --------------------------------------------------------------------------

scaffold_shiny_app <- function(path, template, overwrite, packages) {

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    message("Created directory: ", path)
  }
  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)

  copied <- character(0)

  # --- _brand.yml (bslib-compatible) ---
  brand_dest <- write_brand_yml_for_shiny(path, overwrite)
  if (!is.null(brand_dest)) copied <- c(copied, brand_dest)

  # --- app.R ---
  src  <- system.file(file.path("shiny", template), package = "brandkit")
  dest <- file.path(path, "app.R")
  if (!nzchar(src)) {
    warning("brandkit Shiny template '", template, "' not found in package installation.")
  } else if (file.exists(dest) && !overwrite) {
    message("app.R already exists (use overwrite = TRUE to replace it)")
  } else {
    file.copy(src, dest, overwrite = overwrite)
    copied <- c(copied, dest)
    message("Copied app.R (", template, ")")
  }

  # --- Font files (if local fonts are defined) ---
  copy_brand_fonts(path, overwrite)

  # --- Logo files ---
  copy_brand_logo(path, overwrite)

  warn_missing_packages(packages)

  message("\nDone. Run the app with:")
  message('  shiny::runApp("', path, '")')

  invisible(copied)
}


# --------------------------------------------------------------------------
# Internal: ensure a bslib-compatible _brand.yml exists at path/_brand.yml.
#
# Mirror image of write_brand_yml_for_quarto(). A Quarto-format file
# (nested light/dark colour values) needs converting regardless of
# `overwrite`, because bslib::bs_theme(brand = ) errors on it outright and
# the app would never start.
# --------------------------------------------------------------------------

write_brand_yml_for_shiny <- function(path, overwrite = FALSE) {
  brand_dest <- file.path(path, "_brand.yml")

  needs_conversion <- file.exists(brand_dest) &&
    !is_bslib_compatible_brand_yml(brand_dest)

  if (!file.exists(brand_dest) || overwrite || needs_conversion) {
    write_bslib_brand_yml(brand_dest)
    if (needs_conversion && !overwrite) {
      message(
        "Converted _brand.yml to bslib-compatible format (it was in the ",
        "Quarto format — nested light:/dark: colour values — which ",
        "bslib::bs_theme(brand = ) rejects)"
      )
    } else {
      message("Wrote _brand.yml (bslib-compatible)")
    }
    return(brand_dest)
  }

  message(
    "_brand.yml already exists and is bslib-compatible ",
    "(use overwrite = TRUE to regenerate)"
  )
  NULL
}

# A _brand.yml is usable by bslib as long as no colour value is a nested
# light/dark list. bslib tolerates the extra top-level color-dark: key
# that brandkit relies on for dark mode, and reads Bootstrap variables
# from defaults: bootstrap: defaults:, so neither of those disqualifies a
# file here.
is_bslib_compatible_brand_yml <- function(path) {
  cfg <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
  if (is.null(cfg)) return(FALSE)
  !any(vapply(cfg$color %||% list(), is.list, logical(1)))
}


# --------------------------------------------------------------------------
# Internal: convert any brand config to the bslib-compatible one.
#
# Inverse of quarto_brand_cfg(): unnests Quarto 1.8's per-key light/dark
# colour values back into a flat color: section plus bslib's separate
# color-dark: section.
#
# Bootstrap variables go under defaults: bootstrap: defaults: rather than
# the theme: key configure_brand() writes. brandkit reads either (see
# brand_init()), but bslib only reads the former — a theme: section is
# silently dropped by bs_theme(brand = ), so a configured border radius
# set there never reaches the compiled Bootstrap.
#
# `brand_dir` is the directory the resulting _brand.yml will live in —
# used to check that a referenced logo file actually exists there.
# `keep_logo` overrides that check for callers that know a logo is about
# to be written alongside, and also suppresses the advisory message.
# --------------------------------------------------------------------------

bslib_brand_cfg <- function(cfg,
                            brand_dir = dirname(brand_env$path),
                            keep_logo = NULL) {

  color_keys <- c("primary", "secondary", "success", "danger",
                  "warning", "info", "light", "dark",
                  "foreground", "background")

  light <- list()
  dark  <- as.list(cfg[["color-dark"]] %||% list())

  for (k in color_keys) {
    val <- cfg$color[[k]]
    if (is.null(val)) next

    if (is.list(val)) {
      # Quarto nested form — split it across the two sections. An
      # existing color-dark: entry wins, on the assumption that a file
      # carrying both was authored for bslib in the first place.
      if (!is.null(val[["light"]])) light[[k]] <- val[["light"]]
      if (!is.null(val[["dark"]]) && is.null(dark[[k]])) dark[[k]] <- val[["dark"]]
    } else {
      light[[k]] <- val
    }
  }

  if (!is.null(cfg$color$palette)) {
    light$palette <- cfg$color$palette
  }

  out <- list()
  if (!is.null(cfg$meta)) out$meta <- cfg$meta

  # Only reference a logo if its file(s) will actually be copied
  # alongside this _brand.yml — otherwise a stale or cross-project cache
  # can produce a scaffold that references a logo bslib can never find.
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

  if (length(light))            out$color        <- light
  if (length(dark))             out[["color-dark"]] <- dark
  if (!is.null(cfg$typography)) out$typography   <- cfg$typography

  bs_defaults <- cfg$theme %||% cfg$defaults$bootstrap$defaults
  if (length(bs_defaults)) {
    out$defaults <- list(bootstrap = list(defaults = bs_defaults))
  }

  out
}

write_bslib_brand_yml <- function(dest,
                                  cfg = brand_env$raw,
                                  brand_dir = dirname(brand_env$path),
                                  keep_logo = NULL) {
  yaml::write_yaml(bslib_brand_cfg(cfg, brand_dir, keep_logo), dest)
}


# --------------------------------------------------------------------------
# Internal: report suggested packages a template needs but that aren't
# installed. A message rather than an error — the files are already
# written and useful, the app just won't start until these are there.
# --------------------------------------------------------------------------

warn_missing_packages <- function(packages) {
  if (length(packages) == 0) return(invisible(NULL))

  missing <- packages[!vapply(
    packages, requireNamespace, logical(1), quietly = TRUE
  )]
  if (length(missing) == 0) return(invisible(NULL))

  message(
    "\nThis template needs ", paste0("'", missing, "'", collapse = ", "),
    ", which ", if (length(missing) == 1) "is" else "are", " not installed:"
  )
  message(
    '  install.packages(c(', paste0('"', missing, '"', collapse = ", "), '))'
  )

  invisible(missing)
}
