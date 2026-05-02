# ==========================================================================
# brandkit: edge case tester
# Tests: modals, notifications, progress bars, fileInput, date inputs,
#        navset_card_pill, conditional panels, dynamic UI, tooltips
# ==========================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

ui <- brand_page_sidebar(
  title = "Widget Stress Test",

  sidebar = sidebar(
    width = 300,

    h5("Input widgets"),
    textInput("name", "Text input:", placeholder = "Type something..."),
    textAreaInput("notes", "Text area:", rows = 2, placeholder = "Notes..."),
    passwordInput("pass", "Password:"),
    hr(),

    dateInput("date", "Date picker:"),
    dateRangeInput("date_range", "Date range:"),
    hr(),

    selectInput("select", "Select:", c("Alpha", "Beta", "Gamma", "Delta")),
    selectizeInput("multi", "Multi-select:", c("Red", "Blue", "Green", "Yellow"),
                   multiple = TRUE, selected = c("Red", "Blue")),
    hr(),

    sliderInput("slider", "Slider:", 0, 100, 50),
    sliderInput("range_slider", "Range slider:", 0, 100, c(25, 75)),
    hr(),

    radioButtons("radio", "Radio buttons:", c("Option A", "Option B", "Option C")),
    checkboxGroupInput("checks", "Checkboxes:",
                       c("Item 1", "Item 2", "Item 3"), selected = "Item 1"),
    hr(),

    switchInput_workaround <- checkboxInput("switch1", "Toggle switch", FALSE),
    fileInput("file_upload", "File upload:", accept = ".csv"),
    hr(),

    numericInput("num", "Numeric:", 42, min = 0, max = 100),
    actionButton("action", "Action button", class = "btn-primary w-100 mb-2"),
    actionButton("modal_btn", "Open modal", class = "btn-secondary w-100")
  ),

  # Main content
  navset_card_pill(

    nav_panel(
      "Widgets State",
      card(
        card_header("Current Input Values"),
        verbatimTextOutput("widget_state")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Colour Palette Test"),
          plotOutput("palette_test", height = "250px")
        ),
        card(
          card_header("Faceted Plot"),
          plotOutput("facet_plot", height = "250px")
        )
      )
    ),

    nav_panel(
      "Notifications & Progress",
      layout_columns(
        col_widths = c(4, 4, 4),
        actionButton("notify_msg", "Message", class = "btn-primary"),
        actionButton("notify_warn", "Warning", class = "btn-warning"),
        actionButton("notify_err", "Error", class = "btn-danger")
      ),
      hr(),
      actionButton("run_progress", "Run progress bar", class = "btn-success"),
      hr(),
      card(
        card_header("Conditional Panel"),
        selectInput("cond_select", "Show panel:",
                    c("Plot" = "plot", "Text" = "text", "Table" = "table")),
        conditionalPanel(
          "input.cond_select === 'plot'",
          plotOutput("cond_plot", height = "200px")
        ),
        conditionalPanel(
          "input.cond_select === 'text'",
          p("This is the text panel. Brand fonts and colours should be applied.",
            style = "padding: 20px;")
        ),
        conditionalPanel(
          "input.cond_select === 'table'",
          tableOutput("cond_table")
        )
      )
    ),

    nav_panel(
      "Dynamic UI",
      actionButton("add_card", "Add a card", class = "btn-primary mb-3"),
      uiOutput("dynamic_cards")
    )
  )
)

server <- function(input, output, session) {

  output$widget_state <- renderPrint({
    cat("Text:", input$name, "\n")
    cat("Date:", as.character(input$date), "\n")
    cat("Select:", input$select, "\n")
    cat("Multi:", paste(input$multi, collapse = ", "), "\n")
    cat("Slider:", input$slider, "\n")
    cat("Range:", paste(input$range_slider, collapse = " - "), "\n")
    cat("Radio:", input$radio, "\n")
    cat("Checks:", paste(input$checks, collapse = ", "), "\n")
    cat("Switch:", input$switch1, "\n")
    cat("Numeric:", input$num, "\n")
  })

  output$palette_test <- renderPlot({
    # All palette types in one view
    cols_d <- brand_pal_discrete(n = 6)
    cols_s <- brand_pal_seq(type = "warm", n = 6)
    cols_v <- brand_pal_div(n = 6)

    par(mfrow = c(3, 1), mar = c(1, 6, 2, 1))
    barplot(rep(1, 6), col = cols_d, border = NA, horiz = TRUE,
            axes = FALSE, main = "Discrete")
    barplot(rep(1, 6), col = cols_s, border = NA, horiz = TRUE,
            axes = FALSE, main = "Sequential")
    barplot(rep(1, 6), col = cols_v, border = NA, horiz = TRUE,
            axes = FALSE, main = "Diverging")
  })

  output$facet_plot <- renderPlot({
    ggplot(mpg, aes(displ, hwy, color = drv)) +
      geom_point(size = 2) +
      facet_wrap(~drv) +
      labs(title = "Faceted Scatter")
  })

  # Notifications
  observeEvent(input$notify_msg, {
    showNotification("This is a message notification.", type = "message")
  })
  observeEvent(input$notify_warn, {
    showNotification("This is a warning notification.", type = "warning")
  })
  observeEvent(input$notify_err, {
    showNotification("This is an error notification.", type = "error")
  })

  # Progress bar
  observeEvent(input$run_progress, {
    withProgress(message = "Processing...", value = 0, {
      for (i in 1:10) {
        incProgress(1/10, detail = paste("Step", i))
        Sys.sleep(0.3)
      }
    })
    showNotification("Complete!", type = "message")
  })

  # Modal
  observeEvent(input$modal_btn, {
    showModal(modalDialog(
      title = "Modal Dialog",
      "Does the modal inherit brand styling? Check the header colour, ",
      "button styles, border radius, and fonts.",
      hr(),
      selectInput("modal_select", "Select in modal:", c("A", "B", "C")),
      sliderInput("modal_slider", "Slider in modal:", 0, 10, 5),
      footer = tagList(
        actionButton("modal_ok", "Confirm", class = "btn-primary"),
        modalButton("Cancel")
      )
    ))
  })
  observeEvent(input$modal_ok, {
    removeModal()
    showNotification("Modal confirmed!", type = "message")
  })

  # Conditional panel outputs
  output$cond_plot <- renderPlot({
    ggplot(iris, aes(Sepal.Length, Petal.Length, color = Species)) +
      geom_point(size = 2) +
      labs(title = "Conditional Plot")
  })

  output$cond_table <- renderTable({
    head(iris, 8)
  }, striped = TRUE)

  # Dynamic UI
  card_count <- reactiveVal(0)
  card_list <- reactiveVal(list())

  observeEvent(input$add_card, {
    n <- card_count() + 1
    card_count(n)

    cols <- brand_pal_discrete(n = n)
    new_cards <- lapply(seq_len(n), function(i) {
      card(
        card_header(paste("Dynamic Card", i)),
        div(
          style = paste0("height: 60px; background:", cols[i],
                         "; border-radius: 8px; display: flex; ",
                         "align-items: center; justify-content: center; ",
                         "color: white; font-weight: bold;"),
          paste("Colour", i, ":", cols[i])
        )
      )
    })
    card_list(new_cards)
  })

  output$dynamic_cards <- renderUI({
    cards <- card_list()
    if (length(cards) == 0) return(p("Click 'Add a card' to test dynamic UI."))
    layout_columns(col_widths = rep(4, length(cards)), !!!cards)
  })
}

shinyApp(ui, server)
