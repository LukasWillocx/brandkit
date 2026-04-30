# --------------------------------------------------------------------------
# brandkit: brand_plotly.R
# Branded ggplotly conversion.
# --------------------------------------------------------------------------

#' Convert ggplot to Branded Plotly
#'
#' Applies `theme_brand()` then converts to an interactive plotly widget
#' with branded fonts, transparent background, and styled grid.
#'
#' @param p A ggplot2 object.
#' @param mode `"light"` or `"dark"`.
#' @param base_size Font size in points.
#' @param tooltip Aesthetics to show on hover.
#'
#' @return A plotly htmlwidget.
#' @export
brand_plotly <- function(p, mode = "light", base_size = 14, tooltip = "y") {

  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Install the plotly package to use brand_plotly().", call. = FALSE)
  }

  cols  <- brand_colors(mode)
  fonts <- brand_fonts()

  p <- p + theme_brand(base_size = base_size, mode = mode)

  grid_col <- hex_to_rgba(cols$primary, 0.25)

  plotly::ggplotly(p, tooltip = tooltip) |>
    plotly::config(displayModeBar = FALSE) |>
    plotly::layout(
      paper_bgcolor = "transparent",
      plot_bgcolor  = "transparent",
      font = list(family = fonts$base, color = cols$foreground),
      title = list(font = list(
        family = fonts$heading, size = base_size * 1.3,
        color = cols$foreground
      )),
      xaxis = list(
        titlefont = list(family = fonts$base, color = cols$foreground),
        tickfont  = list(family = fonts$base, color = cols$foreground),
        gridcolor = grid_col, gridwidth = 0.4, griddash = "dash",
        showgrid = TRUE, zeroline = FALSE
      ),
      yaxis = list(
        titlefont = list(family = fonts$base, color = cols$foreground),
        tickfont  = list(family = fonts$base, color = cols$foreground),
        gridcolor = grid_col, gridwidth = 0.4, griddash = "dash",
        showgrid = TRUE, zeroline = FALSE
      ),
      legend     = list(font = list(family = fonts$base, color = cols$foreground)),
      hoverlabel = list(font = list(family = fonts$base, size = base_size))
    )
}
