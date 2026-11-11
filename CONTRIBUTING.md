# Working on brandkit

Notes for anyone changing the package: how the code is laid out, the
decisions behind the less obvious parts, and how to check a change. User
documentation lives in the vignettes (`vignettes/`); this file is the
"why" behind them.

## Checking a change

```r
devtools::document()   # man pages and NAMESPACE
devtools::test()       # about 160 tests; none needs a network or Quarto
devtools::check()      # R CMD check
```

Two things to know when running them:

- The repo's `.Rprofile` activates renv. CI turns that off
  (`RENV_CONFIG_AUTOLOADER_ENABLED=false`); do the same if your library is
  set up outside renv.
- Building the vignettes needs pandoc. Their code is not evaluated, so they
  need no network, Quarto or fonts.

Rendering the templates is not covered by the tests (they check what is
copied, and what is generated, not the result of `quarto render`). After
changing a template or the Typst extension, scaffold into a temp directory and
render it. `quarto render` for HTML/PDF, `quarto serve` for the dashboard, and
`shiny::runApp()` for the Shiny templates. Quarto is not on `PATH` when it only
ships with RStudio.

## Layout

```
R/
  brand_cache.R       _brand.yml parsing, the cache (brand_env), accessors, logo tag
  brand_colors.R      palettes: discrete, sequential, diverging
  brand_fonts.R       font registration (sysfonts/showtext) and the Google font faces
  brand_ggplot.R      theme_brand() and the scale_*_brand_*() functions
  brand_plotly.R      brand_plotly()
  brand_theme.R       bslib theme, dark-mode CSS, brand_dark_mode()
  brand_pages.R       the brand_page_*() wrappers, thematic activation, output-mode detection
  brand_ornaments.R   corner ornaments: the SVG generator, the label, the web tag
  brand_adaptive.R    light/dark twin figures for HTML pages (adaptive = TRUE)
  brand_quarto.R      brand_quarto_setup(), the create_brand_quarto_*() scaffolds, the Quarto _brand.yml writer
  brand_typst.R       the Typst extension: _extension.yml, unit conversions, poster type scale
  brand_shiny.R       the create_brand_shiny_*() scaffolds, the bslib _brand.yml writer
  brand_scaffold.R    what the scaffolds share: project directory, template and asset copying, logo/colour helpers
  brand_configure.R   configure_brand(): the configurator app and what it reads back
  utils.R, zzz.R      small helpers; load/attach hooks
inst/
  _brand.yml          the default brand, used when none is found
  css/                overrides.css (see below) and drift.css (the opt-in drift page style)
  adaptive/           adaptive.js + adaptive.css
  shiny/              one app template per create_brand_shiny_*()
  quarto/             one example .qmd per scaffold, drift.scss, and typst/_extensions/brandkit/
examples/             apps used for conformity testing (not shipped)
vignettes/            user documentation
```

## State and load behaviour

`brand_env` caches the parsed `_brand.yml`. It is filled when the package
loads from the first file found walking up from the working directory (else the
bundled default), and it is not refreshed when the working directory changes.
Scaffolds call `ensure_cache_for_path()` so they read the project they're
writing into rather than a stale cache; accessors don't.

Attaching the package sets the global ggplot2 theme and discrete-colour
options. Loading it registers fonts, which downloads Google fonts the first
time; `options(brandkit.register_fonts = FALSE)` skips that.

## The two `_brand.yml` dialects

bslib and Quarto read the same filename but reject each other's form of dark
colours (`color-dark:` versus nested `light:` / `dark:`), and Quarto also
rejects bslib's `theme:` key. Both errors come from the other tool's
validation, not R, which is why conversion happens at scaffold time and the
configurator can write either. Bootstrap variables go under
`defaults: bootstrap: defaults:`, the one place both honour; `theme:` is read
by brandkit itself but silently ignored by `bslib::bs_theme(brand = )`.
brandkit's own reader (`brand_init()`) accepts both shapes.

## CSS layers

| Layer | Where | What it is |
|---|---|---|
| Brand theme | `brand_theme()` | bslib's theme from the brand file |
| Dark custom properties and buttons | `build_dark_custom_props()` | `--bs-*` under `[data-bs-theme="dark"]` |
| Dark widget rules | `build_widget_overrides()` | ionRangeSlider, checkboxes, radios, switches, selectize, DataTables pagination, compiled into the theme |
| Static polish | `inst/css/overrides.css` | light-mode refinements (transitions, scrollbars, cards, inputs, nav) and leaflet dark-mode rules |
| Datepicker | `brand_dark_css()` | the one widget that loads its own stylesheet outside bslib |
| Drift (Shiny) | `inst/css/drift.css` via `drift_head()` | scoped to `html.bk-drift`, with `--bk-card` written per mode |
| Drift (Quarto) | `inst/quarto/drift.scss` | shared, document, slide and dashboard sections |
| Adaptive | `inst/adaptive/` | swaps light/dark figures and widgets |

