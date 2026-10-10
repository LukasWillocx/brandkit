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

### 3. Scaffold a project

Rather than starting from a blank file, scaffold a working, branded project and edit it down. Each function writes a `_brand.yml` in the right format for its target, plus a template and any local font/logo files.

```r
# Shiny apps — one per brand_page_*() wrapper, each lands as app.R
create_brand_shiny_app(path = "my-app")             # starter, sidebar layout
create_brand_shiny_dashboard(path = "my-dashboard") # KPI dashboard, navbar + DT
create_brand_shiny_map(path = "my-map")             # leaflet + plotly, fluid layout

# Quarto documents
create_brand_quarto_html(path = "my-report")        # HTML report
create_brand_quarto_slides(path = "my-report")      # revealjs slides
create_brand_quarto_pdf(path = "my-report")         # PDF via Typst
create_brand_quarto_print_pdf(path = "my-report")   # PDF via Typst, drift look, print-friendly
create_brand_quarto_poster(path = "my-poster")      # A0 landscape conference poster via Typst
create_brand_quarto_dashboard(path = "my-dashboard")# Quarto dashboard, Shiny runtime
```

Run a Shiny scaffold with `shiny::runApp("my-app")`. For the Quarto scaffolds, add `library(brandkit)` and `brand_quarto_setup()` in a setup chunk (the templates already do); the Quarto dashboard is served with `quarto serve dashboard.qmd` rather than rendered, since it declares `server: shiny`.

The directory is created if it doesn't exist, and nothing is overwritten unless you pass `overwrite = TRUE` — except a `_brand.yml` in the wrong format for the target, which is always converted (see below).

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
  theme_args = list(),          # extra args passed to brand_theme()
  style = "classic"             # "classic" or "drift" (see below)
)
```

#### `style = "drift"`

The poster template's look, carried into the browser. It is opt-in, and `"classic"` (the default) leaves the page exactly as it was, so existing apps are unaffected. What `"drift"` changes:

- **Corner ornaments.** The same geometric motif as the poster, top-right and bottom-left of the *window*, fixed behind the page and sized to 32% of its shorter side. They are inline SVG whose colours are Bootstrap's CSS variables (`--bs-primary`, `--bs-secondary`, `--bs-info`), so they follow the dark-mode toggle live, with no redraw. Available on their own as `brand_ornaments_tag()`.
- **Plain-type title.** The navbar bar and its rule are removed, so the title sits on the page and the top-right ornament shows behind it.
- **Cards as tinted surfaces.** A card is the brand's primary mixed 7% into the background, with a solid primary header bar, no shadow and no hover lift. The tint is computed in R, once per mode, as a plain opaque colour: nothing shows through it, and the colour thematic reads off it to give each plot a matching background is exact. Card colours do not animate on a theme switch, which would otherwise have thematic sampling a half-faded colour.
- **A transparent sidebar.** It runs the full height of the window, which is where the bottom-left ornament lives, so it is left unfilled and the ornament shows behind the controls.
- **Tables and text output.** Body rows show the card; stripes are white at low opacity (a step lighter) and the header a faint wash of the primary. `verbatimTextOutput()` gets the stripes' treatment instead of a grey slab.

All of it is scoped to a class the page adds to `<html>`, so none of it can leak into a classic page.

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
5. `thematic::thematic_shiny()` is activated with the brand font. Discrete ggplot2 colour and fill scales pick the brand's light or dark palette (`brand_pal_discrete(mode = )`) according to the card each plot sits on, so a light/dark switch redraws them with colours that stay legible; base-graphics palettes are left to thematic's defaults
6. A plot-settle script hides ggplot outputs during initial layout to prevent size-flash
7. The app-wide ggplot theme is set to the opaque `theme_brand(transparent = FALSE)`, which `thematic` needs to repaint each plot to match its container (see [Explicit theme function](#explicit-theme-function))

### Scaffolding a Shiny project

There is one template per page wrapper. Each writes a bslib-format `_brand.yml`, an `app.R`, and any local font and logo files into `path` — creating the directory if it doesn't exist — then tells you what to run.

```r
create_brand_shiny_app(path = "my-app")             # brand_page_sidebar
create_brand_shiny_dashboard(path = "my-dashboard") # brand_page_navbar
create_brand_shiny_map(path = "my-map")             # brand_page_fluid

