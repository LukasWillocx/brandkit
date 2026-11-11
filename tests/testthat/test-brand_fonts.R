test_that("as_font_weight accepts numbers and CSS keywords", {
  expect_equal(as_font_weight(c(400, 700)), c(400L, 700L))
  expect_equal(as_font_weight("bold"), 700L)
  expect_equal(as_font_weight(c("Light", "SEMI-BOLD", "black")), c(300L, 600L, 900L))
  expect_equal(as_font_weight("500"), 500L)
  expect_null(as_font_weight(NULL))
})

test_that("as_font_weight drops what it cannot interpret", {
  expect_equal(as_font_weight(c("bold", "chunky")), 700L)
  expect_length(as_font_weight("chunky"), 0)
})

test_that("brand_font_weights always includes 400 and 700, plus the roles' weights", {
  ty <- list(
    base = list(family = "Inter", weight = 300),
    headings = list(family = "Fraunces", weight = "black"),
    monospace = list(family = "IBM Plex Mono")
  )
  expect_equal(brand_font_weights("Inter", ty), c(300L, 400L, 700L))
  expect_equal(brand_font_weights("Fraunces", ty), c(400L, 700L, 900L))
  expect_equal(brand_font_weights("IBM Plex Mono", ty), c(400L, 700L))
  expect_equal(brand_font_weights("Unused", ty), c(400L, 700L))
})

test_that("with_google_font_faces fills in missing weight and style", {
  ty <- list(
    fonts = list(list(family = "Inter", source = "google")),
    base = list(family = "Inter")
  )
  out <- with_google_font_faces(ty)$fonts[[1]]
  expect_equal(out$weight, c(400L, 700L))
  expect_equal(out$style, c("normal", "italic"))
})

test_that("with_google_font_faces treats a missing source as Google", {
  ty <- list(fonts = list(list(family = "Inter")), base = list(family = "Inter"))
  expect_equal(with_google_font_faces(ty)$fonts[[1]]$style, c("normal", "italic"))
})

test_that("with_google_font_faces leaves explicit values and local fonts alone", {
  ty <- list(
    fonts = list(
      list(family = "Inter", source = "google", weight = 500, style = "normal"),
      list(family = "Mine", source = "file", files = list(path = "mine.ttf"))
    ),
    base = list(family = "Inter")
  )
  out <- with_google_font_faces(ty)
  expect_equal(out$fonts[[1]]$weight, 500)
  expect_equal(out$fonts[[1]]$style, "normal")
  expect_equal(out$fonts[[2]], ty$fonts[[2]])
})

test_that("with_google_font_faces is idempotent and tolerates no fonts", {
  ty <- list(fonts = list(list(family = "Inter")), base = list(family = "Inter"))
  once <- with_google_font_faces(ty)
  expect_identical(with_google_font_faces(once), once)

  expect_identical(with_google_font_faces(list(base = list(family = "x"))),
                   list(base = list(family = "x")))
})

# brand_register_fonts() talks to sysfonts/showtext, and for Google fonts to
# the network, so both packages' functions are replaced with recorders.
local_font_recorder <- function(known = character(), fail = FALSE, .env = parent.frame()) {
  calls <- new.env()
  calls$google <- character()
  calls$file <- list()
  calls$auto <- 0L

  testthat::local_mocked_bindings(
    font_families = function() c("sans", "serif", known),
    font_add_google = function(name, family = name, ...) {
      if (fail) stop("offline")
      calls$google <- c(calls$google, name)
    },
    font_add = function(family, regular, ...) {
      calls$file[[family]] <- regular
    },
    .package = "sysfonts", .env = .env
  )
  testthat::local_mocked_bindings(
    showtext_auto = function(enable = TRUE) calls$auto <- calls$auto + 1L,
    .package = "showtext", .env = .env
  )
  calls
}

test_that("a font with no source is registered as a Google font", {
  skip_if_not_installed("sysfonts")
  skip_if_not_installed("showtext")
  cfg <- test_brand_bslib()
  cfg$typography$fonts <- list(list(family = "Inter"))
  local_brand(cfg)
  calls <- local_font_recorder()

  brand_register_fonts()
  expect_equal(calls$google, "Inter")
  expect_equal(calls$auto, 1L)
})

test_that("an already registered family is not downloaded again", {
  skip_if_not_installed("sysfonts")
  skip_if_not_installed("showtext")
  local_brand()
  calls <- local_font_recorder(known = c("Inter", "IBM Plex Mono"))

  brand_register_fonts()
  expect_length(calls$google, 0)
  expect_equal(calls$auto, 0L)
})

test_that("a failed download is reported, not raised, and leaves showtext alone", {
  skip_if_not_installed("sysfonts")
  skip_if_not_installed("showtext")
  local_brand()
  calls <- local_font_recorder(fail = TRUE)

  msgs <- testthat::capture_messages(brand_register_fonts())
  expect_match(msgs, "could not load Google Font 'Inter'", all = FALSE)
  expect_equal(calls$auto, 0L)
})

test_that("local font files are registered relative to _brand.yml", {
  skip_if_not_installed("sysfonts")
  skip_if_not_installed("showtext")
  cfg <- test_brand_bslib()
  cfg$typography$fonts <- list(list(
    family = "Mine", source = "file",
    files = list(list(path = "fonts/Mine-Regular.ttf", weight = 400, style = "normal"),
                 list(path = "fonts/Missing.ttf", weight = 700, style = "normal"))
  ))
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "fonts"))
  file.create(file.path(dir, "fonts", "Mine-Regular.ttf"))
  local_brand(cfg)  # a cache is needed, but the paths come from the file below
  brand_init(write_test_brand(cfg, dir), quiet = TRUE)
  calls <- local_font_recorder()

  brand_register_fonts()
  expect_equal(normalizePath(calls$file$Mine),
               normalizePath(file.path(dir, "fonts", "Mine-Regular.ttf")))
  expect_equal(calls$auto, 1L)
})
