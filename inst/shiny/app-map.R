# ==========================================================================
# Branded Shiny app — map
# Scaffolded by brandkit::create_brand_shiny_map()
#
# A geospatial app on brand_page_fluid(). Leaflet and plotly both sit
# outside Bootstrap's reach, so this template shows the two brandkit
# helpers that bridge that gap:
#
#   brand_pal_seq()  — a sequential brand palette for colorNumeric()
#   brand_plotly()   — applies brand colours/fonts to a ggplot -> plotly
#
# Both take a `mode` argument so they follow the dark-mode toggle.
#
# Requires the leaflet and plotly packages.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(leaflet)
library(plotly)
library(brandkit)


ui <- brand_page_fluid(
  title = "Geospatial Explorer",

  layout_columns(
    col_widths = c(3, 9),

    card(
      card_header("Filters"),
      selectInput("min_mag", "Minimum magnitude",
                  choices = c("All" = 0, "4.0+" = 4, "4.5+" = 4.5, "5.0+" = 5),
                  selected = 4),
      sliderInput("depth", "Depth range (km)",
                  min = 0, max = 700, value = c(0, 700)),
      checkboxInput("cluster", "Cluster markers", TRUE),
      checkboxInput("auto_tiles", "Match tiles to dark mode", TRUE),
      conditionalPanel(
        "!input.auto_tiles",
        selectInput("tile", "Map style",
                    c("OpenStreetMap"     = "OpenStreetMap",
                      "Carto Light"       = "CartoDB.Positron",
                      "Carto Dark"        = "CartoDB.DarkMatter",
                      "Esri Topo"         = "Esri.WorldTopoMap"))
      ),
      hr(),
      verbatimTextOutput("stats")
    ),

    div(
      card(
        card_header("Earthquakes near Fiji"),
        leafletOutput("map", height = "420px")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Magnitude distribution"),
          plotOutput("hist", height = "340px")
        ),
        card(
          card_header("Depth vs magnitude"),
          plotlyOutput("scatter", height = "340px")
        )
      )
    )
  )
)


server <- function(input, output, session) {

  dm <- brand_dark_mode(input)

  # --- Sample data — replace with your own ---------------------------------
  filtered <- reactive({
    d <- quakes
    d <- d[d$mag >= as.numeric(input$min_mag), ]
    d[d$depth >= input$depth[1] & d$depth <= input$depth[2], ]
  })

  # Tile layer either follows the dark-mode toggle or is picked manually.
  tile_provider <- reactive({
    if (isTRUE(input$auto_tiles)) {
      if (dm$mode() == "dark") "CartoDB.DarkMatter" else "CartoDB.Positron"
    } else {
      input$tile
    }
  })

  output$map <- renderLeaflet({
    d <- filtered()
    mode <- dm$mode()

    # A sequential brand palette drives the marker colour ramp — the same
    # ramp scale_color_brand_c() uses for ggplot2.
    pal <- colorNumeric(
      palette = brand_pal_seq(type = "warm", n = 9, mode = mode),
      domain  = d$mag
    )

    m <- leaflet(d) |>
      addProviderTiles(tile_provider()) |>
      addCircleMarkers(
        ~long, ~lat,
        radius      = ~mag * 2,
        color       = ~pal(mag),
        fillOpacity = 0.7,
        stroke      = FALSE,
        popup       = ~paste0(
          "<b>Magnitude:</b> ", mag, "<br>",
          "<b>Depth:</b> ", depth, " km<br>",
          "<b>Stations:</b> ", stations
        ),
        clusterOptions = if (isTRUE(input$cluster)) markerClusterOptions() else NULL
      )

    m |> addLegend("bottomright", pal = pal, values = ~mag, title = "Magnitude")
  })

  output$hist <- renderPlot({
    mode <- dm$mode()
    cols <- brand_colors(mode)
    ggplot(filtered(), aes(mag)) +
      geom_histogram(binwidth = 0.1, fill = cols$primary, color = cols$background) +
      labs(x = "Magnitude", y = "Count") +
      theme_brand(mode = mode)
  })

  output$scatter <- renderPlotly({
    mode <- dm$mode()
    p <- ggplot(filtered(), aes(depth, mag, color = stations)) +
      geom_point(alpha = 0.7, size = 2) +
      scale_color_brand_c(type = "cool", mode = mode) +
      labs(x = "Depth (km)", y = "Magnitude", color = "Stations")

    # brand_plotly() re-applies brand colours and fonts after ggplotly()
    # strips them, and makes the plot background transparent so it sits
    # cleanly on the card in either mode.
    brand_plotly(p, mode = mode, tooltip = c("x", "y"))
  })

  output$stats <- renderPrint({
    d <- filtered()
    cat("Events:       ", nrow(d), "\n")
    cat("Mean mag:     ", round(mean(d$mag), 2), "\n")
    cat("Max mag:      ", max(d$mag), "\n")
    cat("Mean depth:   ", round(mean(d$depth)), "km\n")
  })
}


shinyApp(ui, server)
