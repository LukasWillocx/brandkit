# --------------------------------------------------------------------------
# brandkit: brand_theme.R
# Builds bslib themes and injects CSS overrides for everything BS5 misses.
# --------------------------------------------------------------------------

#' Create a Branded bslib Theme
#'
#' Generates a Bootstrap 5 theme from the cached `_brand.yml` with
#' optional dark-mode Sass overrides and extended CSS for widgets
#' that Bootstrap doesn't reach (sliders, datepickers, selectize, etc).
#'
#' @param mode `"light"` (default) or `"dark"`.
#' @param custom_css Character vector of additional CSS rules to append.
#'
#' @return A `bslib::bs_theme()` object.
#' @export
brand_theme <- function(mode = c("light", "dark"), custom_css = NULL) {
  ensure_cache()
  mode <- match.arg(mode)

  # --- Base theme from _brand.yml via bslib's native brand support ---
  theme <- bslib::bs_theme(version = 5, brand = brand_env$path)

  # --- Dark mode: override Sass variables for full recompile ---
  if (mode == "dark") {
    dk <- brand_env$colors_dark
    if (is.null(dk)) {
      warning("No 'color-dark' section in _brand.yml. Returning light theme.")
    } else {
      theme <- bslib::bs_add_variables(
        theme,
        "primary"   = dk$primary,
        "secondary" = dk$secondary,
        "success"   = dk$success   %||% brand_env$colors$success,
        "danger"    = dk$danger    %||% brand_env$colors$danger,
        "warning"   = dk$warning   %||% brand_env$colors$warning,
        "info"      = dk$info      %||% brand_env$colors$info,
        "light"     = dk$light     %||% brand_env$colors$light,
        "dark"      = dk$dark      %||% brand_env$colors$dark,
        "body-bg"   = dk$background %||% dk$light,
        "body-color" = dk$foreground %||% dk$dark,
        .where = "declarations"
      )
    }
  }

  # --- Dark-mode CSS custom property layer ---
  # Ensures var(--bs-primary) etc. resolve correctly under
  # [data-bs-theme="dark"] for custom.css rules
  dk <- brand_env$colors_dark
  if (!is.null(dk)) {
    theme <- bslib::bs_add_rules(theme, build_dark_custom_props(dk))
  }

  # --- Extended widget overrides (the stuff BS5 misses) ---
  override_css <- build_widget_overrides()
  if (nzchar(override_css)) {
    theme <- bslib::bs_add_rules(theme, override_css)
  }

  # --- User-supplied custom CSS ---
  if (!is.null(custom_css)) {
    theme <- bslib::bs_add_rules(theme, paste(custom_css, collapse = "\n"))
  }

  # --- Static overrides from inst/css/overrides.css ---
  css_path <- system.file("css/overrides.css", package = "brandkit")
  if (nzchar(css_path)) {
    theme <- bslib::bs_add_rules(theme, readLines(css_path, warn = FALSE))
  }

  attr(theme, "brandkit_mode") <- mode
  theme
}


# --------------------------------------------------------------------------
# Dark-mode CSS custom properties
# --------------------------------------------------------------------------

build_dark_custom_props <- function(dk) {
  # Map each semantic colour to both --bs-{name} and --bs-{name}-rgb
  names_map <- c(
    "primary", "secondary", "success", "danger",
    "warning", "info", "light", "dark"
  )

  props <- vapply(names_map, function(nm) {
    hex <- dk[[nm]]
    if (is.null(hex)) return("")
    paste0(
      "  --bs-", nm, ": ", hex, ";\n",
      "  --bs-", nm, "-rgb: ", hex_to_rgb_str(hex), ";"
    )
  }, character(1))

  # Body colours
  body_props <- paste0(
    "  --bs-body-bg: ",    dk$background %||% dk$light, ";\n",
    "  --bs-body-color: ", dk$foreground %||% dk$dark,  ";\n",
    "  --bs-body-bg-rgb: ",    hex_to_rgb_str(dk$background %||% dk$light), ";\n",
    "  --bs-body-color-rgb: ", hex_to_rgb_str(dk$foreground %||% dk$dark),  ";"
  )

  # Button overrides for primary + secondary
  btn_css <- build_dark_button_css(dk)

  paste0(
    '[data-bs-theme="dark"] {\n',
    paste(props[nzchar(props)], collapse = "\n"),
    "\n", body_props, "\n}\n",
    btn_css
  )
}

