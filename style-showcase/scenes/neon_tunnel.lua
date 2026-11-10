-- NEON, scene 3: flying through a wireframe tunnel.
--
-- This is the oldest 3D trick there is: screen = centre + world * focal / z. A tunnel
-- is a stack of polygons ("rings") at increasing z; each ring's corners are projected
-- with that one formula. Moving forward = subtracting from z and wrapping, so a
-- handful of rings loop forever. Bending the tunnel = shifting far rings sideways by
-- an amount that grows with z squared. Colour comes from the ring's index run through
-- HSLuv, so the hue changes smoothly while brightness stays even.

local gfx = require("core.gfx")
local view = require("core.view")
local moonshine = require("moonshine")
local hsluv = require("hsluv")
local shack = require("shack")

local lg = love.graphics
local CX, CY = 640, 380
local FOCAL = 3.6
local RADIUS = 240
local SIDES = 8
local SPACING = 1.0
local RINGS = 42
local SHIP_Z = 2.1
local SPEED = 9

local S = {
  title = "Neon Synthwave",
  subtitle = "Hyperloop",
  blurb = "A wireframe tunnel flown at speed: rings projected by hand, a bending track, pickups, speed lines and a glowing ship.",
  techniques = {
    "Perspective by hand: screen = centre + world * focal / z, for every corner",
    "Endless tunnel: ring depths wrap around, so 42 rings loop forever",
    "Bends: far rings are shifted by an offset that grows with z squared",
    "Rainbow that stays even in brightness: hue stepped per ring through HSLuv",
    "Speed lines: short segments projected at two depths",
    "Pickups live in tunnel space (lane, depth) and are projected like the rings",
  },
  libs = {
    "hsluv: perceptually even rainbow for the rings",
    "moonshine: glow, chromasep, scanlines",
    "shack: a small zoom kick and shake on every pickup",
  },
  genres = { "Tunnel runners and rhythm racers", "Arcade shooters (into-the-screen)", "Bonus stages and warp sequences", "Music visualisers" },
  controls = "move the mouse left/right to steer the ship between the three lanes.",
  warmup = 2.6,
}

-- where the tunnel's centre line is at depth z (in world units), at time t
local function bend(z, t)
  local k = (z / (RINGS * SPACING)) ^ 2
  return math.sin(t * 0.5) * 520 * k + math.sin(t * 0.23 + 1) * 260 * k,
         math.cos(t * 0.37) * 300 * k
end

local function project(wx, wy, z, t)
  local bx, by = bend(z, t)
  local s = FOCAL / z
  return CX + (wx + bx) * s, CY + (wy + by) * s, s
end

local function ringColor(i, l)
  local r, g, b = unpack(hsluv.hsluv_to_rgb({ (i * 22) % 360, 100, l or 62 }))
  return r, g, b
end

function S:load()
  self.t = 0
  self.dist = 0
  self.glow = gfx.radialTexture(128, 2)
  self.font = lg.newFont(22)
  self.small = lg.newFont(13)
  self.big = lg.newFont(40)
  self.fx = moonshine(1280, 720, moonshine.effects.glow)
    .chain(moonshine.effects.chromasep)
    .chain(moonshine.effects.scanlines)
  self.fx.glow.min_luma = 0.3
  self.fx.glow.strength = 6
  self.fx.chromasep.radius = 2.5
  self.fx.scanlines.opacity = 0.18
  self.fx.scanlines.width = 2
  shack:setDimensions(1280, 720)
  love.math.setRandomSeed(21)
  self.streaks = {}
  for i = 1, 90 do
    self.streaks[i] = { a = love.math.random() * math.pi * 2, r = 0.55 + love.math.random() * 0.42, z = love.math.random() * RINGS * SPACING }
  end
  self.ship = { lane = 0, x = 0, roll = 0 }
  self.pickups = {}
  for i = 1, 7 do self.pickups[i] = { lane = love.math.random(-1, 1), z = 6 + i * 5.5 } end
  self.score = 0
  self.pops = {}
  self.mouseSeen = false
