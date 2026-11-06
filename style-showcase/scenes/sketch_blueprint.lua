-- HAND-DRAWN, scene 3: a hand-drafted blueprint of a tower-defence turret.
--
-- Technical drawing has its own vocabulary, all of it just lines and text:
--   * a fine + coarse grid on cyanotype blue paper, with a faint fold crease
--   * dimension lines: extension lines, arrowheads and a measurement in the gap
--   * callout bubbles with leader lines, a section marker, a title block
-- Lines are only slightly wobbly (a draftsman with a ruler, not a doodler), and a
-- couple of parts move: the turret turns in the plan view and the gears mesh in the
-- detail view (the small gear turns faster, by the ratio of tooth counts).

local gfx = require("core.gfx")
local sketchy = require("core.sketchy")
local moonshine = require("moonshine")

local lg = love.graphics
local INK = { 0.93, 0.97, 1, 0.92 }
local FAINT = { 0.85, 0.93, 1, 0.45 }

local S = {
  title = "Hand-Drawn",
  subtitle = "Blueprint",
  blurb = "A hand-drafted turret schematic: grid paper, dimension lines, callouts, a title block, a rotating plan view and meshing gears.",
  techniques = {
    "Cyanotype paper: gradient + baked grid (fine and coarse) + fold crease",
    "Dimension lines with arrowheads and centred labels (a reusable function)",
    "Ruler-steady strokes: the same wobble helper, turned down to 0.8 px",
    "Gear outlines generated from tooth count; meshing speeds follow the ratio",
    "Soft glow so the white ink bleeds slightly into the paper",
  },
  libs = {
    "moonshine: glow (ink bleed) and vignette (paper edges)",
  },
  genres = { "Building / engineering sims", "Tower defence and crafting menus", "Heist and planning screens", "Sci-fi tech trees and codex pages" },
  warmup = 3,
}

