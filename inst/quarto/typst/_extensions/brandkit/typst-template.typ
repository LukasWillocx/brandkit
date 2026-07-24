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

  // brandkit: coloured footer rule (primary) with title + page number
  // (secondary, falling back to primary), only when a brand accent
  // colour is available (i.e. used together with _brand.yml)
  let footer-text-color = if secondary-accent != none { secondary-accent } else { accent }
  if accent != none {
    set page(footer: context [
      #line(length: 100%, stroke: 0.4pt + accent.transparentize(50%))
      #v(3pt)
      #grid(
        columns: (1fr, auto),
        align(left)[#text(size: 8pt, fill: footer-text-color)[#if title != none { title }]],
        align(right)[#text(size: 8pt, fill: footer-text-color)[#counter(page).display("1")]]
      )
    ])
  }

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

  // brandkit: title, subtitle, authors, and date are rendered as part of
  // the full-bleed two-tone banner in page.typ's page background, not
  // here — this just reserves matching vertical space on page 1 (a
  // one-time spacer consumed immediately at the start of flow, so later
  // pages are unaffected) and lets the abstract, if any, flow normally
  // right below it. `thanks:` footnotes aren't supported in the banner
  // layout — footnote placement needs normal document flow, which
  // page-background content isn't part of — so that parameter is kept
  // for signature compatibility but currently has no effect.
  if title != none {
    v(calc.max(0pt, brandkit-banner-height - brandkit-margin-top-assumed) + brandkit-banner-gap)
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
