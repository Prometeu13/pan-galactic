-- HORROR, scene 2: a corridor, failing lights, and something at the far end.
--
-- One-point perspective, done by hand: a point (x, y, z) in the corridor lands on
-- screen at vanishingPoint + (x, y) * size / z. The corridor is cut into thin slices
-- along z, and each slice is shaded by the ceiling lamps near it. That's the whole
-- lighting model: brightness = sum of lamp intensity / distance. Lamps flicker on a
-- noise signal, so pools of light jump around on their own.
--
-- The scare is a state machine with three numbers: time until the next blackout, how
-- long it lasts, and how far away the figure is. Every blackout it moves closer. You
-- never see it move.

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local shack = require("shack")

local lg = love.graphics
local VX, VY = 640, 330          -- vanishing point
local HX, HY = 700, 470          -- half-size of the corridor's cross-section at z = 1
local ZFAR = 10
local STEP = 0.25

local S = {
  title = "Horror",
  subtitle = "Ward C, Night Shift",
  blurb = "A hospital corridor in one-point perspective with flickering lamps. Each blackout, the figure at the end is closer.",
  techniques = {
    "One-point perspective by hand: screen = vanishing point + (x, y) * size / z",
    "Corridor cut into z-slices; each slice lit by the ceiling lamps near it",
    "Lamp flicker from a noise signal; one tube is dying and buzzes on and off",
    "Blackout state machine: lights die, the figure jumps closer, lights return",
    "Glossy floor: each lamp leaves a stretched streak below itself",
    "Camera 'breathing' (slow sway) and a jolt when the lights come back",
  },
  libs = {
    "moonshine: film grain, chromatic aberration, vignette",
    "shack: camera sway and the jolt after each blackout",
  },
  genres = { "First-person horror / walking sims", "Escape rooms", "Psychological horror cutscenes", "Dungeon crawlers (grid corridors)" },
  controls = "click: force a blackout.",
  warmup = 2.4,
}

local function P(x, y, z) return VX + x * HX / z, VY + y * HY / z end

local LAMPS = { 1.6, 3.4, 5.2, 7.0, 8.8 }
-- doors: side (-1 left, 1 right), z start, z end
local DOORS = {
  { -1, 1.9, 2.5 }, { 1, 2.6, 3.2 }, { -1, 3.9, 4.5, ajar = true }, { 1, 4.8, 5.4 },
  { -1, 6.0, 6.6 }, { 1, 7.0, 7.6 }, { -1, 8.0, 8.6 },
}

function S:load()
  self.t = 0
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.font = lg.newFont(13)
  self.fx = moonshine(1280, 720, moonshine.effects.filmgrain)
    .chain(moonshine.effects.chromasep)
    .chain(moonshine.effects.vignette)
  self.fx.filmgrain.opacity = 0.5
  self.fx.filmgrain.size = 2.5
  self.fx.chromasep.radius = 2
  self.fx.vignette.radius = 0.75
  self.fx.vignette.softness = 0.55
  self.fx.vignette.opacity = 0.85
  shack:setDimensions(1280, 720)
  self.intensity = { 1, 1, 1, 1, 1 }
  self.figureZ = 9.4
  self.stage = 1
  self.nextBlackout = 4.2
  self.blackout = 0
end

local STAGES = { 9.4, 7.3, 5.3, 3.5, 2.2 }

function S:mousepressed()
  if self.blackout <= 0 then self.nextBlackout = 0 end
end

