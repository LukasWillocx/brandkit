test_that("brand_ornament returns a single SVG string in brand colours", {
  local_brand()
  svg <- brand_ornament("drift", "top-right")

  expect_type(svg, "character")
  expect_length(svg, 1)
  expect_match(svg, "^<svg ")
  expect_match(svg, "</svg>\\s*$")
  expect_match(svg, "viewBox=\"0 0 100 100\"", fixed = TRUE)
  expect_match(tolower(svg), tolower(brand_colors("light")$primary), fixed = TRUE)
})

test_that("the two corners lead with different colours", {
  local_brand()
  expect_false(identical(
    brand_ornament(corner = "top-right"), brand_ornament(corner = "bottom-left")
  ))
})

test_that("the mode picks the matching palette", {
  local_brand()
  expect_match(
    tolower(brand_ornament(mode = "dark")),
    tolower(brand_colors("dark")$primary), fixed = TRUE
  )
})

test_that("vars = TRUE ties the shapes to Bootstrap variables", {
  local_brand()
  expect_match(brand_ornament(vars = TRUE), "--bs-primary", fixed = TRUE)
  expect_no_match(brand_ornament(vars = FALSE), "--bs-primary", fixed = TRUE)
})

test_that("brand_ornament validates its arguments", {
  local_brand()
  expect_error(brand_ornament(softness = 0), "single number above 0")
  expect_error(brand_ornament(softness = 1.5), "single number above 0")
  expect_error(brand_ornament(softness = c(0.1, 0.2)), "single number above 0")
  expect_error(brand_ornament(softness = NA_real_), "single number above 0")
  expect_error(brand_ornament(corner = "middle"))
  expect_error(brand_ornament(motif = "swirl"))
})

test_that("brand_ornament writes identical bytes on every platform", {
  local_brand()
  path <- withr::local_tempfile(fileext = ".svg")
  res <- brand_ornament(file = path)

  expect_identical(res, brand_ornament())
  bytes <- readBin(path, "raw", file.info(path)$size)
  expect_false(as.raw(13) %in% bytes)  # no CR: not CRLF-converted
  expect_identical(rawToChar(bytes), res)
})

test_that("orn_mix blends two colours by the given fraction", {
  expect_equal(toupper(orn_mix("#000000", "#ffffff", 0)), "#FFFFFF")
  expect_equal(toupper(orn_mix("#000000", "#ffffff", 1)), "#000000")
  expect_equal(toupper(orn_mix("#ff0000", "#0000ff", 0.5)), "#800080")
})

# -- The label ---------------------------------------------------------------

brand_with_label <- function(label) {
  cfg <- test_brand_bslib()
  cfg$meta$`ornament-label` <- label
  cfg
}

# The number in the first `name="..."` attribute of an SVG string.
attr_num <- function(svg, name) {
  hit <- regmatches(svg, regexpr(paste0(name, '="-?[0-9.]+"'), svg))
  as.numeric(gsub("[^0-9.-]", "", sub(name, "", hit, fixed = TRUE)))
}

test_that("an ornament has no label unless the brand asks for one", {
  local_brand()
  expect_no_match(brand_ornament("drift", "top-right"), "<text", fixed = TRUE)
})

test_that("the label comes from meta and is drawn in the heading font", {
  local_brand(brand_with_label("Acme Group"))
  svg <- brand_ornament("drift", "top-right", vars = TRUE)

  expect_match(svg, "<textPath", fixed = TRUE)
  expect_match(svg, "ACME GROUP", fixed = TRUE)   # capitals
  expect_match(svg, "'Inter'", fixed = TRUE)      # the test brand's heading font
})

test_that("web SVG sets the label on a path, standalone SVG places each letter", {
  local_brand(brand_with_label("Acme Group"))

  web <- brand_ornament("drift", "top-right", vars = TRUE)
  expect_match(web, "<textPath", fixed = TRUE)

  # Typst spaces text-on-path unevenly, so the files it draws get one plain
  # rotated <text> per letter (spaces are advanced over, not drawn).
  file <- brand_ornament("drift", "top-right", vars = FALSE)
  expect_no_match(file, "<textPath", fixed = TRUE)
  expect_equal(lengths(regmatches(file, gregexpr("<text ", file, fixed = TRUE))), 9)
  expect_match(file, ">A</text>", fixed = TRUE)
  expect_match(file, "rotate(", fixed = TRUE)
})

test_that("glyph layout runs left to right, descends with the swell, and is centred on the orb", {
  svg <- ornament_svg("drift", "top-right", 0.12, "#111111", "#222222", "#333333",
                      label = "Acme Group", font = "Inter", label_layout = "glyphs")
  pos <- regmatches(svg, gregexpr("translate\\([0-9.]+ [0-9.]+\\)", svg))[[1]]
  xy <- do.call(rbind, lapply(strsplit(gsub("[^0-9. ]", "", pos), " "), as.numeric))

  expect_true(all(diff(xy[, 1]) > 0))             # reads left to right
  expect_true(all(diff(xy[, 2]) > 0))             # and follows the swell down
  # The middle of the line falls near the largest orb's centre (60, 38): the
  # baseline is offset to the side, but not by more than the orb's radius.
  expect_lt(abs(mean(range(xy[, 1])) - orn_drift_orb[1]), 6)
  expect_lt(abs(mean(range(xy[, 2])) - orn_drift_orb[2]), orn_drift_orb[3] / 2)
})

