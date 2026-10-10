# --------------------------------------------------------------------------
# brandkit: brand_ornaments.R
# Soft geometric corner ornaments, drawn as SVG from the brand's colours.
#
# One geometry per motif, defined in a 100 x 100 box with the anchor corner
# at the top-right (100, 0). Everything else is applied at render time: the
# bottom-left corner is the same drawing rotated 180 degrees, the size is
# whatever the caller scales the box to, and the colours are the brand's.
# Nothing reaches further than about three quarters of the way into the box,
# so an ornament frames a corner instead of washing the whole quadrant.
#
# "Soft" is transparency rather than a pale colour: every shape is filled
# with a full brand colour at a low opacity, so the shades come from shapes
# stacking where they overlap. That keeps the file independent of whatever
# it is drawn over (a card, a dark page) and means one `softness` value
# controls the whole drawing.
# --------------------------------------------------------------------------

# Compact number formatting: "100.00" -> "100", "0.50" -> "0.5".
orn_num <- function(x, digits = 2) {
  sub("\\.?0+$", "", sprintf(paste0("%.", digits, "f"), x))
}

# A shape is an SVG element (tag and geometry attributes, no fill), an
# opacity multiplier relative to `softness`, and a colour role:
#   p = the corner's lead colour, s = its partner, t = the accent.
orn_shape <- function(el, m = 1, role = "p") list(el = el, m = m, role = role)

orn_orb <- function(cx, cy, r) {
  sprintf('circle cx="%s" cy="%s" r="%s"', orn_num(cx), orn_num(cy), orn_num(r))
}

# A swell anchored in the corner: an S-curve from the top edge to the right
# edge, bowing away from the corner in its first half and towards it in the
# second, closed off outside the box so only the curve is ever visible.
orn_swell <- function(reach, bow = .14) {
  x0 <- 100 - reach
  k  <- reach * bow
  sprintf(
    'path d="M %s -10 L %s 0 Q %s %s %s %s T 100 %s L 110 %s L 110 -10 Z"',
    orn_num(x0), orn_num(x0),
    orn_num(x0 + .25 * reach - k), orn_num(.25 * reach + k),
    orn_num(x0 + .5 * reach), orn_num(.5 * reach),
    orn_num(reach), orn_num(reach)
  )
}

orn_shapes <- function(motif) {
  switch(motif,
    drift = list(
      orn_shape(orn_swell(74),          1.0, "p"),
      orn_shape(orn_orb(60, 38, 21),    1.0, "s"),
      orn_shape(orn_orb(86, 62, 13),    1.2, "t"),
      orn_shape(orn_orb(30, 13, 8),     1.1, "s"),
      orn_shape(orn_orb(66, 74, 6),     1.4, "p")
    ),
    stop("Unknown ornament motif: ", sQuote(motif), call. = FALSE)
  )
}

orn_motifs <- "drift"

# The drawing itself, from explicit colours — brand_ornament() passes the
# brand's, and the configurator passes whatever is in its colour pickers, which
# are not saved to the brand yet. `primary` leads the top-right corner and
# `secondary` the bottom-left; `accent` is the same in both. With `vars`, the
# fills name Bootstrap's colour variables and the hex values are only the
# fallbacks (see brand_ornament()).
ornament_svg <- function(motif, corner, softness, primary, secondary, accent,
                         vars = FALSE) {
  hue <- if (corner == "top-right") {
    list(p = primary,   s = secondary, t = accent)
  } else {
    list(p = secondary, s = primary,   t = accent)
  }

  # Which Bootstrap variable stands for each hex, so that swapping the two
  # corners' lead colours above swaps the variables with them.
  css_var <- c(p = "--bs-primary", s = "--bs-secondary", t = "--bs-info")
  if (corner == "bottom-left") css_var[c("p", "s")] <- css_var[c("s", "p")]

  body <- vapply(orn_shapes(motif), function(s) {
    opacity <- orn_num(min(1, softness * s$m), 3)
    if (vars) {
      # The colour goes in `style` because var() is not valid in a
      # presentation attribute; the hex after the comma is the fallback for
      # a page that defines no Bootstrap variables.
      sprintf('<%s style="fill:var(%s,%s)" fill-opacity="%s"/>',
              s$el, css_var[[s$role]], hue[[s$role]], opacity)
    } else {
      sprintf('<%s fill="%s" fill-opacity="%s"/>', s$el, hue[[s$role]], opacity)
    }
  }, character(1))

  if (corner == "bottom-left") {
    body <- c('<g transform="rotate(180 50 50)">', body, "</g>")
  }

  paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" ',
    'width="100" height="100">
',
    paste(body, collapse = "
"),
    "
</svg>
"
  )
}