build_dark_button_css <- function(dk) {
  btns <- c("primary", "secondary", "success", "danger", "warning", "info")
  parts <- vapply(btns, function(nm) {
    hex <- dk[[nm]]
    if (is.null(hex)) return("")
    paste0(
      '[data-bs-theme="dark"] .btn-', nm, ' {\n',
      '  --bs-btn-bg: ', hex, ';\n',
      '  --bs-btn-border-color: ', hex, ';\n',
      '  --bs-btn-hover-bg: color-mix(in srgb, ', hex, ' 85%, black);\n',
      '  --bs-btn-hover-border-color: color-mix(in srgb, ', hex, ' 80%, black);\n',
      '  --bs-btn-active-bg: color-mix(in srgb, ', hex, ' 75%, black);\n',
      '  --bs-btn-active-border-color: color-mix(in srgb, ', hex, ' 70%, black);\n',
      '}\n'
    )
  }, character(1))
  paste(parts[nzchar(parts)], collapse = "\n")
}


# --------------------------------------------------------------------------
# Extended widget overrides — what BS5 compiles at build time and never
# updates when dark mode toggles.
# --------------------------------------------------------------------------

build_widget_overrides <- function() {
  dk <- brand_env$colors_dark
  if (is.null(dk)) return("")

  rgb_primary <- hex_to_rgb_str(dk$primary)

  paste0('
/* === brandkit: widget overrides for dark mode === */

/* --- ionRangeSlider --- */
[data-bs-theme="dark"] .irs--shiny .irs-handle,
[data-bs-theme="dark"] .irs--shiny .irs-bar,
[data-bs-theme="dark"] .irs--shiny .irs-from,
[data-bs-theme="dark"] .irs--shiny .irs-to,
[data-bs-theme="dark"] .irs--shiny .irs-single {
  background-color: ', dk$primary, ' !important;
}
[data-bs-theme="dark"] .irs--shiny .irs-bar {
  border-color: ', dk$primary, ' !important;
}
[data-bs-theme="dark"] .irs--shiny .irs-line {
  background-color: color-mix(in srgb, ', dk$primary, ' 20%, ', dk$background, ' 80%) !important;
}

/* --- Checkboxes & radios (Shiny containers) --- */
[data-bs-theme="dark"] .form-check-input:checked,
[data-bs-theme="dark"] .shiny-input-container .checkbox input:checked,
[data-bs-theme="dark"] .shiny-input-container .checkbox-inline input:checked,
[data-bs-theme="dark"] .shiny-input-container .radio input:checked,
[data-bs-theme="dark"] .shiny-input-container .radio-inline input:checked {
  background-color: ', dk$primary, ' !important;
  border-color: ', dk$primary, ' !important;
  accent-color: ', dk$primary, ' !important;
}

/* Checkbox tick SVG */
[data-bs-theme="dark"] .form-check-input:checked[type="checkbox"] {
  background-image: url("data:image/svg+xml,%3csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 20 20\'%3e%3cpath fill=\'none\' stroke=\'%23fff\' stroke-linecap=\'round\' stroke-linejoin=\'round\' stroke-width=\'3\' d=\'m6 10 3 3 6-6\'/%3e%3c/svg%3e") !important;
}

/* Radio dot SVG */
[data-bs-theme="dark"] .form-check-input:checked[type="radio"] {
  background-image: url("data:image/svg+xml,%3csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'-4 -4 8 8\'%3e%3ccircle r=\'2\' fill=\'%23fff\'/%3e%3c/svg%3e") !important;
}

/* --- Focus rings --- */
[data-bs-theme="dark"] .form-check-input:focus,
[data-bs-theme="dark"] .shiny-input-container .checkbox input:focus,
[data-bs-theme="dark"] .shiny-input-container .radio input:focus,
[data-bs-theme="dark"] .form-control:focus,
[data-bs-theme="dark"] .form-select:focus {
  border-color: ', dk$primary, ' !important;
  box-shadow: 0 0 0 0.25rem rgba(', rgb_primary, ', 0.25) !important;
}

/* --- Switches --- */
[data-bs-theme="dark"] .form-switch .form-check-input:checked {
  background-color: ', dk$primary, ' !important;
  border-color: ', dk$primary, ' !important;
}

/* --- Selectize --- */
[data-bs-theme="dark"] .selectize-input.focus {
  border-color: ', dk$primary, ' !important;
  box-shadow: 0 0 0 0.25rem rgba(', rgb_primary, ', 0.25) !important;
}
[data-bs-theme="dark"] .selectize-dropdown .active,
[data-bs-theme="dark"] .selectize-dropdown .selected,
[data-bs-theme="dark"] .selectize-dropdown .option.active {
  background-color: ', dk$primary, ' !important;
  color: ', dk$background, ' !important;
}

/* --- DataTables pagination --- */
[data-bs-theme="dark"] .page-item.active .page-link {
  background-color: ', dk$primary, ' !important;
  border-color: ', dk$primary, ' !important;
}

/* --- Accent colour fallback --- */
[data-bs-theme="dark"] input {
  accent-color: ', dk$primary, ' !important;
}
')
}


# --------------------------------------------------------------------------
# Dark mode Shiny helper — generates <style> tag for datepicker / Shiny
# containers that load CSS independently of bslib.
# --------------------------------------------------------------------------

#' Dark Mode CSS for Third-Party Widgets
#'
#' Returns a `tags$head(tags$style(...))` block for widgets that load their
#' own stylesheets outside bslib (datepicker, Shiny checkbox/radio
#' containers). Place in your UI alongside `brand_theme()`.
#'
#' @return An `htmltools::tags$head()` element.
#' @export
brand_dark_css <- function() {
  ensure_cache()
  dk <- brand_env$colors_dark
  if (is.null(dk)) return(htmltools::tags$head())

  rgb_primary <- hex_to_rgb_str(dk$primary)

  css <- paste0('
/* brandkit: datepicker dark mode overrides */
html[data-bs-theme="dark"] .datepicker table tr td.active,
html[data-bs-theme="dark"] .datepicker table tr td.active:hover,
html[data-bs-theme="dark"] .datepicker table tr td.active:focus,
html[data-bs-theme="dark"] .datepicker table tr td span.active,
html[data-bs-theme="dark"] .datepicker table tr td span.active:hover {
  background-color: ', dk$primary, ' !important;
  border-color: ', dk$primary, ' !important;
  background-image: none !important;
  color: ', dk$background, ' !important;
}
html[data-bs-theme="dark"] .datepicker table tr td.today,
html[data-bs-theme="dark"] .datepicker table tr td.today:hover {
  background-color: color-mix(in srgb, ', dk$primary, ' 30%, ', dk$background, ' 70%) !important;
  background-image: none !important;
}
html[data-bs-theme="dark"] .shiny-input-container .checkbox input:checked,
html[data-bs-theme="dark"] .shiny-input-container .radio input:checked {
  background-color: ', dk$primary, ' !important;
  border-color: ', dk$primary, ' !important;
}
html[data-bs-theme="dark"] .shiny-input-container .checkbox input:focus,
html[data-bs-theme="dark"] .shiny-input-container .radio input:focus {
  border-color: ', dk$primary, ' !important;
  box-shadow: 0 0 0 0.25rem rgba(', rgb_primary, ', 0.25) !important;
}
')

  htmltools::tags$head(htmltools::tags$style(htmltools::HTML(css)))
}


# --------------------------------------------------------------------------
# Dark mode reactive toggle (Shiny)
# --------------------------------------------------------------------------

#' Enable Dark Mode Toggling in Shiny
#'
#' Call once in your server function. Returns reactive `mode()` and
#' `theme()` that track `bslib::input_dark_mode()`.
#'
#' @param input Shiny `input` object.
#' @param session Shiny `session` object (kept for API compat).
#' @param input_id ID of the `input_dark_mode()` widget. Default `"dark_mode"`.
#'
#' @return List with reactive `mode` (`"light"` / `"dark"`) and `theme`.
#' @export
brand_dark_mode <- function(input, session = NULL, input_id = "dark_mode") {
  light <- brand_theme("light")
  dark_cache <- NULL

  current_mode <- shiny::reactive({
    if (identical(input[[input_id]], "dark")) "dark" else "light"
  })

  current_theme <- shiny::reactive({
    if (current_mode() == "dark") {
      if (is.null(dark_cache)) dark_cache <<- brand_theme("dark")
      dark_cache
    } else {
      light
    }
  })

  list(mode = current_mode, theme = current_theme)
}
