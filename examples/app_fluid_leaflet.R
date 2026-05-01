# ==========================================================================
# brandkit: fluid layout with leaflet, plotly, and reactive filters
# Tests: brand_page_fluid, leaflet, brand_plotly, reactive dark mode
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(leaflet)
library(brandkit)

ui <- brand_page_fluid(
  title = "Geospatial Explorer",

  layout_columns(
    col_widths = c(3, 9),

    # Sidebar-like filter column
    card(
      card_header("Filters"),
      selectInput("quake_mag", "Min Magnitude:",
                  choices = c("All" = 0, "3+" = 3, "4+" = 4, "5+" = 5),
                  selected = 4),
      sliderInput("quake_depth", "Depth Range (km):",
                  min = 0, max = 700, value = c(0, 300)),
      selectInput("map_tile", "Map Style:",
                  c("Default" = "OpenStreetMap",
                    "Dark" = "CartoDB.DarkMatter",
                    "Toner" = "Stadia.StamenTonerLite",
                    "Terrain" = "Esri.WorldTopoMap")),
      hr(),
      checkboxInput("show_clusters", "Cluster markers", TRUE),
      verbatimTextOutput("summary_stats")
    ),

    # Main content
    htmltools::div(
      card(
        card_header("Earthquake Map"),
        leafletOutput("map", height = "400px")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Magnitude Distribution"),
          plotOutput("mag_hist", height = "400px")
        ),
        card(
          card_header("Depth vs Magnitude (interactive)"),
          plotlyOutput("depth_scatter", height = "400px")
        )
      )
    )
  )
)

server <- function(input, output, session) {

  # Track dark mode
  dm <- brand_dark_mode(input)

  quakes_filtered <- reactive({
    d <- quakes
    d <- d[d$mag >= as.numeric(input$quake_mag), ]
    d <- d[d$depth >= input$quake_depth[1] & d$depth <= input$quake_depth[2], ]
    d
  })

  output$map <- renderLeaflet({
    d <- quakes_filtered()
    mode <- dm$mode()

    # Colour by magnitude
    pal <- colorNumeric(
      palette = brand_pal_seq(type = "warm", n = 9, mode = mode),
      domain = d$mag
    )

    m <- leaflet(d) |>
      addProviderTiles(input$map_tile)

    if (input$show_clusters) {
      m <- m |> addCircleMarkers(
        ~long, ~lat,
        radius = ~mag * 2,
        color = ~pal(mag),
        fillOpacity = 0.7,
        stroke = FALSE,
        clusterOptions = markerClusterOptions(),
        popup = ~paste0("Mag: ", mag, "<br>Depth: ", depth, " km")
      )
    } else {
      m <- m |> addCircleMarkers(
        ~long, ~lat,
        radius = ~mag * 2,
        color = ~pal(mag),
        fillOpacity = 0.7,
        stroke = FALSE,
        popup = ~paste0("Mag: ", mag, "<br>Depth: ", depth, " km")
      )
    }

    m |> addLegend("bottomright", pal = pal, values = ~mag, title = "Magnitude")
  })

  output$mag_hist <- renderPlot({
    d <- quakes_filtered()
    mode <- dm$mode()
    ggplot(d, aes(mag)) +
      geom_histogram(binwidth = 0.2, fill = brand_colors(mode)$primary, color = "white") +
      labs(title = "Magnitude Distribution", x = "Magnitude", y = "Count") +
      theme_brand(mode = mode)
  })

  output$depth_scatter <- renderPlotly({
    d <- quakes_filtered()
    mode <- dm$mode()
    p <- ggplot(d, aes(depth, mag, color = stations)) +
      geom_point(alpha = 0.6, size = 2) +
      scale_color_brand_c(type = "cool", mode = mode) +
      labs(title = "Depth vs Magnitude", x = "Depth (km)", y = "Magnitude",
           color = "Stations")
    brand_plotly(p, mode = mode, tooltip = c("x", "y"))
  })

  output$summary_stats <- renderPrint({
    d <- quakes_filtered()
    cat("Quakes:", nrow(d), "\n")
    cat("Avg Magnitude:", round(mean(d$mag), 2), "\n")
    cat("Avg Depth:", round(mean(d$depth), 0), "km\n")
    cat("Max Magnitude:", max(d$mag))
  })
}

shinyApp(ui, server)
