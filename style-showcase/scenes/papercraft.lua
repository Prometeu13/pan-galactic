-- PAPERCRAFT: a diorama of cut paper layers.
--
-- Paper reads as paper because of three things:
--   * every layer casts a soft shadow on the layer behind it (the same shape drawn
--     dark, offset down-right, a few times with growing offsets = a cheap blur)
--   * a thin lighter line along each layer's top edge: the cut edge catching light
--   * a fibre texture multiplied over each layer, and flat colours picked from one
--     palette with vivid (lighter for highlights, darker for folds)
-- The layers shift with the mouse (or sway gently on their own) by an amount set by
-- their depth, so the diorama feels like real stacked sheets. The sun's rays are
-- folded: each ray is two triangles, one light and one dark.

local gfx = require("core.gfx")
local view = require("core.view")
local vivid = require("vivid")

local lg = love.graphics

local S = {
  title = "Papercraft",
  subtitle = "Paper Forest Diorama",
  blurb = "Stacked paper cutouts with soft drop shadows, lit cut edges, fibre texture, a folded paper sun, origami birds and parallax.",
  techniques = {
    "Each layer: soft shadow (shape repeated with growing offsets), fill, lit top edge",
    "Paper fibre texture multiplied over every layer",
    "Folded sun rays: each ray is a light triangle + a dark triangle",
    "Parallax by depth from the mouse (or a slow sway when idle)",
    "Palette shades derived with vivid (lighten for edges, darken for folds)",
  },
  libs = {
    "vivid: lighter cut edges and darker folds from each base colour",
  },
  genres = { "Puzzle-platformers with a crafted look", "Storybook and children's adventures", "Cosy exploration games", "Menus and level-select maps" },
  controls = "move the mouse to tilt the diorama.",
  warmup = 2,
}

local function shade(c, amt)
  local r, g, b
  if amt >= 0 then r, g, b = vivid.lighten(amt, c[1], c[2], c[3]) else r, g, b = vivid.darken(-amt, c[1], c[2], c[3]) end
  return { r, g, b }
end

