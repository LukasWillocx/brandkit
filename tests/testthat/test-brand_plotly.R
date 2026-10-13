test_that("brand_plotly picks its mode: explicit, then stored, never the output outside Shiny", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("shiny")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  ink <- function(w) w$x$layout$font$color

  # Outside a render there is no output to read a background from.
  expect_null(detect_output_mode())

  expect_identical(ink(brand_plotly(p, mode = "dark")),  brand_colors("dark")$foreground)
  expect_identical(ink(brand_plotly(p, mode = "light")), brand_colors("light")$foreground)

  old <- brand_env$active_mode
  on.exit(brand_env$active_mode <- old)
  brand_env$active_mode <- "dark"
  expect_identical(ink(brand_plotly(p)), brand_colors("dark")$foreground)
})
