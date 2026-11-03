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
  pt <- orn_swell_points(reach, bow)
  sprintf(
    'path d="M %s -10 L %s 0 Q %s %s %s %s T 100 %s L 110 %s L 110 -10 Z"',
    orn_num(pt$p0[1]), orn_num(pt$p0[1]),
    orn_num(pt$c1[1]), orn_num(pt$c1[2]),
    orn_num(pt$p1[1]), orn_num(pt$p1[2]),
    orn_num(reach), orn_num(reach)
  )
}

# The swell's anchor points: start on the top edge, the first control point,
# the joint between the two curves, and the end on the right edge. The
# second curve (`T`) reflects the first control point through the joint.
# Shared by orn_swell() and the label, which runs along the same curve.
orn_swell_points <- function(reach, bow = .14) {
  x0 <- 100 - reach
  k  <- reach * bow
  list(
    p0 = c(x0, 0),
    c1 = c(x0 + .25 * reach - k, .25 * reach + k),
    p1 = c(x0 + .5 * reach, .5 * reach),
    p2 = c(100, reach)
  )
}

# The drift motif's swell and its largest orb, named because the label is
# placed from them (see orn_label_svg()).
orn_drift_reach <- 74
orn_drift_orb   <- c(60, 38, 21)

orn_shapes <- function(motif) {
  switch(motif,
    drift = list(
      orn_shape(orn_swell(orn_drift_reach), 1.0, "p"),
      orn_shape(orn_orb(orn_drift_orb[1], orn_drift_orb[2], orn_drift_orb[3]),
                1.0, "s"),
      orn_shape(orn_orb(86, 62, 13),    1.2, "t"),
      orn_shape(orn_orb(30, 13, 8),     1.1, "s"),
      orn_shape(orn_orb(66, 74, 6),     1.4, "p")
    ),
    stop("Unknown ornament motif: ", sQuote(motif), call. = FALSE)
  )
}

orn_motifs <- "drift"

# --------------------------------------------------------------------------
# The label: a short line of text set along the swell, beside its largest
# orb. Top-right corner only, and only for the drift motif.
#
# The text runs along the swell's own curve, so it follows the wave rather
# than cutting across it, and sits on the side of that curve away from the
# wave — the part of the orb the swell does not cover. Letters laid on the
# overlap itself would sit on two stacked tints and lose contrast; here
# they sit on one.
#
# The baseline is offset from the curve by `dy`, a perpendicular shift in
# the glyphs' own frame, so it holds along the whole bend. It is centred on
# the point of the curve nearest the orb's centre. The size shrinks with the
# length of the text so it stays within the orb, down to a floor below
# which it would be too small to read at any scale this is drawn at.
# --------------------------------------------------------------------------

orn_label_max_chars <- 16

orn_xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

# Advance widths, in em, of capitals in a typical bold sans (Helvetica Bold's
# metrics), for laying letters out one at a time. A different heading face is
# a few percent narrower or wider, which the tracking absorbs.
orn_cap_width <- function(ch) {
  w <- c(A = .722, B = .722, C = .722, D = .722, E = .667, F = .611, G = .778,
         H = .722, I = .278, J = .556, K = .722, L = .611, M = .833, N = .722,
         O = .778, P = .667, Q = .778, R = .722, S = .667, T = .611, U = .722,
         V = .667, W = .944, X = .667, Y = .667, Z = .611,
         " " = .278, "&" = .722, "-" = .333, "." = .278, "'" = .238)
  out <- unname(w[ch])
  out[is.na(out)] <- .556   # digits and anything else
  out
}

