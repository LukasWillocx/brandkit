# --------------------------------------------------------------------------
# brandkit: brand_pages.R
# Zero-boilerplate page constructors for Shiny.
# Bundles: brand_theme() + dark_css + dark_mode toggle + thematic.
# --------------------------------------------------------------------------

#' Branded Page with Sidebar
#'
#' Drop-in replacement for `bslib::page_sidebar()` that auto-injects
#' the brand theme, dark-mode CSS overrides, a dark-mode toggle, logo,
#' and thematic plot integration. The user writes zero theming code.
#'
#' @param ... UI elements passed to the main content area.
#' @param title App title (character or UI element).
#' @param sidebar A `bslib::sidebar()` object.
#' @param logo Logical. Prepend the brand logo to the title? Default `TRUE`.
#' @param dark_mode Logical. Include a dark-mode toggle? Default `TRUE`.
#' @param dark_mode_id ID for the toggle widget. Default `"dark_mode"`.
#' @param fillable Passed to `bslib::page_sidebar()`.
#' @param theme_args Named list of extra args passed to `brand_theme()`.
#' @param style `"classic"` (default) or `"drift"`. `"drift"` is the
#'   poster template's look carried into the browser: soft geometric
#'   ornaments in the top-right and bottom-left corners of the window
#'   (see [brand_ornaments_tag()]), the title as plain type instead of a
#'   bar, and cards and the sidebar as tinted surfaces with a solid header
#'   rather than shadowed boxes. Plots, which thematic draws on whatever
#'   they sit on, take the card's colour. It follows the dark-mode toggle
#'   live. `"classic"` leaves the page exactly as it was before this
#'   argument existed.
#'
#' @return A Shiny UI definition.
#' @export
brand_page_sidebar <- function(...,
                               title = NULL,
                               sidebar = NULL,
                               logo = TRUE,
                               dark_mode = TRUE,
                               dark_mode_id = "dark_mode",
                               fillable = TRUE,
                               theme_args = list(),
                               style = c("classic", "drift")) {

  style <- match.arg(style)
  setup <- build_page_setup(dark_mode, dark_mode_id, theme_args, style)
  title <- build_branded_title(title, logo)

  bslib::page_sidebar(
    theme    = setup$theme,
    title    = title,
    sidebar  = sidebar,
    fillable = fillable,
    setup$head_tags,
    setup$toggle,
    setup$ornaments,
    ...,
    setup$thematic_script
  )
}


#' Branded Navbar Page
#'
#' Drop-in replacement for `bslib::page_navbar()`. Same auto-injection
#' as `brand_page_sidebar()`.
#'
#' @param ... `bslib::nav_panel()` elements.
#' @param title App title.
#' @param logo Logical. Prepend the brand logo to the title? Default `TRUE`.
#' @param dark_mode Include a dark-mode toggle in the navbar? Default `TRUE`.
#' @param dark_mode_id ID for the toggle widget.
#' @param theme_args Extra args passed to `brand_theme()`.
#'
#' @return A Shiny UI definition.
#' @export
brand_page_navbar <- function(...,
                              title = NULL,
                              logo = TRUE,
                              dark_mode = TRUE,
                              dark_mode_id = "dark_mode",
                              theme_args = list()) {

  setup <- build_page_setup(dark_mode, dark_mode_id, theme_args)
  title <- build_branded_title(title, logo)

  # page_navbar only accepts nav_panel items in ..., so inject
  # head tags and toggle via the header parameter.
  bslib::page_navbar(
    theme  = setup$theme,
    title  = title,
    header = htmltools::tagList(setup$head_tags, setup$toggle),
    ...,
  )
}


#' Branded Fluid Page
#'
#' Drop-in replacement for `bslib::page_fluid()`.
#'
#' @param ... UI elements.
#' @param title Page title.
#' @param logo Logical. Prepend the brand logo to the title? Default `TRUE`.
#' @param dark_mode Include a dark-mode toggle? Default `TRUE`.
#' @param dark_mode_id ID for the toggle widget.
#' @param theme_args Extra args passed to `brand_theme()`.
#'
#' @return A Shiny UI definition.
#' @export
brand_page_fluid <- function(...,
                             title = NULL,
                             logo = TRUE,
                             dark_mode = TRUE,
                             dark_mode_id = "dark_mode",
                             theme_args = list()) {

  setup <- build_page_setup(dark_mode, dark_mode_id, theme_args)
  title <- build_branded_title(title, logo)

  bslib::page_fluid(
    theme = setup$theme,
    title = title,
    setup$head_tags,
    setup$toggle,
    ...,
    setup$thematic_script
  )
}


