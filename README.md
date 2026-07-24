# brandkit

**Opinionated brand theming for R — configure once, apply everywhere.**

brandkit turns a single `_brand.yml` file into consistent, polished theming across Shiny apps, ggplot2 plots, plotly widgets, Quarto documents, and revealjs presentations. It builds on top of the official [brand.yml](https://posit-dev.github.io/brand-yml/) ecosystem while adding an interactive configurator, smart palette generation, auto-applied defaults, and CSS overrides for third-party widgets that Bootstrap 5 doesn't reach.

## Installation

```r
devtools::install_github("LukasWillocx/brandkit")
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
create_brand_quarto_html(path = "my-report")     # HTML report
create_brand_quarto_slides(path = "my-report")   # revealjs slides
create_brand_quarto_pdf(path = "my-report")      # PDF via Typst
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

- The `color-dark:` and `theme:` sections are bslib-specific and not recognized by Quarto. When scaffolding for Quarto via `create_brand_quarto_html()` or `create_brand_quarto_pdf()`, brandkit automatically converts to the Quarto-compatible format (nested `light:`/`dark:` under each colour key).
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
create_brand_quarto_html(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), brandkit.scss, report.qmd, fonts, logo

create_brand_quarto_slides(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), brandkit.scss, slides.qmd, fonts, logo

create_brand_quarto_pdf(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), _extensions/brandkit/ (Typst format), report-pdf.qmd, fonts, logo
```

Each function is standalone and copies only its one example `.qmd` — run whichever ones you need in the same project directory; they share `_brand.yml`, fonts, and logo without overwriting each other's files.

**`configure_brand()` and the `create_brand_quarto_*()` functions write two different `_brand.yml` formats to the same filename.** `configure_brand()` writes the Shiny/bslib format (`color-dark:`, `theme:` sections), which Quarto's own renderer rejects outright — rendering a `.qmd` against that file fails with a Quarto-side YAML validation error, not an R error. The `create_brand_quarto_*()` functions detect this and auto-convert a leftover bslib-format `_brand.yml` regardless of `overwrite`, so the fix is just to (re-)run whichever `create_brand_quarto_*()` function matches your project after configuring the brand. Going the other direction — running `configure_brand()` in a directory that already has a Quarto-compatible `_brand.yml` — will overwrite it with the bslib format again; re-run the `create_brand_quarto_*()` function afterward to convert it back.

### HTML documents

```yaml
---
title: "My Report"
format:
  html:
    theme: [brand, brandkit.scss]
    toc: false
---
```

```r
#| label: setup
#| include: false
library(brandkit)
brand_quarto_setup()
```

`report.qmd` is single-mode (light) by design — no dark-mode toggle, no `brand_quarto_setup("dark")` branching. If you want a light/dark reader toggle on an HTML report, switch `theme:` to the `light: [...]` / `dark: [...]` nested form yourself; plots are still static images baked in at render time either way, matching whichever mode you pass to `brand_quarto_setup()`. Revealjs slides keep both modes available — see below.

`report.qmd` opens with a `.brand-banner` div and closes with a `.brand-footer` div — the same footer styling as the other templates, so all three read as one family, though the banner itself is HTML-specific: a full-bleed primary-colour field, breaking out to the full browser width, with a secondary-colour wedge cut into *both* the left and right edges and the logo/title/subtitle centred between them. (The PDF banner, described below, uses a related but distinct asymmetric layout — a diagonal-stripe field with content left-aligned — better suited to a printed page than a browser window.)

### Revealjs slides

Scaffolded by `create_brand_quarto_slides()`.

```yaml
---
title: "My Slides"
title-slide-attributes:
  data-background-color: "#1a252f"   # brand primary, darkened — see below
format:
  revealjs:
    theme: [brand, brandkit.scss]
    logo: medium
    slide-number: true
    footer: "{{< meta title >}}"
---
```

The title slide's background comes from `title-slide-attributes` (a native revealjs option). `create_brand_quarto_slides()` writes it as a literal hex colour — the brand's primary colour darkened via `colorspace::darken()` — computed at scaffold time, not a runtime CSS expression. That's deliberate: revealjs reads `data-background-color` as a plain colour value, so a `color-mix()`/`var()` expression there isn't reliable, and a plain hex value is guaranteed to give the deck's white title/subtitle/author/date text (styled in `brandkit.scss`) enough contrast regardless of how light the brand's primary colour is. The persistent `footer:` mirrors the title text on every other slide, and the PDF template's footer, for a consistent look across formats.

For dark mode slides, add `brand-mode: dark` and use `brand_quarto_setup("dark")`.

For plotly in slides, always pass fixed dimensions: `brand_plotly(p, width = 1000, height = 600)`.

### PDF documents (Typst)

`create_brand_quarto_pdf()` scaffolds a project that renders to PDF via Quarto's built-in Typst engine — no LaTeX required. Quarto's `_brand.yml` integration already applies brand colours and fonts to Typst output. brandkit's `brandkit-typst` format extension (installed at `_extensions/brandkit/`) adds a full-bleed title banner on page 1 — a diagonal-stripe field, drawn as Typst polygons (no image asset), that runs primary-coloured behind the title/subtitle and switches to secondary-coloured stripes past an angled seam, echoing the HTML report's `.brand-banner` — with the logo (if configured) placed inline in it, plus coloured headings, a coloured footer showing the document title and page number, and rounded code-block corners matching the brand's configured `theme.border-radius` (`_extension.yml` is generated per-brand at scaffold time for these — re-run with `overwrite = TRUE` after changing the brand). If the document has no title, the banner is skipped and the logo falls back to a plain top-right corner mark on page 1 instead (Quarto's own default repeats a logo on every page as a watermark; brandkit restricts it to page 1 either way).

```yaml
---
title: "My Report"
subtitle: "A branded PDF"
author: "Your Name"
date: today
format:
  brandkit-typst:
    toc: false
---
```

```r
#| label: setup
#| include: false
library(brandkit)
brand_quarto_setup()   # PDFs have no dark mode toggle — pick one mode
```

Render with:

```r
quarto::quarto_render("report-pdf.qmd")
```

Since a PDF has no light/dark toggle, plots are baked in at render time in whichever mode you pass to `brand_quarto_setup()`. Widget-based outputs (plotly, DT, leaflet) don't apply to PDF — use static ggplot2 plots and `knitr::kable()` or `gt` tables instead.

To customise the layout further (margins, title page, footer), edit `_extensions/brandkit/typst-template.typ` directly — it's a plain-text Typst file copied into your project, not a package internal.

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
|   +-- quarto/              # SCSS + one example .qmd per create_brand_quarto_*()
|       +-- report.qmd       # Example HTML report
|       +-- slides.qmd       # Example revealjs slides
|       +-- pdf-report.qmd   # Example Typst PDF report
|       +-- typst/_extensions/brandkit/  # brandkit-typst format extension
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

The `color-dark:` and `theme:` sections are bslib-specific. If you copy a Shiny `_brand.yml` into a Quarto project, Quarto will error. Always use `create_brand_quarto_html()` or `create_brand_quarto_pdf()` to scaffold — they convert to the Quarto-compatible format automatically.

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