function S:update(dt)
  self.t = self.t + dt
  shack:update(dt)
  local t = self.t
  if self.blackout > 0 then
    self.blackout = self.blackout - dt
    if self.blackout <= 0 then
      self.stage = self.stage % #STAGES + 1
      self.figureZ = STAGES[self.stage]
      shack:setShake(self.stage == 1 and 2 or 6 + self.stage * 2)
      self.nextBlackout = (self.stage == #STAGES) and 2.2 or 3.6
    end
  else
    self.nextBlackout = self.nextBlackout - dt
    if self.nextBlackout <= 0 then self.blackout = (self.stage == #STAGES) and 1.2 or 0.55 end
  end
  for i = 1, #LAMPS do
    local n = love.math.noise(t * 9 + i * 17.3)
    local v = 0.86 + n * 0.14
    if i == 3 then                                  -- the dying tube
      v = (love.math.noise(t * 3.1, 5) > 0.55) and (0.2 + n * 0.8) or 0.04
    end
    if i == 5 and love.math.noise(t * 1.7, 9) > 0.7 then v = 0.3 end
    -- just before a blackout the lamps stutter
    if self.blackout <= 0 and self.nextBlackout < 0.5 then v = v * ((math.floor(t * 22) % 2 == 0) and 1 or 0.2) end
    if self.blackout > 0 then v = 0 end
    self.intensity[i] = v
  end
end

-- brightness of the corridor at depth z
function S:lightAt(z)
  local sum = 0.035
  for i, lz in ipairs(LAMPS) do
    local d = math.abs(z - lz)
    sum = sum + self.intensity[i] * 0.95 / (1 + d * d * 2.6)
  end
  return math.min(1, sum)
end

local function quad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  local a, b = P(x1, y1, z1)
  local c, d = P(x2, y2, z2)
  local e, f = P(x3, y3, z3)
  local g, h = P(x4, y4, z4)
  lg.polygon("fill", a, b, c, d, e, f, g, h)
end

function S:drawCorridor()
  local t = self.t
  local WALL, WAIN, FLOOR_A, FLOOR_B, CEIL = gfx.rgb("#8d9a84"), gfx.rgb("#55655a"), gfx.rgb("#7a8076"), gfx.rgb("#4c5450"), gfx.rgb("#9a9c8e")
  for z = ZFAR - STEP, 0.75, -STEP do
    local z2 = z + STEP
    local L = self:lightAt(z + STEP / 2)
    local idx = math.floor(z / STEP + 0.5)
    -- ceiling
    lg.setColor(CEIL[1] * L, CEIL[2] * L, CEIL[3] * L)
    quad(-1, -1, z, 1, -1, z, 1, -1, z2, -1, -1, z2)
    -- walls: upper part, dado rail, wainscot
    for _, s in ipairs({ -1, 1 }) do
      local stain = 0.85 + 0.15 * gfx.hash(idx * 3.7 + s)
      lg.setColor(WALL[1] * L * stain, WALL[2] * L * stain, WALL[3] * L * stain)
      quad(s, -1, z, s, 0.3, z, s, 0.3, z2, s, -1, z2)
      lg.setColor(WAIN[1] * L, WAIN[2] * L, WAIN[3] * L)
      quad(s, 0.3, z, s, 1, z, s, 1, z2, s, 0.3, z2)
      lg.setColor(0.9 * L, 0.9 * L, 0.82 * L)
      quad(s, 0.27, z, s, 0.33, z, s, 0.33, z2, s, 0.27, z2)
      -- damp patches creeping down from the ceiling
      if gfx.hash(idx * 9.1 + s * 4) > 0.72 then
        lg.setColor(0.16 * L, 0.2 * L, 0.14 * L, 0.3)
        quad(s, -1, z, s, -1 + 0.5 * gfx.hash(idx + s), z, s, -1 + 0.3 * gfx.hash(idx * 2 + s), z2, s, -1, z2)
      end
    end
    -- floor: checker tiles, four across
    for c = 0, 3 do
      local x1, x2 = -1 + c * 0.5, -0.5 + c * 0.5
      local col = ((idx + c) % 2 == 0) and FLOOR_A or FLOOR_B
      lg.setColor(col[1] * L, col[2] * L, col[3] * L)
      quad(x1, 1, z, x2, 1, z, x2, 1, z2, x1, 1, z2)
    end
  end
  -- glossy streaks under the lamps
  lg.setBlendMode("add")
  for i, lz in ipairs(LAMPS) do
    local I = self.intensity[i]
    if I > 0.05 and lz > 0.9 then
      local x, y = P(0, 1, lz)
      local s = 1 / lz
      lg.setColor(0.8, 0.95, 0.85, 0.35 * I)
      lg.draw(self.glow, x, y + 30 * s, 0, 5.5 * s, 2.2 * s, 64, 64)
    end
  end
  lg.setBlendMode("alpha")
end

function S:drawDoors()
  local t = self.t
  for i = #DOORS, 1, -1 do
    local d = DOORS[i]
    local s, z1, z2 = d[1], d[2], d[3]
    local L = self:lightAt((z1 + z2) / 2)
    -- frame
    lg.setColor(0.22 * L, 0.24 * L, 0.2 * L)
    quad(s, -0.42, z1 - 0.05, s, 1, z1 - 0.05, s, 1, z2 + 0.05, s, -0.42, z2 + 0.05)
    if d.ajar then
      -- a door standing open into the corridor, sick green light behind it
      local flick = 0.7 + 0.3 * love.math.noise(t * 5)
      lg.setColor(0.35 * flick, 0.6 * flick, 0.3 * flick)
      quad(s, -0.36, z1, s, 1, z1, s, 1, z2, s, -0.36, z2)
      lg.setColor(0.12 * L + 0.03, 0.15 * L + 0.04, 0.12 * L + 0.03)
      quad(s, -0.36, z2, s, 1, z2, s * 0.62, 1, z2 - 0.18, s * 0.62, -0.36, z2 - 0.18)
      -- light spilling across the floor
      lg.setBlendMode("add")
      lg.setColor(0.3, 0.7, 0.3, 0.3 * flick)
      quad(s, 1, z1, s, 1, z2, -s * 0.3, 1, z2 + 0.5, -s * 0.3, 1, z1 - 0.3)
      lg.setBlendMode("alpha")
      -- and a long thin shadow lying in that light
      lg.setColor(0, 0, 0, 0.7)
      quad(s, 1, z1 + 0.22, s, 1, z1 + 0.34, -s * 0.1, 1, z1 + 0.44, -s * 0.1, 1, z1 + 0.36)
    else
      lg.setColor(0.36 * L, 0.33 * L, 0.26 * L)
      quad(s, -0.36, z1, s, 1, z1, s, 1, z2, s, -0.36, z2)
      -- window slot and number plate
      lg.setColor(0.03, 0.04, 0.04)
      quad(s, -0.24, z1 + 0.14, s, 0.02, z1 + 0.14, s, 0.02, z1 + 0.34, s, -0.24, z1 + 0.34)
      lg.setColor(0.75 * L, 0.72 * L, 0.6 * L)
      quad(s, -0.33, z1 + 0.18, s, -0.28, z1 + 0.18, s, -0.28, z1 + 0.3, s, -0.33, z1 + 0.3)
      lg.setColor(0.6 * L, 0.6 * L, 0.55 * L)
      quad(s, 0.36, z2 - 0.1, s, 0.42, z2 - 0.1, s, 0.42, z2 - 0.04, s, 0.36, z2 - 0.04)
    end
  end
  -- handprints dragged along the left wall
  for k = 0, 4 do
    local z = 2.75 + k * 0.16
    local L = self:lightAt(z)
    lg.setColor(0.32 * L, 0.05 * L, 0.04 * L, 0.85)
    quad(-1, 0.02 + k * 0.035, z, -1, 0.14 + k * 0.035, z, -1, 0.15 + k * 0.035, z + 0.12, -1, 0.04 + k * 0.035, z + 0.12)
  end
  -- a gurney left against the right wall
  local gz = 3.55
  local L = self:lightAt(gz)
  lg.setColor(0.6 * L, 0.62 * L, 0.6 * L)
  quad(0.55, 0.52, gz, 0.98, 0.52, gz, 0.98, 0.52, gz + 0.95, 0.55, 0.52, gz + 0.95)
  lg.setColor(0.75 * L, 0.76 * L, 0.72 * L)
  quad(0.55, 0.52, gz, 0.98, 0.52, gz, 0.98, 0.6, gz, 0.55, 0.6, gz)
  lg.setColor(0.4 * L, 0.42 * L, 0.4 * L)
  quad(0.55, 0.52, gz, 0.55, 0.6, gz, 0.55, 0.6, gz + 0.95, 0.55, 0.52, gz + 0.95)
  lg.setColor(0.12 * L, 0.12 * L, 0.12 * L)
  lg.setLineWidth(4 / gz * 3)
  for _, c in ipairs({ { 0.58, gz + 0.05 }, { 0.95, gz + 0.05 }, { 0.58, gz + 0.9 } }) do
    local x1, y1 = P(c[1], 0.6, c[2])
    local x2, y2 = P(c[1], 1, c[2])
    lg.line(x1, y1, x2, y2)
  end
  -- a sheet hanging off it
  lg.setColor(0.7 * L, 0.72 * L, 0.68 * L)
  quad(0.55, 0.52, gz + 0.2, 0.55, 0.52, gz + 0.8, 0.55, 0.86, gz + 0.7, 0.55, 0.8, gz + 0.3)
end

function S:drawEnd()
  local t = self.t
  local L = self:lightAt(ZFAR)
  local x1, y1 = P(-1, -1, ZFAR)
  local x2, y2 = P(1, 1, ZFAR)
  lg.setColor(0.3 * L, 0.34 * L, 0.3 * L)
  lg.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
  -- double doors with round windows
  local dx1, dy1 = P(-0.6, -0.5, ZFAR)
  local dx2, dy2 = P(0.6, 1, ZFAR)
  lg.setColor(0.2 * L + 0.01, 0.22 * L + 0.01, 0.2 * L + 0.01)
  lg.rectangle("fill", dx1, dy1, dx2 - dx1, dy2 - dy1)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", (dx1 + dx2) / 2 - 1, dy1, 2, dy2 - dy1)
  lg.circle("fill", (dx1 * 3 + dx2) / 4, dy1 + 26, 9)
  lg.circle("fill", (dx1 + dx2 * 3) / 4, dy1 + 26, 9)
  -- EXIT sign: the only thing that never goes out
  local ex, ey = P(0, -0.66, ZFAR)
  lg.setColor(0.9, 0.1, 0.08)
  lg.rectangle("fill", ex - 20, ey - 7, 40, 14, 2)
  lg.setFont(self.font)
  lg.setColor(1, 0.85, 0.8)
  lg.printf("EXIT", ex - 20, ey - 8, 40, "center")
  lg.setBlendMode("add")
  lg.setColor(1, 0.1, 0.05, 0.5)
  lg.draw(self.glow, ex, ey, 0, 1.6, 1.2, 64, 64)
  lg.setBlendMode("alpha")
end

function S:drawLamps()
  for i = #LAMPS, 1, -1 do
    local lz = LAMPS[i]
    local I = self.intensity[i]
    local x1, y1 = P(-0.3, -0.985, lz - 0.16)
    local x2, y2 = P(0.3, -0.985, lz - 0.16)
    local x3, y3 = P(0.3, -0.985, lz + 0.16)
    local x4, y4 = P(-0.3, -0.985, lz + 0.16)
    lg.setColor(0.15 + 0.85 * I, 0.16 + 0.84 * I, 0.14 + 0.78 * I)
    lg.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
    if I > 0.05 then
      lg.setBlendMode("add")
      local s = 1 / lz
      lg.setColor(0.85, 1, 0.85, 0.5 * I)
      lg.draw(self.glow, (x1 + x2) / 2, (y1 + y4) / 2, 0, 6 * s, 3 * s, 64, 64)
      lg.setBlendMode("alpha")
    end
  end
end

-- The figure: too tall, arms too long, head tilted. All sizes are in corridor units.
function S:drawFigure()
  local t = self.t
  local z = self.figureZ
  local fx, fy = P(0.08, 1, z)
  local u = HY / z                      -- one corridor unit of height, in pixels
  local sway = math.sin(t * 0.9) * 0.02 * u
  local ink = { 0.012, 0.012, 0.014 }
  lg.setColor(ink)
  -- legs
  lg.polygon("fill", fx - 0.07 * u, fy, fx - 0.03 * u, fy, fx + 0.0 * u + sway, fy - 0.72 * u, fx - 0.06 * u + sway, fy - 0.72 * u)
  lg.polygon("fill", fx + 0.03 * u, fy, fx + 0.07 * u, fy, fx + 0.06 * u + sway, fy - 0.72 * u, fx + 0.0 * u + sway, fy - 0.72 * u)
  -- torso in a hospital gown
  lg.polygon("fill", fx - 0.1 * u + sway, fy - 0.62 * u, fx + 0.1 * u + sway, fy - 0.62 * u, fx + 0.085 * u + sway * 1.5, fy - 1.3 * u, fx - 0.085 * u + sway * 1.5, fy - 1.3 * u)
  -- arms that reach almost to the knees
  lg.setLineWidth(math.max(1.5, 0.035 * u))
  lg.line(fx - 0.085 * u + sway * 1.5, fy - 1.27 * u, fx - 0.15 * u + sway, fy - 0.85 * u, fx - 0.13 * u + sway * 0.5, fy - 0.42 * u)
  lg.line(fx + 0.085 * u + sway * 1.5, fy - 1.27 * u, fx + 0.15 * u + sway, fy - 0.85 * u, fx + 0.14 * u + sway * 0.5, fy - 0.42 * u)
  -- neck and a head tilted too far
  local hx, hy = fx + sway * 1.8 + 0.035 * u, fy - 1.45 * u
  lg.polygon("fill", fx - 0.025 * u + sway * 1.5, fy - 1.3 * u, fx + 0.025 * u + sway * 1.5, fy - 1.3 * u, hx + 0.02 * u, hy, hx - 0.02 * u, hy)
  lg.push()
  lg.translate(hx, hy)
  lg.rotate(0.42 + math.sin(t * 0.6) * 0.05)
  lg.ellipse("fill", 0, -0.02 * u, 0.062 * u, 0.085 * u)
  -- stringy hair
  lg.setLineWidth(math.max(1, 0.012 * u))
  for k = -2, 2 do lg.line(k * 0.02 * u, -0.06 * u, k * 0.03 * u, 0.12 * u + math.abs(k) * 0.02 * u) end
  -- eyes: the only light it has
  local a = 0.5 + 0.5 * love.math.noise(t * 2)
  lg.setColor(0.95, 1, 0.9, 0.55 + 0.45 * a)
  lg.circle("fill", -0.022 * u, -0.03 * u, math.max(1, 0.0085 * u))
  lg.circle("fill", 0.022 * u, -0.03 * u, math.max(1, 0.0085 * u))
  lg.pop()
end

function S:draw()
  local t = self.t
  self.fx(function()
    lg.clear(0, 0, 0, 1)
    shack:apply()
    -- breathing: the whole view rocks a little
    lg.translate(640, 360)
    lg.rotate(math.sin(t * 0.7) * 0.012)
    lg.scale(1.03 + math.sin(t * 1.1) * 0.008)
    lg.translate(-640, -360 + math.sin(t * 1.1) * 5)
    self:drawCorridor()
    self:drawEnd()
    -- everything between the end wall and the camera, far to near
    self:drawDoors()
    self:drawFigure()
    self:drawLamps()
    -- dust drifting in the lamp light
    lg.setBlendMode("add")
    for k = 0, 40 do
      local z = 1.2 + gfx.hash(k) * 6
      local x = (gfx.hash(k + 50) - 0.5) * 1.6 + math.sin(t * 0.3 + k) * 0.05
      local y = -0.9 + ((gfx.hash(k + 90) + t * 0.02) % 1) * 1.6
      local px, py = P(x, y, z)
      lg.setColor(1, 1, 0.9, 0.35 * self:lightAt(z))
      lg.circle("fill", px, py, 2.4 / z)
    end
    lg.setBlendMode("alpha")
    lg.origin()
    -- during a blackout, the eyes stay
    if self.blackout > 0 then
      lg.setColor(0, 0, 0, 0.93)
      lg.rectangle("fill", 0, 0, 1280, 720)
    end
  end)
end

return S