shiny::runApp("my-app")
```

| Template | Wrapper | Shows off | Needs |
|---|---|---|---|
| `create_brand_shiny_app()` | `brand_page_sidebar(style = "drift")` | The zero-boilerplate baseline, in the poster's look: sidebar inputs, a ggplot, a `brand_pal_discrete()` swatch, corner ornaments | — |
| `create_brand_shiny_dashboard()` | `brand_page_navbar()` | Value-box KPI row, multi-tab layout, a DT table styled in both modes | `DT` |
| `create_brand_shiny_map()` | `brand_page_fluid()` | `brand_pal_seq()` driving a leaflet colour ramp, `brand_plotly()`, tiles that follow the dark-mode toggle | `leaflet`, `plotly` |

Templates that need a suggested package say so at scaffold time rather than letting you hit the error when the app starts — the files are written either way.

Unlike the Quarto scaffolds there is no stylesheet to copy: the page wrappers pull brandkit's widget CSS overrides and dark-mode CSS in at runtime.

Note that the Shiny and Quarto scaffolds want *different dialects* of `_brand.yml` — see [The two `_brand.yml` formats](#the-two-_brandyml-formats). Running a `create_brand_shiny_*()` function in a directory holding a Quarto-format file converts it (and vice versa), so a directory serving both needs one format chosen deliberately rather than whichever scaffold ran last.

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
theme_brand(base_size = 14, mode = "light", transparent = NULL)
```

Returns a `ggplot2::theme` object with:
- Transparent plot and panel backgrounds by default, so a plot takes on the colour of whatever it sits on (a page, a poster card). Pass `transparent = FALSE` to fill with the brand background instead, e.g. for plots saved with `ggsave()`, which have no container behind them. **Inside a running Shiny app the default flips to `FALSE`:** `thematic` paints each plot's background to match its container by remapping the fills in the ggplot theme, and a theme with no fills leaves it nothing to remap, so after a light/dark switch some plots are left on the old mode's background. The plot still ends up the colour of its container, via thematic
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
# Copies: _brand.yml (Quarto-compatible), drift.scss, _ornaments.html, report.qmd, fonts, logo

create_brand_quarto_slides(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), drift.scss, _ornaments.html, slides.qmd, fonts, logo

create_brand_quarto_pdf(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), _extensions/brandkit/ (Typst format), report-pdf.qmd, fonts, logo

create_brand_quarto_poster(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), _extensions/brandkit-poster/ (Typst format), poster.qmd, fonts, logo

