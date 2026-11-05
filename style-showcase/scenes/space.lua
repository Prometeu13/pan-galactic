-- SPACE / SCI-FI: a living planet, a nebula and a ship drawn from an SVG string.
--
-- The planet is a flat rectangle drawn through a shader that pretends it's a sphere:
-- for each pixel it works out the 3D surface normal, turns that into longitude and
-- latitude, and looks up a texture that was generated with 3D noise at load time.
-- Spin = add time to the longitude. Lighting, a cloud layer that drifts faster than
-- the ground, city lights on the night side and an atmosphere rim all happen in the
-- same shader.
--
-- The ship is a few lines of SVG markup written in this file, rendered by lovector.
-- That's a good workflow if you like designing shapes in a vector mindset.

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local lovector = require("lovector")

local lg = love.graphics

local S = {
  title = "Space Sci-Fi",
  subtitle = "Orbit of Kepler-Vire",
  blurb = "A shader-rendered rotating planet with clouds, night-side city lights and atmosphere; a nebula; and a ship defined as inline SVG.",
  techniques = {
    "Planet textures generated with 3D noise on a sphere (no seams), stored in ImageData",
    "Sphere shader: normal -> lon/lat lookup, lighting, specular oceans, city lights",
    "Nebula: domain-warped fbm in a shader, baked once into a Canvas",
    "Three star layers with parallax drift and twinkle",
    "Ship = an SVG string in the code, rendered by lovector; flame is additive glow",
    "Post: bloom + slight chromatic aberration for a lens feel",
  },
  libs = {
    "lovector: renders the inline SVG spaceship",
    "moonshine: glow and chromasep (chromatic aberration)",
  },
  genres = { "Space shooters and arcade games", "4X / space strategy and trading sims", "Exploration and survival in space", "Sci-fi UI-heavy games" },
  warmup = 3,
}

local SHIP_SVG = [[<?xml version="1.0"?>
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="100" viewBox="0 0 240 100">
  <polygon points="80,38 152,38 124,4 102,4" fill="#5b6b8a" stroke="#1b2030" stroke-width="2"/>
  <polygon points="80,62 152,62 124,96 102,96" fill="#46536d" stroke="#1b2030" stroke-width="2"/>
  <rect x="14" y="36" width="28" height="28" fill="#3a4256" stroke="#1b2030" stroke-width="2"/>
  <path d="M 34 38 L 150 32 Q 214 40 234 50 Q 214 60 150 68 L 34 62 Z" fill="#d6dde8" stroke="#1b2030" stroke-width="2"/>
  <path d="M 36 51 L 232 51 Q 214 60 150 67 L 36 61 Z" fill="#a9b3c4"/>
  <polygon points="60,43 144,38 146,42 60,47" fill="#ff5a5a"/>
  <ellipse cx="176" cy="45" rx="22" ry="7" fill="#62e0ff" stroke="#1b2030" stroke-width="2"/>
  <ellipse cx="170" cy="43" rx="9" ry="2" fill="#d8f8ff"/>
  <circle cx="113" cy="8" r="3" fill="#ff5a5a"/>
  <circle cx="113" cy="92" r="3" fill="#5aff8a"/>
</svg>]]

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 6; i++) { s += a * vnoise(p); p = p * 2.02 + 3.1; a *= 0.5; } return s; }
]]

local NEBULA_SHADER = NOISE .. [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 p = uv * vec2(3.5, 2.0);
  vec2 q = vec2(fbm(p), fbm(p + 5.2));                 // domain warping: noise bends noise
  float n = fbm(p + q * 2.2);
  vec3 col = vec3(0.01, 0.01, 0.03);
  col += vec3(0.45, 0.10, 0.55) * smoothstep(0.45, 0.85, n) * 0.8;
  col += vec3(0.05, 0.45, 0.55) * smoothstep(0.55, 0.9, fbm(p * 1.3 + q + 9.0)) * 0.6;
  col *= 0.4 + 0.8 * (1.0 - uv.x * 0.6);
  return vec4(col, 1.0);
}
]]

