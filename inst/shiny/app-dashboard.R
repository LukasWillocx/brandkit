# ==========================================================================
# Branded Shiny app — dashboard
# Scaffolded by brandkit::create_brand_shiny_dashboard()
#
# A KPI-and-charts dashboard on brand_page_navbar(). The theme, dark-mode
# CSS, toggle, logo, and thematic plot integration are all auto-injected —
# the only theming code below is where a plot needs an explicit brand
# colour (geom_line colour, geom_histogram fill), which thematic can't infer.
#
# Requires the DT package for the data table tab.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(brandkit)

# Sample data - replace with your own. airquality is built into R: daily
# readings in New York, May to September 1973 (ozone in ppb, wind in mph,
# temperature in °F). Ozone and Solar.R have missing days.
aq <- airquality
aq$Date  <- as.Date(sprintf("1973-%02d-%02d", aq$Month, aq$Day))
aq$Month <- factor(month.name[aq$Month], levels = month.name[5:9])

# Ozone bands for the "Ozone level" chart, in ppb.
aq$Level <- cut(aq$Ozone, c(-Inf, 54, 70, 85, Inf),
                labels = c("Low", "Moderate", "High", "Very high"))

monthly <- aggregate(cbind(Temp, Ozone, Wind) ~ Month, aq, mean,
                     na.rm = TRUE, na.action = na.pass)


ui <- brand_page_navbar(
  title = "New York Air Quality",

  nav_panel(
    "Overview",

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box("Average temperature", textOutput("kpi_temp"), showcase = icon("temperature-half"), theme = "primary"),
      value_box("Average ozone", textOutput("kpi_ozone"), showcase = icon("cloud"), theme = "secondary"),
      value_box("Average wind", textOutput("kpi_wind"), showcase = icon("wind"), theme = "info"),
      value_box("Days over 90°F", textOutput("kpi_hot"), showcase = icon("fire"), theme = "warning")
    ),

    layout_columns(
      col_widths = c(8, 4),
      card(
        card_header("Average temperature by month"),
        plotOutput("temp_by_month", height = "360px")
      ),
      card(
        card_header("Ozone level"),
        plotOutput("ozone_level", height = "360px")
      )
    )
  ),

  nav_panel(
    "Trends",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Daily temperature"),
        plotOutput("temp_line", height = "320px")
      ),
      card(
        card_header("Ozone distribution"),
        plotOutput("ozone_hist", height = "320px")
      )
    ),
    card(
      card_header("Ozone and temperature"),
      plotOutput("scatter", height = "320px")
    )
  ),

  nav_panel(
    "Data",
    card(
      card_header("Daily readings"),
      DTOutput("table")
    )
  )
)


server <- function(input, output, session) {

  # Reactive light/dark mode, tracking the auto-injected toggle. Pass
  # dm$mode() to brand_colors() / theme_brand() wherever a plot needs an
  # explicit brand colour so it follows the toggle.
  dm <- brand_dark_mode(input)

  # --- KPIs ----------------------------------------------------------------
  output$kpi_temp <- renderText({
    paste(round(mean(aq$Temp)), "°F")
  })

  output$kpi_ozone <- renderText({
    paste(round(mean(aq$Ozone, na.rm = TRUE)), "ppb")
  })

  output$kpi_wind <- renderText({
    paste(round(mean(aq$Wind), 1), "mph")
  })

  output$kpi_hot <- renderText({
    paste(sum(aq$Temp > 90), "days")
  })

  # --- Plots ---------------------------------------------------------------
  # No theme_brand() call needed here: thematic + the auto-applied discrete
  # scale handle fill colours and the panel background.
  output$temp_by_month <- renderPlot({
    ggplot(monthly, aes(Month, Temp, fill = Month)) +
      geom_col(show.legend = FALSE) +
      labs(x = NULL, y = "Temperature (°F)")
  })

  output$ozone_level <- renderPlot({
    counts <- as.data.frame(table(aq$Level), responseName = "Days")
    ggplot(counts, aes(x = "", y = Days, fill = Var1)) +
      geom_col(width = 1) +
      coord_polar(theta = "y") +
      labs(x = NULL, y = NULL, fill = NULL) +
      theme(
        axis.text        = element_blank(),
        axis.ticks       = element_blank(),
        # theme_brand() sets panel.grid.major explicitly, so it has to be
        # blanked by name — a blanket panel.grid = element_blank() does not
        # override it. Under coord_polar the gridlines curve into rings.
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      )
  })

  output$temp_line <- renderPlot({
    cols <- brand_colors(dm$mode())
    ggplot(aq, aes(Date, Temp)) +
      geom_line(color = cols$primary, linewidth = 1) +
      scale_x_date(date_labels = "%b") +
      labs(x = NULL, y = "Temperature (°F)")
  })

  output$ozone_hist <- renderPlot({
    cols <- brand_colors(dm$mode())
    ggplot(aq, aes(Ozone)) +
      geom_histogram(bins = 15, fill = cols$primary, color = cols$background,
                     na.rm = TRUE) +
      labs(x = "Ozone (ppb)", y = "Days")
  })

  output$scatter <- renderPlot({
    cols <- brand_colors(dm$mode())
    ggplot(aq, aes(Temp, Ozone, color = Month)) +
      geom_point(size = 3, alpha = 0.8, na.rm = TRUE) +
      geom_smooth(aes(group = 1), method = "lm", formula = y ~ x, se = FALSE,
                  color = cols$foreground, na.rm = TRUE) +
      labs(x = "Temperature (°F)", y = "Ozone (ppb)", color = NULL)
  })

  # --- Table ---------------------------------------------------------------
  # DT is styled by brandkit's CSS overrides in both light and dark mode;
  # no datatable() theming arguments needed.
  output$table <- renderDT({
    datatable(
      aq[, c("Date", "Ozone", "Solar.R", "Wind", "Temp")],
      rownames = FALSE,
      options = list(pageLength = 12, dom = "ftip")
    )
  })
}


shinyApp(ui, server)
