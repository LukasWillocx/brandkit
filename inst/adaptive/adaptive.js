/* brandkit: adaptive figures.
   Quarto's light/dark toggle swaps stylesheets and puts quarto-light or
   quarto-dark on <body>. Figures drawn for both modes carry the dark file in
   data-dark-src; this points each one at whichever matches the page. */
(function () {
  function sync() {
    var dark = document.body.classList.contains("quarto-dark");
    document.querySelectorAll("img[data-dark-src]").forEach(function (img) {
      if (!img.dataset.lightSrc) img.dataset.lightSrc = img.getAttribute("src");
      var want = dark ? img.dataset.darkSrc : img.dataset.lightSrc;
      if (img.getAttribute("src") !== want) img.setAttribute("src", want);
    });
  }
  document.addEventListener("DOMContentLoaded", function () {
    new MutationObserver(sync).observe(document.body, {
      attributes: true,
      attributeFilter: ["class"]
    });
    sync();
  });
})();