create_brand_quarto_dashboard(path = "my-project")
# Copies: _brand.yml (Quarto-compatible), drift.scss, _ornaments.html, dashboard.qmd, fonts, logo
```

Each function is standalone and copies only its one example `.qmd` — run whichever ones you need in the same project directory; they share `_brand.yml`, fonts, and logo without overwriting each other's files.

### The two `_brand.yml` formats

There are two dialects of `_brand.yml`, sharing one filename:

| | Shiny / bslib | Quarto |
|---|---|---|
| Dark colours | separate `color-dark:` section | nested `light:` / `dark:` values per colour |
| Bootstrap variables | `defaults: bootstrap: defaults:` | `defaults: bootstrap: defaults:` |
| Read by | bslib | Quarto **and** bslib |

The dialects differ only in how dark colours are carried. Each side rejects the other's form:

- Quarto's renderer rejects `color-dark:` (and `theme:`) outright — rendering a `.qmd` against a bslib-format file fails with a Quarto-side YAML validation error, not an R error.
- bslib rejects Quarto's nested colours — `bslib::bs_theme(brand = )` errors with `` `color.primary` must be a single string or `NULL`, not a list ``, so the app never starts.

> **Note on `theme:`** — `configure_brand()` writes Bootstrap variables under a `theme:` key. bslib does not read that key: a border radius set there is silently ignored and you get Bootstrap's `3px` default. `defaults: bootstrap: defaults:` is the channel both bslib and Quarto honour, and it is what the `create_brand_*()` scaffolds write.

You pick the format in `configure_brand()` itself, via the **Output format** toggle in the sidebar (the YAML tab previews whichever one is selected). It starts on whatever the `_brand.yml` already in that directory is, so re-configuring a Quarto project no longer clobbers it with a file Quarto can't read. Set it up front with `configure_brand(format = "quarto")` if you prefer.

The `create_brand_quarto_*()` functions still convert a bslib-format `_brand.yml` on their own regardless of `overwrite`, so configuring in bslib format and converting at scaffold time remains a valid route — and an already-Quarto-compatible file is left alone.

### HTML documents

```yaml
---
title: "My Report"
subtitle: "A branded HTML report"
author: "Your Name"
date: today
format:
  html:
    title-block-style: none   # the .brand-masthead div supplies the title block
    theme:
      light: [brand, drift.scss]
      dark: [brand, drift.scss]
    include-after-body: _ornaments.html
    toc: false
---
```

```r
#| label: setup
#| include: false
library(brandkit)
brand_quarto_setup()
```

`report.qmd` ships with a reader-facing light/dark toggle, which is what the nested `theme:` form above buys you: Quarto compiles one Bootstrap stylesheet per mode from `_brand.yml`'s `color:`/`color-dark:` entries, and the toggle swaps between them. Note that the flat `theme: [brand, drift.scss]` form is *not* equivalent — it still renders a toggle, but only the syntax highlighting switches while the Bootstrap layer stays light, so keep the nested form if you want the toggle to work.

Plots would normally be the one thing the toggle can't switch: they are static images baked in at render time. `report.qmd` gets round that with `brand_quarto_setup(adaptive = TRUE)`, which draws every figure twice, once per colour mode, and shows whichever matches the page. Nothing in the document's chunks changes: after each chunk that drew figures, brandkit runs its code again in dark mode into twin files (`<label>-dark-<n>.png`), and the plot hook adds a `data-dark-src` attribute to the light image so a small script can swap them when the toggle flips; `brand_plotly()` writes a light and a dark widget and a stylesheet shows the matching one. The dark version gets the dark text colours *and* the brand's dark palette. Costs to know about: each plot chunk runs twice, the dark files must stay beside the page (so `embed-resources: true` is not supported), and a `brand_plotly()` result is a pair of widgets that can't be piped into further plotly calls. Leave `adaptive` off, or pass `mode =` to pick one, for a document with a single mode. Revealjs slides still have the old constraint — see below.

`report.qmd` is in the same "drift" look as the poster, the print PDF and the Shiny starter, and its sample is R's built-in `airquality` data. It opens with a `.brand-masthead` div — the logo (if configured), then the title in the brand's primary, the subtitle a step quieter, and a short round-capped bar in the secondary colour above the author and date — and closes with a `.brand-footer` div. The colour comes from a pair of soft corner ornaments fixed behind the page (`_ornaments.html`, included with `include-after-body:`), so there is no title panel. Both files are short and meant to be edited: `drift.scss` is sectioned into shared, document and dashboard rules (the dashboard rules never match in a report), and the masthead and footer are plain divs that pull title, subtitle, author and date from the YAML via `{{< meta ... >}}`. Tables take a tinted header and a subtle stripe, code blocks the card tint, and headings the brand's primary.

The ornaments are inline SVG filled with the page's own CSS colour variables, so `_ornaments.html` never goes stale when the brand changes and follows the dark-mode toggle. Unlike a dashboard, a report does not group its sections into cards: sections run on as ordinary document flow.

### Revealjs slides

Scaffolded by `create_brand_quarto_slides()`, in the same "drift" look as the report and the poster, on R's built-in `airquality` data.

```yaml
---
title: "My Slides"
format:
  revealjs:
    theme: [brand, drift.scss]
    include-after-body: _ornaments.html
    logo: medium
    slide-number: true
    footer: "{{< meta title >}}"
