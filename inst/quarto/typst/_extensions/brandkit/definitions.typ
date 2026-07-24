// brandkit: shared title-banner geometry.
// brandkit-banner-height must exceed the page's actual top margin — the
// one-time spacer in typst-template.typ subtracts brandkit-margin-top-assumed
// from it to reserve just enough flow space on page 1 for the banner to sit
// above the body without a gap or overlap. brandkit-margin-top-assumed must
// match the `y` value written into contributes.formats.typst.margin by
// write_extension_yml_for_quarto() in R/brand_quarto.R — if that changes,
// update this constant too, or the page-1 spacing will be off by the
// difference (a cosmetic issue, not a render failure).
#let brandkit-banner-height = 2.15in
#let brandkit-margin-top-assumed = 2.5cm
// Extra breathing room between the banner's bottom edge and where body
// content starts — purely cosmetic, doesn't affect the banner's own
// drawn size, only the one-time flow spacer in typst-template.typ.
#let brandkit-banner-gap = 0.3in

// brandkit: diagonal-stripe title-banner fill (Linux Mint wallpaper style),
// drawn as sheared polygons — no raster image involved. The primary/
// secondary split isn't a separate wedge shape layered on top; it falls
// out of which stripe each polygon belongs to, so the seam is just
// "where the stripe color changes" and stays visually continuous with
// the stripe pattern either side of it.
//
// The stripe contrast itself (not a panel drawn on top) stays at exactly
// zero — flat, unbroken `primary`, not even a per-stripe sheen — out to
// `solid-frac` of the width, which is sized to cover as far right as the
// title/subtitle text is ever allowed to run, so the text always lands on
// a calm, legible field no matter how long it is. `solid-frac` is capped
// at `seam-frac` and then pushed one stripe further still, so the solid
// field always swallows the first secondary-coloured stripe too — with
// `seam-frac` this close to `solid-frac` in practice, colour switches from
// primary straight to full-contrast secondary with no visible ramp
// in-between, i.e. deliberately as sharp a transition as the stripe grid
// allows. Because the solid/patterned boundary and the colour seam both
// fall on real stripe edges, they're angled like the rest of the pattern
// rather than a panel with a flat vertical edge cutting across the
// diagonal stripes.
#let brandkit-stripe-fill(
  pw, ph,
  primary, secondary,
  seam-frac: 0.53,
  stripe-angle: 22deg,
  n-stripes: 12,
  stripe-delta: 12%,
  solid-frac: 0.6,
) = {
  let dx = ph * calc.tan(stripe-angle)
  let p = pw / n-stripes
  let pad = int(calc.ceil(calc.abs(dx) / p)) + 2
  let seam-x = pw * seam-frac
  // Snapped down to the stripe grid (a multiple of p) rather than left as
  // a raw fraction of pw — otherwise it typically lands mid-stripe, and
  // the solid mask below clips that one stripe down to whatever sliver is
  // left past the cut, making it visibly narrower than the rest. The extra
  // `+ p` pushes the mask one full stripe further right than that —
  // deliberately covering the first patterned stripe too (omitting it),
  // since the mask and the stripes share the same grid this still lands
  // exactly on a stripe boundary rather than clipping a partial one.
  let solid-x = calc.floor(calc.min(pw * solid-frac, seam-x) / p) * p + p
  let x-min = -pad * p

  for i in range(-pad, int(calc.ceil(pw / p)) + pad) {
    let bx0 = i * p
    let bx1 = bx0 + p
    let mid-x = bx0 + p / 2
    let in-primary = mid-x < seam-x
    let base = if in-primary { primary } else { secondary }
    let local-delta = if in-primary {
      stripe-delta * calc.clamp((mid-x - solid-x) / calc.max(seam-x - solid-x, 0.001pt), 0, 1)
    } else {
      stripe-delta
    }
    let shade = if calc.rem(i, 2) == 0 { base.darken(local-delta) } else { base.lighten(local-delta * 0.85) }
    // Sheen strength is derived from local-delta itself (not a fixed
    // floor) so it is exactly zero — a genuinely flat fill, no per-stripe
    // banding — in the solid zone, and only appears once contrast ramps in.
    place(top + left, polygon(
      fill: gradient.linear(
        shade.darken(local-delta * 0.4), shade.lighten(local-delta * 0.3),
        shade.darken(local-delta * 0.2),
        angle: 90deg - stripe-angle, relative: "self",
      ),
      (bx0 + dx, 0pt), (bx1 + dx, 0pt), (bx1, ph), (bx0, ph),
    ))
  }

  // brandkit: the solid-zone stripes above are all identically-coloured
  // (local-delta is exactly 0 there), but each is still its own polygon,
  // and adjacent same-colour shapes drawn separately can show a hairline
  // seam at their shared edge from independent edge anti-aliasing. One
  // unbroken polygon spanning the whole solid zone, drawn on top, covers
  // that — there's no internal edge left to seam. Its right edge is
  // sheared with the same `dx` as every stripe, so it still meets the
  // first patterned stripe cleanly along a matching diagonal.
  place(top + left, polygon(
    fill: primary,
    (x-min + dx, 0pt), (solid-x + dx, 0pt), (solid-x, ph), (x-min, ph),
  ))
}

// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: $if(code-radius)$$code-radius$$else$0.3em$endif$
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt,
          width: 100%,
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

$if(margin-geometry)$
// Margin layout support using marginalia package
#import "@preview/marginalia:0.3.1" as marginalia: note, notefigure, wideblock

// Render footnote as margin note using standard footnote counter
// Used via show rule: #show footnote: it => column-sidenote(it.body)
// The footnote element already steps the counter, so we just display it
#let column-sidenote(body) = {
  context {
    let num = counter(footnote).display("1")
    // Superscript mark in text
    super(num)
    // Content in margin with matching number
    note(
      alignment: "baseline",
      shift: auto,
      counter: none,  // We display our own number from footnote counter
    )[
      #super(num) #body
    ]
  }
}

// Note: Margin citations are now emitted directly from Lua as #note() calls
// with #cite(form: "full") + locator text, preserving citation locators.

// Utility: compute padding for each side based on side parameter
#let side-pad(side, left-amount, right-amount) = {
  let l = if side == "both" or side == "left" or side == "inner" { left-amount } else { 0pt }
  let r = if side == "both" or side == "right" or side == "outer" { right-amount } else { 0pt }
  (left: l, right: r)
}

// body-outset: extends ~15% into margin area
#let column-body-outset(side: "both", body) = context {
  let r = marginalia.get-right()
  let out = 0.15 * (r.sep + r.width)
  pad(..side-pad(side, -out, -out), body)
}

// page-inset: wideblock minus small inset from page boundary
#let column-page-inset(side: "both", body) = context {
  let l = marginalia.get-left()
  let r = marginalia.get-right()
  // Inset is a small fraction of the extension area (wideblock stops at far)
  let left-inset = 0.15 * l.sep
  let right-inset = 0.15 * (r.sep + r.width)
  wideblock(side: side)[#pad(..side-pad(side, left-inset, right-inset), body)]
}

// screen-inset: full width minus `far` distance from edges
#let column-screen-inset(side: "both", body) = context {
  let l = marginalia.get-left()
  let r = marginalia.get-right()
  wideblock(side: side)[#pad(..side-pad(side, l.far, r.far), body)]
}

// screen-inset-shaded: screen-inset with gray background
#let column-screen-inset-shaded(body) = context {
  let l = marginalia.get-left()
  wideblock(side: "both")[
    #block(fill: luma(245), width: 100%, inset: (x: l.far, y: 1em), body)
  ]
}
$endif$

$if(highlighting-definitions)$
// syntax highlighting functions from skylighting:
$highlighting-definitions$

$endif$
