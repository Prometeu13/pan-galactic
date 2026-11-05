-- ISOMETRIC: a tiny island town in 2:1 isometric projection.
--
-- Isometric is plain 2D drawing with one formula:
--     screenX = originX + (i - j) * tileW/2
--     screenY = originY + (i + j) * tileH/2 - height
-- Each tile is a column: a diamond on top and two darker side faces. Things must be
-- drawn back-to-front (smaller i+j first). Instead of sorting a list every frame we
-- queue draw calls into a `deep` layer with z = (i + j), and it plays them in order.
-- Villagers and the boat are `classic` classes; they move between tiles with tween.lua.

local gfx = require("core.gfx")
local view = require("core.view")
local deep = require("deep")
local Object = require("classic")
local tween = require("tween")

local lg = love.graphics
local N = 15
local TW, TH, LH = 64, 32, 14   -- tile width/height, pixels per height level
local OX, OY = 640, 150

local S = {
  title = "Isometric",
  subtitle = "Tiny Isle",
  blurb = "A cosy 2:1 isometric island: height-mapped tile columns, depth-sorted objects, walking villagers and a sailing boat.",
  techniques = {
    "Iso projection by hand: (i, j, height) -> screen x, y",
    "Island heights = noise x radial falloff, quantised into levels",
    "Each tile is a column: top diamond + two shaded side faces",
    "Depth sorting by queuing draw calls with z = i + j",
    "Mouse -> tile with the inverse projection (hover highlight)",
  },
  libs = {
    "deep: z-ordered draw queue (back-to-front without sorting)",
    "classic: Villager and Boat classes",
    "tween.lua: tile-to-tile movement with easing",
  },
  genres = { "City builders and colony sims", "Tactics RPGs", "Cosy farming / life sims", "Puzzle and diorama games" },
  controls = "hover the island to highlight tiles.",
  warmup = 4,
}

local COLORS = {
  sand = { gfx.hex("#f0d58c") }, grass = { gfx.hex("#7cc95a") }, forest = { gfx.hex("#4f9d48") },
  rock = { gfx.hex("#9a9aa6") }, snow = { gfx.hex("#f4f6fb") },
}

local function project(i, j, h)
  return OX + (i - j) * TW / 2, OY + (i + j) * TH / 2 - h
end

local function shade(c, k) return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end

-- Villager --------------------------------------------------------------------
local Villager = Object:extend()

function Villager:new(scene, i, j, shirt)
  self.scene, self.i, self.j, self.shirt = scene, i, j, shirt
  self.pos = { i = i, j = j }
  self.wait = love.math.random() * 1.5
  self.walking = nil
end

function Villager:update(dt)
  if self.walking then
    if self.walking:update(dt) then
      self.walking = nil
      self.i, self.j = self.pos.i, self.pos.j
      self.wait = 0.3 + love.math.random() * 1.2
    end
    return
  end
  self.wait = self.wait - dt
  if self.wait > 0 then return end
  local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
  local d = dirs[love.math.random(1, 4)]
  local ni, nj = self.i + d[1], self.j + d[2]
  local here, there = self.scene:tile(self.i, self.j), self.scene:tile(ni, nj)
  if there and there.kind ~= "water" and there.kind ~= "rock" and not there.house and math.abs(there.level - here.level) <= 1 then
    self.walking = tween.new(0.7, self.pos, { i = ni, j = nj }, "inOutQuad")
  else
    self.wait = 0.2
  end
end

function Villager:height()
  local s = self.scene
  local a, b = s:tile(self.i, self.j), s:tile(math.floor(self.pos.i + 0.5), math.floor(self.pos.j + 0.5))
  return ((a.level + b.level) / 2) * LH
end

function Villager:draw()
  local x, y = project(self.pos.i + 0.5, self.pos.j + 0.5, self:height())
  local bob = self.walking and math.abs(math.sin(love.timer.getTime() * 12)) * 3 or 0
  lg.setColor(0, 0, 0, 0.2)
  lg.ellipse("fill", x, y, 8, 4)
  lg.setColor(self.shirt)
  lg.rectangle("fill", x - 5, y - 18 - bob, 10, 14, 4)
  lg.setColor(gfx.hex("#f0c8a0"))
  lg.circle("fill", x, y - 23 - bob, 5.5)
  lg.setColor(gfx.hex("#5a3a22"))
  lg.arc("fill", x, y - 24 - bob, 5.8, math.pi, math.pi * 2)
end

-- Boat ------------------------------------------------------------------------
local Boat = Object:extend()

function Boat:new() self.a = 0 end
function Boat:update(dt) self.a = self.a + dt * 0.12 end
function Boat:cell()
  local i = N / 2 + math.cos(self.a) * 8.3
  local j = N / 2 + math.sin(self.a) * 8.3
  return i, j