local PLANET_SHADER = [[
uniform Image surface;   // rgb = colour, a = city lights
uniform Image clouds;    // r = clouds, g = ocean mask
uniform float spin;
uniform vec3 light;
uniform vec3 atmo;
const float PI = 3.14159265;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 p = uv * 2.0 - 1.0;
  float r2 = dot(p, p);
  if (r2 > 1.0) discard;
  vec3 n = vec3(p.x, p.y, sqrt(1.0 - r2));
  float lon = atan(n.x, n.z) / (2.0 * PI) + 0.5;
  float lat = asin(n.y) / PI + 0.5;
  vec4 s = Texel(surface, vec2(fract(lon + spin), lat));
  vec4 c = Texel(clouds, vec2(fract(lon + spin * 1.35), lat));
  float diff = max(dot(n, light), 0.0);
  float night = smoothstep(0.15, -0.1, dot(n, light));
  vec3 col = s.rgb * (0.04 + diff * 1.1);
  // ocean specular (Blinn-Phong with the viewer at +z)
  vec3 h = normalize(light + vec3(0.0, 0.0, 1.0));
  col += vec3(1.0, 0.9, 0.7) * pow(max(dot(n, h), 0.0), 60.0) * c.g * 0.7;
  col += vec3(1.0, 0.75, 0.4) * s.a * night * 1.2;           // cities glow in the dark
  col = mix(col, vec3(1.0) * (0.06 + diff * 1.05), c.r * 0.9); // clouds over everything
  float rim = pow(1.0 - n.z, 2.5);
  col += atmo * rim * (0.25 + diff * 1.4);
  float edge = smoothstep(1.0, 0.985, r2);
  return vec4(col, edge);
}
]]

-- 3D noise sampled on a unit sphere, so the texture wraps around without a seam.
local function sphereNoise(u, v, freq, seed, octaves)
  local lon, lat = u * math.pi * 2, (v - 0.5) * math.pi
  local x, y, z = math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)
  local sum, amp, norm = 0, 1, 0
  for _ = 1, octaves do
    sum = sum + amp * love.math.noise(x * freq + seed, y * freq + seed * 2, z * freq - seed)
    norm = norm + amp
    amp = amp * 0.5
    freq = freq * 2
  end
  return sum / norm
end

