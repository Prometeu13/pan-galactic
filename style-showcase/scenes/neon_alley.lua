-- NEON, scene 2: a rainy street of neon signs.
--
-- The trick that sells "wet street" is a reflection, and a reflection is cheap: draw
-- the street into a Canvas, then draw that same Canvas again upside-down below the
-- kerb, through a tiny shader that wobbles it sideways (ripples), stretches it, and
-- darkens it. Everything bright gets a second life in the puddles for free.
--
-- Neon tubes are drawn three times: a wide dim halo, the coloured tube, and a thin
-- white-hot core. Bloom does the rest. Signs flicker by multiplying their alpha with
-- a noisy on/off signal.

local gfx = require("core.gfx")
local view = require("core.view")
local moonshine = require("moonshine")

local lg = love.graphics
local KERB = 520               -- where the pavement meets the wet road

local S = {
  title = "Neon Synthwave",
  subtitle = "Rain on Kiro Street",
  blurb = "A cyberpunk shopping street in the rain: neon tube signs, steam, an umbrella walker, and the whole scene mirrored in the wet road.",
  techniques = {
    "Reflection: the scene Canvas drawn upside-down through a ripple shader",
    "Neon tube = halo + coloured line + white core, then bloom",
    "Sign flicker: alpha multiplied by a noisy on/off signal",
    "Sign icons are polylines and arcs (bowl, glass, cross, arrow)",
    "Megatowers: rectangles with a hashed grid of lit windows, baked once",
    "Rain streaks, splash rings on the road, steam as rising soft particles",
  },
  libs = {
    "moonshine: glow (bloom) and chromasep (lens fringing)",
  },
  genres = { "Cyberpunk adventures and visual novels", "Side-scrolling action / beat 'em ups", "Detective games in the rain", "Shop / hub screens" },
  warmup = 3,
}

local RIPPLE = [[
extern number time;
extern number kerb;      // kerb height as a 0..1 texture coordinate
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  // d = how far below the kerb this pixel's mirror image is: 0 (kerb) .. 1 (far edge)
  float d = clamp((kerb - uv.y) / (kerb * 0.8), 0.0, 1.0);
  float wob = sin(d * 90.0 + time * 3.0) * 0.004 + sin(d * 31.0 - time * 1.7) * 0.006;
  vec2 p = vec2(uv.x + wob * (0.25 + d * 1.5), uv.y);
  vec4 c = Texel(tex, p);
  float fade = mix(1.0, 0.4, d);
  return vec4(c.rgb * fade * vec3(0.85, 0.92, 1.1), 1.0) * color;
}
]]

-- three passes: halo, tube, core
local function tube(col, w, a, pts, closed)
  local function stroke()
    if closed then lg.polygon("line", pts) else lg.line(pts) end
  end
  lg.setLineJoin("bevel")
  lg.setColor(col[1], col[2], col[3], 0.3 * a)
  lg.setLineWidth(w * 5)
  stroke()
  lg.setColor(col[1], col[2], col[3], a)
  lg.setLineWidth(w)
  stroke()
  lg.setColor(1, 1, 1, 0.85 * a)
  lg.setLineWidth(math.max(1, w * 0.35))
  stroke()
  lg.setLineJoin("miter")
end

