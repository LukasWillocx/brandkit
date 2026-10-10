test_that("hex_to_rgb_str and hex_to_rgba convert hex to CSS channel values", {
  expect_equal(hex_to_rgb_str("#ff8000"), "255, 128, 0")
  expect_equal(hex_to_rgba("#ff8000", 0.5), "rgba(255, 128, 0, 0.5)")
  expect_equal(hex_to_rgba("#000000"), "rgba(0, 0, 0, 1)")
})

test_that("shift_color lightens for positive and darkens for negative amounts", {
  lum <- function(hex) sum(grDevices::col2rgb(hex) * c(0.299, 0.587, 0.114))
  base <- "#808080"
  expect_gt(lum(shift_color(base, 0.3)), lum(base))
  expect_lt(lum(shift_color(base, -0.3)), lum(base))
  expect_equal(lum(shift_color(base, 0)), lum(base), tolerance = 1)
})

test_that("is_dark_colour splits at perceptual luminance", {
  expect_true(is_dark_colour("#000000"))
  expect_true(is_dark_colour("#1b2a4a"))
  expect_false(is_dark_colour("#ffffff"))
  expect_false(is_dark_colour("#f0f2f5"))
  # Green reads brighter than blue at the same channel value
  expect_false(is_dark_colour("#00ff00"))
  expect_true(is_dark_colour("#0000ff"))
})

test_that("dark-mode helpers move colours in the documented direction", {
  lum <- function(hex) sum(grDevices::col2rgb(hex) * c(0.299, 0.587, 0.114))
  expect_gt(lum(auto_dark_variant("#1b2a4a")), lum("#1b2a4a"))
  expect_lt(lum(auto_dark_bg("#1a1d23")), lum("#1a1d23"))
  expect_gt(lum(auto_dark_fg("#10131a")), lum("#10131a"))
  expect_true(is_dark_colour(auto_dark_bg("#1a1d23")))
  expect_false(is_dark_colour(auto_dark_fg("#10131a")))
})
