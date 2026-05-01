# ==========================================================================
# brandkit: sidebar with gt tables, file downloads, accordions
# Tests: gt tables, accordion, download handlers, conditional panels
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(gt)
library(brandkit)

ui <- brand_page_sidebar(
  title = "Data Explorer",

  sidebar = sidebar(
    width = 320,
    accordion(
      accordion_panel(
        "Dataset",
        icon = icon("database"),
        selectInput("data", "Choose dataset:",
                    c("mtcars", "iris", "ToothGrowth", "PlantGrowth")),
        numericInput("n_rows", "Max rows:", 50, min = 5, max = 200)
      ),
      accordion_panel(
        "Plot Options",
        icon = icon("chart-bar"),
        selectInput("plot_type", "Plot type:",
                    c("Scatter" = "scatter", "Bar" = "bar",
                      "Violin" = "violin", "Lollipop" = "lollipop")),
        selectInput("x_var", "X variable:", NULL),
        selectInput("y_var", "Y variable:", NULL),
        selectInput("color_var", "Colour by:", c("None" = ""))
      ),
      accordion_panel(
        "Export",
        icon = icon("download"),
        downloadButton("download_plot", "Download Plot (PNG)", class = "btn-primary w-100 mb-2"),
        downloadButton("download_data", "Download Data (CSV)", class = "btn-secondary w-100")
      )
    )
  ),

  navset_card_tab(
    title = "Analysis",

    nav_panel(
      "Plot",
      plotOutput("main_plot", height = "450px")
    ),

    nav_panel(
      "Summary Table (gt)",
      gt_output("summary_gt")
    ),

    nav_panel(
      "Raw Data",
      tableOutput("raw_table")
    )
  ),

  # Secondary cards
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Correlation Matrix"),
      plotOutput("corr_plot", height = "300px")
    ),
    card(
      card_header("Dataset Info"),
      verbatimTextOutput("data_str")
    )
  )
)

server <- function(input, output, session) {

  # Track dark mode
  dm <- brand_dark_mode(input)

  dat <- reactive({
    d <- switch(input$data,
      mtcars = mtcars,
      iris = iris,
      ToothGrowth = ToothGrowth,
      PlantGrowth = PlantGrowth
    )
    head(d, input$n_rows)
  })

  # Update variable selectors when dataset changes
  observe({
    d <- dat()
    num_vars <- names(d)[sapply(d, is.numeric)]
    all_vars <- names(d)
    cat_vars <- names(d)[sapply(d, function(x) is.factor(x) || is.character(x))]

    updateSelectInput(session, "x_var", choices = all_vars, selected = all_vars[1])
    updateSelectInput(session, "y_var", choices = num_vars, selected = num_vars[min(2, length(num_vars))])
    updateSelectInput(session, "color_var",
                      choices = c("None" = "", cat_vars, num_vars),
                      selected = "")
  })

  current_plot <- reactive({
    d <- dat()
    req(input$x_var, input$y_var)
    req(input$x_var %in% names(d), input$y_var %in% names(d))

    aes_args <- if (nzchar(input$color_var) && input$color_var %in% names(d)) {
      aes(.data[[input$x_var]], .data[[input$y_var]], color = .data[[input$color_var]])
    } else {
      aes(.data[[input$x_var]], .data[[input$y_var]])
    }

    mode <- dm$mode()
    cols <- brand_colors(mode)
    p <- ggplot(d, aes_args)

    switch(input$plot_type,
      scatter = p + geom_point(size = 3, alpha = 0.7),
      bar = p + geom_col(fill = cols$primary),
      violin = {
        if (is.numeric(d[[input$x_var]])) {
          p + geom_violin(fill = cols$primary, alpha = 0.7)
        } else {
          p + geom_violin(aes(fill = .data[[input$x_var]]), alpha = 0.7, show.legend = FALSE)
        }
      },
      lollipop = {
        p + geom_segment(aes(xend = .data[[input$x_var]], yend = 0),
                         color = cols$primary) +
          geom_point(color = cols$secondary, size = 4)
      }
    ) +
      labs(title = paste(input$plot_type, "\u2014", input$data)) +
      theme_brand(mode = mode)
  })

  output$main_plot <- renderPlot({
    current_plot()
  })

  output$summary_gt <- render_gt({
    d <- dat()
    num_d <- d[sapply(d, is.numeric)]
    dm_mode <- dm$mode()
    cols <- brand_colors(dm_mode)

    summary_df <- data.frame(
      Variable = names(num_d),
      Mean = round(sapply(num_d, mean, na.rm = TRUE), 2),
      SD = round(sapply(num_d, sd, na.rm = TRUE), 2),
      Min = round(sapply(num_d, min, na.rm = TRUE), 2),
      Max = round(sapply(num_d, max, na.rm = TRUE), 2)
    )

    gt(summary_df) |>
      tab_header(title = paste(input$data, "\u2014 Summary Statistics")) |>
      tab_style(
        style = list(
          cell_fill(color = cols$primary),
          cell_text(color = "white", weight = "bold")
        ),
        locations = cells_column_labels()
      ) |>
      tab_style(
        style = cell_fill(color = cols$light),
        locations = cells_body(rows = seq(1, nrow(summary_df), 2))
      ) |>
      tab_style(
        style = cell_fill(color = cols$background),
        locations = cells_body(rows = seq(2, nrow(summary_df), 2))
      ) |>
      tab_style(
        style = list(
          cell_text(color = cols$foreground),
          cell_fill(color = cols$background)
        ),
        locations = cells_title()
      ) |>
      tab_style(
        style = cell_text(color = cols$foreground),
        locations = cells_body()
      ) |>
      tab_options(
        table.border.top.color = cols$primary,
        heading.border.bottom.color = cols$primary,
        table.background.color = cols$background,
        table.width = pct(100),
        table.font.size = px(14)
      )
  })

  output$raw_table <- renderTable({
    head(dat(), 20)
  }, striped = TRUE, hover = TRUE)

  output$corr_plot <- renderPlot({
    d <- dat()
    mode <- dm$mode()
    cols <- brand_colors(mode)
    num_d <- d[sapply(d, is.numeric)]
    if (ncol(num_d) < 2) {
      plot.new()
      text(0.5, 0.5, "Need 2+ numeric columns", cex = 1.5,
           col = cols$foreground)
      return()
    }
    cor_mat <- cor(num_d, use = "complete.obs")
    cor_df <- as.data.frame(as.table(cor_mat))
    names(cor_df) <- c("Var1", "Var2", "Correlation")

    ggplot(cor_df, aes(Var1, Var2, fill = Correlation)) +
      geom_tile() +
      scale_fill_brand_div(mode = mode) +
      geom_text(aes(label = round(Correlation, 2)), size = 3,
                color = cols$foreground) +
      labs(title = "Correlation Matrix", x = NULL, y = NULL) +
      theme_brand(mode = mode) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })

  output$data_str <- renderPrint({
    str(dat())
  })

  output$download_plot <- downloadHandler(
    filename = function() paste0(input$data, "_plot.png"),
    content = function(file) {
      mode <- dm$mode()
      ggsave(file, plot = current_plot(), width = 10, height = 6, dpi = 150,
             bg = brand_colors(mode)$background)
    }
  )

  output$download_data <- downloadHandler(
    filename = function() paste0(input$data, "_data.csv"),
    content = function(file) {
      write.csv(dat(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
