# --------------------------------------------------------------------------
# brandkit: brand_plotly.R
# Branded ggplotly conversion.
# --------------------------------------------------------------------------

#' Convert ggplot to Branded Plotly
#'
#' Applies `theme_brand()` then converts to an interactive plotly widget
#' with branded fonts, correct background, and styled grid. Automatically
#' detects the active mode set by `brand_quarto_setup()`.
#'
#' @param p A ggplot2 object.
#' @param mode `"light"`, `"dark"`, or `NULL` (auto-detect from
#'   `brand_quarto_setup()` / `.onAttach`). Default `NULL`.
#' @param base_size Font size in points.
#' @param tooltip Aesthetics to show on hover.
#' @param width Widget width in pixels. Default `NULL` (automatic).
#'   For revealjs slides, `1000` works well.
#' @param height Widget height in pixels. Default `NULL` (automatic).
#'   For revealjs slides, `600` works well.
#'
#' @return A plotly htmlwidget.
#' @export
brand_plotly <- function(p, mode = NULL, base_size = 14, tooltip = "y",
                         width = NULL, height = NULL) {

  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Install the plotly package to use brand_plotly().", call. = FALSE)
  }

  # Auto-detect mode from brand_quarto_setup() or default to light
  mode  <- mode %||% brand_env$active_mode %||% "light"
  cols  <- brand_colors(mode)
  fonts <- brand_fonts()

  p <- p + theme_brand(base_size = base_size, mode = mode)

  grid_col <- hex_to_rgba(cols$primary, 0.25)

  widget <- plotly::ggplotly(p, tooltip = tooltip, width = width, height = height) |>
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
      legend = list(
        font    = list(family = fonts$base, color = cols$foreground),
        bgcolor = "transparent"
      ),
      hoverlabel = list(font = list(family = fonts$base, size = base_size))
    )

  # Fix colorbar (continuous legend) text colour — use tryCatch
  # since not all plots have a colorbar
  tryCatch({
    widget <- plotly::colorbar(widget,
      tickfont = list(color = cols$foreground, family = fonts$base),
      title    = list(font = list(color = cols$foreground, family = fonts$base))
    )
  }, error = function(e) NULL)

  widget
}
