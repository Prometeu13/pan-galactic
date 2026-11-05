-- NEON / SYNTHWAVE: glowing lines on black, a striped sun, a CRT screen.
--
-- Neon is "thin bright line + wide dim copy of the same line": draw every line twice
-- (once 8px wide at low alpha, once 2px at full), then let a bloom pass spread it.
-- The infinite floor grid is a perspective projection: y = horizon + f*h/z. Scrolling
-- is just moving z, wrapped by the grid spacing, so it loops forever.
-- The whole frame pulses on a 125 BPM beat using shack (screen scale/shake helper).

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local shack = require("shack")

local lg = love.graphics
local HZ = 400                   -- horizon line
local BEAT = 60 / 125

local S = {
  title = "Neon Synthwave",
  subtitle = "Midnight Drive",
  blurb = "Retro-futurist vector look: glowing lines, a perspective grid scrolling to infinity, chrome text and a CRT screen.",
  techniques = {
    "Every neon line drawn twice: wide + dim, then thin + bright",
    "Floor grid = 3D perspective projection done by hand (y = horizon + f*h/z)",
    "Striped sun: one 1px row at a time, with gaps that widen toward the bottom",
    "Chrome title: a tiny shader that paints text with a vertical gradient",
    "Post chain: glow -> chromatic aberration -> scanlines -> CRT curvature",
  },
  libs = {
    "moonshine: glow, chromasep, scanlines and crt",
    "shack: beat-synced zoom pulse and camera shake",
  },
  genres = { "Arcade racers and endless runners", "Rhythm games", "Twin-stick / vector shooters", "Cyberpunk menus and HUDs" },
  warmup = 2,
}

local CHROME = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float a = Texel(tex, uv).a;
  float t = clamp((sc.y - 40.0) / 70.0, 0.0, 1.0);
  vec3 top = vec3(0.75, 0.95, 1.0);
  vec3 mid = vec3(0.15, 0.25, 0.65);
  vec3 low = vec3(1.0, 0.55, 0.85);
  vec3 col = t < 0.55 ? mix(top, mid, t / 0.55) : mix(vec3(0.95, 0.85, 1.0), low, (t - 0.55) / 0.45);
  return vec4(col, a * color.a);
}
]]

local function neonLine(r, g, b, a, w, ...)
  lg.setColor(r, g, b, 0.18 * a)
  lg.setLineWidth(w * 4)
  lg.line(...)
  lg.setColor(r, g, b, a)
  lg.setLineWidth(w)
  lg.line(...)
end

local function palm(x, y, h, lean, t)
  lg.setColor(0.02, 0, 0.05)
  local curve = love.math.newBezierCurve(x, y, x + lean * 0.3, y - h * 0.5, x + lean, y - h)
  lg.setLineWidth(14)
  lg.line(curve:render(4))
  local tx, ty = x + lean, y - h
  for i = 0, 6 do
    local a = -math.pi / 2 + (i - 3) * 0.5 + math.sin(t * 0.8 + i) * 0.04
    local len = 130 + (i % 2) * 30
    local ex, ey = tx + math.cos(a) * len, ty + math.sin(a) * len * 0.5 + len * 0.35
    local mx, my = tx + math.cos(a) * len * 0.5, ty + math.sin(a) * len * 0.6 - 10
    local leaf = love.math.newBezierCurve(tx, ty, mx, my, ex, ey):render(4)
    lg.setLineWidth(9)
    lg.line(leaf)
  end
end

