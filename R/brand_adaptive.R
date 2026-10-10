# --------------------------------------------------------------------------
# brandkit: brand_adaptive.R
# Plots that follow a Quarto HTML page's light/dark toggle.
#
# A static figure is baked in at render time, so it cannot follow a toggle
# the way the page does. The way round it is to render every figure twice —
# once per colour mode — and show the one that matches. brand_quarto_setup(
# adaptive = TRUE) arranges that without any change to the document's own
# chunks:
#
#   * images: after a chunk that drew figures, its code is run again in dark
#     mode into twin files (`<label>-dark-<n>.png`), and the plot hook adds
#     a `data-dark-src` attribute to the light image pointing at its twin. A
#     small script (inst/adaptive) swaps `src` when the page changes mode.
#   * plotly: brand_plotly() returns a light and a dark widget side by side,
#     and a stylesheet shows the one that matches (see brand_plotly.R).
#
# Both ride in on one htmlDependency, which Quarto copies beside the page.
# --------------------------------------------------------------------------

# Run `code` with the ggplot2 theme, the default discrete scales and the
# active mode all set for `mode`, and put everything back afterwards. This
# is what makes a plot drawn "in dark mode" use the dark text colours AND the
# dark palette, rather than just one of the two.
with_brand_mode <- function(mode, code) {
  old_theme   <- ggplot2::theme_set(theme_brand(
    mode = mode, transparent = brand_env$transparent %||% TRUE
  ))
  old_options <- options(
    ggplot2.discrete.colour = brand_pal_discrete(mode = mode),
    ggplot2.discrete.fill   = brand_pal_discrete(mode = mode)
  )
  old_mode <- brand_env$active_mode
  brand_env$active_mode <- mode
  on.exit({
    ggplot2::theme_set(old_theme)
    options(old_options)
    brand_env$active_mode <- old_mode
  })
  force(code)
}

adaptive_dependency <- function() {
  htmltools::htmlDependency(
    name    = "brandkit-adaptive",
    version = as.character(utils::packageVersion("brandkit")),
    src     = system.file("adaptive", package = "brandkit"),
    script  = "adaptive.js",
    stylesheet = "adaptive.css"
  )
}

# Where the dark twin of a light figure lives: the same folder, with `-dark`
# after the chunk label, which is also what the twin chunk is labelled.
twin_path <- function(path, label) {
  file.path(dirname(path),
            sub(paste0(label, "-"), paste0(label, "-dark-"),
                basename(path), fixed = TRUE))
}

escape_regex <- function(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)

# Switches the document over to adaptive figures. Called from
# brand_quarto_setup(adaptive = TRUE), which is called from a setup chunk, so
# this runs inside the knit it is setting up.
setup_adaptive <- function() {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(NULL))

  brand_env$adaptive <- TRUE
  knitr::knit_meta_add(list(adaptive_dependency()))

  # Point each light image at its twin. `out.extra` is how a chunk adds
  # attributes to its images, and Quarto's plot hook writes it straight into
  # the attribute block, so captions, cross-references and layout are all
  # left to Quarto exactly as before.
  plot_hook <- knitr::knit_hooks$get("plot")
  if (is.null(attr(plot_hook, "brandkit"))) {
    wrapped <- function(x, options) {
      if (isTRUE(options$brandkit_twin) && length(x) == 1) {
        options$out.extra <- paste(
          c(options$out.extra,
            sprintf('data-dark-src="%s"', twin_path(x, options$label))),
          collapse = " "
        )
      }
      plot_hook(x, options)
    }
    attr(wrapped, "brandkit") <- TRUE
    knitr::knit_hooks$set(plot = wrapped)
  }

  # Draw the twins. Running the chunk's code again, as a child document with
  # its figure options, reuses knitr's own devices, sizes and retina scaling,
  # so the two versions come out the same size. Its output is thrown away;
  # only the files matter.
  knitr::knit_hooks$set(brandkit_twin = function(before, options, envir) {
    if (before || !isTRUE(options$brandkit_twin)) return(NULL)

    label <- options$label
    dir   <- dirname(paste0(options$fig.path, "x"))
    files <- function(suffix) {
      list.files(dir, pattern = paste0("^", escape_regex(label), suffix,
                                       "-[0-9]+\\.png$"))
    }
    if (!length(files(""))) return(NULL)

    # Start from no twins: a leftover from an earlier render would otherwise
    # be mistaken for one of this render's.
    unlink(file.path(dir, files("-dark")))

    keep <- c("fig.width", "fig.height", "fig.asp", "dpi", "fig.retina",
              "dev", "dev.args", "fig.path", "out.width", "out.height")
    opts <- options[intersect(keep, names(options))]
    # By now knitr has already multiplied `dpi` by `fig.retina`, and it
    # would do so again for the child: undo it, or the twin comes out at
    # twice the pixel size and its text at half the relative size.
    opts$dpi <- options$dpi / (options$fig.retina %||% 1)
    opts$echo <- FALSE
    opts$results <- "hide"
    opts$message <- FALSE
    opts$warning <- FALSE
    opts$brandkit_twin <- FALSE

    text <- c(sprintf("```{r %s-dark}", label), options$code, "```")
    with_brand_mode("dark", knitr::knit_child(
      text = text, options = opts, envir = envir, quiet = TRUE
    ))

    # knitr numbers figures with a counter that carries on from the chunk
    # just run, so the twins arrive as -dark-2, -dark-3 and so on. The light
    # image is pointed at -dark-1, -dark-2, ... by position (see twin_path),
    # so renumber them to match.
    twins <- files("-dark")
    twins <- twins[order(as.integer(sub("^.*-([0-9]+)\\.png$", "\\1", twins)))]
    for (i in seq_along(twins)) {
      file.rename(file.path(dir, twins[i]),
                  file.path(dir, sprintf("%s-dark-%d.png", label, i)))
    }
    NULL
  })
  knitr::opts_chunk$set(brandkit_twin = TRUE)

  invisible(NULL)
}
