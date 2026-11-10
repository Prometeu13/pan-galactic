-- INK WASH, scene 2: a plum branch that paints itself.
--
-- The whole picture is a list of strokes with a start time. A stroke can be drawn
-- "partially" (only the first part of its curve), so advancing a clock makes the
-- branch grow out of the corner the way a brush would paint it: trunk first, then
-- limbs, then twigs. When a twig is done, its blossoms bloom (scale in), in the only
-- colour on the page. Then a small bird lands. Click to watch it being painted again.

local gfx = require("core.gfx")
local ink = require("core.inkkit")

local lg = love.graphics

local S = {
  title = "Ink Wash",
  subtitle = "Plum Blossom, First Snow",
  blurb = "A plum branch that paints itself stroke by stroke, red blossoms that bloom as the twigs finish, a moon left as bare paper and a small bird.",
  techniques = {
    "Timed strokes: each stroke has a start time and draws only part of its curve",
    "Growth order: trunk -> limbs -> twigs, each starting where its parent ends",
    "One accent colour: blossoms are five soft red blots plus dark stamens",
    "The moon is unpainted paper inside a ring of pale wash (a Mesh ring)",
    "Snow = paper-coloured strokes laid on top of the dark branch",
    "The bird: two blots, three strokes and a dot",
  },
  libs = {
    "(none: Bezier curves, Meshes and generated textures; see core/inkkit.lua)",
  },
  genres = { "Calligraphy / drawing games", "Seasonal and poetic narrative games", "Title cards and chapter breaks", "Meditative idle games" },
  controls = "click: wipe the paper and paint it again.",
  warmup = 9,
}

local RED = { 0.8, 0.14, 0.16 }
local PINK = { 0.9, 0.42, 0.46 }