local function gearPoints(cx, cy, r, teeth, rot)
  local pts = {}
  local n = teeth * 4
  for i = 0, n - 1 do
    local a = rot + i / n * math.pi * 2
    local k = i % 4
    local rr = (k == 1 or k == 2) and r or r * 0.82
    pts[#pts + 1] = cx + math.cos(a) * rr
    pts[#pts + 1] = cy + math.sin(a) * rr
  end
  return pts
end

function S:load()
  self.t = 0
  self.pen = sketchy.new({ wobble = 0.8, double = false })
  self.paper = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.paper)
  lg.draw(gfx.vgradient(1280, 720, { { 0, gfx.rgb("#1f5aa0") }, { 1, gfx.rgb("#17447e") } }))
  lg.setLineWidth(1)
  for x = 0, 1280, 16 do
    lg.setColor(1, 1, 1, x % 80 == 0 and 0.16 or 0.06)
    lg.line(x, 0, x, 720)
  end
  for y = 0, 720, 16 do
    lg.setColor(1, 1, 1, y % 80 == 0 and 0.16 or 0.06)
    lg.line(0, y, 1280, y)
  end
  lg.setColor(1, 1, 1, 0.05)
  lg.setLineWidth(6)
  lg.line(640, 0, 640, 720)
  lg.pop()

  self.big = lg.newFont(24)
  self.mid = lg.newFont(16)
  self.small = lg.newFont(13)
  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.7
  self.fx.glow.strength = 2
  self.fx.vignette.opacity = 0.45
end

function S:update(dt)
  self.t = self.t + dt
end

function S:arrow(x, y, angle)
  local s = 10
  lg.setColor(INK)
  lg.polygon("fill", x, y, x - math.cos(angle - 0.3) * s, y - math.sin(angle - 0.3) * s, x - math.cos(angle + 0.3) * s, y - math.sin(angle + 0.3) * s)
end

-- Horizontal or vertical dimension line between two points, with a label in the middle.
function S:dimension(x1, y1, x2, y2, label, offset)
  local pen = self.pen
  local horizontal = math.abs(y2 - y1) < math.abs(x2 - x1)
  if horizontal then
    local y = math.max(y1, y2) + offset
    pen:line(x1, y1 + 6, x1, y + 8, FAINT, 1)
    pen:line(x2, y2 + 6, x2, y + 8, FAINT, 1)
    pen:line(x1, y, x2, y, INK, 1.2)
    self:arrow(x1, y, math.pi)
    self:arrow(x2, y, 0)
    lg.setFont(self.small)
    local w = self.small:getWidth(label)
    lg.setColor(gfx.hex("#1d5293"))
    lg.rectangle("fill", (x1 + x2) / 2 - w / 2 - 4, y - 8, w + 8, 16)
    lg.setColor(INK)
    lg.print(label, (x1 + x2) / 2 - w / 2, y - 8)
  else
    local x = math.min(x1, x2) - offset
    pen:line(x1 - 6, y1, x - 8, y1, FAINT, 1)
    pen:line(x2 - 6, y2, x - 8, y2, FAINT, 1)
    pen:line(x, y1, x, y2, INK, 1.2)
    self:arrow(x, y1, -math.pi / 2)
    self:arrow(x, y2, math.pi / 2)
    lg.setFont(self.small)
    lg.setColor(INK)
    lg.print(label, x - 4, (y1 + y2) / 2 + 20, -math.pi / 2)
  end
end

function S:callout(n, x, y, tx, ty)
  self.pen:line(x, y, tx, ty, FAINT, 1)
  lg.setColor(INK)
  lg.circle("fill", tx, ty, 3)
  self.pen:circle(x, y, 13, INK, 1.4)
  lg.setFont(self.mid)
  lg.printf(tostring(n), x - 13, y - 9, 26, "center")
end

function S:elevation()
  local pen = self.pen
  local cx, base = 330, 560
  -- base plinth
  pen:poly({ cx - 140, base, cx + 140, base, cx + 120, base - 50, cx - 120, base - 50 }, INK, 1.8)
  pen:line(cx - 120, base - 25, cx + 120, base - 25, FAINT, 1)
  -- column
  pen:poly({ cx - 40, base - 50, cx + 40, base - 50, cx + 34, base - 210, cx - 34, base - 210 }, INK, 1.8)
  for y = base - 70, base - 200, -26 do pen:line(cx - 36, y, cx + 36, y, FAINT, 1) end
  -- turret head and barrel
  pen:poly({ cx - 90, base - 210, cx + 90, base - 210, cx + 70, base - 290, cx - 70, base - 290 }, INK, 1.8)
  pen:poly({ cx + 70, base - 268, cx + 230, base - 262, cx + 230, base - 244, cx + 82, base - 236 }, INK, 1.8)
  pen:poly({ cx + 230, base - 270, cx + 250, base - 270, cx + 250, base - 236, cx + 230, base - 236 }, INK, 1.8)
  pen:circle(cx - 20, base - 252, 20, INK, 1.5)
  pen:circle(cx - 20, base - 252, 6, FAINT, 1)
  -- centre line (dash-dot)
  for y = base + 20, base - 320, -24 do pen:line(cx, y, cx, y - 12, FAINT, 1) end
  self:dimension(cx - 140, base, cx + 140, base, "1200", 30)
  self:dimension(cx - 140, base, cx - 140, base - 290, "1450", 30)
  self:dimension(cx + 70, base - 262, cx + 250, base - 262, "780", -40)
  self:callout(1, cx - 210, base - 330, cx - 60, base - 270)
  self:callout(2, cx + 190, base - 190, cx + 160, base - 252)
  self:callout(3, cx + 190, base - 110, cx + 36, base - 120)
  lg.setFont(self.big)
  lg.setColor(INK)
  lg.print("SIDE ELEVATION", cx - 100, 110)
end

function S:plan()
  local pen = self.pen
  local cx, cy, r = 820, 260, 110
  pen:circle(cx, cy, r, INK, 1.8)
  pen:circle(cx, cy, r * 0.55, FAINT, 1.2)
  pen:line(cx - r - 20, cy, cx + r + 20, cy, FAINT, 1)
  pen:line(cx, cy - r - 20, cx, cy + r + 20, FAINT, 1)
  local a = math.sin(self.t * 0.6) * 1.1
  local ca, sa = math.cos(a), math.sin(a)
  local function rot(x, y) return cx + x * ca - y * sa, cy + x * sa + y * ca end
  local box = {}
  for _, p in ipairs({ { -60, -50 }, { 60, -50 }, { 60, 50 }, { -60, 50 } }) do
    local x, y = rot(p[1], p[2]); box[#box + 1] = x; box[#box + 1] = y
  end
  pen:poly(box, INK, 1.6)
  local b1x, b1y = rot(60, -10)
  local b2x, b2y = rot(180, -10)
  local b3x, b3y = rot(180, 10)
  local b4x, b4y = rot(60, 10)
  pen:poly({ b1x, b1y, b2x, b2y, b3x, b3y, b4x, b4y }, INK, 1.6)
  lg.setFont(self.big)
  lg.setColor(INK)
  lg.print("PLAN", cx - 30, 110)
  self:dimension(cx - r, cy + r + 10, cx + r, cy + r + 10, "Ø 880", 22)
  lg.setFont(self.small)
  lg.setColor(FAINT)
  lg.print(("traverse %+04d°"):format(math.floor(math.deg(a))), cx + 60, cy + r - 10)
end

function S:detail()
  local pen = self.pen
  local cx, cy = 1080, 270
  pen:circle(cx, cy, 120, FAINT, 1.2)
  lg.setFont(self.big)
  lg.setColor(INK)
  lg.print("DETAIL B (2:1)", cx - 90, 110)
  local big, small = 24, 12
  local r1, r2 = 60, 30
  local a1 = self.t * 0.6
  local a2 = -a1 * big / small + math.pi / small -- meshing gear turns faster, opposite way
  pen:poly(gearPoints(cx - 24, cy + 10, r1, big, a1), INK, 1.4)
  pen:poly(gearPoints(cx + 24 + r2 + 6, cy - 10 - 20, r2, small, a2), INK, 1.4)
  pen:circle(cx - 24, cy + 10, 10, INK, 1.2)
  pen:circle(cx + 60, cy - 30, 6, INK, 1.2)
end

function S:titleBlock()
  local x, y, w, h = 840, 470, 410, 220
  local pen = self.pen
  pen:poly({ x, y, x + w, y, x + w, y + h, x, y + h }, INK, 2)
  for _, yy in ipairs({ 56, 100, 144, 182 }) do pen:line(x, y + yy, x + w, y + yy, INK, 1.2) end
  pen:line(x + 200, y + 100, x + 200, y + h, INK, 1.2)
  lg.setColor(INK)
  lg.setFont(self.big)
  lg.print("TURRET  MK II", x + 14, y + 14)
  lg.setFont(self.small)
  lg.print("PROJECT: TOWER DEFENCE - LEVEL 4", x + 14, y + 70)
  lg.print("SCALE 1:20", x + 14, y + 112)
  lg.print("SHEET 2 OF 7", x + 214, y + 112)
  lg.print("DRAWN: LÖVE / LUA", x + 14, y + 154)
  lg.print("MATERIAL: STEEL", x + 214, y + 154)
  lg.print("UNITS: MM", x + 14, y + 192)
  lg.print("REV C", x + 214, y + 192)
  -- section marker A-A
  for _, p in ipairs({ { 560, 600 }, { 560, 150 } }) do
    pen:circle(p[1], p[2], 16, INK, 1.4)
    lg.setFont(self.mid)
    lg.printf("A", p[1] - 16, p[2] - 9, 32, "center")
  end
  for yy = 175, 575, 30 do pen:line(560, yy, 560, yy + 16, FAINT, 1) end
end

function S:draw()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.paper)
    self:elevation()
    self:plan()
    self:detail()
    self:titleBlock()
  end)
end

return S