#' Brand Corner Ornament (SVG)
#'
#' Draws a soft geometric corner ornament in the brand's colours and returns
#' it as an SVG string, optionally writing it to a file. The ornaments are
#' designed to sit in the top-right and bottom-left corners of a page,
#' behind the content, at a low opacity.
#'
#' The drawing is one 100 x 100 unit square with its anchor in a corner and
#' no fixed size: scale it by sizing the box it is placed in. A good size
#' is a fixed fraction of the page's shorter side, so the proportions hold
#' from a letter page to an A0 poster.
#'
#' Each shape is filled with a brand colour at a low opacity, so the shades
#' come from shapes overlapping rather than from pale colours. This keeps an
#' ornament usable over any background, light or dark.
#'
#' The two corners lead with different colours so a page is balanced rather
#' than mirrored: `"top-right"` leads with the brand's primary colour and
#' `"bottom-left"` with its secondary, each with the other as its partner.
#' The accent in both is the brand's `info` colour.
#'
#' @param motif Name of the motif. Currently `"drift"`: one soft swell
#'   anchored in the corner, with orbs of the other brand colours
#'   straddling its edge and a few floating loose.
#' @param corner Which corner the ornament is for, `"top-right"` (the
#'   drawing as designed) or `"bottom-left"` (rotated 180 degrees, with the
#'   lead and partner colours swapped).
#' @param softness Opacity of a single shape, between 0 and 1. Overlaps
#'   build up from this, so useful values are small; the default is `0.17`.
#' @param mode `"light"` or `"dark"`: which of the brand's palettes to draw
#'   with.
#' @param file Optional path. If given, the SVG is also written there.
#' @param vars Logical. `FALSE` (default) writes the brand colours into the
#'   SVG as hex values, which is what a standalone file, an `<img>` or a
#'   Typst `image()` needs. `TRUE` writes them as Bootstrap's CSS variables
#'   (`--bs-primary`, `--bs-secondary`, `--bs-info`) instead, with the hex
#'   values as fallbacks. That only works for SVG placed *inline* in a web
#'   page, where the variables resolve against the page, but there it
#'   follows a light/dark toggle with no redraw; see
#'   [brand_ornaments_tag()]. `mode` only chooses the fallbacks then.
#'
#' @return The SVG as a single character string; invisibly, when `file` is
#'   given.
#'
#' @examples
#' \dontrun{
#' cat(brand_ornament("drift", "top-right"))
#' brand_ornament("drift", "bottom-left", file = "corner.svg")
#' }
#' @export
brand_ornament <- function(motif = "drift",
                           corner = c("top-right", "bottom-left"),
                           softness = 0.17,
                           mode = c("light", "dark"),
                           file = NULL,
                           vars = FALSE) {

  motif  <- match.arg(motif, orn_motifs)
  corner <- match.arg(corner)
  mode   <- match.arg(mode)
  if (!is.numeric(softness) || length(softness) != 1 ||
      is.na(softness) || softness <= 0 || softness > 1) {
    stop("`softness` must be a single number above 0 and at most 1.",
         call. = FALSE)
  }

  cols <- brand_colors(mode)
  svg <- ornament_svg(
    motif, corner, softness,
    primary   = cols$primary,
    secondary = cols$secondary %||% cols$primary,
    accent    = cols$info %||% cols$secondary %||% cols$primary,
    vars      = vars
  )

  if (!is.null(file)) {
    # Raw bytes rather than writeLines(): the string is plain ASCII, and a
    # text-mode write would turn each newline into CRLF on Windows, so the
    # same call would produce different files on different platforms.
    writeBin(charToRaw(svg), file)
    return(invisible(svg))
  }
  svg
}

# `t` of colour `a` mixed into colour `b`, as a hex string: the same mix the
# poster's cards make with Typst's color.mix(), done in R so a page can be
# handed a plain, opaque colour.
orn_mix <- function(a, b, t) {
  m <- round(t * grDevices::col2rgb(a) + (1 - t) * grDevices::col2rgb(b))
  grDevices::rgb(m[1], m[2], m[3], maxColorValue = 255)
}