-- Build the branch as a tree of strokes. Each: ctrl points, width, start time, duration.
function S:plan()
  local strokes, blossoms = {}, {}
  local rng = love.math.newRandomGenerator(self.seed)
  local function add(ctrl, width, start, dur, alpha, flick)
    strokes[#strokes + 1] = { ctrl = ctrl, w = width, start = start, dur = dur, a = alpha or 0.88, flick = flick }
    return start + dur
  end
  local function bloom(x, y, at, size, bud)
    blossoms[#blossoms + 1] = { x = x, y = y, at = at, s = size, bud = bud, rot = rng:random() * 6, pale = rng:random() < 0.3 }
  end
  -- a twig with blossoms along it
  local function twig(x, y, ang, len, t0, depth)
    local bend = (rng:random() - 0.5) * 0.9
    local mx, my = x + math.cos(ang + bend * 0.4) * len * 0.5, y + math.sin(ang + bend * 0.4) * len * 0.5
    local ex, ey = x + math.cos(ang + bend) * len, y + math.sin(ang + bend) * len
    local done = add({ x, y, mx, my, ex, ey }, 3 + depth * 2.2, t0, 0.5, 0.85, 0.6)
    local n = 2 + rng:random(0, 2)
    for i = 1, n do
      local u = 0.25 + rng:random() * 0.75
      local bx, by = gfx.lerp(x, ex, u) + (rng:random() - 0.5) * 16, gfx.lerp(y, ey, u) + (rng:random() - 0.5) * 16
      bloom(bx, by, done + rng:random() * 1.2, 0.8 + rng:random() * 0.5, rng:random() < 0.35)
    end
    if depth > 0 then
      twig(gfx.lerp(x, ex, 0.6), gfx.lerp(y, ey, 0.6), ang + bend + (rng:random() < 0.5 and -1 or 1) * (0.5 + rng:random() * 0.4), len * 0.62, done - 0.15, depth - 1)
    end
    return ex, ey, done
  end
  -- the old trunk: angular, entering from the lower right
  local t = 0.2
  local pts = { { 1290, 610 }, { 1150, 560 }, { 1040, 470 }, { 900, 450 }, { 770, 360 }, { 640, 330 }, { 520, 250 }, { 400, 232 } }
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local kink = (i % 2 == 0) and 26 or -22
    local w = 44 - i * 4.6
    t = add({ a[1], a[2], (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 + kink, b[1], b[2] }, w, t, 0.42, 0.9, 0.12) - 0.1
    -- side limbs spring from the joints
    if i >= 2 then
      local up = (i % 2 == 0) and -1 or 1
      local ang = math.atan2(b[2] - a[2], b[1] - a[1]) + up * (0.9 + rng:random() * 0.3)
      twig(b[1], b[2], ang, 150 + rng:random() * 70, t + 0.1, 2)
      if i % 3 == 0 then twig(b[1], b[2], ang - up * 1.9, 110, t + 0.3, 1) end
    end
  end
  local ex, ey = twig(400, 232, math.pi + 0.25, 190, t, 2)
  -- a second, thinner limb dropping down across the lower left
  local t2 = add({ 1040, 470, 960, 540, 860, 560 }, 16, 1.6, 0.5, 0.85, 0.2)
  t2 = add({ 860, 560, 760, 566, 690, 620 }, 11, t2 - 0.1, 0.5, 0.85, 0.3)
  twig(690, 620, math.pi - 0.3, 150, t2, 2)
  twig(860, 560, math.pi / 2 + 0.5, 90, t2, 1)
  self.strokes, self.blossoms = strokes, blossoms
  self.done = 0
  for _, s in ipairs(strokes) do self.done = math.max(self.done, s.start + s.dur) end
  for _, b in ipairs(blossoms) do self.done = math.max(self.done, b.at + 0.6) end
end

function S:load()
  self.t = 0
  self.seed = 5
  self.paper = ink.paper(8)
  self.clock = 0
  self:plan()
  -- the moon's halo: a ring that is darkest just outside the disc
  local v = {}
  local n = 64
  for i = 0, n do
    local a = i / n * math.pi * 2
    v[#v + 1] = { math.cos(a) * 118, math.sin(a) * 118, 0, 0, 0.1, 0.1, 0.14, 0.2 }
    v[#v + 1] = { math.cos(a) * 330, math.sin(a) * 330, 0, 0, 0.1, 0.1, 0.14, 0 }
  end
  self.halo = lg.newMesh(v, "strip", "static")
  love.math.setRandomSeed(2)
  self.petals = {}
  for i = 1, 16 do
    self.petals[i] = { x = love.math.random(100, 1200), y = love.math.random(0, 720), v = 16 + love.math.random() * 22, p = love.math.random() * 6 }
  end
  self.snow = {}
  for i = 1, 70 do
    self.snow[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), v = 20 + love.math.random() * 30, p = love.math.random() * 6, r = 1.5 + love.math.random() * 2.5 }
  end
end

function S:mousepressed()
  self.clock = 0
  self.seed = love.math.random(1, 9999)
  self:plan()
end

function S:update(dt)
  self.t = self.t + dt
  self.clock = self.clock + dt
  for _, p in ipairs(self.petals) do
    p.y = p.y + p.v * dt
    p.x = p.x - (14 + math.sin(self.t + p.p) * 20) * dt
    if p.y > 730 then p.y = -10 p.x = love.math.random(200, 1300) end
  end
  for _, s in ipairs(self.snow) do
    s.y = s.y + s.v * dt
    s.x = s.x + math.sin(self.t * 0.8 + s.p) * 12 * dt
    if s.y > 730 then s.y = -10 end
  end
end

local function blossom(b, k)
  local s = b.s * (k < 1 and (1 - (1 - k) ^ 3) or 1)
  if b.bud then
    ink.dot(b.x, b.y, 11 * s, 0.9, RED)
    ink.dot(b.x - 3, b.y + 4, 6 * s, 0.7)
    return
  end
  local col = b.pale and PINK or RED
  for p = 0, 4 do
    local a = b.rot + p / 5 * math.pi * 2
    local px, py = b.x + math.cos(a) * 11 * s, b.y + math.sin(a) * 11 * s
    ink.dot(px, py, 15 * s, 0.75, col)
    ink.dot(px + math.cos(a) * 3, py + math.sin(a) * 3, 9 * s, 0.35, { 0.55, 0.05, 0.08 })
  end
  ink.dot(b.x, b.y, 7 * s, 0.6, { 0.98, 0.85, 0.5 })
  lg.setColor(0.1, 0.08, 0.08, 0.85 * k)
  lg.setLineWidth(1)
  for p = 0, 6 do
    local a = b.rot + p / 7 * math.pi * 2
    local ex, ey = b.x + math.cos(a) * 9 * s, b.y + math.sin(a) * 9 * s
    lg.line(b.x, b.y, ex, ey)
    lg.circle("fill", ex, ey, 1.3)
  end
end

function S:drawBird(x, y, k)
  local t = self.t
  local INK = ink.INK
  lg.push()
  lg.translate(x, y - (1 - k) * 160)
  lg.rotate((1 - k) * -0.5)
  local tilt = (math.sin(t * 0.7) > 0.6) and 0.3 or 0
  -- tail: two long strokes that flick
  local tf = math.sin(t * 3) * ((math.sin(t * 0.9) > 0.8) and 8 or 1)
  ink.brush({ 16, -8, 48, 4 + tf, 82, 22 + tf }, 9, 0.85, 0.5)
  ink.brush({ 16, -4, 44, 12 + tf, 70, 34 + tf }, 6, 0.7, 0.5)
  -- body: a pale wash blot with a darker wing stroke over it
  ink.dot(0, -14, 34, 0.42)
  ink.dot(-6, -8, 24, 0.3, { 0.5, 0.36, 0.26 })
  ink.brush({ -12, -26, 12, -24, 34, -6 }, 16, 0.85, 0.45)
  ink.brush({ -4, -16, 14, -14, 30, -2 }, 7, 0.6, 0.5)
  -- head: a dark cap, a pale cheek, an eye, a beak
  lg.push()
  lg.translate(-24, -34)
  lg.rotate(tilt)
  ink.dot(0, 0, 20, 0.9)
  ink.dot(-3, 5, 10, 0.9, { 0.93, 0.89, 0.8 })
  lg.setColor(INK)
  lg.circle("fill", -5, -2, 2.2)
  lg.setColor(1, 1, 1)
  lg.circle("fill", -5.6, -2.6, 0.8)
  ink.brush({ -12, 0, -20, 2, -27, 5 }, 5, 0.9, 0.7)
  lg.pop()
  -- legs gripping the branch
  lg.setColor(INK[1], INK[2], INK[3], 0.85)
  lg.setLineWidth(1.6)
  lg.line(-4, 6, -6, 22, -12, 26)
  lg.line(6, 6, 6, 22, 0, 27)
  lg.pop()
end

function S:draw()
  local t, clock = self.t, self.clock
  lg.setColor(1, 1, 1)
  lg.draw(self.paper)
  -- moon: bare paper, defined by the wash around it
  lg.setColor(1, 1, 1)
  lg.draw(self.halo, 330, 250)
  -- far hills, barely there
  self.hills = self.hills or ink.fade(gfx.ridge(1280, 640, 120, 0.003, 4.2, 12, 4), 110, 0.16)
  lg.draw(self.hills)
  -- the branch, as far as the clock has painted it
  for _, s in ipairs(self.strokes) do
    local p = (clock - s.start) / s.dur
    if p > 0 then ink.brush(s.ctrl, s.w, s.a, s.flick, math.min(1, p)) end
  end
  -- snow resting on the thick strokes (paper colour on top of ink)
  for i, s in ipairs(self.strokes) do
    if s.w > 14 and clock > s.start + s.dur + 0.4 then
      local c = s.ctrl
      local k = gfx.clamp((clock - s.start - s.dur - 0.4) / 0.8, 0, 1)
      ink.brush({ c[1], c[2] - s.w * 0.42, c[3], c[4] - s.w * 0.5, c[5], c[6] - s.w * 0.42 }, s.w * 0.45, 0.95 * k, 0.3, nil, { 0.96, 0.93, 0.86 })
    end
  end
  for _, b in ipairs(self.blossoms) do
    local k = (clock - b.at) / 0.6
    if k > 0 then blossom(b, math.min(1, k)) end
  end
  -- the bird lands when the painting is done
  local bk = gfx.clamp((clock - self.done - 0.2) / 0.9, 0, 1)
  if bk > 0 then self:drawBird(978, 420, 1 - (1 - bk) ^ 3) end
  -- drifting petals and snow
  for _, p in ipairs(self.petals) do
    ink.dot(p.x, p.y, 7, 0.7, RED)
  end
  for _, s in ipairs(self.snow) do
    lg.setColor(1, 1, 1, 0.85)
    lg.circle("fill", s.x, s.y, s.r)
  end
  -- calligraphy and seal appear last
  local ck = gfx.clamp((clock - self.done) / 2.2, 0, 1)
  if ck > 0 then ink.column(120, 420, 4, ck) end
  if clock > self.done + 2.4 then ink.seal(96, 640, 52, gfx.clamp((clock - self.done - 2.4) / 0.3, 0, 1)) end
end

return S
