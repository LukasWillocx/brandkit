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
#' The `_brand.yml` this writes uses the Shiny/bslib format (`color-dark:`,
#' `theme:` sections) — Quarto's own renderer does not accept those keys.
#' If `path` is also used for a Quarto project, re-run whichever of
#' [create_brand_quarto_html()], [create_brand_quarto_slides()], or
#' [create_brand_quarto_pdf()] you use after saving here; they detect and
#' convert a bslib-format `_brand.yml` automatically.
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
    # --- Unconventional (still readable) ---
    "Space Mono / Space Grotesk"       = list(base = "Space Mono", heading = "Space Grotesk"),
    "Karla / Bungee"                   = list(base = "Karla", heading = "Bungee"),
    "Custom"                           = NULL
  )

  # ===== UI =====
  ui <- bslib::page_sidebar(
    title = "brandkit configurator",
    theme = bslib::bs_theme(version = 5, preset = "flatly", brand = FALSE),

    sidebar = bslib::sidebar(
      width = 380,
      bslib::accordion(
        id = "config_accordion",
        open = FALSE,

        bslib::accordion_panel(
          "Colours",
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

        bslib::accordion_panel(
          "Fonts",
          shiny::selectInput(
            "font_pair",
            label = htmltools::tagList(
              "Font pairing:",
              bslib::popover(
                htmltools::tags$span(
                  "ⓘ",
                  style = paste0(
                    "cursor: pointer; font-weight: bold; margin-left: 6px; ",
                    "color: var(--bs-primary);"
                  )
                ),
                title = "Using your own system fonts",
                htmltools::tags$p(
                  "Want a font already installed on this computer instead ",
                  "of a Google Font? Pick \"Custom\" above, then type its ",
                  "exact name into the Body font / Heading font boxes below."
                ),
                htmltools::tags$p(htmltools::strong("Where to look it up:")),
                htmltools::tags$ul(
                  htmltools::tags$li("Windows: Settings → Personalization → Fonts"),
                  htmltools::tags$li("macOS: Font Book (Cmd+Space, search \"Font Book\")"),
                  htmltools::tags$li("Linux: run ", htmltools::code("fc-list"), " in a terminal")
                ),
                htmltools::tags$p(
                  htmltools::em(
                    "A system font only renders correctly on machines that ",
                    "have it installed — it won't carry over to Quarto/PDF ",
                    "rendering unless you also supply the font file."
                  )
                )
              )
            ),
            choices = names(font_pairs), selected = "Manrope / Montserrat"
          ),
          htmltools::hr(),
          shiny::textInput("font_base", "Body font:", "Manrope"),
          shiny::textInput("font_heading", "Heading font:", "Montserrat"),
          shiny::textInput("font_mono", "Code font:", "Manrope"),
          htmltools::hr(),
          shiny::numericInput("font_size", "Base size (rem):", 1, min = 0.7, max = 1.5, step = 0.05),
          shiny::numericInput("line_height", "Line height:", 1.65, min = 1.2, max = 2, step = 0.05)
        ),

        bslib::accordion_panel(
          "Meta & Logo",
          shiny::textInput("brand_name", "Brand name:", "My Brand"),
          shiny::fileInput("logo_file", "Logo (optional):",
                           accept = c("image/png", "image/svg+xml", "image/jpeg")),
          htmltools::hr(),
          shiny::numericInput("border_radius", "Border radius (rem):", 0.75,
                             min = 0, max = 2, step = 0.25)
        )
      ),

      htmltools::hr(),
      htmltools::div(
        style = "font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;",
        paste("Save to:", path)
      ),
      shiny::actionButton("save_brand", "Save & Close",
                          class = "btn-lg btn-success w-100")
    ),

    # Reactive font loader — injected into head, updated from server
    shiny::uiOutput("font_loader"),

    bslib::navset_tab(
      id = "main_tabs",

      # ----- Live preview (default) -----
      bslib::nav_panel(
        "Live Preview",
        htmltools::div(
          style = "padding-top: 1rem;",
          shiny::uiOutput("preview_banner"),
          bslib::layout_columns(
            col_widths = c(6, 6),
            shiny::uiOutput("preview_light"),
            shiny::uiOutput("preview_dark")
          )
        )
      ),

      # ----- Raw YAML -----
      bslib::nav_panel(
        "YAML",
        htmltools::div(
          style = "padding-top: 1rem;",
          bslib::card(
            bslib::card_header("Generated _brand.yml"),
            shiny::verbatimTextOutput("yml_preview")
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
    # Code font defaults to the body font on every pairing switch (kept a
    # freely-editable text input afterward, same as font_base/font_heading,
    # so it's still a default, not a lock).
    shiny::observeEvent(input$font_pair, {
      fp <- font_pairs[[input$font_pair]]
      if (!is.null(fp)) {
        shiny::updateTextInput(session, "font_base", value = fp$base)
        shiny::updateTextInput(session, "font_heading", value = fp$heading)
        shiny::updateTextInput(session, "font_mono", value = fp$base)
      }
    })

    # -- Reactive Google Font loader (updates all previews) --
    output$font_loader <- shiny::renderUI({
      base <- input$font_base
      heading <- input$font_heading
      mono <- input$font_mono
      families <- unique(c(base, heading, mono))
      url <- paste0(
        "https://fonts.googleapis.com/css2?",
        paste0("family=", gsub(" ", "+", families), ":wght@400;700", collapse = "&"),
        "&display=swap"
      )
      htmltools::tags$head(htmltools::tags$link(rel = "stylesheet", href = url))
    })

    # -- Reactive colours --
    # Debounced: colourpicker's updateColourInput() round-trips each
    # input through its JS widget individually, so applying a preset
    # (8 inputs at once) arrives back on the server as a staggered burst
    # of separate changes rather than one atomic update — visible as the
    # preview flickering through intermediate combinations before it
    # settles. Debouncing waits for the burst to finish before any
    # downstream output (banner/cards/plot/YAML) recomputes.
    light_cols_raw <- shiny::reactive({
      list(
        primary = input$col_primary, secondary = input$col_secondary,
        success = input$col_success, danger = input$col_danger,
        warning = input$col_warning, info = input$col_info,
        light = input$col_light, dark = input$col_dark,
        foreground = input$col_dark, background = input$col_light
      )
    })
    light_cols <- shiny::debounce(light_cols_raw, millis = 200)

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

    # -- Logo tag (shared by banner preview) --
    logo_tag <- shiny::reactive({
      if (is.null(input$logo_file)) return(NULL)
      # Serve logo via Shiny resource path
      logo_dir <- dirname(input$logo_file$datapath)
      logo_name <- basename(input$logo_file$datapath)
      shiny::addResourcePath("brandkit-preview-logo", logo_dir)
      htmltools::img(
        src = paste0("brandkit-preview-logo/", logo_name),
        style = "max-height: 56px; margin-bottom: 10px;"
      )
    })

    # -- Banner preview (mirrors the .brand-banner used in the scaffolded
    #    HTML report, so this preview matches what create_brand_quarto_html()
    #    actually produces) --
    output$preview_banner <- shiny::renderUI({
      lc <- light_cols()
      htmltools::div(
        style = paste0(
          "background:", lc$primary, "; color: white; text-align: center; ",
          "padding: 2rem 1rem; border-radius:", input$border_radius, "rem; ",
          "margin-bottom: 1rem;"
        ),
        logo_tag(),
        htmltools::h2(
          input$brand_name,
          style = paste0(
            "font-family:'", input$font_heading, "', sans-serif;",
            " font-weight: 700; margin: 0; color: white;"
          )
        )
      )
    })

    # -- Light / dark mode previews: one bordered surface per mode,
    #    holding swatches and a stress-test line chart — no nested
    #    boxes-within-boxes.
    output$preview_light <- shiny::renderUI({
      lc <- light_cols()
      htmltools::div(
        style = paste0(
          "background:", lc$background, "; padding: 16px; ",
          "border-radius:", input$border_radius, "rem; ",
          "box-shadow: 0 1px 3px rgba(0,0,0,.08), 0 4px 12px rgba(0,0,0,.06);"
        ),
        brandkit_mode_label(lc, "Light Mode"),
        brandkit_swatches(lc),
        htmltools::div(
          style = "margin-top: 14px;",
          brandkit_typography_sample(lc, input$font_base, input$font_heading,
                                     input$font_mono, input$brand_name,
                                     input$font_size, input$line_height)
        ),
        htmltools::div(
          style = "margin-top: 10px;",
          shiny::plotOutput("preview_plot_light", height = "220px")
        )
      )
    })

    output$preview_dark <- shiny::renderUI({
      dc <- dark_cols()
      if (is.null(dc)) {
        return(htmltools::div(
          style = "padding: 20px; text-align: center; color: #999; font-style: italic;",
          "Dark mode auto-generation disabled."
        ))
      }
      htmltools::div(
        style = paste0(
          "background:", dc$background, "; padding: 16px; ",
          "border-radius:", input$border_radius, "rem; ",
          "box-shadow: 0 1px 3px rgba(0,0,0,.08), 0 4px 12px rgba(0,0,0,.06);"
        ),
        brandkit_mode_label(dc, "Dark Mode"),
        brandkit_swatches(dc),
        htmltools::div(
          style = "margin-top: 14px;",
          brandkit_typography_sample(dc, input$font_base, input$font_heading,
                                     input$font_mono, input$brand_name,
                                     input$font_size, input$line_height)
        ),
        htmltools::div(
          style = "margin-top: 10px;",
          shiny::plotOutput("preview_plot_dark", height = "220px")
        )
      )
    })

    # -- Stress-test line charts: several jittery, overlapping series in
    #    the palette colours, so two colours that are too close to tell
    #    apart (or don't stand out against the background) show up
    #    immediately, the way flat swatches never reveal. The underlying
    #    random walks are seeded so only the colours change on tweak —
    #    a stable "same bad case, different palette" comparison.
    output$preview_plot_light <- shiny::renderPlot({
      lc <- light_cols()
      pal <- c(lc$primary, lc$secondary, lc$success, lc$danger, lc$warning, lc$info)
      brandkit_stress_plot(pal, bg = lc$background, fg = lc$foreground)
    }, res = 96)

    output$preview_plot_dark <- shiny::renderPlot({
      dc <- dark_cols()
      shiny::req(dc)
      pal <- c(dc$primary, dc$secondary, dc$success, dc$danger, dc$warning, dc$info)
      brandkit_stress_plot(pal, bg = dc$background, fg = dc$foreground)
    }, res = 96)

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
          # Deduplicated by family — code font defaults to the body font
          # (see the font_pair sync above), so base/heading/mono commonly
          # repeat the same family, and Quarto would otherwise be told to
          # fetch the identical Google Font two or three times over.
          fonts = lapply(
            unique(c(input$font_base, input$font_heading, input$font_mono)),
            function(fam) list(family = fam, source = "google")
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
          ),
          monospace = list(
            family = input$font_mono,
            size = paste0(input$font_size, "rem"),
            weight = 400L
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

    # Shiny suspends computation for outputs inside a hidden tab panel by
    # default, so the whole Live Preview / YAML tab's outputs invalidate
    # and recompute together the moment you switch onto it — visible as a
    # burst of updates that then settles once each has caught up. Keeping
    # them live avoids that stagger; none of these are expensive enough
    # to justify suspending them while off-screen.
    shiny::outputOptions(output, "preview_banner", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "preview_light", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "preview_dark", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "preview_plot_light", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "preview_plot_dark", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "yml_preview", suspendWhenHidden = FALSE)

    # -- Save --
    shiny::observeEvent(input$save_brand, {
      cfg <- brand_yml()
      dest <- file.path(path, "_brand.yml")

      # This always writes the Shiny/bslib format (color-dark:, theme:),
      # which Quarto's own renderer rejects. If a Quarto project was
      # already scaffolded here, its _brand.yml is about to be clobbered
      # with a format Quarto can't read.
      was_quarto_format <- file.exists(dest) && is_quarto_compatible_brand_yml(dest)

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

      if (was_quarto_format) {
        message(
          "Note: _brand.yml at ", dest, " was in Quarto-compatible format ",
          "and has been replaced with the Shiny/bslib format. Re-run ",
          "create_brand_quarto_html()/create_brand_quarto_slides()/",
          "create_brand_quarto_pdf() (they'll auto-convert it back) before ",
          "rendering any Quarto document in this project again."
        )
      }

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

  # bslib auto-discovers _brand.yml by walking up from the working
  # directory, and does so from more than one internal call site (passing
  # brand = FALSE to our own bs_theme() call above only covers that one
  # call — Shiny's own tag-rendering pipeline independently constructs a
  # default bs_theme() elsewhere, with no way for us to intercept it).
  # The only fully reliable way to keep the configurator's UI from ever
  # hitting an incompatible _brand.yml is to make sure none is
  # discoverable at all: run the app with the working directory
  # temporarily pointed somewhere brand-free, and always restore it.
  old_wd <- getwd()
  setwd(tempdir())
  on.exit(setwd(old_wd), add = TRUE)

  # If a previous configure_brand() call was interrupted while still
  # starting up (e.g. Ctrl-C/Escape hit right after launch, before the
  # app finished initialising), Shiny's own internal "an app is running"
  # flag can be left stuck, and every later runApp() call fails with
  # "Can't call runApp() from within runApp()" even though nothing is
  # actually running. Proactively stopping any orphaned httpuv server
  # first clears that out via the public API, rather than restarting R.
  if (requireNamespace("httpuv", quietly = TRUE)) {
    tryCatch(httpuv::stopAllServers(), error = function(e) NULL)
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
  # hex is already the light mode's dark/foreground colour, so it's
  # already quite dark to begin with — darkening it further by 0.85
  # crushed almost any input toward pure black, losing the brand's hue.
  # A lighter touch keeps more of that colour's character.
  colorspace::darken(hex, amount = 0.45)
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


# --------------------------------------------------------------------------
# Internal: shared live-preview building blocks (used for both light and
# dark mode in the configurator's Live Preview tab)
# --------------------------------------------------------------------------

#' Row of semantic colour swatches
#' @keywords internal
brandkit_swatches <- function(cols) {
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
    style = "display: flex; gap: 6px; flex-wrap: wrap;",
    swatch("primary", cols$primary), swatch("secondary", cols$secondary),
    swatch("success", cols$success), swatch("danger", cols$danger),
    swatch("warning", cols$warning), swatch("info", cols$info)
  )
}

#' Section label + heading/body/code sample, to actually evaluate the
#' chosen font trio (not just name it) — heading rendered in the heading
#' font, body copy rendered in the base font at the configured size and
#' line height, and a code snippet rendered in the monospace font (the
#' same one that reaches code chunks in the Quarto Typst PDF via
#' `typography.monospace.family`).
#' @keywords internal
brandkit_typography_sample <- function(cols, base, heading, mono, brand_name,
                                       font_size = 1, line_height = 1.5) {
  htmltools::div(
    htmltools::h4(
      brand_name,
      style = paste0(
        "color:", cols$primary, "; margin: 0 0 4px 0;",
        " font-family:'", heading, "', sans-serif; font-weight: 700;"
      )
    ),
    htmltools::p(
      "Regular text sits alongside ",
      htmltools::strong("bold emphasis"), ", ",
      htmltools::em("italic emphasis"), ", and even ",
      htmltools::tags$small("a quieter aside"),
      " — enough to eyeball before shipping a report.",
      style = paste0(
        "color:", cols$foreground, "; margin: 0 0 6px 0;",
        " font-family:'", base, "', sans-serif;",
        " font-size:", font_size, "rem; line-height:", line_height, ";"
      )
    ),
    htmltools::tags$code(
      "brand_pal_discrete()",
      style = paste0(
        "display: inline-block; color:", cols$foreground, "; background:",
        cols$light, "; padding: 2px 6px; border-radius: 4px;",
        " font-family:'", mono, "', monospace;",
        " font-size:", font_size, "rem;"
      )
    )
  )
}

#' Small, unobtrusive mode label — replaces a bslib::card_header() now
#' that the coloured surface itself is the card, not something nested
#' inside a separate neutral one
#' @keywords internal
brandkit_mode_label <- function(cols, label) {
  htmltools::div(
    label,
    style = paste0(
      "font-size: 12px; font-weight: 700; text-transform: uppercase; ",
      "letter-spacing: 0.04em; color:", cols$foreground, "; opacity: 0.55; ",
      "margin-bottom: 10px;"
    )
  )
}

#' "Bad case scenario" stress-test chart: several erratic, overlapping
#' random-walk lines in the given palette colours. Flat swatches never
#' reveal when two colours are too close to tell apart, or too weak
#' against the background — busy, realistic chart data does. The walks
#' are seeded so only the colours change when the palette is tweaked, a
#' stable "same bad case, different palette" comparison.
#' @keywords internal
brandkit_stress_plot <- function(pal, bg, fg) {
  n <- 60
  walks <- lapply(seq_along(pal), function(i) {
    set.seed(100 + i)
    cumsum(stats::rnorm(n, sd = 1))
  })
  y_range <- range(unlist(walks))

  par(bg = bg, mar = c(2.5, 2.5, 0.5, 0.5))
  plot(NULL, xlim = c(1, n), ylim = y_range, axes = FALSE, xlab = "", ylab = "")
  axis(1, col = fg, col.axis = fg, cex.axis = 0.7)
  axis(2, col = fg, col.axis = fg, cex.axis = 0.7)
  for (i in seq_along(pal)) {
    lines(seq_len(n), walks[[i]], col = pal[i], lwd = 2)
  }
}