local function bakePlanet(w, h)
  local surf = love.image.newImageData(w, h)
  local cl = love.image.newImageData(w, h)
  local stops = {
    { 0.00, gfx.rgb("#0b1f4a") }, { 0.47, gfx.rgb("#1d4f8f") }, { 0.5, gfx.rgb("#3d86b8") },
    { 0.515, gfx.rgb("#d8c48a") }, { 0.56, gfx.rgb("#5f9a45") }, { 0.66, gfx.rgb("#2f6b35") },
    { 0.75, gfx.rgb("#7a6a55") }, { 0.82, gfx.rgb("#e8eef5") }, { 1.0, gfx.rgb("#ffffff") },
  }
  local function ramp(t)
    for i = 1, #stops - 1 do
      local a, b = stops[i], stops[i + 1]
      if t <= b[1] then return gfx.mix(a[2], b[2], (t - a[1]) / (b[1] - a[1])) end
    end
    return stops[#stops][2]
  end
  for y = 0, h - 1 do
    local v = (y + 0.5) / h
    local polar = math.abs(v - 0.5) * 2
    for x = 0, w - 1 do
      local u = (x + 0.5) / w
      local e = sphereNoise(u, v, 1.6, 10, 6)
      e = e + (polar > 0.82 and (polar - 0.82) * 3 or 0) -- ice caps
      local c = ramp(e)
      local land = e > 0.515 and e < 0.8
      local city = 0
      if land and sphereNoise(u, v, 22, 40, 2) > 0.62 then city = 0.6 + love.math.random() * 0.4 end
      surf:setPixel(x, y, c[1], c[2], c[3], city)
      local cloud = sphereNoise(u, v, 3, 77, 5)
      cloud = gfx.clamp((cloud - 0.5) * 3.2, 0, 1)
      cl:setPixel(x, y, cloud, e < 0.515 and 1 or 0, 0, 1)
    end
  end
  local a, b = lg.newImage(surf), lg.newImage(cl)
  a:setWrap("repeat", "clampzero")
  b:setWrap("repeat", "clampzero")
  return a, b
end

local function bakeMoon(w, h)
  local d = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local u, v = (x + 0.5) / w, (y + 0.5) / h
      local n = sphereNoise(u, v, 4, 3, 5)
      local crater = sphereNoise(u, v, 14, 9, 2)
      local g = 0.45 + n * 0.35 - (crater > 0.66 and 0.15 or 0)
      d:setPixel(x, y, g, g * 0.97, g * 0.95, 0)
    end
  end
  local blank = love.image.newImageData(4, 4)
  local img = lg.newImage(d)
  img:setWrap("repeat", "clampzero")
  return img, lg.newImage(blank)
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(99)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  self.white = lg.newImage(white)
  self.glow = gfx.radialTexture(128, 2)

  self.nebula = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.nebula)
  lg.setShader(lg.newShader(NEBULA_SHADER))
  lg.draw(self.white, 0, 0, 0, 1280, 720)
  lg.pop()

  self.planetShader = lg.newShader(PLANET_SHADER)
  self.surface, self.clouds = bakePlanet(512, 256)
  self.moonSurface, self.moonClouds = bakeMoon(256, 128)

  self.stars = {}
  for layer = 1, 3 do
    for _ = 1, 90 do
      self.stars[#self.stars + 1] = { x = love.math.random() * 1280, y = love.math.random() * 720, layer = layer, p = love.math.random() * 6 }
    end
  end

  -- lovector fills shapes with the stencil buffer, so render the SVG once into a
  -- stencil-enabled canvas (at 2x for crisp edges) and draw that image afterwards.
  local svg = lovector.SVG(SHIP_SVG)
  self.ship = lg.newCanvas(480, 200, { msaa = 4 })
  lg.push("all")
  lg.setCanvas({ self.ship, stencil = true })
  lg.clear(0, 0, 0, 0)
  svg:draw(0, 0, 2)
  lg.pop()
  self.trail = {}

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.chromasep)
  self.fx.glow.min_luma = 0.7
  self.fx.glow.strength = 4
  self.fx.chromasep.radius = 1.5
  self.fx.chromasep.angle = 0.4
  self.font = lg.newFont(13)
end

