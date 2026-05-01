# --------------------------------------------------------------------------
# brandkit: brand_cache.R
# Package-level environment for caching parsed _brand.yml data.
# Parsed once on load, shared by all downstream functions.
# --------------------------------------------------------------------------

#' @keywords internal
brand_env <- new.env(parent = emptyenv())

# ---------------------------------------------------------------------------
# Initialise cache from a _brand.yml path
# ---------------------------------------------------------------------------

#' Initialise the Brand Cache
#'
#' Reads `_brand.yml`, validates required sections, and populates the
#' package-level cache. Called automatically in `.onLoad` but can be
#' called manually to point at a different file (e.g. during
#' configurator preview).
#'
#' @param path Path to a `_brand.yml` file. If `NULL`, searches the
#'   current working directory, then `inst/` inside the package.
#' @param quiet Logical. Suppress informational messages.
#'
#' @return Invisibly returns the parsed brand list.
#' @export
brand_init <- function(path = NULL, quiet = FALSE) {

 path <- path %||% find_brand_yml()

 if (is.null(path) || !file.exists(path)) {
   stop(
     "No _brand.yml found. Run `brandkit::configure_brand()` to create one, ",
     "or pass a path explicitly.",
     call. = FALSE
   )
 }

 cfg <- yaml::read_yaml(path)

 # Helper: resolve a colour value that may be a plain string "#hex" or
 # a Quarto 1.8 nested list {light: "#hex", dark: "#hex"}.
 resolve_col <- function(val, mode = "light", fallback = NULL) {
   if (is.null(val)) return(fallback)
   if (is.list(val)) return(val[[mode]] %||% val[["light"]] %||% fallback)
   val
 }

 # --- Colours (light) ---
 brand_env$colors <- list(
   primary    = resolve_col(cfg$color$primary, "light"),
   secondary  = resolve_col(cfg$color$secondary, "light"),
   success    = resolve_col(cfg$color$success, "light", "#198754"),
   danger     = resolve_col(cfg$color$danger, "light", "#dc3545"),
   warning    = resolve_col(cfg$color$warning, "light", "#ffc107"),
   info       = resolve_col(cfg$color$info, "light", "#0d6efd"),
   light      = resolve_col(cfg$color$light, "light", "#f8f9fa"),
   dark       = resolve_col(cfg$color$dark, "light", "#212529"),
   foreground = resolve_col(cfg$color$foreground, "light") %||%
                resolve_col(cfg$color$dark, "light") %||% "#212529",
   background = resolve_col(cfg$color$background, "light") %||%
                resolve_col(cfg$color$light, "light") %||% "#f8f9fa"
 )

 # --- Colours (dark) ---
 # Support both bslib format (separate color-dark: section) and
 # Quarto 1.8 format (nested light/dark under each key).
 dk_section <- cfg[["color-dark"]]
 if (!is.null(dk_section)) {
   brand_env$colors_dark <- dk_section
 } else {
   # Check if any colour has a dark variant (Quarto nested format)
   has_dark <- any(vapply(cfg$color, function(v) {
     is.list(v) && !is.null(v[["dark"]])
   }, logical(1)))
   if (has_dark) {
     brand_env$colors_dark <- list(
       primary    = resolve_col(cfg$color$primary, "dark"),
       secondary  = resolve_col(cfg$color$secondary, "dark"),
       success    = resolve_col(cfg$color$success, "dark"),
       danger     = resolve_col(cfg$color$danger, "dark"),
       warning    = resolve_col(cfg$color$warning, "dark"),
       info       = resolve_col(cfg$color$info, "dark"),
       light      = resolve_col(cfg$color$light, "dark"),
       dark       = resolve_col(cfg$color$dark, "dark"),
       foreground = resolve_col(cfg$color$foreground, "dark"),
       background = resolve_col(cfg$color$background, "dark")
     )
   } else {
     brand_env$colors_dark <- NULL
   }
 }

 # --- Typography ---
 fonts_raw <- cfg$typography$fonts %||% list()
 families  <- vapply(fonts_raw, function(f) f$family %||% "sans", character(1))

 fam1 <- if (length(families) >= 1) families[1] else "sans"
 fam2 <- if (length(families) >= 2) families[2] else fam1

 brand_env$fonts <- list(
   base    = cfg$typography$base$family     %||% fam1,
   heading = cfg$typography$headings$family  %||% fam2,
   all     = if (length(families)) families else "sans",
   raw     = fonts_raw
 )

 brand_env$typography <- cfg$typography

 # --- Theme / Bootstrap overrides ---
 brand_env$theme_vars <- cfg$theme %||% list()

 # --- Logo ---
 brand_env$logo <- cfg$logo %||% list()

 # --- Meta ---
 brand_env$meta <- cfg$meta %||% list()

 # --- Full config (escape hatch) ---
 brand_env$raw   <- cfg
 brand_env$path  <- normalizePath(path)
 brand_env$ready <- TRUE

 if (!quiet) {
   message(
     "brandkit: loaded brand '",
     brand_env$meta$name %||% "unnamed",
     "' from ", brand_env$path
   )
 }

 invisible(cfg)
}

