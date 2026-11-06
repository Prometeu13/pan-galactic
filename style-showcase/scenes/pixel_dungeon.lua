-- PIXEL ART, scene 2: a torchlit roguelike dungeon at 256x144 (scaled 5x).
--
-- The level is ASCII art in this file. Every tile (bricks, cracked floor, water, chest)
-- is painted pixel by pixel from a hash of its position, so no two floor tiles match.
--
-- Classic roguelike tricks, all with pixels:
--   * field of view: a Bresenham line from the hero to each tile; walls block it
--   * lighting: each pixel adds up light from torches and the hero's lantern, then the
--     result is quantised into 4 levels and drawn as ordered-dither black dots, so the
--     palette never gains new colours
--   * the hero walks to random targets with a breadth-first-search path

local gfx = require("core.gfx")
local pixelfont = require("core.pixelfont")
local Bresenham = require("Bresenham")

local lg = love.graphics
local PW, PH, T = 256, 144, 16

local S = {
  title = "Pixel Art",
  subtitle = "Torchlit Dungeon",
  blurb = "A roguelike dungeon at 256x144: ASCII level, field of view, BFS pathfinding and dithered torch light that keeps the palette strict.",
  techniques = {
    "Level written as ASCII; each character becomes a tile painted from a position hash",
    "Field of view: Bresenham lines from the hero; walls block sight",
    "Light per pixel from flickering torches + lantern, quantised to 4 dithered levels",
    "Explored-but-unseen tiles stay dimly remembered (fog of war)",
    "Hero AI: breadth-first search to a random reachable tile",
  },
  libs = {
    "Bresenham: line-of-sight rays for the field of view",
    "(lighting, BFS and tile painting are plain Lua over ImageData)",
  },
  genres = { "Roguelikes and dungeon crawlers", "Top-down action RPGs", "Turn-based tactics with fog of war", "Stealth games (light = visibility)" },
  warmup = 6,
}

local MAP = {
  "####t######t####",
  "#.....#........#",
  "#.~~..#..s.....#",
  "t.~~..+........t",
  "#.....#....##..#",
  "#.c...#....##.>#",
  "##.####........#",
  "#......b.....c.#",
  "################",
}

local PAL = {
  k = "#09070f", d = "#1c1726", s = "#3b3347", S = "#5e5470", l = "#8f84a3",
  b = "#4a3427", B = "#7a5638", y = "#ffd166", o = "#f08a4b", r = "#c4473a",
  w = "#2b4a7a", W = "#4f86c6", g = "#3fa66b", G = "#8be08f", m = "#f2e8c9", p = "#b86bd6",
}
local C = {}
for k, v in pairs(PAL) do C[k] = gfx.rgb(v) end

local HERO = {
  { "..kkkk..", ".kllllk.", ".klmmlk.", ".kmkmkm.", "..kmmk..", ".kkWWkk.", "kSkWWkSk", ".kWWWWk.", ".kbbbbk.", ".kb..bk.", ".kk..kk." },
  { "..kkkk..", ".kllllk.", ".klmmlk.", ".kmkmkm.", "..kmmk..", ".kkWWkk.", "kSkWWkSk", ".kWWWWk.", ".kbbbbk.", "..kbbk..", "..kkkk.." },
}
local SLIME = {
  { "........", "..kkkk..", ".kGGGGk.", "kGmGGmGk", "kGkGGkGk", "kGGGGGGk", ".kkkkkk." },
  { "........", "........", ".kkkkkk.", "kGmGGmGk", "kGkGGkGk", "kGGGGGGk", "kkkkkkkk" },
}
local BAT = {
  { "k......k", "kk.kk.kk", "kpkppkpk", ".kpyypk.", "..kppk..", "........" },
  { "........", "...kk...", ".kkppkk.", "kpkyykpk", "k.kppk.k", "........" },
}
local HEART = { ".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..." }

local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local function tileAt(x, y)
  local row = MAP[y + 1]
  if not row or x < 0 or x >= #row then return "#" end
  return row:sub(x + 1, x + 1)
end
local function solid(ch) return ch == "#" or ch == "t" end
local function walkable(ch) return not solid(ch) and ch ~= "~" end

