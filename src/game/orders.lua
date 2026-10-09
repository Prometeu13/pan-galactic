-- Customer orders. An order is built backwards from a dish the player CAN make with what's in
-- the pantry right now, so every order is solvable (at the time it's placed).
local TAGS = require("content.tags")
local ING = require("content.ingredients")
local Flavor = require("src.game.flavor")
local Run = require("src.game.run")

local O = {}

local function contains(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

-- How much a species fancies an ingredient: liked tags make it more likely to be in the order.
local function appeal(species, id)
  local w = 1
  for _, t in ipairs(ING.byId[id].tags) do
    if contains(species.likes, t) then w = w + 2 end
    if contains(species.hates, t) then w = w * 0.2 end
  end
  return w
end

-- "{doom}" in a phrase -> "{Doom:doom}" so the renderer knows which colour to use.
local function markup(tag, phrase)
  return (phrase:gsub("{(.-)}", "{" .. tag .. ":%1}"))
end

function O.phrase(tag, n, rng)
  local p = markup(tag, rng.pick(TAGS.defs[tag].phrases))
  if n and n >= 2 then p = "a double helping of " .. p end
  return p
end

local HATE = {
  "And NOTHING %s. It reminds me of my ex.",
  "Absolutely nothing %s, I'm allergic to it emotionally.",
  "If it's %s, I will write a strongly worded review.",
  "Hold the %s. I mean it. Hold it far away.",
}

-- run: current run; species: content/species entry; rng: src/core/rng; quirk: planet quirk
function O.generate(run, species, rng, quirk, attempt)
  quirk = quirk or {}
  attempt = attempt or 1
  local avail = Run.available(run)
  local potSize = Run.potSize(run)

  -- How many ingredients the secret "solution" uses.
  local k = rng.weighted({ 1, 2, 2, 3, 3, 4 }, function(n) return n <= potSize and 1 or 0 end)

  -- Pool of individual units (staples count as up to k each).
  local pool = {}
  for _, id in ipairs(avail) do
    for _ = 1, math.min(Run.count(run, id), k) do pool[#pool + 1] = id end
  end
  local solution = {}
  for _ = 1, k do
    if #pool == 0 then break end
    local id = rng.weighted(pool, function(i) return appeal(species, i) end)
    solution[#solution + 1] = id
    for i, x in ipairs(pool) do
      if x == id then table.remove(pool, i) break end
    end
  end

  local dish = Flavor.combine(solution)
  local tags = Flavor.list(dish.counts)

  -- Re-roll dishes that make a muddled order: more than 3 tags (no clean perfect answer), or an
  -- explosion nobody asked for (Blagulons are the only ones who'd ever ASK for one).
  local muddled = #tags > 3 or #tags == 0
  local unwantedBoom = dish.counts.Explosive and not contains(species.likes, "Explosive")
  if (muddled or unwantedBoom) and attempt < 40 then
    return O.generate(run, species, rng, quirk, attempt + 1)
  end

  -- Choose wanted tags (all of them if <= 3, so a perfect dish always exists).
  local wants = {}
  if #tags <= 3 then
    for _, e in ipairs(tags) do wants[#wants + 1] = { tag = e.tag, n = 1, have = e.n } end
  else
    local pick = {}
    for _, e in ipairs(tags) do pick[#pick + 1] = e end
    for _ = 1, 3 do
      local e = rng.weighted(pick, function(x) return contains(species.likes, x.tag) and 4 or 1 end)
      wants[#wants + 1] = { tag = e.tag, n = 1, have = e.n }
      for i, x in ipairs(pick) do if x == e then table.remove(pick, i) break end end
    end
  end
  if #wants == 0 then wants[1] = { tag = species.likes[1], n = 1, have = 1 } end
  for _, w in ipairs(wants) do
    if w.have >= 2 and rng.chance(0.5) then w.n = 2 end
    w.have = nil
  end

  -- A hated tag that isn't in the solution.
  local hateable = {}
  for _, t in ipairs(species.hates) do
    if not dish.counts[t] then hateable[#hateable + 1] = t end
  end
  local hate = (#hateable > 0 and rng.chance(0.65)) and rng.pick(hateable) or nil

  -- Words.
  local parts = {}
  for _, w in ipairs(wants) do parts[#parts + 1] = O.phrase(w.tag, w.n, rng) end
  local text = rng.pick(species.openers) .. " something that tastes like " .. parts[1]
  if parts[2] then text = text .. (parts[3] and ", " or " but with ") .. parts[2] end
  if parts[3] then text = text .. ", and " .. parts[3] end
  text = text .. "."
  if hate then
    text = text .. " " .. string.format(rng.pick(HATE), "{" .. hate .. ":" .. TAGS.defs[hate].word .. "}")
  end

  local extra = 0
  for _, w in ipairs(wants) do extra = extra + (w.n - 1) end
  local price = math.floor((10 + 7 * #wants + 5 * extra) * species.wealth * (quirk.pay or 1) + 0.5)

  return { wants = wants, hate = hate, text = text, price = price, solution = solution }
end

return O
