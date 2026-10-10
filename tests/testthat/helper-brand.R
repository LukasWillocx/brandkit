# Test helpers. Loaded automatically before every test file.
#
# The brand cache (brand_env) is package-level state that .onLoad fills from
# whichever _brand.yml it finds walking up from the working directory. A
# developer's own _brand.yml would therefore change what the tests see, so
# every test that reads the cache sets it explicitly and restores it after.

# A small, complete brand in the bslib / Shiny dialect: flat colours plus a
# separate color-dark: section and a theme: block.
test_brand_bslib <- function() {
  list(
    meta = list(name = "Test Brand"),
    color = list(
      primary = "#1b2a4a", secondary = "#c0945b", success = "#2e7d32",
      danger = "#b71c1c", warning = "#e6a817", info = "#37718e",
      light = "#f0f2f5", dark = "#1a1d23"
    ),
    `color-dark` = list(
      primary = "#6b86c4", secondary = "#d9b27f", background = "#10131a",
      foreground = "#e8eaee"
    ),
    typography = list(
      fonts = list(
        list(family = "Inter", source = "google"),
        list(family = "IBM Plex Mono", source = "google")
      ),
      base = list(family = "Inter", size = "1rem"),
      headings = list(family = "Inter", weight = 700),
      monospace = list(family = "IBM Plex Mono")
    ),
    theme = list(`border-radius` = "0.75rem")
  )
}

# The same brand in the Quarto dialect: dark values nested under each
# colour, Bootstrap variables under defaults: bootstrap: defaults:.
test_brand_quarto <- function() {
  list(
    meta = list(name = "Test Brand"),
    color = list(
      primary = list(light = "#1b2a4a", dark = "#6b86c4"),
      secondary = list(light = "#c0945b", dark = "#d9b27f"),
      success = "#2e7d32", danger = "#b71c1c", warning = "#e6a817",
      info = "#37718e", light = "#f0f2f5", dark = "#1a1d23",
      background = list(light = "#f0f2f5", dark = "#10131a"),
      foreground = list(light = "#1a1d23", dark = "#e8eaee")
    ),
    typography = list(
      fonts = list(list(family = "Inter", source = "google")),
      base = list(family = "Inter", size = "1rem"),
      headings = list(family = "Inter", weight = 700)
    ),
    defaults = list(bootstrap = list(defaults = list(`border-radius` = "0.75rem")))
  )
}

# Write `cfg` to a _brand.yml inside `dir` and return its path.
write_test_brand <- function(cfg, dir = withr::local_tempdir(.local_envir = parent.frame())) {
  path <- file.path(dir, "_brand.yml")
  yaml::write_yaml(cfg, path)
  path
}

# Point the brand cache at `cfg` for the calling test, then put the cache
# back exactly as it was. Returns the path of the _brand.yml it wrote.
local_brand <- function(cfg = test_brand_bslib(), .env = parent.frame()) {
  old <- as.list(brand_env, all.names = TRUE)
  withr::defer({
    rm(list = ls(brand_env, all.names = TRUE), envir = brand_env)
    list2env(old, envir = brand_env)
  }, envir = .env)

  dir <- withr::local_tempdir(.local_envir = .env)
  path <- write_test_brand(cfg, dir)
  brand_init(path, quiet = TRUE)
  path
}
