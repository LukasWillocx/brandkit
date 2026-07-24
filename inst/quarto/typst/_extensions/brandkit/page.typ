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
$if(title)$
// brandkit: full-bleed, diagonal-stripe title banner on page 1 (Linux Mint
// wallpaper style) — brandkit-stripe-fill in definitions.typ draws it as
// sheared polygons in brand-color.primary/secondary, no raster image
// involved. This lives in the page background (like the logo-only
// fallback below) so it spans the full physical page width, ignoring
// margins entirely. typst-template.typ reserves matching vertical space
// in the normal flow (see brandkit-banner-height there) so body content
// starts right below it instead of underneath it.
#set page(background: context [
  #if counter(page).get().first() == 1 {
    let pw = page.width
    let ph = brandkit-banner-height
    let seam-frac = 0.53
    let solid-frac = 0.6
    // brandkit: a sized, clipped box, not the bare page background, is
    // the container the place() calls below anchor to — without it,
    // alignments like `horizon` resolve against the *entire physical
    // page height* rather than just this banner strip, and the title
    // text ends up stranded around the vertical middle of the page
    // instead of inside the banner. That same "no container" issue
    // applies one level up too: content dropped straight into
    // `page(background: ...)` isn't automatically top-anchored — left
    // unplaced, Typst centers it on the full page — so the box itself
    // also has to be wrapped in an explicit place(top, ...). clip: true
    // trims the stripes, which are drawn wider than pw to cover the
    // sheared overhang, back down to the banner's bounds.
    place(top, box(width: pw, height: ph, clip: true)[
      #brandkit-stripe-fill(pw, ph, brand-color.primary, brand-color.secondary, seam-frac: seam-frac, solid-frac: solid-frac)
      $if(logo)$
      // brandkit: top-right, inset into the secondary-colour zone — not
      // sharing the left column with the title. That column's text block
      // below is vertically centred (`horizon`) and drawn after the logo,
      // so if the logo sat in the same column, a tall title/subtitle/date
      // stack could vertically center right over it and paint on top,
      // hiding it. The secondary zone starts at seam-frac of the page
      // width at every height (give or take one stripe's width), so a
      // small inset from the top-right corner stays inside it regardless.
      #place(top + right, dx: -0.45in, dy: 0.4in, image("$logo.path$", width: $logo.width$$if(logo.alt)$, alt: "$logo.alt$"$endif$))
      $endif$
      #let text-safe-w = pw * seam-frac - 0.7in - 0.25in
      #place(left + horizon, dx: 0.7in, block(width: pw * 0.55)[
        #text(
          fill: white,
          size: 22pt,
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
        $if(subtitle)$
        #v(0.35em)
        // brandkit: narrower than the title's own block — the title is
        // large/bold enough to stay legible wherever it wraps, but the
        // smaller subtitle wraps late enough at the title's full width
        // that it can run past the solid field and into the stripes.
        #block(width: text-safe-w, text(fill: white.transparentize(15%), size: 12.5pt)[$subtitle$])
        $endif$
        $if(date)$
        #v(0.6em)
        #block(width: text-safe-w, text(fill: white.transparentize(30%), size: 8.5pt)[$if(by-author)$$for(by-author)$$it.name.literal$$sep$, $endfor$ · $endif$$date$])
        $endif$
      ])
    ])
  }
])
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
