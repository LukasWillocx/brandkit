test_that("every Quarto scaffold creates a missing project directory", {
  local_brand(test_brand_quarto())

  creators <- list(
    html      = create_brand_quarto_html,
    slides    = create_brand_quarto_slides,
    dashboard = create_brand_quarto_dashboard,
    pdf       = create_brand_quarto_pdf,
    print     = create_brand_quarto_print_pdf,
    poster    = create_brand_quarto_poster
  )
  for (nm in names(creators)) {
    dir <- file.path(withr::local_tempdir(), "new", nm)
    suppressMessages(copied <- creators[[nm]](dir, examples = FALSE))
    expect_true(dir.exists(dir), info = nm)
    expect_true(file.exists(file.path(dir, "_brand.yml")), info = nm)
    expect_gt(length(copied), 0, label = nm)
  }
})

test_that("the HTML-based scaffolds share drift.scss and the ornaments", {
  local_brand(test_brand_quarto())
  for (create in list(create_brand_quarto_html, create_brand_quarto_slides,
                      create_brand_quarto_dashboard)) {
    dir <- withr::local_tempdir()
    suppressMessages(copied <- create(dir, examples = FALSE))
    expect_true(all(c("drift.scss", "_ornaments.html") %in% basename(copied)))
  }
})

test_that("the example file is named for the scaffold and is skipped on request", {
  local_brand(test_brand_quarto())
  dir <- withr::local_tempdir()
  suppressMessages(create_brand_quarto_pdf(dir))
  suppressMessages(create_brand_quarto_print_pdf(dir))
  expect_true(all(c("report-pdf.qmd", "report-print.qmd") %in% list.files(dir)))

  bare <- withr::local_tempdir()
  suppressMessages(create_brand_quarto_html(bare, examples = FALSE))
  expect_false(file.exists(file.path(bare, "report.qmd")))
})

test_that("copy_template copies, skips what exists, and replaces on request", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "drift.scss")

  expect_message(wrote <- copy_template("quarto/drift.scss", dest, FALSE), "Copied drift.scss")
  expect_equal(wrote, dest)

  writeLines("mine", dest)
  expect_identical(copy_template("quarto/drift.scss", dest, FALSE), character(0))
  expect_equal(readLines(dest), "mine")

  suppressMessages(copy_template("quarto/drift.scss", dest, TRUE))
  expect_false(identical(readLines(dest), "mine"))

  expect_identical(copy_template("quarto/not-there.qmd", file.path(dir, "x"), TRUE),
                   character(0))
})

test_that("copy_template can rewrite the lines it copies", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "out.scss")
  suppressMessages(copy_template("quarto/drift.scss", dest, FALSE,
                                 transform = function(lines) toupper(lines[1:2])))
  expect_length(readLines(dest), 2)
  expect_equal(readLines(dest), toupper(readLines(system.file("quarto/drift.scss",
                                                              package = "brandkit"))[1:2]))
})

test_that("the slide scaffold keeps the logo line only when the brand has a logo", {
  dir <- withr::local_tempdir()

  local_brand(test_brand_quarto())            # no logo
  suppressMessages(create_brand_quarto_slides(dir))
  expect_false(any(grepl("^\\s*logo:\\s*medium", readLines(file.path(dir, "slides.qmd")))))

  cfg <- test_brand_quarto()
  cfg$logo <- list(medium = "logo/mark.png")
  local_brand(cfg)
  other <- withr::local_tempdir()
  suppressMessages(create_brand_quarto_slides(other))
  expect_true(any(grepl("^\\s*logo:\\s*medium", readLines(file.path(other, "slides.qmd")))))
})

test_that("logo_paths reads every shape a logo: section can take", {
  expect_equal(logo_paths("mark.png"), "mark.png")
  expect_setequal(
    logo_paths(list(small = "s.png", medium = list(light = "m-l.png", dark = "m-d.png"))),
    c("s.png", "m-l.png", "m-d.png")
  )
  expect_equal(logo_paths(list(medium = "m.png", large = "m.png")), "m.png")
  expect_identical(logo_paths(list()), character(0))
})

test_that("logo_files_exist needs every referenced file to be there", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "a.png"))

  expect_true(logo_files_exist("a.png", dir))
  expect_false(logo_files_exist(list(small = "a.png", large = "b.png"), dir))
  expect_false(logo_files_exist(list(), dir))
})

test_that("convert_logo keeps a logo that will be found and drops one that won't", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "a.png"))

  expect_null(convert_logo(list(), dir))
  expect_equal(convert_logo(list(logo = "a.png"), dir), "a.png")

  expect_message(dropped <- convert_logo(list(logo = "gone.png"), dir), "omitting logo")
  expect_null(dropped)

  # A caller that knows a logo is about to be written overrides the check, and
  # one that knows it is not suppresses the message too.
  expect_equal(convert_logo(list(logo = "gone.png"), dir, keep_logo = TRUE), "gone.png")
  expect_no_message(expect_null(convert_logo(list(logo = "gone.png"), dir, keep_logo = FALSE)))
})

test_that("both converters leave out a logo they cannot find", {
  local_brand(test_brand_bslib())
  cfg <- list(color = list(primary = "#123456"), logo = "gone.png")
  dir <- withr::local_tempdir()

  expect_null(suppressMessages(quarto_brand_cfg(cfg, dir))$logo)
  expect_null(suppressMessages(bslib_brand_cfg(cfg, dir))$logo)
  expect_equal(quarto_brand_cfg(cfg, dir, keep_logo = TRUE)$logo, "gone.png")
  expect_equal(bslib_brand_cfg(cfg, dir, keep_logo = TRUE)$logo, "gone.png")
})

test_that("both converters cover the same colour keys", {
  cfg <- list(color = stats::setNames(as.list(rep("#123456", length(brand_color_keys))),
                                      brand_color_keys))
  expect_setequal(names(quarto_brand_cfg(cfg, tempdir())$color), brand_color_keys)
  expect_setequal(names(bslib_brand_cfg(cfg, tempdir())$color), brand_color_keys)
})

test_that("the print report's extension is titled as such", {
  dir <- withr::local_tempdir()
  local_brand(test_brand_quarto())
  title <- function(...) {
    write_extension_yml_for_quarto(file.path(dir, "e.yml"), ...)
    yaml::read_yaml(file.path(dir, "e.yml"))$title
  }
  expect_equal(title(), "brandkit Typst Report")
  expect_equal(title(banner_inset = TRUE, drift = TRUE), "brandkit Typst Print Report")
  expect_equal(title(banner_inset = TRUE, poster = list(paper = "a0", columns = 3)),
               "brandkit Typst Poster")
})