# `layout = "path"` sets the whole line as one text-on-path element, which
# browsers lay out with the real font's metrics. `layout = "glyphs"` places
# each letter itself as a plain rotated <text>: Typst's SVG renderer spaces
# the letters of a text-on-path line unevenly (wide at the start, tight at
# the end, whatever the path is made of), but lays out a straight line of
# text exactly, so the files Typst draws get the second form.
orn_label_svg <- function(label, font, fill, vars = FALSE,
                          layout = c("path", "glyphs")) {
  layout <- match.arg(layout)
  label <- toupper(trimws(label))
  if (nchar(label) > orn_label_max_chars) {
    warning("Ornament label is longer than ", orn_label_max_chars,
            " characters; truncating it.", call. = FALSE)
    label <- substr(label, 1, orn_label_max_chars)
  }

  # Where the label goes: the swell's curve, and how far along it the orb's
  # centre falls, measured in arc length from the curve's start.
  pt <- orn_swell_points(orn_drift_reach)
  bez <- function(a, b, c, t) (1 - t)^2 * a + 2 * (1 - t) * t * b + t^2 * c
  t <- seq(0, 1, length.out = 401)
  c2 <- 2 * pt$p1 - pt$c1
  curve <- rbind(
    cbind(bez(pt$p0[1], pt$c1[1], pt$p1[1], t), bez(pt$p0[2], pt$c1[2], pt$p1[2], t)),
    cbind(bez(pt$p1[1], c2[1],    pt$p2[1], t), bez(pt$p1[2], c2[2],    pt$p2[2], t))[-1, ]
  )
  along <- c(0, cumsum(sqrt(rowSums(diff(curve)^2))))
  centre <- which.min((curve[, 1] - orn_drift_orb[1])^2 +
                      (curve[, 2] - orn_drift_orb[2])^2)

  # Capitals in a bold heading face run about 0.72em wide, plus the
  # tracking; the room is the chord of the orb at the label's offset.
  tracking <- 0.12
  size <- min(5.2, max(2.5, 34 / (nchar(label) * (0.72 + tracking))))

  path <- sprintf("M %s %s Q %s %s %s %s T %s %s",
                  orn_num(pt$p0[1]), orn_num(pt$p0[2]),
                  orn_num(pt$c1[1]), orn_num(pt$c1[2]),
                  orn_num(pt$p1[1]), orn_num(pt$p1[2]),
                  orn_num(pt$p2[1]), orn_num(pt$p2[2]))

  family <- paste0("'", gsub("['\"]", "", font), "', sans-serif")
  paint  <- if (vars) {
    sprintf('style="fill:var(--bs-primary,%s);font-family:%s"', fill, family)
  } else {
    sprintf('fill="%s" font-family="%s"', fill, family)
  }

  if (layout == "glyphs") {
    chars <- strsplit(label, "")[[1]]
    adv   <- orn_cap_width(chars)
    # Sized from the real advances rather than an average, and laid out with
    # the same tracking between letters as the path form.
    size  <- min(5.2, max(2.5, 34 / (sum(adv) + tracking * (length(chars) - 1))))
    pitch <- size * (adv + tracking)                 # advance + tracking, each
    total <- sum(pitch) - size * tracking
    # Arc-length position of each letter's centre, centred on the orb.
    mid <- along[centre] - total / 2 + cumsum(pitch) - pitch + size * adv / 2
    at <- function(s, v) stats::approx(along, v, xout = s, rule = 2)$y
    px <- at(mid, curve[, 1]); py <- at(mid, curve[, 2])
    # Tangent from a short step either side, so the angle is smooth.
    ang <- atan2(at(mid + .5, curve[, 2]) - at(mid - .5, curve[, 2]),
                 at(mid + .5, curve[, 1]) - at(mid - .5, curve[, 1])) * 180 / pi
    keep <- chars != " "
    glyphs <- sprintf(
      '<text transform="translate(%s %s) rotate(%s)" y="%s">%s</text>',
      orn_num(px[keep], 3), orn_num(py[keep], 3), orn_num(ang[keep], 2),
      orn_num(1.15 * size, 3), orn_xml_escape(chars[keep])
    )
    return(paste0(
      sprintf('<g %s font-size="%s" font-weight="700" fill-opacity="0.8" text-anchor="middle">',
              paint, orn_num(size)),
      "\n", paste(glyphs, collapse = "\n"), "\n</g>\n"
    ))
  }

  paste0(
    '<defs><path id="bk-orn-label" d="', path, '" fill="none"/></defs>
',
    sprintf(
      paste0('<text %s font-size="%s" font-weight="700" letter-spacing="%s" ',
             'fill-opacity="0.8" text-anchor="middle">',
             '<textPath href="#bk-orn-label" startOffset="%s">',
             '<tspan dy="%s">%s</tspan></textPath></text>'),
      paint, orn_num(size), orn_num(tracking * size, 3),
      orn_num(along[centre]), orn_num(1.15 * size), orn_xml_escape(label)
    ),
    "
"
  )
}

