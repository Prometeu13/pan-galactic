-- REALISTIC, scene 2: northern lights over a frozen lake.
--
-- The aurora is one fragment shader. A wavy "hem" line moves across the sky; light is
-- strongest just above the hem and fades upward, then thin vertical rays (noise that's
-- stretched tall) break it into curtains. Colour shifts from green near the hem to
-- violet higher up, like oxygen vs nitrogen emission in the real thing.
-- The landscape is lit by that sky: snow takes a cold teal tint, the only warm light is
-- the cabin window. The frozen lake shows a soft, slightly smeared reflection.

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics
local SHORE = 500

local S = {
  title = "Realistic",
  subtitle = "Northern Lights",
  blurb = "An aurora shader over a snowy forest and frozen lake, with falling snow and one warm cabin window.",
  techniques = {
    "Aurora shader: a moving hem line, light decaying upward, stretched-noise rays",
    "Colour by height (green to violet) and additive blending over the stars",
    "Snow-capped pines: stacked triangles with a white top layer, from a seeded list",
    "Frozen lake: mirrored sky, smeared with a vertical blur, plus crack lines",
    "Three layers of snowflakes with different size, speed and blur",
  },
  libs = {
    "moonshine: glow (bloom) for the aurora and the cabin light",
    "(the aurora, stars and ice are inline GLSL)",
  },
  genres = { "Survival and exploration in the cold", "Relaxing and atmospheric adventures", "Narrative games with a quiet tone", "Seasonal and winter-themed scenes" },
  warmup = 3,
}

local SKY = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 7.0; a *= 0.5; } return s; }
uniform float time;
vec3 curtain(vec2 uv, float seed, float base) {
  float hem = base + 0.13 * sin(uv.x * 3.0 + time * 0.25 + seed) + 0.16 * (fbm(vec2(uv.x * 2.5 + seed, time * 0.07)) - 0.5);
  float d = hem - uv.y;                         // > 0 above the hem
  float glow = d > 0.0 ? exp(-d * 6.0) : exp(d * 40.0);
  float rays = 0.45 + 0.75 * fbm(vec2(uv.x * 55.0 + seed, uv.y * 1.2 - time * 0.15));
  float k = glow * rays;
  vec3 green = vec3(0.15, 1.0, 0.55);
  vec3 violet = vec3(0.65, 0.25, 0.95);
  return mix(green, violet, clamp(d * 3.0, 0.0, 1.0)) * k;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 col = mix(vec3(0.01, 0.02, 0.07), vec3(0.03, 0.08, 0.16), uv.y);
  // stars: a hash per cell, only a few cells get one
  vec2 cell = floor(sc / 3.0);
  float h = hash(cell);
  if (h > 0.996) col += vec3(0.8) * (0.5 + 0.5 * sin(time * 2.0 + h * 90.0));
  col += curtain(uv, 1.0, 0.50) * 0.9;
  col += curtain(uv, 5.0, 0.34) * 0.5;
  return vec4(col, 1.0);
}
]]

local ICE = [[
uniform Image top;
uniform float time;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float depth = uv.y;
  vec2 ruv = vec2(uv.x, 1.0 - depth * 0.7);
  vec3 r = vec3(0.0);
  for (int i = -3; i <= 3; i++) r += Texel(top, ruv + vec2(0.0, float(i) * 0.006 * (0.3 + depth))).rgb;
  r /= 7.0;
  vec3 ice = mix(vec3(0.10, 0.16, 0.22), vec3(0.05, 0.08, 0.12), depth);
  return vec4(mix(ice, r, 0.7 - depth * 0.35), 1.0);
}
]]

