is_hex <- function(x) grepl("^#[0-9A-Fa-f]{6}$", x)

test_that("brand_pal_discrete leads with the brand's semantic colours", {
  local_brand()
  cols <- brand_colors("light")
  pal <- brand_pal_discrete(mode = "light")

  expect_length(pal, 15)
  expect_true(all(is_hex(pal)))
  expect_equal(
    pal[1:6],
    c(cols$primary, cols$secondary, cols$success,
      cols$warning, cols$danger, cols$info)
  )
  expect_false(anyDuplicated(tolower(pal)) > 0)
})

test_that("brand_pal_discrete honours n and caps at 15", {
  local_brand()
  expect_length(brand_pal_discrete(3), 3)
  expect_equal(brand_pal_discrete(3), brand_pal_discrete()[1:3])
  expect_warning(out <- brand_pal_discrete(20), "Max 15")
  expect_length(out, 15)
})

test_that("brand_pal_discrete uses the dark palette in dark mode", {
  local_brand()
  expect_equal(brand_pal_discrete(1, mode = "dark"), brand_colors("dark")$primary)
  expect_false(identical(
    brand_pal_discrete(mode = "light"), brand_pal_discrete(mode = "dark")
  ))
})

test_that("brand_pal_discrete defaults to the mode brand_quarto_setup() set", {
  local_brand()
  withr::defer(brand_env$active_mode <- NULL)
  brand_env$active_mode <- "dark"
  expect_equal(brand_pal_discrete(1), brand_colors("dark")$primary)
  brand_env$active_mode <- NULL
  expect_equal(brand_pal_discrete(1), brand_colors("light")$primary)
})

test_that("brand_pal_seq ramps from the background to a brand colour", {
  local_brand()
  cols <- brand_colors("light")

  warm <- brand_pal_seq("warm", n = 5)
  expect_length(warm, 5)
  expect_equal(toupper(warm[1]), toupper(cols$background))
  expect_equal(toupper(warm[5]), toupper(cols$danger))
  expect_equal(toupper(brand_pal_seq("cool", 5)[5]), toupper(cols$secondary))
  expect_equal(toupper(brand_pal_seq("green", 5)[5]), toupper(cols$dark))

  expect_equal(brand_pal_seq("warm", 5, reverse = TRUE), rev(warm))
  expect_error(brand_pal_seq("purple"), "must be 'warm', 'cool', or 'green'")
})

test_that("brand_pal_div runs cool to warm through the background", {
  local_brand()
  cols <- brand_colors("light")

  div <- brand_pal_div(n = 5)
  expect_equal(toupper(div[1]), toupper(cols$info))
  expect_equal(toupper(div[3]), toupper(cols$background))
  expect_equal(toupper(div[5]), toupper(cols$danger))
  expect_equal(brand_pal_div(5, reverse = TRUE), rev(div))
  expect_length(brand_pal_div(), 11)
})
