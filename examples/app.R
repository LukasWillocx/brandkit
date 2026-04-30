# ==========================================================================
# brandkit: zero-boilerplate example
# Compare this to the verbose version in app_verbose.R
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

# --- UI: one function, everything injected ---
ui <- brand_page_sidebar(
  title = "brandkit test drive",

  sidebar = sidebar(
    # dark mode toggle is auto-injected here ^^
    selectInput("dataset", "Dataset", c("mtcars", "iris", "faithful")),
    sliderInput("alpha", "Point opacity", 0.3, 1, 0.7, step = 0.1),
    checkboxInput("smooth", "Add trend line", TRUE),
    dateRangeInput("dates", "Date range (widget test):"),
    radioButtons("palette", "Palette type",
                 c("Discrete" = "discrete", "Sequential" = "seq", "Diverging" = "div"))
  ),

  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Scatter plot"),
      plotOutput("scatter", height = "350px")
    ),
    card(
      card_header("Palette preview"),
      plotOutput("palette_preview", height = "350px")
    )
  ),

  card(
    card_header("Brand colours (from cache)"),
    verbatimTextOutput("colors_debug")
  )
)


# --- Server: no theming code at all ---
server <- function(input, output, session) {

  dat <- reactive({
    switch(input$dataset,
      mtcars   = mtcars,
      iris     = iris,
      faithful = faithful
    )
  })

  output$scatter <- renderPlot({
    d <- dat()
    if (input$dataset == "mtcars") {
      ggplot(d, aes(mpg, wt, color = factor(cyl))) +
        geom_point(size = 3, alpha = input$alpha) +
        labs(title = "MPG vs Weight", color = "Cylinders") +
        { if (input$smooth) geom_smooth(method = "lm", se = FALSE) }
    } else if (input$dataset == "iris") {
      ggplot(d, aes(Sepal.Length, Sepal.Width, color = Species)) +
        geom_point(size = 3, alpha = input$alpha) +
        labs(title = "Iris Measurements") +
        { if (input$smooth) geom_smooth(method = "lm", se = FALSE) }
    } else {
      ggplot(d, aes(waiting, eruptions)) +
        geom_point(size = 2, alpha = input$alpha) +
        labs(title = "Old Faithful") +
        { if (input$smooth) geom_smooth(method = "lm", se = FALSE) }
    }
  })

  output$palette_preview <- renderPlot({
    cols <- switch(input$palette,
      discrete = brand_pal_discrete(n = 10),
      seq      = brand_pal_seq(type = "warm", n = 10),
      div      = brand_pal_div(n = 10)
    )
    barplot(
      rep(1, length(cols)), col = cols, border = NA,
      axes = FALSE, main = paste(input$palette, "palette")
    )
  })

  output$colors_debug <- renderPrint({
    str(brand_colors())
  })
}

shinyApp(ui, server)
