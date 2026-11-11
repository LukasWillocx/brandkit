# --------------------------------------------------------------------------
# brandkit: zzz.R
# Package hooks. After library(brandkit), ggplot2 is branded automatically.
# --------------------------------------------------------------------------

#' @importFrom rlang %||%
# bslib::bs_theme(brand = ) reads _brand.yml through brand.yml, which bslib only
# suggests. brandkit builds its theme that way, so it is a hard dependency here.
#' @importFrom brand.yml read_brand_yml
#' @importFrom methods as
#' @importFrom graphics axis lines par
NULL

.onLoad <- function(libname, pkgname) {
  # Try to initialise the cache silently; don't error if no _brand.yml
  # is found yet (user may call brand_init() later).
  tryCatch(
    brand_init(quiet = TRUE),
    error = function(e) NULL
  )

  # Register fonts from cache (reads _brand.yml typography section). Google
  # fonts are downloaded, so this can be switched off for a quick load.
  if (isTRUE(getOption("brandkit.register_fonts", TRUE))) {
    tryCatch(
      brand_register_fonts(),
      error = function(e) NULL
    )
  }
}

.onAttach <- function(libname, pkgname) {
  if (!isTRUE(brand_env$ready)) {
    packageStartupMessage(
      "brandkit: no _brand.yml found. Run brandkit::configure_brand() ",
      "or brandkit::brand_init('path/to/_brand.yml') to get started."
    )
    return(invisible(NULL))
  }

  # --- Auto-apply ggplot2 theme ---
  brand_env$active_mode <- "light"

  if (requireNamespace("ggplot2", quietly = TRUE)) {
    ggplot2::theme_set(theme_brand())

    # Register default discrete palette via options so every ggplot
    # that maps colour/fill to a discrete variable uses brand colours.
    pal <- brand_pal_discrete()
    options(
      ggplot2.discrete.colour = pal,
      ggplot2.discrete.fill   = pal
    )
  }

  packageStartupMessage(
    "brandkit: brand '", brand_env$meta$name %||% "unnamed",
    "' applied. ggplot2 defaults set."
  )
}
