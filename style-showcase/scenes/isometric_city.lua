-- ISOMETRIC, scene 2: a city block at night.
--
-- Same projection as Tiny Isle, but the columns are tall buildings and the light comes
-- from them. Windows are little parallelograms placed with the face's own (u, v)
-- coordinates: u runs along the bottom edge, v goes up. A hash of (building, row,
-- column) decides which windows are lit and which flicker. Cars are tiny iso boxes
-- that follow the road rows/columns, with additive headlight glows. Everything is
-- depth-sorted with `deep`, then bloomed.

local gfx = require("core.gfx")
local deep = require("deep")
local Object = require("classic")
local moonshine = require("moonshine")

local lg = love.graphics
local N = 15
local TW, TH = 56, 28
local OX, OY = 640, 150

local S = {
  title = "Isometric",
  subtitle = "Neon City Block",
  blurb = "A night-time isometric city: towers with lit windows, rooftop neon, blinking antennas and cars with headlights on the grid.",
  techniques = {
    "Building = iso box; windows placed with each face's (u, v) coordinates",
    "Window lights from a hash; a few flicker over time",
    "Roads every 5 tiles; cars move along them as tiny iso boxes",
    "Headlights and neon are additive glows, then bloom",
    "Depth sorting by queuing draw calls with z = i + j",
  },
  libs = {
    "deep: back-to-front draw queue",
    "classic: the Car class",
    "moonshine: glow (bloom) and vignette",
  },
  genres = { "City builders and tycoon games", "Cyberpunk tactics and stealth", "Delivery / traffic puzzle games", "Management sims with a night mode" },
  warmup = 4,
}

local function project(i, j, h)
  return OX + (i - j) * TW / 2, OY + (i + j) * TH / 2 - (h or 0)
end

local function isRoad(i, j) return i % 5 == 2 or j % 5 == 2 end

-- Car ---------------------------------------------------------------------------
local Car = Object:extend()
function Car:new(axis, lane, pos, speed, color)
  self.axis, self.lane, self.pos, self.speed, self.color = axis, lane, pos, speed, color
end
function Car:update(dt)
  self.pos = self.pos + self.speed * dt
  if self.pos > N + 1 then self.pos = -1 elseif self.pos < -1 then self.pos = N + 1 end
end
function Car:cell()
  local off = self.speed > 0 and 0.3 or 0.7 -- drive on one side of the road
  if self.axis == "i" then return self.pos, self.lane + off end
  return self.lane + off, self.pos
end
function Car:draw(glow)
  local i, j = self:cell()
  local x, y = project(i, j, 0)
  local dx, dy = 0, 0
  if self.axis == "i" then dx, dy = TW / 2, TH / 2 else dx, dy = -TW / 2, TH / 2 end
  local dir = self.speed > 0 and 1 or -1
  local fx, fy = x + dx * 0.25 * dir, y + dy * 0.25 * dir
  local bx, by = x - dx * 0.25 * dir, y - dy * 0.25 * dir
  lg.setColor(self.color)
  lg.setLineWidth(9)
  lg.line(bx, by - 4, fx, fy - 4)
  lg.setColor(0.1, 0.1, 0.15)
  lg.setLineWidth(5)
  lg.line(bx * 0.7 + fx * 0.3, by * 0.7 + fy * 0.3 - 8, bx * 0.3 + fx * 0.7, by * 0.3 + fy * 0.7 - 8)
  lg.setBlendMode("add")
  lg.setColor(1, 0.95, 0.8, 0.55)
  lg.draw(glow, fx + dx * 0.25 * dir, fy + dy * 0.25 * dir - 2, 0, 0.35, 0.22, 64, 64)
  lg.setColor(1, 0.15, 0.1, 0.6)
  lg.draw(glow, bx, by - 4, 0, 0.12, 0.08, 64, 64)
  lg.setBlendMode("alpha")
end

