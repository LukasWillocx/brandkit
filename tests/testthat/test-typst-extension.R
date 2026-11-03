extension_typst <- function(dir, ext = "brandkit-print") {
  yaml::read_yaml(file.path(dir, "_extensions", ext, "_extension.yml"))$contributes$formats$typst
}

brand_with_size <- function(size) {
  cfg <- test_brand_quarto()
  cfg$typography$base$size <- size
  cfg
}

test_that("re-running the print scaffold picks up a changed base size", {
  dir <- withr::local_tempdir()
  write_test_brand(brand_with_size("0.7rem"), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  expect_equal(extension_typst(dir)$fontsize, "8.4pt")

  # What configure_brand() does on save: rewrite _brand.yml in place.
  write_test_brand(brand_with_size("1.5rem"), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  expect_equal(extension_typst(dir)$fontsize, "18pt")
})

test_that("syncing the extension keeps hand edits to other keys", {
  dir <- withr::local_tempdir()
  write_test_brand(brand_with_size("1rem"), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))

  yml <- file.path(dir, "_extensions", "brandkit-print", "_extension.yml")
  cfg <- yaml::read_yaml(yml)
  cfg$contributes$formats$typst$margin$x <- "4cm"
  yaml::write_yaml(cfg, yml)

  write_test_brand(brand_with_size("1.2rem"), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))

  typst <- extension_typst(dir)
  expect_equal(typst$fontsize, "14.4pt")
  expect_equal(typst$margin$x, "4cm")
})

test_that("an up-to-date extension is not rewritten", {
  dir <- withr::local_tempdir()
  write_test_brand(brand_with_size("1rem"), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))

  yml <- file.path(dir, "_extensions", "brandkit-print", "_extension.yml")
  before <- unname(tools::md5sum(yml))
  expect_no_match(
    capture.output(create_brand_quarto_print_pdf(dir, examples = FALSE), type = "message"),
    "Updated"
  )
  expect_equal(unname(tools::md5sum(yml)), before)
})

test_that("re-running the print scaffold picks up a changed ornament label", {
  dir <- withr::local_tempdir()
  cfg <- test_brand_quarto()
  write_test_brand(cfg, dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  svg <- file.path(dir, "_extensions", "brandkit-print", "drift-top-right.svg")
  expect_no_match(paste(readLines(svg), collapse = "\n"), "<text", fixed = TRUE)

  cfg$meta$`ornament-label` <- "Acme"
  write_test_brand(cfg, dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  # The file Typst draws sets one letter per element (see orn_label_svg()).
  expect_match(paste(readLines(svg), collapse = "\n"), ">M</text>", fixed = TRUE)
})

test_that("every Typst format sets inline code with the filter, and ships it", {
  scaffold <- list(
    brandkit        = function(d) create_brand_quarto_pdf(d, examples = FALSE),
    `brandkit-print`  = function(d) create_brand_quarto_print_pdf(d, examples = FALSE),
    `brandkit-poster` = function(d) create_brand_quarto_poster(d, examples = FALSE)
  )
  for (ext in names(scaffold)) {
    dir <- withr::local_tempdir()
    write_test_brand(test_brand_quarto(), dir)
    suppressMessages(scaffold[[ext]](dir))

    expect_true(file.exists(file.path(dir, "_extensions", ext, "inline-code.lua")), info = ext)
    filters <- unlist(extension_typst(dir, ext)$filters)
    expect_equal(filters[1], "inline-code.lua", info = ext)
    # The poster's own filter follows it; nobody else has one.
    expect_equal(filters, if (ext == "brandkit-poster") c("inline-code.lua", "poster.lua") else "inline-code.lua", info = ext)
  }
})

test_that("the inline-code macro and the skylighting wrapper are in the template", {
  dir <- withr::local_tempdir()
  write_test_brand(test_brand_quarto(), dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  show <- paste(readLines(file.path(dir, "_extensions", "brandkit-print", "typst-show.typ")), collapse = "\n")

  # The filter emits a call of this, so it must exist wherever the filter runs.
  expect_match(show, "#let brandkit-inline-code(s)", fixed = TRUE)
  # Skylighting is only defined when the document has highlighted code, so the
  # wrapper has to sit behind the same guard or a code-free document would fail
  # to compile.
  start   <- regexpr("$if(highlighting-definitions)$", show, fixed = TRUE)[[1]]
  wrapper <- regexpr("#let Skylighting(..args)", show, fixed = TRUE)[[1]]
  close   <- regexpr("$endif$", substring(show, start), fixed = TRUE)[[1]] + start - 1
  expect_gt(start, 0)
  expect_true(wrapper > start && wrapper < close)
})

test_that("code blocks and callouts take the brand radius, not a hard-coded one", {
  cfg <- test_brand_quarto()
  cfg$defaults$bootstrap$defaults$`border-radius` <- "1.5rem"
  dir <- withr::local_tempdir()
  write_test_brand(cfg, dir)
  suppressMessages(create_brand_quarto_print_pdf(dir, examples = FALSE))
  ext  <- file.path(dir, "_extensions", "brandkit-print")
  read <- function(f) paste(readLines(file.path(ext, f)), collapse = "\n")

  expect_equal(extension_typst(dir)$`code-radius`, "1.5em")
  # Skylighting hard-codes radius: 2pt; the wrapper in typst-show.typ replaces it.
  expect_match(read("typst-show.typ"), "block.with(..fields, fill: fill, radius: radius)", fixed = TRUE)
  # Quarto's callout hard-codes the same, and clips its square-cornered title
  # and body to the rounded outline.
  defs <- read("definitions.typ")
  expect_no_match(defs, "radius: 2pt", fixed = TRUE)
  expect_match(defs, "clip: true", fixed = TRUE)
})