local function arcPts(cx, cy, rx, ry, a1, a2, n)
  local pts = {}
  for i = 0, n do
    local a = a1 + (a2 - a1) * i / n
    pts[#pts + 1] = cx + math.cos(a) * rx
    pts[#pts + 1] = cy + math.sin(a) * ry
  end
  return pts
end

local function neonText(text, font, x, y, col, a, limit, align)
  lg.setFont(font)
  for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
    lg.setColor(col[1], col[2], col[3], 0.3 * a)
    lg.printf(text, x + o[1], y + o[2], limit, align)
  end
  lg.setColor(gfx.lerp(col[1], 1, 0.55), gfx.lerp(col[2], 1, 0.55), gfx.lerp(col[3], 1, 0.55), a)
  lg.printf(text, x, y, limit, align)
end

local PINK, CYAN, YELLOW, GREEN, VIOLET, ORANGE =
  { 1, 0.2, 0.6 }, { 0.2, 0.9, 1 }, { 1, 0.85, 0.25 }, { 0.3, 1, 0.5 }, { 0.7, 0.4, 1 }, { 1, 0.5, 0.2 }

function S:load()
  self.t = 0
  self.scene = lg.newCanvas(1280, 720)
  self.ripple = lg.newShader(RIPPLE)
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.big = lg.newFont(44)
  self.mid = lg.newFont(28)
  self.small = lg.newFont(15)
  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.chromasep)
  self.fx.glow.min_luma = 0.35
  self.fx.glow.strength = 6
  self.fx.chromasep.radius = 1.5

  -- backdrop baked once: night sky, megatowers with windows, the shop row's walls
  self.back = lg.newCanvas(1280, 720)
  love.math.setRandomSeed(77)
  lg.push("all")
  lg.setCanvas(self.back)
  lg.clear(gfx.hex("#07041a"))
  lg.setColor(1, 1, 1)
  lg.draw(gfx.vgradient(1280, 300, { { 0, gfx.rgb("#07041a") }, { 1, gfx.rgb("#3a1050") } }))
  for layer = 1, 2 do
    for i = 0, 15 do
      local x = i * 86 + love.math.random(-20, 20)
      local w = love.math.random(50, 110)
      local h = love.math.random(120, 280) * (layer == 1 and 1 or 0.7)
      local top = 300 - h
      local base = layer == 1 and gfx.rgb("#160a30") or gfx.rgb("#0d0620")
      lg.setColor(base)
      lg.rectangle("fill", x, top, w, h + 40)
      if love.math.random() < 0.4 then lg.rectangle("fill", x + w * 0.4, top - 40, 4, 40) end
      for wy = top + 8, 300, 9 do
        for wx = x + 5, x + w - 8, 8 do
          local r = love.math.random()
          if r < 0.2 then
            local c = r < 0.07 and CYAN or (r < 0.13 and PINK or YELLOW)
            lg.setColor(c[1], c[2], c[3], layer == 1 and 0.35 or 0.6)
            lg.rectangle("fill", wx, wy, 4, 4)
          end
        end
      end
    end
  end
  -- the shop row: five buildings of different heights
  self.shops = {
    { x = 0, w = 250, top = 130, col = "#1a1230" },
    { x = 250, w = 210, top = 70, col = "#141028" },
    { x = 460, w = 280, top = 160, col = "#1d1434" },
    { x = 740, w = 230, top = 100, col = "#120e24" },
    { x = 970, w = 310, top = 140, col = "#1a1230" },
  }
  for i, b in ipairs(self.shops) do
    lg.setColor(gfx.hex(b.col))
    lg.rectangle("fill", b.x, b.top, b.w, KERB - b.top)
    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", b.x + b.w - 6, b.top, 6, KERB - b.top)
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("fill", b.x, b.top, b.w, 5)
    -- upper-floor windows, a few lit behind blinds
    for wy = b.top + 26, 320, 62 do
      for wx = b.x + 22, b.x + b.w - 60, 62 do
        local r = love.math.random()
        lg.setColor(0.03, 0.02, 0.08)
        lg.rectangle("fill", wx, wy, 40, 40)
        if r < 0.45 then
          local c = r < 0.15 and { 0.5, 0.8, 1 } or { 1, 0.75, 0.4 }
          lg.setColor(c[1], c[2], c[3], 0.55)
          lg.rectangle("fill", wx + 3, wy + 3, 34, 34)
          lg.setColor(0.03, 0.02, 0.08, 0.7)
          for k = 0, 5 do lg.rectangle("fill", wx + 3, wy + 5 + k * 6, 34, 2) end
          if r < 0.08 then
            lg.setColor(0.03, 0.02, 0.08)
            lg.circle("fill", wx + 20, wy + 22, 7)
            lg.rectangle("fill", wx + 11, wy + 28, 18, 9)
          end
        end
        lg.setColor(0.25, 0.2, 0.4)
        lg.rectangle("fill", wx - 3, wy + 40, 46, 4)
      end
    end
    -- air conditioners and a drain pipe
    lg.setColor(0.2, 0.18, 0.3)
    lg.rectangle("fill", b.x + b.w - 52, b.top + 96, 34, 22)
    lg.setColor(0.1, 0.08, 0.18)
    lg.circle("fill", b.x + b.w - 35, b.top + 107, 8)
    lg.setColor(0.12, 0.1, 0.22)
    lg.rectangle("fill", b.x + 8, b.top, 5, KERB - b.top)
    -- shopfront: a dark glass band with a warm interior
    lg.setColor(0.04, 0.03, 0.09)
    lg.rectangle("fill", b.x + 14, 372, b.w - 28, KERB - 372)
  end
  -- pavement
  lg.setColor(gfx.hex("#191428"))
  lg.rectangle("fill", 0, KERB - 26, 1280, 26)
  lg.setColor(gfx.hex("#2c2444"))
  lg.rectangle("fill", 0, KERB - 26, 1280, 3)
  lg.setColor(0, 0, 0, 0.5)
  for x = 0, 1280, 64 do lg.rectangle("fill", x, KERB - 23, 2, 23) end
  lg.pop()

  love.math.setRandomSeed(5)
  self.rain = {}
  for i = 1, 260 do
    self.rain[i] = { x = love.math.random(-100, 1380), y = love.math.random(-720, 720), v = love.math.random(900, 1300), l = love.math.random(12, 28) }
  end
  self.splash = {}
  for i = 1, 40 do self.splash[i] = { x = love.math.random(0, 1280), y = KERB + 14 + love.math.random() ^ 1.6 * 180, p = love.math.random() } end
  self.steam = {}
  self.walker = { x = 200 }
  self.car = { x = -300 }
end

function S:update(dt)
  self.t = self.t + dt
  for _, r in ipairs(self.rain) do
    r.y = r.y + r.v * dt
    r.x = r.x - r.v * 0.12 * dt
    if r.y > 720 then r.y, r.x = r.y - 760, love.math.random(-100, 1380) end
  end
  if love.math.random() < dt * 9 then
    self.steam[#self.steam + 1] = { x = 884 + love.math.random(-8, 8), y = KERB - 30, life = 0, d = love.math.random() - 0.5 }
  end
  for i = #self.steam, 1, -1 do
    local s = self.steam[i]
    s.life = s.life + dt
    s.y = s.y - 34 * dt
    s.x = s.x + s.d * 16 * dt
    if s.life > 3.5 then table.remove(self.steam, i) end
  end
  self.walker.x = self.walker.x + 46 * dt
  if self.walker.x > 1360 then self.walker.x = -80 end
  self.car.x = self.car.x + 190 * dt
  if self.car.x > 2600 then self.car.x = -400 end
end

-- on/off flicker signal for sign number k
local function flicker(t, k)
  local n = love.math.noise(t * 7 + k * 31.7)
  if k % 3 == 0 and n > 0.72 then return 0.25 end
  return 0.92 + 0.08 * math.sin(t * 40 + k)
end

function S:drawSigns()
  local t = self.t
  -- 1. noodle bar: a bowl with chopsticks and steam, and a blade sign
  local a = flicker(t, 1)
  tube(PINK, 4, a, arcPts(125, 262, 62, 50, 0.08, math.pi - 0.08, 20))
  tube(PINK, 4, a, { 58, 262, 192, 262 })
  tube(PINK, 4, a, { 100, 312, 150, 312 })
  tube(CYAN, 3, a, { 96, 258, 150, 198 })
  tube(CYAN, 3, a, { 112, 258, 170, 204 })
  for k = 0, 2 do
    local pts = {}
    for i = 0, 8 do
      pts[#pts + 1] = 96 + k * 28 + math.sin(i * 0.9 + t * 2 + k) * 6
      pts[#pts + 1] = 246 - i * 7
    end
    tube(YELLOW, 2, a * (0.5 + 0.5 * math.sin(t * 2 + k)), pts)
  end
  neonText("NOODLES", self.mid, 20, 330, YELLOW, a, 210, "center")
  -- 2. hotel: a tall vertical sign hanging off the wall, with an arrow
  a = flicker(t, 2)
  lg.setColor(0.05, 0.04, 0.12)
  lg.rectangle("fill", 404, 96, 62, 260, 6)
  tube(CYAN, 3, a, { 408, 100, 462, 100, 462, 352, 408, 352 }, true)
  local word = "HOTEL"
  for i = 1, #word do
    neonText(word:sub(i, i), self.big, 404, 100 + (i - 1) * 46, CYAN, a, 62, "center")
  end
  tube(PINK, 3, flicker(t, 6), { 300, 344, 380, 344, 364, 330, 380, 344, 364, 358 })
  -- 3. pharmacy cross, blinking, and "24H"
  a = ((t + 0.6) % 1.6 < 1.1) and 1 or 0.15
  tube(GREEN, 4, a, { 574, 196, 606, 196, 606, 228, 638, 228, 638, 260, 606, 260, 606, 292, 574, 292, 574, 260, 542, 260, 542, 228, 574, 228 }, true)
  neonText("24H", self.mid, 500, 326, GREEN, 0.95, 200, "center")
  -- 4. arcade: a star burst and a marquee of chasing bulbs
  a = flicker(t, 4)
  local star = {}
  for i = 0, 9 do
    local r = (i % 2 == 0) and 46 or 20
    local an = i / 10 * math.pi * 2 - math.pi / 2 + math.sin(t) * 0.1
    star[#star + 1] = 855 + math.cos(an) * r
    star[#star + 1] = 200 + math.sin(an) * r
  end
  tube(VIOLET, 3, a, star, true)
  neonText("ARCADE", self.mid, 752, 262, PINK, a, 206, "center")
  for k = 0, 16 do
    local on = (math.floor(t * 8) + k) % 4 == 0
    lg.setColor(1, 0.9, 0.5, on and 1 or 0.2)
    lg.circle("fill", 762 + k * 11.6, 308, 3)
  end
  -- 5. bar: a cocktail glass with an olive, and a wavy underline
  a = flicker(t, 5)
  tube(ORANGE, 4, a, { 1090, 196, 1180, 196, 1135, 250, 1090, 196 })
  tube(ORANGE, 4, a, { 1135, 250, 1135, 300 })
  tube(ORANGE, 4, a, { 1108, 300, 1162, 300 })
  tube(GREEN, 3, a, arcPts(1150, 214, 7, 7, 0, math.pi * 2, 12))
  tube(GREEN, 2, a, { 1154, 210, 1176, 180 })
  neonText("BAR", self.big, 1000, 316, YELLOW, a, 270, "center")
end

function S:drawShopfronts()
  local t = self.t
  -- interiors glowing through the glass
  local tints = { { 1, 0.5, 0.3 }, { 0.3, 0.7, 1 }, { 0.4, 1, 0.6 }, { 0.9, 0.3, 1 }, { 1, 0.7, 0.3 } }
  for i, b in ipairs(self.shops) do
    local c = tints[i]
    lg.setColor(c[1], c[2], c[3], 0.42)
    lg.rectangle("fill", b.x + 20, 380, b.w - 40, KERB - 412)
    lg.setColor(c[1], c[2], c[3], 0.9)
    lg.rectangle("fill", b.x + 20, 380, b.w - 40, 5)
    -- door
    lg.setColor(0.03, 0.02, 0.07)
    lg.rectangle("fill", b.x + b.w * 0.5 - 22, 404, 44, KERB - 430)
    lg.setColor(c[1], c[2], c[3], 0.35)
    lg.rectangle("fill", b.x + b.w * 0.5 - 17, 410, 34, 50)
    -- mullions
    lg.setColor(0.03, 0.02, 0.07)
    for x = b.x + 20, b.x + b.w - 20, 46 do lg.rectangle("fill", x, 380, 3, KERB - 412) end
  end
  -- noodle bar: a cook's silhouette and hanging lanterns
  lg.setColor(0.03, 0.02, 0.07)
  lg.circle("fill", 70, 420, 12)
  lg.rectangle("fill", 54, 430, 32, 60, 6)
  lg.rectangle("fill", 58, 402, 24, 10)
  for k = 0, 3 do
    local x = 40 + k * 56
    local sw = math.sin(t * 1.4 + k) * 3
    lg.setColor(0.03, 0.02, 0.07)
    lg.line(x, 372, x + sw, 386)
    lg.setColor(1, 0.35, 0.2)
    lg.ellipse("fill", x + sw, 396, 11, 13)
    lg.setColor(1, 0.85, 0.5)
    lg.ellipse("fill", x + sw, 396, 5, 9)
  end
  -- vending machine on the pavement
  lg.setColor(0.08, 0.1, 0.2)
  lg.rectangle("fill", 478, KERB - 126, 60, 100, 4)
  lg.setColor(0.5, 0.95, 1)
  lg.rectangle("fill", 484, KERB - 120, 48, 56, 2)
  for r = 0, 2 do
    for c = 0, 3 do
      local col = ({ PINK, YELLOW, GREEN, ORANGE })[(r + c) % 4 + 1]
      lg.setColor(col)
      lg.rectangle("fill", 488 + c * 11, KERB - 116 + r * 18, 7, 13, 2)
    end
  end
  lg.setColor(0.03, 0.02, 0.07)
  lg.rectangle("fill", 488, KERB - 54, 40, 12)
  -- steam vent grate, bin bags, a cat on a crate
  lg.setColor(0.03, 0.02, 0.07)
  lg.rectangle("fill", 868, KERB - 30, 34, 4)
  lg.ellipse("fill", 1228, KERB - 36, 20, 16)
  lg.ellipse("fill", 1254, KERB - 34, 16, 13)
  lg.rectangle("fill", 640, KERB - 52, 40, 26)
  lg.ellipse("fill", 660, KERB - 60, 14, 9)
  lg.circle("fill", 672, KERB - 68, 7)
  lg.polygon("fill", 667, KERB - 73, 669, KERB - 81, 673, KERB - 74)
  lg.polygon("fill", 673, KERB - 74, 677, KERB - 81, 678, KERB - 72)
  lg.setLineWidth(3)
  lg.line(love.math.newBezierCurve(648, KERB - 58, 636, KERB - 60, 634 + math.sin(t * 2) * 3, KERB - 76):render(3))
  lg.setColor(0.6, 1, 0.5)
  lg.circle("fill", 670, KERB - 69, 1.2)
  lg.circle("fill", 675, KERB - 69, 1.2)
  -- cables strung across the street, with drips of light
  lg.setColor(0.02, 0.01, 0.05)
  lg.setLineWidth(2)
  for k = 0, 2 do
    local pts = {}
    for i = 0, 30 do
      local u = i / 30
      pts[#pts + 1] = u * 1280
      pts[#pts + 1] = 70 + k * 26 + math.sin(u * math.pi * (3 + k)) ^ 2 * 22
    end
    lg.line(pts)
  end
end

function S:drawWalker()
  local t = self.t
  local x, y = self.walker.x, KERB - 26
  local step = math.sin(t * 5)
  local ink = { 0.02, 0.015, 0.05 }
  lg.setColor(ink)
  -- legs
  lg.setLineWidth(8)
  lg.line(x, y - 56, x + step * 13, y - 28, x + step * 15, y)
  lg.line(x, y - 56, x - step * 13, y - 28, x - step * 15, y)
  -- long coat, head
  lg.polygon("fill", x - 15, y - 112, x + 15, y - 112, x + 20, y - 44, x - 20, y - 44)
  lg.circle("fill", x + 2, y - 124, 11)
  -- arm and umbrella handle
  lg.setLineWidth(6)
  lg.line(x + 10, y - 102, x + 18, y - 122)
  lg.setLineWidth(2.5)
  lg.line(x + 18, y - 104, x + 18, y - 172)
  -- a clear umbrella: dark ribs, a glowing rim that picks up the signs
  local rim = arcPts(x + 18, y - 150, 58, 34, math.pi, math.pi * 2, 16)
  lg.setColor(0.6, 0.9, 1, 0.1)
  lg.polygon("fill", rim)
  tube(CYAN, 2, 0.9, rim)
  lg.setColor(0.6, 0.9, 1, 0.35)
  lg.setLineWidth(1)
  for k = 1, 4 do lg.line(x + 18, y - 183, x + 18 - 58 + k * 23.2, y - 150) end
  -- coat hem lit by the shop windows
  lg.setColor(1, 0.3, 0.6, 0.6)
  lg.setLineWidth(2)
  lg.line(x + 15, y - 112, x + 20, y - 44)
end

function S:drawStreet()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.back)
  -- flying traffic between the towers
  for k = 0, 2 do
    local x = (self.car.x * (0.5 + k * 0.2) + k * 500) % 1700 - 200
    local y = 60 + k * 50
    lg.setColor(1, 0.3, 0.3)
    lg.rectangle("fill", x, y, 10, 3)
    lg.setColor(1, 1, 0.8)
    lg.rectangle("fill", x + 26, y, 6, 3)
    lg.setColor(0.4, 0.8, 1, 0.3)
    lg.rectangle("fill", x - 60, y + 1, 60, 1)
  end
  -- a holographic billboard high up
  local ha = 0.5 + 0.2 * math.sin(t * 3)
  lg.setColor(0.3, 0.9, 1, ha * 0.25)
  lg.rectangle("fill", 760, 20, 190, 64)
  for k = 0, 7 do
    lg.setColor(0.3, 0.9, 1, ha * 0.5)
    lg.rectangle("fill", 760, 22 + k * 8 + (t * 20 % 8), 190, 1)
  end
  neonText("FLY KIRO AIR", self.small, 760, 40, CYAN, ha + 0.3, 190, "center")
  self:drawShopfronts()
  self:drawSigns()
  -- street lamp
  lg.setColor(0.03, 0.02, 0.07)
  lg.rectangle("fill", 360, 300, 6, KERB - 326)
  lg.rectangle("fill", 360, 300, 46, 5)
  lg.setColor(1, 0.9, 0.7)
  lg.ellipse("fill", 398, 308, 10, 4)
  lg.setBlendMode("add")
  lg.setColor(1, 0.85, 0.6, 0.5)
  lg.draw(self.glow, 398, 312, 0, 1.3, 1.3, 64, 64)
  lg.setColor(1, 0.85, 0.6, 0.2)
  lg.polygon("fill", 390, 310, 406, 310, 470, KERB - 26, 330, KERB - 26)
  -- coloured light spilling from each sign
  local spill = { { 125, 280, PINK }, { 436, 230, CYAN }, { 590, 250, GREEN }, { 855, 230, VIOLET }, { 1135, 250, ORANGE } }
  for _, sp in ipairs(spill) do
    lg.setColor(sp[3][1], sp[3][2], sp[3][3], 0.3)
    lg.draw(self.soft, sp[1], sp[2], 0, 4.4, 4.4, 64, 64)
  end
  lg.setBlendMode("alpha")
  self:drawWalker()
  -- steam
  for _, s in ipairs(self.steam) do
    local u = s.life / 3.5
    lg.setColor(0.8, 0.75, 0.95, 0.16 * (1 - u))
    lg.draw(self.soft, s.x, s.y, 0, 0.3 + u * 1.2, 0.3 + u * 1.2, 64, 64)
  end
end

function S:draw()
  local t = self.t
  -- 1. the street, into its own canvas
  lg.setCanvas(self.scene)
  lg.clear(0, 0, 0, 1)
  self:drawStreet()
  lg.setCanvas({ view.canvas, stencil = true })

  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.setBlendMode("alpha", "premultiplied")
    lg.setScissor(0, 0, 1280, KERB)
    lg.draw(self.scene)
    lg.setScissor()
    -- 2. the same canvas, mirrored below the kerb through the ripple shader
    self.ripple:send("time", t)
    lg.setShader(self.ripple)
    self.ripple:send("kerb", KERB / 720)
    local sy = (720 - KERB) / (KERB * 0.8)          -- squash: we see the road at a shallow angle
    lg.setScissor(0, KERB, 1280, 720 - KERB)
    lg.draw(self.scene, 0, KERB + KERB * sy, 0, 1, -sy)
    lg.setScissor()
    lg.setShader()
    lg.setBlendMode("alpha")
    -- road markings and the kerb edge on top of the reflection
    lg.setColor(1, 1, 1, 0.1)
    for x = -40, 1280, 170 do lg.polygon("fill", x, 640, x + 90, 640, x + 80, 652, x - 14, 652) end
    lg.setColor(0.02, 0.01, 0.05)
    lg.rectangle("fill", 0, KERB, 1280, 6)
    -- splash rings where drops hit the road
    for _, s in ipairs(self.splash) do
      local u = (t * 1.6 + s.p) % 1
      local scale = 0.5 + (s.y - KERB) / 200
      lg.setColor(0.8, 0.9, 1, 0.45 * (1 - u))
      lg.setLineWidth(1)
      lg.ellipse("line", s.x, s.y, (3 + u * 16) * scale, (1 + u * 5) * scale)
    end
    -- rain
    lg.setLineWidth(1.2)
    for _, r in ipairs(self.rain) do
      lg.setColor(0.75, 0.85, 1, 0.3)
      lg.line(r.x, r.y, r.x + r.l * 0.12, r.y - r.l)
    end
  end)
end

return S
