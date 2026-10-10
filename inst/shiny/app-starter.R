# ==========================================================================
# Branded Shiny app — starter
# Scaffolded by brandkit::create_brand_shiny_app()
#
# brand_page_sidebar() auto-injects everything: the bslib theme built from
# _brand.yml, dark-mode CSS for widgets Bootstrap doesn't reach, the
# dark-mode toggle, the logo next to the title, and thematic so every
# renderPlot() picks up brand colours and fonts. There is no theming code
# below on purpose — that's the point.
#
# style = "drift" is the page look shared with brandkit's poster template:
# soft geometric ornaments in the window's top-right and bottom-left
# corners, the title as plain type, and cards as tinted surfaces with a
# solid header. Everything in it is drawn from _brand.yml and follows the
# dark-mode toggle. Drop the argument (or use style = "classic") for the
# plain Bootstrap look.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

# Sample data - replace with your own. airquality is built into R: daily
# readings in New York, May to September 1973.
aq <- airquality
aq$Month <- factor(month.name[aq$Month], levels = month.name[5:9])

measures <- c(
  "Ozone (ppb)"               = "Ozone",
  "Solar radiation (langley)" = "Solar.R",
  "Wind (mph)"                = "Wind"
)


ui <- brand_page_sidebar(
  title = "New York Air Quality",
  style = "drift",

  sidebar = sidebar(
    # The dark-mode toggle is injected automatically (top-right).
    selectInput("measure", "Measure", measures),
    sliderInput("alpha", "Point opacity", min = 0.2, max = 1, value = 0.7, step = 0.1),
    checkboxInput("smooth", "Add trend line", TRUE)
  ),

  layout_columns(
    col_widths = c(8, 4),
    card(
      card_header("Temperature and air quality"),
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

  output$scatter <- renderPlot({
    d <- aq[!is.na(aq[[input$measure]]), ]

    p <- ggplot(d, aes(Temp, .data[[input$measure]], color = Month)) +
      geom_point(size = 3, alpha = input$alpha) +
      labs(x = "Temperature (°F)", y = names(measures)[measures == input$measure],
           color = NULL)

    if (input$smooth) {
      # color = NULL: one trend line for all months, not one per month.
      p <- p + geom_smooth(aes(color = NULL), method = "lm", formula = y ~ x, se = FALSE)
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
    summary(aq[c("Ozone", "Solar.R", "Wind", "Temp")])
  })
}


shinyApp(ui, server)