---
```

The title slide is plain type, left-aligned, with no panel: the title in the brand's primary colour, the subtitle a step quieter, then a short round-capped bar above the author and date. Content slides carry headings in the primary colour, and every slide has the pair of corner ornaments behind it, from `_ornaments.html`. `drift.scss` is the same file the HTML report and dashboard use; its Slides section holds the rules below. Two of them are worth knowing about if you adapt the deck: revealjs defines no Bootstrap colour variables, so the section defines the three the ornaments are filled with from the brand colours of the deck's mode (otherwise a dark deck would draw the light ornaments), and reveal paints its viewport opaque, which would hide anything fixed behind the slides, so the page background is moved onto `<html>`. The persistent `footer:` mirrors the title text on every other slide, and the PDF template's footer, for a consistent look across formats.

For dark mode slides, add `brand-mode: dark` and use `brand_quarto_setup("dark")`.

For plotly in slides, always pass fixed dimensions: `brand_plotly(p, width = 1000, height = 600)`.

### Dashboard

`create_brand_quarto_dashboard()` scaffolds a small Shiny-backed Quarto dashboard in the same "drift" look as the poster and the Shiny starter: soft corner ornaments behind the page, the title as plain type, tinted cards under a solid header, a transparent sidebar rail. The sample is R's built-in `airquality` data (daily New York air quality, 1973), filtered by month and temperature. It is three short files you edit directly:

- `dashboard.qmd` — the dashboard: sidebar inputs, a row of value boxes, two charts and a table, in about 130 lines of Quarto markdown and Shiny code.
- `drift.scss` — the look, built from the brand's own Sass variables. Quarto compiles it once per colour mode, so one file serves both.
- `_ornaments.html` — the two corner ornaments, drawn with the page's CSS colour variables rather than hex values, so they follow the brand and the dark-mode toggle without being regenerated.

Dark mode is on by default: the document declares one theme per mode (`theme: light: [brand, drift.scss]  dark: [...]`), which is what puts the toggle in the navbar. Plots are drawn live by Shiny rather than baked in at render time, so — unlike the static report — they follow the toggle too. `brand_quarto_setup(shiny = TRUE)` is the one line that arranges that: it switches on thematic, which gives every `renderPlot()` the colours, fonts and background of the card it sits in and redraws it when the mode changes — including the discrete palette, which switches to the brand's dark colours on a dark card. Add `# Page` headings for more pages; the tab strip appears once there are two. Serve with `quarto serve dashboard.qmd`.

### PDF documents (Typst)

`create_brand_quarto_pdf()` scaffolds a project that renders to PDF via Quarto's built-in Typst engine — no LaTeX required. Quarto's `_brand.yml` integration already applies brand colours and fonts to Typst output. brandkit's `brandkit-typst` format extension (installed at `_extensions/brandkit/`) adds a full-bleed title banner on page 1 — a diagonal-stripe field, drawn as Typst polygons (no image asset), that runs primary-coloured behind the title/subtitle and switches to secondary-coloured stripes past an angled seam, the field the slide deck's stylesheet shares — with the logo (if configured) placed inline in it, plus coloured headings, a coloured footer showing the document title and page number, and rounded code-block corners matching the brand's configured `theme.border-radius` (`_extension.yml` is generated per-brand at scaffold time for these — re-run with `overwrite = TRUE` after changing the brand). If the document has no title, the banner is skipped and the logo falls back to a plain top-right corner mark on page 1 instead (Quarto's own default repeats a logo on every page as a watermark; brandkit restricts it to page 1 either way).

### Print-friendly PDF

