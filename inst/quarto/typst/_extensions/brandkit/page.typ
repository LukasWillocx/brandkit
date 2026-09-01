$if(poster)$
// brandkit: poster layout — one landscape sheet, no page numbering.
//
// Real *page* columns, not a `columns()` block on the flow. The two
// look identical when the content happens to fill the sheet and differ
// sharply when it does not: a `columns()` block balances, shrinking to
// the least height its content fits in, which on a poster means the
// material floats as a slab in the upper half of the sheet — and,
// because the cards are unbreakable and so give the balancer only
// coarse split points, it will happily settle on a height that leaves
// the third column completely empty. Page columns fill top-to-bottom in
// order, which is how a poster is read and how every poster template
// behaves.
//
// The cost is that the masthead can no longer just be flow content
// emitted before the columns — it has to span them. That is what
// `place(float: true, scope: "parent")` in typst-template.typ is for.
//
// `flipped` rather than a custom width/height so the paper stays a
// named size: Typst knows "a0" through "a10", and print shops speak the
// same names. An explicit `papersize:` in the document YAML still wins,
// but note that the type ramp is scaled at scaffold time from the paper
// passed to create_brand_quarto_poster() — changing the paper here
// without re-scaffolding leaves the text sized for the old sheet.
#set page(
  paper: $if(papersize)$"$papersize$"$else$"a0"$endif$,
  flipped: true,
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$else$
  margin: (x: 1.5in, y: 1.5in),
$endif$
  numbering: none,
  columns: $if(columns)$$columns$$else$3$endif$,
  // Typst lowers the footer 30% of the way into the bottom margin by
  // default, which is sized for a page-number-and-rule at 8pt. The
  // poster's standing band is set at poster scale and several times
  // that tall, so the default drops it off the bottom edge of the
  // sheet. Anchored flush to the text region instead, and the band
  // takes its own space downward from there.
  footer-descent: 0pt,
)
// Wider than Typst's own 4%, which is sized for a page read at arm's
// length; at a foot per column the default reads as cramped. Set on the
// `columns` element rather than passed to page(), which has no gutter
// parameter of its own.
#set columns(gutter: 5%)
$else$
#set page(
  paper: $if(papersize)$"$papersize$"$else$"us-letter"$endif$,
$if(margin-geometry)$
  // Margins handled by marginalia.setup below
