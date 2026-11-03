// brandkit: Typst show/metadata bridge
//
// Based on Quarto's default typst-show.typ (src/resources/formats/typst/
// pandoc/quarto/typst-show.typ). Adds brand-aware defaults: headings,
// the title rule, links, the footer text and the table accent colour fall
// back to `brand-color.primary`; the subtitle falls back to
// `brand-color.secondary`; the footer rule is drawn in
// `brand-color.foreground`; inline code text is tinted a blend of
// `brand-color.secondary` and `brand-color.foreground` (see
// brandkit-inline-code below).
// The brand logo itself is handled entirely by Quarto's own typst pipeline
// (page.typ, via the pandoc `$logo$` variable) as a page background — not
// something this file touches.

// brandkit: inline code. inline-code.lua rewrites every inline code span to
// a call of this, so it is plain text and not `raw`: pandoc's highlighter
// emits inline code and each token of a fenced block as the same `raw`
// element, which leaves a show rule on `raw` no way to treat the two
// differently. As text it takes the body font and size from the page, and
// is set apart by a colour of its own — a 75/25 blend of the brand's
// secondary accent and its foreground, so it reads as distinct from the
// primary-coloured headings, links and footer. Contextual alternates are
// off, so a face that turns an ASCII arrow into one glyph shows the
// characters that were typed. Defined here because `brand-color` is only
// in scope from this point on.
#let brandkit-inline-code(s) = text(
  fill: color.mix((brand-color.secondary, 75%), (brand-color.foreground, 25%)),
  features: (calt: 0),
  hyphenate: false,
  s,
)

$if(highlighting-definitions)$
// brandkit: a fenced block's box. Skylighting draws it with a fixed
// background from the highlighting theme (a grey one step off a light page,
// which is close to invisible), set as an explicit argument, so no rule can
// override it from outside; the one place to change it is the block itself,
// as it passes through. The colour is the one the HTML templates give code
// (the brand's primary mixed 7% into the page, in sRGB), and the same as
// article()'s fill for blocks that are not highlighted. A show rule that
// returns a block matches its own result, hence the early return once the
// fill is already right. Only the fill changes: the syntax colours are the
// highlighting theme's, which nothing else here touches. The corners are
// the same: Skylighting hard-codes a 2pt radius, so the brand's own
// border-radius (the value the HTML templates round code with) is set here
// along with the fill.
#let brandkit-skylighting = Skylighting
#let Skylighting(..args) = {
  let fill = color.mix((brand-color.primary, 7%), (brand-color.background, 93%), space: rgb)
  let radius = $if(code-radius)$$code-radius$$else$0.3em$endif$
  show block: it => if it.fill == fill { it } else {
    let fields = it.fields()
    let _ = fields.remove("body")
    block.with(..fields, fill: fill, radius: radius)(it.body)
  }
  brandkit-skylighting(..args)
}
$endif$

#show: doc => article(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(by-author)$
  authors: (
$for(by-author)$
$if(it.name.literal)$
    ( name: [$it.name.literal$],
      affiliation: [$for(it.affiliations)$$it.name$$sep$, $endfor$],
      email: [$it.email$] ),
$endif$
$endfor$
    ),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
$if(abstract)$
  abstract: [$abstract$],
  abstract-title: "$labels.abstract$",
$endif$
$if(mainfont)$
  font: ("$mainfont$",),
$elseif(brand.typography.base.family)$
  font: $brand.typography.base.family$,
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$elseif(brand.typography.base.size)$
  fontsize: $brand.typography.base.size$,
$endif$
$if(title)$
$if(brand.typography.headings.family)$
  heading-family: $brand.typography.headings.family$,
$elseif(mainfont)$
  heading-family: ("$mainfont$",),
$endif$
$if(brand.typography.headings.weight)$
  heading-weight: $brand.typography.headings.weight$,
$endif$
$if(brand.typography.headings.style)$
  heading-style: "$brand.typography.headings.style$",
$endif$
$if(brand.typography.headings.color)$
  heading-color: $brand.typography.headings.color$,
$else$
  heading-color: brand-color.primary,
$endif$
$if(brand.typography.headings.line-height)$
  heading-line-height: $brand.typography.headings.line-height$,
$endif$
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
$if(mathfont)$
  mathfont: ($for(mathfont)$"$mathfont$",$endfor$),
$endif$
$if(codefont)$
  codefont: ($for(codefont)$"$codefont$",$endfor$),
$elseif(brand.typography.monospace.family)$
  codefont: $brand.typography.monospace.family$,
$endif$
$if(linestretch)$
  linestretch: $linestretch$,
$endif$
$if(thanks)$
  thanks: [$thanks$],
$endif$
$if(linkcolor)$
  linkcolor: [$linkcolor$],
$endif$
$if(citecolor)$
  citecolor: [$citecolor$],
$endif$
$if(filecolor)$
  filecolor: [$filecolor$],
$endif$
$if(keywords)$
  keywords: ($for(keywords)$"$keywords$",$endfor$),
$endif$
$if(toc)$
  toc: $toc$,
$endif$
$if(toc-title)$
  toc_title: [$toc-title$],
$endif$
$if(toc-indent)$
  toc_indent: $toc-indent$,
$endif$
  toc_depth: $toc-depth$,
  accent: brand-color.primary,
  secondary-accent: brand-color.secondary,
  foreground: brand-color.foreground,
  // Used together with `secondary-accent` to derive the fenced-code
  // background — see the code-block-fill comment in typst-template.typ.
  background: brand-color.background,
$if(banner-inset)$
$if(title)$
  // Print layout only: the inset banner panel built in page.typ. Passed
  // through here because this file is the first point at which both
  // article() and the panel are in scope — see the `banner` parameter's
  // comment in typst-template.typ. Omitted entirely for the full-bleed
  // format, where the banner is drawn as a page background instead and
  // article() reserves flow space for it rather than emitting it.
  //
  // The surrounding title guard is not redundant with article()'s own
  // title check: page.typ only defines brandkit-banner-content inside
  // its own title branch, so referencing it in a titleless document is
  // an unknown-variable error at compile time, before article() ever
  // gets to decide whether to draw a banner. (Note for editors: never
  // write a pandoc directive literally in these comments — the template
  // is preprocessed before Typst ever sees it, and one written in prose
  // here is parsed as real markup and breaks every render.)
  banner: brandkit-banner-content,
$endif$
$endif$
$if(drift)$
  drift: true,
$endif$
$if(poster)$
  // Poster layout only. The column count itself doesn't come through
  // here — page.typ reads `columns` straight into the page setup — but
  // article() still needs to know it is laying out a poster, so that
  // the masthead is emitted as a column-spanning float and the running
  // footer is replaced by the standing band.
  poster: true,
  poster-scale: $poster-scale$,
$if(poster-footer)$
  poster-footer: [$poster-footer$],
$endif$
$endif$
  doc,
)
