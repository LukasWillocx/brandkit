# --------------------------------------------------------------------------
# brandkit: brand_scaffold.R
# What the create_brand_*() scaffolds have in common: the project directory,
# copying the templates and brand assets into it, and the pieces of a
# _brand.yml that the Quarto and bslib dialects share.
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# The project directory: created if it is missing, resolved to a full path,
# and the brand cache pointed at that directory's own _brand.yml. Every
# scaffold starts here.
# --------------------------------------------------------------------------

scaffold_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    message("Created directory: ", path)
  }
  path <- normalizePath(path, mustWork = TRUE)
  ensure_cache_for_path(path)
  path
}


# --------------------------------------------------------------------------
# Copy a template out of the package's inst/ into the project, unless the
# destination exists and `overwrite` is off. `transform` may rewrite the
# lines on the way. Returns the destination if it wrote one, otherwise
# character(0), so callers can c() it straight onto their list.
# --------------------------------------------------------------------------

copy_template <- function(template, dest, overwrite, transform = NULL) {
  src <- system.file(template, package = "brandkit")
  if (!nzchar(src) || (file.exists(dest) && !overwrite)) return(character(0))

  if (is.null(transform)) {
    file.copy(src, dest, overwrite = overwrite)
  } else {
    writeLines(transform(readLines(src, warn = FALSE)), dest)
  }
  message("Copied ", basename(dest))
  dest
}

# The stylesheet and the pair of corner ornaments the HTML-based Quarto
# templates (report, slides, dashboard) share.
copy_drift_assets <- function(path, overwrite) {
  copied <- copy_template("quarto/drift.scss", file.path(path, "drift.scss"),
                          overwrite)

  orn_dest <- file.path(path, "_ornaments.html")
  if (write_ornaments_html(orn_dest, overwrite)) {
    copied <- c(copied, orn_dest)
    message("Wrote _ornaments.html")
  }
  copied
}

# Local font files and logo files the brand refers to, which have to sit
# next to the _brand.yml that names them.
copy_brand_assets <- function(path, overwrite) {
  copy_brand_fonts(path, overwrite)
  copy_brand_logo(path, overwrite)
  invisible(NULL)
}


# --------------------------------------------------------------------------
# Copy local font files referenced in _brand.yml
# --------------------------------------------------------------------------

copy_brand_fonts <- function(dest_dir, overwrite = FALSE) {
  fonts_raw <- brand_env$fonts$raw
  if (length(fonts_raw) == 0) return(invisible(NULL))

  brand_dir <- dirname(brand_env$path)

  for (fdef in fonts_raw) {
    if ((fdef$source %||% "google") != "file") next
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
# The logo files a brand.yml logo: section refers to: a bare string, or the
# small / medium / large entries, each a path or a {light, dark} pair.
# --------------------------------------------------------------------------

logo_paths <- function(logo) {
  if (is.character(logo)) return(logo)
  as.character(unique(unlist(lapply(logo[c("small", "medium", "large")], function(x) {
    if (is.character(x)) x else if (is.list(x)) c(x$light, x$dark)
  }))))
}


# --------------------------------------------------------------------------
# Check whether a brand.yml logo: section's referenced file(s) actually
# exist relative to the currently cached _brand.yml's directory.
# --------------------------------------------------------------------------

logo_files_exist <- function(logo, brand_dir = dirname(brand_env$path)) {
  paths <- logo_paths(logo)
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

  for (p in logo_paths(logo)) {
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
# The parts of converting a _brand.yml between the bslib and Quarto
# dialects that do not depend on the dialect (see bslib_brand_cfg() and
# quarto_brand_cfg()).
# --------------------------------------------------------------------------

brand_color_keys <- c("primary", "secondary", "success", "danger",
                      "warning", "info", "light", "dark",
                      "foreground", "background")

# The logo: section for a converted _brand.yml, or NULL to leave it out. A
# logo is only referenced if its file(s) will actually sit alongside the
# written _brand.yml, because a stale or cross-project cache would otherwise
# produce a scaffold that points at a logo nothing can find. `keep_logo`
# overrides the on-disk check for callers that know a logo is about to be
# written (the configurator), and also suppresses the advisory message.
convert_logo <- function(cfg, brand_dir, keep_logo = NULL) {
  if (is.null(cfg$logo)) return(NULL)
  if (keep_logo %||% logo_files_exist(cfg$logo, brand_dir)) return(cfg$logo)

  if (is.null(keep_logo)) {
    message(
      "Note: the cached brand references a logo, but its file could ",
      "not be found \u2014 omitting logo: from _brand.yml. Run ",
      "configure_brand() in this project (or copy the logo file in ",
      "manually) if you want a logo here."
    )
  }
  NULL
}
