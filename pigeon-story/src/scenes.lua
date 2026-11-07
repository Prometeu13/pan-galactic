-- The four staged scenes, painted in COLOUR. The film grade (desaturate + grain +
-- vignette) turns them into black and white; the light map gives them hard shadows.
--
-- Each scene returns:
--   lights      { {x, y, radius, r, g, b} }  lights that cast ray-traced shadows
--   occluders   static shapes that cast shadows (and get lit themselves)
--   ambient     how dark the shadows are
--   back(g, t)      background, props and the characters who stay put
--   emissive(g, t)  things that glow, drawn after the light map (neon, windows, embers)

local Pigeon = require("src.pigeon")

local lg = love.graphics
local S = {}
local GROUND = Pigeon.GROUND

local function hex(h, a)
  h = h:gsub("#", "")
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
local function rect(x, y, w, h) return { x, y, x + w, y, x + w, y + h, x, y + h } end
local function fbm(x, y)
  local s, a, f, n = 0, 1, 1, 0
  for _ = 1, 3 do s, n, a, f = s + a * love.math.noise(x * f, y * f), n + a, a * 0.5, f * 2 end
  return s / n
end

function S.load()
  local d = love.image.newImageData(64, 64)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / 32 - 1, (y + 0.5) / 32 - 1
    return 1, 1, 1, (1 - math.min(1, math.sqrt(dx * dx + dy * dy))) ^ 2
  end)
  S.glow = lg.newImage(d)
  S.neonFont = lg.newFont(40)
  S.signFont = lg.newFont(22)
end

-- Bricks, baked once per scene with its own colour.
local function bakeBricks(w, h, base, seed)
  local c = lg.newCanvas(w, h)
  lg.push("all")
  lg.setCanvas(c)
  lg.clear(base[1] * 0.45, base[2] * 0.45, base[3] * 0.45)
  love.math.setRandomSeed(seed)
  for row = 0, math.ceil(h / 24) do
    local off = (row % 2) * 32
    for col = -1, math.ceil(w / 64) do
      local x, y = col * 64 + off, row * 24
      local v = 0.65 + fbm(x * 0.01 + seed, y * 0.01) * 0.3 + love.math.random() * 0.1
      lg.setColor(base[1] * v, base[2] * v, base[3] * v)
      lg.rectangle("fill", x + 2, y + 2, 60, 20, 2)
    end
  end
  for y = 0, h, 4 do
    lg.setColor(0.04, 0.03, 0.03, (y / h) ^ 2 * 0.5)
    lg.rectangle("fill", 0, y, w, 4)
  end
  lg.pop()
  return c
end

local function sidewalk(color)
  lg.setColor(color or hex("#4a4744"))
  lg.rectangle("fill", 0, GROUND, 1280, 120)
  lg.setColor(0.17, 0.16, 0.15)
  for x = 0, 1280, 160 do lg.rectangle("fill", x, GROUND, 3, 120) end
  lg.rectangle("fill", 0, GROUND, 1280, 5)
end

local function glow(x, y, sx, sy, r, g, b, a)
  lg.setBlendMode("add")
  lg.setColor(r, g, b, a)
  lg.draw(S.glow, x, y, 0, sx, sy, 32, 32)
  lg.setBlendMode("alpha")
end

