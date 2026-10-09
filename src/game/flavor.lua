-- The Flavor Synthesizer: combines ingredients into a dish (a bag of tags with counts)
-- and judges a dish against an order. Pure rules, no drawing.
local TAGS = require("content.tags")
local REACTIONS = require("content.reactions")
local ING = require("content.ingredients")

local F = {}

local tagIndex = {}
for i, t in ipairs(TAGS.order) do tagIndex[t] = i end

-- counts: tag -> n. Applies reactions in place, returns the list of reactions that fired.
local function react(counts)
  local fired = {}
  for _, r in ipairs(REACTIONS) do
    while true do
      local ca, cb = counts[r.a] or 0, counts[r.b] or 0
      if r.a == r.b then
        if ca < 2 then break end
        counts[r.a] = ca - 2
      else
        if ca < 1 or cb < 1 then break end
        counts[r.a], counts[r.b] = ca - 1, cb - 1
      end
      counts[r.result] = (counts[r.result] or 0) + 1
      fired[#fired + 1] = r
    end
  end
  for t, n in pairs(counts) do
    if n <= 0 then counts[t] = nil end
  end
  return fired
end

-- ids: list of ingredient ids (repeats allowed). Returns { counts, fired, ingredients }.
function F.combine(ids)
  local counts = {}
  for _, id in ipairs(ids) do
    for _, t in ipairs(ING.byId[id].tags) do counts[t] = (counts[t] or 0) + 1 end
  end
  local fired = react(counts)
  return { counts = counts, fired = fired, ingredients = ids }
end

-- Like combine, but only with the tags the player knows. isKnown(id, tag) -> bool.
-- Returns counts plus `unknown` (how many hidden tags went in).
function F.predict(ids, isKnown)
  local counts, unknown = {}, 0
  for _, id in ipairs(ids) do
    for _, t in ipairs(ING.byId[id].tags) do
      if isKnown(id, t) then counts[t] = (counts[t] or 0) + 1 else unknown = unknown + 1 end
    end
  end
  local fired = react(counts)
  return { counts = counts, fired = fired, unknown = unknown }
end

-- Tags of a counts table as a sorted list: { {tag=, n=}, ... }
function F.list(counts)
  local out = {}
  for t, n in pairs(counts) do out[#out + 1] = { tag = t, n = n } end
  table.sort(out, function(a, b) return tagIndex[a.tag] < tagIndex[b.tag] end)
  return out
end

F.RATINGS = {
  { id = "transcendent", label = "TRANSCENDENT!", stars = 5, tip = 0.5 },
  { id = "delighted", label = "DELIGHTED", stars = 4, tip = 0.1 },
  { id = "bemused", label = "BEMUSED", stars = 3, tip = 0 },
  { id = "complaint", label = "COMPLAINT FILED", stars = 1, tip = 0 },
  { id = "kaboom", label = "KABOOM", stars = 0, tip = 0 },
}
local ratingById = {}
for _, r in ipairs(F.RATINGS) do ratingById[r.id] = r end
F.rating = ratingById

-- order: { wants = { {tag=, n=}, ... }, hate = tag or nil, price = n }
-- Returns { score 0..1, rating, pay, matched = {tag=true}, missing = {...}, hated = bool,
--           extras = n, catastrophe = bool }
function F.score(dish, order)
  local c = dish.counts
  local wanted, matched, missing = {}, {}, {}
  local hits = 0
  for _, w in ipairs(order.wants) do
    wanted[w.tag] = true
    if (c[w.tag] or 0) >= w.n then
      hits = hits + 1
      matched[w.tag] = true
    else
      missing[#missing + 1] = w.tag
    end
  end
  local extras = 0
  for t, n in pairs(c) do
    if not wanted[t] then extras = extras + n end
  end
  local hated = order.hate ~= nil and (c[order.hate] or 0) > 0
  local catastrophe = (c.Explosive or 0) > 0 and not wanted.Explosive

  local score = hits / #order.wants - 0.12 * extras
  if hated then score = math.min(score, 0.3) - 0.2 end
  score = math.max(0, math.min(1, score))
  if catastrophe then score = 0 end

  local rating
  if catastrophe then rating = ratingById.kaboom
  elseif hated then rating = ratingById.complaint
  elseif score >= 0.99 then rating = ratingById.transcendent
  elseif score >= 0.7 then rating = ratingById.delighted
  elseif score >= 0.4 then rating = ratingById.bemused
  else rating = ratingById.complaint end

  local pay = math.floor(order.price * score * (1 + rating.tip) + 0.5)
  return { score = score, rating = rating, pay = pay, matched = matched, missing = missing,
    hated = hated, extras = extras, catastrophe = catastrophe }
end

return F
