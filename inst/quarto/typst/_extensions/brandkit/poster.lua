-- brandkit poster: wrap every level-2 section in a card panel.
--
-- Typst 0.13 has no way to express "this heading and everything after
-- it, up to the next heading" as a show rule — a show rule sees the
-- heading, never the content that follows it — so the grouping has to
-- happen while the document is still a block list. Hence a filter
-- rather than more Typst.
--
-- The card itself is #brandkit-card, defined in page.typ (it needs
-- `brand-color`, which is only in scope from that file onwards). All
-- this filter does is bracket the section and hand over its title:
--
--   #brandkit-card(title: [ <heading inlines> ])[ <section body> ]
--
-- The title goes out as a Plain rather than raw Typst so that pandoc
-- writes it through its own typst writer — emphasis, inline code,
-- maths and escaping in a heading all keep working.
--
-- Declared under contributes.formats.typst.filters in the poster
-- extension's _extension.yml only, so it never runs for the report
-- formats even though it is copied alongside them.

local OPEN_TITLE = "#brandkit-card(title: ["
local CLOSE_TITLE = "])["
local CLOSE_CARD = "]"

-- A level-2 heading marked {.plain} opts out and stays an ordinary
-- heading — the escape hatch for a section that should run free in the
-- column (a full-width intro, a bare figure) rather than sit in a panel.
local function starts_card(block)
  return block.t == "Header"
    and block.level == 2
    and not block.classes:includes("plain")
end

-- Level 1 is above the card grouping: it closes any open card and
-- passes through, so a poster can still use a heading to divide its
-- columns into larger parts if it wants one.
local function breaks_card(block)
  return block.t == "Header" and block.level < 2
end

function Pandoc(doc)
  local out = pandoc.Blocks({})
  local open = false

  local function close_card()
    if open then
      out:insert(pandoc.RawBlock("typst", CLOSE_CARD))
      open = false
    end
  end

  for _, block in ipairs(doc.blocks) do
    if starts_card(block) then
      close_card()
      out:insert(pandoc.RawBlock("typst", OPEN_TITLE))
      out:insert(pandoc.Plain(block.content))
      out:insert(pandoc.RawBlock("typst", CLOSE_TITLE))
      open = true
    elseif breaks_card(block) then
      close_card()
      out:insert(block)
    else
      out:insert(block)
    end
  end

  close_card()
  return pandoc.Pandoc(out, doc.meta)
end