# --------------------------------------------------------------------------
# Internal: branded title with logo
# --------------------------------------------------------------------------

build_branded_title <- function(title, logo) {
  if (!isTRUE(logo) || is.null(title)) return(title)

  logo_tag <- brand_logo_tag(height = "1.8em")
  if (is.null(logo_tag)) return(title)

  htmltools::tagList(
    htmltools::div(
      style = "display: flex; align-items: center;",
      logo_tag,
      htmltools::span(title)
    )
  )
}


# --------------------------------------------------------------------------
# Internal: shared page setup logic
# --------------------------------------------------------------------------

build_page_setup <- function(dark_mode, dark_mode_id, theme_args,
                             style = "classic") {

  ensure_cache()

  # Build theme
  theme <- do.call(brand_theme, theme_args)

  # Head tags: dark-mode widget CSS overrides + plot settle script
  head_tags <- htmltools::tagList(
    brand_dark_css(),
    plot_settle_script()
  )

  # The drift style adds its stylesheet and the corner ornaments; the
  # classic one adds nothing, which is what keeps it byte-for-byte what
  # existing apps already get.
  ornaments <- NULL
  if (identical(style, "drift")) {
    head_tags <- htmltools::tagList(head_tags, drift_head())
    ornaments <- brand_ornaments_tag()
  }

  # Activate thematic as a side effect during UI construction.
  # thematic_shiny() must run before the app starts, which is exactly
  # when page_*() functions evaluate. This gives every renderPlot()
  # automatic brand colours, fonts, and transparent backgrounds.
  # We pass the brand discrete palette as qualitative so thematic
  # uses our colours instead of its own defaults.
  thematic_script <- NULL
  activate_thematic_shiny()

  # Dark mode toggle — fixed top-right corner
  toggle <- if (dark_mode) {
    htmltools::div(
      style = "position: fixed; top: 12px; right: 16px; z-index: 1050;",
      bslib::input_dark_mode(id = dark_mode_id)
    )
  }

  list(
    theme           = theme,
    head_tags       = head_tags,
    toggle          = toggle,
    ornaments       = ornaments,
    thematic_script = thematic_script
  )
}

# --------------------------------------------------------------------------
# Internal: switch on thematic for every renderPlot() in the app or document
#
# Shared by the Shiny page wrappers and brand_quarto_setup(shiny = TRUE),
# which are the two places a Shiny app gets built from brandkit.
# --------------------------------------------------------------------------

activate_thematic_shiny <- function(mode = "light") {
  if (!requireNamespace("thematic", quietly = TRUE)) return(invisible(FALSE))

  tryCatch({
    # A fallback for the moments when no plot is being drawn for a browser:
    # rendering a Quarto document runs a knitr hook that asks thematic for
    # the background, and with nothing to read it warns. Shiny's own output
    # info outranks this, so it only ever applies outside renderPlot().
    cols <- brand_colors(mode)
    thematic::auto_config_set(thematic::auto_config(
      bg = cols$background, fg = cols$foreground, accent = cols$primary
    ))
    # qualitative = NA: thematic would otherwise force one fixed palette
    # onto every discrete scale, and the brand's light palette (a navy
    # first colour) vanishes on a dark card. The ggplot2 scale options set
    # below choose the palette per plot instead.
    thematic::thematic_shiny(font = brand_fonts()$base, qualitative = NA)
    options(
      ggplot2.discrete.colour = output_discrete_scale("colour"),
      ggplot2.discrete.fill   = output_discrete_scale("fill")
    )
    # thematic matches each plot's background to its container by
    # remapping the fills in the ggplot theme, so the app-wide theme
    # needs fills to remap. The one set when brandkit attaches is
    # unfilled (it is built outside Shiny, where transparent is right),
    # and with it a light/dark switch leaves some plots on the old
    # mode's background. See theme_brand().
    ggplot2::theme_set(theme_brand(mode = mode, transparent = FALSE))
    invisible(TRUE)
  }, error = function(e) invisible(FALSE))
}

# --------------------------------------------------------------------------
# Internal: discrete colour/fill scales that follow the page's colour mode
#
# ggplot2 accepts a function as the default discrete scale, and calls it
# when a plot is built — inside renderPlot(), where Shiny can say what
# background the plot is going on. A dark one gets the brand's dark palette,
# anything else the light one. Reading the background is reactive, so a
# light/dark switch redraws the plot with the other palette, exactly as it
# already does for the text and background colours.
# --------------------------------------------------------------------------

