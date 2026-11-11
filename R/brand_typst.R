# --------------------------------------------------------------------------
# brandkit: brand_typst.R
# The Typst format extension behind the brandkit PDF templates: the generated
# _extension.yml, the CSS-to-Typst unit conversions, the poster's type scale,
# and the copy of the extension into a project.
# --------------------------------------------------------------------------

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
                                           poster = NULL, drift = FALSE) {
  # The poster is a drift layout with columns and cards on top.
  drift <- isTRUE(drift) || !is.null(poster)

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
    `code-radius` = radius,
    # Sets inline code as plain text rather than `raw`, which is what lets it
    # differ from a fenced block; see inline-code.lua. Every format has it.
    filters = list("inline-code.lua")
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

  # Selects the plain masthead and the corner-ornament background in
  # page.typ, in place of the striped panel. Written only when TRUE, for
  # the same reason as banner-inset.
  if (drift) {
    typst_fmt$drift <- TRUE
    # The corner ornaments page.typ draws as the page background. Quarto
    # copies format-resources next to the rendered document, which is
    # what lets page.typ name them without a path: the compiled .typ sits
    # beside the document, wherever in the project that is, whereas the
    # extension directory is only a fixed distance away for documents at
    # the project root.
    typst_fmt$`format-resources` <- as.list(typst_ornament_files)
  }

  if (!is.null(poster)) {
    typst_fmt$papersize <- poster$paper
    typst_fmt$poster <- TRUE
    typst_fmt$`poster-scale` <- type_scale
    # Read by typst-show.typ as the *flow* column count, not Typst page
    # columns — page.typ's poster branch pins those to 1. Overridable
    # per document from the .qmd YAML like any other format option.
    typst_fmt$columns <- poster$columns
    # Groups each level-2 section into a card panel; see poster.lua.
    typst_fmt$filters <- c(typst_fmt$filters, list("poster.lua"))
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
    title = if (!is.null(poster)) {
      "brandkit Typst Poster"
    } else if (drift) {
      "brandkit Typst Print Report"
    } else {
      "brandkit Typst Report"
    },
    author = "brandkit",
    version = "1.0.0",
    `quarto-required` = ">=1.8.0",
    contributes = list(formats = list(typst = typst_fmt))
  )

  yaml::write_yaml(cfg, dest)
}

# Bring the brand-derived values of an existing _extension.yml back in line
# with the current brand, leaving every other key as the user has it. These
# are the only values write_extension_yml_for_quarto() computes from the
# brand: the base font size (and, for the poster, the scale and logo width
# that follow from it) and the code-block corner radius. Returns the names
# of the keys that changed; the file is only rewritten when some did.
sync_extension_yml_brand_values <- function(dest, banner_inset = FALSE,
                                            poster = NULL, drift = FALSE) {
  old <- tryCatch(yaml::read_yaml(dest), error = function(e) NULL)
  old_typst <- old$contributes$formats$typst
  if (is.null(old_typst)) return(character(0))

  fresh <- tempfile(fileext = ".yml")
  on.exit(unlink(fresh), add = TRUE)
  write_extension_yml_for_quarto(fresh, banner_inset = banner_inset,
                                 poster = poster, drift = drift)
  new_typst <- yaml::read_yaml(fresh)$contributes$formats$typst

  changed <- character(0)
  for (key in c("fontsize", "code-radius", "poster-scale")) {
    if (!identical(old_typst[[key]], new_typst[[key]])) {
      old_typst[[key]] <- new_typst[[key]]
      changed <- c(changed, key)
    }
  }
  if (!identical(old_typst$logo$width, new_typst$logo$width) &&
      !is.null(old_typst$logo)) {
    old_typst$logo$width <- new_typst$logo$width
    changed <- c(changed, "logo width")
  }

  if (length(changed)) {
    old$contributes$formats$typst <- old_typst
    yaml::write_yaml(old, dest)
  }
  changed
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
                                 poster = NULL, drift = FALSE) {
  drift <- isTRUE(drift) || !is.null(poster)
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
                                   poster = poster, drift = drift)
    copied <- c(copied, ext_yml_dest)
    message("Wrote _extensions/", ext_name, "/_extension.yml")
  } else {
    # Left alone otherwise, so hand edits (margins, extra options) survive
    # a re-run — but the brand-derived values in it go stale the moment the
    # brand changes, and a stale `fontsize:` wins over _brand.yml in
    # typst-show.typ, so a new base size would silently never reach the PDF.
    changed <- sync_extension_yml_brand_values(
      ext_yml_dest, banner_inset = banner_inset, poster = poster, drift = drift
    )
    if (length(changed)) {
      copied <- c(copied, ext_yml_dest)
      message(
        "Updated ", paste(changed, collapse = ", "), " in _extensions/",
        ext_name, "/_extension.yml to match the brand ",
        "(use overwrite = TRUE to regenerate the whole file)"
      )
    }
  }

  # The corner ornaments are generated like _extension.yml, and for the
  # same reason: they are drawn in the brand's colours, which only the
  # R side knows. The drift layouts only (the poster and the print report);
  # the full-bleed report keeps the striped banner.
  if (drift) {
    wrote <- write_typst_ornaments(ext_dest_dir, overwrite)
    if (length(wrote)) {
      copied <- c(copied, wrote)
      message("Wrote _extensions/", ext_name, "/ ", paste(basename(wrote), collapse = ", "))
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
