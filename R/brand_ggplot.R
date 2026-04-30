# --------------------------------------------------------------------------
# brandkit: brand_ggplot.R
# ggplot2 theme + convenience scales. Auto-applied via .onAttach.
# --------------------------------------------------------------------------

#' Branded ggplot2 Theme
#'
#' Clean, transparent-background theme that reads colours and fonts
#' from the brand cache. Works inside Shiny dashboards and standalone.
#'
#' @param base_size Base font size in points.
#' @param mode `"light"` or `"dark"`.
#'
#' @return A `ggplot2::theme` object.
#' @export
theme_brand <- function(base_size = 14, mode = "light") {
  cols  <- brand_colors(mode)
  fonts <- brand_fonts()

  # Use actual brand background — works in Quarto/scripts.
  # In Shiny, thematic (activated by brand_page_*) overrides this.
  bg <- cols$background

  ggplot2::theme_minimal(base_size = base_size, base_family = fonts$base) +
    ggplot2::theme(
      plot.background        = ggplot2::element_rect(fill = bg, color = NA),
      panel.background       = ggplot2::element_rect(fill = bg, color = NA),
      panel.grid.major       = ggplot2::element_line(
        color = ggplot2::alpha(cols$primary, 0.25), linewidth = 0.4, linetype = "dashed"
      ),
      panel.grid.minor       = ggplot2::element_blank(),
      plot.title             = ggplot2::element_text(
        family = fonts$heading, face = "bold",
        size = base_size * 1.3, color = cols$foreground
      ),
      plot.subtitle          = ggplot2::element_text(
        color = cols$foreground, margin = ggplot2::margin(b = 10)
      ),
      axis.text              = ggplot2::element_text(color = cols$foreground),
      axis.title             = ggplot2::element_text(color = cols$foreground),
      legend.text            = ggplot2::element_text(color = cols$foreground),
      legend.title           = ggplot2::element_text(color = cols$foreground),
      legend.background      = ggplot2::element_rect(fill = bg, color = NA),
      legend.key             = ggplot2::element_rect(fill = bg, color = NA),
      legend.box.background  = ggplot2::element_rect(fill = bg, color = NA),
      strip.background       = ggplot2::element_rect(fill = cols$light, color = NA),
      strip.text             = ggplot2::element_text(
        family = fonts$base, face = "bold", color = cols$foreground
      )
    )
}


# --------------------------------------------------------------------------
# Convenience scales — thin wrappers so users don't assemble palettes
# --------------------------------------------------------------------------

#' @rdname brand_scales
#' @export
scale_color_brand_d <- function(..., mode = "light") {
  ggplot2::scale_color_manual(values = brand_pal_discrete(mode = mode), ...)
}

#' @rdname brand_scales
#' @export
scale_fill_brand_d <- function(..., mode = "light") {
  ggplot2::scale_fill_manual(values = brand_pal_discrete(mode = mode), ...)
}

#' @rdname brand_scales
#' @export
scale_color_brand_c <- function(type = "warm", ..., mode = "light") {
  ggplot2::scale_color_gradientn(
    colors = brand_pal_seq(type = type, mode = mode), ...
  )
}

#' @rdname brand_scales
#' @export
scale_fill_brand_c <- function(type = "warm", ..., mode = "light") {
  ggplot2::scale_fill_gradientn(
    colors = brand_pal_seq(type = type, mode = mode), ...
  )
}

#' @rdname brand_scales
#' @export
scale_color_brand_div <- function(..., mode = "light") {
  ggplot2::scale_color_gradientn(
    colors = brand_pal_div(mode = mode), ...
  )
}

#' Branded ggplot2 Colour / Fill Scales
#'
#' Drop-in replacements for `scale_color_manual()`, `scale_fill_gradientn()`,
#' etc. that pull colours from the brand cache.
#'
#' @param type For continuous scales: `"warm"`, `"cool"`, or `"green"`.
#' @param mode `"light"` or `"dark"`.
#' @param ... Passed to the underlying ggplot2 scale function.
#'
#' @name brand_scales
#' @export
scale_fill_brand_div <- function(..., mode = "light") {
  ggplot2::scale_fill_gradientn(
    colors = brand_pal_div(mode = mode), ...
  )
}
