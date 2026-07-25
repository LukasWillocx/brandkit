# --------------------------------------------------------------------------
# brandkit: brand_configure.R
# Interactive Shiny wizard to generate a _brand.yml — from scratch, or
# seeded from the one already in the target directory.
# --------------------------------------------------------------------------

#' Launch the Brand Configurator
#'
#' Opens an interactive Shiny app that walks you through palette selection,
#' font choice, logo upload, and live preview. On save, writes a complete
#' `_brand.yml` (and optional font/logo assets) to a target directory.
#'
#' @section Starting from the brand already in `path`:
#' If `path` already contains a `_brand.yml`, every input starts on that
#' brand's current values — colours, font pairing, sizes, border radius,
#' brand name, logo — rather than on the built-in defaults, so opening the
#' configurator on a configured project is a way to make small adjustments
#' instead of redoing the whole wizard. Both `_brand.yml` formats are read
#' back. Pass `reset = TRUE` to ignore the existing file and start from the
#' built-in defaults.
#'
#' The dark palette is always re-derived from the light colours (that is
#' what the "Auto-generate dark mode palette" box does), so hand-edited
#' dark colours in an existing file are not preserved — but the box starts
#' ticked whenever the file has dark colours at all.
#'
#' @section Output format:
#' The "Output format" toggle in the sidebar decides which of the two
#' `_brand.yml` dialects gets written:
#' \describe{
#'   \item{Shiny / bslib}{`color-dark:` and `theme:` sections. What bslib
#'     reads; Quarto's renderer rejects those keys outright.}
#'   \item{Quarto}{Dark colours folded into nested `light:`/`dark:` values
#'     and the Bootstrap variables moved under
#'     `defaults: bootstrap: defaults:`. Readable by Quarto and bslib
#'     alike.}
#' }
#' It defaults to whichever format the existing `_brand.yml` in `path` is
#' already in, so re-configuring a Quarto project no longer clobbers it
#' with a file Quarto can't read. The `create_brand_quarto_*()` functions
#' still convert a bslib-format file on their own, so writing Shiny/bslib
#' here and converting later also remains a valid route.
#'
#' @param path Directory to write the generated `_brand.yml` and assets.
#'   Default is the current working directory.
#' @param format Initial setting for the output-format toggle: `"auto"`
#'   (default) to match the `_brand.yml` already in `path`, or `"bslib"` /
#'   `"quarto"` to force one. Changeable in the app either way.
#' @param reset Logical. Start from the built-in defaults even when `path`
#'   already has a `_brand.yml`. Default `FALSE`.
#'
#' @return Called for side effect (launches Shiny app). Invisibly returns
#'   the path to the saved `_brand.yml`.
#' @export
configure_brand <- function(path = ".",
                            format = c("auto", "bslib", "quarto"),
                            reset = FALSE) {

  format <- match.arg(format)

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

  # -- Seed every input from the brand already in `path`, if any --
  existing <- existing_brand_yml(path)
  existing_cfg <- if (is.null(existing) || reset) {
    NULL
  } else {
    tryCatch(yaml::read_yaml(existing), error = function(e) NULL)
  }
  d <- configurator_defaults(existing_cfg, presets, font_pairs)

  # Save back over the file that was found, so a project spelled
  # `_brand.yaml` doesn't end up with a second, conflicting `_brand.yml`
  # sitting next to it.
  dest <- existing %||% file.path(path, "_brand.yml")

  # The format toggle tracks the file on disk even when `reset = TRUE` —
  # resetting the aesthetic is not a reason to start writing a dialect
  # the project's renderer can't read.
  compliance_default <- if (format != "auto") {
    format
  } else if (!is.null(existing) && is_quarto_compatible_brand_yml(existing)) {
    "quarto"
  } else {
    "bslib"
  }

  # An existing logo can't be pre-loaded into a fileInput, so it's held
  # aside: used for the preview and carried through on save unless the
  # user actually uploads a replacement.
  existing_logo <- resolve_existing_logo(path, d$logo)

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
                             names(presets), selected = d$preset),
          htmltools::hr(),
          colourpicker::colourInput("col_primary", "Primary", d$cols$primary),
          colourpicker::colourInput("col_secondary", "Secondary", d$cols$secondary),
          colourpicker::colourInput("col_success", "Success", d$cols$success),
          colourpicker::colourInput("col_danger", "Danger", d$cols$danger),
          colourpicker::colourInput("col_warning", "Warning", d$cols$warning),
          colourpicker::colourInput("col_info", "Info", d$cols$info),
          htmltools::hr(),
          colourpicker::colourInput("col_light", "Background (light)", d$cols$light),
          colourpicker::colourInput("col_dark", "Foreground (dark)", d$cols$dark),
          htmltools::hr(),
          shiny::checkboxInput("auto_dark", "Auto-generate dark mode palette",
                               d$auto_dark)
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
            choices = names(font_pairs), selected = d$font_pair
          ),
          htmltools::hr(),
          shiny::textInput("font_base", "Body font:", d$font_base),
          shiny::textInput("font_heading", "Heading font:", d$font_heading),
          shiny::textInput("font_mono", "Code font:", d$font_mono),
          htmltools::hr(),
          shiny::numericInput("font_size", "Base size (rem):", d$font_size,
                              min = 0.7, max = 1.5, step = 0.05),
          shiny::numericInput("line_height", "Line height:", d$line_height,
                              min = 1.2, max = 2, step = 0.05)
        ),

        bslib::accordion_panel(
          "Meta & Logo",
          shiny::textInput("brand_name", "Brand name:", d$brand_name),
          shiny::fileInput("logo_file", "Logo (optional):",
                           accept = c("image/png", "image/svg+xml", "image/jpeg")),
          if (!is.null(existing_logo)) {
            htmltools::div(
              style = "font-size: 0.8rem; color: #666; margin-top: -0.5rem;",
              "Currently using ", htmltools::code(basename(existing_logo)),
              " — upload a file only to replace it."
            )
          },
          htmltools::hr(),
          shiny::numericInput("border_radius", "Border radius (rem):",
                              d$border_radius, min = 0, max = 2, step = 0.25)
        )
      ),

      htmltools::hr(),
      shiny::radioButtons(
        "compliance",
        label = htmltools::tagList(
          "Output format:",
          bslib::popover(
            htmltools::tags$span(
              "ⓘ",
              style = paste0(
                "cursor: pointer; font-weight: bold; margin-left: 6px; ",
                "color: var(--bs-primary);"
              )
            ),
            title = "Which _brand.yml dialect to write",
            htmltools::tags$p(
              htmltools::strong("Shiny / bslib"), " — writes ",
              htmltools::code("color-dark:"), " and ", htmltools::code("theme:"),
              " sections. What bslib reads; Quarto's renderer rejects them."
            ),
            htmltools::tags$p(
              htmltools::strong("Quarto"), " — folds the dark palette into ",
              "nested ", htmltools::code("light:"), "/", htmltools::code("dark:"),
              " colour values and moves the Bootstrap variables under ",
              htmltools::code("defaults:"), ". Read by Quarto and bslib alike."
            ),
            htmltools::tags$p(
              htmltools::em(
                "Either way you can switch later: the ",
                "create_brand_quarto_*() functions convert a bslib-format ",
                "file on their own."
              )
            )
          )
        ),
        choices = c("Shiny / bslib" = "bslib", "Quarto" = "quarto"),
        selected = compliance_default,
        inline = TRUE
      ),
      htmltools::div(
        style = "font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;",
        paste("Save to:", dest),
        if (!is.null(existing_cfg)) {
          htmltools::div(
            htmltools::tags$em("Started from the _brand.yml already here.")
          )
        }
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
    # ignoreInit: the inputs already start on the loaded brand's colours,
    # and the preset select starts on whichever preset matches them (or
    # "Custom"). Letting this fire on startup would be a no-op at best and,
    # for a brand that matches a preset on all eight colours but was then
    # hand-tuned elsewhere, an unrequested reset.
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
    }, ignoreInit = TRUE)

    # -- Font pair sync --
    # Code font defaults to the body font on every pairing switch (kept a
    # freely-editable text input afterward, same as font_base/font_heading,
    # so it's still a default, not a lock). ignoreInit matters here for the
    # same reason as above, and more concretely: a loaded brand whose code
    # font differs from its body font would otherwise have that overwritten
    # on startup the moment its body/heading pair matched a known pairing.
    shiny::observeEvent(input$font_pair, {
      fp <- font_pairs[[input$font_pair]]
      if (!is.null(fp)) {
        shiny::updateTextInput(session, "font_base", value = fp$base)
        shiny::updateTextInput(session, "font_heading", value = fp$heading)
        shiny::updateTextInput(session, "font_mono", value = fp$base)
      }
    }, ignoreInit = TRUE)

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

    # -- Logo: an upload wins, otherwise whatever the existing _brand.yml
    #    already pointed at (so re-configuring a branded project doesn't
    #    silently drop its logo). --
    logo_src <- shiny::reactive({
      if (!is.null(input$logo_file)) input$logo_file$datapath else existing_logo
    })

    logo_cfg <- shiny::reactive({
      if (!is.null(input$logo_file)) {
        p <- file.path("logo", input$logo_file$name)
        return(list(small = p, medium = p, large = p))
      }
      if (!is.null(existing_logo)) d$logo else NULL
    })

    # -- Logo tag (shared by banner preview) --
    logo_tag <- shiny::reactive({
      src <- logo_src()
      if (is.null(src)) return(NULL)
      # Serve logo via Shiny resource path
      shiny::addResourcePath("brandkit-preview-logo", dirname(src))
      htmltools::img(
        src = paste0("brandkit-preview-logo/", basename(src)),
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
          #
          # A family the loaded _brand.yml already defined keeps that
          # definition verbatim: a locally-sourced font (source: file,
          # with files:) would otherwise be rewritten on save as a Google
          # font of the same name, which is a different font or no font
          # at all.
          fonts = lapply(
            unique(c(input$font_base, input$font_heading, input$font_mono)),
            function(fam) {
              if (fam %in% names(d$font_defs)) {
                d$font_defs[[fam]]
              } else {
                list(family = fam, source = "google")
              }
            }
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

      # A named palette isn't editable here, but carry a loaded one through
      # rather than dropping it on save.
      if (!is.null(d$palette)) cfg$color$palette <- d$palette

      cfg$logo <- logo_cfg()

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

    # -- What actually gets written, in the chosen dialect. The YAML tab
    #    renders this rather than brand_yml() so the preview is the file,
    #    not an intermediate the Quarto setting would then rewrite. --
    output_yml <- shiny::reactive({
      cfg <- brand_yml()
      if (input$compliance != "quarto") return(cfg)
      # keep_logo: the referenced logo either exists already or is about
      # to be copied next to the _brand.yml by the save handler, so the
      # converter's own on-disk check would be answering the wrong
      # question (and would emit an advisory message on every keystroke).
      quarto_brand_cfg(cfg, brand_dir = path,
                       keep_logo = !is.null(logo_src()))
    })

    output$yml_preview <- shiny::renderPrint({
      cat(yaml::as.yaml(output_yml()))
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
      was_quarto_format <- file.exists(dest) &&
        is_quarto_compatible_brand_yml(dest)

      # Copy the logo before writing, so the file is in place by the time
      # anything downstream goes looking for what _brand.yml references.
      if (!is.null(input$logo_file)) {
        logo_dir <- file.path(path, "logo")
        if (!dir.exists(logo_dir)) dir.create(logo_dir)
        logo_dest <- file.path(logo_dir, input$logo_file$name)
        file.copy(input$logo_file$datapath, logo_dest, overwrite = TRUE)
      }

      yaml::write_yaml(output_yml(), dest)

      # Reload the cache so subsequent brandkit calls use the new brand
      tryCatch(
        brand_init(dest, quiet = FALSE),
        error = function(e) NULL
      )

      if (input$compliance == "quarto") {
        message(
          "Wrote _brand.yml in Quarto-compatible format — render a .qmd ",
          "in this project directly. The create_brand_quarto_*() functions ",
          "will leave it alone (they only convert bslib-format files)."
        )
      } else if (was_quarto_format) {
        message(
          "Note: _brand.yml at ", dest, " was in Quarto-compatible format ",
          "and has been replaced with the Shiny/bslib format. Re-run ",
          "create_brand_quarto_html()/create_brand_quarto_slides()/",
          "create_brand_quarto_pdf() (they'll auto-convert it back), or ",
          "pick \"Quarto\" under Output format, before rendering any Quarto ",
          "document in this project again."
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
# Internal: seed the configurator from the brand already on disk
#
# Opening the configurator in a configured project should land on that
# project's own aesthetic, not back on the built-in starting point — the
# common case is nudging one colour or bumping a font size, not redoing
# the whole wizard. Everything the UI exposes is read back here, from
# either _brand.yml format.
# --------------------------------------------------------------------------

#' Path to an existing `_brand.yml` in `path`, or `NULL`
#' @keywords internal
existing_brand_yml <- function(path) {
  hits <- file.path(path, c("_brand.yml", "_brand.yaml"))
  hits <- hits[file.exists(hits)]
  if (length(hits)) hits[1] else NULL
}

#' Parse a CSS length back to the plain rem number the configurator's
#' numeric inputs hold. Absolute units are converted against a 16px /
#' 12pt root, matching css_length_to_typst_pt() in the other direction.
#' @keywords internal
css_length_to_rem <- function(x, fallback) {
  if (is.null(x)) return(fallback)
  if (is.numeric(x)) return(x)
  m <- regmatches(x, regexec("^\\s*([0-9.]+)\\s*(rem|em|px|pt)?\\s*$", x))[[1]]
  if (length(m) != 3) return(fallback)
  num <- suppressWarnings(as.numeric(m[2]))
  if (is.na(num)) return(fallback)
  switch(m[3], px = num / 16, pt = num / 12, num)
}

#' Name of the preset matching these colours exactly, else `"Custom"`
#' @keywords internal
match_brand_preset <- function(cols, presets) {
  keys <- c("primary", "secondary", "success", "danger",
            "warning", "info", "light", "dark")
  norm <- function(x) tolower(as.character(x %||% ""))
  target <- vapply(cols[keys], norm, character(1))
  for (nm in names(presets)) {
    p <- presets[[nm]]
    if (is.null(p)) next
    if (identical(vapply(p[keys], norm, character(1)), target)) return(nm)
  }
  "Custom"
}

#' Name of the font pairing matching this base/heading combo, else `"Custom"`
#' @keywords internal
match_font_pair <- function(base, heading, font_pairs) {
  for (nm in names(font_pairs)) {
    fp <- font_pairs[[nm]]
    if (is.null(fp)) next
    if (identical(fp$base, base) && identical(fp$heading, heading)) return(nm)
  }
  "Custom"
}

#' First usable relative path out of a `logo:` section, or `NULL`
#' @keywords internal
brand_logo_first_path <- function(logo) {
  if (length(logo) == 0) return(NULL)
  if (is.character(logo)) return(logo[1])
  for (sz in c("medium", "small", "large")) {
    p <- logo[[sz]]
    if (is.list(p)) p <- p$light %||% p$dark
    if (is.character(p) && nzchar(p)) return(p)
  }
  NULL
}

#' Absolute path to the logo an existing `_brand.yml` points at, but only
#' if that file is actually there — a stale reference shouldn't produce a
#' broken image in the preview or get carried forward on save.
#' @keywords internal
resolve_existing_logo <- function(path, logo) {
  p <- brand_logo_first_path(logo)
  if (is.null(p)) return(NULL)
  full <- file.path(path, p)
  if (file.exists(full)) normalizePath(full) else NULL
}

#' Starting values for every configurator input
#'
#' With `cfg = NULL` these are the built-in defaults; otherwise each is
#' read back out of an already-parsed `_brand.yml`. Also carries through
#' the parts the UI has no control over (`font_defs`, `palette`, `logo`)
#' so a round-trip through the configurator doesn't quietly drop them.
#' @keywords internal
configurator_defaults <- function(cfg, presets, font_pairs) {
  d <- list(
    brand_name    = "My Brand",
    cols          = presets[["Wine & Sage"]],
    preset        = "Wine & Sage",
    auto_dark     = TRUE,
    font_pair     = "Manrope / Montserrat",
    font_base     = "Manrope",
    font_heading  = "Montserrat",
    font_mono     = "Manrope",
    font_size     = 1,
    line_height   = 1.65,
    border_radius = 0.75,
    font_defs     = list(),
    palette       = NULL,
    logo          = NULL
  )
  if (!is.list(cfg) || !length(cfg)) return(d)

  # -- Colours -- both the bslib shape ("#hex") and Quarto's nested
  # {light:, dark:} shape resolve through the same helper. light/dark
  # and background/foreground are aliases of each other in this UI, so
  # either spelling seeds the two background/foreground pickers.
  col <- function(k, fallback) resolve_brand_col(cfg$color[[k]]) %||% fallback
  d$cols <- list(
    primary   = col("primary",   d$cols$primary),
    secondary = col("secondary", d$cols$secondary),
    success   = col("success",   d$cols$success),
    danger    = col("danger",    d$cols$danger),
    warning   = col("warning",   d$cols$warning),
    info      = col("info",      d$cols$info),
    light     = col("light",     resolve_brand_col(cfg$color$background) %||% d$cols$light),
    dark      = col("dark",      resolve_brand_col(cfg$color$foreground) %||% d$cols$dark)
  )
  d$preset    <- match_brand_preset(d$cols, presets)
  d$auto_dark <- brand_cfg_has_dark(cfg)
  d$palette   <- cfg$color$palette
  d$logo      <- cfg$logo

  if (!is.null(cfg$meta$name)) d$brand_name <- cfg$meta$name

  # -- Typography --
  ty <- cfg$typography
  d$font_base    <- ty$base$family      %||% d$font_base
  d$font_heading <- ty$headings$family  %||% d$font_heading
  d$font_mono    <- ty$monospace$family %||% d$font_base
  d$font_pair    <- match_font_pair(d$font_base, d$font_heading, font_pairs)
  d$font_size    <- css_length_to_rem(ty$base$size, d$font_size)

  lh <- suppressWarnings(as.numeric(ty$base[["line-height"]] %||% NA))
  if (!is.na(lh)) d$line_height <- lh

  # Full font definitions keyed by family, so a locally-sourced font
  # (source: file, with files:) survives a round-trip instead of being
  # rewritten as a Google font it isn't.
  defs <- ty$fonts %||% list()
  if (length(defs)) {
    fams <- vapply(defs, function(f) f$family %||% "", character(1))
    d$font_defs <- stats::setNames(defs, fams)
  }

  # -- Border radius -- theme: in bslib's format, defaults: bootstrap:
  # defaults: in Quarto's.
  d$border_radius <- css_length_to_rem(
    cfg$theme[["border-radius"]] %||%
      cfg$defaults$bootstrap$defaults[["border-radius"]],
    d$border_radius
  )

  d
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
