test_presets <- function() {
  list(
    "Wine & Sage" = list(
      primary = "#570a10", secondary = "#ad720a", success = "#325106",
      danger = "#d64550", warning = "#cda029", info = "#5a8cb5",
      light = "#bad9cf", dark = "#1a1c1a"
    ),
    "Slate & Teal" = list(
      primary = "#2c3e50", secondary = "#1abc9c", success = "#27ae60",
      danger = "#e74c3c", warning = "#f39c12", info = "#2980b9",
      light = "#ecf0f1", dark = "#1a252f"
    ),
    "Custom" = NULL
  )
}

test_font_pairs <- function() {
  list(
    "Plus Jakarta Sans / Montserrat" = list(base = "Plus Jakarta Sans", heading = "Montserrat"),
    "Roboto / Bitter" = list(base = "Roboto", heading = "Bitter"),
    "Custom" = NULL
  )
}

test_that("css_length_to_rem parses CSS lengths into rem numbers", {
  expect_equal(css_length_to_rem("1.2rem", 9), 1.2)
  expect_equal(css_length_to_rem("1.5em", 9), 1.5)
  expect_equal(css_length_to_rem("24px", 9), 1.5)
  expect_equal(css_length_to_rem("12pt", 9), 1)
  expect_equal(css_length_to_rem(" 2 rem ", 9), 2)
  expect_equal(css_length_to_rem("2", 9), 2)
  expect_equal(css_length_to_rem(0.75, 9), 0.75)
})

test_that("css_length_to_rem falls back on anything it cannot read", {
  expect_equal(css_length_to_rem(NULL, 9), 9)
  expect_equal(css_length_to_rem("large", 9), 9)
  expect_equal(css_length_to_rem("1.2vh", 9), 9)
  expect_equal(css_length_to_rem("", 9), 9)
})

test_that("match_brand_preset finds a preset exactly, ignoring case", {
  presets <- test_presets()
  expect_equal(match_brand_preset(presets[["Slate & Teal"]], presets), "Slate & Teal")

  shouted <- lapply(presets[["Wine & Sage"]], toupper)
  expect_equal(match_brand_preset(shouted, presets), "Wine & Sage")
})

test_that("match_brand_preset returns Custom when anything differs", {
  presets <- test_presets()
  tweaked <- presets[["Wine & Sage"]]
  tweaked$info <- "#000000"
  expect_equal(match_brand_preset(tweaked, presets), "Custom")
})

test_that("match_font_pair needs both fonts to match", {
  pairs <- test_font_pairs()
  expect_equal(match_font_pair("Roboto", "Bitter", pairs), "Roboto / Bitter")
  expect_equal(match_font_pair("Roboto", "Montserrat", pairs), "Custom")
  expect_equal(match_font_pair("Comic Sans", "Comic Sans", pairs), "Custom")
})

test_that("brand_logo_first_path prefers medium, then small, then large", {
  expect_null(brand_logo_first_path(list()))
  expect_null(brand_logo_first_path(NULL))
  expect_equal(brand_logo_first_path("a.png"), "a.png")
  expect_equal(brand_logo_first_path(list(large = "l.png", small = "s.png")), "s.png")
  expect_equal(brand_logo_first_path(list(medium = "m.png", small = "s.png")), "m.png")
  # Light/dark variants: light wins
  expect_equal(
    brand_logo_first_path(list(medium = list(light = "ml.png", dark = "md.png"))),
    "ml.png"
  )
  expect_null(brand_logo_first_path(list(medium = "")))
})

test_that("resolve_existing_logo only returns files that exist", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "logo.png"))
  expect_equal(
    basename(resolve_existing_logo(dir, list(medium = "logo.png"))),
    "logo.png"
  )
  expect_null(resolve_existing_logo(dir, list(medium = "missing.png")))
  expect_null(resolve_existing_logo(dir, NULL))
})

test_that("existing_brand_yml finds .yml, then .yaml, else NULL", {
  dir <- withr::local_tempdir()
  expect_null(existing_brand_yml(dir))
  file.create(file.path(dir, "_brand.yaml"))
  expect_equal(basename(existing_brand_yml(dir)), "_brand.yaml")
  file.create(file.path(dir, "_brand.yml"))
  expect_equal(basename(existing_brand_yml(dir)), "_brand.yml")
})

test_that("configurator_defaults gives built-in values without a config", {
  d <- configurator_defaults(NULL, test_presets(), test_font_pairs())
  expect_equal(d$preset, "Wine & Sage")
  expect_equal(d$font_pair, "Plus Jakarta Sans / Montserrat")
  expect_equal(d$brand_name, "My Brand")
  expect_true(d$auto_dark)
  expect_equal(d$font_mono, brandkit_mono_default)

  expect_equal(configurator_defaults(list(), test_presets(), test_font_pairs()), d)
})

test_that("configurator_defaults reads a bslib-dialect brand back", {
  cfg <- test_brand_bslib()
  cfg$color <- c(test_presets()[["Slate & Teal"]])
  cfg$typography$base <- list(family = "Roboto", size = "1.25rem", `line-height` = 1.4)
  cfg$typography$headings <- list(family = "Bitter")

  d <- configurator_defaults(cfg, test_presets(), test_font_pairs())
  expect_equal(d$brand_name, "Test Brand")
  expect_equal(d$preset, "Slate & Teal")
  expect_equal(d$font_pair, "Roboto / Bitter")
  expect_equal(d$font_size, 1.25)
  expect_equal(d$line_height, 1.4)
  expect_equal(d$font_mono, "IBM Plex Mono")
  expect_equal(d$border_radius, 0.75)
  expect_true(d$auto_dark)
  expect_named(d$font_defs, c("Inter", "IBM Plex Mono"))
})

test_that("configurator_defaults reads a Quarto-dialect brand back", {
  d <- configurator_defaults(test_brand_quarto(), test_presets(), test_font_pairs())
  # Nested colours resolve to their light value
  expect_equal(d$cols$primary, "#1b2a4a")
  expect_equal(d$border_radius, 0.75)
  expect_true(d$auto_dark)
  expect_equal(d$preset, "Custom")
})

test_that("configurator_defaults seeds light/dark from background/foreground", {
  cfg <- list(color = list(
    primary = "#112233", secondary = "#445566",
    background = "#fafafa", foreground = "#050505"
  ))
  d <- configurator_defaults(cfg, test_presets(), test_font_pairs())
  expect_equal(d$cols$light, "#fafafa")
  expect_equal(d$cols$dark, "#050505")
  expect_false(d$auto_dark)
})
