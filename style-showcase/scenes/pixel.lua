-- PIXEL ART: a 320x180 canvas with a fixed 16-colour palette, scaled up 4x with
-- "nearest" filtering so every pixel stays a crisp square.
--
-- Nothing here is an image file:
--   * sprites are strings in this file, one character per pixel (see HERO, CAT, PINE)
--   * the pixel font is also strings, turned into a LÖVE ImageFont at load time
--   * the sky is a gradient made of only 5 colours, blended with ordered (Bayer) dithering
--   * lines (timber frames, shooting star) use Bresenham so they are pixel-perfect

local gfx = require("core.gfx")
local maid64 = require("maid64")
local Bresenham = require("Bresenham")
local tick = require("tick")
local pixelfont = require("core.pixelfont") -- 3x5 glyphs as strings -> ImageFont

local lg = love.graphics
local PW, PH = 320, 180

local S = {
  title = "Pixel Art",
  subtitle = "Moonlit Village",
  blurb = "A real low-resolution canvas (320x180) with a strict 16-colour palette, scaled 4x. Sprites, font and dithering all come from strings and loops.",
  techniques = {
    "Sprites are tables of strings: one character = one palette colour",
    "Pixel font: 3x5 glyphs as strings -> ImageData -> love.graphics.newImageFont",
    "Sky gradient from 5 colours using a 4x4 Bayer dither matrix",
    "Lamp glow = dithered circle (no alpha blending, keeps the palette strict)",
    "Pixel-perfect lines with Bresenham; integer positions only",
  },
  libs = {
    "maid64: low-res canvas with nearest-neighbour upscaling",
    "Bresenham: pixel-perfect line rasterising",
    "tick: timed events (shooting stars, window lights)",
  },
  genres = { "Retro platformers and metroidvanias", "Top-down RPGs and roguelikes", "Fantasy-console style arcade games", "Game jams (fast to author)" },
  warmup = 4,
}

-- 16-colour palette. Characters are used in the sprite strings below.
local PAL = {
  k = "#0d0b1e", n = "#1d1b3a", b = "#2f2d5c", v = "#4b3f7a",
  p = "#7a5c9e", m = "#f2e8c9", y = "#ffd166", o = "#f08a4b",
  r = "#b8432f", d = "#5c2a3d", g = "#2e4a3f", G = "#3f7a4f",
  l = "#8fbf6a", w = "#6b4a3a", s = "#e8b796", c = "#3a7bd5",
}
local C = {}
for k, v in pairs(PAL) do C[k] = gfx.rgb(v) end

local HERO_TOP = {
  "..kkkk..",
  ".krrrrk.",
  ".krrrrrk",
  ".kssksk.",
  ".kssssk.",
  "..kkkk..",
  ".kcccck.",
}
local HERO_LEGS = {
  { "kscccck.", ".kcccck.", ".kwwwwk.", ".kw..wk.", ".kk..kk." },
  { ".kccccsk", ".kcccck.", ".kwwwwk.", "..kwwk..", "..kkkk.." },
  { ".kcccksk", ".kcccck.", ".kwwwwk.", "kw....wk", "kk....kk" },
  { ".kccccsk", ".kcccck.", ".kwwwwk.", "..kwwk..", "..kkkk.." },
}

local CAT = {
  { "k...k...", "kk.kk...", "kkkkk...", "kykyk..k", "kkkkkk.k", ".kkkkkkk" },
  { "k...k...", "kk.kk...", "kkkkk..k", "kykyk.k.", "kkkkkkk.", ".kkkkkk." },
}

local PINE = {
  "....g....",
  "...gGg...",
  "..ggGgg..",
  "...ggg...",
  "..gGggg..",
  ".ggggGgg.",
  "...ggg...",
  "..gGgggg.",
  ".gggggGgg",
  "ggGgggggg",
  "...www...",
  "...www...",
}

local BAYER = {
  { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 },
}
local function bayer(x, y) return (BAYER[y % 4 + 1][x % 4 + 1] + 0.5) / 16 end

local function hill(x) return math.floor(128 + math.sin(x * 0.03) * 4 + math.sin(x * 0.011 + 1) * 6) end

