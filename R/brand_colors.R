# --------------------------------------------------------------------------
# brandkit: brand_colors.R
# Palette generation — everything derived from the brand, nothing hardcoded.
# --------------------------------------------------------------------------

#' Sequential Palette
#'
#' @param type `"warm"`, `"cool"`, or `"green"`.
#' @param n Number of colours (default 9).
#' @param reverse Flip direction.
#' @param mode `"light"` or `"dark"`.
#' @return Character vector of hex codes.
#' @export
brand_pal_seq <- function(type = "warm", n = 9, reverse = FALSE,
                          mode = "light") {
  cols <- brand_colors(mode)
  anchors <- switch(type,
    warm  = c(cols$background, cols$primary, cols$danger),
    cool  = c(cols$background, cols$info,    cols$secondary),
    green = c(cols$background, cols$success, cols$dark),
    stop("type must be 'warm', 'cool', or 'green'", call. = FALSE)
  )
  pal <- grDevices::colorRampPalette(anchors)(n)
  if (reverse) rev(pal) else pal
}

#' Diverging Palette
#'
#' Cool → neutral → warm gradient.
#'
#' @param n Number of colours (default 11, use odd for a neutral midpoint).
#' @param reverse Flip direction.
#' @param mode `"light"` or `"dark"`.
#' @return Character vector of hex codes.
#' @export
brand_pal_div <- function(n = 11, reverse = FALSE, mode = "light") {
  cols <- brand_colors(mode)
  anchors <- c(
    cols$info,       # cool end
    cols$secondary,
    cols$background, # neutral midpoint
    cols$primary,
    cols$danger      # warm end
  )
  pal <- grDevices::colorRampPalette(anchors)(n)
  if (reverse) rev(pal) else pal
}

#' Discrete Palette (Algorithmically Derived)
#'
#' Starts with brand semantic colours, then fills remaining slots by
#' rotating hue from the primary in perceptually-uniform HCL space.
#' No hardcoded hex values.
#'
#' @param n Number of colours needed. `NULL` returns all (up to 15).
#' @param mode `"light"` or `"dark"`.
#' @return Character vector of hex codes.
#' @export
brand_pal_discrete <- function(n = NULL, mode = "light") {
  cols <- brand_colors(mode)
  max_n <- 15

  # Tier 1: brand semantic colours (guaranteed distinct in the brand)
  base <- c(
    cols$primary, cols$secondary, cols$success,
    cols$warning, cols$danger,    cols$info
  )
  base <- unique(base)

  # Tier 2: fill to max_n via HCL hue rotation from primary
  need <- max_n - length(base)
  if (need > 0) {
    hcl_primary <- as(colorspace::hex2RGB(cols$primary), "polarLUV")
    base_hue    <- hcl_primary@coords[1, "H"]
    base_c      <- hcl_primary@coords[1, "C"]
    base_l      <- hcl_primary@coords[1, "L"]
    # Clamp chroma and luminance for readability
    gen_c <- min(base_c, 70)
    gen_l <- if (mode == "dark") min(base_l + 15, 80) else max(base_l - 5, 45)

    offsets <- seq(360 / (need + 1), 360, length.out = need)
    generated <- vapply(offsets, function(off) {
      h <- (base_hue + off) %% 360
      colorspace::hex(colorspace::polarLUV(gen_l, gen_c, h))
    }, character(1))

    base <- c(base, generated)
  }

  base <- base[seq_len(max_n)]

  if (is.null(n)) return(base)
  if (n > max_n) {
    warning("Max ", max_n, " discrete colours available.", call. = FALSE)
    n <- max_n
  }
  base[seq_len(n)]
}
