# ==========================================================================
# Branded Shiny app — starter
# Scaffolded by brandkit::create_brand_shiny_app()
#
# brand_page_sidebar() auto-injects everything: the bslib theme built from
# _brand.yml, dark-mode CSS for widgets Bootstrap doesn't reach, the
# dark-mode toggle, the logo next to the title, and thematic so every
# renderPlot() picks up brand colours and fonts. There is no theming code
# below on purpose — that's the point.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)


ui <- brand_page_sidebar(
  title = "My Branded App",

  sidebar = sidebar(
    # The dark-mode toggle is injected automatically (top-right).
    selectInput("dataset", "Dataset", c("mtcars", "iris", "faithful")),
    sliderInput("alpha", "Point opacity", min = 0.2, max = 1, value = 0.7, step = 0.1),
    checkboxInput("smooth", "Add trend line", TRUE)
  ),

  layout_columns(
    col_widths = c(8, 4),
    card(
      card_header("Plot"),
      plotOutput("scatter", height = "380px")
    ),
    card(
      card_header("Brand palette"),
      plotOutput("palette", height = "380px")
    )
  ),

  card(
    card_header("Summary"),
    verbatimTextOutput("summary")
  )
)


server <- function(input, output, session) {

  dat <- reactive({
    switch(input$dataset,
      mtcars   = mtcars,
      iris     = iris,
      faithful = faithful
    )
  })

  # Plot variables per dataset, so the scatter works for all three.
  vars <- reactive({
    switch(input$dataset,
      mtcars   = list(x = "mpg", y = "wt", color = "cyl"),
      iris     = list(x = "Sepal.Length", y = "Sepal.Width", color = "Species"),
      faithful = list(x = "waiting", y = "eruptions", color = NULL)
    )
  })

  output$scatter <- renderPlot({
    d <- dat()
    v <- vars()

    mapping <- if (is.null(v$color)) {
      aes(.data[[v$x]], .data[[v$y]])
    } else {
      aes(.data[[v$x]], .data[[v$y]], color = factor(.data[[v$color]]))
    }

    p <- ggplot(d, mapping) +
      geom_point(size = 3, alpha = input$alpha) +
      labs(title = paste(v$y, "vs", v$x), color = v$color)

    if (input$smooth) {
      p <- p + geom_smooth(method = "lm", formula = y ~ x, se = FALSE)
    }
    p
  })

  # brand_pal_discrete() pulls the qualitative palette straight from
  # _brand.yml — handy as a visual check that your brand is loading.
  output$palette <- renderPlot({
    cols <- brand_pal_discrete(n = 8)
    ggplot(
      data.frame(i = seq_along(cols), col = factor(seq_along(cols))),
      aes(i, 1, fill = col)
    ) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = cols) +
      labs(title = "brand_pal_discrete()", x = NULL, y = NULL) +
      theme(
        axis.text        = element_blank(),
        axis.ticks       = element_blank(),
        # theme_brand() sets panel.grid.major explicitly, so it has to be
        # blanked by name — a blanket panel.grid = element_blank() would
        # not override it.
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      )
  })

  output$summary <- renderPrint({
    summary(dat())
  })
}


shinyApp(ui, server)
