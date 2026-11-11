# detect_output_mode() reads the background of the Shiny output being drawn;
# outside a render there is nothing to read.

test_that("detect_output_mode has nothing to say outside a Shiny render", {
  expect_null(detect_output_mode())
  expect_equal(output_mode(), "light")
})

test_that("detect_output_mode calls a dark background dark and a light one light", {
  testthat::local_mocked_bindings(
    getCurrentOutputInfo = function(...) list(bg = "#10131a"), .package = "shiny"
  )
  expect_equal(detect_output_mode(), "dark")

  testthat::local_mocked_bindings(
    getCurrentOutputInfo = function(...) list(bg = "rgb(250, 250, 250)"), .package = "shiny"
  )
  expect_equal(detect_output_mode(), "light")
})

test_that("detect_output_mode accepts a reactive background", {
  testthat::local_mocked_bindings(
    getCurrentOutputInfo = function(...) list(bg = function() "#000000"), .package = "shiny"
  )
  expect_equal(detect_output_mode(), "dark")
})

test_that("detect_output_mode returns NULL for a background it cannot read", {
  for (bg in list(NULL, NA_character_, "", "not a colour")) {
    testthat::local_mocked_bindings(
      getCurrentOutputInfo = function(...) list(bg = bg), .package = "shiny"
    )
    expect_null(detect_output_mode(), info = format(bg))
  }
})

test_that("the discrete scale picks its palette from the output's background", {
  local_brand()
  for (mode in c("light", "dark")) {
    testthat::local_mocked_bindings(detect_output_mode = function() mode)
    scale <- output_discrete_scale("colour")()
    expect_equal(unname(scale$palette(15)), brand_pal_discrete(mode = mode), info = mode)
  }
  fill <- output_discrete_scale("fill")()
  expect_equal(fill$aesthetics, "fill")
})