-- Scene -------------------------------------------------------------------------
function S:load()
  self.t = 0
  love.math.setRandomSeed(2077)
  self.layer = deep:new()
  self.glow = gfx.radialTexture(128, 2)
  self.sky = gfx.vgradient(1280, 720, { { 0, gfx.rgb("#05030f") }, { 0.6, gfx.rgb("#160a2e") }, { 1, gfx.rgb("#2a0f3a") } })
  self.stars = {}
  for i = 1, 90 do self.stars[i] = { love.math.random(0, 1280), love.math.random(0, 300), love.math.random() * 6 } end

  self.buildings = {}
  local neon = { { 1, 0.2, 0.7 }, { 0.2, 0.9, 1 }, { 1, 0.75, 0.2 }, { 0.6, 0.3, 1 } }
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      if not isRoad(i, j) and love.math.random() < 0.72 then
        local centre = 1 - (math.abs(i - N / 2) + math.abs(j - N / 2)) / N
        local h = 24 + love.math.random() * 46 + centre * centre * 190
        self.buildings[#self.buildings + 1] = {
          i = i, j = j, h = h, id = i * 31 + j * 7,
          tint = 0.75 + love.math.random() * 0.3,
          neon = (love.math.random() < 0.22) and neon[love.math.random(1, #neon)] or nil,
          antenna = h > 170,
        }
      end
    end
  end
  self.cars = {}
  local colors = { { 0.9, 0.2, 0.3 }, { 0.2, 0.6, 1 }, { 0.95, 0.9, 0.85 }, { 1, 0.75, 0.2 } }
  for k = 1, 14 do
    local axis = k % 2 == 0 and "i" or "j"
    local lane = ({ 2, 7, 12 })[love.math.random(1, 3)]
    local speed = (love.math.random() < 0.5 and -1 or 1) * (1.2 + love.math.random() * 1.4)
    self.cars[k] = Car(axis, lane, love.math.random() * N, speed, colors[love.math.random(1, #colors)])
  end

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.55
  self.fx.glow.strength = 5
  self.fx.vignette.opacity = 0.6
end

function S:update(dt)
  self.t = self.t + dt
  for _, c in ipairs(self.cars) do c:update(dt) end
end

function S:drawGround(i, j)
  local x, y = project(i, j)
  local road = isRoad(i, j)
  lg.setColor(road and { 0.09, 0.09, 0.13 } or { 0.12, 0.1, 0.18 })
  lg.polygon("fill", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  if road then
    lg.setColor(0.9, 0.85, 0.5, 0.35)
    if i % 5 == 2 and j % 5 ~= 2 then
      lg.line(x - 4, y + TH / 2 - 2, x + 4, y + TH / 2 + 2)
    elseif j % 5 == 2 and i % 5 ~= 2 then
      lg.line(x - 4, y + TH / 2 + 2, x + 4, y + TH / 2 - 2)
    end
  end
  -- street lamp glow at crossings
  if i % 5 == 2 and j % 5 == 2 then
    lg.setBlendMode("add")
    lg.setColor(1, 0.7, 0.4, 0.18)
    lg.draw(self.glow, x, y + TH / 2, 0, 0.8, 0.4, 64, 64)
    lg.setBlendMode("alpha")
  end
end

function S:windows(b, x, y, side)
  -- side = -1 left face, +1 right face. Point on the face for (u along, v up):
  local function P(u, v)
    if side < 0 then return x - TW / 2 + TW / 2 * u, y + TH / 2 + TH / 2 * u - v end
    return x + TW / 2 * u, y + TH - TH / 2 * u - v
  end
  local rows = math.floor((b.h - 12) / 14)
  for r = 0, rows - 1 do
    for c = 0, 2 do
      local h = gfx.hash(b.id * 13 + r * 7 + c * 3 + (side > 0 and 100 or 0))
      local lit = h > 0.45
      if h > 0.93 then lit = math.sin(self.t * 2 + h * 40) > 0 end -- a few flicker
      if lit then
        local warm = gfx.hash(b.id + r) > 0.35
        lg.setColor(warm and 1 or 0.55, warm and 0.8 or 0.85, warm and 0.45 or 1, side < 0 and 0.95 or 0.75)
        local u0, v0 = 0.12 + c * 0.28, 8 + r * 14
        local ax, ay = P(u0, v0)
        local bx, by = P(u0 + 0.16, v0)
        local cx, cy = P(u0 + 0.16, v0 + 7)
        local dx, dy = P(u0, v0 + 7)
        lg.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
      end
    end
  end
end

function S:drawBuilding(b)
  local x, y = project(b.i, b.j)
  local h, k = b.h, b.tint
  lg.setColor(0.16 * k, 0.15 * k, 0.28 * k)
  lg.polygon("fill", x - TW / 2, y + TH / 2 - h, x, y + TH - h, x, y + TH, x - TW / 2, y + TH / 2)
  lg.setColor(0.1 * k, 0.09 * k, 0.2 * k)
  lg.polygon("fill", x, y + TH - h, x + TW / 2, y + TH / 2 - h, x + TW / 2, y + TH / 2, x, y + TH)
  lg.setColor(0.22 * k, 0.2 * k, 0.36 * k)
  lg.polygon("fill", x, y - h, x + TW / 2, y + TH / 2 - h, x, y + TH - h, x - TW / 2, y + TH / 2 - h)
  self:windows(b, x, y, -1)
  self:windows(b, x, y, 1)
  if b.neon then
    local c = b.neon
    local on = math.sin(self.t * 3 + b.id) > -0.7
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.2)
    lg.setLineWidth(3)
    lg.line(x - TW / 2 + 6, y + TH / 2 - h - 4, x - 4, y + TH - h - 6)
    lg.line(x - TW / 2 + 6, y + TH / 2 - h - 12, x - 4, y + TH - h - 14)
    if on then
      lg.setBlendMode("add")
      lg.setColor(c[1], c[2], c[3], 0.45)
      lg.draw(self.glow, x - TW / 4, y + TH * 0.75 - h - 10, 0, 0.5, 0.35, 64, 64)
      lg.setBlendMode("alpha")
    end
  end
  if b.antenna then
    lg.setColor(0.3, 0.3, 0.4)
    lg.setLineWidth(2)
    lg.line(x, y + TH / 2 - h, x, y + TH / 2 - h - 40)
    if math.sin(self.t * 4 + b.id) > 0.6 then
      lg.setColor(1, 0.2, 0.2)
      lg.circle("fill", x, y + TH / 2 - h - 40, 3)
      lg.setBlendMode("add")
      lg.setColor(1, 0.2, 0.2, 0.5)
      lg.draw(self.glow, x, y + TH / 2 - h - 40, 0, 0.25, 0.25, 64, 64)
      lg.setBlendMode("alpha")
    end
  end
end

function S:draw()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.sky)
    for _, s in ipairs(self.stars) do
      lg.setColor(1, 1, 1, 0.3 + 0.3 * math.sin(self.t + s[3]))
      lg.circle("fill", s[1], s[2], 1)
    end
    -- the city sits on a slab
    local l1x, l1y = project(0, N)
    local l2x, l2y = project(N, N)
    local l3x, l3y = project(N, 0)
    lg.setColor(0.06, 0.05, 0.1)
    lg.polygon("fill", l1x, l1y, l2x, l2y, l2x, l2y + 40, l1x, l1y + 40)
    lg.setColor(0.04, 0.03, 0.08)
    lg.polygon("fill", l2x, l2y, l3x, l3y, l3x, l3y + 40, l2x, l2y + 40)

    for j = 0, N - 1 do
      for i = 0, N - 1 do
        self.layer:queue((i + j) * 10, function() self:drawGround(i, j) end)
      end
    end
    for _, b in ipairs(self.buildings) do
      self.layer:queue((b.i + b.j) * 10 + 5, function() self:drawBuilding(b) end)
    end
    for _, c in ipairs(self.cars) do
      local i, j = c:cell()
      self.layer:queue(math.floor((i + j) * 10) + 6, function() c:draw(self.glow) end)
    end
    self.layer:draw()
  end)
end

return S
