test_that("brand_init reads the bslib dialect", {
  local_brand(test_brand_bslib())

  light <- brand_colors("light")
  expect_equal(light$primary, "#1b2a4a")
  expect_equal(light$danger, "#b71c1c")

  dark <- brand_colors("dark")
  expect_equal(dark$primary, "#6b86c4")
  # Colours the dark section doesn't set fall back to the light ones
  expect_equal(dark$danger, light$danger)
  expect_equal(dark$background, "#10131a")
  expect_equal(dark$foreground, "#e8eaee")
})

test_that("brand_init reads Quarto's nested light/dark dialect", {
  local_brand(test_brand_quarto())

  expect_equal(brand_colors("light")$primary, "#1b2a4a")
  expect_equal(brand_colors("dark")$primary, "#6b86c4")
  expect_equal(brand_colors("dark")$background, "#10131a")
  # Plain strings serve both modes
  expect_equal(brand_colors("dark")$success, "#2e7d32")
})

test_that("both dialects give the same cached brand", {
  local_brand(test_brand_bslib())
  from_bslib <- list(light = brand_colors("light"), dark = brand_colors("dark"))
  local_brand(test_brand_quarto())
  from_quarto <- list(light = brand_colors("light"), dark = brand_colors("dark"))

  expect_equal(from_quarto$light$primary, from_bslib$light$primary)
  expect_equal(from_quarto$dark$primary, from_bslib$dark$primary)
})

test_that("a brand without dark colours serves the light ones for dark mode", {
  cfg <- test_brand_bslib()
  cfg[["color-dark"]] <- NULL
  local_brand(cfg)
  expect_equal(brand_colors("dark"), brand_colors("light"))
})

test_that("colours the file omits fall back to Bootstrap-like defaults", {
  local_brand(list(color = list(primary = "#112233", secondary = "#445566")))
  cols <- brand_colors()
  expect_equal(cols$success, "#198754")
  expect_equal(cols$background, "#f8f9fa")
  expect_equal(cols$foreground, "#212529")
})

test_that("fonts fall back through the declared families", {
  local_brand(test_brand_bslib())
  f <- brand_fonts()
  expect_equal(f$base, "Inter")
  expect_equal(f$heading, "Inter")
  expect_equal(f$all, c("Inter", "IBM Plex Mono"))

  local_brand(list(color = list(primary = "#112233", secondary = "#445566")))
  expect_equal(brand_fonts()$base, "sans")
  expect_equal(brand_fonts()$all, "sans")
})

test_that("theme variables are read from either location", {
  local_brand(test_brand_bslib())
  expect_equal(brand_env$theme_vars[["border-radius"]], "0.75rem")
  local_brand(test_brand_quarto())
  expect_equal(brand_env$theme_vars[["border-radius"]], "0.75rem")
})

test_that("brand_init fails clearly when given a path that does not exist", {
  expect_error(brand_init("no/such/_brand.yml"), "No _brand.yml found")
})

test_that("brand_init is quiet on request and informative otherwise", {
  local_brand()
  path <- write_test_brand(test_brand_bslib())
  expect_message(brand_init(path), "loaded brand 'Test Brand'")
  expect_no_message(brand_init(path, quiet = TRUE))
})

test_that("resolve_brand_col handles strings, nested values and fallbacks", {
  expect_equal(resolve_brand_col("#fff"), "#fff")
  expect_null(resolve_brand_col(NULL))
  expect_equal(resolve_brand_col(NULL, fallback = "#000"), "#000")
  nested <- list(light = "#aaa", dark = "#bbb")
  expect_equal(resolve_brand_col(nested, "dark"), "#bbb")
  expect_equal(resolve_brand_col(list(light = "#aaa"), "dark"), "#aaa")
})

test_that("brand_cfg_has_dark spots dark colours in either dialect", {
  expect_true(brand_cfg_has_dark(test_brand_bslib()))
  expect_true(brand_cfg_has_dark(test_brand_quarto()))
  expect_false(brand_cfg_has_dark(list(color = list(primary = "#fff"))))
  expect_false(brand_cfg_has_dark(list()))
})

test_that("brand_logo resolves relative to the _brand.yml and ignores missing files", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "img"))
  file.create(file.path(dir, "img", "logo.png"))

  cfg <- test_brand_bslib()
  cfg$logo <- list(medium = "img/logo.png")
  path <- write_test_brand(cfg, dir)
  old <- as.list(brand_env, all.names = TRUE)
  withr::defer({
    rm(list = ls(brand_env, all.names = TRUE), envir = brand_env)
    list2env(old, envir = brand_env)
  })
  brand_init(path, quiet = TRUE)

  expect_equal(basename(brand_logo()), "logo.png")
  # Any size falls back to the one that exists
  expect_equal(basename(brand_logo("small")), "logo.png")

  cfg$logo <- list(medium = "img/gone.png")
  brand_init(write_test_brand(cfg, withr::local_tempdir()), quiet = TRUE)
  expect_null(brand_logo())

  local_brand(test_brand_bslib())
  expect_null(brand_logo())
})
