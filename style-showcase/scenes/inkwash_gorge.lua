-- INK WASH, scene 3: a mountain gorge with a waterfall (shan shui, "mountain-water").
--
-- Classical landscapes stack three distances and separate them with mist. Mist costs
-- nothing: every cliff is a wash that is dark along its top edge and fades to bare
-- paper below (ink.fade), so the paper between the layers reads as fog. The waterfall
-- is also just paper: dark rock on both sides, and a few thin moving lines to say
-- "falling". Texture strokes on the cliffs follow the old rule of thumb: short, dry,
-- all leaning the same way. A tiny traveller gives the mountains their size.

local gfx = require("core.gfx")
local ink = require("core.inkkit")

local lg = love.graphics
local INK = ink.INK

local S = {
  title = "Ink Wash",
  subtitle = "The Gorge at Dawn",
  blurb = "A shan-shui landscape: stacked cliffs fading into mist, a waterfall left as bare paper, clinging pines, a pavilion and a tiny traveller on a bridge.",
  techniques = {
    "Three distances separated by mist: each cliff wash fades to bare paper below",
    "Waterfall = unpainted paper between dark rocks + a few thin falling lines",
    "Cliff texture: hundreds of short dry strokes that all lean the same way",
    "Pines from one function: crooked trunk, side branches, fans of needles",
    "Scale figure: a traveller a few pixels tall makes the cliffs enormous",
    "Mist that moves: paper-coloured soft blobs drifting across the gorge",
  },
  libs = {
    "(none: Bezier curves, Meshes and generated textures; see core/inkkit.lua)",
  },
  genres = { "Wuxia / martial-arts adventures", "Exploration and pilgrimage games", "Strategy maps and loading screens", "Poetic walking sims" },
  warmup = 3,
}

