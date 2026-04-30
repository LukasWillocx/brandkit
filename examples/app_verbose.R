# ==========================================================================
# brandkit: verbose example (showing what brand_page_sidebar does for you)
# Compare to app.R for the zero-boilerplate version.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

ui <- page_sidebar(
  theme = brand_theme(),           # manual: brand bslib theme
  brand_dark_css(),                # manual: datepicker/widget dark overrides
  title = "brandkit verbose demo",

  sidebar = sidebar(
    input_dark_mode(id = "dark_mode"),   # manual: dark mode toggle
    hr(),
    selectInput("dataset", "Dataset", c("mtcars", "iris", "faithful")),
    sliderInput("alpha", "Point opacity", 0.3, 1, 0.7, step = 0.1),
    checkboxInput("smooth", "Add trend line", TRUE)
  ),

  card(
    card_header("Scatter plot"),
    plotOutput("scatter", height = "350px")
  )
)

server <- function(input, output, session) {

  # manual: reactive dark mode tracking
  dm <- brand_dark_mode(input, session)

  output$scatter <- renderPlot({
    d <- switch(input$dataset, mtcars = mtcars, iris = iris, faithful = faithful)

    if (input$dataset == "mtcars") {
      ggplot(d, aes(mpg, wt, color = factor(cyl))) +
        geom_point(size = 3, alpha = input$alpha) +
        scale_color_brand_d(mode = dm$mode()) +    # manual: pass mode
        theme_brand(mode = dm$mode()) +             # manual: pass mode
        labs(title = "MPG vs Weight", color = "Cylinders")
    } else if (input$dataset == "iris") {
      ggplot(d, aes(Sepal.Length, Sepal.Width, color = Species)) +
        geom_point(size = 3, alpha = input$alpha) +
        scale_color_brand_d(mode = dm$mode()) +
        theme_brand(mode = dm$mode()) +
        labs(title = "Iris Measurements")
    } else {
      ggplot(d, aes(waiting, eruptions)) +
        geom_point(size = 2, alpha = input$alpha,
                   color = brand_colors(dm$mode())$primary) +
        theme_brand(mode = dm$mode()) +
        labs(title = "Old Faithful")
    }
  })
}

shinyApp(ui, server)