-- Paint one tile into ImageData, pixel by pixel.
local function paintTile(d, tx, ty, ch)
  local ox, oy = tx * T, ty * T
  local function set(x, y, c) d:setPixel(ox + x, oy + y, c[1], c[2], c[3], 1) end
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local h = gfx.hash(tx * 977 + ty * 131 + x * 17 + y * 3)
      if solid(ch) then
        -- bricks: rows of 4px, staggered every other row, mortar lines in dark
        local row = math.floor(y / 4)
        local bx = (x + (row % 2) * 4) % 8
        local c = (y % 4 == 3 or bx == 7) and C.d or (h > 0.85 and C.l or C.S)
        if y == 0 and solid(tileAt(tx, ty - 1)) == false then c = C.l end -- lit top edge
        set(x, y, c)
      elseif ch == "~" then
        local wave = (x + y * 2) % 7 == 0
        set(x, y, wave and C.W or C.w)
      else
        local c = C.s
        if h > 0.93 then c = C.S elseif (x == 0 or y == 0) then c = C.d end
        set(x, y, c)
      end
    end
  end
  if ch == "+" then -- wooden door
    for y = 1, T - 1 do for x = 3, 12 do set(x, y, (x % 3 == 0) and C.b or C.B) end end
    set(10, 8, C.y)
  elseif ch == ">" then -- stairs down
    for i = 0, 5 do for x = 2 + i, 13 do set(x, 3 + i * 2, C.s); set(x, 4 + i * 2, C.k) end end
  elseif ch == "c" then -- chest
    for y = 6, 13 do for x = 3, 12 do set(x, y, (y == 9) and C.y or C.B) end end
    for x = 3, 12 do set(x, 6, C.b) end
    set(7, 10, C.k); set(8, 10, C.k)
  end
end

