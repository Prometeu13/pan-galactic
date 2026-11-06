-- UNDERWATER: a bioluminescent reef.
--
-- Underwater = light from above + glow from below:
--   * shafts of light from the surface: additive gradient wedges that sway slowly
--   * caustics on the sand: a shader where two moving noise fields cross; bright
--     thin lines appear wherever their sum is close to 1 (pow makes them sharp)
--   * colour falls off with depth: reds vanish first, everything drifts toward blue
--   * the reef glows: coral tips, jellyfish and plankton are additive blooms
-- The fish school is a boids simulation (separation, alignment, cohesion), written
-- with brinevector's 2D vectors.

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local Vector = require("brinevector")

local lg = love.graphics
local FLOOR = 600

local S = {
  title = "Underwater",
  subtitle = "Bioluminescent Reef",
  blurb = "Light shafts from the surface, caustics rippling on the sand, glowing coral and jellyfish, and a fish school driven by boids.",
  techniques = {
    "Light shafts: additive gradient wedges swaying from the surface",
    "Caustics shader: two drifting noise fields; bright where their sum is near 1",
    "Branching coral from a recursive function, glowing tips via additive blending",
    "Jellyfish: bell squashes with a pulse; tentacles trail with a phase delay",
    "Boids: separation + alignment + cohesion + a gentle pull toward the centre",
  },
  libs = {
    "brinevector: 2D vectors for the boids (fast, LuaJIT FFI based)",
    "moonshine: glow (bloom) and a deep-blue vignette",
  },
  genres = { "Ocean exploration and diving games", "Aquarium / creature-collecting sims", "Relaxing ambient games", "Bullet-hell or shmups with an organic theme" },
  warmup = 4,
}

local CAUSTICS = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
uniform float time;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 p = sc * vec2(0.012, 0.03);
  float a = vnoise(p * 1.0 + vec2(time * 0.25, time * 0.1));
  float b = vnoise(p * 1.3 - vec2(time * 0.18, -time * 0.07) + 4.0);
  // thin bright lines where the two fields are equal (the zero contour of a - b)
  float c = pow(1.0 - clamp(abs(a - b) * 7.0, 0.0, 1.0), 3.0);
  float depthFade = 1.0 - uv.y * 0.6;
  vec3 sand = mix(vec3(0.32, 0.34, 0.32), vec3(0.10, 0.16, 0.22), uv.y);
  vec3 col = sand + vec3(0.45, 0.8, 0.85) * c * depthFade * 0.8;
  float top = smoothstep(0.0, 0.25, uv.y);          // blend into the water at the top edge
  return vec4(col, top);
}
]]