# ---------------------------------------------------------------------------
# Accessors — thin wrappers so callers don't touch brand_env directly
# ---------------------------------------------------------------------------

#' Get Cached Brand Colours
#'
#' @param mode `"light"` or `"dark"`.
#' @return Named list of hex colour values.
#' @export
brand_colors <- function(mode = c("light", "dark")) {
 ensure_cache()
 mode <- match.arg(mode)
 if (mode == "dark" && !is.null(brand_env$colors_dark)) {
   dk <- brand_env$colors_dark
   return(list(
     primary    = dk$primary,
     secondary  = dk$secondary,
     success    = dk$success   %||% brand_env$colors$success,
     danger     = dk$danger    %||% brand_env$colors$danger,
     warning    = dk$warning   %||% brand_env$colors$warning,
     info       = dk$info      %||% brand_env$colors$info,
     light      = dk$light     %||% brand_env$colors$light,
     dark       = dk$dark      %||% brand_env$colors$dark,
     foreground = dk$foreground %||% dk$dark  %||% brand_env$colors$foreground,
     background = dk$background %||% dk$light %||% brand_env$colors$background
   ))
 }
 brand_env$colors
}

#' Get Cached Brand Fonts
#'
#' @return Named list with `base`, `heading`, `all`, and `raw`.
#' @export
brand_fonts <- function() {
 ensure_cache()
 brand_env$fonts
}

#' Get Raw Brand Config
#'
#' Escape hatch for anything not covered by the convenience accessors.
#'
#' @return The full parsed YAML list.
#' @export
brand_raw <- function() {
 ensure_cache()
 brand_env$raw
}

#' Get Brand Logo Path
#'
#' Returns the resolved file path to the brand logo. Tries `medium`,
#' then `small`, then `large`, then a bare string.
#'
#' @param size `"medium"`, `"small"`, or `"large"`.
#' @return Absolute file path to the logo, or `NULL` if none configured.
#' @export
brand_logo <- function(size = "medium") {
 ensure_cache()
 logo <- brand_env$logo
 if (length(logo) == 0) return(NULL)

 # Bare string: logo: "path/to/logo.png"
 if (is.character(logo)) {
   path <- logo
 } else {
   path <- logo[[size]] %||% logo$medium %||% logo$small %||% logo$large
 }

 if (is.null(path)) return(NULL)

 # Resolve relative to _brand.yml location
 base_dir <- dirname(brand_env$path)
 full <- file.path(base_dir, path)
 if (file.exists(full)) return(normalizePath(full))

 # Try as-is
 if (file.exists(path)) return(normalizePath(path))

 NULL
}

#' Build Logo HTML Tag for Shiny Titles
#'
#' Returns an `img` tag sized for inline use next to a title, or `NULL`
#' if no logo is configured.
#'
#' @param height CSS height. Default `"1.8em"`.
#' @param size Which logo size to use from `_brand.yml`.
#'
#' @return An `htmltools::img()` tag or `NULL`.
#' @export
brand_logo_tag <- function(height = "1.8em", size = "medium") {
 logo_path <- brand_logo(size)
 if (is.null(logo_path)) return(NULL)

 # Serve via Shiny resource path
 if (requireNamespace("shiny", quietly = TRUE)) {
   logo_dir  <- dirname(logo_path)
   logo_file <- basename(logo_path)
   shiny::addResourcePath("brandkit-logo", logo_dir)
   return(htmltools::img(
     src = paste0("brandkit-logo/", logo_file),
     style = paste0(
       "height:", height, "; vertical-align: middle; margin-right: 8px;"
     )
   ))
 }

 NULL
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

ensure_cache <- function() {
 if (!isTRUE(brand_env$ready)) {
   brand_init(quiet = TRUE)
 }
}

find_brand_yml <- function() {
 # 1. Working directory (+ parent walk like bslib does)
 candidates <- c(
   "_brand.yml", "_brand.yaml",
   "_brand/_brand.yml", "brand/_brand.yml"
 )
 dir <- getwd()
 for (i in seq_len(10)) {
   hits <- file.path(dir, candidates)
   found <- hits[file.exists(hits)]
   if (length(found)) return(found[1])
   parent <- dirname(dir)
   if (parent == dir) break
   dir <- parent
 }

 # 2. Package inst/ (for bundled brands shipped with an R package)
 pkg_path <- system.file("_brand.yml", package = "brandkit")
 if (nzchar(pkg_path)) return(pkg_path)

 NULL
}

# %||% imported from rlang via NAMESPACE