# The drawing itself, from explicit colours — brand_ornament() passes the
# brand's, and the configurator passes whatever is in its colour pickers, which
# are not saved to the brand yet. `primary` leads the top-right corner and
# `secondary` the bottom-left; `accent` is the same in both. With `vars`, the
# fills name Bootstrap's colour variables and the hex values are only the
# fallbacks (see brand_ornament()).
ornament_svg <- function(motif, corner, softness, primary, secondary, accent,
                         vars = FALSE, label = NULL, font = NULL,
                         label_layout = if (vars) "path" else "glyphs") {
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
  } else if (!is.null(label) && nzchar(trimws(label))) {
    # Top-right only. Appended after the shapes so it is drawn over them.
    body <- c(body, orn_label_svg(label, font %||% "sans-serif", primary, vars,
                                  layout = label_layout))
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
#' @param label Optional short text set along the swell of the `"top-right"`
#'   ornament, in capitals in the brand's heading font, beside its largest
#'   orb: a brand name or a tagline. It sits on the part of the orb the swell
#'   does not cover, and is ignored for `"bottom-left"`. Short text reads
#'   best, and anything over 16 characters is truncated. Defaults to the
#'   brand's `meta: ornament-label:` (which [configure_brand()] writes); `NULL`
#'   or `""` draws none.
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
                           label = brand_ornament_label(),
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
    vars      = vars,
    label     = label,
    font      = brand_fonts()$heading
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

# The brand's ornament label, or NULL. It lives under `meta:` because that is
# the one place in _brand.yml that Quarto's validation lets an extra key
# through (a new top-level section is rejected), and bslib and brand.yml
# read the file with the same schema.
brand_ornament_label <- function() {
  ensure_cache()
  label <- brand_env$meta[["ornament-label"]]
  if (is.character(label) && length(label) == 1 && !is.na(label) &&
      nzchar(trimws(label))) {
    trimws(label)
  } else {
    NULL
  }
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

# Writes the pair into `dir`, but only the files whose contents differ from
# what is already there (all of them with `overwrite`), and returns the paths
# it wrote. They are generated from the brand — colours and the label — so a
# plain re-run has to catch up with a changed brand, not leave stale files.
write_poster_ornaments <- function(dir, overwrite = FALSE) {
  paths <- file.path(dir, poster_ornament_files)
  corners <- c("top-right", "bottom-left")
  wrote <- character(0)
  for (i in seq_along(paths)) {
    svg <- brand_ornament("drift", corners[i], poster_ornament_softness)
    if (overwrite || !identical(read_file_bytes(paths[i]), charToRaw(svg))) {
      writeBin(charToRaw(svg), paths[i])
      wrote <- c(wrote, paths[i])
    }
  }
  wrote
}

# The file's bytes, or NULL if it does not exist.
read_file_bytes <- function(path) {
  if (!file.exists(path)) return(NULL)
  readBin(path, "raw", file.info(path)$size)
}

# The same pair for a Quarto page, as an HTML snippet that
# `include-after-body:` drops into the document. Unlike the poster's files
# these carry no hex colours (see `vars` in brand_ornament()), so the file
# never goes stale when the brand changes and follows Quarto's own
# light/dark toggle: each mode's stylesheet defines the --bs-* variables
# the ornaments are filled with.
#
# Colours never go stale, but the label does, so like the poster's files this
# is rewritten when its contents differ. Returns TRUE if it wrote the file.
write_ornaments_html <- function(path, overwrite = FALSE) {
  r <- htmltools::renderTags(brand_ornaments_tag())
  bytes <- charToRaw(paste0(r$head, "\n", r$html, "\n"))
  if (!overwrite && identical(read_file_bytes(path), bytes)) return(FALSE)
  writeBin(bytes, path)
  TRUE
}
