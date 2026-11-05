-- HAND-DRAWN / SKETCHBOOK: pencil doodles on a page of a school notebook.
--
-- Straight lines look like a computer drew them. To look hand-made:
--   * every stroke is split into short pieces and each point is nudged sideways by noise
--   * every stroke is drawn twice with different nudges (people rarely hit the same line)
--   * the noise seed changes 8 times a second, so lines "boil" like hand-drawn animation
--   * fills are hatching: diagonal strokes clipped to the shape with a stencil
--   * letters are printed one by one with a small random tilt and baseline wobble
-- In the corner, turtle.lua draws a pattern live, one pen move at a time.

local gfx = require("core.gfx")
local Turtle = require("turtle.turtle")

local lg = love.graphics
local PENCIL = { 0.22, 0.22, 0.27, 0.85 }
local INK = { 0.12, 0.25, 0.65, 0.9 }

local S = {
  title = "Hand-Drawn",
  subtitle = "Doodle Notebook",
  blurb = "Pencil and crayon on lined paper. Wobbly, boiling strokes and hatched fills make code-drawn shapes feel hand-made.",
  techniques = {
    "Strokes are subdivided and jittered with noise, drawn twice per line",
    "Line boil: the jitter seed changes 8x per second",
    "Hatching fills: diagonal strokes clipped with love.graphics.stencil",
    "Handwriting: each letter printed with its own tilt and baseline offset",
    "Paper: baked grain noise, ruled lines, margin, punch holes and a coffee ring",
  },
  libs = {
    "turtle.lua: Logo-style turtle that draws the spiral star live (bottom right)",
  },
  genres = { "Doodle platformers and physics drawing games", "Puzzle games and educational apps", "Journals, diaries and narrative indies", "Prototype art that still has charm" },
  warmup = 4,
}

local function bakePaper()
  local w, h = 640, 360
  local d = love.image.newImageData(w, h)
  d:mapPixel(function(x, y)
    local n = love.math.noise(x * 0.9, y * 0.9) * 0.04 + gfx.fbm(x * 0.01, y * 0.01, 3) * 0.05
    return 0.97 - n, 0.95 - n, 0.89 - n, 1
  end)
  local c = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(lg.newImage(d), 0, 0, 0, 2, 2)
  lg.setLineWidth(1.5)
  for y = 96, 720, 34 do
    lg.setColor(0.45, 0.62, 0.85, 0.55)
    lg.line(0, y, 1280, y)
  end
  lg.setColor(0.9, 0.35, 0.4, 0.6)
  lg.line(118, 0, 118, 720)
  for _, y in ipairs({ 140, 360, 580 }) do
    lg.setColor(0.82, 0.8, 0.74)
    lg.circle("fill", 52, y, 16)
    lg.setColor(0.7, 0.68, 0.62)
    lg.circle("line", 52, y, 16)
  end
  -- coffee ring
  lg.setLineWidth(5)
  lg.setColor(0.55, 0.38, 0.2, 0.18)
  lg.ellipse("line", 1080, 160, 74, 70)
  lg.setLineWidth(2)
  lg.setColor(0.55, 0.38, 0.2, 0.25)
  lg.ellipse("line", 1083, 158, 70, 67)
  lg.pop()
  return c
end

function S:load()
  self.t = 0
  self.paper = bakePaper()
  self.hand = lg.newFont(26)
  self.handSmall = lg.newFont(19)
  self:newTurtle()
end

function S:newTurtle()
  -- A spiral star: forward, turn 170 degrees, repeat. Classic Logo.
  local t = Turtle(1010, 440, 4)
  t:color(INK):pensize(1.5)       -- each move remembers the pen colour/size at that moment
  t:turtlecolor({ 0.12, 0.25, 0.65, 1 })
  for i = 1, 40 do
    t:forward(24 + i * 4):right(170)
  end
  -- We drive its animation from update() so it runs at the scene's own pace.
  t.update = function() end
  self.turtle = t
  self.turtleDone = nil
  t:ondrawfinish(function() self.turtleDone = self.turtleDone or 0 end)
