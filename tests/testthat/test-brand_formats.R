# The two _brand.yml dialects and the conversions between them.

test_that("quarto_brand_cfg nests dark colours and drops bslib-only keys", {
  out <- quarto_brand_cfg(test_brand_bslib(), brand_dir = tempdir())

  expect_null(out[["color-dark"]])
  expect_null(out$theme)
  expect_equal(out$color$primary, list(light = "#1b2a4a", dark = "#6b86c4"))
  # No dark counterpart: stays a plain string
  expect_equal(out$color$danger, "#b71c1c")
  # theme: moves to the channel Quarto accepts
  expect_equal(out$defaults$bootstrap$defaults[["border-radius"]], "0.75rem")
  expect_equal(out$meta$name, "Test Brand")
})

test_that("bslib_brand_cfg flattens nested colours into color: and color-dark:", {
  out <- bslib_brand_cfg(test_brand_quarto(), brand_dir = tempdir())

  expect_equal(out$color$primary, "#1b2a4a")
  expect_equal(out[["color-dark"]]$primary, "#6b86c4")
  expect_equal(out[["color-dark"]]$background, "#10131a")
  expect_equal(out$color$success, "#2e7d32")
  expect_null(out$theme)
  expect_equal(out$defaults$bootstrap$defaults[["border-radius"]], "0.75rem")
  # No colour value is a list, so bslib accepts it
  expect_false(any(vapply(out$color, is.list, logical(1))))
})

test_that("an existing color-dark: wins over nested dark values", {
  cfg <- test_brand_quarto()
  cfg[["color-dark"]] <- list(primary = "#abcdef")
  out <- bslib_brand_cfg(cfg, brand_dir = tempdir())
  expect_equal(out[["color-dark"]]$primary, "#abcdef")
})

test_that("converting there and back keeps the colours", {
  # The configurator always writes foreground/background in color: next to
  # the dark ones, so the fixture does too.
  original <- test_brand_bslib()
  original$color$background <- "#f0f2f5"
  original$color$foreground <- "#1a1d23"
  round_trip <- bslib_brand_cfg(
    quarto_brand_cfg(original, brand_dir = tempdir()), brand_dir = tempdir()
  )
  expect_equal(round_trip$color[names(original$color)], original$color)
  dark_keys <- names(original[["color-dark"]])
  expect_equal(round_trip[["color-dark"]][dark_keys], original[["color-dark"]])
})

test_that("the palette survives both conversions", {
  cfg <- test_brand_bslib()
  cfg$color$palette <- list(brand = "#123456")
  expect_equal(quarto_brand_cfg(cfg, tempdir())$color$palette, list(brand = "#123456"))
  expect_equal(bslib_brand_cfg(cfg, tempdir())$color$palette, list(brand = "#123456"))
})

test_that("a logo is kept only when its file exists beside the brand", {
  dir <- withr::local_tempdir()
  cfg <- test_brand_bslib()
  cfg$logo <- list(medium = "logo.png")

  expect_message(out <- quarto_brand_cfg(cfg, brand_dir = dir), "omitting logo")
  expect_null(out$logo)
  expect_message(out <- bslib_brand_cfg(cfg, brand_dir = dir), "omitting logo")
  expect_null(out$logo)

  file.create(file.path(dir, "logo.png"))
  expect_no_message(out <- quarto_brand_cfg(cfg, brand_dir = dir))
  expect_equal(out$logo, cfg$logo)
  expect_equal(bslib_brand_cfg(cfg, brand_dir = dir)$logo, cfg$logo)

  # keep_logo overrides the check, silently
  expect_no_message(out <- quarto_brand_cfg(cfg, brand_dir = tempdir(), keep_logo = TRUE))
  expect_equal(out$logo, cfg$logo)
})

test_that("quarto_brand_cfg adds Google font faces", {
  out <- quarto_brand_cfg(test_brand_bslib(), brand_dir = tempdir())
  inter <- out$typography$fonts[[1]]
  expect_equal(inter$style, c("normal", "italic"))
  expect_true(all(c(400L, 700L) %in% inter$weight))
})

test_that("logo_files_exist checks every referenced file", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, c("a.png", "b.png")))

  expect_false(logo_files_exist(list(), dir))
  expect_true(logo_files_exist("a.png", dir))
  expect_true(logo_files_exist(list(small = "a.png", large = "b.png"), dir))
  expect_false(logo_files_exist(list(small = "a.png", large = "gone.png"), dir))
  expect_true(logo_files_exist(list(medium = list(light = "a.png", dark = "b.png")), dir))
})

test_that("dialect detection on files", {
  dir <- withr::local_tempdir()
  bslib <- write_test_brand(test_brand_bslib(), dir)
  expect_true(is_bslib_compatible_brand_yml(bslib))
  expect_false(is_quarto_compatible_brand_yml(bslib))

  quarto <- write_test_brand(test_brand_quarto(), withr::local_tempdir())
  expect_true(is_quarto_compatible_brand_yml(quarto))
  expect_false(is_bslib_compatible_brand_yml(quarto))

  missing <- file.path(dir, "nope.yml")
  suppressWarnings({
    expect_false(is_bslib_compatible_brand_yml(missing))
    expect_false(is_quarto_compatible_brand_yml(missing))
  })
})

test_that("write_brand_yml_for_quarto converts a bslib file in place", {
  local_brand(test_brand_bslib())
  dir <- withr::local_tempdir()
  write_test_brand(test_brand_bslib(), dir)

  expect_message(dest <- write_brand_yml_for_quarto(dir), "Converted")
  expect_true(is_quarto_compatible_brand_yml(dest))
})

test_that("write_brand_yml_for_quarto leaves a compatible file alone unless overwritten", {
  local_brand(test_brand_bslib())
  dir <- withr::local_tempdir()
  path <- write_test_brand(test_brand_quarto(), dir)
  # Declare the faces so the font patcher has nothing to do
  cfg <- yaml::read_yaml(path)
  cfg$typography <- with_google_font_faces(cfg$typography)
  yaml::write_yaml(cfg, path)
  before <- readLines(path)

  expect_message(res <- write_brand_yml_for_quarto(dir), "already exists")
  expect_null(res)
  expect_equal(readLines(path), before)

  expect_message(res <- write_brand_yml_for_quarto(dir, overwrite = TRUE), "Wrote")
  expect_equal(res, path)
})

test_that("write_brand_yml_for_shiny converts a Quarto file in place", {
  local_brand(test_brand_quarto())
  dir <- withr::local_tempdir()
  write_test_brand(test_brand_quarto(), dir)

  expect_message(dest <- write_brand_yml_for_shiny(dir), "Converted")
  expect_true(is_bslib_compatible_brand_yml(dest))
  expect_equal(yaml::read_yaml(dest)[["color-dark"]]$primary, "#6b86c4")
})

test_that("patch_brand_yml_font_faces rewrites once, then reports nothing to do", {
  path <- write_test_brand(test_brand_quarto())
  expect_true(patch_brand_yml_font_faces(path))
  expect_false(patch_brand_yml_font_faces(path))

  no_typography <- write_test_brand(list(color = list(primary = "#fff")))
  expect_false(patch_brand_yml_font_faces(no_typography))
})

test_that("a bundled-brand round trip keeps every colour", {
  bundled <- yaml::read_yaml(system.file("_brand.yml", package = "brandkit"))
  skip_if(length(bundled) == 0, "bundled _brand.yml not found")
  out <- quarto_brand_cfg(bundled, brand_dir = tempdir())
  expect_equal(names(out$color), names(bundled$color))
})