-- cliff silhouettes: lists of ridge points, left to right
local function cliffLine(x1, x2, topY, drop, seed, steps)
  local pts = {}
  for i = 0, steps do
    local u = i / steps
    local x = gfx.lerp(x1, x2, u)
    local n = gfx.fbm(u * 3 + seed, seed, 4)
    -- stepped, blocky profile: quantise a little so cliffs get shoulders
    local h = math.floor(n * 6) / 6 * 0.6 + n * 0.4
    pts[#pts + 1] = x
    pts[#pts + 1] = topY + drop * u + (0.5 - h) * 220
  end
  return pts
end

function S:load()
  self.t = 0
  self.paper = ink.paper(21)
  self.soft = gfx.radialTexture(128, 1.1)
  love.math.setRandomSeed(14)
  local rng = love.math.newRandomGenerator(14)

  -- far peaks: thin, tall spires in pale ink
  self.far = {}
  for i, p in ipairs({ { 300, 250, 150 }, { 470, 170, 120 }, { 640, 230, 170 }, { 820, 150, 130 }, { 980, 240, 160 } }) do
    local cx, top, w = p[1], p[2], p[3]
    local pts = {}
    for k = 0, 20 do
      local u = k / 20
      local shape = 1 - math.abs(u * 2 - 1) ^ 1.6
      pts[#pts + 1] = cx - w + u * w * 2
      pts[#pts + 1] = top + (1 - shape) * 330 + (gfx.fbm(u * 6 + i, i, 3) - 0.5) * 50
    end
    self.far[i] = ink.fade(pts, 230, 0.2)
  end

  -- the two walls of the gorge and their texture, baked once
  self.static = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.static)
  lg.clear(0, 0, 0, 0)
  local walls = {
    -- left wall: three shelves stepping down toward the middle
    { pts = cliffLine(-20, 520, 150, 150, 2.1, 40), depth = 520, a = 0.5 },
    { pts = cliffLine(-20, 430, 380, 110, 5.3, 34), depth = 380, a = 0.62 },
    -- right wall
    { pts = cliffLine(1300, 800, 90, 190, 8.7, 40), depth = 560, a = 0.5 },
    { pts = cliffLine(1300, 860, 330, 140, 3.9, 34), depth = 420, a = 0.64 },
  }
  self.walls = walls
  for wi, wall in ipairs(walls) do
    lg.setColor(1, 1, 1)
    lg.draw(ink.fade(wall.pts, wall.depth, wall.a))
    -- a second, narrower pass makes the top edge heavier
    lg.draw(ink.fade(wall.pts, 70, 0.35))
    -- bold contour along the ridge, in a few overlapping strokes
    local n = #wall.pts / 2
    for i = 1, n - 4, 3 do
      ink.brush({ wall.pts[i * 2 - 1], wall.pts[i * 2], wall.pts[i * 2 + 1], wall.pts[i * 2 + 2] - 4, wall.pts[i * 2 + 5], wall.pts[i * 2 + 6] }, 5 + (i % 4) * 2, 0.8, 0.4)
    end
    -- texture strokes: short, dry, leaning the same way, denser near the top
    local dir = (wall.pts[1] < wall.pts[#wall.pts - 1]) and 1 or -1
    for k = 1, 90 do
      local i = rng:random(1, n)
      local x, y = wall.pts[i * 2 - 1], wall.pts[i * 2]
      local d = rng:random() ^ 1.7 * wall.depth * 0.7
      local len = 12 + rng:random() * 26
      local sx, sy = x + (rng:random() - 0.5) * 30, y + 8 + d
      ink.brush({ sx, sy, sx + dir * len * 0.2, sy + len * 0.5, sx + dir * len * 0.3, sy + len }, 2 + rng:random() * 5, 0.5 * (1 - d / wall.depth), 0.6)
    end
    -- vertical fissures
    for k = 1, 9 do
      local i = rng:random(2, n - 1)
      local x, y = wall.pts[i * 2 - 1], wall.pts[i * 2]
      ink.brush({ x, y + 4, x + dir * 6, y + 70, x + dir * 2, y + 130 + rng:random() * 80 }, 4, 0.6, 0.7)
    end
    -- moss dots ("dian"): clusters of small blots on the ledges
    for k = 1, 40 do
      local i = rng:random(1, n)
      ink.dot(wall.pts[i * 2 - 1] + rng:random(-14, 14), wall.pts[i * 2] + rng:random(-4, 10), 5 + rng:random() * 5, 0.75)
    end
  end
  -- dark rocks framing the top of the waterfall and its plunge pool
  lg.setColor(1, 1, 1)
  lg.draw(ink.fade({ 500, 320, 530, 282, 566, 266, 598, 280, 610, 300 }, 230, 0.75))
  lg.draw(ink.fade({ 692, 304, 716, 272, 750, 258, 792, 272, 820, 310 }, 250, 0.75))
  ink.brush({ 500, 322, 548, 258, 610, 296 }, 10, 0.9)
  ink.brush({ 692, 306, 744, 250, 820, 308 }, 10, 0.9)
  ink.brush({ 608, 296, 600, 360, 592, 430 }, 8, 0.7, 0.7)
  ink.brush({ 694, 304, 704, 370, 712, 440 }, 8, 0.7, 0.7)
  for k = 1, 16 do
    ink.dot(rng:random(505, 600), rng:random(280, 330), 6, 0.7)
    ink.dot(rng:random(700, 810), rng:random(274, 330), 6, 0.7)
  end
  for k = 0, 5 do
    ink.dot(500 + k * 60 + rng:random(-10, 10), 634 + rng:random(-8, 8), 36 + rng:random() * 20, 0.6)
  end
  ink.brush({ 470, 640, 560, 612, 640, 632 }, 12, 0.85)
  ink.brush({ 660, 636, 740, 610, 840, 640 }, 12, 0.85)
  -- pines on the ledges
  ink.pine(250, 372, 120, -0.12)
  ink.pine(330, 420, 86, 0.18)
  ink.pine(1040, 316, 130, 0.14)
  ink.pine(960, 372, 90, -0.2)
  ink.pine(120, 300, 70, 0.1)
  ink.pine(1190, 250, 76, -0.1)
  -- a pavilion on the right shelf: roof with upturned eaves, four posts
  local px, py = 1120, 372
  ink.brush({ px - 54, py - 40, px, py - 62, px + 54, py - 40 }, 9, 0.9, 0.3)
  ink.brush({ px - 54, py - 40, px - 66, py - 46, px - 72, py - 56 }, 4, 0.9, 0.6)
  ink.brush({ px + 54, py - 40, px + 66, py - 46, px + 72, py - 56 }, 4, 0.9, 0.6)
  ink.brush({ px - 8, py - 62, px, py - 76, px + 8, py - 62 }, 5, 0.9)
  lg.setColor(INK[1], INK[2], INK[3], 0.85)
  lg.setLineWidth(3)
  for _, ox in ipairs({ -38, -14, 14, 38 }) do lg.line(px + ox, py - 40, px + ox, py) end
  lg.setLineWidth(2)
  lg.line(px - 46, py, px + 46, py)
  lg.line(px - 38, py - 14, px + 38, py - 14)
  -- winding path steps up the left shelf
  for k = 0, 12 do
    local u = k / 12
    lg.setColor(INK[1], INK[2], INK[3], 0.5)
    lg.setLineWidth(1.5)
    lg.line(300 + u * 130 + math.sin(u * 9) * 12, 600 - u * 120, 318 + u * 130 + math.sin(u * 9) * 12, 600 - u * 120)
  end
  -- the bridge across the stream: a shallow arch with posts
  ink.brush({ 520, 600, 640, 566, 760, 600 }, 7, 0.9, 0.2)
  ink.brush({ 520, 590, 640, 552, 760, 590 }, 2.5, 0.8, 0.2)
  lg.setColor(INK[1], INK[2], INK[3], 0.8)
  lg.setLineWidth(1.5)
  for k = 0, 10 do
    local u = k / 10
    local y = 600 - math.sin(u * math.pi) * 17
    lg.line(520 + u * 240, y, 520 + u * 240, y - 11)
  end
  lg.pop()

  self.mist = {}
  for i = 1, 22 do
    self.mist[i] = { x = rng:random(-200, 1480), y = 440 + rng:random() * 170, s = 2.5 + rng:random() * 3.5, v = 8 + rng:random() * 12, a = 0.3 + rng:random() * 0.3 }
  end
  self.geese = {}
  for i = 0, 6 do self.geese[i + 1] = { dx = -math.abs(i - 3) * 26, dy = (i - 3) * 13, p = i } end
end

function S:update(dt)
  self.t = self.t + dt
  for _, m in ipairs(self.mist) do
    m.x = m.x + m.v * dt
    if m.x > 1500 then m.x = -260 end
  end
end

function S:drawTraveller(x, y)
  local t = self.t
  local step = math.sin(t * 4)
  lg.setColor(INK[1], INK[2], INK[3], 0.9)
  lg.setLineWidth(2)
  lg.line(x, y - 12, x + step * 3, y)
  lg.line(x, y - 12, x - step * 3, y)
  lg.polygon("fill", x - 5, y - 12, x + 5, y - 12, x + 3, y - 26, x - 3, y - 26)
  lg.circle("fill", x, y - 29, 3.2)
  -- wide straw hat, staff, a small bundle on the back
  lg.polygon("fill", x - 11, y - 30, x + 11, y - 30, x, y - 38)
  lg.setLineWidth(1.5)
  lg.line(x + 8, y - 34, x + 9 + step, y)
  lg.setColor(0.78, 0.12, 0.1, 0.9)
  lg.circle("fill", x - 6, y - 20, 3.5)
end

function S:draw()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.paper)
  -- a pale sun disc: a ring of wash, bare paper inside
  ink.dot(640, 120, 150, 0.1)
  lg.setColor(0.96, 0.89, 0.78)
  lg.circle("fill", 640, 120, 46)
  lg.setColor(0.8, 0.2, 0.14, 0.2)
  lg.circle("fill", 640, 120, 46)
  lg.setColor(1, 1, 1)
  for _, m in ipairs(self.far) do lg.draw(m) end
  -- geese in a V, far away
  local gx, gy = 300 + (t * 14) % 900, 120 + math.sin(t * 0.3) * 14
  for _, g in ipairs(self.geese) do
    local f = math.sin(t * 5 + g.p) * 3
    lg.setColor(INK[1], INK[2], INK[3], 0.7)
    lg.setLineWidth(1.6)
    lg.line(gx + g.dx - 7, gy + g.dy - f, gx + g.dx, gy + g.dy, gx + g.dx + 7, gy + g.dy - f)
  end
  -- mist behind the gorge walls
  for i, m in ipairs(self.mist) do
    if i % 2 == 0 then
      lg.setColor(0.95, 0.91, 0.82, m.a)
      lg.draw(self.soft, m.x, m.y - 120, 0, m.s * 1.6, m.s * 0.5, 64, 64)
    end
  end
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.static)
  lg.setBlendMode("alpha")
  -- the waterfall: thin lines sliding down the bare paper, and its second drop
  for k = 0, 13 do
    local x = 612 + k * 6.4 + math.sin(k * 3.1) * 2
    for j = 0, 3 do
      local y = 290 + ((t * (150 + (k % 4) * 30) + j * 80 + k * 37) % 300)
      local len = 30 + (k * 7 + j * 13) % 40
      lg.setColor(INK[1], INK[2], INK[3], 0.3 * (1 - (y - 290) / 300))
      lg.setLineWidth(1.2)
      lg.line(x, y, x + math.sin(y * 0.02) * 2, math.min(590, y + len))
    end
  end
  ink.brush({ 606, 286, 600, 380, 596, 470 }, 3, 0.5, 0.8)
  ink.brush({ 700, 290, 708, 380, 712, 470 }, 3, 0.5, 0.8)
  -- spray at the foot: paper-coloured blobs that pulse
  for k = 0, 6 do
    lg.setColor(0.95, 0.91, 0.82, 0.55 + 0.25 * math.sin(t * 1.4 + k))
    lg.draw(self.soft, 580 + k * 22, 560 + math.sin(t * 0.9 + k * 2) * 8, 0, 1.2 + (k % 3) * 0.4, 0.8, 64, 64)
  end
  -- ripples in the pool below the bridge
  for k = 0, 4 do
    local u = (t * 0.25 + k / 5) % 1
    lg.setColor(INK[1], INK[2], INK[3], 0.3 * (1 - u))
    lg.setLineWidth(1.2)
    lg.arc("line", "open", 640, 660, 30 + u * 120, math.pi * 1.1, math.pi * 1.9)
  end
  -- the traveller crossing the bridge, very slowly
  local u = (t * 0.02 + 0.3) % 1
  self:drawTraveller(520 + u * 240, 598 - math.sin(u * math.pi) * 17)
  -- mist in front: drifting paper-coloured fog that hides the cliff feet
  for i, m in ipairs(self.mist) do
    if i % 2 == 1 then
      lg.setColor(0.95, 0.91, 0.82, m.a * 0.9)
      lg.draw(self.soft, m.x, m.y + 40, 0, m.s * 1.8, m.s * 0.45, 64, 64)
    end
  end
  ink.column(470, 56, 2)
  ink.seal(448, 158, 44)
end

return S
