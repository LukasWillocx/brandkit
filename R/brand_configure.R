# --------------------------------------------------------------------------
# brandkit: brand_configure.R
# Interactive Shiny wizard to generate a _brand.yml from scratch.
# --------------------------------------------------------------------------

#' Launch the Brand Configurator
#'
#' Opens an interactive Shiny app that walks you through palette selection,
#' font choice, logo upload, and live preview. On save, writes a complete
#' `_brand.yml` (and optional font/logo assets) to a target directory.
#'
#' @param path Directory to write the generated `_brand.yml` and assets.
#'   Default is the current working directory.
#'
#' @return Called for side effect (launches Shiny app). Invisibly returns
#'   the path to the saved `_brand.yml`.
#' @export
configure_brand <- function(path = ".") {

  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Install the 'shiny' package to use the configurator.", call. = FALSE)
  }
  if (!requireNamespace("colourpicker", quietly = TRUE)) {
    stop("Install the 'colourpicker' package to use the configurator.", call. = FALSE)
  }

  path <- normalizePath(path, mustWork = TRUE)

  # -- Prebuilt palettes: professional → playful --
  presets <- list(
    # --- Professional ---
    "Corporate Navy" = list(
      primary = "#1b2a4a", secondary = "#c0945b", success = "#2e7d32",
      danger = "#b71c1c", warning = "#e6a817", info = "#37718e",
      light = "#f0f2f5", dark = "#1a1d23"
    ),
    "Charcoal & Steel" = list(
      primary = "#333333", secondary = "#607d8b", success = "#388e3c",
      danger = "#d32f2f", warning = "#fbc02d", info = "#5c8db5",
      light = "#f5f5f5", dark = "#212121"
    ),
    "Slate & Teal" = list(
      primary = "#2c3e50", secondary = "#1abc9c", success = "#27ae60",
      danger = "#e74c3c", warning = "#f39c12", info = "#2980b9",
      light = "#ecf0f1", dark = "#1a252f"
    ),
    # --- Refined ---
    "Wine & Sage" = list(
      primary = "#570a10", secondary = "#ad720a", success = "#325106",
      danger = "#d64550", warning = "#cda029", info = "#5a8cb5",
      light = "#bad9cf", dark = "#1a1c1a"
    ),
    "Plum & Gold" = list(
      primary = "#4a1942", secondary = "#c9a227", success = "#27ae60",
      danger = "#e74c3c", warning = "#f1c40f", info = "#8e44ad",
      light = "#f4ecf7", dark = "#1a0a18"
    ),
    "Ocean & Coral" = list(
      primary = "#1a5276", secondary = "#e74c3c", success = "#1e8449",
      danger = "#c0392b", warning = "#f39c12", info = "#3498db",
      light = "#eaf2f8", dark = "#0e2f44"
    ),
    "Forest & Amber" = list(
      primary = "#2d5016", secondary = "#b8860b", success = "#3a7d44",
      danger = "#c0392b", warning = "#d4a017", info = "#4682b4",
      light = "#e8f0e4", dark = "#1a2612"
    ),
    # --- Warm & inviting ---
    "Terracotta & Cream" = list(
      primary = "#a0522d", secondary = "#6b8e23", success = "#3a7d44",
      danger = "#cd5c5c", warning = "#daa520", info = "#708090",
      light = "#faf3eb", dark = "#2c1810"
    ),
    "Espresso & Caramel" = list(
      primary = "#3e2723", secondary = "#d4a574", success = "#558b2f",
      danger = "#c62828", warning = "#f9a825", info = "#5d8aa8",
      light = "#f5f0eb", dark = "#1a1210"
    ),
    # --- Light-hearted & modern ---
    "Mint & Peach" = list(
      primary = "#26a69a", secondary = "#ff8a65", success = "#66bb6a",
      danger = "#ef5350", warning = "#ffca28", info = "#42a5f5",
      light = "#f1f8f6", dark = "#1a2c2a"
    ),
    "Lavender & Rose" = list(
      primary = "#7e57c2", secondary = "#ec407a", success = "#66bb6a",
      danger = "#ef5350", warning = "#ffca28", info = "#42a5f5",
      light = "#f3f0fa", dark = "#1e1730"
    ),
    "Sunset Gradient" = list(
      primary = "#e65100", secondary = "#ad1457", success = "#2e7d32",
      danger = "#c62828", warning = "#ff8f00", info = "#0277bd",
      light = "#fff8f0", dark = "#1a1210"
    ),
    "Custom" = NULL
  )

  # -- Google Font pairs: grouped by character --
  font_pairs <- list(
    # --- Clean & professional ---
    "Inter / Inter"                    = list(base = "Inter", heading = "Inter"),
    "Manrope / Montserrat"             = list(base = "Manrope", heading = "Montserrat"),
    "Source Sans 3 / Source Serif 4"   = list(base = "Source Sans 3", heading = "Source Serif 4"),
    "Roboto / Roboto Slab"             = list(base = "Roboto", heading = "Roboto Slab"),
    # --- Modern & geometric ---
    "Lato / Poppins"                   = list(base = "Lato", heading = "Poppins"),
    "Nunito / Raleway"                 = list(base = "Nunito", heading = "Raleway"),
    "DM Sans / DM Serif Display"       = list(base = "DM Sans", heading = "DM Serif Display"),
    "Outfit / Outfit"                  = list(base = "Outfit", heading = "Outfit"),
    # --- Warm & editorial ---
    "Open Sans / Lora"                 = list(base = "Open Sans", heading = "Lora"),
    "Nunito / Merriweather"            = list(base = "Nunito", heading = "Merriweather"),
    "Inter / Playfair Display"         = list(base = "Inter", heading = "Playfair Display"),
    "Libre Franklin / Libre Baskerville" = list(base = "Libre Franklin", heading = "Libre Baskerville"),
    # --- Friendly & rounded ---
    "Quicksand / Quicksand"            = list(base = "Quicksand", heading = "Quicksand"),
    "Nunito Sans / Nunito"             = list(base = "Nunito Sans", heading = "Nunito"),
    "Rubik / Rubik"                    = list(base = "Rubik", heading = "Rubik"),
    "Custom"                           = NULL
  )

  # ===== UI =====
  ui <- bslib::page_fluid(
    theme = bslib::bs_theme(version = 5, preset = "flatly"),
    title = "brandkit configurator",

    htmltools::tags$head(htmltools::tags$style(htmltools::HTML('
      .color-preview {
        width: 100%; height: 36px; border-radius: 6px;
        border: 1px solid #ddd; margin-bottom: 8px;
      }
      .step-panel { min-height: 400px; }
      .preview-card { border: 2px solid var(--bs-primary); }
      body { padding: 1rem 2rem; }
    '))),

    # Reactive font loader — injected into head, updated from server
    shiny::uiOutput("font_loader"),

    htmltools::h2("brandkit configurator", style = "margin-bottom: 1.5rem;"),

    bslib::navset_pill(
      id = "wizard_step",

      # ----- Step 1: Colours -----
      bslib::nav_panel(
        "1. Colours",
        htmltools::div(
          class = "step-panel",
          bslib::layout_columns(
            col_widths = c(4, 8),

            # Left: controls
            bslib::card(
              bslib::card_header("Colour palette"),
              shiny::selectInput("preset", "Start from a preset:",
                                 names(presets), selected = "Wine & Sage"),
              htmltools::hr(),
              colourpicker::colourInput("col_primary", "Primary", "#570a10"),
              colourpicker::colourInput("col_secondary", "Secondary", "#ad720a"),
              colourpicker::colourInput("col_success", "Success", "#325106"),
              colourpicker::colourInput("col_danger", "Danger", "#d64550"),
              colourpicker::colourInput("col_warning", "Warning", "#cda029"),
              colourpicker::colourInput("col_info", "Info", "#5a8cb5"),
              htmltools::hr(),
              colourpicker::colourInput("col_light", "Background (light)", "#bad9cf"),
              colourpicker::colourInput("col_dark", "Foreground (dark)", "#1a1c1a"),
              htmltools::hr(),
              shiny::checkboxInput("auto_dark", "Auto-generate dark mode palette", TRUE)
            ),

            # Right: preview
            bslib::card(
              bslib::card_header("Preview"),
              shiny::uiOutput("colour_preview"),
              htmltools::hr(),
              htmltools::h5("Dark mode (auto-generated):"),
              shiny::uiOutput("dark_preview")
            )
          )
        )
      ),

      # ----- Step 2: Fonts -----
      bslib::nav_panel(
        "2. Fonts",
        htmltools::div(
          class = "step-panel",
          bslib::layout_columns(
            col_widths = c(4, 8),
            bslib::card(
              bslib::card_header("Typography"),
              shiny::selectInput("font_pair", "Font pairing:",
                                 names(font_pairs), selected = "Manrope / Montserrat"),
              htmltools::hr(),
              shiny::textInput("font_base", "Body font:", "Manrope"),
              shiny::textInput("font_heading", "Heading font:", "Montserrat"),
              htmltools::hr(),
              shiny::numericInput("font_size", "Base size (rem):", 1, min = 0.7, max = 1.5, step = 0.05),
              shiny::numericInput("line_height", "Line height:", 1.65, min = 1.2, max = 2, step = 0.05)
            ),
            bslib::card(
              bslib::card_header("Preview"),
              shiny::uiOutput("font_preview")
            )
          )
        )
      ),

      # ----- Step 3: Meta & Logo -----
      bslib::nav_panel(
        "3. Meta & Logo",
        htmltools::div(
          class = "step-panel",
          bslib::layout_columns(
            col_widths = c(4, 8),
            bslib::card(
              bslib::card_header("Brand identity"),
              shiny::textInput("brand_name", "Brand name:", "My Brand"),
              shiny::fileInput("logo_file", "Logo (optional):",
                               accept = c("image/png", "image/svg+xml", "image/jpeg")),
              htmltools::hr(),
              shiny::numericInput("border_radius", "Border radius (rem):", 0.75,
                                 min = 0, max = 2, step = 0.25)
            ),
            bslib::card(
              bslib::card_header("Preview"),
              shiny::uiOutput("meta_preview")
            )
          )
        )
      ),

      # ----- Step 4: Review & Save -----
      bslib::nav_panel(
        "4. Save",
        htmltools::div(
          class = "step-panel",
          bslib::layout_columns(
            col_widths = c(6, 6),
            bslib::card(
              bslib::card_header("Generated _brand.yml"),
              shiny::verbatimTextOutput("yml_preview")
            ),
            bslib::card(
              bslib::card_header("Live preview"),
              shiny::plotOutput("final_plot", height = "250px"),
              htmltools::hr(),
              shiny::uiOutput("final_card_preview")
            )
          ),
          htmltools::div(
            style = "margin-top: 1rem; text-align: right;",
            htmltools::tags$label(
              paste("Save to:", path),
              style = "margin-right: 1rem; color: #666;"
            ),
            shiny::actionButton("save_brand", "Save & Close",
                                class = "btn-lg btn-success")
          )
        )
      )
    )
  )

  # ===== Server =====
  server <- function(input, output, session) {

    # -- Preset sync --
    shiny::observeEvent(input$preset, {
      p <- presets[[input$preset]]
      if (!is.null(p)) {
        colourpicker::updateColourInput(session, "col_primary", value = p$primary)
        colourpicker::updateColourInput(session, "col_secondary", value = p$secondary)
        colourpicker::updateColourInput(session, "col_success", value = p$success)
        colourpicker::updateColourInput(session, "col_danger", value = p$danger)
        colourpicker::updateColourInput(session, "col_warning", value = p$warning)
        colourpicker::updateColourInput(session, "col_info", value = p$info)
        colourpicker::updateColourInput(session, "col_light", value = p$light)
        colourpicker::updateColourInput(session, "col_dark", value = p$dark)
      }
    })

    # -- Font pair sync --
    shiny::observeEvent(input$font_pair, {
      fp <- font_pairs[[input$font_pair]]
      if (!is.null(fp)) {
        shiny::updateTextInput(session, "font_base", value = fp$base)
        shiny::updateTextInput(session, "font_heading", value = fp$heading)
      }
    })

    # -- Reactive Google Font loader (updates all previews) --
    output$font_loader <- shiny::renderUI({
      base <- input$font_base
      heading <- input$font_heading
      families <- unique(c(base, heading))
      url <- paste0(
        "https://fonts.googleapis.com/css2?",
        paste0("family=", gsub(" ", "+", families), ":wght@400;700", collapse = "&"),
        "&display=swap"
      )
      htmltools::tags$head(htmltools::tags$link(rel = "stylesheet", href = url))
    })

    # -- Reactive colours --
    light_cols <- shiny::reactive({
      list(
        primary = input$col_primary, secondary = input$col_secondary,
        success = input$col_success, danger = input$col_danger,
        warning = input$col_warning, info = input$col_info,
        light = input$col_light, dark = input$col_dark,
        foreground = input$col_dark, background = input$col_light
      )
    })

    dark_cols <- shiny::reactive({
      if (!input$auto_dark) return(NULL)
      lc <- light_cols()
      list(
        primary    = auto_dark_variant(lc$primary),
        secondary  = auto_dark_variant(lc$secondary),
        success    = auto_dark_variant(lc$success),
        danger     = auto_dark_variant(lc$danger),
        warning    = auto_dark_variant(lc$warning),
        info       = auto_dark_variant(lc$info),
        light      = auto_dark_bg(lc$dark),
        dark       = auto_dark_fg(lc$light),
        foreground = auto_dark_fg(lc$light),
        background = auto_dark_bg(lc$dark)
      )
    })

    # -- Colour preview --
    output$colour_preview <- shiny::renderUI({
      lc <- light_cols()
      swatch <- function(nm, hex) {
        htmltools::div(
          style = paste0(
            "flex: 1; min-width: 60px; text-align: center; ",
            "padding: 12px 4px; border-radius: 6px; ",
            "background:", hex, "; ",
            "color:", if (is_dark_colour(hex)) "white" else "black", "; ",
            "font-size: 11px; font-weight: bold;"
          ),
          nm
        )
      }
      htmltools::div(
        style = paste0("background:", lc$light, "; padding: 16px; border-radius: 8px;"),
        htmltools::div(
          style = "display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 10px;",
          swatch("primary", lc$primary), swatch("secondary", lc$secondary),
          swatch("success", lc$success), swatch("danger", lc$danger),
          swatch("warning", lc$warning), swatch("info", lc$info)
        ),
        htmltools::div(
          style = "display: flex; gap: 6px;",
          htmltools::div(
            style = paste0(
              "flex: 1; padding: 10px; border-radius: 6px; text-align: center; ",
              "background:", lc$light, "; color:", lc$dark, "; ",
              "border: 1px solid ", lc$dark, "; font-size: 11px; font-weight: bold;"
            ),
            paste0("background: ", lc$light)
          ),
          htmltools::div(
            style = paste0(
              "flex: 1; padding: 10px; border-radius: 6px; text-align: center; ",
              "background:", lc$dark, "; color:", lc$light, "; ",
              "font-size: 11px; font-weight: bold;"
            ),
            paste0("foreground: ", lc$dark)
          )
        )
      )
    })

    output$dark_preview <- shiny::renderUI({
      dc <- dark_cols()
      if (is.null(dc)) return(htmltools::p("Dark mode auto-generation disabled."))
      htmltools::div(
        style = paste0("background:", dc$background,
                       "; padding: 16px; border-radius: 8px;"),
        htmltools::div(
          style = "display: flex; gap: 6px; flex-wrap: wrap;",
          lapply(c("primary", "secondary", "success", "danger", "warning", "info"),
                 function(nm) {
                   htmltools::div(
                     style = paste0(
                       "flex: 1; min-width: 60px; text-align: center; ",
                       "padding: 12px 4px; border-radius: 6px; ",
                       "background:", dc[[nm]], "; ",
                       "color:", if (is_dark_colour(dc[[nm]])) "white" else "black", "; ",
                       "font-size: 11px; font-weight: bold;"
                     ),
                     nm
                   )
                 })
        )
      )
    })

    # -- Font preview --
    output$font_preview <- shiny::renderUI({
      base <- input$font_base
      heading <- input$font_heading
      lc <- light_cols()
      htmltools::div(
        style = paste0("padding: 20px; background:", lc$light,
                       "; border-radius: 8px;"),
        htmltools::h2(
          "Heading in ", heading,
          style = paste0("font-family:'", heading, "', sans-serif;",
                         " color:", lc$primary, "; font-weight: 700;")
        ),
        htmltools::p(
          "Body text in ", base, ". This is what your paragraphs, labels, ",
          "and general content will look like across Shiny, Quarto, and plots.",
          style = paste0("font-family:'", base, "', sans-serif;",
                         " color:", lc$dark,
                         "; font-size:", input$font_size, "rem;",
                         " line-height:", input$line_height, ";")
        ),
        htmltools::p(
          htmltools::strong("Bold text"), " and ",
          htmltools::em("italic text"), " samples.",
          style = paste0("font-family:'", base, "', sans-serif; color:", lc$dark, ";")
        ),
        htmltools::h4(
          "Card header sample",
          style = paste0("font-family:'", heading, "', sans-serif;",
                         " color:", lc$primary, "; font-weight: 700;",
                         " margin-top: 16px;")
        ),
        htmltools::p(
          "This shows how card headers and titles will render with your heading font.",
          style = paste0("font-family:'", base, "', sans-serif; color:", lc$dark, ";")
        )
      )
    })

    # -- Meta preview --
    output$meta_preview <- shiny::renderUI({
      lc <- light_cols()
      base <- input$font_base
      heading <- input$font_heading
      logo_tag <- NULL
      if (!is.null(input$logo_file)) {
        # Serve logo via Shiny resource path
        logo_dir <- dirname(input$logo_file$datapath)
        logo_name <- basename(input$logo_file$datapath)
        shiny::addResourcePath("brandkit-preview-logo", logo_dir)
        logo_tag <- htmltools::img(
          src = paste0("brandkit-preview-logo/", logo_name),
          style = "max-height: 80px; margin-bottom: 12px;"
        )
      }
      htmltools::div(
        style = paste0("padding: 20px; background:", lc$light,
                       "; border-radius: ", input$border_radius, "rem;",
                       " font-family:'", base, "', sans-serif;"),
        logo_tag,
        htmltools::h3(input$brand_name,
                      style = paste0("color:", lc$primary,
                                     "; font-family:'", heading, "', sans-serif;",
                                     " font-weight: 700;")),
        htmltools::p("Cards, buttons, and containers will use this border radius.",
                     style = paste0("color:", lc$dark, ";")),
        htmltools::div(
          style = paste0(
            "display: inline-block; padding: 8px 20px; ",
            "background:", lc$primary, "; color: white; ",
            "border-radius:", input$border_radius, "rem; font-weight: bold;",
            " font-family:'", base, "', sans-serif;"
          ),
          "Sample Button"
        )
      )
    })

    # -- Build YAML --
    brand_yml <- shiny::reactive({
      lc <- light_cols()
      dc <- dark_cols()

      cfg <- list(
        meta = list(name = input$brand_name),
        color = list(
          primary = lc$primary, secondary = lc$secondary,
          success = lc$success, danger = lc$danger,
          warning = lc$warning, info = lc$info,
          light = lc$light, dark = lc$dark,
          foreground = lc$dark, background = lc$light
        ),
        typography = list(
          fonts = list(
            list(family = input$font_base, source = "google"),
            list(family = input$font_heading, source = "google")
          ),
          base = list(
            family = input$font_base,
            size = paste0(input$font_size, "rem"),
            `line-height` = input$line_height,
            weight = 400L
          ),
          headings = list(
            family = input$font_heading,
            weight = 700L,
            `line-height` = 1.1
          )
        ),
        theme = list(
          `border-radius`    = paste0(input$border_radius, "rem"),
          `border-radius-sm` = paste0(max(input$border_radius - 0.25, 0), "rem"),
          `border-radius-lg` = paste0(input$border_radius + 0.25, "rem")
        )
      )

      # Logo (if uploaded)
      if (!is.null(input$logo_file)) {
        logo_path <- file.path("logo", input$logo_file$name)
        cfg$logo <- list(
          small  = logo_path,
          medium = logo_path,
          large  = logo_path
        )
      }

      if (!is.null(dc)) {
        cfg[["color-dark"]] <- list(
          primary = dc$primary, secondary = dc$secondary,
          success = dc$success, danger = dc$danger,
          warning = dc$warning, info = dc$info,
          light = dc$light, dark = dc$dark,
          foreground = dc$foreground, background = dc$background
        )
      }

      cfg
    })

    output$yml_preview <- shiny::renderPrint({
      cat(yaml::as.yaml(brand_yml()))
    })

    # -- Final preview plot --
    output$final_plot <- shiny::renderPlot({
      lc <- light_cols()
      base <- input$font_base
      heading <- input$font_heading
      pal <- c(lc$primary, lc$secondary, lc$success, lc$danger, lc$warning, lc$info)

      # Try to register the selected font for plot text
      font_family <- ""
      if (requireNamespace("sysfonts", quietly = TRUE) &&
          requireNamespace("showtext", quietly = TRUE)) {
        tryCatch({
          sysfonts::font_add_google(heading, heading)
          sysfonts::font_add_google(base, base)
          showtext::showtext_auto()
          font_family <- base
        }, error = function(e) NULL)
      }

      par(bg = lc$light, mar = c(2, 2, 3, 1),
          family = if (nzchar(font_family)) font_family else "sans")
      barplot(
        c(8, 6, 5, 4, 3, 2), col = pal, border = NA,
        names.arg = c("Primary", "Sec.", "Success", "Danger", "Warn.", "Info"),
        main = paste(input$brand_name, "\u2014 palette"),
        col.main = lc$dark, col.axis = lc$dark, col.lab = lc$dark,
        font.main = 2  # bold
      )
    })

    output$final_card_preview <- shiny::renderUI({
      lc <- light_cols()
      base <- input$font_base
      heading <- input$font_heading
      htmltools::div(
        style = paste0(
          "background:", lc$light, "; padding: 16px; ",
          "border-radius:", input$border_radius, "rem; ",
          "border: 1px solid ", lc$primary, ";",
          " font-family:'", base, "', sans-serif;"
        ),
        htmltools::h4(input$brand_name,
                      style = paste0("color:", lc$primary,
                                     "; margin: 0 0 8px 0;",
                                     " font-family:'", heading, "', sans-serif;",
                                     " font-weight: 700;")),
        htmltools::p("This is how a branded card will look.",
                     style = paste0("color:", lc$dark, "; margin: 0;"))
      )
    })

    # -- Save --
    shiny::observeEvent(input$save_brand, {
      cfg <- brand_yml()
      dest <- file.path(path, "_brand.yml")
      yaml::write_yaml(cfg, dest)

      # Copy logo file if uploaded
      if (!is.null(input$logo_file)) {
        logo_dir <- file.path(path, "logo")
        if (!dir.exists(logo_dir)) dir.create(logo_dir)
        logo_dest <- file.path(logo_dir, input$logo_file$name)
        file.copy(input$logo_file$datapath, logo_dest, overwrite = TRUE)
      }

      # Reload the cache so subsequent brandkit calls use the new brand
      tryCatch(
        brand_init(dest, quiet = FALSE),
        error = function(e) NULL
      )

      shiny::showNotification(
        paste("\u2714 Saved _brand.yml to", dest, "\u2014 closing configurator..."),
        type = "message", duration = 2
      )

      # Graceful shutdown after a brief pause for the notification
      later::later(function() {
        shiny::stopApp(returnValue = dest)
      }, delay = 1.5)
    })
  }

  result <- shiny::runApp(shiny::shinyApp(ui, server), launch.browser = TRUE)
  invisible(result)
}


# --------------------------------------------------------------------------
# Internal: auto-generate dark mode colour variants
# --------------------------------------------------------------------------

#' Lighten a colour for dark mode (semantic colours need to pop on dark bg)
#' @keywords internal
auto_dark_variant <- function(hex) {
  hsl <- grDevices::col2rgb(hex)
  # Lighten and slightly desaturate for dark backgrounds
  colorspace::lighten(hex, amount = 0.35)
}

#' Generate dark background from light foreground
#' @keywords internal
auto_dark_bg <- function(hex) {
  colorspace::darken(hex, amount = 0.85)
}

#' Generate light foreground from dark background
#' @keywords internal
auto_dark_fg <- function(hex) {
  colorspace::lighten(hex, amount = 0.8)
}

#' Check if a hex colour is perceptually dark
#' @keywords internal
is_dark_colour <- function(hex) {
  rgb <- grDevices::col2rgb(hex)
  # Relative luminance approximation
  lum <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  lum < 0.5
}
