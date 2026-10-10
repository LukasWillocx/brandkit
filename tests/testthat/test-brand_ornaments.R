test_that("brand_ornament returns a single SVG string in brand colours", {
  local_brand()
  svg <- brand_ornament("drift", "top-right")

  expect_type(svg, "character")
  expect_length(svg, 1)
  expect_match(svg, "^<svg ")
  expect_match(svg, "</svg>\\s*$")
  expect_match(svg, "viewBox=\"0 0 100 100\"", fixed = TRUE)
  expect_match(tolower(svg), tolower(brand_colors("light")$primary), fixed = TRUE)
})

test_that("the two corners lead with different colours", {
  local_brand()
  expect_false(identical(
    brand_ornament(corner = "top-right"), brand_ornament(corner = "bottom-left")
  ))
})

test_that("the mode picks the matching palette", {
  local_brand()
  expect_match(
    tolower(brand_ornament(mode = "dark")),
    tolower(brand_colors("dark")$primary), fixed = TRUE
  )
})

test_that("vars = TRUE ties the shapes to Bootstrap variables", {
  local_brand()
  expect_match(brand_ornament(vars = TRUE), "--bs-primary", fixed = TRUE)
  expect_no_match(brand_ornament(vars = FALSE), "--bs-primary", fixed = TRUE)
})

test_that("brand_ornament validates its arguments", {
  local_brand()
  expect_error(brand_ornament(softness = 0), "single number above 0")
  expect_error(brand_ornament(softness = 1.5), "single number above 0")
  expect_error(brand_ornament(softness = c(0.1, 0.2)), "single number above 0")
  expect_error(brand_ornament(softness = NA_real_), "single number above 0")
  expect_error(brand_ornament(corner = "middle"))
  expect_error(brand_ornament(motif = "swirl"))
})

test_that("brand_ornament writes identical bytes on every platform", {
  local_brand()
  path <- withr::local_tempfile(fileext = ".svg")
  res <- brand_ornament(file = path)

  expect_identical(res, brand_ornament())
  bytes <- readBin(path, "raw", file.info(path)$size)
  expect_false(as.raw(13) %in% bytes)  # no CR: not CRLF-converted
  expect_identical(rawToChar(bytes), res)
})

test_that("orn_mix blends two colours by the given fraction", {
  expect_equal(toupper(orn_mix("#000000", "#ffffff", 0)), "#FFFFFF")
  expect_equal(toupper(orn_mix("#000000", "#ffffff", 1)), "#000000")
  expect_equal(toupper(orn_mix("#ff0000", "#0000ff", 0.5)), "#800080")
})
