-- Procedural planets and the rides that take you there. Pure rules, no drawing.
local P = require("content.planets")
local ING = require("content.ingredients")
local SPECIES = require("content.species")
local RIDES = require("content.rides")
local Run = require("src.game.run")

local G = {}

local function hsv(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return { v, t, p } elseif i == 1 then return { q, v, p }
  elseif i == 2 then return { p, v, t } elseif i == 3 then return { p, q, v }
  elseif i == 4 then return { t, p, v } else return { v, p, q } end
end
G.hsv = hsv

-- rng: src/core/rng instance (the run's). Returns a planet table.
function G.planet(rng)
  local seed = rng.random(1, 2 ^ 30)
  local name = rng.pick(P.prefixes) .. rng.pick(P.suffixes) .. rng.pick(P.numerals)
  local hue = rng.float(0, 1)

  local residents = {}
  local sp = {}
  for _, s in ipairs(SPECIES.list) do sp[#sp + 1] = s.id end
  rng.shuffle(sp)
  for i = 1, rng.random(2, 3) do residents[i] = sp[i] end

  local foraged = {}
  for _, ing in ipairs(ING.list) do
    if not ing.staple then foraged[#foraged + 1] = ing.id end
  end
  rng.shuffle(foraged)
  local pool = {}
  for i = 1, 6 do pool[i] = foraged[i] end

  return {
    seed = seed, name = name, epithet = rng.pick(P.epithets), quirk = rng.pick(P.quirks),
    terrain = rng.pick(P.terrains),
    ground = hsv(hue, rng.float(0.35, 0.6), rng.float(0.35, 0.55)),
    sky = hsv((hue + rng.float(0.3, 0.7)) % 1, rng.float(0.4, 0.7), rng.float(0.45, 0.75)),
    accent = hsv((hue + 0.5) % 1, 0.7, 0.95),
    ringed = rng.chance(0.4),
    residents = residents, pool = pool,
  }
end

function G.rides(run, rng)
  local n = Run.has(run, "navcom") and 4 or 3
  local out = {}
  for i = 1, n do
    local def = RIDES[((i - 1) % #RIDES) + 1]
    out[i] = {
      def = def, planet = G.planet(rng),
      revealed = def.reveals or Run.has(run, "navcom"),
      poem = def.poem and rng.pick(RIDES.poems) or nil,
    }
  end
  return out
end

return G
