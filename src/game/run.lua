-- The current run: money, debt, pantry, what you've learned, upgrades. Pure rules, no drawing.
local ING = require("content.ingredients")
local UP = require("content.upgrades")
local GUIDE = require("content.guide")

local R = { current = nil }

function R.new()
  local run = {
    day = 0, flurbos = 40, debt = 1000,
    inventory = {},   -- id -> count (foraged ingredients only; staples are infinite)
    known = {},       -- id -> { tag = true } tags the player has discovered
    upgrades = {},    -- id -> true
    ratings = {},     -- recent star ratings
    rumors = 0,       -- how many rumors of the Restaurant you've heard
    planet = nil,
    stats = { served = 0, transcendent = 0, explosions = 0, walkouts = 0, earned = 0 },
    lastShift = nil,
  }
  for _, ing in ipairs(ING.list) do
    if ing.staple then
      run.known[ing.id] = {}
      for _, t in ipairs(ing.tags) do run.known[ing.id][t] = true end
    end
  end
  R.current = run
  return run
end

function R.has(run, id) return run.upgrades[id] == true end
function R.potSize(run) return R.has(run, "pot4") and 4 or 3 end
function R.basketSize(run) return R.has(run, "basket") and 12 or 8 end

function R.count(run, id)
  if ING.byId[id].staple then return math.huge end
  return run.inventory[id] or 0
end

-- Adds an ingredient. Returns the tag revealed if this is the first one ever found.
function R.add(run, id, n)
  run.inventory[id] = (run.inventory[id] or 0) + (n or 1)
  if not run.known[id] then
    local first = ING.byId[id].tags[1]
    run.known[id] = { [first] = true }
    return first
  end
end

function R.take(run, id)
  if ING.byId[id].staple then return true end
  local n = run.inventory[id] or 0
  if n <= 0 then return false end
  run.inventory[id] = n - 1
  return true
end

function R.giveBack(run, id)
  if not ING.byId[id].staple then run.inventory[id] = (run.inventory[id] or 0) + 1 end
end

function R.isKnown(run, id, tag)
  if R.has(run, "tasteotron") then return true end
  return run.known[id] ~= nil and run.known[id][tag] == true
end

-- Cooking with an ingredient teaches you all of its tags. Returns how many were new.
function R.learn(run, id)
  run.known[id] = run.known[id] or {}
  local new = 0
  for _, t in ipairs(ING.byId[id].tags) do
    if not run.known[id][t] then
      run.known[id][t] = true
      new = new + 1
    end
  end
  return new
end

-- Ingredient ids you can cook with right now, staples first, in content order.
function R.available(run)
  local out = {}
  for _, ing in ipairs(ING.list) do
    if R.count(run, ing.id) > 0 then out[#out + 1] = ing.id end
  end
  return out
end

-- Everything in the pantry (including ones you've run out of but discovered).
function R.pantry(run)
  local out = {}
  for _, ing in ipairs(ING.list) do
    if ing.staple or run.known[ing.id] then out[#out + 1] = ing.id end
  end
  return out
end

function R.addRating(run, stars)
  table.insert(run.ratings, stars)
  if #run.ratings > 12 then table.remove(run.ratings, 1) end
end

function R.rating(run)
  if #run.ratings == 0 then return 3 end
  local s = 0
  for _, v in ipairs(run.ratings) do s = s + v end
  return s / #run.ratings
end

function R.canBuy(run, id)
  return not R.has(run, id) and run.flurbos >= UP.byId[id].price
end

function R.buy(run, id)
  if not R.canBuy(run, id) then return false end
  run.flurbos = run.flurbos - UP.byId[id].price
  run.upgrades[id] = true
  return true
end

function R.payDebt(run, amount)
  amount = math.min(amount, run.flurbos, run.debt)
  run.flurbos = run.flurbos - amount
  run.debt = run.debt - amount
  return amount
end

-- Next rumor of the Restaurant at the End of the Universe, or nil when you've heard them all.
function R.nextRumor(run)
  if run.rumors >= #GUIDE.rumors then return nil end
  run.rumors = run.rumors + 1
  return GUIDE.rumors[run.rumors]
end

return R
