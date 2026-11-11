# brand_quarto_setup() and setup_adaptive() change global state (the ggplot2
# theme and options, knitr's chunk options and hooks), so each test puts all of
# it back.

local_render_state <- function(.env = parent.frame()) {
  old_theme <- ggplot2::theme_get()
  old_opts  <- options("ggplot2.discrete.colour", "ggplot2.discrete.fill")
  old_chunk <- knitr::opts_chunk$get()
  old_hooks <- knitr::knit_hooks$get()
  old_env   <- as.list(brand_env, all.names = TRUE)
  withr::defer({
    ggplot2::theme_set(old_theme)
    options(old_opts)
    knitr::opts_chunk$restore(old_chunk)
    knitr::knit_hooks$restore(old_hooks)
    knitr::knit_meta(clean = TRUE)
    rm(list = ls(brand_env, all.names = TRUE), envir = brand_env)
    list2env(old_env, envir = brand_env)
  }, envir = .env)
}

test_that("brand_quarto_setup records the mode and themes ggplot2 for it", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()

  brand_quarto_setup("dark")
  dark <- brand_colors("dark")

  expect_equal(brand_env$active_mode, "dark")
  expect_true(brand_env$transparent)
  expect_equal(unname(getOption("ggplot2.discrete.colour")),
               brand_pal_discrete(mode = "dark"))
  expect_equal(ggplot2::theme_get()$axis.text$colour, dark$foreground)
  expect_equal(knitr::opts_chunk$get("dev.args")$bg, "transparent")
})

test_that("transparent = FALSE paints the device with the brand background", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()

  brand_quarto_setup("light", transparent = FALSE)
  expect_equal(knitr::opts_chunk$get("dev.args")$bg, brand_colors("light")$background)
  expect_false(brand_env$transparent)
})

test_that("brand_quarto_setup sets the base graphics colours before each chunk", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()

  brand_quarto_setup("dark")
  expect_true(knitr::opts_chunk$get("brandkit_par"))

  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off())
  knitr::knit_hooks$get("brandkit_par")(TRUE, list(), NULL)
  expect_equal(tolower(graphics::par("col.axis")), brand_colors("dark")$foreground)
})

test_that("shiny = TRUE hands the plots to thematic and sets no knitr hooks", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()

  seen <- NULL
  testthat::local_mocked_bindings(activate_thematic_shiny = function(mode) seen <<- mode)
  before <- knitr::opts_chunk$get("brandkit_par")

  brand_quarto_setup("dark", shiny = TRUE)
  expect_equal(seen, "dark")
  expect_identical(knitr::opts_chunk$get("brandkit_par"), before)
})

test_that("adaptive = TRUE forces light and switches the twin machinery on", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()

  brand_quarto_setup("dark", adaptive = TRUE)
  expect_equal(brand_env$active_mode, "light")
  expect_true(brand_env$adaptive)
  expect_true(knitr::opts_chunk$get("brandkit_twin"))

  # A later call without it switches it off again.
  brand_quarto_setup()
  expect_false(brand_env$adaptive)
})

test_that("with_brand_mode sets the theme, palette and mode, then puts them back", {
  local_brand()
  local_render_state()
  brand_env$active_mode <- "light"
  ggplot2::theme_set(theme_brand())
  before_theme <- ggplot2::theme_get()

  inside <- with_brand_mode("dark", list(
    mode    = brand_env$active_mode,
    palette = unname(getOption("ggplot2.discrete.colour")),
    axis    = ggplot2::theme_get()$axis.text$colour
  ))

  expect_equal(inside$mode, "dark")
  expect_equal(inside$palette, brand_pal_discrete(mode = "dark"))
  expect_equal(inside$axis, brand_colors("dark")$foreground)
  expect_equal(brand_env$active_mode, "light")
  expect_identical(ggplot2::theme_get(), before_theme)
})

test_that("with_brand_mode restores everything when the code fails", {
  local_brand()
  local_render_state()
  brand_env$active_mode <- "light"

  expect_error(with_brand_mode("dark", stop("boom")), "boom")
  expect_equal(brand_env$active_mode, "light")
})

test_that("twin_path names the dark file after the chunk label", {
  expect_equal(twin_path("figs/scatter-1.png", "scatter"), "figs/scatter-dark-1.png")
  expect_equal(twin_path("a/b/fig-2.png", "fig"), "a/b/fig-dark-2.png")
  # Only the label is rewritten, not a matching piece of the folder.
  expect_equal(twin_path("scatter-files/scatter-1.png", "scatter"),
               "scatter-files/scatter-dark-1.png")
})

test_that("escape_regex makes a label safe to put in a pattern", {
  label <- "fig.a+b(1)"
  expect_true(grepl(paste0("^", escape_regex(label), "$"), label))
  expect_false(grepl(paste0("^", escape_regex(label), "$"), "figxa+b(1)"))
})

test_that("knitting a chunk with adaptive on writes a dark twin beside each figure", {
  skip_if_not_installed("knitr")
  local_brand()
  local_render_state()
  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  rmd <- c(
    "```{r setup}",
    "brandkit::brand_quarto_setup(adaptive = TRUE)",
    "```",
    "```{r scatter, fig.path = 'figs/', dev = 'png'}",
    "library(ggplot2)",
    "ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point()",
    "plot(1:3)",
    "```"
  )
  out <- suppressMessages(suppressWarnings(
    knitr::knit(text = rmd, output = file.path(dir, "out.md"), quiet = TRUE,
                envir = new.env(parent = globalenv()))
  ))

  files <- sort(list.files("figs"))
  expect_true("scatter-1.png" %in% files)
  expect_true("scatter-dark-1.png" %in% files)
  # Two figures in the chunk: the twins are numbered to match them.
  expect_true("scatter-2.png" %in% files)
  expect_true("scatter-dark-2.png" %in% files)
  expect_match(paste(readLines(out), collapse = "
"), "data-dark-src", fixed = TRUE)
})