$elseif(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$else$
  margin: (x: 1.25in, y: 1.25in),
$endif$
  numbering: $if(page-numbering)$"$page-numbering$"$else$none$endif$,
  columns: $if(columns)$$columns$$else$1$endif$,
)
$endif$
$if(title)$
// brandkit: the diagonal-stripe title banner, drawn by
// brandkit-stripe-fill in definitions.typ as sheared polygons in
// brand-color.primary/secondary — no raster image involved.
//
// The same banner serves two layouts, which differ only in the container
// it is drawn into:
//
//   full-bleed (default) — the panel spans the whole physical page
//     width from the page background, ignoring margins.
//     typst-template.typ reserves matching vertical space in the flow so
//     body content starts below it rather than underneath it.
//   inset (`banner-inset`, written by create_brand_quarto_print_pdf) —
//     the panel is ordinary flow content sized to the text measure, so
//     no ink crosses the margin. Full-bleed needs a printer that can
//     bleed; on an ordinary one the panel either clips at the
//     unprintable edge or leaves a white hairline frame around itself.
//
// Everything inside the panel — the type ramp, the fitted gap, the rail,
// the logo — is identical between the two, so it lives in one function
// parameterised by the panel's own size rather than being written twice.
// `min-h` is the panel's design height. With grow: false it is also the
// final height — the full-bleed banner has to be exactly
// brandkit-banner-height, because typst-template.typ reserves that much
// flow space for it and the two would otherwise disagree. With
// grow: true (the inset panel, which owns its space in the flow) it is a
// floor instead, and a title too long to fit makes the panel taller
// rather than being clipped by it.
//
// `type-scale` multiplies the whole ramp at once. The report layouts
// leave it at 1; the poster raises it, because a masthead sized for a
// letter page is a caption on A0. It is a single factor rather than
// three separate sizes so the ramp's internal proportions — and the
// spacers derived from them below — survive the change untouched.
#let brandkit-banner-panel(pw, min-h, pad-l, radius: 0pt, grow: false, type-scale: 1.0) = {
  let seam-frac = 0.53
  [
      #let text-safe-w = pw * seam-frac - pad-l - 0.25in
      // brandkit: the banner's type ramp. Named here rather than inlined
      // at each use so the spacers below can be derived from the sizes
      // they actually separate — the two are a single rhythm, and tuning
      // one without the other is what made this stack look arbitrary.
      //
      // The author/date line is the quietest step, but it still has to
      // read as deliberate rather than incidental. At the 8.5pt it used
      // to be it sat well below the body text of any normal brand (a
      // 1rem base is 12pt, and brandkit's own default is larger still),
      // so the one line naming the author looked like a footnote that
      // had drifted upwards.
      #let title-size = 22pt * type-scale
      #let subtitle-size = 13.5pt * type-scale
      #let meta-size = 11pt * type-scale
      // brandkit: the rail deliberately overruns the text it sits under,
      // stopping short of the seam rather than tracking any line's
      // length — that is what makes it read as a structural edge the
      // group rests on rather than an underline belonging to one line of
      // type. It stays inside the solid primary field (which runs a full
      // stripe past seam-frac), so it never crosses onto the stripes
      // where a thin secondary line would disappear against them.
      #let rail-w = text-safe-w - 0.25in
      // brandkit: the rail and the author/date line share one accent —
      // the brand's secondary blended 30% toward white, matching the way
      // every other element in the banner is lifted toward white against
      // the primary field. Raw secondary is mixed to sit on the page,
      // not on a saturated primary panel, so it reads heavy here; the
      // lift also buys contrast rather than costing it (5.17:1 -> 7.23:1
      // against the default primary, clearing AAA for normal text).
      #let banner-accent = brand-color.secondary.lighten(30%)
      // brandkit: the banner owns its vertical rhythm instead of
      // inheriting the body's, which it otherwise does — this content
      // sits in a page background, but Typst still resolves body text
      // styles into it (that inheritance is also what gets the brand
      // font here, so it can't simply be cut off).
      //
      // Zeroing par/block spacing is the load-bearing part. Left alone,
      // Typst adds its own paragraph and block spacing on top of the
      // explicit v() spacers, and because that spacing is an em of the
      // *body* size, the banner's proportions end up driven by
      // typography.base.size — a setting with nothing to do with the
      // banner. Measured across a 14.4pt and a 9pt brand base, with
      // identical banner sizes: the title/subtitle gap moved 25.9pt ->
      // 24pt and the subtitle/date gap 25.4pt -> 15.8pt. At 14.4pt the
      // two gaps came out equal (25.9 vs 25.4), which is what made the
      // three lines read as three unrelated items rather than a title
      // followed by its supporting detail.
      //
      // justify: false because a wrapping subtitle would otherwise be
      // stretched to the block's full width. leading stays in em so a
      // title that wraps spaces its own lines off its own 22pt rather
      // than off the body size — a touch tighter than the 0.65em body
      // default, which is right for display type, but not so tight
      // that a three-line title knots together.
      //
      // These sit outside the block below rather than inside it because
      // the measurements further down have to see the same styles the
      // final layout uses, or the fitted gap is computed against the
      // wrong heights.
      #set par(justify: false, leading: 0.5em, spacing: 0pt)
      #set block(spacing: 0pt)
      #let block-w = pw * 0.55
      #let title-content = text(
          fill: white,
          size: title-size,
          $if(brand.typography.headings.weight)$
          weight: $brand.typography.headings.weight$,
          $else$
          weight: "bold",
          $endif$
          $if(brand.typography.headings.family)$
          font: $brand.typography.headings.family$,
          $elseif(mainfont)$
          font: ("$mainfont$",),
          $endif$
        )[$title$]
      // brandkit: the subtitle, rail and author/date line are one group,
      // set off from the title as a unit — hence the fitted gap above it
      // (computed below) and much tighter spacing within it. Even
      // spacing gives three isolated lines; this gives a title plus its
      // detail.
      #let group-content = [
        $if(subtitle)$
        // Narrower than the title's own block — the title is large/bold
        // enough to stay legible wherever it wraps, but the smaller
        // subtitle wraps late enough at the title's full width that it
        // can run past the solid field and into the stripes.
        #block(width: text-safe-w, text(fill: white.transparentize(15%), size: subtitle-size)[$subtitle$])
        $endif$
        $if(date)$
        $if(subtitle)$
        #v(0.75 * subtitle-size)
        $endif$
        #line(length: rail-w, stroke: 0.75pt + banner-accent)
        #v(0.75 * subtitle-size)
        // brandkit: set in the brand's secondary — the same colour as
        // the rail above it and the stripes on the right — so the accent
        // reads as one idea rather than three unrelated golds. Full
        // opacity, not the transparentized white used for the subtitle:
        // secondary on primary is 5.17:1 for the default brand, which
        // clears WCAG AA for normal text, and thinning it with
        // transparency would drop it below. The slight tracking is there
        // because a coloured line this size sits lighter on the eye than
        // white does at the same weight.
        #block(width: text-safe-w, text(fill: banner-accent, size: meta-size, tracking: 0.04em)[$if(by-author)$$for(by-author)$$it.name.literal$$sep$, $endfor$ · $endif$$date$])
        $endif$
      ]
      // brandkit: the whole stack hangs off the bottom edge rather than
      // being centred, so the supporting group sits at a fixed distance
      // from the banner's lower edge however long the title runs. Under
      // `horizon` the group drifted vertically whenever the title
      // wrapped, which is what made the spacing feel unpredictable
      // between documents.
      //
      // The catch is that a bottom-anchored stack grows straight up into
      // the banner's top edge, and the banner is a fixed
      // brandkit-banner-height with clip: true — a three-line title
      // overran it and lost its first line entirely. So the gap between
      // title and group is fitted rather than fixed: it opens to
      // gap-ideal when there is room (every ordinary title), and closes
      // toward gap-min as the title grows, spending slack space before
      // spending legibility. Both measurements run under the same style
      // rules as the final layout, set above.
      #context {
        // Fractions of the panel's *design* height rather than fixed
        // lengths, so the inset panel (shorter than the full-bleed one)
        // keeps the same proportions instead of looking bottom-heavy.
        // Deriving them from min-h rather than the final height also
        // keeps the arithmetic non-circular once the panel can grow.
        let pad-b-ideal = 0.16 * min-h
        let pad-b-min = 0.084 * min-h
        let pad-t = 0.075 * min-h
        let gap-ideal = 1.2 * title-size
        let gap-min = 0.45 * title-size
        // Parenthesised deliberately: Typst ends a statement at the line
        // break, so a trailing `+ ...` on the next line would parse as a
        // separate unary-plus expression and get joined into the block's
        // return value instead of added here.
        let stack-h = (
          measure(block(width: block-w, title-content)).height
            + measure(block(width: block-w, group-content)).height
        )
        // A growing panel simply takes the height its content wants, so
        // nothing below ever has to give. A fixed one is capped at min-h
        // and falls back on the two-stage squeeze.
        let ph = if grow {
          calc.max(min-h, pad-t + stack-h + gap-ideal + pad-b-ideal)
        } else {
          min-h
        }
        // Two stages, in order of what costs least to give up. The gap
        // closes first, because slack space between two groups is the
        // cheapest thing in the composition to spend. Only once it is at
        // gap-min does the bottom inset start to give, and never past
        // pad-b-min. An ordinary title never reaches stage two, so the
        // group keeps its fixed distance from the lower edge in every
        // normal document; a three-line title in the fixed-height
        // full-bleed banner trades a few points of that inset rather
        // than losing its first line off the top.
        let gap = calc.max(gap-min,
          calc.min(gap-ideal, ph - pad-t - pad-b-ideal - stack-h))
        let pad-b = calc.max(pad-b-min,
          calc.min(pad-b-ideal, ph - pad-t - stack-h - gap))
        // The stripe field is drawn here, inside the height computation,
        // rather than at the top of this function: it has to be sized to
        // the final ph, which is not known until the content above has
        // been measured.
        box(width: pw, height: ph, radius: radius, clip: true)[
          #brandkit-stripe-fill(pw, ph, brand-color.primary, brand-color.secondary, seam-frac: seam-frac, solid-frac: 0.6)
          $if(logo)$
          // brandkit: top-right, inset into the secondary-colour zone —
          // not sharing the left column with the title. That column's
          // text block is drawn after the logo, so if the logo sat in the
          // same column a tall title/subtitle/date stack could paint over
          // it and hide it. The secondary zone starts at seam-frac of the
          // panel width at every height (give or take one stripe's
          // width), so a small inset from the top-right corner stays
          // inside it regardless.
          #place(top + right, dx: -0.45 * pad-l, dy: 0.57 * pad-l, image("$logo.path$", width: $logo.width$$if(logo.alt)$, alt: "$logo.alt$"$endif$))
          $endif$
          #place(bottom + left, dx: pad-l, dy: -pad-b, block(width: block-w)[
            #title-content
            #v(gap)
            #group-content
          ])
        ]
      }
  ]
}