# Web size and softness. The softness sits between the poster's and the
# default: a browser window is read at arm's length like a page, but the
# ornament is fixed to the viewport corner rather than stretched over a
# sheet, so it does not need the poster's extra restraint.
web_ornament_softness <- 0.14

#' Corner Ornaments for a Web Page
#'
#' Returns the pair of corner ornaments from [brand_ornament()] as HTML
#' ready to place in a Shiny UI: two inline SVGs fixed to the top-right and
#' bottom-left corners of the browser window, behind the page content, sized
#' to a fraction of the window's shorter side. The brand colours are
#' Bootstrap CSS variables, so the ornaments follow a light/dark toggle
#' (such as [bslib::input_dark_mode()]) with no redraw.
#'
#' The page-level wrappers use this for `style = "drift"`; call it directly
#' to add the ornaments to a page you are building by hand. It needs a
#' Bootstrap 5 page (for the variables) whose body background is painted on
#' the page itself, which is how [bslib::page()] and its relatives work.
#'
#' @inheritParams brand_ornament
#' @param softness Opacity of a single shape; see [brand_ornament()].
#'
#' @return An [htmltools::tagList()].
#'
#' @examples
#' \dontrun{
#' bslib::page_fluid(brand_ornaments_tag(), "Content")
#' }
#' @export
brand_ornaments_tag <- function(motif = "drift", softness = web_ornament_softness) {
  ensure_cache()

  inline <- function(corner) {
    svg <- brand_ornament(motif, corner, softness, vars = TRUE)
    # Sized by the wrapper's CSS, and hidden from assistive technology: it
    # is decoration.
    svg <- sub('width="100" height="100"',
               'class="bk-ornament-svg" aria-hidden="true" focusable="false"',
               svg, fixed = TRUE)
    htmltools::div(
      class = paste0("bk-ornament bk-ornament-",
                     if (corner == "top-right") "tr" else "bl"),
      htmltools::HTML(svg)
    )
  }

  htmltools::tagList(
    htmltools::tags$head(htmltools::tags$style(htmltools::HTML(paste(
      # z-index -1 puts them above the page's own background but below
      # everything in the flow, so no content needs a stacking context of
      # its own to stay on top, and pointer-events keeps them from ever
      # being the thing a click lands on.
      ".bk-ornament { position: fixed; z-index: -1; pointer-events: none;",
      "  width: 32vmin; height: 32vmin; }",
      ".bk-ornament-tr { top: 0; right: 0; }",
      ".bk-ornament-bl { bottom: 0; left: 0; }",
      ".bk-ornament-svg { display: block; width: 100%; height: 100%; }",
      "@media print { .bk-ornament { display: none; } }",
      sep = "
"
    )))),
    inline("top-right"),
    inline("bottom-left")
  )
}

# The two files the poster extension ships. Named for the corner rather
# than the motif so page.typ does not have to change when the motif does.
#
# Softer than brand_ornament()'s default. The default was tuned on page-
# sized mock-ups, where the shapes are small; stretched across an A0 sheet
# the same opacity reads as large flat blocks of colour behind the text,
# so the poster takes a lower one.
poster_ornament_softness <- 0.12

poster_ornament_files <- c(
  "drift-top-right.svg",
  "drift-bottom-left.svg"
)

write_poster_ornaments <- function(dir) {
  paths <- file.path(dir, poster_ornament_files)
  brand_ornament("drift", "top-right",   poster_ornament_softness, file = paths[1])
  brand_ornament("drift", "bottom-left", poster_ornament_softness, file = paths[2])
  paths
}

# The same pair for a Quarto page, as an HTML snippet that
# `include-after-body:` drops into the document. Unlike the poster's files
# these carry no hex colours (see `vars` in brand_ornament()), so the file
# never goes stale when the brand changes and follows Quarto's own
# light/dark toggle: each mode's stylesheet defines the --bs-* variables
# the ornaments are filled with.
write_ornaments_html <- function(path) {
  r <- htmltools::renderTags(brand_ornaments_tag())
  writeBin(charToRaw(paste0(r$head, "\n", r$html, "\n")), path)
  invisible(path)
}
