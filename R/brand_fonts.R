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


# --------------------------------------------------------------------------
# Declare, per family, the faces a Google-sourced brand font must ship
#
# Quarto's Typst path fetches brand Google Fonts by building a Fonts v1
# CSS URL (`?family=<Family>[:<styles>][:<weights>]`), caching the returned
# faces under .quarto/typst-font-cache and handing Typst a --font-path.
# An entry declaring neither style nor weight produces a bare
# `?family=<Family>` request, which returns one face — upright, weight
# 400 — and nothing else.
#
# Typst synthesizes NOTHING: no faux-bold, and no faux-oblique either. A
# face that wasn't fetched simply doesn't exist, and the markup that asks
# for it degrades in silence — `**bold**` typesets at 400, `*italic*`
# typesets upright. Nor is a locally installed copy of the family a
# safety net: Typst reads only a variable font's default instance, so a
# system Inter-VariableFont exposes upright 400 alone. (Inter happens to
# ship a *separate* italic VF file, which is the only reason italics
# survived here before this function existed — an accident of one
# machine's font folder, not behaviour to rely on.)
#
# Both axes are therefore requested explicitly:
#
#   - styles: normal and italic, always. Prose can italicize anywhere, so
#     this isn't derivable from the brand the way weights are.
#   - weights: 400 and 700 unconditionally — the regular face, plus the
#     weight Typst's `strong` resolves to over body text (it applies a
#     +300 delta to the ambient 400) — plus every weight the brand
#     explicitly assigns that family, so `headings.weight: 800` fetches
#     an 800 face as well.
#
# Over-requesting is safe by design, which is what lets one rule cover
# every family including ones typed in by hand: asked for a style or
# weight it lacks, the v1 API answers 200 and omits that face. So a
# family with no italic at all (Quicksand, Outfit and Bungee are all
# like this) still comes back with its upright faces intact rather than
# erroring the render. The configurator's own pairings are curated to
# families that carry all three faces (see font_pairs in
# brand_configure.R), but a custom family typed into the wizard has no
# such guarantee, which is what this tolerance is for.
#
# Requesting styles and weights TOGETHER matters: a style-only request
# (`?family=Bungee:italic`) is a hard 400 for a family with no italic,
# and Quarto never checks the status — it scans the response for `src:`
# lines, finds none in the error body, and silently caches nothing at
# all. Combining the axes in the single request Quarto already builds
# keeps that failure mode out of reach.
#
# Known gap: italic-700 is unreachable. Google's v1 API only expresses
# bold-italic via the `400italic,700italic` weight spelling, which
# Quarto's schema rejects (weight is a strict enum of 100..900 and CSS
# keywords), and `:italic:700` returns italic-400 regardless. So
# `***bold italic***` renders italic-but-unbolded. That is a limitation
# of Quarto's URL builder, not something this function can route around.
# --------------------------------------------------------------------------

# brand.yml permits CSS keyword weights as well as numbers; anything
# unrecognised is dropped rather than coerced, so a typo can't smuggle an
# NA into the weight list and corrupt the generated URL.
as_font_weight <- function(w) {
  if (length(w) == 0) return(NULL)
  if (is.numeric(w)) return(as.integer(w))

  keywords <- c(thin = 100L, "extra-light" = 200L, ultralight = 200L,
                light = 300L, normal = 400L, regular = 400L, medium = 500L,
                "semi-bold" = 600L, semibold = 600L, bold = 700L,
                "extra-bold" = 800L, extrabold = 800L, black = 900L)

  num <- suppressWarnings(as.integer(w))
  resolved <- unname(ifelse(is.na(num), keywords[tolower(as.character(w))], num))
  resolved[!is.na(resolved)]
}

brand_font_weights <- function(family, typography) {
  roles <- list(typography$base, typography$headings, typography$monospace)

  assigned <- unlist(lapply(roles, function(role) {
    if (identical(role$family, family)) as_font_weight(role$weight) else NULL
  }))

  sort(unique(c(400L, 700L, assigned)))
}

# Fill in `style:` and `weight:` on every Google-sourced font entry that
# hasn't declared them. Each key is filled independently, and an explicit
# value is left untouched — an author who spelled the list out means it —
# which also makes this idempotent, so re-saving can't accumulate changes.
with_google_font_faces <- function(typography) {
  if (length(typography$fonts) == 0) return(typography)

  typography$fonts <- lapply(typography$fonts, function(f) {
    # Matches Quarto's own default (`_font.source ?? "google"`): an entry
    # with no source: is a Google font. `source: file` entries enumerate
    # their faces in files: and are left alone.
    if (!identical(f$source %||% "google", "google")) return(f)

    if (is.null(f$weight)) f$weight <- brand_font_weights(f$family, typography)
    if (is.null(f$style))  f$style  <- c("normal", "italic")
    f
  })

  typography
}
