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