local function growCoral(list, x, y, angle, len, depth)
  local x2, y2 = x + math.cos(angle) * len, y + math.sin(angle) * len
  list[#list + 1] = { x, y, x2, y2, depth }
  if depth == 0 then return end
  growCoral(list, x2, y2, angle - 0.4 - love.math.random() * 0.3, len * 0.75, depth - 1)
  growCoral(list, x2, y2, angle + 0.4 + love.math.random() * 0.3, len * 0.75, depth - 1)
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(4242)
  self.glow = gfx.radialTexture(128, 2)
  self.water = gfx.vgradient(1280, 720, { { 0, gfx.rgb("#1f7fa8") }, { 0.45, gfx.rgb("#0f3f6e") }, { 1, gfx.rgb("#06142e") } })
  self.caustics = lg.newShader(CAUSTICS)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  self.white = lg.newImage(white)
  local shaft = {}
  shaft[1] = { 0, 0, 0, 0, 0.7, 0.95, 1, 0.15 }
  shaft[2] = { 1, 0, 0, 0, 0.7, 0.95, 1, 0.15 }
  shaft[3] = { 1, 1, 0, 0, 0.5, 0.8, 1, 0 }
  shaft[4] = { 0, 1, 0, 0, 0.5, 0.8, 1, 0 }
  self.shaftMesh = lg.newMesh(shaft, "fan", "static")

  self.corals = {}
  local colors = { { 1, 0.35, 0.6 }, { 1, 0.6, 0.3 }, { 0.6, 0.4, 1 }, { 0.3, 1, 0.8 } }
  for k = 1, 7 do
    local branches = {}
    local x = 80 + k * 160 + love.math.random(-40, 40)
    growCoral(branches, x, FLOOR + 30, -math.pi / 2 + love.math.random(-2, 2) * 0.1, 40 + love.math.random(0, 25), 4)
    self.corals[k] = { branches = branches, color = colors[(k - 1) % #colors + 1], p = love.math.random() * 6 }
  end
  self.kelp = {}
  for k = 1, 9 do
    self.kelp[k] = { x = love.math.random(0, 1280), h = love.math.random(220, 420), p = love.math.random() * 6 }
  end
  self.jellies = {
    { x = 300, y = 260, s = 1.0, p = 0, c = { 1, 0.5, 0.9 } },
    { x = 900, y = 180, s = 0.75, p = 2, c = { 0.5, 0.9, 1 } },
    { x = 1080, y = 380, s = 0.55, p = 4, c = { 0.8, 0.6, 1 } },
  }
  self.fish = {}
  for k = 1, 45 do
    self.fish[k] = {
      pos = Vector(500 + love.math.random() * 300, 300 + love.math.random() * 160),
      vel = Vector(love.math.random() * 2 - 1, love.math.random() * 2 - 1) * 60,
    }
  end
  self.snow, self.bubbles = {}, {}
  for k = 1, 120 do self.snow[k] = { love.math.random(0, 1280), love.math.random(0, 720), love.math.random() * 6 } end
  for k = 1, 30 do self.bubbles[k] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), r = love.math.random(2, 7) } end

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.5
  self.fx.glow.strength = 5
  self.fx.vignette.color = { 0, 10, 30 }
  self.fx.vignette.opacity = 0.75
end

-- Boids: each fish looks at neighbours within 60px.
function S:updateFish(dt)
  local centre = Vector(640 + math.sin(self.t * 0.3) * 250, 330 + math.sin(self.t * 0.5) * 80)
  for _, f in ipairs(self.fish) do
    local sep, ali, coh, n = Vector(0, 0), Vector(0, 0), Vector(0, 0), 0
    for _, o in ipairs(self.fish) do
      if o ~= f then
        local d = f.pos - o.pos
        local dist = d.length
        if dist < 60 then
          n = n + 1
          ali = ali + o.vel
          coh = coh + o.pos
          if dist < 18 and dist > 0 then sep = sep + d.normalized * (18 - dist) end
        end
      end
    end
    local steer = (centre - f.pos) * 0.15
    if n > 0 then
      steer = steer + (ali / n - f.vel) * 0.8 + (coh / n - f.pos) * 0.5 + sep * 6
    end
    f.vel = f.vel + steer * dt
    local speed = f.vel.length
    if speed > 110 then f.vel = f.vel.normalized * 110 elseif speed < 40 then f.vel = f.vel.normalized * 40 end
    f.pos = f.pos + f.vel * dt
  end
end

function S:update(dt)
  self.t = self.t + dt
  self:updateFish(dt)
  for _, s in ipairs(self.snow) do
    s[2] = s[2] + 6 * dt
    s[1] = s[1] + math.sin(self.t + s[3]) * 4 * dt
    if s[2] > 720 then s[2] = 0 end
  end
  for _, b in ipairs(self.bubbles) do
    b.y = b.y - (30 + b.r * 8) * dt
    b.x = b.x + math.sin(self.t * 3 + b.r) * 10 * dt
    if b.y < -10 then b.y = 730; b.x = love.math.random(0, 1280) end
  end
  for _, j in ipairs(self.jellies) do
    j.y = j.y - (math.max(0, math.sin(self.t * 1.6 + j.p)) * 14) * dt + 2 * dt
    if j.y < -120 then j.y = 800 end
  end
end

function S:drawJelly(j)
  local pulse = math.sin(self.t * 1.6 + j.p)
  local sx, sy = (1 + pulse * 0.12) * j.s, (1 - pulse * 0.15) * j.s
  local x, y = j.x, j.y
  lg.setBlendMode("add")
  lg.setColor(j.c[1], j.c[2], j.c[3], 0.25)
  lg.draw(self.glow, x, y, 0, 1.4 * j.s, 1.4 * j.s, 64, 64)
  lg.setBlendMode("alpha")
  -- tentacles: each point lags further behind the pulse
  for k = -3, 3 do
    local pts = {}
    for i = 0, 12 do
      local lag = self.t * 1.6 + j.p - i * 0.25
      pts[#pts + 1] = x + k * 9 * sx + math.sin(lag + k) * (3 + i * 1.2) * j.s
      pts[#pts + 1] = y + 10 * sy + i * 11 * j.s
    end
    lg.setColor(j.c[1], j.c[2], j.c[3], 0.45)
    lg.setLineWidth(1.5)
    lg.line(pts)
  end
  lg.setColor(j.c[1], j.c[2], j.c[3], 0.55)
  lg.arc("fill", x, y + 10 * sy, 44 * sx, math.pi, math.pi * 2)
  lg.setColor(1, 1, 1, 0.35)
  lg.arc("fill", x - 10 * sx, y - 4 * sy, 16 * sx, math.pi, math.pi * 2)
end

function S:draw()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.water)
    -- light shafts
    lg.setBlendMode("add")
    for k = 0, 6 do
      local x = 80 + k * 190 + math.sin(self.t * 0.3 + k) * 40
      local w = 60 + (k % 3) * 30
      lg.push()
      lg.translate(x, -20)
      lg.shear(0.35 + math.sin(self.t * 0.2 + k) * 0.05, 0)
      lg.scale(w, 600)
      lg.setColor(1, 1, 1, 0.8)
      lg.draw(self.shaftMesh)
      lg.pop()
    end
    lg.setBlendMode("alpha")
    -- surface shimmer
    for k = 0, 40 do
      local x = k * 34 + math.sin(self.t * 2 + k) * 8
      lg.setColor(0.8, 1, 1, 0.25 + 0.2 * math.sin(self.t * 3 + k * 1.7))
      lg.ellipse("fill", x, 6 + math.sin(self.t + k) * 3, 18, 3)
    end
    -- kelp, far and dim
    for _, k in ipairs(self.kelp) do
      local pts = {}
      for i = 0, 16 do
        local f = i / 16
        pts[#pts + 1] = k.x + math.sin(self.t * 0.9 + k.p + f * 3) * 22 * f
        pts[#pts + 1] = FLOOR + 60 - f * k.h
      end
      lg.setColor(0.1, 0.35, 0.3, 0.8)
      lg.setLineWidth(10)
      lg.line(pts)
      for i = 4, #pts - 2, 4 do
        lg.ellipse("fill", pts[i - 1] + 12, pts[i], 14, 5)
      end
    end
    -- sand with caustics
    lg.setShader(self.caustics)
    self.caustics:send("time", self.t)
    lg.setColor(1, 1, 1)
    lg.draw(self.white, 0, FLOOR - 30, 0, 1280, 720 - FLOOR + 30)
    lg.setShader()
    -- coral with glowing tips
    for _, c in ipairs(self.corals) do
      local sway = math.sin(self.t + c.p) * 0.02
      lg.push()
      lg.translate(c.branches[1][1], c.branches[1][2])
      lg.rotate(sway)
      lg.translate(-c.branches[1][1], -c.branches[1][2])
      for _, b in ipairs(c.branches) do
        lg.setColor(c.color[1] * 0.6, c.color[2] * 0.4, c.color[3] * 0.6)
        lg.setLineWidth(2 + b[5] * 2.5)
        lg.line(b[1], b[2], b[3], b[4])
        if b[5] == 0 then
          local tw = 0.6 + 0.4 * math.sin(self.t * 2 + b[3] * 0.1)
          lg.setBlendMode("add")
          lg.setColor(c.color[1], c.color[2], c.color[3], 0.6 * tw)
          lg.draw(self.glow, b[3], b[4], 0, 0.18, 0.18, 64, 64)
          lg.setBlendMode("alpha")
          lg.setColor(c.color)
          lg.circle("fill", b[3], b[4], 3)
        end
      end
      lg.pop()
    end
    for _, j in ipairs(self.jellies) do self:drawJelly(j) end
    -- fish school
    for _, f in ipairs(self.fish) do
      local a = f.vel.angle
      lg.push()
      lg.translate(f.pos.x, f.pos.y)
      lg.rotate(a)
      lg.setColor(0.7, 0.85, 0.95)
      lg.ellipse("fill", 0, 0, 9, 3.5)
      lg.polygon("fill", -7, 0, -14, -4, -14, 4)
      lg.setColor(0.95, 1, 1)
      lg.ellipse("fill", 2, -1, 4, 1.2)
      lg.pop()
    end
    -- marine snow and bubbles
    for _, s in ipairs(self.snow) do
      lg.setColor(0.8, 0.95, 1, 0.35)
      lg.circle("fill", s[1], s[2], 1.2)
    end
    for _, b in ipairs(self.bubbles) do
      lg.setColor(0.8, 0.95, 1, 0.5)
      lg.setLineWidth(1)
      lg.circle("line", b.x, b.y, b.r)
      lg.circle("fill", b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.25)
    end
  end)
end

return S
