# ==========================================================================
# brandkit: navbar layout with tables, value boxes, and multiple tabs
# Tests: brand_page_navbar, DT tables, value boxes, multiple plot types
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
      col_widths = c(4, 4, 4),
      value_box("Revenue", "$1.2M", theme = "primary"),
      value_box("Orders", "3,847", theme = "secondary"),
      value_box("Growth", "+12.3%", theme = "success")
    ),
    layout_columns(
      col_widths = c(8, 4),
      card(
        card_header("Monthly Revenue"),
        plotOutput("revenue_plot", height = "350px")
      ),
      card(
        card_header("Top Products"),
        plotOutput("product_pie", height = "350px")
      )
    )
  ),

  nav_panel(
    "Data Table",
    card(
      card_header("Interactive Table (DT)"),
      DTOutput("sales_table")
    )
  ),

  nav_panel(
    "Distributions",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Histogram"),
        plotOutput("histogram", height = "300px")
      ),
      card(
        card_header("Box Plot"),
        plotOutput("boxplot", height = "300px")
      )
    ),
    card(
      card_header("Density Plot"),
      plotOutput("density", height = "300px")
    )
  )
)

server <- function(input, output, session) {

  # Sample data
  sales <- data.frame(
    Month = factor(month.abb, levels = month.abb),
    Revenue = c(95, 110, 125, 108, 140, 155, 148, 165, 172, 158, 180, 195) * 1000,
    Orders = c(320, 380, 410, 365, 470, 520, 495, 550, 575, 530, 600, 650),
    Region = rep(c("North", "South", "East", "West"), each = 3)
  )

  output$revenue_plot <- renderPlot({
    ggplot(sales, aes(Month, Revenue, fill = Region)) +
      geom_col(position = "dodge") +
      scale_y_continuous(labels = scales::dollar) +
      labs(title = "Revenue by Region", y = "Revenue", x = NULL)
  })

  output$product_pie <- renderPlot({
    products <- data.frame(
      Product = c("Widget A", "Widget B", "Widget C", "Widget D"),
      Sales = c(35, 28, 22, 15)
    )
    ggplot(products, aes(x = "", y = Sales, fill = Product)) +
      geom_col(width = 1) +
      coord_polar(theta = "y") +
      labs(title = "Product Mix") +
      theme(axis.text = element_blank(), axis.title = element_blank())
  })

  output$sales_table <- renderDT({
    datatable(
      sales,
      options = list(pageLength = 12, dom = "tip"),
      class = "table-striped",
      rownames = FALSE
    )
  })

  output$histogram <- renderPlot({
    ggplot(faithful, aes(waiting)) +
      geom_histogram(bins = 20, fill = brand_colors()$primary, color = "white") +
      labs(title = "Old Faithful Wait Times", x = "Minutes", y = "Count")
  })

  output$boxplot <- renderPlot({
    ggplot(mpg, aes(class, hwy, fill = class)) +
      geom_boxplot(alpha = 0.8, show.legend = FALSE) +
      labs(title = "Highway MPG by Class", x = NULL, y = "MPG") +
      coord_flip()
  })

  output$density <- renderPlot({
    ggplot(diamonds, aes(price, fill = cut)) +
      geom_density(alpha = 0.6) +
      scale_x_log10(labels = scales::dollar) +
      labs(title = "Diamond Price Distribution by Cut", x = "Price", y = "Density")
  })
}

shinyApp(ui, server)