local function bfs(sx, sy, gx, gy)
  local prev, q, head = {}, { { sx, sy } }, 1
  local key = function(x, y) return y * 100 + x end
  prev[key(sx, sy)] = false
  while head <= #q do
    local c = q[head]; head = head + 1
    if c[1] == gx and c[2] == gy then break end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, ny = c[1] + d[1], c[2] + d[2]
      if prev[key(nx, ny)] == nil and walkable(tileAt(nx, ny)) then
        prev[key(nx, ny)] = c
        q[#q + 1] = { nx, ny }
      end
    end
  end
  if prev[key(gx, gy)] == nil then return nil end
  local path, c = {}, { gx, gy }
  while c do
    table.insert(path, 1, c)
    c = prev[key(c[1], c[2])]
  end
  return path
end

function S:load()
  self.t = 0
  self.canvas = lg.newCanvas(PW, PH)
  self.canvas:setFilter("nearest", "nearest")
  self.font = pixelfont.make()

  local d = love.image.newImageData(PW, PH)
  self.torches, self.floors = {}, {}
  for ty = 0, #MAP - 1 do
    for tx = 0, 15 do
      local ch = tileAt(tx, ty)
      paintTile(d, tx, ty, ch)
      if ch == "t" then self.torches[#self.torches + 1] = { x = tx * T + 8, y = ty * T + 8 } end
      if walkable(ch) then self.floors[#self.floors + 1] = { tx, ty } end
    end
  end
  self.map = lg.newImage(d)
  self.map:setFilter("nearest", "nearest")

  local function frames(list)
    local out = {}
    for i, f in ipairs(list) do out[i] = gfx.spriteFromStrings(f, C) end
    return out
  end
  self.heroImg, self.slimeImg, self.batImg = frames(HERO), frames(SLIME), frames(BAT)
  self.heart = gfx.spriteFromStrings(HEART, C)

  self.hero = { tx = 1, ty = 1, x = 1, y = 1, path = nil, step = 0 }
  -- Pretend most of this floor was explored already, so it's dimly remembered.
  self.seen = {}
  for k = 0, 16 * #MAP - 1 do self.seen[k] = true end
  self.shade = love.image.newImageData(PW, PH)
  self.shadeImg = lg.newImage(self.shade)
  self.shadeImg:setFilter("nearest", "nearest")
  self.lightTimer = 0
end

function S:updateFOV()
  self.visible = {}
  local hx, hy = self.hero.tx, self.hero.ty
  for ty = 0, #MAP - 1 do
    for tx = 0, 15 do
      local clear = true
      Bresenham.line(hx, hy, tx, ty, function(x, y)
        if x == tx and y == ty then return true end
        if solid(tileAt(x, y)) and not (x == hx and y == hy) then clear = false return false end
        return true
      end)
      if clear and (tx - hx) ^ 2 + (ty - hy) ^ 2 <= 49 then
        self.visible[ty * 16 + tx] = true
        self.seen[ty * 16 + tx] = true
      end
    end
  end
end

-- Rebuild the dithered shadow overlay (black dots, 0..4 per 4x4 pattern level).
function S:updateLight()
  local lights = {}
  for _, tc in ipairs(self.torches) do
    local f = 1 + love.math.noise(tc.x, self.t * 6) * 0.25
    lights[#lights + 1] = { tc.x, tc.y + 6, 72 * f }
  end
  lights[#lights + 1] = { self.hero.x * T + 8, self.hero.y * T + 8, 64 }
  local shade, vis, seen = self.shade, self.visible, self.seen
  shade:mapPixel(function(x, y)
    local key = math.floor(y / T) * 16 + math.floor(x / T)
    local light = 0
    if vis[key] then
      for i = 1, #lights do
        local L = lights[i]
        local dx, dy = x - L[1], y - L[2]
        local v = 1 - (dx * dx + dy * dy) / (L[3] * L[3])
        if v > 0 then light = light + v end
      end
      light = math.min(1, light) * 0.9 + 0.1
    elseif seen[key] then
      light = 0.3                          -- remembered: dim
    end
    local level = math.floor(light * 4 + 0.5) / 4 -- 4 light levels
    local threshold = (BAYER[y % 4 + 1][x % 4 + 1] + 0.5) / 16
    if threshold > level then return 0.035, 0.027, 0.06, 1 end
    return 0, 0, 0, 0
  end)
  self.shadeImg:replacePixels(shade)
end

function S:update(dt)
  self.t = self.t + dt
  local h = self.hero
  if not h.path or #h.path == 0 then
    local target = self.floors[love.math.random(1, #self.floors)]
    h.path = bfs(h.tx, h.ty, target[1], target[2])
    if h.path then table.remove(h.path, 1) end
  else
    h.step = h.step + dt * 4.5
    local nxt = h.path[1]
    h.x = h.tx + (nxt[1] - h.tx) * math.min(1, h.step)
    h.y = h.ty + (nxt[2] - h.ty) * math.min(1, h.step)
    if h.step >= 1 then
      h.step = 0
      h.tx, h.ty = nxt[1], nxt[2]
      table.remove(h.path, 1)
      self:updateFOV()
    end
  end
  if not self.visible then self:updateFOV() end
  -- Recompute light 15 times a second: torch flicker reads better a bit "steppy".
  self.lightTimer = self.lightTimer - dt
  if self.lightTimer <= 0 then
    self.lightTimer = 1 / 15
    self:updateLight()
  end
end

local function px(x, y, w, h) lg.rectangle("fill", math.floor(x), math.floor(y), w or 1, h or 1) end

function S:draw()
  local view = require("core.view")
  lg.push("all")
  lg.setCanvas(self.canvas)
  lg.clear(C.k)
  lg.setColor(1, 1, 1)
  lg.draw(self.map)

  -- flames on the wall torches
  for _, tc in ipairs(self.torches) do
    local f = math.floor(self.t * 8 + tc.x) % 2
    lg.setColor(C.o)
    px(tc.x - 1, tc.y + 2 - f, 3, 3)
    lg.setColor(C.y)
    px(tc.x, tc.y + 3 - f, 1, 2)
    lg.setColor(C.B)
    px(tc.x - 1, tc.y + 5, 3, 3)
  end
  -- monsters (only drawn when you can see their tile)
  local function visibleAt(tx, ty) return self.visible and self.visible[ty * 16 + tx] end
  local f = math.floor(self.t * 3) % 2 + 1
  local sx = 9 + math.floor(math.sin(self.t * 0.7) * 2 + 0.5)
  if visibleAt(sx, 2) then
    lg.setColor(1, 1, 1)
    lg.draw(self.slimeImg[f], sx * T + 4, 2 * T + 8)
  end
  local bx, by = 7 * T + math.sin(self.t * 1.3) * 20, 7 * T + 2 + math.sin(self.t * 4) * 3
  if visibleAt(math.floor((bx + 4) / T), 7) then
    lg.setColor(1, 1, 1)
    lg.draw(self.batImg[math.floor(self.t * 8) % 2 + 1], math.floor(bx), math.floor(by))
  end
  -- hero
  local h = self.hero
  local walking = h.path and #h.path > 0
  lg.setColor(1, 1, 1)
  lg.draw(self.heroImg[walking and (math.floor(self.t * 6) % 2 + 1) or 1], math.floor(h.x * T + 4), math.floor(h.y * T + 4))

  -- darkness on top
  lg.draw(self.shadeImg)

  -- HUD in the bottom wall row
  for i = 0, 2 do lg.draw(self.heart, 4 + i * 9, PH - 11) end
  lg.setFont(self.font)
  lg.setColor(C.y)
  lg.print("GOLD 042", 34, PH - 10)
  lg.setColor(C.l)
  lg.print("FLOOR B3", PW - 38, PH - 10)
  lg.pop()

  lg.setCanvas({ view.canvas, stencil = true })
  lg.setColor(1, 1, 1)
  lg.draw(self.canvas, 0, 0, 0, 1280 / PW, 720 / PH)
end

return S
