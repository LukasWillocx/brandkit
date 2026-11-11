# Background fill of a theme element, whichever way ggplot2 stores it.
bg_fill <- function(theme, element) theme[[element]]$fill

test_that("theme_brand is transparent outside Shiny, opaque with transparent = FALSE", {
  local_brand()
  cols <- brand_colors("light")

  expect_true(is.na(bg_fill(theme_brand(), "panel.background")))
  expect_true(is.na(bg_fill(theme_brand(transparent = TRUE), "plot.background")))
  expect_equal(bg_fill(theme_brand(transparent = FALSE), "panel.background"),
               cols$background)
})

test_that("theme_brand defaults to opaque inside a Shiny session", {
  local_brand()
  shiny::testServer(
    function(input, output, session) {},
    expect_false(is.na(bg_fill(theme_brand(), "panel.background")))
  )
})

test_that("theme_brand takes its text and background colours from the mode", {
  local_brand()
  dark <- brand_colors("dark")
  th <- theme_brand(mode = "dark", transparent = FALSE)

  expect_equal(th$axis.text$colour, dark$foreground)
  expect_equal(bg_fill(th, "plot.background"), dark$background)
  expect_equal(th$text$size, 14)
  expect_equal(theme_brand(base_size = 20)$text$size, 20)
})

test_that("the discrete scales use the brand palette for the mode asked for", {
  local_brand()
  light <- brand_pal_discrete(mode = "light")
  dark  <- brand_pal_discrete(mode = "dark")

  expect_equal(unname(scale_color_brand_d()$palette(15)), light)
  expect_equal(unname(scale_fill_brand_d(mode = "dark")$palette(15)), dark)
})

test_that("the scales follow the active mode unless told otherwise", {
  local_brand()
  withr::defer(brand_env$active_mode <- NULL)
  brand_env$active_mode <- "dark"

  dark <- brand_pal_discrete(mode = "dark")
  expect_equal(unname(scale_color_brand_d()$palette(15)), dark)
  expect_equal(unname(scale_fill_brand_d()$palette(15)), dark)
  # An explicit mode still wins.
  expect_equal(unname(scale_color_brand_d(mode = "light")$palette(15)),
               brand_pal_discrete(mode = "light"))
})

test_that("the sequential and diverging palettes follow the active mode too", {
  local_brand()
  withr::defer(brand_env$active_mode <- NULL)

  brand_env$active_mode <- "light"
  light_seq <- brand_pal_seq()
  light_div <- brand_pal_div()

  brand_env$active_mode <- "dark"
  expect_false(identical(brand_pal_seq(), light_seq))
  expect_equal(brand_pal_seq(), brand_pal_seq(mode = "dark"))
  expect_equal(brand_pal_div(), brand_pal_div(mode = "dark"))
  expect_equal(brand_pal_div(mode = "light"), light_div)
})

test_that("the continuous scales build from the brand ramps", {
  local_brand()
  expect_s3_class(scale_color_brand_c(type = "cool"), "ScaleContinuous")
  expect_s3_class(scale_fill_brand_c(), "ScaleContinuous")
  expect_s3_class(scale_color_brand_div(), "ScaleContinuous")
  expect_s3_class(scale_fill_brand_div(mode = "dark"), "ScaleContinuous")
  expect_error(scale_color_brand_c(type = "purple"), "type must be")
})

test_that("a plot with a brand theme and scale builds without error", {
  local_brand()
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
    ggplot2::geom_point() +
    scale_color_brand_d() +
    theme_brand()
  expect_no_error(ggplot2::ggplot_build(p))
})
