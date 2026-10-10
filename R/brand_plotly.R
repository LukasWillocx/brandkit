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
#'   `brand_quarto_setup()` / `.onAttach`). Default `NULL`. After
#'   `brand_quarto_setup(adaptive = TRUE)`, `NULL` draws the plot in both
#'   modes (see Value).
#' @param base_size Font size in points.
#' @param tooltip Aesthetics to show on hover.
#' @param width Widget width in pixels. Default `NULL` (automatic).
#'   For revealjs slides, `1000` works well.
#' @param height Widget height in pixels. Default `NULL` (automatic).
#'   For revealjs slides, `600` works well.
#'
#' @return A plotly htmlwidget. After `brand_quarto_setup(adaptive = TRUE)`
#'   (and with `mode = NULL`) it is instead a tag list holding a light and a
#'   dark widget, of which the page's stylesheet shows the one that matches
#'   its light/dark toggle; it prints in a Quarto chunk like a widget, but
#'   cannot be piped into further plotly functions.
#' @export
brand_plotly <- function(p, mode = NULL, base_size = 14, tooltip = "y",
                         width = NULL, height = NULL) {

  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Install the plotly package to use brand_plotly().", call. = FALSE)
  }

  if (is.null(mode) && isTRUE(brand_env$adaptive)) {
    one <- function(m) {
      htmltools::div(
        class = paste0("bk-mode bk-mode-", m),
        brand_plotly_mode(p, m, base_size, tooltip, width, height)
      )
    }
    return(htmltools::tagList(one("light"), one("dark")))
  }

  # Auto-detect mode from brand_quarto_setup() or default to light
  brand_plotly_mode(p, mode %||% brand_env$active_mode %||% "light",
                    base_size, tooltip, width, height)
}

# One widget, drawn for one mode. ggplotly() resolves the discrete palette
# when it builds the plot, so the mode has to be in force around that call
# for the dark widget to get the dark palette and not just dark text.
brand_plotly_mode <- function(p, mode, base_size, tooltip, width, height) {
  cols  <- brand_colors(mode)
  fonts <- brand_fonts()

  p <- p + theme_brand(base_size = base_size, mode = mode)

  grid_col <- hex_to_rgba(cols$primary, 0.25)

  widget <- with_brand_mode(mode, plotly::ggplotly(
    p, tooltip = tooltip, width = width, height = height
  )) |>
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
  # since not all plots have a colorbar. plotly also *warns* when there is
  # none, which knitr prints into the document, so that one warning is
  # muffled.
  tryCatch({
    widget <- withCallingHandlers(
      plotly::colorbar(widget,
        tickfont = list(color = cols$foreground, family = fonts$base),
        title    = list(font = list(color = cols$foreground, family = fonts$base))
      ),
      warning = function(w) {
        if (grepl("colorbar", conditionMessage(w), fixed = TRUE)) {
          invokeRestart("muffleWarning")
        }
      }
    )
  }, error = function(e) NULL)

  plotly_remeasure_fonts(widget)
}

# plotly lays its legend and axes out by measuring text, and it measures
# before a web font (the brand's) has finished loading, in whatever fallback
# is showing. The legend is then sized to the fallback's narrower text and
# clips the real thing: "September" arrives as "Septembe". Measurements are
# cached per font string, so redrawing alone repeats the mistake; changing
# the string does not. Once the font has loaded, restate it with a generic
# fallback appended — the same font, but a key the cache has not seen — so
# plotly measures again, properly.
plotly_remeasure_fonts <- function(widget) {
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) return(widget)

  htmlwidgets::onRender(widget, "
    function(el, x) {
      var fam = x.layout && x.layout.font && x.layout.font.family;
      if (!fam || !document.fonts || !document.fonts.load) return;
      var first = fam.split(',')[0].replace(/['\"]/g, '').trim();
      document.fonts.load('16px \"' + first + '\"').then(function() {
        var f = fam + ', sans-serif';
        Plotly.relayout(el, {
          'font.family': f,
          'legend.font.family': f,
          'xaxis.tickfont.family': f,
          'yaxis.tickfont.family': f,
          'xaxis.title.font.family': f,
          'yaxis.title.font.family': f
        });
      });
    }")
}
