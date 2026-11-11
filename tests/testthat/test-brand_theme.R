test_that("brand_theme returns a bslib theme tagged with its mode", {
  local_brand()
  light <- brand_theme()
  expect_s3_class(light, "bs_theme")
  expect_equal(attr(light, "brandkit_mode"), "light")
  expect_equal(attr(brand_theme("dark"), "brandkit_mode"), "dark")
  expect_error(brand_theme("sepia"), "should be one of")
})

test_that("a dark theme from a brand with no dark colours warns and stays light", {
  cfg <- test_brand_bslib()
  cfg[["color-dark"]] <- NULL
  local_brand(cfg)
  expect_warning(brand_theme("dark"), "color-dark")
})

test_that("custom_css is accepted", {
  local_brand()
  expect_s3_class(brand_theme(custom_css = c(".a { color: red; }", ".b { color: blue; }")),
                  "bs_theme")
})

test_that("build_dark_custom_props writes each dark colour and its rgb triple", {
  dk <- list(primary = "#6b86c4", secondary = "#d9b27f",
             background = "#10131a", foreground = "#e8eaee")
  css <- build_dark_custom_props(dk)

  expect_match(css, '[data-bs-theme="dark"] {', fixed = TRUE)
  expect_match(css, "--bs-primary: #6b86c4;", fixed = TRUE)
  expect_match(css, "--bs-primary-rgb: 107, 134, 196;", fixed = TRUE)
  expect_match(css, "--bs-body-bg: #10131a;", fixed = TRUE)
  expect_match(css, "--bs-body-color-rgb: 232, 234, 238;", fixed = TRUE)
  # Colours the brand does not define are not written.
  expect_no_match(css, "--bs-danger", fixed = TRUE)
})

test_that("build_dark_button_css covers only the colours present", {
  css <- build_dark_button_css(list(primary = "#6b86c4", danger = "#ff0000"))
  expect_match(css, ".btn-primary", fixed = TRUE)
  expect_match(css, ".btn-danger", fixed = TRUE)
  expect_no_match(css, ".btn-info", fixed = TRUE)
  expect_match(css, "color-mix(in srgb, #6b86c4 85%, black)", fixed = TRUE)
})

test_that("widget overrides need dark colours and use the dark primary", {
  cfg <- test_brand_bslib()
  cfg[["color-dark"]] <- NULL
  local_brand(cfg)
  expect_identical(build_widget_overrides(), "")

  local_brand()
  css <- build_widget_overrides()
  expect_match(css, ".irs--shiny .irs-handle", fixed = TRUE)
  expect_match(css, ".form-check-input:checked", fixed = TRUE)
  expect_match(css, "background-color: #6b86c4 !important", fixed = TRUE)
})

test_that("brand_dark_css is the datepicker only, and empty without dark colours", {
  local_brand()
  css <- head_html(brand_dark_css())
  expect_match(css, ".datepicker", fixed = TRUE)
  expect_match(css, "#6b86c4", fixed = TRUE)
  # Checkboxes and radios are compiled into the theme, not repeated here.
  expect_no_match(css, ".shiny-input-container", fixed = TRUE)

  cfg <- test_brand_bslib()
  cfg[["color-dark"]] <- NULL
  local_brand(cfg)
  expect_no_match(head_html(brand_dark_css()), "datepicker", fixed = TRUE)
})

test_that("brand_dark_mode follows the toggle and caches the dark theme", {
  local_brand()

  shiny::testServer(
    function(input, output, session) {
      dm <- brand_dark_mode(input)
    },
    {
      expect_equal(dm$mode(), "light")
      expect_equal(attr(dm$theme(), "brandkit_mode"), "light")

      session$setInputs(dark_mode = "dark")
      expect_equal(dm$mode(), "dark")
      dark <- dm$theme()
      expect_equal(attr(dark, "brandkit_mode"), "dark")

      session$setInputs(dark_mode = "light")
      session$setInputs(dark_mode = "dark")
      expect_identical(dm$theme(), dark)
    }
  )
})

test_that("brand_dark_mode reads a custom input id", {
  local_brand()
  shiny::testServer(
    function(input, output, session) {
      dm <- brand_dark_mode(input, input_id = "my_toggle")
    },
    {
      session$setInputs(my_toggle = "dark")
      expect_equal(dm$mode(), "dark")
    }
  )
})