The dark rules exist because Bootstrap compiles some colours at build time and
never updates them when `data-bs-theme` changes; they are the part the official
bslib / brand.yml pipeline doesn't provide.

## Why the drift style is built the way it is

- **Everything is scoped to `html.bk-drift`**, which a script in `<head>` adds
  before first paint, so a classic page is untouched and there's no flash.
- **The card colour is a plain opaque `rgb()` computed in R** (the brand's
  primary mixed 7% into the background, once per mode), not `color-mix()` or an
  alpha. It must be opaque so the ornaments behind the page don't show through,
  and it must be a plain colour because thematic reads it off the card to give
  each plot a matching background.
- **Cards have no transitions.** `overrides.css` animates every card property,
  and on a light/dark switch that fades the colour over a third of a second;
  Shiny reads the card colour for thematic mid-fade, so plots would be redrawn
  on a muddy in-between grey that is never corrected.
- **The sidebar is transparent**, because it runs the full height of the
  window, which is where the bottom-left ornament lives.
- **The navbar loses its bar and the rule bslib draws under it**, since
  anything opaque in front of the fixed ornaments hides them.

## Fonts and Typst

Typst synthesises neither bold nor oblique, and reads only a variable font's
default instance. Quarto fetches brand Google fonts by building a Fonts v1 CSS
URL, and an entry with no `style` or `weight` yields one face (upright 400). So
`with_google_font_faces()` requests normal and italic, and weights 400, 700 and
any the brand assigns, in a single request (a style-only request is a hard 400
for a family without italic, which Quarto never checks). Known gap: bold italic
is unreachable, since Google's API expresses it only as `400italic,700italic`,
which Quarto's schema rejects.

The configurator only offers families that clear three checks:

1. **A bold and an italic face**, because of the above.
2. **A name that matches what Typst downloads.** Families with an optical-size
   axis are served as `<Family> <n>pt` and never match the requested name.
3. **For the base font, an x-height close to the code face's** (IBM Plex Mono,
   0.5160 em), because point size is not what the eye reads as size. Every base
   font is within 3.7%, except Jost at 12.2%, kept because it's in use; no
   monospace face fixes it without breaking the others. Heading fonts are
   exempt, as they never sit inline with code.

`copy_typst_extension()` installs the same partials for every PDF variant; they
differ only in the generated `_extension.yml` (`banner-inset`, `drift`, and for
the poster `poster`). Keep one copy of the templates: a fix to the banner or code
styling must reach every format.

Other points in the extension:

- `fontsize` is resolved to an absolute `pt` in `_extension.yml`, because a
  relative `em` from Quarto's rem conversion compounds when reused for code
  sizing.
- Pandoc gives inline code and fenced blocks the same `raw` element, so
  `inline-code.lua` sets inline code as plain text, and `typst-show.typ` wraps
  skylighting's block to set its fill and radius.
- A `_extension.yml` key written as `false` still reads as present to pandoc's
  `$if()$`, so `banner-inset` and `drift` are written only when true.

## The poster's type scale

Scaling type with the sheet is wrong twice over: A0 is four times A4 in linear
size, and a 14.4 pt base times four is a 58 pt slide, but reading distance
doesn't grow with the sheet either. So the size comes from the column it has to
fill: a line wants about 70 characters at about 0.37 em each, so body size is
the column width over that. A floor from viewing distance sits under it, 24 pt on
A0 and falling with the square root of the sheet's linear scale, because the
measure alone would set a four-column A1 poster in 18 pt. The result is a
multiple of the brand's base size (clamped to 1 to 4), which the masthead,
banner clearance and logo scale by too. `margin` and `gutter` are duplicated
between `brand_typst.R` and `page.typ`; change them together.

## Ornaments

One geometry per motif in a 100 x 100 box anchored at the top-right. The
bottom-left corner is the same drawing rotated 180 degrees with the lead and
partner colours swapped. Each shape is a full brand colour at a low opacity, so
shades come from overlaps and one `softness` controls everything. With
`vars = TRUE` the fills name Bootstrap's CSS variables (the hex values are
fallbacks), which is what lets an inline SVG follow a toggle with no redraw.

The label is text set along the swell's own curve, centred on the point nearest
the largest orb, on the side away from the wave. Browsers lay out text on a
path with the font's real metrics (`layout = "path"`); Typst's SVG renderer
spaces the letters of such a line unevenly, so the files Typst draws place each
letter as a rotated `<text>` (`layout = "glyphs"`). The bottom-left label can't
ride along inside the corner's rotation (it would be upside down), so it is laid
out on the rotated curve, run the other way, with the baseline offset to the
other side. The label's text and corner live under `meta:` because Quarto
accepts extra keys there and rejects new top-level ones.

## Adding a template

A scaffold is `scaffold_dir()`, the `_brand.yml` writer for its dialect,
`copy_template()` for each file, and `copy_brand_assets()`. Put the example in
`inst/`, give it a test in `test-scaffold-*.R`, mention it in the vignette and
the README's table, and note it in `NEWS.md`.