function S:load()
  self.t = 0
  self.sky = gfx.vgradient(1280, HZ, {
    { 0, gfx.rgb("#05010f") }, { 0.55, gfx.rgb("#250842") }, { 1, gfx.rgb("#8a1f6e") },
  })
  self.floor = gfx.vgradient(1280, 720 - HZ, {
    { 0, gfx.rgb("#2a0636") }, { 1, gfx.rgb("#05010a") },
  })
  self.glow = gfx.radialTexture(128, 2)
  self.chrome = lg.newShader(CHROME)
  self.titleFont = lg.newFont(78)
  self.small = lg.newFont(16)
  love.math.setRandomSeed(80)
  self.stars = {}
  for i = 1, 120 do self.stars[i] = { love.math.random(0, 1280), love.math.random(0, HZ - 60), love.math.random() * 6 } end

  local function ridge(x0, x1, peak, seed)
    local pts = {}
    for i = 0, 14 do
      local x = x0 + (x1 - x0) * i / 14
      local m = 1 - math.abs(i / 14 * 2 - 1)
      pts[#pts + 1] = { x, HZ - (m ^ 0.8) * peak * (0.6 + 0.4 * gfx.hash(i + seed)) }
    end
    return pts
  end
  self.mountains = { ridge(-60, 520, 210, 1), ridge(760, 1340, 190, 9), ridge(380, 900, 55, 4) }

  self.fx = moonshine(1280, 720, moonshine.effects.glow)
    .chain(moonshine.effects.chromasep)
    .chain(moonshine.effects.scanlines)
    .chain(moonshine.effects.crt)
  self.fx.glow.min_luma = 0.35
  self.fx.glow.strength = 5
  self.fx.chromasep.radius = 2
  self.fx.scanlines.opacity = 0.25
  self.fx.scanlines.width = 2
  self.fx.crt.distortionFactor = { 1.03, 1.04 }

  shack:setDimensions(1280, 720)
  self.nextBeat = BEAT
end

function S:update(dt)
  self.t = self.t + dt
  if self.t >= self.nextBeat then
    self.nextBeat = self.nextBeat + BEAT
    shack:setScale(1.018)   -- kick: jump to 1.8% zoom, shack eases it back to 1
    shack:setShake(2)
  end
  shack:update(dt)
end

function S:drawSun()
  local cx, cy, r = 640, 270, 160
  local top, bottom = { gfx.hex("#ffe45c") }, { gfx.hex("#ff2a8a") }
  lg.setBlendMode("add")
  lg.setColor(1, 0.3, 0.6, 0.45)
  lg.draw(self.glow, cx, cy, 0, 4.2, 4.2, 64, 64)
  lg.setBlendMode("alpha")
  for y = -r, r do
    local t = (y + r) / (2 * r)
    -- cut bands: below the middle, every 18px there's a gap that grows with depth
    local cut = false
    if t > 0.45 then
      local band = (y + r) % 18
      cut = band < (t - 0.45) * 22
    end
    if not cut then
      local hw = math.sqrt(r * r - y * y)
      lg.setColor(gfx.mix(top, bottom, t))
      lg.rectangle("fill", cx - hw, cy + y, hw * 2, 1)
    end
  end
end

function S:drawMountains()
  for k, m in ipairs(self.mountains) do
    local pts = {}
    for _, p in ipairs(m) do pts[#pts + 1] = p[1]; pts[#pts + 1] = p[2] end
    lg.setColor(gfx.hex(k == 3 and "#1a0630" or "#12041f"))
    gfx.fillRidge(pts, HZ)
    local c = (k == 3) and { 0.3, 0.9, 1 } or { 1, 0.25, 0.85 }
    -- wireframe: from each vertex, a line down to the base
    for i, p in ipairs(m) do
      if i % 2 == 0 then
        lg.setColor(c[1], c[2], c[3], 0.35)
        lg.setLineWidth(1)
        lg.line(p[1], p[2], p[1] + (p[1] - 640) * 0.05, HZ)
      end
    end
    neonLine(c[1], c[2], c[3], 0.95, 2, pts)
  end
end

function S:drawGrid()
  lg.setColor(1, 1, 1)
  lg.draw(self.floor, 0, HZ)
  local f, h = 320, 1
  local phase = (self.t * 6) % 1
  for i = 0, 40 do
    local z = (i + 1 - phase) * 0.5 + 0.3
    local y = HZ + f * h / z
    if y <= 730 then
      local a = gfx.clamp((y - HZ) / 120, 0.08, 1)
      neonLine(1, 0.2, 0.85, a, 2, 0, y, 1280, y)
    end
  end
  for x = -24, 24 do
    local x1 = 640 + f * x / 0.3
    local x2 = 640 + f * x / 40
    neonLine(1, 0.2, 0.85, 0.8, 2, x2, HZ + 8, x1, HZ + f * h / 0.3)
  end
  -- horizon line glows hottest
  neonLine(1, 0.6, 0.9, 1, 3, 0, HZ, 1280, HZ)
end

function S:drawCar()
  local x, y = 640, 618 + math.sin(self.t * 30) * 0.8
  lg.push()
  lg.translate(x, y)
  -- shadow and wheels
  lg.setColor(0, 0, 0, 0.6)
  lg.ellipse("fill", 0, 78, 200, 16)
  lg.setColor(0.03, 0.02, 0.05)
  lg.rectangle("fill", -170, 40, 52, 40, 8)
  lg.rectangle("fill", 118, 40, 52, 40, 8)
  -- body
  lg.setColor(gfx.hex("#140a24"))
  lg.polygon("fill", -185, 50, -175, 0, 175, 0, 185, 50)
  lg.polygon("fill", -120, 0, -90, -52, 90, -52, 120, 0)
  lg.setColor(gfx.hex("#2b1650"))
  lg.polygon("fill", -100, -4, -78, -44, 78, -44, 100, -4)
  neonLine(0.3, 0.9, 1, 0.9, 2, -185, 50, -175, 0, -120, 0, -90, -52, 90, -52, 120, 0, 175, 0, 185, 50, -185, 50)
  -- tail-light bar
  lg.setBlendMode("add")
  lg.setColor(1, 0.1, 0.3, 0.6)
  lg.draw(self.glow, 0, 22, 0, 3.4, 0.5, 64, 64)
  lg.setBlendMode("alpha")
  lg.setColor(1, 0.25, 0.4)
  lg.rectangle("fill", -168, 14, 336, 14, 4)
  lg.setColor(1, 0.85, 0.9)
  lg.rectangle("fill", -164, 18, 336 - 8, 4, 2)
  -- plate
  lg.setColor(0.9, 0.9, 1)
  lg.rectangle("fill", -42, 32, 84, 18, 3)
  lg.setFont(self.small)
  lg.setColor(0.1, 0.05, 0.2)
  lg.printf("LÖVE 11", -42, 32, 84, "center")
  lg.pop()
end

function S:draw()
  self.fx(function()
    lg.push()
    shack:apply()
    lg.setColor(1, 1, 1)
    lg.draw(self.sky)
    for _, s in ipairs(self.stars) do
      lg.setColor(1, 0.85, 1, 0.3 + 0.3 * math.sin(self.t * 2 + s[3]))
      lg.circle("fill", s[1], s[2], 1.1)
    end
    self:drawSun()
    self:drawMountains()
    self:drawGrid()
    palm(90, 720, 330, 60, self.t)
    palm(200, 720, 230, -30, self.t + 1)
    palm(1170, 720, 340, -70, self.t + 2)
    self:drawCar()

    lg.setFont(self.titleFont)
    local title = "MIDNIGHT DRIVE"
    local w = self.titleFont:getWidth(title)
    lg.setColor(1, 0.2, 0.75, 0.9)
    for dx = -3, 3, 3 do
      for dy = -3, 3, 3 do lg.print(title, 640 - w / 2 + dx, 34 + dy) end
    end
    lg.setShader(self.chrome)
    lg.setColor(1, 1, 1)
    lg.print(title, 640 - w / 2, 34)
    lg.setShader()
    lg.pop()
  end)
end

return S
