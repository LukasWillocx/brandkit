# ==========================================================================
# brandkit: no _brand.yml test
# Tests: graceful fallback, error handling, manual init
# Run this from a directory that does NOT contain a _brand.yml
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

# This should print a startup message about missing _brand.yml
# but should NOT error. The app should still launch with bslib defaults.

ui <- tryCatch(
  brand_page_sidebar(
    title = "Fallback Test",
    sidebar = sidebar(
      selectInput("x", "X:", names(iris)[1:4]),
      selectInput("y", "Y:", names(iris)[1:4], selected = "Sepal.Width")
    ),
    card(
      card_header("Does this work without _brand.yml?"),
      plotOutput("plot")
    )
  ),
  error = function(e) {
    # If brand_page_sidebar fails, fall back to plain bslib
    message("brand_page_sidebar failed: ", e$message)
    message("Falling back to plain page_sidebar")
    page_sidebar(
      title = "Fallback (plain bslib)",
      sidebar = sidebar(
        selectInput("x", "X:", names(iris)[1:4]),
        selectInput("y", "Y:", names(iris)[1:4], selected = "Sepal.Width")
      ),
      card(
        card_header("brand_page_sidebar failed — using plain bslib"),
        plotOutput("plot")
      )
    )
  }
)

server <- function(input, output, session) {
  output$plot <- renderPlot({
    ggplot(iris, aes(.data[[input$x]], .data[[input$y]], color = Species)) +
      geom_point(size = 3) +
      labs(title = "This plot should still render")
  })
}

shinyApp(ui, server)