test_that("glyph layout sizes the line from letter widths, within the floor", {
  size <- function(label) {
    svg <- ornament_svg("drift", "top-right", 0.12, "#111111", "#222222",
                        "#333333", label = label, font = "Inter",
                        label_layout = "glyphs")
    attr_num(svg, "font-size")
  }
  expect_gt(size("Acme"), size("Acme Group"))
  expect_gt(size("Illiniilini"), size("Wwwwwwwwww"))   # narrow letters get more size
  expect_gte(size(strrep("W", orn_label_max_chars)), 2.5)
})

test_that("an explicit label overrides the brand, and NULL or blank removes it", {
  local_brand(brand_with_label("Acme Group"))
  expect_match(brand_ornament(label = "Other", vars = TRUE), "OTHER", fixed = TRUE)
  expect_match(brand_ornament(label = "Other"), ">R</text>", fixed = TRUE)
  expect_no_match(brand_ornament(label = NULL), "<text", fixed = TRUE)
  expect_no_match(brand_ornament(label = "  "), "<text", fixed = TRUE)
})

test_that("the label is drawn on the top-right corner unless the brand says otherwise", {
  local_brand(brand_with_label("Acme"))
  expect_equal(brand_ornament_label_corner(), "top-right")
  expect_match(brand_ornament("drift", "top-right"), "<text", fixed = TRUE)
  expect_no_match(brand_ornament("drift", "bottom-left"), "<text", fixed = TRUE)
})

brand_with_label_corner <- function(corner, label = "Acme") {
  cfg <- brand_with_label(label)
  cfg$meta$`ornament-label-corner` <- corner
  cfg
}

test_that("meta: ornament-label-corner moves the label to the bottom-left ornament", {
  for (corner in c("bottom-left", "bottom", " Bottom-Left ")) {
    local_brand(brand_with_label_corner(corner))
    expect_equal(brand_ornament_label_corner(), "bottom-left", info = corner)
    expect_no_match(brand_ornament("drift", "top-right"), "<text", fixed = TRUE)
    expect_match(brand_ornament("drift", "bottom-left"), "<text", fixed = TRUE)
  }
})

test_that("an unrecognised or top label corner means the top-right", {
  for (corner in list("top", "top-right", "middle", "", 3)) {
    local_brand(brand_with_label_corner(corner))
    expect_equal(brand_ornament_label_corner(), "top-right", info = format(corner))
  }
})

test_that("the corner follows the label: no label, no text on either", {
  local_brand(brand_with_label_corner("bottom-left", label = ""))
  expect_no_match(brand_ornament("drift", "bottom-left"), "<text", fixed = TRUE)
  expect_no_match(brand_ornament("drift", "top-right"), "<text", fixed = TRUE)
})

test_that("an explicit label is drawn on whichever corner is asked for", {
  local_brand()
  expect_match(brand_ornament("drift", "bottom-left", label = "Acme", vars = TRUE), "ACME", fixed = TRUE)
  expect_match(brand_ornament("drift", "top-right", label = "Acme", vars = TRUE), "ACME", fixed = TRUE)
})

test_that("the bottom label reads upright, left to right, on the far side of the curve", {
  svg <- ornament_svg("drift", "bottom-left", 0.12, "#111111", "#222222",
                      "#333333", label = "Acme", font = "Inter",
                      label_layout = "path")
  # The turned curve is walked from its left-edge end, so the text runs
  # left to right; the offset is the other way (up, in the glyphs' frame),
  # a mirror of the top label's.
  expect_match(svg, '<path id="bk-orn-label-bl" d="M 0 26 ', fixed = TRUE)
  expect_lt(attr_num(svg, "dy"), 0)

  top <- ornament_svg("drift", "top-right", 0.12, "#111111", "#222222",
                      "#333333", label = "Acme", font = "Inter",
                      label_layout = "path")
  expect_equal(abs(attr_num(svg, "dy")) + 0.72 * attr_num(svg, "font-size"),
               attr_num(top, "dy"), tolerance = 0.05)
})

test_that("the bottom label is not drawn inside the corner's half turn", {
  svg <- ornament_svg("drift", "bottom-left", 0.12, "#111111", "#222222",
                      "#333333", label = "Acme", font = "Inter")
  start <- regexpr('<g transform="rotate(180 50 50)">', svg, fixed = TRUE)
  stop  <- regexpr("</g>", svg, fixed = TRUE)
  rotated <- substr(svg, start, stop)
  expect_no_match(rotated, "<text", fixed = TRUE)
  expect_match(svg, "<text", fixed = TRUE)
})