`create_brand_quarto_print_pdf()` is the PDF in the "drift" look, and the one to reach for when the document will be printed. Where `create_brand_quarto_pdf()` keeps its firm striped banner, this one opens with a plain masthead — the logo on the right, the title in the brand's primary, the subtitle beneath, then a short round-capped bar above the author and date — and frames the first page with the same pair of soft corner ornaments as the poster and the HTML report. It installs its own extension at `_extensions/brandkit-print/`, contributing the `brandkit-print-typst` format, and both PDF formats can live in one project — switch by changing a document's `format:` key.

It suits paper for three reasons. Nothing is full-bleed, so there is no ink near the unprintable edge of an ordinary printer (the ornaments are faint enough that a clipped edge does not show); there is no solid panel to show through lighter stock; and the ornaments are drawn at a low opacity, so the header area uses a fraction of the ink of the striped banner. They appear on the first page only, as a title page framed and the pages after it plain — in `page.typ` it is a single `if` to repeat them on every page. The running footer (rule, title and page number) is the other way round: it starts on page two, so the title page carries nothing but the masthead and the ornaments.

The masthead is flow content rather than a fixed-height background, so it sizes itself to its content — a long title simply wraps. The ornaments are generated from `_brand.yml` at scaffold time (`drift-top-right.svg`, `drift-bottom-left.svg`); re-run with `overwrite = TRUE` after changing the brand. The sample is the `airquality` data.

One caveat if you are optimising for print: Quarto fills the whole page with `_brand.yml`'s `color.background`, independently of the ornaments. If your brand's background is anything other than white, that tint is itself full-bleed and will clip at an ordinary printer's unprintable edge. Set `color.background` to white for a print-targeted brand.

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

### Conference posters (Typst)

`create_brand_quarto_poster()` scaffolds a single landscape sheet built from the same template partials as the report formats — the same colours, code styling and table rules — installed at `_extensions/brandkit-poster/` as the `brandkit-poster-typst` format. It is still a plain `.qmd`: knitr chunks, `brand_quarto_setup()`, `theme_brand()` and the palette helpers all work exactly as they do in a report.

```r
create_brand_quarto_poster(path = "my-poster", paper = "a0", columns = 3)
# Copies: _brand.yml, _extensions/brandkit-poster/ (incl. poster.lua), poster.qmd, fonts, logo
```

Five things differ from the reports, all following from it being one big sheet:

- **Soft corner ornaments instead of a title panel.** The sheet's colour comes from a pair of geometric corner pieces, top-right and bottom-left, drawn behind everything in the brand's primary, secondary and info colours at a low opacity. The title sits on the page as plain type in the brand's primary colour. See *Corner ornaments* below.
- **Landscape page columns.** The body flows down column one, then two, then three. The masthead spans them as a parent-scope float.
- **Every `##` section becomes a card** — a tinted panel with a primary header bar and the brand's own corner radius, grouped by the `poster.lua` filter the extension ships. Cards never split across a column: one that doesn't fit moves to the next column whole. Mark a heading `## Something {.plain}` to opt it out and let it run free in the column.
- **Type is sized to the measure, not to the sheet.** A line wants about 70 characters, so the body size falls out of whatever measure `paper` and `columns` produce: A0 at three columns is a 13-inch measure and ~36pt type; A0 at four columns is ~26pt. Under that sits a viewing-distance floor (24pt on A0, less on smaller sheets), so a narrow-columned layout can't set type too small to read standing in front of it. The masthead takes a further 1.6× on top, since it is the part read from across a hall.
- **No running footer.** `poster-footer:` in the document YAML fills an optional standing band for affiliations, funding or a URL, set flush right with no rule above it (the bottom-left ornament owns that side); leave it out and there is no footer at all.

```yaml
---
title: "A Branded Conference Poster"
subtitle: "Landscape, three columns, all inferred from _brand.yml"
author: "Your Name"
date: today
poster-footer: "Department of Everything | you@example.org"
format:
  brandkit-poster-typst:
    columns: 3
execute:
  echo: false        # a poster shows findings, not source
---
```

#### Corner ornaments