$if(poster)$
// brandkit: poster masthead — the same panel the report layouts use, at
// poster scale. It is inset (flow content sized to the text measure)
// for the same reason the print layout is: a poster is printed, and
// large-format printers have an unprintable edge like any other.
//
// The design height is a fraction of the panel's own width rather than
// a fixed length, so it holds its proportions across A0/A1/A2 without a
// per-paper constant. 0.105 puts the masthead at roughly an eighth of a
// landscape sheet's height — enough to carry a title at this size, not
// so much that it eats a column's worth of body space.
#let brandkit-poster-scale = $poster-scale$
#let brandkit-banner-content = layout(size => brandkit-banner-panel(
  size.width,
  size.width * 0.105,
  0.42in * brandkit-poster-scale,
  radius: $if(code-radius)$$code-radius$$else$0.3em$endif$,
  grow: true,
  // 1.6x the body's own scale factor. The report's masthead runs at
  // 22pt over a 12pt body (1.8x); a poster is read at two distances
  // rather than one — the title from across a hall, the body from
  // arm's length — so the gap between them has to open up rather than
  // stay proportional.
  type-scale: brandkit-poster-scale * 1.6,
))

// brandkit: the section card. Defined here rather than in
// definitions.typ because it needs `brand-color`, and Quarto injects
// that constant via header-includes — which template.typ emits after
// definitions.typ but before this file. A Typst closure captures its
// defining scope, so a card function declared in definitions.typ would
// fail with an unknown-variable error however late it were called.
//
// Called from the body by poster.lua, which turns every level-2 section
// into one of these. Colours are therefore baked in here rather than
// passed at the call site — the filter emits nothing but the title and
// the body.
#let brandkit-card(title: none, body) = {
  let radius = $if(code-radius)$$code-radius$$else$0.3em$endif$
  let pad = 1.1em
  block(
    width: 100%,
    radius: radius,
    clip: true,
    // A tint of the brand's primary over its own background, rather
    // than a fixed grey: it follows the brand into a dark palette
    // instead of stranding dark text on a light panel, and it is the
    // same move the fenced-code fill in typst-template.typ makes, so
    // the poster's two panelled surfaces are visibly related.
    fill: color.mix((brand-color.primary, 7%), (brand-color.background, 93%)),
    // Deliberately unbreakable. In a three-column poster a card split
    // across a column boundary reads as two half-finished sections, and
    // unlike a report there is no page turn to justify it — pushing the
    // whole card to the next column is always the better outcome. The
    // cost is that a card taller than one column overflows onto a
    // second sheet, which is a content problem rather than a layout one.
    breakable: false,
    [
      #if title != none {
        block(
          width: 100%,
          fill: brand-color.primary,
          inset: (x: pad, y: 0.62 * pad),
          // The title arrives from poster.lua as a pandoc paragraph, so
          // it carries the document's own par/block spacing into the
          // bar and pads it unevenly. Zeroed here so the bar's height is
          // set by its inset alone.
          [
            #set par(spacing: 0pt, leading: 0.55em)
            #set block(spacing: 0pt)
            #text(fill: white, weight: "bold", size: 1.15em, title)
          ],
        )
      }
      #block(width: 100%, inset: pad, body)
    ],
  )
}
$elseif(banner-inset)$
// brandkit: print layout. The panel is ordinary flow content emitted by
// typst-template.typ at the top of the body, so it is bounded by the
// page margins and nothing bleeds. `layout` is what makes that possible:
// brandkit-stripe-fill needs a concrete width to compute its stripe
// grid, and in the flow that width is only known once the text measure
// is resolved, so it cannot be read off page.width as the full-bleed
// branch does.
//
// The corner radius is the brand's own border-radius — the same value
// the code blocks use — so the document has one corner language rather
// than a panel that rounds differently to everything else.
#let brandkit-banner-content = layout(size => brandkit-banner-panel(
  size.width,
  brandkit-banner-inset-height,
  0.42in,
  radius: $if(code-radius)$$code-radius$$else$0.3em$endif$,
  // Flow content owns its own space, so the panel is free to grow past
  // its design height for a long title instead of clipping it — the one
  // thing the fixed-height full-bleed banner cannot do.
  grow: true,
))
$else$
// brandkit: full-bleed layout. A sized, clipped box, not the bare page
// background, is the container the places inside anchor to — without it,
// alignments like `bottom` resolve against the entire physical page
// height rather than just this banner strip, and the text ends up
// stranded near the middle of the page. That same "no container" issue
// applies one level up too: content dropped straight into
// `page(background: ...)` isn't automatically top-anchored — left
// unplaced, Typst centres it on the full page — so the box itself also
// has to be wrapped in an explicit place(top, ...). clip: true trims the
// stripes, which are drawn wider than pw to cover the sheared overhang,
// back down to the banner's bounds.
#set page(background: context [
  #if counter(page).get().first() == 1 {
    place(top, brandkit-banner-panel(page.width, brandkit-banner-height, 0.7in))
  }
])
$endif$
$else$
$if(logo)$
// brandkit: logo on the first page only (Quarto's default places it on
// every page as a persistent watermark; wrapping in a page-1 check here
// overrides that). Only reached when there's no title, i.e. no banner —
// see the title branch above for the normal, banner-embedded logo.
#set page(background: context [
  #if counter(page).get().first() == 1 {
    align($logo.location$, box(inset: $logo.inset$, image("$logo.path$", width: $logo.width$$if(logo.alt)$, alt: "$logo.alt$"$endif$)))
  }
])
$endif$
$endif$
$if(margin-geometry)$
// Configure marginalia page geometry (functions defined in definitions.typ)
#show: marginalia.setup.with(
  inner: (
    far: $margin-geometry.inner.far$,
    width: $margin-geometry.inner.width$,
    sep: $margin-geometry.inner.separation$,
  ),
  outer: (
    far: $margin-geometry.outer.far$,
    width: $margin-geometry.outer.width$,
    sep: $margin-geometry.outer.separation$,
  ),
  top: $if(margin.top)$$margin.top$$else$1.25in$endif$,
  bottom: $if(margin.bottom)$$margin.bottom$$else$1.25in$endif$,
  book: false,
  clearance: $margin-geometry.clearance$,
)
$endif$
