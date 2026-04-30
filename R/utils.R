# --------------------------------------------------------------------------
# brandkit: utils.R
# Shared utility functions.
# --------------------------------------------------------------------------

#' Convert Hex to "r, g, b" String
#' @keywords internal
hex_to_rgb_str <- function(hex) {
  rgb <- grDevices::col2rgb(hex)
  paste(rgb[1], rgb[2], rgb[3], sep = ", ")
}

#' Convert Hex to rgba() String
#' @keywords internal
hex_to_rgba <- function(hex, alpha = 1) {
  rgb <- grDevices::col2rgb(hex)
  sprintf("rgba(%s, %s, %s, %s)", rgb[1], rgb[2], rgb[3], alpha)
}

#' Lighten or Darken a Hex Colour
#'
#' Thin wrapper around colorspace for palette derivation.
#' @param hex Hex colour string.
#' @param amount Positive = lighten, negative = darken. Range roughly -1 to 1.
#' @keywords internal
shift_color <- function(hex, amount) {
  if (amount >= 0) {
    colorspace::lighten(hex, amount = amount)
  } else {
    colorspace::darken(hex, amount = abs(amount))
  }
}