The ornaments are SVG, generated from `_brand.yml` at scaffold time and written next to the extension as `drift-top-right.svg` and `drift-bottom-left.svg`. Quarto copies them beside the rendered document, and `page.typ` draws them as the page background at 32% of the sheet's shorter side, so the proportions hold from A4 to A0. The bottom-left piece leads with the secondary colour where the top-right leads with the primary, so the sheet is balanced rather than mirrored.

Each shape is a full brand colour at a low opacity, so the extra shades come from shapes overlapping rather than from pale colours, and one `softness` value controls the whole drawing. The same generator is exported as `brand_ornament()` for use anywhere an SVG will do:

```r
cat(brand_ornament("drift", "top-right"))
brand_ornament("drift", "bottom-left", softness = 0.1, file = "corner.svg")
```

The poster uses a lower opacity (0.12) than the function's default (0.17): the default was tuned on page-sized layouts, and the same value across an A0 sheet reads as large flat blocks of colour. Re-run `create_brand_quarto_poster(overwrite = TRUE)` after changing the brand to redraw them in the new colours.

Because the type scale is baked into the extension at scaffold time, `paper` and `columns` are arguments to `create_brand_quarto_poster()` rather than things to change in the YAML afterwards — setting `papersize:` in a document changes the sheet but not the type sized for it. Re-run the function instead.

