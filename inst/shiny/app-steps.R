# ==========================================================================
# Branded Shiny app — step-by-step workflow
# Scaffolded by brandkit::create_brand_shiny_steps()
#
# A pipeline of consecutive steps (set up -> analyse -> report) driven from
# the sidebar: a column of numbered pills on the left, one page of content
# on the right. It is brand_page_sidebar() with two additions, both plain
# bslib:
#
#   navset_pill()    the pills, in the sidebar, stacked into a column by one
#                    CSS rule. Its panels are empty: only the pills are used...
#   navset_hidden()  ...and this holds the real pages, with no tab strip of
#                    its own. One observer below keeps the two in step, and
#                    the Back / Next buttons just move the pills.
#
# The theming is the usual brandkit one: nothing below sets a colour. The
# step badges and the button row take theirs from the Bootstrap variables
# the brand theme defines, so they follow _brand.yml and the dark-mode
# toggle.
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

# A numbered pill. The number is a badge, so it can be drawn as a disc.
step_title <- function(n, label) {
  tagList(span(class = "step-badge", n), label)
}

# The Back / Next row at the foot of a step. Either side can be left out.
step_buttons <- function(id, back = FALSE, nxt = TRUE) {
  div(
    class = "step-buttons",
    if (back) actionButton(paste0("back_", id), "Back",
                           icon = icon("arrow-left"), class = "btn-outline-primary"),
    if (nxt) actionButton(paste0("next_", id), "Next",
                          icon = icon("arrow-right"), class = "btn-primary")
  )
}

# Badge and button-row styling. Only Bootstrap variables here, so the
# brand's colours and the dark-mode toggle reach it without further work.
# On the active pill the disc swaps to the page colour, or it would be the
# pill's own colour on the pill.
step_css <- "
/* The pills run down the sidebar, one per row, each the full width of it. */
.sidebar .nav-pills { flex-direction: column; flex-wrap: nowrap; }
.nav-pills .nav-link { display: flex; align-items: center; }
.step-badge {
  display: inline-flex; align-items: center; justify-content: center;
  flex-shrink: 0; width: 1.5em; height: 1.5em; margin-right: .6em;
  border-radius: 50%; font-size: .8em; font-weight: 700;
  background: var(--bs-primary); color: var(--bs-body-bg);
}
.nav-pills .nav-link.active .step-badge {
  background: var(--bs-body-bg); color: var(--bs-primary);
}
.step-buttons {
  display: flex; justify-content: space-between; gap: .5rem; margin-top: .75rem;
}
.step-buttons .btn:only-child { margin-left: auto; }
"


ui <- brand_page_sidebar(
  title = "Air Quality Report",
  style = "drift",
  tags$style(HTML(step_css)),

  sidebar = sidebar(
    title = "Steps",
    open  = "always",
    navset_pill(
      id = "step",
      nav_panel(step_title(1, "Data"),     value = "data"),
      nav_panel(step_title(2, "Analysis"), value = "analysis"),
      nav_panel(step_title(3, "Report"),   value = "report")
    )
  ),

  navset_hidden(
    id = "content",

    # --- Step 1 ---------------------------------------------------------
    nav_panel_hidden(
      value = "data",
      card(
        card_header("Choose the data"),
        selectInput("measure", "Measure", measures),
        checkboxGroupInput("months", "Months", levels(aq$Month),
                           selected = levels(aq$Month), inline = TRUE)
      ),
      card(
        card_header("Preview"),
        tableOutput("preview")
      ),
      step_buttons("data", back = FALSE)
    ),

    # --- Step 2 ---------------------------------------------------------
    nav_panel_hidden(
      value = "analysis",
      card(
        card_header("Temperature against the measure"),
        plotOutput("scatter", height = "380px"),
        textOutput("fit_summary")
      ),
      step_buttons("analysis", back = TRUE)
    ),

    # --- Step 3 ---------------------------------------------------------
    nav_panel_hidden(
      value = "report",
      card(
        card_header("Monthly means"),
        tableOutput("monthly"),
        textInput("report_name", "File name", "air-quality"),
        downloadButton("download", "Download CSV", class = "btn-primary")
      ),
      step_buttons("report", back = TRUE, nxt = FALSE)
    )
  )
)


server <- function(input, output, session) {

  # --- Navigation -------------------------------------------------------
  # The pills are the one source of truth for the current step; the page
  # follows them, and so do the buttons, by moving the pills.
  observeEvent(input$step, nav_select("content", input$step))

  go <- function(button, to) {
    observeEvent(input[[button]], nav_select("step", to))
  }
  go("next_data",     "analysis")
  go("back_analysis", "data")
  go("next_analysis", "report")
  go("back_report",   "analysis")

  # --- Data -------------------------------------------------------------
  chosen <- reactive({
    req(input$measure, input$months)
    d <- aq[aq$Month %in% input$months & !is.na(aq[[input$measure]]), ]
    d$value <- d[[input$measure]]
    d
  })

  output$preview <- renderTable(
    head(chosen()[c("Month", "Day", "Temp", "value")], 8),
    striped = TRUE, width = "100%"
  )

  # --- Analysis ---------------------------------------------------------
  output$scatter <- renderPlot({
    d <- chosen()
    ggplot(d, aes(Temp, value, color = Month)) +
      geom_point(size = 3) +
      geom_smooth(aes(color = NULL), method = "lm", formula = y ~ x, se = FALSE) +
      labs(x = "Temperature (°F)", y = names(measures)[measures == input$measure],
           color = NULL)
  })

  output$fit_summary <- renderText({
    d <- chosen()
    req(nrow(d) > 2)
    fit <- lm(value ~ Temp, d)
    sprintf("Linear fit on %d days: R² = %.3f", nrow(d), summary(fit)$r.squared)
  })

  # --- Report -----------------------------------------------------------
  monthly <- reactive({
    d <- chosen()
    aggregate(cbind(Temp, value) ~ Month, d, mean)
  })

  output$monthly <- renderTable({
    out <- monthly()
    names(out)[3] <- names(measures)[measures == input$measure]
    out
  }, striped = TRUE, digits = 1, width = "100%")

  output$download <- downloadHandler(
    filename = function() paste0(input$report_name, ".csv"),
    content  = function(file) utils::write.csv(monthly(), file, row.names = FALSE)
  )
}


shinyApp(ui, server)
