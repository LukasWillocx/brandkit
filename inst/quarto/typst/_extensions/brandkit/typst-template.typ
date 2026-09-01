// brandkit: Typst article template
//
// Based on Quarto's default typst-template.typ (src/resources/formats/typst/
// pandoc/quarto/typst-template.typ), extended with:
//   - a coloured footer rule (primary) with secondary-coloured text
//   - booktabs-style table rules, a tinted header row, and zebra striping
//   - links defaulting to the brand's primary colour
// `brand-color` is a Typst constant Quarto injects automatically whenever
// a `_brand.yml` is active for the format — see
// https://quarto.org/docs/authoring/brand.html
//
// The title/subtitle/author/date banner and the logo are NOT handled
// here — see page.typ, which draws the full-bleed two-tone banner (and,
// when there's no title, the plain corner logo) as a page background so
// it can span the full physical page width, ignoring margins. This file
// only reserves matching vertical space on page 1 (see the `v(...)` call
// below) and lets the abstract, if any, flow normally beneath it.

#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  accent: none,
  secondary-accent: none,
  foreground: none,
  background: none,
  // brandkit: the inset (print) banner, passed in rather than referenced
  // directly. page.typ builds it, but page.typ is emitted *after* this
  // file (see template.typ's partial order), and a Typst closure
  // captures its defining scope — so article() cannot see a top-level
  // binding declared later in the document. typst-show.typ comes after
  // both and hands it over, which is the same route brand-color takes to
  // reach `accent`/`foreground` here.
  banner: none,
  // brandkit: poster layout. The columns themselves are page columns
  // set in page.typ; what `poster` changes here is how the masthead is
  // emitted (spanning those columns rather than sitting above a single
  // flow) and that the report's running footer gives way to an optional
  // standing band. `poster-scale` is the same factor the type ramp was
  // scaled by at scaffold time, reused for the handful of fixed lengths
  // — the masthead's clearance, the footer rule — that would otherwise
  // stay letter-sized on A0.
  poster: false,
  poster-footer: none,
  poster-scale: 1.0,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  // brandkit: raw/code text (inline spans and fenced blocks alike) is
  // pinned to the exact same `fontsize` as body text, so the two always
  // match exactly. This is only safe because `fontsize` is guaranteed
  // absolute (an explicit pt value written into _extension.yml by
  // write_extension_yml_for_quarto() — see its comment for why) rather
  // than a relative Typst `em` — reusing a relative size here, inside
  // text already scaled by that same relative factor once, would
  // compound multiplicatively instead of matching.
  show raw: set text(size: fontsize)
  show raw: set text(font: codefont) if codefont != none

  // brandkit: code is typeset literally, so the font's contextual
  // alternates are switched off inside raw. Text faces routinely map
  // ASCII operator sequences onto single glyphs through `calt` — Inter
  // turns `<-` into a left arrow and `->` into a right one — which
  // silently misrepresents the source: an R assignment stops looking
  // like an R assignment, and the glyph can't be copied back out of the
  // PDF as the characters that were written. Programming faces do the
  // same deliberately (JetBrains Mono, Fira Code), and the same argument
  // applies to them, so this is switched off for every family rather
  // than only for the accidental cases. `ligatures: false` does NOT
  // cover this — these substitutions are `calt`, not `liga`.
  show raw: set text(features: (calt: 0))

  // brandkit: fenced-code background, derived from the brand rather than
  // the fixed luma(230) Quarto's template ships. That constant is a
  // light grey whatever the brand is, which is merely off-palette in a
  // light document but breaks a dark one outright: the page goes dark
  // and `foreground` goes near-white, while the block stays light, so
  // every token the highlighter doesn't colour — punctuation, braces,
  // plain identifiers — lands at about 1.2:1 and disappears.
  //
  // Mixing a little of the brand's secondary into the background instead
  // keeps the block a shade off the page it sits on, carries the same
  // accent the banner rail and inline code already use, and follows the
  // brand into dark mode automatically. 12% is enough to read as a
  // deliberate tint rather than a neutral grey while leaving the block
  // firmly a background: across the light, tinted and dark brands this
  // was checked against, foreground on this fill stays between 10.4:1
  // and 15.2:1.
  //
  // Falls back to foreground when a brand defines no secondary, since a
  // tint of nothing would leave the block indistinguishable from the
  // page.
  //
  // Only the fill is set here; width, inset and the brand-derived corner
  // radius stay in definitions.typ, and its luma(230) still applies
  // whenever article() is called without these parameters — they are
  // always supplied by typst-show.typ, so in practice that is the
  // direct-call case rather than anything Quarto renders.
  let code-block-tint = if secondary-accent != none { secondary-accent } else { foreground }
  let code-block-fill = if code-block-tint != none and background != none {
    color.mix((code-block-tint, 12%), (background, 88%))
  } else {
    none
  }
  show raw.where(block: true): set block(fill: code-block-fill) if code-block-fill != none

  // brandkit: inline code (raw spans set with single backticks in running
  // body text) gets a colour of its own — a 75/25 blend weighted toward
  // the brand's secondary accent, with its foreground/dark colour
  // rounding it out — so it stands out from surrounding prose (and reads
  // as distinct from primary-coloured headings/links/footer). Fenced
  // code blocks are deliberately left out of this (raw.where(block:
  // false) only): they already stand out via the shaded block background
  // set in definitions.typ, and tinting every token in a whole block the
  // same flat colour would fight with syntax highlighting there.
  let inline-code-color = if secondary-accent != none and foreground != none {
    color.mix((secondary-accent, 75%), (foreground, 25%))
  } else if secondary-accent != none {
    secondary-accent
  } else if accent != none {
    accent
  } else {
    black
  }
  show raw.where(block: false): set text(fill: inline-code-color)

  set heading(numbering: sectionnumbering)

  // brandkit: the page footer — a coloured rule over the report's
  // title/page-number line, or over the poster's standing band.
  //
  // Both are built into one value and applied by a single, unconditional
  // `set page`. That shape is load-bearing rather than tidiness: a Typst
  // `set` rule lives only to the end of the block it is written in, so
  // the obvious `if accent != none { set page(footer: ...) }` compiles
  // without complaint and then applies to precisely nothing — the
  // branded footer silently never appears, and Typst's own centred page
  // number shows through in its place.
  //
  // The fallbacks differ deliberately. A report with no brand accent to
  // draw with falls back to `auto`, leaving Quarto's own footer alone. A
  // poster falls back to `none`: it is one sheet, so a running footer
  // carrying a title and a page number is noise beside a title already
  // six inches tall above it. What a poster wants there is a standing
  // band for what the masthead has no room for — affiliations, funding,
  // a URL — and that is opt-in via `poster-footer:` in the document
  // YAML, so an unrequested footer should not appear at all.
  let footer-text-color = if secondary-accent != none { secondary-accent } else { accent }
  let page-footer = if poster {
    if poster-footer != none and accent != none {
      [
        #line(length: 100%, stroke: (0.4pt * poster-scale) + accent.transparentize(50%))
        #v(0.35em)
        #text(size: 0.8em, fill: footer-text-color, poster-footer)
      ]
    } else {
      none
    }
  } else if accent != none {
    context [
      #line(length: 100%, stroke: 0.4pt + accent.transparentize(50%))
      #v(3pt)
      #grid(
        columns: (1fr, auto),
        align(left)[#text(size: 8pt, fill: footer-text-color)[#if title != none { title }]],
        align(right)[#text(size: 8pt, fill: footer-text-color)[#counter(page).display("1")]]
      )
    ]
  } else {
    auto
  }
  set page(footer: page-footer)

  // brandkit: booktabs-style tables — a rule under the header row only,
  // no outer top/bottom rules (those sat flush against the table's own
  // edges and just doubled up), no vertical rules — centred at 90% of
  // the line width. Header row gets a light primary tint, alternating
  // body rows get an even lighter tint (zebra striping) — kept light
  // enough that the pandoc-generated cell text, whatever colour it
  // already is, stays legible without needing a text-colour override.
  let table-rule-color = if accent != none { accent } else { black }
  let table-fill-color = if accent != none { accent } else { none }
  show table: it => align(center, block(
    width: 90%,
    inset: 0pt,
    it
  ))
  set table(
    inset: 7pt,
    stroke: (x, y) => if y == 0 { (bottom: 0.5pt + table-rule-color) } else { none },
    fill: (x, y) => if table-fill-color == none {
      none
    } else if y == 0 {
      table-fill-color.lighten(80%)
    } else if calc.even(y) {
      table-fill-color.lighten(92%)
    } else {
      none
    }
  )

  // brandkit: links default to the brand's primary colour when no
  // explicit linkcolor is set in the document YAML (an explicit
  // linkcolor: still takes precedence)
  let link-color = if linkcolor != none { rgb(content-to-string(linkcolor)) } else { accent }
  show link: set text(fill: link-color) if link-color != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  // brandkit: title, subtitle, authors and date are rendered as the
  // two-tone banner built in page.typ, not here. Which of the two
  // layouts is in force decides what this has to do:
  //
  //   inset (print) — the panel is flow content, so it is simply emitted
  //     at the top of the body and takes its own space. Nothing is
  //     reserved, and no assumption about the top margin is involved.
  //   full-bleed — the panel lives in the page background and occupies
  //     no flow space at all, so a one-time spacer stands in for it
  //     (consumed immediately at the start of flow, leaving later pages
  //     unaffected) to keep body content from starting underneath it.
  //
  // Either way the abstract, if any, flows normally below. `thanks:`
  // footnotes aren't supported in either layout — footnote placement
  // needs normal document flow, and the banner is a self-contained panel
  // — so that parameter is kept for signature compatibility but
  // currently has no effect.
  if title != none {
    if poster {
      // brandkit: the masthead has to span the page's columns, and the
      // only thing in Typst that escapes a column is a float scoped to
      // the parent. `top` rather than the flow position because a
      // parent float is placed on the page, not where it was written.
      //
      // `clearance` is the gap to the column content below — the same
      // 0.3in the reports leave under their banner, scaled with the
      // type ramp, since 0.3in reads as breathing room under a 22pt
      // masthead and as a hairline under an 80pt one.
      place(
        top,
        float: true,
        scope: "parent",
        clearance: brandkit-banner-gap * poster-scale,
        banner,
      )
    } else if banner != none {
      banner
      v(brandkit-banner-gap)
    } else {
      v(calc.max(0pt, brandkit-banner-height - brandkit-margin-top-assumed) + brandkit-banner-gap)
    }
  }

  if abstract != none {
    block(inset: (bottom: 2em))[
      #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}
