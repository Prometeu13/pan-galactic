-- CARTOON: thick outlines, saturated flat colours, squash & stretch.
--
-- The whole look comes from two rules:
--   1. Draw every shape twice: a slightly bigger copy in the outline colour, then the fill.
--      For a group of circles (clouds, bushes) draw ALL outlines first, then ALL fills,
--      so the group reads as one puffy silhouette.
--   2. Never move rigidly. The blob squashes before it jumps, stretches in the air and
--      wobbles when it lands (flux tweens with elastic easing do the work).

local gfx = require("core.gfx")
local view = require("core.view")
local flux = require("flux")
local Timer = require("hump.timer")
local Draft = require("draft")

local lg = love.graphics
local OUT = { gfx.hex("#2a1f3d") }   -- one outline colour for everything = cohesive cartoon look
local LW = 5

local S = {
  title = "Cartoon",
  subtitle = "Sunny Meadow",
  blurb = "Bold outlines, flat saturated colour and bouncy animation. The character is three ellipses and a lot of easing.",
  techniques = {
    "Outline pass then fill pass for every shape (circles drawn r+5 in dark purple first)",
    "Puffy clouds and bushes = several circles: all outlines first, then all fills",
    "Squash & stretch: the body is one ellipse scaled by tweened sx/sy around its feet",
    "Pupils look at the mouse; blinks scheduled at random intervals",
    "Comic 'BOING!' burst is a draft star polygon that pops in with back-out easing",
  },
  libs = {
    "flux: chained tweens (squash -> jump -> fall -> elastic wobble)",
    "hump.timer: random blinks and the pause between hops",
    "draft: star, egg and ellipse polygons (sun rays, burst, petals)",
  },
  genres = { "Platformers and casual mobile games", "Kids' and educational games", "Party / physics toys", "Cosy farming or pet sims" },
  controls = "click anywhere on the grass to make the blob hop there.",
  warmup = 2.6,
}

local draft = Draft("fill")

local function hillY(x, layer)
  if layer == 1 then
    return 430 + math.sin(x * 0.006 + 1.2) * 34 + math.sin(x * 0.013) * 14
  end
  return 540 + math.sin(x * 0.004 + 0.3) * 28 + math.sin(x * 0.011 + 2) * 10
end

local function outlinedCircles(circles, fill)
  lg.setColor(OUT)
  for _, c in ipairs(circles) do lg.circle("fill", c[1], c[2], c[3] + LW) end
  lg.setColor(fill)
  for _, c in ipairs(circles) do lg.circle("fill", c[1], c[2], c[3]) end
end

local function outlinedPoly(pts, fill)
  lg.setColor(fill)
  draft:polygon(pts, "fill")
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  lg.setLineJoin("bevel")
  lg.polygon("line", pts)
end