-- Hill silhouette with little tree cutouts standing on it.
local function hillLayer(baseY, amp, freq, seed, trees)
  local pts = {}
  for x = -80, 1360, 10 do
    pts[#pts + 1] = x
    pts[#pts + 1] = baseY - gfx.fbm(x * freq + seed, seed, 3) * amp
  end
  local treeList = {}
  if trees then
    for k = 1, trees do
      local x = love.math.random(-40, 1320)
      local i = math.floor((x + 80) / 10) * 2 + 1
      treeList[#treeList + 1] = { x = x, y = pts[i + 1] + 6, h = love.math.random(50, 110), round = love.math.random() < 0.4 }
    end
  end
  return pts, treeList
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(99)
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local fib = love.math.noise(x * 0.9, y * 0.12) * 0.05 + love.math.noise(x * 0.12, y * 0.9) * 0.04
    local v = 1 - fib - gfx.fbm(x * 0.02, y * 0.02, 2) * 0.04
    return v, v, v, 1
  end)
  self.fibre = lg.newImage(d)

  local palette = {
    { gfx.hex("#c9b3e6") }, { gfx.hex("#9fa8e0") }, { gfx.hex("#7fc2a8") },
    { gfx.hex("#4fa37c") }, { gfx.hex("#2f7d5c") }, { gfx.hex("#235c45") },
  }
  self.layers = {}
  local specs = {
    { 380, 160, 0.003, 1, 0, 0.1 }, { 430, 140, 0.004, 4, 0, 0.2 }, { 500, 120, 0.005, 7, 14, 0.35 },
    { 570, 110, 0.006, 11, 12, 0.55 }, { 650, 90, 0.007, 15, 8, 0.8 }, { 720, 60, 0.009, 19, 0, 1.0 },
  }
  for i, sp in ipairs(specs) do
    local pts, trees = hillLayer(sp[1], sp[2], sp[3], sp[4], sp[5])
    self.layers[i] = { pts = pts, trees = trees, color = palette[i], depth = sp[6] }
  end
  self.clouds = {
    { x = 220, y = 120, s = 1 }, { x = 760, y = 90, s = 0.75 }, { x = 1060, y = 190, s = 0.6 },
  }
  self.par = { x = 0, y = 0 }
end

function S:update(dt)
  self.t = self.t + dt
  local tx, ty
  if love.window and love.window.hasMouseFocus() then
    local mx, my = view.mouse()
    tx, ty = (mx - 640) / 640, (my - 360) / 360
  else
    tx, ty = math.sin(self.t * 0.4), math.sin(self.t * 0.3) * 0.5
  end
  self.par.x = self.par.x + (tx - self.par.x) * math.min(1, dt * 3)
  self.par.y = self.par.y + (ty - self.par.y) * math.min(1, dt * 3)
end

-- Draw one cutout: shadow, fill, fibre, lit edge. `shape` draws the filled shape.
function S:cutout(shape, color, edge)
  for k = 3, 1, -1 do
    lg.push()
    lg.translate(k * 3, k * 4)
    lg.setColor(0.1, 0.05, 0.15, 0.09)
    shape()
    lg.pop()
  end
  lg.setColor(color)
  shape()
  if edge then
    lg.setColor(shade(color, 0.12))
    lg.setLineWidth(3)
    edge()
  end
end

function S:drawSun()
  local cx, cy = 980, 170
  lg.push()
  lg.translate(cx, cy)
  lg.rotate(self.t * 0.05)
  local sunC = { gfx.hex("#ffc85a") }
  for k = 0, 11 do
    local a = k / 12 * math.pi * 2
    local r1, r2 = 70, 130
    local tipx, tipy = math.cos(a) * r2, math.sin(a) * r2
    local lx, ly = math.cos(a - 0.2) * r1, math.sin(a - 0.2) * r1
    local rx, ry = math.cos(a + 0.2) * r1, math.sin(a + 0.2) * r1
    lg.setColor(0.1, 0.05, 0.15, 0.12)
    lg.polygon("fill", lx + 4, ly + 5, tipx + 4, tipy + 5, rx + 4, ry + 5)
    lg.setColor(shade(sunC, 0.08))
    lg.polygon("fill", lx, ly, tipx, tipy, 0, 0)      -- light half of the fold
    lg.setColor(shade(sunC, -0.1))
    lg.polygon("fill", 0, 0, tipx, tipy, rx, ry)      -- shadow half of the fold
  end
  lg.pop()
  self:cutout(function() lg.circle("fill", cx, cy, 72) end, sunC)
  lg.setColor(shade(sunC, 0.15))
  lg.circle("fill", cx - 20, cy - 22, 18)
end

function S:drawCloud(c)
  local function shape()
    for k = -2, 2 do
      lg.circle("fill", c.x + k * 34 * c.s, c.y + math.abs(k) * 8 * c.s, (40 - math.abs(k) * 6) * c.s)
    end
    lg.rectangle("fill", c.x - 80 * c.s, c.y, 160 * c.s, 30 * c.s, 14 * c.s)
  end
  -- hanging string, like a real diorama
  lg.setColor(0.4, 0.35, 0.45, 0.6)
  lg.setLineWidth(1)
  lg.line(c.x, 0, c.x, c.y - 40 * c.s)
  self:cutout(shape, { 0.98, 0.97, 1 })
end

function S:drawBirds()
  for k = 0, 2 do
    local x = (self.t * 40 + k * 160) % 1500 - 120
    local y = 260 + k * 30 + math.sin(self.t * 2 + k) * 10
    local f = math.sin(self.t * 5 + k) * 10
    lg.setColor(0.1, 0.05, 0.15, 0.12)
    lg.polygon("fill", x + 4, y + 6, x - 26, y - 10 - f + 6, x - 4, y + 6)
    lg.setColor(gfx.hex("#f2f0f7"))
    lg.polygon("fill", x, y, x - 26, y - 10 - f, x - 4, y + 2)   -- folded wing (light)
    lg.setColor(gfx.hex("#c9c4d6"))
    lg.polygon("fill", x, y, x + 24, y - 6 - f, x + 4, y + 2)    -- other wing (in shade)
    lg.setColor(gfx.hex("#e2deeb"))
    lg.polygon("fill", x - 14, y + 2, x + 18, y + 2, x + 26, y - 4)
  end
end

function S:drawLayer(L)
  local dx, dy = -self.par.x * 26 * L.depth, -self.par.y * 12 * L.depth
  lg.push()
  lg.translate(dx, dy)
  local pts = L.pts
  local function shape()
    gfx.fillRidge(pts, 760)
    for _, tr in ipairs(L.trees) do
      if tr.round then
        lg.circle("fill", tr.x, tr.y - tr.h * 0.7, tr.h * 0.32)
        lg.rectangle("fill", tr.x - 3, tr.y - tr.h * 0.5, 6, tr.h * 0.5)
      else
        lg.polygon("fill", tr.x - tr.h * 0.28, tr.y, tr.x, tr.y - tr.h, tr.x + tr.h * 0.28, tr.y)
      end
    end
  end
  self:cutout(shape, L.color, function() lg.line(pts) end)
  -- fold lines on pointy trees: a darker half
  for _, tr in ipairs(L.trees) do
    if not tr.round then
      lg.setColor(shade(L.color, -0.07))
      lg.polygon("fill", tr.x, tr.y - tr.h, tr.x + tr.h * 0.28, tr.y, tr.x, tr.y)
    end
  end
  lg.pop()
end

function S:drawAnimals()
  -- a paper fox on the front hill
  local L = self.layers[5]
  local dx = -self.par.x * 26 * L.depth
  local x, y = 360 + dx, 610
  local fox = { gfx.hex("#e8823a") }
  self:cutout(function()
    lg.ellipse("fill", x, y, 40, 18)
    lg.polygon("fill", x + 30, y - 10, x + 64, y - 24, x + 56, y + 2)
    lg.polygon("fill", x + 44, y - 18, x + 50, y - 40, x + 58, y - 22)
    lg.polygon("fill", x - 36, y - 4, x - 90, y - 26 + math.sin(self.t * 3) * 6, x - 70, y + 6)
    lg.rectangle("fill", x - 26, y + 6, 8, 22)
    lg.rectangle("fill", x + 18, y + 6, 8, 22)
  end, fox)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", x - 90, y - 26 + math.sin(self.t * 3) * 6, x - 80, y - 14, x - 72, y - 22)
  lg.setColor(0.15, 0.1, 0.1)
  lg.circle("fill", x + 50, y - 14, 2.5)
end

function S:draw()
  lg.setColor(1, 1, 1)
  self.sky = self.sky or gfx.vgradient(1280, 720, { { 0, gfx.rgb("#f6d7e0") }, { 0.6, gfx.rgb("#e9e1f5") }, { 1, gfx.rgb("#d6ecef") } })
  lg.draw(self.sky)
  self:drawSun()
  for _, c in ipairs(self.clouds) do self:drawCloud(c) end
  for i, L in ipairs(self.layers) do
    self:drawLayer(L)
    if i == 3 then self:drawBirds() end
    if i == 5 then self:drawAnimals() end
  end
  -- paper fibre over everything
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.fibre, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")
end

return S