-- A human, as a few convex pieces (they double as shadow casters).
local function personPieces(x, kind)
  local p = {
    { x - 22, 470, x + 22, 470, x + 30, 560, x - 30, 560 },       -- torso / coat
    { x - 20, 560, x - 4, 560, x - 6, GROUND, x - 20, GROUND },   -- legs
    { x + 4, 560, x + 20, 560, x + 20, GROUND, x + 6, GROUND },
    { x - 13, 432, x + 13, 432, x + 15, 462, x - 15, 462 },       -- head
  }
  if kind == "dot" then p[#p + 1] = { x - 16, 432, x - 12, 404, x + 12, 404, x + 16, 432 } end -- beehive hair
  return p
end

local function drawPerson(x, kind, t)
  local pieces = personPieces(x, kind)
  for i, pc in ipairs(pieces) do
    if i == 4 then lg.setColor(hex("#c99a7a"))
    elseif i == 5 then lg.setColor(hex("#3a2a20"))
    elseif kind == "marty" then lg.setColor(i == 1 and hex("#e8e4dc") or hex("#2a2622"))
    else lg.setColor(i == 1 and hex("#7a3a4a") or hex("#2a2622")) end
    lg.polygon("fill", pc)
  end
  if kind == "marty" then -- apron strings and a paper hat
    lg.setColor(hex("#f2f0ea"))
    lg.polygon("fill", x - 14, 432, x + 14, 432, x + 10, 420, x - 10, 420)
    lg.setColor(0.2, 0.2, 0.2)
    lg.rectangle("fill", x + 14, 488, 26, 5) -- arm with cigarette
  else
    lg.setColor(hex("#5a2a3a"))
    lg.rectangle("fill", x - 24, 500, 48, 10) -- folded arms
  end
end

local function cat(x, y, t, dir)
  local d = dir or -1
  lg.setColor(hex("#8a847c"))                          -- a scruffy grey tom
  lg.ellipse("fill", x, y - 18, 24, 18)                          -- sitting body
  lg.circle("fill", x + d * 6, y - 44, 13)                       -- head
  lg.polygon("fill", x + d * -4, y - 52, x + d * -2, y - 68, x + d * 6, y - 55) -- ears (one torn)
  lg.polygon("fill", x + d * 10, y - 54, x + d * 16, y - 64, x + d * 18, y - 50)
  local sw = math.sin(t * 1.4) * 10
  lg.setLineWidth(7)
  lg.line(x - d * 20, y - 6, x - d * 30, y + 14, x - d * 26 + sw, y + 34)  -- tail hanging over the can
  lg.setColor(hex("#d8c040"))
  local blink = math.sin(t * 0.6) > 0.95 and 0.4 or 2.5
  lg.ellipse("fill", x + d * 1, y - 46, 3, blink)
  lg.ellipse("fill", x + d * 12, y - 46, 3, blink)
end

-------------------------------------------------------------------------------------------
-- CHAPTER ONE: the alley and Sal's bench
-------------------------------------------------------------------------------------------
function S.alley()
  local sc = { ambient = 0.06 }
  sc.wall = bakeBricks(1280, GROUND, hex("#a85a44"), 3)
  sc.lights = { { 272, 262, 2700, 1, 0.84, 0.6 }, { 770, 320, 1700, 0.8, 0.66, 0.48 } }
  local occ = {}
  local function o(p) occ[#occ + 1] = p return p end
  sc.bench = { o(rect(180, 545, 180, 10)), o(rect(186, 498, 168, 8)), o(rect(186, 516, 168, 8)), o(rect(195, 555, 8, 45)), o(rect(338, 555, 8, 45)) }
  sc.fence = {}
  for x = 520, 700, 24 do sc.fence[#sc.fence + 1] = o(rect(x, 462, 9, 138)) end
  o(rect(515, 488, 195, 7))
  sc.cans = { o(rect(850, 548, 62, 52)), o(rect(925, 556, 54, 44)) }
  o({ 856, 548, 904, 548, 900, 500, 860, 500 })        -- the cat, roughly
  sc.escape = {}
  for _, p in ipairs({ rect(990, 230, 260, 10), rect(990, 120, 260, 5), rect(1020, 400, 200, 8) }) do sc.escape[#sc.escape + 1] = o(p) end
  for x = 994, 1246, 24 do sc.escape[#sc.escape + 1] = o(rect(x, 125, 4, 105)) end
  for k = 0, 6 do sc.escape[#sc.escape + 1] = o(rect(1010 + k * 22, 250 + k * 22, 30, 4)) end
  -- (the lamp post is NOT an occluder: it sits right under its own light and would
  -- throw a giant wedge of shadow straight down)
  sc.occluders = occ

  function sc.back(g, t)
    lg.setColor(1, 1, 1)
    lg.draw(sc.wall)
    -- the window high up, its blinds and frame
    lg.setColor(hex("#2a1a14"))
    lg.setLineWidth(10)
    lg.rectangle("line", 595, 145, 170, 160)
    sidewalk()
    -- bench
    lg.setColor(hex("#5a4632"))
    for _, p in ipairs(sc.bench) do lg.polygon("fill", p) end
    -- fence
    lg.setColor(hex("#6a6258"))
    for _, p in ipairs(sc.fence) do lg.polygon("fill", p) end
    lg.rectangle("fill", 515, 488, 195, 7)
    if not g:hasClue("Sal's scarf") then
      lg.setColor(hex("#7a8090"))
      lg.polygon("fill", 600, 494, 626, 494, 630, 548, 618, 556, 604, 540)
      lg.setColor(hex("#5a6070"))
      for k = 0, 3 do lg.rectangle("fill", 603 + k * 6, 548, 3, 12) end
    end
    -- puddle with the lamp in it
    lg.setColor(hex("#25282c"))
    lg.ellipse("fill", 760, 618, 70, 9)
    -- cans and Vinnie on top of one
    lg.setColor(hex("#55585c"))
    for _, p in ipairs(sc.cans) do lg.polygon("fill", p) end
    lg.setColor(hex("#3a3c40"))
    lg.rectangle("fill", 846, 544, 70, 6)
    lg.rectangle("fill", 921, 552, 62, 6)
    cat(880, 548, t, -1)
    -- fire escape and lamp post
    lg.setColor(hex("#3a3634"))
    for _, p in ipairs(sc.escape) do lg.polygon("fill", p) end
    lg.setColor(hex("#1b1b1b"))
    lg.rectangle("fill", 268, 270, 8, GROUND - 270)
    lg.polygon("fill", 250, 262, 296, 256, 300, 268, 246, 272)
  end

  function sc.emissive(g, t)
    -- lit window with venetian blinds
    lg.setColor(hex("#ffd58a"))
    lg.rectangle("fill", 600, 150, 160, 150)
    lg.setColor(hex("#2a1a14"))
    for y = 158, 296, 15 do lg.rectangle("fill", 600, y, 160, 7) end
    glow(680, 225, 4, 3.5, 1, 0.85, 0.6, 0.35)
    glow(272, 266, 2.2, 1.6, 1, 0.85, 0.6, 0.9)
    glow(760, 618, 2.6, 0.3, 1, 0.85, 0.6, 0.35)      -- the lamp in the puddle
  end
  return sc
end

-------------------------------------------------------------------------------------------
-- CHAPTER TWO: the Lucky Diner, front window and back door
-------------------------------------------------------------------------------------------
function S.diner()
  local sc = { ambient = 0.07 }
  sc.front = bakeBricks(780, GROUND, hex("#8a7a60"), 7)
  sc.side = bakeBricks(520, GROUND, hex("#7a4a3a"), 9)
  sc.lights = { { 1040, 330, 2000, 1, 0.9, 0.7 }, { 335, 440, 1300, 1, 0.82, 0.55 } }
  local occ = {}
  local function o(p) occ[#occ + 1] = p return p end
  sc.mullions = { o(rect(256, 330, 8, 210)), o(rect(410, 330, 8, 210)), o(rect(110, 428, 450, 6)) }
  sc.dumpster = o(rect(840, 520, 120, 80))
  sc.people = {}
  for _, who in ipairs({ { 1100, "marty" }, { 1175, "dot" } }) do
    for _, pc in ipairs(personPieces(who[1], who[2])) do o(pc) end
  end
  o(Pigeon.occluder(520, GROUND, -1, 0.8))       -- Pip
  sc.occluders = occ
  sc.smoke = {}

  function sc.update(g, dt)
    if love.math.random() < dt * 8 then
      sc.smoke[#sc.smoke + 1] = { x = 1140, y = 488, life = 0 }
    end
    for i = #sc.smoke, 1, -1 do
      local s = sc.smoke[i]
      s.life = s.life + dt
      s.y = s.y - 18 * dt
      s.x = s.x + math.sin(s.life * 2) * 8 * dt
      if s.life > 3.5 then table.remove(sc.smoke, i) end
    end
  end

  function sc.back(g, t)
    lg.setColor(1, 1, 1)
    lg.draw(sc.front, 0, 0)
    lg.draw(sc.side, 780, 0)
    lg.setColor(0.1, 0.08, 0.07)
    lg.rectangle("fill", 774, 0, 10, GROUND)            -- the building corner
    -- window frame, door, the sign's box
    lg.setColor(hex("#2a2420"))
    lg.setLineWidth(12)
    lg.rectangle("line", 104, 324, 462, 222)
    lg.rectangle("fill", 600, 452, 80, 148)
    lg.setColor(hex("#1e1a18"))
    lg.rectangle("fill", 140, 196, 400, 70, 6)
    sidewalk()
    -- the back door and its light
    lg.setColor(hex("#2a2420"))
    lg.rectangle("fill", 990, 440, 96, 160)
    lg.setColor(hex("#3a3230"))
    lg.polygon("fill", 1010, 316, 1070, 316, 1060, 330, 1020, 330)
    -- dumpster
    lg.setColor(hex("#3a5a48"))
    lg.polygon("fill", sc.dumpster)
    lg.setColor(hex("#2a4236"))
    lg.rectangle("fill", 834, 512, 132, 10)
    for x = 860, 940, 26 do lg.rectangle("fill", x, 530, 6, 60) end
    -- Marty and Dot on their smoke break
    drawPerson(1100, "marty", t)
    drawPerson(1175, "dot", t)
    -- Pip, waiting under the window
    Pigeon.paint(520, GROUND, -1, t, { scale = 0.8, body = { 0.5, 0.52, 0.56 }, fluffed = true }, 0, false, (math.sin(t * 1.3) > 0.7) and 0.6 or 0)
    for _, s in ipairs(sc.smoke) do
      lg.setColor(0.85, 0.85, 0.85, 0.18 * (1 - s.life / 3.5))
      lg.circle("fill", s.x, s.y, 6 + s.life * 10)
    end
  end

  function sc.emissive(g, t)
    -- the window: warm interior, counter, Dot's empty booth with the upside-down cup
    lg.setColor(hex("#f0c878"))
    lg.rectangle("fill", 110, 330, 450, 210)
    lg.setColor(hex("#8a5a3a"))
    lg.rectangle("fill", 110, 470, 450, 70)             -- counter
    lg.setColor(hex("#5a3a2a"))
    for x = 150, 520, 60 do lg.rectangle("fill", x, 500, 22, 40) end
    lg.setColor(hex("#3a2a20"))
    local dx = 260 + math.sin(t * 0.5) * 110              -- somebody behind the counter, wiping
    lg.rectangle("fill", dx - 14, 400, 28, 70)
    lg.circle("fill", dx, 388, 12)
    lg.setColor(hex("#f4f0e8"))
    lg.polygon("fill", 470, 458, 486, 458, 482, 446, 474, 446)
    lg.setColor(hex("#2a2420"))
    for _, p in ipairs(sc.mullions) do lg.polygon("fill", p) end
    glow(335, 440, 6, 3.6, 1, 0.8, 0.5, 0.3)
    -- neon: LUCKY DINER, with the L burned out
    local on = math.sin(t * 6) > -0.9
    lg.setFont(S.neonFont)
    lg.setColor(1, 0.4, 0.3, 0.15)
    lg.printf("L", 120, 205, 60, "center")
    lg.setColor(1, 0.45, 0.35, on and 1 or 0.3)
    lg.printf("UCKY DINER", 160, 205, 380, "center")
    if on then glow(340, 230, 7, 1.5, 1, 0.35, 0.25, 0.35) end
    glow(1040, 334, 1.6, 1.2, 1, 0.9, 0.7, 0.8)
    local ember = 0.6 + 0.4 * math.sin(t * 3)
    glow(1142, 490, 0.25, 0.25, 1, 0.5, 0.1, ember)
    lg.setColor(1, 0.55, 0.2, ember)
    lg.circle("fill", 1142, 490, 2.5)
  end
  return sc
end

-------------------------------------------------------------------------------------------
-- CHAPTER THREE: the rooftop and the empty coop
-------------------------------------------------------------------------------------------
function S.roof()
  local sc = { ambient = 0.1 }
  love.math.setRandomSeed(31)
  sc.skyline = {}
  local x = -20
  while x < 1300 do
    local w = love.math.random(50, 120)
    sc.skyline[#sc.skyline + 1] = { x = x, w = w, top = love.math.random(260, 470) }
    x = x + w + love.math.random(2, 12)
  end
  sc.lights = { { 230, 372, 1900, 1, 0.85, 0.6 }, { 1180, 40, 3200, 0.7, 0.78, 0.95 } }
  local occ = {}
  local function o(p) occ[#occ + 1] = p return p end
  sc.coop = { o(rect(300, 470, 220, 108)), o({ 290, 470, 410, 424, 530, 470 }) }
  sc.coopLegs = { o(rect(312, 578, 8, 22)), o(rect(500, 578, 8, 22)) }
  sc.chimney = o(rect(640, 430, 60, 170))
  sc.tank = o(rect(820, 232, 180, 140))
  sc.tankRoof = o({ 812, 232, 910, 186, 1008, 232 })
  sc.legs = {}
  for _, lx in ipairs({ 830, 880, 940, 984 }) do sc.legs[#sc.legs + 1] = o(rect(lx, 372, 8, 228)) end
  sc.legs[#sc.legs + 1] = o(rect(830, 470, 162, 6))
  sc.mast = o(rect(1136, 260, 8, 340))
  sc.bars = { o(rect(1100, 330, 80, 5)), o(rect(1110, 290, 60, 4)) }
  sc.occluders = occ

  function sc.back(g, t)
    lg.setColor(1, 1, 1)
    sc.sky = sc.sky or (function()
      local v = { { 0, 0, 0, 0, 0.05, 0.06, 0.12, 1 }, { 1280, 0, 0, 0, 0.05, 0.06, 0.12, 1 },
                  { 1280, 600, 0, 0, 0.18, 0.16, 0.22, 1 }, { 0, 600, 0, 0, 0.18, 0.16, 0.22, 1 } }
      return lg.newMesh(v, "fan", "static")
    end)()
    lg.draw(sc.sky)
    for _, b in ipairs(sc.skyline) do
      lg.setColor(0.09, 0.09, 0.12)
      lg.rectangle("fill", b.x, b.top, b.w, GROUND - b.top)
    end
    -- parapet and the tar roof
    lg.setColor(hex("#4a3a34"))
    lg.rectangle("fill", 0, 560, 1280, 40)
    lg.setColor(hex("#2a2826"))
    lg.rectangle("fill", 0, GROUND, 1280, 120)
    -- coop: weathered planks, wire mesh, the door hanging open
    lg.setColor(hex("#7a6248"))
    lg.polygon("fill", sc.coop[1])
    lg.setColor(hex("#5a4434"))
    lg.polygon("fill", sc.coop[2])
    for _, p in ipairs(sc.coopLegs) do lg.polygon("fill", p) end
    lg.setColor(hex("#9a9a92"))
    lg.setLineWidth(1)
    for mx = 312, 470, 12 do lg.line(mx, 486, mx, 566) end
    for my = 486, 566, 12 do lg.line(312, my, 470, my) end
    lg.setColor(hex("#1a1412"))
    lg.rectangle("fill", 476, 488, 36, 80)
    lg.setColor(hex("#6a5440"))
    lg.polygon("fill", 512, 488, 548, 500, 548, 580, 512, 568)
    -- chimney with Tony on top, unless he's joined the flock
    lg.setColor(hex("#8a4a3a"))
    lg.polygon("fill", sc.chimney)
    lg.setColor(hex("#5a3028"))
    lg.rectangle("fill", 634, 424, 72, 10)
    if not g.flags.tony then Pigeon.paint(670, 430, -1, t, { scale = 1.25, body = { 0.45, 0.46, 0.5 }, fluffed = true }, 0, false, 0) end
    -- water tower
    lg.setColor(hex("#6a5442"))
    lg.polygon("fill", sc.tank)
    lg.setColor(hex("#4a3a2e"))
    lg.polygon("fill", sc.tankRoof)
    for _, p in ipairs(sc.legs) do lg.polygon("fill", p) end
    lg.setColor(hex("#3a2e24"))
    for by = 262, 362, 34 do lg.rectangle("fill", 820, by, 180, 5) end
    if not g.flags.rosa then Pigeon.paint(905, GROUND, -1, t, { scale = 1, body = { 0.62, 0.58, 0.56 }, neck = { 0.5, 0.35, 0.45 } }, 0, false, 0) end
    -- antenna, with Wren clinging to the crossbar
    lg.setColor(hex("#5a5a60"))
    lg.polygon("fill", sc.mast)
    for _, p in ipairs(sc.bars) do lg.polygon("fill", p) end
    if not g.flags.wren then Pigeon.paint(1140, 330, -1, t, { scale = 0.75, body = { 0.68, 0.68, 0.7 } }, 0, false, 0) end
    -- bare bulb on a pole
    lg.setColor(hex("#1b1b1b"))
    lg.rectangle("fill", 226, 380, 8, 220)
  end

  function sc.emissive(g, t)
    for _, b in ipairs(sc.skyline) do
      for wy = b.top + 14, 540, 24 do
        for wx = b.x + 8, b.x + b.w - 12, 16 do
          if (math.floor(wx) * 13 + wy * 7) % 9 == 0 then
            lg.setColor(1, 0.85, 0.55, 0.85)
            lg.rectangle("fill", wx, wy, 6, 9)
          end
        end
      end
    end
    lg.setColor(1, 0.95, 0.85)
    lg.circle("fill", 230, 376, 6)
    glow(230, 376, 1.4, 1.4, 1, 0.85, 0.6, 0.8)
    lg.setColor(0.92, 0.94, 1)
    lg.circle("fill", 1180, 90, 40)
    glow(1180, 90, 3, 3, 0.7, 0.8, 1, 0.3)
  end
  return sc
end

-------------------------------------------------------------------------------------------
-- CHAPTER FOUR: St. Agnes, before dawn (and at dawn, the colour comes back)
-------------------------------------------------------------------------------------------
function S.hospital()
  local sc = { ambient = 0.08 }
  love.math.setRandomSeed(41)
  sc.lights = { { 190, 330, 2300, 1, 0.86, 0.62 }, { 720, 322, 1300, 1, 0.85, 0.6 } }
  local occ = {}
  local function o(p) occ[#occ + 1] = p return p end
  -- window bars are drawn but don't cast shadows: the room's light sits right behind them
  sc.mull = { rect(716, 250, 8, 145), rect(640, 318, 160, 6) }
  sc.occluders = occ
  sc.skyline = {}
  local x = 1060
  while x < 1300 do
    local w = love.math.random(40, 80)
    sc.skyline[#sc.skyline + 1] = { x = x, w = w, top = love.math.random(380, 500) }
    x = x + w + 4
  end

  function sc.update(g, dt)
    -- dawn lifts the shadows a little
    sc.ambient = 0.08 + g.dawn * 0.45
  end

  function sc.back(g, t)
    local d = g.dawn
    -- sky beyond the hospital: night navy, warming to peach at dawn
    local top = { 0.05 + d * 0.45, 0.06 + d * 0.35, 0.12 + d * 0.3 }
    local low = { 0.15 + d * 0.85, 0.14 + d * 0.55, 0.2 + d * 0.25 }
    lg.setColor(1, 1, 1)
    sc.skyMesh = sc.skyMesh or lg.newMesh(4, "fan", "stream")
    sc.skyMesh:setVertices({ { 1040, 0, 0, 0, top[1], top[2], top[3], 1 }, { 1280, 0, 0, 0, top[1], top[2], top[3], 1 },
      { 1280, 600, 0, 0, low[1], low[2], low[3], 1 }, { 1040, 600, 0, 0, low[1], low[2], low[3], 1 } })
    lg.draw(sc.skyMesh)
    for _, b in ipairs(sc.skyline) do
      lg.setColor(0.12 + d * 0.2, 0.12 + d * 0.15, 0.16 + d * 0.12)
      lg.rectangle("fill", b.x, b.top, b.w, GROUND - b.top)
    end
    -- the hospital: pale stone, a grid of dark windows
    lg.setColor(hex("#b8b0a2"))
    lg.rectangle("fill", 0, 0, 1050, GROUND)
    lg.setColor(hex("#a29a8c"))
    for y = 0, GROUND, 48 do lg.rectangle("fill", 0, y, 1050, 3) end
    for row = 0, 3 do
      for col = 0, 6 do
        local wx, wy = 60 + col * 145, 80 + row * 170
        if not (row == 1 and col == 4) and wy < 500 then
          lg.setColor(hex("#2a2c32"))
          lg.rectangle("fill", wx, wy, 90, 120)
          lg.setColor(hex("#8a8274"))
          lg.rectangle("fill", wx - 8, wy + 120, 106, 10)
        end
      end
    end
    -- the ledge under Sal's window, and the geraniums next door
    lg.setColor(hex("#8a8274"))
    lg.rectangle("fill", 590, 412, 260, 14)
    lg.setColor(hex("#6a4a32"))
    lg.rectangle("fill", 862, 392, 80, 20)
    for k = 0, 4 do
      lg.setColor(0.85, 0.12, 0.12)
      lg.circle("fill", 872 + k * 15, 384 - (k % 2) * 6, 7)
      lg.setColor(0.2, 0.5, 0.2)
      lg.circle("fill", 868 + k * 15, 392, 5)
    end
    -- entrance and lettering
    lg.setColor(hex("#3a3632"))
    lg.rectangle("fill", 230, 500, 120, 100)
    lg.setColor(hex("#4a463e"))
    lg.setFont(S.signFont)
    lg.printf("ST. AGNES HOSPITAL", 120, 466, 340, "center")
    -- Sal's window is painted here (not as an emissive) so the birds on the ledge
    -- sit in front of it; the light right behind the glass keeps it bright anyway
    lg.setColor(hex("#f4dca8"))
    lg.rectangle("fill", 640, 250, 160, 145)
    lg.setColor(hex("#e8e4dc"))
    lg.rectangle("fill", 652, 352, 130, 20)
    lg.setColor(hex("#7a8aa0"))
    lg.rectangle("fill", 680, 344, 100, 14)               -- blanket
    lg.setColor(hex("#c9a080"))
    lg.circle("fill", 668, 340 - (g.salAwake and 18 or 0), 10) -- Sal's head, rising when he wakes
    lg.setColor(hex("#3a3a3a"))
    lg.rectangle("fill", 770, 270, 3, 82)                 -- IV pole
    lg.rectangle("fill", 740, 280, 26, 20)
    local beep = (t % 1.2) < 0.15
    lg.setColor(0.3, 1, 0.5, beep and 1 or 0.5)
    lg.line(742, 292, 748, 292, 751, 284, 754, 298, 757, 292, 764, 292)
    lg.setColor(hex("#2a2620"))
    for _, p in ipairs(sc.mull) do lg.polygon("fill", p) end
    sidewalk(hex("#5a5650"))
    lg.setColor(hex("#1b1b1b"))
    lg.rectangle("fill", 186, 340, 8, 260)
    lg.polygon("fill", 170, 332, 214, 326, 216, 338, 168, 342)
  end

  function sc.emissive(g, t)
    glow(720, 322, 4, 3, 1, 0.85, 0.6, 0.35)
    glow(190, 334, 1.8, 1.4, 1, 0.86, 0.62, 0.8 * (1 - g.dawn * 0.8))
    if g.dawn > 0 then glow(1160, 560, 9, 5, 1, 0.6, 0.3, 0.5 * g.dawn) end
  end
  return sc
end

return S