function S:load()
  self.flux = flux.group()
  self.timer = Timer.new()
  self.t = 0
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#4fb8ff") }, { 0.55, gfx.rgb("#a8e6ff") }, { 1, gfx.rgb("#e6fbff") },
  })

  self.clouds = {
    { x = 180, y = 120, s = 1.0, v = 12 },
    { x = 620, y = 80, s = 0.75, v = 18 },
    { x = 900, y = 210, s = 0.6, v = 9 },
  }

  -- Flowers along the front hill.
  self.flowers = {}
  local petals = { "#ff7aa8", "#ffffff", "#ffb347", "#c38bff", "#ff5d5d" }
  love.math.setRandomSeed(7)
  for i = 1, 16 do
    local x = 40 + i * 76 + love.math.random(-20, 20)
    self.flowers[i] = {
      x = x, h = love.math.random(34, 64), color = { gfx.hex(petals[(i % #petals) + 1]) },
      phase = love.math.random() * 6,
    }
  end

  -- The blob. x/h are position and height above ground, sx/sy the squash & stretch.
  self.blob = { x = 640, h = 0, sx = 1, sy = 1, blink = false, airborne = false, target = 640 }
  self.dust = {}
  self.burst = { scale = 0, alpha = 0, x = 0, y = 0, rot = 0 }

  local function blinkLoop()
    self.timer:after(love.math.random() * 2.5 + 1.2, function()
      self.blob.blink = true
      self.timer:after(0.12, function() self.blob.blink = false; blinkLoop() end)
    end)
  end
  blinkLoop()
  self:hop()
end

function S:hop(target)
  local b = self.blob
  if b.airborne then return end
  b.airborne = true
  b.target = target or gfx.clamp(b.x + love.math.random(-260, 260), 360, 1000)
  self.flux:to(b, 0.12, { sx = 1.28, sy = 0.72 }):ease("quadout")
    :after(b, 0.34, { h = 150, sx = 0.84, sy = 1.22 }):ease("quadout")
    :after(b, 0.34, { h = 0, sx = 1, sy = 1 }):ease("quadin")
    :oncomplete(function() self:land() end)
  self.flux:to(b, 0.8, { x = b.target }):ease("sineinout"):delay(0.12)
end

function S:land()
  local b = self.blob
  b.airborne = false
  for i = 1, 10 do
    local a = math.pi + (i - 0.5) / 10 * math.pi
    self.dust[#self.dust + 1] = { x = b.x, y = hillY(b.x, 2), vx = math.cos(a) * 140, vy = math.sin(a) * 50, r = 12, life = 0.5 }
  end
  local burst = self.burst
  burst.x, burst.y, burst.rot = b.x + 120, hillY(b.x, 2) - 170, love.math.random() * 0.4 - 0.2
  burst.scale, burst.alpha = 0, 1
  self.flux:to(burst, 0.3, { scale = 1 }):ease("backout")
    :after(burst, 0.4, { alpha = 0 }):delay(0.4)

  self.flux:to(b, 0.08, { sx = 1.4, sy = 0.62 }):ease("quadout")
    :after(b, 0.7, { sx = 1, sy = 1 }):ease("elasticout")
    :oncomplete(function()
      self.timer:after(0.3 + love.math.random() * 0.6, function() self:hop() end)
    end)
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  self.timer:update(dt)
  for _, c in ipairs(self.clouds) do
    c.x = c.x + c.v * dt
    if c.x > 1450 then c.x = -200 end
  end
  for i = #self.dust, 1, -1 do
    local d = self.dust[i]
    d.life = d.life - dt
    d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
    d.r = d.r + 30 * dt
    if d.life <= 0 then table.remove(self.dust, i) end
  end
end

function S:mousepressed(x, y)
  if y > 380 then self:hop(gfx.clamp(x, 80, 1200)) end
end

local function drawCloud(c)
  local s = c.s
  local parts = {
    { -70, 10, 42 }, { -25, -18, 55 }, { 35, -8, 50 }, { 80, 14, 36 }, { 5, 22, 44 },
  }
  local circles = {}
  for i, p in ipairs(parts) do circles[i] = { c.x + p[1] * s, c.y + p[2] * s, p[3] * s } end
  outlinedCircles(circles, { 1, 1, 1 })
  lg.setColor(gfx.hex("#d9f2ff"))
  lg.ellipse("fill", c.x + 5 * s, c.y + 38 * s, 80 * s, 12 * s)
end

function S:drawSun()
  local cx, cy = 1080, 130
  local rot = self.t * 0.25
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  local rays = draft:star(cx, cy, 300, 175, 12, rot, false)
  lg.setColor(gfx.hex("#ffd23f"))
  draft:polygon(rays, "fill")
  lg.setColor(OUT)
  lg.polygon("line", rays)
  outlinedCircles({ { cx, cy, 70 } }, { gfx.hex("#ffe873") })
  -- Face: closed happy eyes, smile and blush.
  lg.setColor(OUT)
  lg.setLineWidth(4)
  lg.arc("line", "open", cx - 24, cy - 6, 11, math.pi, math.pi * 2)
  lg.arc("line", "open", cx + 24, cy - 6, 11, math.pi, math.pi * 2)
  lg.arc("line", "open", cx, cy + 10, 26, 0.3, math.pi - 0.3)
  lg.setColor(gfx.hex("#ff8a8a", 0.7))
  lg.ellipse("fill", cx - 44, cy + 14, 11, 7)
  lg.ellipse("fill", cx + 44, cy + 14, 11, 7)
end

local function hillPoints(layer)
  local pts = {}
  for x = -20, 1300, 20 do
    pts[#pts + 1] = x
    pts[#pts + 1] = hillY(x, layer)
  end
  return pts
end

function S:drawHill(layer, color, shade)
  local pts = hillPoints(layer)
  lg.setColor(color)
  gfx.fillRidge(pts, 720)
  -- cartoon "rim light": a lighter band just under the outline
  lg.setColor(shade)
  lg.setLineWidth(10)
  local inner = {}
  for i = 1, #pts, 2 do inner[i], inner[i + 1] = pts[i], pts[i + 1] + 9 end
  lg.line(inner)
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  lg.line(pts)
end

function S:drawTree(x)
  local gy = hillY(x, 1) + 12
  outlinedPoly({ x - 22, gy, x - 14, gy - 150, x + 14, gy - 150, x + 24, gy }, { gfx.hex("#9b5d33") })
  local leaves = {
    { x - 70, gy - 170, 52 }, { x, gy - 215, 70 }, { x + 72, gy - 168, 54 },
    { x - 30, gy - 140, 46 }, { x + 34, gy - 138, 46 },
  }
  outlinedCircles(leaves, { gfx.hex("#43b649") })
  lg.setColor(gfx.hex("#6fd96b"))
  lg.circle("fill", x - 20, gy - 240, 26)
  lg.circle("fill", x - 82, gy - 185, 18)
  for _, a in ipairs({ { x - 40, gy - 190 }, { x + 50, gy - 200 }, { x + 15, gy - 160 }, { x - 75, gy - 150 } }) do
    outlinedCircles({ { a[1], a[2], 9 } }, { gfx.hex("#ff4d4d") })
    lg.setColor(1, 1, 1, 0.8)
    lg.circle("fill", a[1] - 3, a[2] - 3, 2.5)
  end
end

function S:drawFlower(f)
  local gy = hillY(f.x, 2) + 8
  local sway = math.sin(self.t * 2 + f.phase) * 6
  local hx, hy = f.x + sway, gy - f.h
  lg.setColor(OUT)
  lg.setLineWidth(8)
  lg.line(f.x, gy, hx, hy)
  lg.setColor(gfx.hex("#3fa535"))
  lg.setLineWidth(4)
  lg.line(f.x, gy, hx, hy)
  local petals = {}
  for i = 0, 4 do
    local a = i / 5 * math.pi * 2 + self.t * 0.5
    petals[#petals + 1] = { hx + math.cos(a) * 11, hy + math.sin(a) * 11, 9 }
  end
  outlinedCircles(petals, f.color)
  outlinedCircles({ { hx, hy, 6 } }, { gfx.hex("#ffd23f") })
end

function S:drawBlob()
  local b = self.blob
  local gy = hillY(b.x, 2) + 6
  local R = 58
  -- Shadow shrinks as the blob rises.
  local k = 1 - b.h / 300
  lg.setColor(0.1, 0.25, 0.1, 0.35)
  lg.ellipse("fill", b.x, gy + 4, R * 1.1 * k * b.sx, 12 * k)

  lg.push()
  lg.translate(b.x, gy - b.h)
  lg.scale(b.sx, b.sy) -- squash & stretch around the feet
  lg.setColor(OUT)
  lg.ellipse("fill", 0, -R, R + LW, R + LW - 2)
  lg.setColor(gfx.hex("#ff7eb6"))
  lg.ellipse("fill", 0, -R, R, R - 2)
  lg.setColor(gfx.hex("#ff5d9e"))
  lg.ellipse("fill", 8, -R + 24, R * 0.8, R * 0.42)
  lg.setColor(gfx.hex("#ff7eb6"))
  lg.ellipse("fill", 0, -R + 4, R * 0.95, R * 0.75)
  lg.setColor(1, 1, 1, 0.85)
  lg.ellipse("fill", -26, -R - 30, 14, 9)

  -- Eyes follow the mouse.
  local mx, my = view.mouse()
  local dx, dy = mx - b.x, my - (gy - b.h - R)
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  dx, dy = dx / len * 6, dy / len * 6
  for _, ex in ipairs({ -20, 20 }) do
    if b.blink then
      lg.setColor(OUT)
      lg.setLineWidth(4)
      lg.line(ex - 10, -R - 8, ex + 10, -R - 8)
    else
      lg.setColor(OUT)
      lg.ellipse("fill", ex, -R - 10, 15, 19)
      lg.setColor(1, 1, 1)
      lg.ellipse("fill", ex, -R - 10, 11, 15)
      lg.setColor(OUT)
      lg.circle("fill", ex + dx, -R - 8 + dy, 6.5)
      lg.setColor(1, 1, 1)
      lg.circle("fill", ex + dx - 2, -R - 11 + dy, 2)
    end
  end
  lg.setColor(OUT)
  if b.airborne then
    lg.ellipse("fill", 0, -R + 16, 10, 12)
    lg.setColor(gfx.hex("#ff3d6e"))
    lg.ellipse("fill", 0, -R + 21, 6, 5)
  else
    lg.setLineWidth(4)
    lg.arc("line", "open", 0, -R + 6, 10, 0.4, math.pi - 0.4)
  end
  lg.setColor(gfx.hex("#ff3d6e", 0.6))
  lg.ellipse("fill", -38, -R + 6, 9, 6)
  lg.ellipse("fill", 38, -R + 6, 9, 6)
  lg.pop()
end

function S:drawBurst()
  local bu = self.burst
  if bu.alpha <= 0.01 or bu.scale <= 0.01 then return end
  lg.push()
  lg.translate(bu.x, bu.y)
  lg.rotate(bu.rot)
  lg.scale(bu.scale)
  local pts = draft:star(0, 0, 210, 140, 11, 0, false)
  lg.setColor(OUT[1], OUT[2], OUT[3], bu.alpha)
  lg.push()
  lg.scale(1.06)
  draft:polygon(pts, "fill")
  lg.pop()
  lg.setColor(1, 0.86, 0.25, bu.alpha)
  draft:polygon(pts, "fill")
  lg.setFont(S.font)
  gfx.outlinedText("BOING!", -72, -22, { 1, 0.36, 0.55, bu.alpha }, { OUT[1], OUT[2], OUT[3], bu.alpha }, 3)
  lg.pop()
end

function S:draw()
  S.font = S.font or lg.newFont(36)
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  self:drawSun()
  for _, c in ipairs(self.clouds) do drawCloud(c) end
  self:drawHill(1, { gfx.hex("#7ed957") }, { gfx.hex("#a6ec7f") })
  self:drawTree(250)
  -- bushes on the back hill
  outlinedCircles({ { 900, hillY(900, 1) + 10, 34 }, { 940, hillY(940, 1) - 2, 42 }, { 985, hillY(985, 1) + 12, 30 } }, { gfx.hex("#52c447") })
  self:drawHill(2, { gfx.hex("#58c23a") }, { gfx.hex("#7fdc5a") })
  -- foreground: grass tufts and pebbles (seeded so they never jump around)
  for i = 0, 22 do
    local x = 30 + i * 57 + gfx.hash(i) * 30
    local y = 625 + gfx.hash(i + 40) * 80
    if gfx.hash(i + 7) > 0.5 then
      local blades = { x - 12, y, x - 8, y - 22, x - 2, y, x + 2, y - 30, x + 7, y, x + 12, y - 20, x + 14, y }
      lg.setColor(gfx.hex("#3fa535"))
      draft:polygon(blades, "fill")
      lg.setColor(OUT)
      lg.setLineWidth(3)
      lg.line(blades)
    else
      lg.setColor(OUT)
      lg.ellipse("fill", x, y, 17, 11)
      lg.setColor(gfx.hex("#c9c3d9"))
      lg.ellipse("fill", x, y - 1, 14, 8)
      lg.setColor(1, 1, 1, 0.8)
      lg.ellipse("fill", x - 5, y - 4, 4, 2)
    end
  end
  for _, f in ipairs(self.flowers) do self:drawFlower(f) end
  for _, d in ipairs(self.dust) do
    lg.setColor(1, 1, 1, d.life * 1.6)
    lg.circle("fill", d.x, d.y, d.r)
  end
  self:drawBlob()
  self:drawBurst()
end

return S
