# ==========================================================================
# Branded Shiny app — dashboard
# Scaffolded by brandkit::create_brand_shiny_dashboard()
#
# A KPI-and-charts dashboard on brand_page_navbar(). The theme, dark-mode
# CSS, toggle, logo, and thematic plot integration are all auto-injected —
# the only theming code below is where a plot needs an explicit brand
# colour (geom_col fill, geom_histogram fill), which thematic can't infer.
#
# Requires the DT package for the data table tab.
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(brandkit)


ui <- brand_page_navbar(
  title = "Sales Dashboard",

  nav_panel(
    "Overview",

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box("Revenue", textOutput("kpi_revenue"), showcase = icon("dollar-sign"), theme = "primary"),
      value_box("Orders", textOutput("kpi_orders"), showcase = icon("cart-shopping"), theme = "secondary"),
      value_box("Avg order", textOutput("kpi_aov"), showcase = icon("receipt"), theme = "info"),
      value_box("Growth", textOutput("kpi_growth"), showcase = icon("arrow-trend-up"), theme = "success")
    ),

    layout_columns(
      col_widths = c(8, 4),
      card(
        card_header("Monthly revenue by region"),
        plotOutput("revenue_plot", height = "360px")
      ),
      card(
        card_header("Product mix"),
        plotOutput("product_mix", height = "360px")
      )
    )
  ),

  nav_panel(
    "Trends",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Orders over time"),
        plotOutput("orders_line", height = "320px")
      ),
      card(
        card_header("Revenue distribution"),
        plotOutput("revenue_hist", height = "320px")
      )
    ),
    card(
      card_header("Revenue vs orders"),
      plotOutput("scatter", height = "320px")
    )
  ),

  nav_panel(
    "Data",
    card(
      card_header("Monthly detail"),
      DTOutput("table")
    )
  )
)


server <- function(input, output, session) {

  # Reactive light/dark mode, tracking the auto-injected toggle. Pass
  # dm$mode() to brand_colors() / theme_brand() wherever a plot needs an
  # explicit brand colour so it follows the toggle.
  dm <- brand_dark_mode(input)

  # --- Sample data — replace with your own ---------------------------------
  sales <- data.frame(
    Month   = factor(rep(month.abb, each = 4), levels = month.abb),
    Region  = rep(c("North", "South", "East", "West"), times = 12),
    Revenue = c(
      24, 19, 27, 25, 28, 22, 31, 29, 32, 26, 34, 33, 27, 23, 29, 29,
      36, 30, 38, 36, 39, 34, 42, 40, 37, 32, 40, 39, 42, 37, 45, 41,
      44, 39, 47, 42, 40, 36, 43, 39, 46, 41, 49, 44, 50, 45, 53, 47
    ) * 1000
  )
  sales$Orders <- round(sales$Revenue / runif(nrow(sales), 280, 340))

  monthly <- reactive({
    agg <- aggregate(cbind(Revenue, Orders) ~ Month, data = sales, FUN = sum)
    agg[order(agg$Month), ]
  })

  # --- KPIs ----------------------------------------------------------------
  output$kpi_revenue <- renderText({
    paste0("$", format(round(sum(sales$Revenue) / 1000), big.mark = ","), "K")
  })

  output$kpi_orders <- renderText({
    format(sum(sales$Orders), big.mark = ",")
  })

  output$kpi_aov <- renderText({
    paste0("$", round(sum(sales$Revenue) / sum(sales$Orders)))
  })

  output$kpi_growth <- renderText({
    m <- monthly()
    paste0("+", round(100 * (m$Revenue[nrow(m)] / m$Revenue[1] - 1)), "%")
  })

  # --- Plots ---------------------------------------------------------------
  # No theme_brand() call needed here: thematic + the auto-applied discrete
  # scale handle fill colours and the panel background.
  output$revenue_plot <- renderPlot({
    ggplot(sales, aes(Month, Revenue, fill = Region)) +
      geom_col() +
      scale_y_continuous(labels = function(x) paste0("$", x / 1000, "K")) +
      labs(x = NULL, y = "Revenue", fill = NULL)
  })

  output$product_mix <- renderPlot({
    products <- data.frame(
      Product = c("Widget A", "Widget B", "Widget C", "Widget D"),
      Share   = c(35, 28, 22, 15)
    )
    ggplot(products, aes(x = "", y = Share, fill = Product)) +
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

  output$orders_line <- renderPlot({
    m <- monthly()
    cols <- brand_colors(dm$mode())
    ggplot(m, aes(as.integer(Month), Orders, group = 1)) +
      geom_line(color = cols$primary, linewidth = 1.2) +
      geom_point(color = cols$secondary, size = 3) +
      scale_x_continuous(breaks = seq_along(month.abb), labels = month.abb) +
      labs(x = NULL, y = "Orders")
  })

  output$revenue_hist <- renderPlot({
    cols <- brand_colors(dm$mode())
    ggplot(sales, aes(Revenue)) +
      geom_histogram(bins = 15, fill = cols$primary, color = cols$background) +
      scale_x_continuous(labels = function(x) paste0("$", x / 1000, "K")) +
      labs(x = "Revenue", y = "Count")
  })

  output$scatter <- renderPlot({
    ggplot(sales, aes(Orders, Revenue, color = Region)) +
      geom_point(size = 3, alpha = 0.8) +
      geom_smooth(method = "lm", formula = y ~ x, se = FALSE) +
      scale_y_continuous(labels = function(x) paste0("$", x / 1000, "K")) +
      labs(color = NULL)
  })

  # --- Table ---------------------------------------------------------------
  # DT is styled by brandkit's CSS overrides in both light and dark mode;
  # no datatable() theming arguments needed.
  output$table <- renderDT({
    datatable(
      sales,
      rownames = FALSE,
      options = list(pageLength = 12, dom = "ftip")
    )
  })
}


shinyApp(ui, server)