A poster is a fixed sheet and Typst will not shrink content to fit one: material that overruns spills onto a second page, and so does any single card taller than a column. Both are content problems — cut, or move to four columns.

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
3. Sets `knitr::opts_chunk$set(dev.args = list(bg = "transparent"))` — eliminates white device canvas, and lets plots take the colour of the page or card behind them (`brand_quarto_setup(transparent = FALSE)` paints them the brand background instead)
4. Registers a knitr hook to set `par()` colours for base R graphics
5. Stores the active mode so `brand_plotly()` auto-detects it
6. With `adaptive = TRUE` (HTML pages with a toggle) draws every figure in both modes; see [HTML documents](#html-documents)
7. With `shiny = TRUE` (for `server: shiny` documents) switches on thematic, so live plots follow the page's light/dark toggle

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

### `inst/quarto/drift.scss` (Quarto)

SCSS rules layered after brand in Quarto's theme pipeline, for the HTML report, the revealjs slides and the Quarto dashboard. Compiled once per colour mode, built from the brand's own Sass variables. Sectioned into shared rules (tables), document rules (masthead, headings, code, footer), slide rules (title slide, background, footer) and dashboard rules (navbar, cards, sidebar).

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
configure_brand(path = ".")                     # picks up the brand already there
configure_brand(path = ".", reset = TRUE)       # ignore it, start from defaults
configure_brand(path = ".", format = "quarto")  # preselect the output format
```

**Starting from an existing brand.** If `path` already has a `_brand.yml`, every input opens on that brand's current values — colours, font pairing, sizes, border radius, name, logo — instead of the built-in defaults, so adjusting a configured project is a nudge rather than a re-run of the whole wizard. Either format is read back. The preset and font-pairing dropdowns land on whichever entry matches, or on **Custom** for a hand-tuned brand.

Things the UI doesn't expose are carried through rather than dropped on save: a named `color.palette`, and font definitions for locally-sourced families (`source: file`), which would otherwise be rewritten as Google fonts of the same name. The one thing not preserved is hand-edited dark colours — the dark palette is always re-derived from the light one, which is what the "Auto-generate dark mode palette" box does. That box starts ticked whenever the loaded file has dark colours at all.

**Colour presets (12):**

| Category | Presets |
|---|---|
| Professional | Corporate Navy, Charcoal & Steel, Slate & Teal |
| Refined | Wine & Sage, Plum & Gold, Ocean & Coral, Forest & Amber |
| Warm | Terracotta & Cream, Espresso & Caramel |
| Light-hearted | Mint & Peach, Lavender & Rose, Sunset Gradient |

**Font pairings (10, plus Custom):**

| Category | Pairings |
|---|---|
| Clean & professional | Plus Jakarta Sans / Montserrat, IBM Plex Sans, Roboto / Bitter |
| Modern & geometric | Raleway / Playfair Display, Jost |
| Warm & editorial | Libre Franklin / Libre Baskerville, Mulish / Lora |
| Expressive & bold | Work Sans / Fraunces |
| Friendly & rounded | Rubik, Nunito |

Every family offered here is verified to survive the Typst/PDF path, where two things can go wrong silently that never show up in the HTML preview:

- **A missing face.** Typst synthesizes neither bold nor oblique, so a family without a 700 or an italic renders that markup unstyled — `**bold**` unbolded, `*italic*` upright. Browsers fake both, which is why HTML looks fine.
- **A family-name mismatch.** Families with an optical-size axis are served as static instances named `<Family> <n>pt` (e.g. `DM Sans 9pt`), which never match the requested name — so Typst ignores the downloaded files and falls back to its default serif, dropping the brand font from the PDF entirely.

A third criterion applies to the **base** font only: its x-height is matched to the code face. Point size is not what the eye reads as size, so a base font whose x-height sits far from IBM Plex Mono's (0.5160 em) makes inline `code` and fenced blocks look mis-sized even though both are pinned to identical points. Every base font above is within 3.7%. Heading fonts are exempt — they never sit inline with code — which is why high-contrast display serifs stay on the menu.

**Jost is a deliberate exception at 12.2% off**, kept because it's in use: code will read slightly larger than body text in that pairing. No monospace face fixes it without breaking the others (the three that match Jost land 15–17% out against Inter-class bases, and Inconsolata has no italic).

If you type a custom family into the wizard, it's worth checking both. `quarto typst fonts --font-path <project>/.quarto/typst-font-cache --ignore-system-fonts` lists the family names actually downloaded for your brand.

Dark mode palette is auto-generated by lightening semantic colours and inverting foreground/background.

**Output format.** A sidebar toggle picks which `_brand.yml` dialect gets written — Shiny/bslib or Quarto (see [The two `_brand.yml` formats](#the-two-_brandyml-formats)). It defaults to the format of the file already in `path`, and the YAML tab previews the selected dialect, so what you read there is what lands on disk. The configurator saves and closes gracefully after writing `_brand.yml`.

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
|   +-- brand_ornaments.R    # Corner ornaments: SVG generator + web tag (poster, drift)
|   +-- brand_pages.R        # Zero-boilerplate Shiny page wrappers + thematic
|   +-- brand_plotly.R       # Branded ggplotly conversion
|   +-- brand_quarto.R       # Quarto scaffolding + render-time setup
|   +-- brand_shiny.R        # Shiny app scaffolding (+ bslib _brand.yml writer)
|   +-- brand_theme.R        # bslib theme + dark mode CSS generation
|   +-- utils.R              # Hex conversion, colour shifting helpers
|   +-- zzz.R                # .onLoad / .onAttach (auto-apply theme + scales)
+-- inst/
|   +-- _brand.yml           # Bundled default brand (Slate & Teal / Inter)
|   +-- css/overrides.css    # Static CSS for BS5 gaps + leaflet dark mode
|   +-- css/drift.css        # The opt-in "drift" page style (scoped to html.bk-drift)
|   +-- quarto/              # SCSS + one example .qmd per create_brand_quarto_*()
|   |   +-- report.qmd       # Example HTML report
|   |   +-- slides.qmd       # Example revealjs slides
|   |   +-- pdf-report.qmd   # Example Typst PDF report
|   |   +-- dashboard.qmd    # Example Shiny dashboard (format: dashboard)
|   |   +-- drift.scss       # The "drift" look for Quarto pages (dashboard)
|   |   +-- typst/_extensions/brandkit/  # brandkit-typst format extension
|   +-- shiny/               # One app template per create_brand_shiny_*()
|       +-- app-starter.R    # Sidebar starter (brand_page_sidebar, style = "drift")
|       +-- app-dashboard.R  # KPI dashboard, DT table (brand_page_navbar)
|       +-- app-map.R        # Leaflet + plotly (brand_page_fluid)
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
