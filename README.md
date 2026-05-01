# brandkit <img src="man/figures/logo.png" align="right" height="120" />

**Opinionated brand theming for R — configure once, apply everywhere.**

brandkit turns a single `_brand.yml` file into consistent, polished theming across Shiny apps, ggplot2 plots, plotly widgets, Quarto documents, and revealjs presentations. It builds on top of the official [brand.yml](https://posit-dev.github.io/brand-yml/) ecosystem while adding an interactive configurator, smart palette generation, auto-applied defaults, and CSS overrides for third-party widgets that Bootstrap 5 doesn't reach.

## Installation

```r
# Install from GitHub
devtools::install_github("yourusername/brandkit")
```

## Quick start

### 1. Configure your brand

```r
library(brandkit)
configure_brand()
```

This launches an interactive Shiny wizard that walks you through colour palettes, font pairings, logo upload, and border radius — with live preview. Hit save and it writes a `_brand.yml` to your project.

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

That's it. No `theme =`, no `+ theme_brand()`, no `scale_color_brand_d()`, no dark mode plumbing. Everything is injected automatically:

- Brand colours, fonts, and logo from `_brand.yml`
- Dark mode toggle (top-right corner)
- ggplot2 theme and discrete scales set globally on `library(brandkit)`
- CSS overrides for sliders, datepickers, selectize, checkboxes, radios, switches
- Plot backgrounds that match dark/light mode via thematic

### 3. Use in Quarto

```r
# Scaffold a Quarto project with brand assets
use_brand_quarto(path = "my-report")
```

Then in your `.qmd`:

```yaml
---
title: "My Report"
format:
  html:
    theme:
      light: [brand, brandkit.scss]
      dark: [brand, brandkit.scss]
---
```

```r
#| label: setup
#| include: false
library(brandkit)
brand_quarto_setup()  # or brand_quarto_setup("dark")
```

Every ggplot and plotly output is auto-themed. For revealjs slides, add `logo: medium` to the format options.

## What brandkit handles that the official tooling doesn't

The official `brand.yml` + `bslib` pipeline covers Bootstrap compilation. brandkit adds the layer on top:

| Gap | What brandkit does |
|---|---|
| ionRangeSlider colours in dark mode | Dynamic CSS injection from `_brand.yml` dark palette |
| Shiny checkbox/radio containers | Override baked-in compiled styles |
| Selectize focus rings and active states | CSS custom property overrides |
| Datepicker active/today highlights | `brand_dark_css()` injects at runtime |
| ggplot2 not auto-themed | `.onAttach` calls `theme_set()` and registers default scales |
| No interactive brand setup | `configure_brand()` wizard with live preview |
| Discrete palettes use hardcoded hex | Derived algorithmically via HCL hue rotation |
| Plot backgrounds white in Quarto | `brand_quarto_setup()` sets `dev.args$bg` |
| No logo in Shiny title | `brand_page_sidebar()` auto-prepends from `_brand.yml` |

## Key functions

### Configurator

| Function | Purpose |
|---|---|
| `configure_brand()` | Interactive Shiny wizard to create `_brand.yml` |

### Shiny page wrappers

| Function | Purpose |
|---|---|
| `brand_page_sidebar()` | Drop-in `page_sidebar()` with full brand injection |
| `brand_page_navbar()` | Drop-in `page_navbar()` with full brand injection |
| `brand_page_fluid()` | Drop-in `page_fluid()` with full brand injection |

### Theming

| Function | Purpose |
|---|---|
| `brand_theme()` | bslib theme with dark mode + CSS overrides |
| `theme_brand()` | ggplot2 theme from brand cache |
| `brand_plotly()` | Branded ggplotly conversion |
| `brand_dark_css()` | CSS overrides for third-party widgets |

### Colour palettes

| Function | Purpose |
|---|---|
| `brand_pal_discrete()` | Algorithmically derived discrete palette |
| `brand_pal_seq()` | Sequential palette (warm, cool, green) |
| `brand_pal_div()` | Diverging palette |
| `scale_color_brand_d()` / `scale_fill_brand_d()` | ggplot2 discrete scales |
| `scale_color_brand_c()` / `scale_fill_brand_c()` | ggplot2 continuous scales |

### Quarto integration

| Function | Purpose |
|---|---|
| `use_brand_quarto()` | Scaffold a Quarto project with brand assets |
| `brand_quarto_setup()` | Set up ggplot2 + knitr for branded rendering |

### Cache & accessors

| Function | Purpose |
|---|---|
| `brand_init()` | Load/reload a `_brand.yml` |
| `brand_colors()` | Get cached colours (light or dark) |
| `brand_fonts()` | Get cached font families |
| `brand_logo()` | Get resolved logo file path |
| `brand_logo_tag()` | Get inline `<img>` tag for Shiny |
| `brand_raw()` | Full parsed YAML (escape hatch) |

## Package structure

```
brandkit/
├── R/
│   ├── brand_cache.R        # YAML parsing, caching, accessors
│   ├── brand_colors.R       # Palette generation (discrete, sequential, diverging)
│   ├── brand_configure.R    # Interactive Shiny configurator
│   ├── brand_fonts.R        # Font registration (sysfonts/showtext)
│   ├── brand_ggplot.R       # ggplot2 theme + scale functions
│   ├── brand_pages.R        # Zero-boilerplate Shiny page wrappers
│   ├── brand_plotly.R       # Branded ggplotly conversion
│   ├── brand_quarto.R       # Quarto scaffolding + render setup
│   ├── brand_theme.R        # bslib theme + dark mode CSS generation
│   ├── utils.R              # Shared helpers (hex conversion, colour shifting)
│   └── zzz.R                # .onLoad / .onAttach hooks (auto-apply)
├── inst/
│   ├── _brand.yml           # Bundled default brand
│   ├── css/overrides.css    # Static CSS for BS5 gaps
│   └── quarto/              # SCSS + example .qmd templates
└── examples/
    ├── app.R                # Zero-boilerplate Shiny demo
    ├── app_verbose.R        # Explicit theming demo (for comparison)
    └── test_ggplot.R        # Quick ggplot2 test (no Shiny)
```

## Requirements

- R ≥ 4.1
- bslib ≥ 0.9.0 (for native `_brand.yml` support)
- Quarto ≥ 1.8 (for brand shortcodes and light/dark support)

## License

MIT