test_that("each corner's label path has its own id", {
  svg <- function(corner) ornament_svg("drift", corner, 0.12, "#111111", "#222222",
                                       "#333333", label = "A", font = "Inter",
                                       label_layout = "path")
  expect_match(svg("top-right"), 'id="bk-orn-label-tr"', fixed = TRUE)
  expect_match(svg("top-right"), 'href="#bk-orn-label-tr"', fixed = TRUE)
  expect_match(svg("bottom-left"), 'href="#bk-orn-label-bl"', fixed = TRUE)
})

test_that("a page's pair of web ornaments carries the label once", {
  local_brand(brand_with_label_corner("bottom-left"))
  html <- as.character(brand_ornaments_tag())
  expect_equal(lengths(regmatches(html, gregexpr("<textPath", html))), 1L)
  expect_match(html, "bk-orn-label-bl", fixed = TRUE)
})

test_that("moving the label rewrites both Typst ornaments, and only those", {
  dir <- withr::local_tempdir()
  local_brand(brand_with_label("Acme"))
  write_typst_ornaments(dir)

  local_brand(brand_with_label_corner("bottom-left"))
  wrote <- write_typst_ornaments(dir)
  expect_setequal(basename(wrote), c("drift-top-right.svg", "drift-bottom-left.svg"))
  expect_no_match(rawToChar(read_file_bytes(file.path(dir, "drift-top-right.svg"))),
                  "<text", fixed = TRUE)
  expect_match(rawToChar(read_file_bytes(file.path(dir, "drift-bottom-left.svg"))),
               ">M</text>", fixed = TRUE)
})

test_that("a label is escaped and cannot break out of the SVG", {
  local_brand()
  svg <- brand_ornament(label = "A & <b>\"x\"", vars = TRUE)
  expect_match(svg, "A &amp; &lt;B&gt;&quot;X&quot;", fixed = TRUE)
  expect_no_match(svg, "<b>", fixed = TRUE)

  # One letter per element in the standalone form: each is escaped alone.
  file <- brand_ornament(label = "A & <b>", vars = FALSE)
  expect_match(file, ">&amp;</text>", fixed = TRUE)
  expect_match(file, ">&lt;</text>", fixed = TRUE)
  expect_no_match(file, "<b>", fixed = TRUE)
})

test_that("a long label is truncated with a warning", {
  local_brand()
  expect_warning(
    svg <- brand_ornament(label = strrep("a", 40), vars = TRUE),
    "truncating"
  )
  expect_match(svg, strrep("A", orn_label_max_chars), fixed = TRUE)
  expect_no_match(svg, strrep("A", orn_label_max_chars + 1), fixed = TRUE)
})

test_that("with vars the label takes the primary colour variable", {
  local_brand(brand_with_label("Acme"))
  expect_match(brand_ornament(vars = TRUE), "fill:var(--bs-primary", fixed = TRUE)
})

test_that("a longer label is set smaller, within a floor", {
  size <- function(label) {
    svg <- ornament_svg("drift", "top-right", 0.12, "#111111", "#222222",
                        "#333333", label = label, font = "Inter")
    attr_num(svg, "font-size")
  }
  expect_gt(size("Acme"), size("Acme Group"))
  expect_gte(size(strrep("W", orn_label_max_chars)), 2.5)
})

test_that("the label sits beside the swell's curve, on the side away from the wave", {
  # The orb's centre falls on the curve, so the offset is what keeps the text
  # off the overlap: it must be positive (down, in the glyphs' frame).
  svg <- ornament_svg("drift", "top-right", 0.12, "#111111", "#222222",
                      "#333333", label = "Acme", font = "Inter",
                      label_layout = "path")
  expect_gt(attr_num(svg, "dy"), 0)
})

test_that("write_typst_ornaments rewrites only what changed", {
  dir <- withr::local_tempdir()
  local_brand()
  expect_length(write_typst_ornaments(dir), 2)       # first write: both files
  expect_length(write_typst_ornaments(dir), 0)       # unchanged: nothing
  expect_length(write_typst_ornaments(dir, overwrite = TRUE), 2)

  local_brand(brand_with_label("Acme"))
  wrote <- write_typst_ornaments(dir)                # label added: top-right only
  expect_equal(basename(wrote), "drift-top-right.svg")
  expect_match(rawToChar(read_file_bytes(wrote)), ">M</text>", fixed = TRUE)
})

test_that("write_ornaments_html rewrites only when the contents change", {
  path <- withr::local_tempfile(fileext = ".html")
  local_brand()
  expect_true(write_ornaments_html(path))
  expect_false(write_ornaments_html(path))
  expect_true(write_ornaments_html(path, overwrite = TRUE))

  local_brand(brand_with_label("Acme"))
  expect_true(write_ornaments_html(path))
  expect_match(paste(readLines(path), collapse = "\n"), "ACME", fixed = TRUE)
})
