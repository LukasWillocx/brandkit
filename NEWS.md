# brandkit (development version)

* Declared dependencies that were used but not listed: `later` and `utils`
  in Imports, `htmlwidgets` in Suggests.

# brandkit 0.3.0

Everything below is relative to 0.2.0 (the initial release, 2026-05-01).

## New: Quarto templates

* `create_brand_quarto_html()` and `create_brand_quarto_pdf()` scaffold a
  branded report. The HTML and Typst PDF versions are kept visually in step.
* `create_brand_quarto_slides()` scaffolds a branded slide deck (reveal.js).
* `create_brand_quarto_dashboard()` scaffolds a branded Quarto dashboard.
* `create_brand_quarto_print_pdf()` scaffolds a print-friendly PDF.
* `create_brand_quarto_poster()` scaffolds a Typst poster.
* All templates use `airquality` as sample data, so they render without extra
  packages.

## New: Shiny templates

* `create_brand_shiny_app()`, `create_brand_shiny_dashboard()` and
  `create_brand_shiny_map()` scaffold branded starter apps (the map template
  uses leaflet, now listed in Suggests).

## New: drift ornaments

* `brand_ornament()` draws a soft corner ornament in the brand colours, and
  `brand_ornaments_tag()` places the pair on a web page. The ornaments follow
  the Bootstrap light/dark variables.
* The page wrappers (`brand_page_fluid()`, `brand_page_sidebar()`,
  `brand_page_navbar()`) accept `style = "drift"`.
* The Quarto templates have an optional drift style for banner and footer
  ornaments, including slides, via a shared `drift.scss`.

## Dark and light mode

* HTML reports and dashboards render in both light and dark mode, following
  the viewer's setting.
* The Quarto/bslib brand compliance can be switched on or off per template.
* Plotly colours are inherited correctly in dark mode.

## Fonts and plots

* Brand font handling was reworked, bold weights work again, and font
  pairings are validated.
* ggplot output can use a transparent background so it blends into themed
  pages.

## Widgets and layout

* CSS overrides now cover leaflet, DT/table and gt output.
* Navbar page layouts are supported.
* `configure_brand()` closes the app when you save, and its preview was
  adjusted.

## Package housekeeping

* `colourpicker` and `thematic` moved from Suggests to Imports; `rlang` is
  imported explicitly.
* The root `_brand.yml` is no longer tracked, and `.gitignore` rules that had
  no effect were fixed.
* Added `examples/` apps (fluid + leaflet, navbar, sidebar + gt, no brand,
  stress test) used for conformity testing.