output_discrete_scale <- function(aesthetic) {
  maker <- switch(aesthetic,
    colour = ggplot2::scale_colour_manual,
    fill   = ggplot2::scale_fill_manual
  )
  function(...) maker(..., values = brand_pal_discrete(mode = output_mode()))
}

output_mode <- function() {
  bg <- tryCatch({
    bg <- shiny::getCurrentOutputInfo()$bg
    if (is.function(bg)) bg() else bg
  }, error = function(e) NULL)
  if (is.null(bg) || is.na(bg) || !nzchar(bg)) return("light")

  rgb <- tryCatch(
    grDevices::col2rgb(htmltools::parseCssColors(bg)),
    error = function(e) NULL
  )
  if (is.null(rgb)) return("light")

  # Relative luminance, close enough: this only has to tell a dark card
  # from a light one.
  lum <- sum(c(0.2126, 0.7152, 0.0722) * rgb[, 1]) / 255
  if (lum < 0.5) "dark" else "light"
}

# --------------------------------------------------------------------------
# Internal: the drift style's head content
#
# A script that marks <html> (so every rule in drift.css, scoped to
# html.bk-drift, only applies on a page that asked for it, and does so
# before first paint rather than after a flash of the classic page), and the
# stylesheet with its two per-mode card colours written in front.
# --------------------------------------------------------------------------

drift_head <- function() {
  light <- brand_colors("light")
  dark  <- brand_colors("dark")

  vars <- sprintf(
    paste0("html.bk-drift { --bk-card: %s; }
",
           "html.bk-drift[data-bs-theme=\"dark\"] { --bk-card: %s; }
"),
    orn_mix(light$primary, light$background, 0.07),
    orn_mix(dark$primary,  dark$background,  0.07)
  )

  css_path <- system.file("css/drift.css", package = "brandkit")
  css <- if (nzchar(css_path)) paste(readLines(css_path, warn = FALSE), collapse = "
") else ""

  htmltools::tags$head(
    htmltools::tags$script(htmltools::HTML(
      'document.documentElement.classList.add("bk-drift");'
    )),
    htmltools::tags$style(htmltools::HTML(paste0(vars, css)))
  )
}

# JS: hide plots only during initial page load. Once each plot's first
# render settles at the correct container size, remove the loading class
# permanently. All subsequent renders (dark mode, input changes) are instant.
plot_settle_script <- function() {
  htmltools::tags$head(htmltools::tags$script(htmltools::HTML('
(function() {
  var ro = new ResizeObserver(function(entries) {
    entries.forEach(function(entry) {
      var el = entry.target;
      if (!el.classList.contains("brandkit-loading")) return;
      clearTimeout(el._bkTimer);
      el._bkTimer = setTimeout(function() {
        el.classList.remove("brandkit-loading");
        ro.unobserve(el);
      }, 300);
    });
  });

  $(document).on("shiny:value", function(e) {
    var el = e.target;
    if (!$(el).hasClass("shiny-plot-output")) return;
    if (!el._bkFirst) {
      el._bkFirst = true;
      el.classList.add("brandkit-loading");
      ro.observe(el);
      clearTimeout(el._bkTimer);
      el._bkTimer = setTimeout(function() {
        el.classList.remove("brandkit-loading");
        ro.unobserve(el);
      }, 300);
    }
  });
})();
')))
}



# --------------------------------------------------------------------------
# Thematic server-side activation
# --------------------------------------------------------------------------

#' Activate Thematic for Branded Plots
#'
#' Call once at the top of your server function (or not at all — the
#' `brand_page_*()` wrappers handle this automatically if you use the
#' `brand_server()` helper). Sets up `thematic::thematic_shiny()` so
#' all `renderPlot()` outputs inherit brand colours and fonts with
#' transparent backgrounds that match dark/light mode.
#'
#' @param font Font family to use for plots. Default reads from brand cache.
#'
#' @return Invisible `NULL`. Called for side effect.
#' @export
brand_activate_thematic <- function(font = NULL) {
  if (!requireNamespace("thematic", quietly = TRUE)) {
    message("Install the 'thematic' package for automatic plot theming.")
    return(invisible(NULL))
  }

  font <- font %||% brand_fonts()$base
  pal  <- brand_pal_discrete()
  thematic::thematic_shiny(font = font, qualitative = pal)
  invisible(NULL)
}