end

function S:update(dt)
  self.t = self.t + dt
  self.seed = math.floor(self.t * 8)
  getmetatable(self.turtle).__index.update(self.turtle, dt)
  if self.turtleDone then
    self.turtleDone = self.turtleDone + dt
    if self.turtleDone > 2.5 then self:newTurtle() end
  end
end

-- A wobbly line: subdivide, then push each point sideways with noise.
function S:stroke(x1, y1, x2, y2, pass)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  local n = math.max(2, math.floor(len / 14))
  local nx, ny = -dy / (len + 0.001), dx / (len + 0.001)
  local pts = {}
  local s = (self.seed or 0) * 13.7 + (pass or 0) * 51.3 + x1 * 0.37 + y1 * 0.71
  for i = 0, n do
    local f = i / n
    local off = (love.math.noise(s, i * 0.35) - 0.5) * 3.2
    -- strokes overshoot or stop short a little at the ends
    local e = (i == 0 and -1 or (i == n and 1 or 0)) * (love.math.noise(s + 5) - 0.3) * 4
    pts[#pts + 1] = x1 + dx * f + nx * off + dx / (len + 0.001) * e
    pts[#pts + 1] = y1 + dy * f + ny * off + dy / (len + 0.001) * e
  end
  lg.line(pts)
end

function S:sketchLine(x1, y1, x2, y2, color, width)
  lg.setColor(color or PENCIL)
  lg.setLineWidth(width or 2)
  self:stroke(x1, y1, x2, y2, 0)
  lg.setColor((color or PENCIL)[1], (color or PENCIL)[2], (color or PENCIL)[3], 0.45)
  lg.setLineWidth((width or 2) * 0.7)
  self:stroke(x1, y1, x2, y2, 1)
end

function S:sketchPoly(pts, color, width)
  for i = 1, #pts, 2 do
    local j = (i + 2 > #pts) and 1 or i + 2
    self:sketchLine(pts[i], pts[i + 1], pts[j], pts[j + 1], color, width)
  end
end

function S:sketchCircle(cx, cy, r, color, width)
  local prev
  local n = math.max(10, math.floor(r / 4))
  for i = 0, n do
    local a = i / n * math.pi * 2 + 0.3
    local wob = 1 + (love.math.noise((self.seed or 0) * 3.1 + cx * 0.01, i * 0.3) - 0.5) * 0.08
    local x, y = cx + math.cos(a) * r * wob, cy + math.sin(a) * r * wob
    if prev then self:sketchLine(prev[1], prev[2], x, y, color, width) end
    prev = { x, y }
  end
end

-- Hatching: clip to the shape with a stencil, then draw diagonal strokes over its bounding box.
function S:hatch(drawShape, x, y, w, h, color, gap, angleUp)
  lg.stencil(drawShape, "replace", 1)
  lg.setStencilTest("greater", 0)
  local g = gap or 9
  for k = -h, w, g do
    if angleUp then
      self:sketchLine(x + k, y + h, x + k + h, y, color, 1.6)
    else
      self:sketchLine(x + k, y, x + k + h, y + h, color, 1.6)
    end
  end
  lg.setStencilTest()
end

function S:handwrite(text, x, y, font, color, seed)
  lg.setFont(font)
  lg.setColor(color)
  local cx = x
  for i = 1, #text do
    local ch = text:sub(i, i)
    local n1 = love.math.noise(i * 0.7, seed or 1)
    local n2 = love.math.noise(i * 0.7, (seed or 1) + 9)
    lg.print(ch, cx, y + (n1 - 0.5) * 6, (n2 - 0.5) * 0.25)
    cx = cx + font:getWidth(ch) * (0.92 + n1 * 0.12)
  end
end

function S:drawHouse()
  local x, y = 190, 300
  local wall = { x, y, x + 180, y, x + 180, y + 150, x, y + 150 }
  local roof = { x - 20, y, x + 90, y - 90, x + 200, y }
  self:hatch(function() lg.polygon("fill", roof) end, x - 20, y - 90, 220, 90, { 0.75, 0.25, 0.2, 0.7 }, 8, true)
  self:sketchPoly(wall)
  self:sketchPoly(roof)
  self:sketchPoly({ x + 70, y + 150, x + 70, y + 80, x + 110, y + 80, x + 110, y + 150 })
  self:sketchPoly({ x + 20, y + 30, x + 55, y + 30, x + 55, y + 65, x + 20, y + 65 })
  self:sketchLine(x + 37, y + 30, x + 37, y + 65)
  self:sketchLine(x + 20, y + 47, x + 55, y + 47)
  self:sketchPoly({ x + 135, y - 55, x + 135, y - 90, x + 160, y - 90, x + 160, y - 30 })
  -- smoke spiral
  local prev
  for i = 0, 40 do
    local a = i * 0.45
    local px = x + 148 + math.cos(a) * (6 + i * 0.6) + i * 1.2
    local py = y - 100 - i * 3.2 + math.sin(a) * 6
    if prev then self:sketchLine(prev[1], prev[2], px, py, { 0.4, 0.4, 0.45, 0.6 }, 1.5) end
    prev = { px, py }
  end
  self:sketchLine(140, y + 152, 420, y + 152)
end

function S:drawSun()
  local cx, cy = 1080, 160
  lg.stencil(function() lg.circle("fill", cx, cy, 52) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  for k = -60, 60, 7 do self:sketchLine(cx - 60 + k, cy - 60, cx + k + 60, cy + 60, { 1, 0.75, 0.1, 0.8 }, 3) end
  lg.setStencilTest()
  self:sketchCircle(cx, cy, 52, { 0.85, 0.55, 0.05, 0.9 }, 2.2)
  for i = 0, 11 do
    local a = i / 12 * math.pi * 2 + math.sin(self.t) * 0.05
    self:sketchLine(cx + math.cos(a) * 66, cy + math.sin(a) * 66, cx + math.cos(a) * 96, cy + math.sin(a) * 96, { 0.85, 0.55, 0.05, 0.9 }, 2.2)
  end
  self:sketchLine(cx - 22, cy - 10, cx - 12, cy - 10, PENCIL)
  self:sketchLine(cx + 12, cy - 10, cx + 22, cy - 10, PENCIL)
  local prev
  for i = 0, 8 do
    local a = 0.4 + i / 8 * (math.pi - 0.8)
    local p = { cx + math.cos(a) * 22, cy + 4 + math.sin(a) * 16 }
    if prev then self:sketchLine(prev[1], prev[2], p[1], p[2], PENCIL) end
    prev = p
  end
end

function S:drawKnightAndDragon()
  -- stick knight
  local kx, ky = 520, 520
  self:sketchCircle(kx, ky - 110, 16)
  self:sketchLine(kx, ky - 94, kx, ky - 40)
  self:sketchLine(kx, ky - 40, kx - 20, ky)
  self:sketchLine(kx, ky - 40, kx + 20, ky)
  self:sketchLine(kx, ky - 80, kx + 30, ky - 70)
  self:sketchLine(kx, ky - 80, kx - 26, ky - 60)
  local swing = math.sin(self.t * 3) * 0.3
  local sx, sy = kx + 30, ky - 70
  self:sketchLine(sx, sy, sx + math.cos(-0.9 + swing) * 70, sy + math.sin(-0.9 + swing) * 70, { 0.3, 0.3, 0.4, 0.9 }, 2.5)
  self:sketchPoly({ kx - 40, ky - 75, kx - 22, ky - 75, kx - 22, ky - 45, kx - 31, ky - 35, kx - 40, ky - 45 }, { 0.2, 0.35, 0.7, 0.9 })
  -- dragon
  local dx, dy = 780, 470
  local body = { dx - 60, dy, dx - 30, dy - 40, dx + 40, dy - 45, dx + 90, dy - 10, dx + 60, dy + 30, dx - 30, dy + 30 }
  self:hatch(function() lg.polygon("fill", body) end, dx - 60, dy - 45, 150, 75, { 0.2, 0.55, 0.3, 0.6 }, 9)
  self:sketchPoly(body, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchLine(dx - 30, dy - 40, dx - 70, dy - 100, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchLine(dx - 10, dy - 42, dx - 50, dy - 100, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchPoly({ dx - 90, dy - 120, dx - 45, dy - 115, dx - 60, dy - 95, dx - 85, dy - 100 }, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchCircle(dx - 70, dy - 112, 3, PENCIL, 2)
  local flap = math.sin(self.t * 4) * 20
  self:sketchPoly({ dx + 10, dy - 45, dx + 30, dy - 130 - flap, dx + 70, dy - 90 - flap * 0.5, dx + 50, dy - 40 }, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchLine(dx + 90, dy - 10, dx + 150, dy - 30, { 0.15, 0.4, 0.2, 0.9 })
  self:sketchLine(dx + 150, dy - 30, dx + 165, dy - 50, { 0.15, 0.4, 0.2, 0.9 })
  for i = 0, 3 do
    local x = dx - 20 + i * 25
    self:sketchPoly({ x, dy - 44, x + 8, dy - 62, x + 16, dy - 44 }, { 0.15, 0.4, 0.2, 0.9 })
  end
  -- fire scribble in crayon colours
  for i = 0, 10 do
    local f = love.math.noise(self.seed * 0.7, i * 0.9)
    local col = (i % 3 == 0) and { 1, 0.75, 0.1, 0.8 } or { 0.95, 0.3, 0.1, 0.75 }
    self:sketchLine(dx - 92, dy - 108, dx - 150 - f * 70, dy - 130 + i * 6 + f * 10, col, 3)
  end
  self:sketchLine(140, ky + 2, 960, ky + 2)
end

function S:drawSticky()
  lg.push()
  lg.translate(870, 600)
  lg.rotate(-0.05)
  lg.setColor(0, 0, 0, 0.12)
  lg.rectangle("fill", -96, -76, 200, 150)
  lg.setColor(1, 0.92, 0.45)
  lg.rectangle("fill", -100, -80, 200, 150)
  lg.setColor(1, 0.97, 0.7)
  lg.rectangle("fill", -100, -80, 200, 20)
  self:handwrite("game ideas:", -88, -54, self.handSmall, { 0.15, 0.15, 0.3, 0.9 }, 4)
  self:handwrite("- doodle jumper", -88, -22, self.handSmall, { 0.15, 0.15, 0.3, 0.9 }, 5)
  self:handwrite("- ink physics", -88, 6, self.handSmall, { 0.15, 0.15, 0.3, 0.9 }, 6)
  self:handwrite("- dragon diary!", -88, 34, self.handSmall, { 0.8, 0.2, 0.2, 0.9 }, 7)
  lg.pop()
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.paper)
  self:handwrite("Level 1 ideas ... (don't forget the dragon)", 150, 64, self.hand, { 0.15, 0.2, 0.5, 0.9 }, 2)
  self:drawHouse()
  self:drawSun()
  self:drawKnightAndDragon()
  self:handwrite("TODO: slay dragon", 470, 610, self.hand, { 0.15, 0.2, 0.5, 0.9 }, 3)
  self:sketchLine(600, 600, 690, 520, INK)
  self:sketchLine(690, 520, 672, 528, INK)
  self:sketchLine(690, 520, 686, 538, INK)
  self:drawSticky()
  -- turtle.lua, drawing live
  lg.setColor(INK)
  self.turtle:draw()
  self:handwrite("^ turtle.lua draws this live", 1000, 600, self.handSmall, { 0.15, 0.2, 0.5, 0.75 }, 11)
end

return S
