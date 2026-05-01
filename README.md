# brandkit

**Opinionated brand theming for R — configure once, apply everywhere.**

brandkit turns a single `_brand.yml` file into consistent, polished theming across Shiny apps, ggplot2 plots, plotly widgets, Quarto documents, and revealjs presentations. It builds on top of the official [brand.yml](https://posit-dev.github.io/brand-yml/) ecosystem while adding an interactive configurator, smart palette generation, auto-applied defaults, and CSS overrides for third-party widgets that Bootstrap 5 doesn't reach.

## Installation

```r
devtools::install_github("yourusername/brandkit")
```

Required dependencies: `bslib (>= 0.9.0)`, `colorspace`, `ggplot2`, `htmltools`, `rlang`, `yaml`.

Recommended: `shiny`, `plotly`, `thematic`, `showtext`, `sysfonts`, `colourpicker`, `gt`, `DT`, `leaflet`.

---

## Quick Start

### 1. Configure your brand

```r
library(brandkit)
configure_brand()
```

This launches an interactive Shiny wizard with 12 colour presets, 15 font pairings, logo upload, and live preview. On save, it writes `_brand.yml` to your project and gracefully closes.

### 2. Use in Shiny (zero boilerplate)

```r
library(shiny)
library(bslib)
library(ggplot2)
library(brandkit)

ui <- brand_page_sidebar(
  title = "My Dashboard",
  sidebar = sidebar(
    selectInput("var", "Variable", names(mtcars))
  ),
  card(
    card_header("Plot"),
    plotOutput("plot")
  )
)

server <- function(input, output, session) {
  output$plot <- renderPlot({
    ggplot(mtcars, aes(.data[[input$var]], mpg, color = factor(cyl))) +
      geom_point(size = 3)
  })
}

shinyApp(ui, server)
```

No `theme =`, no `+ theme_brand()`, no `scale_color_brand_d()`, no dark mode plumbing. Everything is injected automatically.

### 3. Use in Quarto

```r
use_brand_quarto(path = "my-report")
```

Then in your `.qmd` file, add `library(brandkit)` and `brand_quarto_setup()` in a setup chunk.

---

## The `_brand.yml` Format

brandkit reads and extends the official `brand.yml` specification. A complete file looks like this:

```yaml
meta:
  name: My Brand
color:
  primary: "#2c3e50"
  secondary: "#1abc9c"
  success: "#27ae60"
  danger: "#e74c3c"
  warning: "#f39c12"
  info: "#2980b9"
  light: "#ecf0f1"        # used as background in light mode
  dark: "#1a252f"          # used as foreground in light mode
  foreground: "#1a252f"
  background: "#ecf0f1"
color-dark:                 # bslib-specific section for dark mode
  primary: "#5a8a9f"
  secondary: "#4edfc0"
  success: "#52c98a"
  danger: "#f08a82"
  warning: "#f7c056"
  info: "#59ade0"
  light: "#121a20"
  dark: "#e8eff5"
  foreground: "#e8eff5"
  background: "#121a20"
typography:
  fonts:
    - family: Inter
      source: google        # "google" or "file" (for local .ttf)
    - family: Montserrat
      source: google
  base:
    family: Inter
    size: 1rem
    line-height: 1.65
    weight: 400
  headings:
    family: Montserrat
    weight: 700
    line-height: 1.1
logo:
  small: "logo/brand.png"
  medium: "logo/brand.png"
  large: "logo/brand.png"
theme:                       # bslib-specific Bootstrap Sass overrides
  border-radius: "0.75rem"
  border-radius-sm: "0.5rem"
  border-radius-lg: "1rem"
```

**Important format notes:**

- The `color-dark:` and `theme:` sections are bslib-specific and not recognized by Quarto. When scaffolding for Quarto via `use_brand_quarto()`, brandkit automatically converts to the Quarto-compatible format (nested `light:`/`dark:` under each colour key).
- The `logo:` section uses `small`, `medium`, and `large` keys (not `light`/`dark`).
- `source: google` loads fonts from Google Fonts at runtime. `source: file` requires `.ttf` files at the paths specified in `files:`.

---

## Shiny: Page Wrappers

brandkit provides three drop-in replacements for bslib page functions. Each one auto-injects: the brand theme, dark mode CSS overrides for third-party widgets, a dark mode toggle (fixed top-right), the brand logo next to the title, and thematic integration for automatic plot theming.

### `brand_page_sidebar()`

```r
brand_page_sidebar(
  ...,                          # UI content (cards, layouts, etc.)
  title = NULL,                 # app title (character or UI)
  sidebar = NULL,               # bslib::sidebar() object
  logo = TRUE,                  # prepend logo to title
  dark_mode = TRUE,             # include dark mode toggle
  dark_mode_id = "dark_mode",   # input ID for the toggle
  fillable = TRUE,
  theme_args = list()           # extra args passed to brand_theme()
)
```

### `brand_page_navbar()`

```r
brand_page_navbar(
  ...,                          # nav_panel() items ONLY
  title = NULL,
  logo = TRUE,
  dark_mode = TRUE,
  dark_mode_id = "dark_mode",
  theme_args = list()
)
```

**Critical:** `brand_page_navbar()` only accepts `nav_panel()` and `nav_menu()` items in `...`. Non-nav content (cards, divs) will cause the error: *"Navigation containers expect a collection of nav_panel()s"*. Place non-nav content inside a `nav_panel()`.

### `brand_page_fluid()`

```r
brand_page_fluid(
  ...,                          # any UI content
  title = NULL,
  logo = TRUE,
  dark_mode = TRUE,
  dark_mode_id = "dark_mode",
  theme_args = list()
)
```

### What the page wrappers inject automatically

When you use `brand_page_sidebar()` instead of `bslib::page_sidebar()`, the following happens behind the scenes:

1. `brand_theme()` is called to build the bslib Bootstrap 5 theme from `_brand.yml`
2. `brand_dark_css()` injects `<style>` overrides for datepicker, Shiny checkbox/radio containers
3. A dark mode toggle is positioned `fixed` at top-right (`z-index: 1050`)
4. The brand logo (if configured) is prepended inline next to the title
5. `thematic::thematic_shiny()` is activated with the brand discrete palette and font
6. A plot-settle script hides ggplot outputs during initial layout to prevent size-flash

---

## Shiny: Dark Mode Handling

### Automatic (zero-boilerplate)

When using `brand_page_*()` wrappers, ggplot2 plots automatically adapt to dark/light mode via thematic. The theme, discrete scales, and plot background are handled without any server-side code.

```r
# This plot adapts to dark mode automatically:
output$plot <- renderPlot({
  ggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species)) +
    geom_point(size = 3)
})
```

### Manual (when you need mode-aware logic)

For plotly, gt tables, leaflet, or any output that needs to know the current mode, use `brand_dark_mode()`:

```r
server <- function(input, output, session) {
  dm <- brand_dark_mode(input)

  output$my_plotly <- renderPlotly({
    mode <- dm$mode()  # returns "light" or "dark"
    cols <- brand_colors(mode)

    p <- ggplot(data, aes(x, y, color = group)) +
      geom_point() +
      scale_color_brand_d(mode = mode)

    brand_plotly(p, mode = mode)
  })

  output$my_gt <- render_gt({
    mode <- dm$mode()
    cols <- brand_colors(mode)

    gt(data) |>
      tab_style(
        style = list(
          cell_fill(color = cols$primary),
          cell_text(color = "white", weight = "bold")
        ),
        locations = cells_column_labels()
      ) |>
      tab_options(
        table.background.color = cols$background,
        table.width = pct(100)
      )
  })
}
```

**When to use manual mode tracking:**

- `brand_plotly()` — always pass `mode` explicitly when inside a Shiny app with dark mode toggling
- `gt()` tables — gt does not respond to Bootstrap CSS variables; style manually with `brand_colors(mode)`
- `leaflet()` — pass `mode` to `brand_pal_seq()` for map colour palettes
- `base::barplot()` / `base::plot()` — use `brand_colors(mode)` for `col.main`, `col.axis`, etc.
- Download handlers — use `brand_colors(mode)$background` for `ggsave(bg = ...)`

**When you do NOT need manual mode tracking:**

- `renderPlot()` with ggplot2 — thematic handles it
- HTML/CSS elements in the UI — Bootstrap CSS variables handle it
- DT datatables with `class = "table-striped"` — Bootstrap handles it

---

## ggplot2 Theming

### Auto-applied on load

After `library(brandkit)`, two things happen automatically:

1. `ggplot2::theme_set(theme_brand())` — every plot uses the brand theme
2. `options(ggplot2.discrete.colour = brand_pal_discrete())` — discrete colour mappings use brand colours

This means a plain `ggplot(data, aes(x, y, color = group)) + geom_point()` is fully branded without any extra calls.

### Explicit theme function

```r
theme_brand(base_size = 14, mode = "light")
```

Returns a `ggplot2::theme` object with:
- Brand background colour (not transparent — works in Quarto/scripts)
- Brand fonts for title (heading font, bold), body text (base font)
- Dashed grid lines in brand primary at 25% opacity
- Minor grid removed
- Transparent legend background

### Scale functions

```r
# Discrete
scale_color_brand_d(..., mode = "light")
scale_fill_brand_d(..., mode = "light")

# Continuous (sequential)
scale_color_brand_c(type = "warm", ..., mode = "light")  # type: "warm", "cool", "green"
scale_fill_brand_c(type = "warm", ..., mode = "light")

# Continuous (diverging)
scale_color_brand_div(..., mode = "light")
scale_fill_brand_div(..., mode = "light")
```

### Palette generators (raw hex vectors)

```r
brand_pal_discrete(n = NULL, mode = "light")  # up to 15 colours
brand_pal_seq(type = "warm", n = 9, reverse = FALSE, mode = "light")
brand_pal_div(n = 11, reverse = FALSE, mode = "light")
```

The discrete palette uses the 6 semantic brand colours first, then fills to 15 via HCL hue rotation from the primary. No hardcoded hex values — everything derives from `_brand.yml`.

---

## Plotly Integration

### `brand_plotly()`

Converts a ggplot2 object to an interactive plotly widget with branded colours, fonts, and grid styling.

```r
brand_plotly(
  p,                    # ggplot2 object
  mode = NULL,          # "light", "dark", or NULL (auto-detect)
  base_size = 14,       # font size in points
  tooltip = "y",        # aesthetics to show on hover
  width = NULL,         # widget width in px (NULL = automatic)
  height = NULL         # widget height in px (NULL = automatic)
)
```

**Usage in Shiny:**

```r
output$plot <- renderPlotly({
  mode <- dm$mode()
  p <- ggplot(data, aes(x, y, color = group)) + geom_point()
  brand_plotly(p, mode = mode, tooltip = c("x", "y"))
})
```

**Usage in Quarto (revealjs slides):**

For slides, pass fixed dimensions to prevent overflow:

```r
brand_plotly(p, width = 1000, height = 600)
```

For HTML documents, leave width/height as NULL (automatic sizing).

**What brand_plotly handles:**

- All text elements (title, axes, ticks, legend) use brand foreground colour and font
- Continuous colour scale legend (colorbar) text adapts to dark mode
- Legend background is transparent
- Grid lines use brand primary at 25% opacity
- Plot background is transparent (inherits from container)

**What brand_plotly does NOT handle:**

- Tooltip positioning near container edges (plotly limitation)
- Automatic dark mode toggling — pass `mode` explicitly in Shiny

---

## Table Theming

### gt tables

gt does not inherit Bootstrap CSS variables. Style manually using `brand_colors()`:

```r
cols <- brand_colors(mode)

gt(data) |>
  tab_style(
    style = list(
      cell_fill(color = cols$primary),
      cell_text(color = "white", weight = "bold")
    ),
    locations = cells_column_labels()
  ) |>
  tab_style(
    style = cell_fill(color = cols$light),
    locations = cells_body(rows = seq(1, nrow(data), 2))
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
    table.background.color = cols$background,
    table.border.top.color = cols$primary,
    heading.border.bottom.color = cols$primary,
    table.width = pct(100),
    table.font.size = px(14)
  )
```

### DT datatables

DT inherits Bootstrap styling. Use `class = "table-striped"` for branded stripe colours:

```r
DT::datatable(
  data,
  options = list(pageLength = 10, dom = "tip"),
  class = "table-striped",
  rownames = FALSE
)
```

DT pagination buttons, search inputs, and striped rows all adapt to dark mode automatically via the CSS overrides in `brand_theme()`.

---

## Leaflet Integration

Leaflet maps are not themed by Bootstrap, but brandkit provides:

1. **Brand palettes for markers:** Use `brand_pal_seq()` with `leaflet::colorNumeric()` or `colorBin()`
2. **Dark mode CSS overrides:** Zoom buttons, attribution, and legend backgrounds adapt automatically
3. **Dark tile provider:** Use `CartoDB.DarkMatter` for a dark-mode-appropriate base map

```r
dm <- brand_dark_mode(input)

output$map <- renderLeaflet({
  mode <- dm$mode()

  pal <- colorNumeric(
    palette = brand_pal_seq(type = "warm", n = 9, mode = mode),
    domain = data$value
  )

  leaflet(data) |>
    addProviderTiles(if (mode == "dark") "CartoDB.DarkMatter" else "OpenStreetMap") |>
    addCircleMarkers(~lng, ~lat, color = ~pal(value), fillOpacity = 0.7) |>
    addLegend("bottomright", pal = pal, values = ~value)
})
```

---

## Quarto Integration

### Setup

```r
use_brand_quarto(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), brandkit.scss, example .qmd files, fonts, logo
```

### HTML documents

```yaml
---
title: "My Report"
format:
  html:
    theme:
      light: [brand, brandkit.scss]
      dark: [brand, brandkit.scss]
    toc: true
---
```

```r
#| label: setup
#| include: false
library(brandkit)
brand_quarto_setup()           # light mode
# brand_quarto_setup("dark")   # for dark-only documents
```

The light/dark theme structure enables a reader-facing toggle. Note that plots are static images baked at render time — they match whichever mode you pass to `brand_quarto_setup()`.

### Revealjs slides

```yaml
---
title: "My Slides"
format:
  revealjs:
    theme: [brand, brandkit.scss]
    logo: medium
    slide-number: true
---
```

For dark mode slides, add `brand-mode: dark` and use `brand_quarto_setup("dark")`.

For plotly in slides, always pass fixed dimensions: `brand_plotly(p, width = 1000, height = 600)`.

### Logo in documents

```markdown
::: {.brand-logo-container}
{{< brand logo medium >}}
:::
```

The `.brand-logo-container` class constrains the logo to `max-height: 48px`. Requires Quarto >= 1.8.

### What `brand_quarto_setup()` does

1. Sets `ggplot2::theme_set(theme_brand(mode = mode))`
2. Registers brand discrete palette as ggplot2 default
3. Sets `knitr::opts_chunk$set(dev.args = list(bg = background_colour))` — eliminates white device canvas
4. Registers a knitr hook to set `par()` colours for base R graphics
5. Stores the active mode so `brand_plotly()` auto-detects it

---

## Cache & Accessors

brandkit parses `_brand.yml` once at package load and caches the result. All downstream functions read from the cache.

```r
brand_init(path = NULL, quiet = FALSE)    # (re)load a _brand.yml
brand_colors(mode = "light")              # named list: primary, secondary, ..., foreground, background
brand_fonts()                             # list: base, heading, all, raw
brand_logo(size = "medium")               # resolved file path or NULL
brand_logo_tag(height = "1.8em")          # inline <img> tag for Shiny titles
brand_raw()                               # full parsed YAML list (escape hatch)
```

The cache auto-initialises from `_brand.yml` found by walking up from the working directory or from `inst/_brand.yml` inside the package. Call `brand_init("path/to/file.yml")` to point at a specific file.

`brand_colors()` handles both bslib format (`primary: "#hex"`) and Quarto nested format (`primary: {light: "#hex", dark: "#hex"}`).

---

## CSS Overrides

brandkit ships two CSS layers:

### `inst/css/overrides.css` (Shiny)

Static overrides loaded via `brand_theme()` for components Bootstrap 5 compiles at build time and never updates on dark mode toggle:

- ionRangeSlider handle, bar, and label colours
- Shiny checkbox/radio containers (compiled outside bslib)
- Selectize focus rings, active option highlights
- Bootstrap-datepicker active/today states
- Form input backgrounds and focus states
- Card hover effects and shadows
- Nav pill and tab active states
- Scrollbar styling
- Leaflet zoom buttons, attribution, and legend in dark mode
- Plot output initial-load settle (prevents size-flash)

### `inst/quarto/brandkit.scss` (Quarto)

SCSS rules layered after brand in Quarto's theme pipeline. Covers the same card, table, scrollbar, and nav polish, plus logo sizing.

### `brand_dark_css()` (runtime injection)

Returns a `tags$head(tags$style(...))` block for datepicker and Shiny widget containers that load their own stylesheets independently of bslib. Already included by `brand_page_*()` wrappers.

### Dynamic dark mode CSS generation

`brand_theme()` generates CSS at build time from the `color-dark` section:

1. **Custom properties:** `[data-bs-theme="dark"] { --bs-primary: ...; --bs-primary-rgb: ...; }`
2. **Button overrides:** `.btn-primary { --bs-btn-bg: ...; }` for each semantic colour
3. **Widget overrides:** ionRangeSlider, checkboxes, radios, switches, selectize, DataTables pagination

This is the layer that the official bslib / brand.yml pipeline does not provide.

---

## Configurator Details

```r
configure_brand(path = ".")
```

**Colour presets (12):**

| Category | Presets |
|---|---|
| Professional | Corporate Navy, Charcoal & Steel, Slate & Teal |
| Refined | Wine & Sage, Plum & Gold, Ocean & Coral, Forest & Amber |
| Warm | Terracotta & Cream, Espresso & Caramel |
| Light-hearted | Mint & Peach, Lavender & Rose, Sunset Gradient |

**Font pairings (15):**

| Category | Pairings |
|---|---|
| Clean | Inter, Manrope / Montserrat, Source Sans / Serif, Roboto / Slab |
| Geometric | Lato / Poppins, Nunito / Raleway, DM Sans / DM Serif, Outfit |
| Editorial | Open Sans / Lora, Nunito / Merriweather, Inter / Playfair, Libre Franklin / Baskerville |
| Friendly | Quicksand, Nunito Sans / Nunito, Rubik |

Dark mode palette is auto-generated by lightening semantic colours and inverting foreground/background. The configurator saves and closes gracefully after writing `_brand.yml`.

---

## Package Structure

```
brandkit/
+-- R/
|   +-- brand_cache.R        # YAML parsing, caching, accessors, logo helpers
|   +-- brand_colors.R       # Palette generation (discrete, sequential, diverging)
|   +-- brand_configure.R    # Interactive Shiny configurator wizard
|   +-- brand_fonts.R        # Font registration via sysfonts/showtext
|   +-- brand_ggplot.R       # ggplot2 theme + scale functions
|   +-- brand_pages.R        # Zero-boilerplate Shiny page wrappers + thematic
|   +-- brand_plotly.R       # Branded ggplotly conversion
|   +-- brand_quarto.R       # Quarto scaffolding + render-time setup
|   +-- brand_theme.R        # bslib theme + dark mode CSS generation
|   +-- utils.R              # Hex conversion, colour shifting helpers
|   +-- zzz.R                # .onLoad / .onAttach (auto-apply theme + scales)
+-- inst/
|   +-- _brand.yml           # Bundled default brand (Slate & Teal / Inter)
|   +-- css/overrides.css    # Static CSS for BS5 gaps + leaflet dark mode
|   +-- quarto/              # SCSS, example .qmd (report, slides, showcase)
+-- examples/
    +-- app.R                # Zero-boilerplate sidebar demo
    +-- app_navbar.R         # Navbar layout, DT, value boxes, distributions
    +-- app_fluid_leaflet.R  # Fluid layout, leaflet map, reactive plotly
    +-- app_sidebar_gt.R     # Sidebar, gt table, correlation matrix, downloads
    +-- app_stress_test.R    # Every Shiny input widget, modals, dynamic UI
    +-- app_no_brand.R       # Graceful fallback test (no _brand.yml)
    +-- app_verbose.R        # Explicit theming (for comparison / learning)
    +-- test_ggplot.R        # Quick ggplot2 test (no Shiny needed)
```

---

## Common Patterns & Pitfalls

### Pattern: Minimal Shiny app

```r
library(shiny); library(bslib); library(ggplot2); library(brandkit)

ui <- brand_page_sidebar(
  title = "App",
  sidebar = sidebar(selectInput("x", "X:", names(mtcars))),
  card(card_header("Plot"), plotOutput("p"))
)
server <- function(input, output, session) {
  output$p <- renderPlot(ggplot(mtcars, aes(.data[[input$x]], mpg)) + geom_point())
}
shinyApp(ui, server)
```

### Pattern: Plotly in Shiny with dark mode

```r
server <- function(input, output, session) {
  dm <- brand_dark_mode(input)
  output$p <- renderPlotly({
    p <- ggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species)) + geom_point()
    brand_plotly(p, mode = dm$mode())
  })
}
```

### Pattern: gt table with dark mode

```r
server <- function(input, output, session) {
  dm <- brand_dark_mode(input)
  output$tbl <- render_gt({
    cols <- brand_colors(dm$mode())
    gt(data) |>
      tab_style(
        style = list(cell_fill(color = cols$primary), cell_text(color = "white", weight = "bold")),
        locations = cells_column_labels()
      ) |>
      tab_style(style = cell_text(color = cols$foreground), locations = cells_body()) |>
      tab_options(table.background.color = cols$background, table.width = pct(100))
  })
}
```

### Pattern: Quarto setup chunk

```r
#| label: setup
#| include: false
library(brandkit)
library(ggplot2)
brand_quarto_setup()  # all subsequent plots are branded
```

### Pitfall: `brand_page_navbar()` with non-nav content

```r
# WRONG — will error:
brand_page_navbar(title = "App", card("content"), nav_panel("Tab", "..."))

# CORRECT — all content inside nav_panel():
brand_page_navbar(title = "App", nav_panel("Main", card("content")))
```

### Pitfall: Plotly in revealjs slides

```r
# WRONG — plot overflows the slide:
brand_plotly(p)

# CORRECT — fixed dimensions for slides:
brand_plotly(p, width = 1000, height = 600)
```

### Pitfall: `_brand.yml` format for Quarto vs Shiny

The `color-dark:` and `theme:` sections are bslib-specific. If you copy a Shiny `_brand.yml` into a Quarto project, Quarto will error. Always use `use_brand_quarto()` to scaffold — it converts to the Quarto-compatible format automatically.

### Pitfall: gt tables don't respond to dark mode CSS

Unlike DT, gt renders its own HTML/CSS and ignores Bootstrap variables. Always style gt tables manually with `brand_colors(mode)`. Use `table.width = pct(100)` to fill the container.

### Pitfall: Leaflet tiles don't auto-switch

Leaflet tile providers are set at render time. To match dark mode, conditionally use `CartoDB.DarkMatter`:

```r
leaflet() |> addProviderTiles(if (mode == "dark") "CartoDB.DarkMatter" else "OpenStreetMap")
```

### Pitfall: Continuous colour scales in plotly tooltips

```r
# WRONG for continuous colour:
brand_plotly(p, tooltip = c("x", "y", "colour"))

# CORRECT for continuous:
brand_plotly(p, tooltip = c("x", "y"))

# OK for discrete colour:
brand_plotly(p, tooltip = c("x", "y", "colour"))
```

---

## Requirements

- R >= 4.1
- bslib >= 0.9.0 (for native `_brand.yml` support)
- Quarto >= 1.8 (for brand shortcodes and `brand-mode`)

## License

MIT
