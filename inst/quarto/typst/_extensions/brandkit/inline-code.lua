-- brandkit: set inline code as plain text rather than `raw`.
--
-- Pandoc's highlighter writes inline code and every token of a fenced block
-- through the same Typst token functions, and each of those is a bare
-- `raw(...)` element. A show rule on `raw` therefore cannot tell a code span
-- in a sentence from a token inside a block, so any rule that gave inline
-- code the body font and its own colour gave the same to every block (and
-- one that kept blocks in the code font kept inline code in it, where a
-- monospace face reads oversized beside body text).
--
-- Rewriting the inline spans here, before they ever reach pandoc's Typst
-- writer, is what separates the two: an inline span becomes a call of
-- #brandkit-inline-code (defined in typst-show.typ, where `brand-color` is
-- in scope) and no longer matches anything aimed at `raw`, while a fenced
-- block is untouched and keeps the highlighting theme's own colours.
--
-- Declared under contributes.formats.typst.filters in _extension.yml, ahead
-- of the poster's filter.

-- The text as a Typst string literal: backslash and quote escaped, and a
-- newline (which a span may carry from a wrapped source line) as a space.
local function typst_string(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\r?\n", " ")
  return '"' .. s .. '"'
end

function Code(el)
  if FORMAT:match("typst") then
    return pandoc.RawInline("typst", "#brandkit-inline-code(" .. typst_string(el.text) .. ")")
  end
end
