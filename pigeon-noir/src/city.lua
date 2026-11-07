-- The city: buildings, perches, shelters, food and hazards. Rules only, no drawing.
--
-- The street is seen from the side. Two ground layers: the sidewalk (y = 600) and the
-- road in front of it (y = 668), where cars drive and the fat crumbs are. Everything
-- else you stand on is a one-way platform: ledges, fire escapes, awnings, wires,
-- lamp heads and rooftops.

local city = {}

city.W = 6400
city.SIDEWALK = 600
city.ROAD = 668

-- { x1, x2, roof y, kind, neon sign }
local BUILDINGS = {
  { 60, 480, 400, "diner", "diner" },
  { 640, 1180, 210, "tenement" },
  { 1300, 1900, 260, "tenement" },
  { 2120, 2800, 150, "hotel", "hotel" },
  { 3250, 3700, 330, "bar", "bar" },
  { 3900, 4500, 280, "pawn", "pawn" },
  { 4700, 5200, 190, "office" },
  { 5400, 6400, 270, "sal" },
}

function city.build()
  local c = {
    buildings = {}, platforms = {}, shelters = {}, vents = {}, lamps = {},
    crumbs = {}, trash = {}, cats = {}, wires = {}, escapes = {},
  }
  local function plat(x1, x2, y, kind, extra)
    local p = { x1 = x1, x2 = x2, y = y, kind = kind }
    for k, v in pairs(extra or {}) do p[k] = v end
    c.platforms[#c.platforms + 1] = p
    return p
  end

  plat(0, city.W, city.SIDEWALK, "sidewalk")
  plat(0, city.W, city.ROAD, "road")

  for _, b in ipairs(BUILDINGS) do
    local bld = { x1 = b[1], x2 = b[2], top = b[3], kind = b[4], sign = b[5] }
    c.buildings[#c.buildings + 1] = bld
    plat(b[1], b[2], b[3], "roof")
    -- a cornice ledge partway up every tall building: a place to rest your wings
    if b[3] < 300 then plat(b[1] + 10, b[2] - 10, b[3] + 120, "ledge") end
  end

  -- fire escapes: stacked landings you can hop up
  for _, fe in ipairs({ { 760, 880, { 500, 390, 290 } }, { 4800, 4920, { 490, 380, 290 } }, { 5500, 5620, { 500, 410, 330 } } }) do
    local e = { x1 = fe[1], x2 = fe[2], levels = fe[3] }
    c.escapes[#c.escapes + 1] = e
    for _, y in ipairs(fe[3]) do plat(fe[1], fe[2], y, "escape") end
  end

  -- awnings and the bus shelter: perches on top, dry underneath
  for _, a in ipairs({ { 300, 480, 470 }, { 1650, 1800, 480 }, { 2300, 2500, 470 }, { 2900, 3060, 500, true }, { 4000, 4200, 480 } }) do
    local p = plat(a[1], a[2], a[3], "awning", { bus = a[4] })
    c.shelters[#c.shelters + 1] = p
  end

  -- telephone wires across the alleys
  for _, w in ipairs({ { 1900, 2120, 330 }, { 3700, 3900, 360 }, { 480, 640, 360 }, { 5200, 5400, 340 } }) do
    c.wires[#c.wires + 1] = plat(w[1], w[2], w[3], "wire")
  end

  -- street lamps: perch on the head to remember the spot (checkpoint)
  for _, x in ipairs({ 1240, 3150, 4600 }) do
    local l = { x = x, y = 430 }
    c.lamps[#c.lamps + 1] = l
    l.platform = plat(x - 18, x + 18, l.y, "lamp", { lamp = l })
  end

  for _, x in ipairs({ 1450, 3400, 5330 }) do c.vents[#c.vents + 1] = { x = x } end

  for _, t in ipairs({ 520, 2060, 3800, 5240 }) do c.trash[#c.trash + 1] = { x = t, knocked = false } end

  for _, cat in ipairs({ 570, 1990, 3760, 3860, 5300 }) do
    c.cats[#c.cats + 1] = { x = cat, home = cat, y = city.SIDEWALK, state = "idle", t = 0, dir = -1 }
  end

  -- crumbs: thin pickings on the sidewalk, fat ones on the road
  local walkCrumbs = { 250, 900, 1120, 1560, 1760, 2250, 2650, 3000, 3350, 3600, 4100, 4380, 4950, 5600, 5900 }
  for _, x in ipairs(walkCrumbs) do
    c.crumbs[#c.crumbs + 1] = { x = x, y = city.SIDEWALK, food = 12, alive = true, respawn = 0, home = true }
  end
  for _, x in ipairs({ 700, 1380, 2950, 3020, 3090, 4300, 5050, 5700 }) do
    c.crumbs[#c.crumbs + 1] = { x = x, y = city.ROAD, food = 22, alive = true, respawn = 0, home = true, road = true }
  end
  -- a few on the high ledges, for the brave
  for _, p in ipairs(c.platforms) do
    if p.kind == "ledge" then
      c.crumbs[#c.crumbs + 1] = { x = (p.x1 + p.x2) / 2, y = p.y, food = 12, alive = true, respawn = 0, home = true }
    end
  end

  c.diner = { x = 430, nextThrow = 6 }
  c.coop = { x = 6150, y = 270 }
  return c
end

-- The first platform the pigeon's feet cross while falling from prevY to y.
function city.landing(platforms, x, prevY, y, ignore)
  local best
  for _, p in ipairs(platforms) do
    if p ~= ignore and x >= p.x1 and x <= p.x2 and prevY <= p.y + 0.5 and y >= p.y then
      if not best or p.y < best.y then best = p end
    end
  end
  return best
end

function city.sheltered(c, x, y)
  for _, s in ipairs(c.shelters) do
    if x > s.x1 and x < s.x2 and y > s.y + 4 then return s end
  end
  return nil
end

function city.nearVent(c, x, y)
  if y < city.SIDEWALK - 4 then return nil end
  for _, v in ipairs(c.vents) do
    if math.abs(x - v.x) < 60 then return v end
  end
end

return city
