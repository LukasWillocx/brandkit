# The page wrappers pull in brand_theme() and, as a side effect, switch on
# thematic and the app-wide ggplot theme, so each test puts the ggplot theme
# and options back as it found them.

local_page_state <- function(.env = parent.frame()) {
  old_theme <- ggplot2::theme_get()
  old_opts  <- options("ggplot2.discrete.colour", "ggplot2.discrete.fill")
  withr::defer({
    ggplot2::theme_set(old_theme)
    options(old_opts)
  }, envir = .env)
}

# The body's tags only. Rendering with dependencies would compile the theme,
# which fetches the brand's web fonts.
page_html <- function(ui) as.character(ui)

test_that("the page wrappers leave the classic page without drift", {
  skip_if_not_installed("thematic")
  local_brand()
  local_page_state()

  pages <- list(
    sidebar = brand_page_sidebar("x", title = "T", sidebar = bslib::sidebar("s")),
    navbar  = brand_page_navbar(title = "T", bslib::nav_panel("A", "x")),
    fluid   = brand_page_fluid("x", title = "T")
  )
  for (nm in names(pages)) {
    html <- page_html(pages[[nm]])
    expect_false(grepl("bk-ornament", html, fixed = TRUE), info = nm)
  }
  expect_false(grepl("bk-drift", head_html(build_page_setup(TRUE, "m", list())$head_tags),
                     fixed = TRUE))
})

test_that("style = 'drift' adds the stylesheet and ornaments on every wrapper", {
  skip_if_not_installed("thematic")
  local_brand()
  local_page_state()

  pages <- list(
    sidebar = brand_page_sidebar("x", title = "T", sidebar = bslib::sidebar("s"),
                                 style = "drift"),
    navbar  = brand_page_navbar(title = "T", bslib::nav_panel("A", "x"),
                                style = "drift"),
    fluid   = brand_page_fluid("x", title = "T", style = "drift")
  )
  for (nm in names(pages)) {
    html <- page_html(pages[[nm]])
    # One wrapper element per corner.
    expect_equal(lengths(regmatches(html, gregexpr('class="bk-ornament ', html))),
                 2L, info = nm, ignore_attr = TRUE)
  }
  expect_true(grepl("bk-drift",
                    head_html(build_page_setup(TRUE, "m", list(), "drift")$head_tags),
                    fixed = TRUE))
})

test_that("an unknown style is refused", {
  local_brand()
  expect_error(brand_page_navbar(title = "T", style = "pop"), "should be one of")
  expect_error(brand_page_fluid(title = "T", style = "pop"), "should be one of")
})