end
function Boat:draw(t)
  local i, j = self:cell()
  local x, y = project(i, j, math.sin(t * 2) * 2)
  lg.setColor(1, 1, 1, 0.5)
  lg.ellipse("line", x, y + 4, 26 + math.sin(t * 3) * 2, 8)
  lg.setColor(gfx.hex("#8a5a3a"))
  lg.polygon("fill", x - 22, y - 4, x + 22, y - 4, x + 14, y + 6, x - 14, y + 6)
  lg.setColor(gfx.hex("#5a3a22"))
  lg.rectangle("fill", x - 1.5, y - 44, 3, 40)
  lg.setColor(gfx.hex("#fff8ea"))
  lg.polygon("fill", x + 2, y - 42, x + 24, y - 10, x + 2, y - 10)
  lg.setColor(gfx.hex("#e25a5a"))
  lg.polygon("fill", x + 2, y - 44, x + 12, y - 40, x + 2, y - 36)
end

-- Scene -----------------------------------------------------------------------
function S:tile(i, j)
  if i < 0 or j < 0 or i >= N or j >= N then return nil end
  return self.map[j * N + i + 1]
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(31)
  self.layer = deep:new()
  self.map = {}
  local c = (N - 1) / 2
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      local d = math.sqrt((i - c) ^ 2 + (j - c) ^ 2) / (N / 2)
      local h = gfx.fbm(i * 0.18 + 3, j * 0.18 + 7, 4) * 1.2 - d * d * 0.95
      local level, kind
      if h < 0.0 then level, kind = 0, "water"
      elseif h < 0.14 then level, kind = 1, "sand"
      elseif h < 0.4 then level, kind = 2, "grass"
      elseif h < 0.58 then level, kind = 3, "forest"
      elseif h < 0.68 then level, kind = 4, "rock"
      else level, kind = 5, "snow" end
      self.map[j * N + i + 1] = { i = i, j = j, level = level, kind = kind, tree = (kind == "forest" and love.math.random() < 0.7) or (kind == "grass" and love.math.random() < 0.08) }
    end
  end
  -- Place a few houses on grass.
  local placed = 0
  for _, tile in ipairs(self.map) do
    if placed < 4 and tile.kind == "grass" and not tile.tree and (tile.i + tile.j) % 3 == 0 then
      tile.house = { roof = ({ "#d9574a", "#5a7fd9", "#d9a44a", "#8a5ad9" })[placed + 1] }
      placed = placed + 1
    end
  end
  self.villagers = {}
  local shirts = { "#e26d5a", "#5ab0e2", "#e2c45a", "#9b6be2", "#5ae29b", "#ffffff" }
  for k = 1, 6 do
    for _ = 1, 200 do
      local tile = self.map[love.math.random(1, #self.map)]
      if tile.kind == "grass" or tile.kind == "sand" then
        if not tile.house then
          self.villagers[#self.villagers + 1] = Villager(self, tile.i, tile.j, { gfx.hex(shirts[k]) })
          break
        end
      end
    end
  end
  self.boat = Boat()
  self.sea = gfx.vgradient(1280, 720, { { 0, gfx.rgb("#7ad0f0") }, { 1, gfx.rgb("#2b7fbf") } })
  self.clouds = {}
  for k = 1, 4 do self.clouds[k] = { x = love.math.random(0, 1280), y = love.math.random(50, 120), s = 0.7 + love.math.random() * 0.6 } end
end

function S:update(dt)
  self.t = self.t + dt
  for _, v in ipairs(self.villagers) do v:update(dt) end
  self.boat:update(dt)
  for _, c in ipairs(self.clouds) do
    c.x = c.x + 12 * dt
    if c.x > 1450 then c.x = -200 end
  end
  -- Inverse projection: which tile is under the mouse?
  local mx, my = view.mouse()
  local a = (mx - OX) / (TW / 2)
  local b = (my - OY) / (TH / 2)
  self.hover = { math.floor((a + b) / 2), math.floor((b - a) / 2) }
end

function S:drawTile(tile)
  local i, j = tile.i, tile.j
  local h = tile.level * LH
  if tile.kind == "water" then
    local wave = math.sin(self.t * 2 + i * 0.7 + j * 0.5) * 2
    local x, y = project(i, j, wave)
    local k = 0.92 + 0.08 * math.sin(self.t * 1.5 + i + j)
    lg.setColor(0.35 * k, 0.72 * k, 0.9 * k, 0.9)
    lg.polygon("fill", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
    if (i * 7 + j * 3 + math.floor(self.t * 2)) % 11 == 0 then
      lg.setColor(1, 1, 1, 0.7)
      lg.line(x - 8, y + TH / 2, x + 8, y + TH / 2)
    end
    return
  end
  local col = COLORS[tile.kind]
  local x, y = project(i, j, h)
  local base = 10 + h -- columns go down to below sea level
  local side = (tile.kind == "sand" or tile.kind == "rock" or tile.kind == "snow") and COLORS[tile.kind == "snow" and "rock" or tile.kind] or { gfx.hex("#a07a50") }
  lg.setColor(shade(side, 0.75))
  lg.polygon("fill", x - TW / 2, y + TH / 2, x, y + TH, x, y + TH + base, x - TW / 2, y + TH / 2 + base)
  lg.setColor(shade(side, 0.58))
  lg.polygon("fill", x, y + TH, x + TW / 2, y + TH / 2, x + TW / 2, y + TH / 2 + base, x, y + TH + base)
  lg.setColor(col)
  lg.polygon("fill", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  lg.setColor(shade(col, 0.9))
  lg.setLineWidth(1)
  lg.polygon("line", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  if self.hover and self.hover[1] == i and self.hover[2] == j then
    lg.setColor(1, 1, 1, 0.9)
    lg.setLineWidth(3)
    lg.polygon("line", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  end
end

function S:drawTree(tile)
  local x, y = project(tile.i + 0.5, tile.j + 0.5, tile.level * LH)
  local sway = math.sin(self.t * 1.5 + tile.i) * 1.5
  lg.setColor(gfx.hex("#6b4a2a"))
  lg.rectangle("fill", x - 3, y - 18, 6, 18)
  for k = 0, 2 do
    local w = 18 - k * 4
    local ty = y - 16 - k * 13
    lg.setColor(shade({ gfx.hex("#2f7a3a") }, 0.85 + k * 0.1))
    lg.polygon("fill", x - w + sway * k * 0.3, ty, x + sway * (k + 1) * 0.4, ty - 24, x + w + sway * k * 0.3, ty)
  end
end

function S:drawHouse(tile)
  local x, y = project(tile.i + 0.5, tile.j + 0.5, tile.level * LH)
  local w, d, hgt = 22, 11, 22
  lg.setColor(gfx.hex("#efe2c8"))
  lg.polygon("fill", x - w, y - d + 2, x, y + 2, x, y - hgt + 2, x - w, y - d - hgt + 2)
  lg.setColor(gfx.hex("#d1c1a2"))
  lg.polygon("fill", x, y + 2, x + w, y - d + 2, x + w, y - d - hgt + 2, x, y - hgt + 2)
  local roof = { gfx.hex(tile.house.roof) }
  lg.setColor(roof)
  lg.polygon("fill", x - w - 3, y - d - hgt + 3, x, y - hgt + 4, x + 2, y - hgt - 18, x - w + 1, y - d - hgt - 20)
  lg.setColor(shade(roof, 0.75))
  lg.polygon("fill", x, y - hgt + 4, x + w + 3, y - d - hgt + 3, x + w - 1, y - d - hgt - 20, x + 2, y - hgt - 18)
  lg.setColor(gfx.hex("#7a5232"))
  lg.polygon("fill", x - 12, y - 4, x - 6, y - 1, x - 6, y - 13, x - 12, y - 16)
  local lit = math.sin(self.t + tile.i) > 0
  lg.setColor(lit and { gfx.hex("#ffe08a") } or { gfx.hex("#5a7a9a") })
  lg.polygon("fill", x + 6, y - 6, x + 12, y - 9, x + 12, y - 15, x + 6, y - 12)
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.sea)
  -- sparkles on the open sea
  for k = 0, 40 do
    local x = (k * 197 + self.t * 8) % 1280
    local y = (k * 113) % 720
    lg.setColor(1, 1, 1, 0.25 + 0.25 * math.sin(self.t * 2 + k))
    lg.line(x - 5, y, x + 5, y)
  end

  -- Queue everything with its depth, then draw in order.
  for _, tile in ipairs(self.map) do
    local z = (tile.i + tile.j) * 10
    self.layer:queue(z, function() self:drawTile(tile) end)
    if tile.tree then self.layer:queue(z + 5, function() self:drawTree(tile) end) end
    if tile.house then self.layer:queue(z + 5, function() self:drawHouse(tile) end) end
  end
  for _, v in ipairs(self.villagers) do
    local z = math.floor((v.pos.i + v.pos.j) * 10 + 0.5) + 6
    self.layer:queue(z, function() v:draw() end)
  end
  local bi, bj = self.boat:cell()
  self.layer:queue(math.floor((bi + bj) * 10) + 6, function() self.boat:draw(self.t) end)
  self.layer:draw()

  for _, c in ipairs(self.clouds) do
    lg.setColor(1, 1, 1, 0.75)
    for k = -2, 2 do
      lg.ellipse("fill", c.x + k * 30 * c.s, c.y + math.abs(k) * 6 * c.s, 40 * c.s, 22 * c.s)
    end
  end
end

return S
