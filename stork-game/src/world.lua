-- The valley: terrain shape, shallow water, and where everything is placed.
-- Rules only (no drawing), so the self-test can check it without a window.

local ink = require("src.ink")

local world = {}

world.W = 5200   -- world width in pixels; the screen is 1280 wide

-- Raised areas: { x1, x2, height-of-top, edge softness }
local PLATEAUS = {
  { 180, 470, 330, 60 },   -- nest cliff
  { 4860, 5060, 300, 50 }, -- ledge above the pond
  { 1290, 1390, 525, 20 }, -- a mossy rock in the marsh
}

-- Shallow water: { x1, x2, water level, bed depth }
world.WATER = {
  { x1 = 820, x2 = 1500, level = 575, bed = 618, name = "marsh" },
  { x1 = 2380, x2 = 3000, level = 585, bed = 632, name = "river" },
  { x1 = 4150, x2 = 4760, level = 570, bed = 615, name = "pond" },
}

world.REGIONS = {
  { x1 = 0, x2 = 1700 },
  { x1 = 1700, x2 = 3700 },
  { x1 = 3700, x2 = 5200 },
}

local function base(x)
  return 556 + (ink.fbm(x * 0.0021, 3.7, 3) - 0.5) * 70
end

-- Height of the walkable surface at x (the riverbed, where there's water).
function world.ground(x)
  local y = base(x)
  for _, p in ipairs(PLATEAUS) do
    local up = ink.smooth(p[1] - p[4], p[1], x) * (1 - ink.smooth(p[2], p[2] + p[4], x))
    y = ink.lerp(y, p[3], up)
  end
  for _, w in ipairs(world.WATER) do
    local inside = ink.smooth(w.x1 - 50, w.x1 + 30, x) * (1 - ink.smooth(w.x2 - 30, w.x2 + 50, x))
    y = ink.lerp(y, w.bed, inside)
  end
  return y
end

-- Water surface height at x, or nil when dry.
function world.water(x)
  for _, w in ipairs(world.WATER) do
    if x > w.x1 - 10 and x < w.x2 + 10 then return w.level, w end
  end
end

function world.regionAt(x)
  for i, r in ipairs(world.REGIONS) do
    if x >= r.x1 and x < r.x2 then return i end
  end
  return #world.REGIONS
end

-- Everything you can interact with. Positions are where the thing sits.
function world.build()
  local g = world.ground
  local w = {
    nest = { x = 330, y = 205 },
    twigs = {
      { x = 690, y = g(690) - 4 },
      { x = 1340, y = g(1340) - 4 },
      { x = 2060, y = g(2060) - 130 - 52 }, -- on a village roof ridge: fly up for it
      { x = 3300, y = g(3300) - 4 },
      { x = 4960, y = g(4960) - 4 },      -- on the high ledge
    },
    lantern = { x = 3470, y = g(3470) - 6, taken = false },
    seals = {
      { x = 600, y = g(600), region = 1 },
      { x = 1715, y = g(1715), region = 2 },   -- at the village entrance
      { x = 4060, y = g(4060), region = 3 },
    },
    fisherman = { x = 2690, y = world.WATER[2].level },
    frog = { x = 4420, y = world.WATER[3].level },
    villager = { x = 1940, y = g(1940) },
    houses = { { x = 1850, w = 150, h = 120 }, { x = 2060, w = 170, h = 130 }, { x = 2280, w = 130, h = 110 } },
    fish = {},
  }
  for _, wz in ipairs(world.WATER) do
    for k = 1, 3 do
      w.fish[#w.fish + 1] = {
        water = wz, x = ink.lerp(wz.x1 + 60, wz.x2 - 60, k / 4), dir = (k % 2 == 0) and 1 or -1,
        speed = 30 + k * 8, phase = k * 1.7, caught = false, respawn = 0,
      }
    end
  end
  return w
end

return world
