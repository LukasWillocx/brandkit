# brandkit (development version)

* Inline code now matches the text around it. In the HTML templates (report,
  slides, dashboard) it is set in the body font at the surrounding size, in a
  small-cornered box padded sideways only, so a span can no longer reach the
  line above or below (it was a monospace face that read larger, in a box with
  the brand's pill-shaped radius). In the Typst PDFs inline code is likewise
  set in the body font and told apart by its colour, and fenced blocks keep the
  monospace font.
* Typst code blocks now match the HTML ones. Their box is the brand's primary
  mixed 7% into the page, the colour the HTML templates give code (it was the
  highlighting theme's fixed grey, one level off the page and close to
  invisible; the brand-derived fill the template meant to apply never reached
  highlighted blocks), and their tokens keep the highlighting theme's syntax
  colours (they had all been tinted the inline-code colour). Pandoc gives inline
  code and fenced blocks the same element, which no styling rule can tell apart,
  so a new filter, `inline-code.lua`, sets inline code as plain text; the
  extension's `typst-show.typ` also wraps skylighting's block to set its fill.
  Existing projects get this, and the HTML change, from `drift.scss`,
  `definitions.typ`, `typst-show.typ`, `typst-template.typ`, `inline-code.lua`
  and `_extension.yml`, which are only copied over with `overwrite = TRUE`.
* The top-right corner ornament can carry a short label (a brand name, say),
  set along the swell beside its largest circle, in capitals in the heading
  font. Set it in the configurator's *Meta & Logo* tab (blank by default) or
  with `meta: ornament-label:` in `_brand.yml`; `brand_ornament()` gains a
  `label` argument. It is stored under `meta:` because Quarto rejects a new
  top-level key in `_brand.yml` but accepts one there. Web pages set it as one
  text-on-path line; the SVG files Typst draws place each letter themselves,
  because Typst spaces text-on-path letters unevenly.
* Re-running a `create_brand_quarto_*()` function now brings the generated
  files up to date with a changed brand without `overwrite = TRUE`: the base
  font size and code radius in a Typst `_extension.yml` (a stale `fontsize:`
  silently beat the brand's size), and the baked ornament SVGs and
  `_ornaments.html`. Other hand edits to `_extension.yml` are kept.
* `brand_plotly()` now follows the page's light/dark mode inside a Shiny
  render when `mode` is left `NULL`, by reading the background of the output
  it sits on. This is what lets it work in a Quarto dashboard (`server:
  shiny`), whose toggle gives Shiny no input to read. An explicit `mode`
  still wins.
* The `create_brand_quarto_dashboard()` template now shows its ozone scatter
  as an interactive `brand_plotly()` card, which follows the dark-mode toggle.
  The template needs plotly (already in Suggests), and the scaffold reports it
  if it is missing.
* Declared dependencies that were used but not listed: `later` and `utils`
  in Imports, `htmlwidgets` in Suggests.
* The `create_brand_shiny_app()` template now shows its scatter plot a second
  time as an interactive `brand_plotly()` card. The template needs plotly
  (already in Suggests), and the scaffold reports it if it is missing.
* New `create_brand_shiny_steps()` template for a workflow that runs in order:
  numbered pills in the sidebar select the page for each step, with Back /
  Next buttons. It is `brand_page_sidebar()` plus a `navset_pill()` and a
  `navset_hidden()`, so no new page wrapper was needed.

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
