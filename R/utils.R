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