local function snowyPine(x, base, h)
  local w = h * 0.36
  lg.setColor(0.04, 0.07, 0.09)
  lg.rectangle("fill", x - 2, base - h * 0.12, 4, h * 0.14)
  for i = 0, 3 do
    local y = base - h * 0.1 - i * h * 0.22
    local ww = w * (1 - i * 0.22)
    lg.setColor(0.04, 0.08, 0.1)
    lg.polygon("fill", x - ww, y, x, y - h * 0.34, x + ww, y)
    lg.setColor(0.36, 0.5, 0.55)
    lg.polygon("fill", x - ww * 0.55, y - h * 0.15, x, y - h * 0.34, x + ww * 0.55, y - h * 0.15)
  end
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(70)
  self.skyShader = lg.newShader(SKY)
  self.iceShader = lg.newShader(ICE)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  self.white = lg.newImage(white)
  self.glow = gfx.radialTexture(128, 2)
  self.top = lg.newCanvas(1280, SHORE)

  self.far = gfx.ridge(1280, SHORE - 30, 210, 0.0028, 2.5, 6, 5)
  self.trees = {}
  for x = -10, 1290, 9 do
    if not (x > 820 and x < 980) then
      self.trees[#self.trees + 1] = { x = x + love.math.random(-3, 3), h = 40 + love.math.random(0, 50) + gfx.fbm(x * 0.01, 1, 2) * 30 }
    end
  end
  self.flakes = {}
  for i = 1, 260 do
    local layer = love.math.random(1, 3)
    self.flakes[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), layer = layer, p = love.math.random() * 6 }
  end
  self.cracks = {}
  for i = 1, 14 do
    local x, y = love.math.random(0, 1280), love.math.random(SHORE + 20, 720)
    local pts = { x, y }
    for _ = 1, 6 do
      x, y = x + love.math.random(-60, 60), y + love.math.random(-6, 14)
      pts[#pts + 1] = x; pts[#pts + 1] = y
    end
    self.cracks[i] = pts
  end

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.5
  self.fx.glow.strength = 4
  self.fx.vignette.opacity = 0.5
end

function S:update(dt)
  self.t = self.t + dt
  for _, f in ipairs(self.flakes) do
    local sp = 18 + f.layer * 22
    f.y = f.y + sp * dt
    f.x = f.x + (math.sin(self.t * 0.8 + f.p) * 10 + 8) * dt
    if f.y > 730 then f.y = -10; f.x = love.math.random(-50, 1280) end
  end
end

function S:drawTop()
  lg.setShader(self.skyShader)
  self.skyShader:send("time", self.t)
  lg.setColor(1, 1, 1)
  lg.draw(self.white, 0, 0, 0, 1280, SHORE)
  lg.setShader()
  -- far mountains, snow lit faintly green by the aurora
  lg.setColor(0.12, 0.2, 0.24)
  gfx.fillRidge(self.far, SHORE)
  lg.setColor(0.25, 0.42, 0.42, 0.25)
  for i = 1, #self.far - 2, 2 do
    local y = self.far[i + 1]
    if y < SHORE - 120 then
      lg.polygon("fill", self.far[i], y, self.far[i + 2], self.far[i + 3], self.far[i + 2], self.far[i + 3] + 30, self.far[i], y + 30)
    end
  end
  for _, tr in ipairs(self.trees) do snowyPine(tr.x, SHORE + 4, tr.h) end
  -- the cabin with a warm window and chimney smoke
  local cx, cy = 900, SHORE
  lg.setColor(0.09, 0.07, 0.07)
  lg.rectangle("fill", cx - 50, cy - 48, 100, 48)
  lg.setColor(0.42, 0.55, 0.6)
  lg.polygon("fill", cx - 64, cy - 46, cx, cy - 92, cx + 64, cy - 46)
  lg.setColor(0.09, 0.07, 0.07)
  lg.rectangle("fill", cx + 22, cy - 96, 12, 34)
  local flick = 0.9 + 0.1 * math.sin(self.t * 7)
  lg.setColor(1, 0.7, 0.3, flick)
  lg.rectangle("fill", cx - 30, cy - 34, 20, 18)
  lg.rectangle("fill", cx + 10, cy - 34, 20, 18)
  lg.setBlendMode("add")
  lg.setColor(1, 0.6, 0.25, 0.4 * flick)
  lg.draw(self.glow, cx, cy - 26, 0, 1.6, 1.0, 64, 64)
  lg.setBlendMode("alpha")
  for i = 0, 10 do
    local a = (self.t * 0.5 + i * 0.1) % 1
    lg.setColor(0.7, 0.75, 0.8, 0.2 * (1 - a))
    lg.circle("fill", cx + 28 + math.sin(a * 6 + i) * 8 + a * 40, cy - 100 - a * 120, 6 + a * 18)
  end
end

function S:draw()
  lg.push("all")
  lg.setCanvas(self.top)
  self:drawTop()
  lg.pop()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.top)
    lg.setShader(self.iceShader)
    self.iceShader:send("top", self.top)
    lg.draw(self.white, 0, SHORE, 0, 1280, 720 - SHORE)
    lg.setShader()
    -- snow bank along the shore
    lg.setColor(0.55, 0.72, 0.78)
    lg.rectangle("fill", 0, SHORE, 1280, 6)
    lg.setColor(0.8, 0.95, 1, 0.12)
    lg.setLineWidth(1)
    for _, c in ipairs(self.cracks) do lg.line(c) end
    for _, f in ipairs(self.flakes) do
      lg.setColor(0.9, 0.95, 1, 0.3 + f.layer * 0.2)
      lg.circle("fill", f.x, f.y, f.layer * 0.9)
    end
  end)
end

return S