-- Static background baked once into an ImageData: dithered sky, moon, mountains.
local function bakeBackground()
  local d = love.image.newImageData(PW, PH)
  local bands = { C.k, C.n, C.b, C.v, C.p }
  for y = 0, PH - 1 do
    for x = 0, PW - 1 do
      local t = math.min(1, y / 125) * (#bands - 1)
      local i = math.floor(t)
      local f = t - i
      local col = bands[math.min(#bands, i + 1)]
      if f > bayer(x, y) and i + 2 <= #bands then col = bands[i + 2] end
      d:setPixel(x, y, col[1], col[2], col[3], 1)
    end
  end
  -- Moon with a dithered halo.
  local mx, my = 252, 34
  for y = my - 30, my + 30 do
    for x = mx - 30, mx + 30 do
      local dist = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
      if dist <= 12 then
        local col = C.m
        if (x - mx + 4) ^ 2 + (y - my + 2) ^ 2 < 10 or (x - mx - 5) ^ 2 + (y - my - 4) ^ 2 < 5 then col = C.s end
        d:setPixel(x, y, col[1], col[2], col[3], 1)
      elseif dist < 22 and (22 - dist) / 10 * 0.6 > bayer(x, y) then
        local r, g, b = d:getPixel(x, y)
        local up = (r + g + b < 0.5) and C.v or C.p
        d:setPixel(x, y, up[1], up[2], up[3], 1)
      end
    end
  end
  -- Distant mountains (two layers) from noise.
  for x = 0, PW - 1 do
    local h1 = math.floor(96 - gfx.fbm(x * 0.012, 3.1, 4) * 40)
    local h2 = math.floor(112 - gfx.fbm(x * 0.02 + 9, 1.7, 4) * 26)
    for y = h1, PH - 1 do d:setPixel(x, y, C.n[1], C.n[2], C.n[3], 1) end
    for y = h2, PH - 1 do d:setPixel(x, y, C.k[1], C.k[2], C.k[3], 1) end
    -- snow caps: the top pixels of the far range catch the moonlight
    if h1 < 78 then
      for y = h1, h1 + 1 do d:setPixel(x, y, C.p[1], C.p[2], C.p[3], 1) end
    end
  end
  -- Village ground and the pond.
  for x = 0, PW - 1 do
    local hy = hill(x)
    for y = hy, PH - 1 do
      local col = (y == hy) and C.l or ((y < hy + 3) and C.G or C.g)
      d:setPixel(x, y, col[1], col[2], col[3], 1)
    end
  end
  -- Foreground: grass tufts and flowers, a few pixels each.
  love.math.setRandomSeed(3)
  for _ = 1, 140 do
    local x, y = love.math.random(1, PW - 2), love.math.random(136, 157)
    if y > hill(x) + 3 then
      d:setPixel(x, y, C.G[1], C.G[2], C.G[3], 1)
      d:setPixel(x - 1, y + 1, C.G[1], C.G[2], C.G[3], 1)
      d:setPixel(x + 1, y + 1, C.G[1], C.G[2], C.G[3], 1)
    end
  end
  for _ = 1, 40 do
    local x, y = love.math.random(1, PW - 2), love.math.random(140, 157)
    local col = ({ C.y, C.o, C.m, C.p })[love.math.random(1, 4)]
    if y > hill(x) + 3 then
      d:setPixel(x, y, col[1], col[2], col[3], 1)
      d:setPixel(x, y + 1, C.G[1], C.G[2], C.G[3], 1)
    end
  end
  for y = 160, PH - 1 do
    for x = 0, PW - 1 do
      local col = ((x + y) % 2 == 0 and y < 162) and C.v or C.b
      if y >= 166 then col = C.n end
      d:setPixel(x, y, col[1], col[2], col[3], 1)
    end
  end
  local img = lg.newImage(d)
  img:setFilter("nearest", "nearest")
  return img
end

-- Dithered lamp glow: a circle whose "alpha" is a dither threshold, not blending.
local function bakeGlow(r)
  local size = r * 2 + 1
  local d = love.image.newImageData(size, size)
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      local dist = math.sqrt((x - r) ^ 2 + (y - r) ^ 2) / r
      if dist < 1 and (1 - dist) ^ 1.5 * 0.45 > bayer(x, y) then d:setPixel(x, y, C.o[1], C.o[2], C.o[3], 1) end
    end
  end
  local img = lg.newImage(d)
  img:setFilter("nearest", "nearest")
  return img
end

function S:load()
  maid64.setup(PW, PH)
  self.t = 0
  self.tick = tick.group()
  self.bg = bakeBackground()
  self.glow = bakeGlow(22)
  self.font = pixelfont.make()

  self.heroFrames = {}
  for i, legs in ipairs(HERO_LEGS) do
    local rows = {}
    for _, r in ipairs(HERO_TOP) do rows[#rows + 1] = r end
    for _, r in ipairs(legs) do rows[#rows + 1] = r end
    self.heroFrames[i] = gfx.spriteFromStrings(rows, C)
  end
  self.cat = { gfx.spriteFromStrings(CAT[1], C), gfx.spriteFromStrings(CAT[2], C) }
  self.pine = gfx.spriteFromStrings(PINE, C)

  love.math.setRandomSeed(42)
  self.stars = {}
  for i = 1, 70 do
    self.stars[i] = { x = love.math.random(0, PW - 1), y = love.math.random(0, 70), p = love.math.random() * 6 }
  end
  self.houses = {
    { x = 40, w = 26, h = 18, roof = C.r },
    { x = 96, w = 34, h = 22, roof = C.d },
    { x = 170, w = 24, h = 16, roof = C.r },
    { x = 216, w = 30, h = 20, roof = C.d },
  }
  self.windows = {}
  for i, h in ipairs(self.houses) do self.windows[i] = { true, love.math.random() < 0.6 } end
  self.hero = { x = -10, frame = 1, ft = 0 }
  self.smoke = {}
  self.flies = {}
  for i = 1, 10 do
    self.flies[i] = { x = love.math.random(0, PW), y = love.math.random(120, 155), a = love.math.random() * 6 }
  end
  self.shooting = nil

  -- tick: recurring timed events.
  self.tick:recur(function()
    self.shooting = { x = love.math.random(20, 200), y = love.math.random(8, 30), len = 0 }
  end, 3.2)
  self.tick:recur(function()
    local i = love.math.random(1, #self.windows)
    local j = love.math.random(1, 2)
    self.windows[i][j] = not self.windows[i][j]
  end, 0.9)
  self.tick:recur(function()
    for _, h in ipairs(self.houses) do
      local base = hill(h.x + h.w / 2)
      self.smoke[#self.smoke + 1] = { x = h.x + h.w - 7, y = base - h.h - h.w / 2 - 2, life = 0 }
    end
  end, 0.45)
end

function S:update(dt)
  self.t = self.t + dt
  self.tick:update(dt)
  local hero = self.hero
  hero.x = hero.x + 18 * dt
  if hero.x > PW + 10 then hero.x = -12 end
  hero.ft = hero.ft + dt
  if hero.ft > 0.14 then hero.ft = 0; hero.frame = hero.frame % 4 + 1 end
  for i = #self.smoke, 1, -1 do
    local s = self.smoke[i]
    s.life = s.life + dt
    s.y = s.y - 6 * dt
    s.x = s.x + 4 * dt
    if s.life > 3 then table.remove(self.smoke, i) end
  end
  for _, f in ipairs(self.flies) do
    f.a = f.a + dt * (0.8 + (f.x % 3) * 0.2)
    f.x = (f.x + math.cos(f.a) * 6 * dt) % PW
    f.y = f.y + math.sin(f.a * 1.3) * 4 * dt
  end
  if self.shooting then
    self.shooting.len = self.shooting.len + 120 * dt
    if self.shooting.len > 90 then self.shooting = nil end
  end
end

local function px(x, y) lg.rectangle("fill", math.floor(x), math.floor(y), 1, 1) end

function S:drawHouse(h, lit)
  local x, w = h.x, h.w
  local base = hill(x + w / 2)
  local top = base - h.h
  -- walls + timber frame drawn with Bresenham
  lg.setColor(C.m)
  lg.rectangle("fill", x, top, w, h.h)
  lg.setColor(C.w)
  lg.rectangle("fill", x, top, w, 1)
  lg.rectangle("fill", x, top, 1, h.h)
  lg.rectangle("fill", x + w - 1, top, 1, h.h)
  Bresenham.line(x, base - 1, x + 8, top, function(bx, by) px(bx, by) return true end)
  Bresenham.line(x + w - 1, base - 1, x + w - 9, top, function(bx, by) px(bx, by) return true end)
  -- roof: one row at a time, each row 2px narrower -> a pixel-perfect triangle
  local half = math.floor(w / 2) + 2
  for i = 0, half do
    lg.setColor(i == 0 and C.k or h.roof)
    lg.rectangle("fill", x - 2 + i, top - i, w + 4 - i * 2, 1)
  end
  lg.setColor(C.k)
  lg.rectangle("fill", x - 2, top, w + 4, 1)
  -- chimney
  lg.setColor(C.d)
  lg.rectangle("fill", x + w - 9, top - half + 2, 4, half - 4)
  -- door and windows (light toggled by tick events)
  lg.setColor(C.w)
  lg.rectangle("fill", x + math.floor(w / 2) - 2, base - 7, 5, 7)
  for j, wx in ipairs({ x + 3, x + w - 8 }) do
    lg.setColor(lit[j] and C.y or C.b)
    lg.rectangle("fill", wx, top + 4, 5, 5)
    lg.setColor(C.w)
    lg.rectangle("fill", wx + 2, top + 4, 1, 5)
    lg.rectangle("fill", wx, top + 6, 5, 1)
  end
end

function S:draw()
  -- Draw at 320x180 into maid64's canvas...
  maid64.start()
  lg.setLineStyle("rough")
  lg.setColor(1, 1, 1)
  lg.draw(self.bg, 0, 0)

  for _, s in ipairs(self.stars) do
    local on = math.sin(self.t * 2 + s.p) > -0.2
    if on then
      lg.setColor(math.sin(self.t * 3 + s.p * 2) > 0.7 and C.m or C.p)
      px(s.x, s.y)
    end
  end
  if self.shooting then
    local sh = self.shooting
    local x2, y2 = math.floor(sh.x + sh.len), math.floor(sh.y + sh.len * 0.4)
    local x1, y1 = math.floor(sh.x + math.max(0, sh.len - 22)), math.floor(sh.y + math.max(0, sh.len - 22) * 0.4)
    Bresenham.line(x1, y1, x2, y2, function(bx, by, n)
      lg.setColor(n > 14 and C.m or (n > 6 and C.p or C.v))
      px(bx, by)
      return true
    end)
  end

  for _, tx in ipairs({ 8, 140, 200, 262, 300 }) do
    lg.setColor(1, 1, 1)
    lg.draw(self.pine, tx, hill(tx + 4) - 11)
  end
  for i, h in ipairs(self.houses) do self:drawHouse(h, self.windows[i]) end

  -- Cat on the second roof, tail flicking.
  local h2 = self.houses[2]
  lg.setColor(1, 1, 1)
  lg.draw(self.cat[math.floor(self.t * 2) % 2 + 1], h2.x + 4, hill(h2.x + h2.w / 2) - h2.h - 9)

  for _, s in ipairs(self.smoke) do
    lg.setColor(s.life < 1 and C.p or (s.life < 2 and C.v or C.b))
    px(s.x + math.sin(s.life * 3) * 1.5, s.y)
    px(s.x + 1 + math.sin(s.life * 3) * 1.5, s.y)
  end

  -- Lamp post + dithered glow.
  local lx = 150
  local lb = hill(lx)
  lg.setColor(1, 1, 1)
  lg.draw(self.glow, lx - 22, lb - 22 - 22)
  lg.setColor(C.v)
  lg.rectangle("fill", lx, lb - 22, 1, 22)
  lg.rectangle("fill", lx - 1, lb - 24, 3, 2)
  lg.setColor(C.y)
  lg.rectangle("fill", lx - 1, lb - 26, 3, 2)

  -- Fence along the pond: posts every 9px, rails and braces with Bresenham.
  for fx = 2, PW, 9 do
    lg.setColor(C.w)
    lg.rectangle("fill", fx, 149, 2, 9)
    lg.setColor(C.k)
    lg.rectangle("fill", fx, 158, 2, 1)
  end
  lg.setColor(C.w)
  lg.rectangle("fill", 0, 151, PW, 1)
  lg.rectangle("fill", 0, 155, PW, 1)
  for fx = 2, PW - 9, 18 do
    Bresenham.line(fx + 2, 155, fx + 9, 151, function(bx, by) px(bx, by) return true end)
  end

  -- Hero walking along the path.
  local hero = self.hero
  local hx = math.floor(hero.x)
  lg.setColor(1, 1, 1)
  lg.draw(self.heroFrames[hero.frame], hx, hill(hx + 4) - 12 + (hero.frame % 2 == 0 and -1 or 0))

  -- Moon reflection: horizontal streaks that shimmer on the pond.
  for i = 0, 5 do
    local y = 161 + i * 3
    local w = 10 - i + math.floor(math.sin(self.t * 3 + i) * 2)
    lg.setColor(i < 2 and C.m or C.p)
    lg.rectangle("fill", 252 - math.floor(w / 2) + math.floor(math.sin(self.t * 2 + i * 1.7) * 2), y, w, 1)
  end

  for _, f in ipairs(self.flies) do
    if math.sin(self.t * 4 + f.a * 3) > 0 then
      lg.setColor(C.y)
      px(f.x, f.y)
    end
  end

  lg.setFont(self.font)
  lg.setColor(C.k)
  lg.print("MOONLIT VILLAGE", 131, 6)
  lg.setColor(C.m)
  lg.print("MOONLIT VILLAGE", 130, 5)
  lg.setColor(C.p)
  lg.print("320X180 - 16 COLOURS", 121, 13)
  lg.setLineStyle("smooth")

  -- ...then scale it 4x onto the 1280x720 screen canvas with nearest filtering.
  lg.setCanvas({ require("core.view").canvas, stencil = true })
  lg.setColor(1, 1, 1)
  lg.draw(maid64.canvas, 0, 0, 0, 1280 / PW, 720 / PH)
end

return S
