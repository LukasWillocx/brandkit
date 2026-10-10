test_that("create_brand_shiny_app writes a bslib-format _brand.yml and app.R", {
  local_brand(test_brand_quarto())
  dir <- file.path(withr::local_tempdir(), "my-app")

  suppressMessages(copied <- create_brand_shiny_app(dir))

  expect_true(file.exists(file.path(dir, "app.R")))
  brand <- file.path(dir, "_brand.yml")
  expect_true(file.exists(brand))
  expect_true(is_bslib_compatible_brand_yml(brand))
  expect_setequal(basename(copied), c("_brand.yml", "app.R"))
})

test_that("create_brand_shiny_app never overwrites app.R unless asked", {
  local_brand(test_brand_bslib())
  dir <- withr::local_tempdir()
  writeLines("# mine", file.path(dir, "app.R"))

  suppressMessages(create_brand_shiny_app(dir))
  expect_equal(readLines(file.path(dir, "app.R")), "# mine")

  suppressMessages(create_brand_shiny_app(dir, overwrite = TRUE))
  expect_false(identical(readLines(file.path(dir, "app.R")), "# mine"))
})

test_that("the bundled Shiny templates are all installed", {
  for (tpl in c("app-starter.R", "app-dashboard.R", "app-map.R")) {
    expect_true(nzchar(system.file("shiny", tpl, package = "brandkit")), info = tpl)
  }
})

test_that("the bundled Quarto templates and Typst extension are installed", {
  for (f in c("report.qmd", "slides.qmd", "pdf-report.qmd", "print-report.qmd",
              "poster.qmd", "dashboard.qmd", "drift.scss")) {
    expect_true(nzchar(system.file("quarto", f, package = "brandkit")), info = f)
  }
  expect_true(nzchar(system.file("quarto/typst/_extensions/brandkit", package = "brandkit")))
})

test_that("warn_missing_packages reports only what is missing", {
  expect_no_message(warn_missing_packages(character(0)))
  expect_no_message(warn_missing_packages("stats"))
  msgs <- character(0)
  res <- withCallingHandlers(
    warn_missing_packages(c("stats", "notarealpackage123")),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_match(paste(msgs, collapse = ""), "notarealpackage123")
  expect_equal(res, "notarealpackage123")
})