function S:update(dt)
  self.t = self.t + dt
  for _, s in ipairs(self.stars) do
    s.x = s.x - dt * s.layer * 6
    if s.x < 0 then s.x = s.x + 1280 end
  end
  local sx, sy, ang = self:shipPose()
  local bx, by = sx - math.cos(ang) * 95, sy - math.sin(ang) * 95
  self.trail[#self.trail + 1] = { x = bx, y = by, life = 1 }
  for i = #self.trail, 1, -1 do
    local p = self.trail[i]
    p.life = p.life - dt * 1.4
    p.x = p.x - dt * 40
    if p.life <= 0 then table.remove(self.trail, i) end
  end
end

function S:shipPose()
  local t = self.t
  local x = 300 + math.sin(t * 0.35) * 60
  local y = 470 + math.sin(t * 0.7) * 40
  local ang = math.cos(t * 0.7) * 0.12 - 0.12
  return x, y, ang
end

function S:drawPlanet(img, cl, x, y, r, spin, light, atmo)
  lg.setBlendMode("add")
  lg.setColor(atmo[1], atmo[2], atmo[3], 0.55)
  lg.draw(self.glow, x - r * 0.18, y - r * 0.08, 0, r * 2.5 / 128, r * 2.5 / 128, 64, 64)
  lg.setBlendMode("alpha")
  lg.setShader(self.planetShader)
  self.planetShader:send("surface", img)
  self.planetShader:send("clouds", cl)
  self.planetShader:send("spin", spin)
  self.planetShader:send("light", light)
  self.planetShader:send("atmo", atmo)
  lg.setColor(1, 1, 1)
  lg.draw(self.white, x - r, y - r, 0, r * 2, r * 2)
  lg.setShader()
end

local function bracket(x, y, w, h, len)
  lg.line(x, y + len, x, y, x + len, y)
  lg.line(x + w - len, y, x + w, y, x + w, y + len)
  lg.line(x, y + h - len, x, y + h, x + len, y + h)
  lg.line(x + w - len, y + h, x + w, y + h, x + w, y + h - len)
end

function S:draw()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.nebula)
    for _, s in ipairs(self.stars) do
      local tw = 0.5 + 0.5 * math.sin(self.t * (1 + s.layer) + s.p)
      lg.setColor(0.85, 0.9, 1, (0.25 + 0.25 * s.layer) * (0.6 + 0.4 * tw))
      lg.circle("fill", s.x, s.y, 0.6 + s.layer * 0.45)
    end

    local L = { -0.62, -0.38, 0.69 }
    self:drawPlanet(self.surface, self.clouds, 860, 330, 250, self.t * 0.012, L, { 0.35, 0.6, 1.0 })
    self:drawPlanet(self.moonSurface, self.moonClouds, 1170, 110, 46, self.t * 0.02 + 0.3, L, { 0.4, 0.4, 0.45 })

    -- engine trail
    lg.setBlendMode("add")
    for _, p in ipairs(self.trail) do
      lg.setColor(0.3, 0.7, 1, p.life * 0.25)
      lg.draw(self.glow, p.x, p.y, 0, p.life * 0.3, p.life * 0.3, 64, 64)
    end
    lg.setBlendMode("alpha")

    local sx, sy, ang = self:shipPose()
    lg.push()
    lg.translate(sx, sy)
    lg.rotate(ang)
    -- flame: layered triangles that flicker, plus glow
    local f = 0.8 + love.math.noise(self.t * 12) * 0.5
    lg.setBlendMode("add")
    lg.setColor(0.3, 0.75, 1, 0.9)
    lg.draw(self.glow, -95, 0, 0, 0.9 * f, 0.5, 64, 64)
    lg.setColor(0.4, 0.8, 1, 0.9)
    lg.polygon("fill", -96, -10, -96 - 60 * f, 0, -96, 10)
    lg.setColor(1, 1, 1, 0.9)
    lg.polygon("fill", -96, -5, -96 - 30 * f, 0, -96, 5)
    lg.setBlendMode("alpha")
    lg.setColor(1, 1, 1)
    lg.draw(self.ship, -110, -50, 0, 0.5, 0.5)
    lg.pop()

    -- HUD: target brackets and readouts, all lines and text.
    lg.setLineWidth(1.5)
    lg.setColor(0.45, 0.95, 1, 0.75)
    bracket(590, 60, 540, 540, 28)
    lg.setFont(self.font)
    lg.print("TARGET  KEPLER-VIRE b", 600, 610 - 4)
    lg.setColor(0.45, 0.95, 1, 0.5)
    lg.print(("CLASS M   GRAV 1.12g   ROT %.1f h   ATM N2/O2"):format(31.4), 600, 626 - 4)
    lg.setColor(0.45, 0.95, 1, 0.6)
    lg.circle("line", 110, 610, 56)
    lg.circle("line", 110, 610, 30)
    lg.line(110, 610, 110 + math.cos(self.t * 2) * 56, 610 + math.sin(self.t * 2) * 56)
    lg.setColor(1, 0.4, 0.4, 0.9)
    lg.circle("fill", 130, 590, 3)
  end)
end

return S
