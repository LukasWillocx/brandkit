test_that("css_length_pt_num converts to points against a 16px / 12pt root", {
  expect_equal(css_length_pt_num("12pt"), 12)
  expect_equal(css_length_pt_num("16px"), 12)
  expect_equal(css_length_pt_num("1rem"), 12)
  expect_equal(css_length_pt_num("1.5em"), 18)
})

test_that("css_length_pt_num returns NULL for anything it cannot place", {
  expect_null(css_length_pt_num(NULL))
  expect_null(css_length_pt_num(""))
  expect_null(css_length_pt_num("large"))
  expect_null(css_length_pt_num("10vh"))
  expect_null(css_length_pt_num("1.2"))
})

test_that("css_length_to_typst_pt formats, scales and falls back", {
  expect_equal(css_length_to_typst_pt("1rem"), "12pt")
  expect_equal(css_length_to_typst_pt("1rem", scale = 0.5), "6pt")
  expect_equal(css_length_to_typst_pt("0.9rem"), "10.8pt")
  expect_null(css_length_to_typst_pt("bogus"))
  expect_equal(css_length_to_typst_pt("bogus", fallback = "11pt"), "11pt")
})

test_that("css_rem_to_typst_em maps rem to em and keeps a fallback", {
  expect_equal(css_rem_to_typst_em("0.75rem"), "0.75em")
  expect_equal(css_rem_to_typst_em("2rem"), "2em")
  expect_equal(css_rem_to_typst_em(NULL), "0.3em")
  expect_equal(css_rem_to_typst_em(""), "0.3em")
  expect_equal(css_rem_to_typst_em("big", fallback = "1em"), "1em")
})

test_that("poster_type_scale stays within its 1-4 clamp for every sheet", {
  for (paper in names(poster_paper_mm)) {
    for (cols in 1:4) {
      s <- poster_type_scale(paper, cols)
      expect_gte(s, 1)
      expect_lte(s, 4)
    }
  }
})

test_that("poster_type_scale gives a bigger scale on a bigger sheet", {
  expect_gt(poster_type_scale("a0", 3), poster_type_scale("a2", 3))
})

test_that("poster_type_scale falls back to A0 for an unknown paper", {
  expect_equal(poster_type_scale("tabloid", 3), poster_type_scale("a0", 3))
  expect_equal(poster_type_scale(NULL, 3), poster_type_scale("a0", 3))
  expect_equal(poster_type_scale("A0", 3), poster_type_scale("a0", 3))
})