end

function S:update(dt)
  self.t = self.t + dt
  self.dist = self.dist + SPEED * dt
  shack:update(dt)
  for _, s in ipairs(self.streaks) do
    s.z = s.z - SPEED * 1.6 * dt
    if s.z < 0.6 then s.z = RINGS * SPACING end
  end
  -- steering: mouse if it moves, otherwise an autopilot that chases the next pickup
  local mx = view.mouse()
  if self.lastMx and mx ~= self.lastMx then self.mouseSeen = true end
  self.lastMx = mx
  local ship = self.ship
  local nearest
  for _, p in ipairs(self.pickups) do
    if not nearest or p.z < nearest.z then nearest = p end
  end
  local target
  if self.mouseSeen and mx then
    target = gfx.clamp((mx - 640) / 300, -1, 1)
  else
    target = nearest and nearest.lane or 0
  end
  local old = ship.x
  ship.x = ship.x + (target - ship.x) * math.min(1, dt * 5)
  ship.roll = gfx.lerp(ship.roll, (ship.x - old) / math.max(dt, 0.001) * 0.18, math.min(1, dt * 8))
  for _, p in ipairs(self.pickups) do
    p.z = p.z - SPEED * dt
    if p.z < SHIP_Z then
      if math.abs(p.lane - ship.x) < 0.45 then
        self.score = self.score + 100
        self.pops[#self.pops + 1] = { x = ship.x, life = 0 }
        shack:setScale(1.03)
        shack:setShake(6)
      end
      p.z = p.z + 7 * 5.5
      p.lane = love.math.random(-1, 1)
    end
  end
  for i = #self.pops, 1, -1 do
    self.pops[i].life = self.pops[i].life + dt
    if self.pops[i].life > 0.9 then table.remove(self.pops, i) end
  end
end

-- corner k of the ring at depth z
function S:corner(k, z, twist)
  local a = k / SIDES * math.pi * 2 + math.pi / SIDES + twist
  return project(math.cos(a) * RADIUS, math.sin(a) * RADIUS * 0.72, z, self.t)
end

function S:drawTunnel()
  local t = self.t
  local off = self.dist % SPACING
  local first = math.floor(self.dist / SPACING)
  local rings = {}
  for i = RINGS, 1, -1 do
    local z = i * SPACING - off
    if z > 0.9 then
      local idx = first + i
      local pts = {}
      for k = 0, SIDES - 1 do
        local x, y = self:corner(k, z, 0)
        pts[#pts + 1] = x
        pts[#pts + 1] = y
      end
      rings[#rings + 1] = { z = z, idx = idx, pts = pts }
    end
  end
  -- wall panels between consecutive rings (far to near): floor brighter than ceiling
  for r = 1, #rings - 1 do
    local A, B = rings[r], rings[r + 1]
    local fade = gfx.clamp(1 - A.z / (RINGS * SPACING), 0, 1)
    local cr, cg, cb = ringColor(A.idx, 30)
    for k = 0, SIDES - 1 do
      local k2 = (k + 1) % SIDES
      local floorish = (k == 1 or k == 2)
      local lit = ((A.idx + k) % 2 == 0)
      local a = (floorish and 0.6 or 0.22) * fade * (lit and 1 or 0.4)
      lg.setColor(cr, cg, cb, a)
      lg.polygon("fill", A.pts[k * 2 + 1], A.pts[k * 2 + 2], A.pts[k2 * 2 + 1], A.pts[k2 * 2 + 2],
        B.pts[k2 * 2 + 1], B.pts[k2 * 2 + 2], B.pts[k * 2 + 1], B.pts[k * 2 + 2])
    end
  end
  -- rails: lines along the tunnel through each corner
  for k = 0, SIDES - 1 do
    local line = {}
    for r = 1, #rings do
      line[#line + 1] = rings[r].pts[k * 2 + 1]
      line[#line + 1] = rings[r].pts[k * 2 + 2]
    end
    if #line >= 4 then
      lg.setColor(0.4, 0.8, 1, 0.1)
      lg.setLineWidth(5)
      lg.line(line)
      lg.setColor(0.6, 0.9, 1, 0.5)
      lg.setLineWidth(1.2)
      lg.line(line)
    end
  end
  -- the rings themselves
  for r = 1, #rings do
    local R = rings[r]
    local fade = gfx.clamp(1.15 - R.z / (RINGS * SPACING), 0, 1)
    local cr, cg, cb = ringColor(R.idx)
    local w = gfx.clamp(FOCAL / R.z * 2.2, 1, 7)
    local beat = (R.idx % 4 == 0) and 1 or 0.6
    lg.setColor(cr, cg, cb, 0.2 * fade * beat)
    lg.setLineWidth(w * 4)
    lg.polygon("line", R.pts)
    lg.setColor(cr, cg, cb, fade * beat)
    lg.setLineWidth(w)
    lg.polygon("line", R.pts)
    lg.setColor(1, 1, 1, 0.7 * fade * beat)
    lg.setLineWidth(math.max(1, w * 0.3))
    lg.polygon("line", R.pts)
  end
end

-- lane (-1..1) -> world position on the tunnel floor
local function lanePos(lane) return lane * 105, RADIUS * 0.72 * 0.86 end

function S:drawPickups()
  local t = self.t
  table.sort(self.pickups, function(a, b) return a.z > b.z end)
  for _, p in ipairs(self.pickups) do
    if p.z > 1 and p.z < RINGS * SPACING * 0.8 then
      local wx, wy = lanePos(p.lane)
      local x, y, s = project(wx, wy - 46, p.z, t)
      local r = 30 * s
      local squash = math.abs(math.cos(t * 3 + p.z))
      lg.setBlendMode("add")
      lg.setColor(1, 0.9, 0.3, 0.5)
      lg.draw(self.glow, x, y, 0, r / 22, r / 22, 64, 64)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.85, 0.25)
      lg.polygon("fill", x, y - r, x + r * 0.7 * squash, y, x, y + r, x - r * 0.7 * squash, y)
      lg.setColor(1, 1, 0.85)
      lg.polygon("fill", x, y - r, x + r * 0.7 * squash, y, x, y - r * 0.2, x - r * 0.25 * squash, y - r * 0.3)
    end
  end
end

function S:drawShip()
  local t = self.t
  local ship = self.ship
  local wx, wy = lanePos(ship.x)
  local x, y = project(wx, wy - 30, SHIP_Z, t)
  lg.push()
  lg.translate(x, y + math.sin(t * 6) * 3)
  lg.rotate(gfx.clamp(ship.roll, -0.5, 0.5))
  -- engine glow and exhaust
  lg.setBlendMode("add")
  for _, ex in ipairs({ -38, 38 }) do
    lg.setColor(0.3, 0.9, 1, 0.9)
    lg.draw(self.glow, ex, 14, 0, 0.9, 0.9 + 0.2 * math.sin(t * 40), 64, 64)
    lg.setColor(1, 1, 1, 0.9)
    lg.ellipse("fill", ex, 14, 13, 7)
  end
  lg.setBlendMode("alpha")
  -- rear view of a wedge-shaped racer: dark body, neon edges
  local body = { -96, 16, -52, -8, -22, -30, 22, -30, 52, -8, 96, 16, 60, 26, -60, 26 }
  lg.setColor(0.04, 0.02, 0.1)
  lg.polygon("fill", body)
  lg.setColor(0.1, 0.06, 0.24)
  lg.polygon("fill", -22, -30, 22, -30, 34, -6, -34, -6)
  lg.setColor(0.3, 0.9, 1, 0.5)
  lg.polygon("fill", -16, -26, 16, -26, 24, -10, -24, -10)
  lg.setColor(1, 0.2, 0.7, 0.25)
  lg.setLineWidth(9)
  lg.polygon("line", body)
  lg.setColor(1, 0.3, 0.75)
  lg.setLineWidth(2.5)
  lg.polygon("line", body)
  -- tail fins and tail lights
  lg.setColor(0.04, 0.02, 0.1)
  lg.polygon("fill", -70, 2, -62, -30, -52, -4)
  lg.polygon("fill", 70, 2, 62, -30, 52, -4)
  lg.setColor(1, 0.3, 0.75)
  lg.setLineWidth(2)
  lg.line(-70, 2, -62, -30, -52, -4)
  lg.line(70, 2, 62, -30, 52, -4)
  lg.setColor(1, 0.2, 0.2)
  lg.rectangle("fill", -90, 12, 22, 5)
  lg.rectangle("fill", 68, 12, 22, 5)
  lg.pop()
  -- "+100" pops
  for _, p in ipairs(self.pops) do
    local px = project(p.x * 105, 0, SHIP_Z, t)
    lg.setFont(self.big)
    gfx.outlinedText("+100", px - 100, y - 90 - p.life * 80, { 1, 0.95, 0.4, 1 - p.life / 0.9 }, { 0.2, 0, 0.3, 1 - p.life / 0.9 }, 2, 200, "center")
  end
end

function S:draw()
  local t = self.t
  self.fx(function()
    lg.clear(0.02, 0.005, 0.06, 1)
    shack:apply()
    -- the light at the end of the tunnel
    local ex, ey = project(0, 0, RINGS * SPACING, t)
    lg.setBlendMode("add")
    lg.setColor(1, 0.5, 0.9, 0.9)
    lg.draw(self.glow, ex, ey, 0, 1.6, 1.6, 64, 64)
    lg.setColor(1, 1, 1, 0.9)
    lg.draw(self.glow, ex, ey, 0, 0.5, 0.5, 64, 64)
    lg.setBlendMode("alpha")
    self:drawTunnel()
    -- speed lines
    lg.setLineWidth(1.5)
    for _, s in ipairs(self.streaks) do
      local wx, wy = math.cos(s.a) * RADIUS * s.r, math.sin(s.a) * RADIUS * 0.72 * s.r
      local x1, y1 = project(wx, wy, s.z, t)
      local x2, y2 = project(wx, wy, s.z + 0.5, t)
      lg.setColor(1, 1, 1, gfx.clamp(1.2 - s.z / 20, 0, 0.7))
      lg.line(x1, y1, x2, y2)
    end
    self:drawPickups()
    self:drawShip()
    lg.origin()
    -- HUD
    lg.setFont(self.small)
    lg.setColor(0.4, 0.95, 1, 0.8)
    lg.print("SCORE", 40, 34)
    lg.print("SPEED", 1140, 34)
    lg.setFont(self.font)
    lg.setColor(1, 1, 1)
    lg.print(string.format("%06d", self.score + math.floor(self.dist) * 3), 40, 50)
    lg.printf(string.format("%d km/h", 840 + math.floor(math.sin(t * 2) * 12)), 1040, 50, 200, "right")
    -- speed bar made of segments
    for k = 0, 19 do
      local on = k < 15 + math.floor(math.sin(t * 2) * 2)
      local r, g, b = ringColor(k * 2 + 6)
      lg.setColor(r, g, b, on and 1 or 0.18)
      lg.polygon("fill", 1040 + k * 10, 96, 1047 + k * 10, 96, 1050 + k * 10, 84 - k * 0.7, 1043 + k * 10, 84 - k * 0.7)
    end
    -- lane indicator
    for k = -1, 1 do
      local on = math.abs(self.ship.x - k) < 0.5
      lg.setColor(1, 0.3, 0.75, on and 1 or 0.25)
      lg.rectangle("fill", 640 + k * 44 - 16, 676, 32, 5, 2)
    end
  end)
end

return S
