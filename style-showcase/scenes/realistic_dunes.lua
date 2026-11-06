-- REALISTIC, scene 3: desert dunes under a high sun.
--
-- Dunes are all about the two tones of sand: the face toward the sun is bright and
-- warm, the slip face away from it is in cool mauve shadow, with a sharp crest between.
-- Each dune ridge is a Mesh whose vertices carry "how much this slope faces the sun";
-- a shader turns that into lit/shadow sand, adds wind ripples, and fades far dunes
-- into the haze. Then the whole frame goes through a heat-shimmer shader that wobbles
-- pixels near the horizon, and a lens flare is added along the line through the sun.

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics
local HZ = 330

local S = {
  title = "Realistic",
  subtitle = "Desert Dunes",
  blurb = "Sun-and-shadow dune shading, wind ripples, a camel caravan on a crest, heat shimmer and a lens flare.",
  techniques = {
    "Dune ridges from sharpened noise; vertex alpha = how much the slope faces the sun",
    "Sand shader: warm lit face vs cool shadow face, wind ripples, distance haze",
    "Heat shimmer: a full-screen shader offsets pixels near the horizon over time",
    "Lens flare: discs placed along the line from the sun through the screen centre",
    "Caravan walks along the crest; camel legs swing on sine waves",
  },
  libs = {
    "moonshine: glow on the sun and sand highlights",
    "(sky, sand and heat shimmer are inline GLSL shaders)",
  },
  genres = { "Open-world exploration and survival", "Racing and rally games", "Historical / trading caravans", "Western and desert adventures" },
  warmup = 3,
}

local SAND = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
uniform float haze;
uniform float rippleScale;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float lit = color.a;
  vec3 sun = vec3(0.98, 0.76, 0.48);
  vec3 shade = vec3(0.60, 0.40, 0.40);
  vec3 col = mix(shade, sun, smoothstep(0.38, 0.62, lit));
  float n = vnoise(sc * vec2(0.02, 0.08));
  float rip = sin(sc.x * 0.25 * rippleScale + sc.y * 1.3 * rippleScale + n * 6.0);
  col *= 1.0 + rip * 0.05 * (0.4 + lit);
  col += (hash(floor(sc)) - 0.5) * 0.03;                   // grain
  col = mix(col, vec3(0.93, 0.85, 0.80), haze);
  return vec4(col, 1.0);
}
]]

local SKY = [[
uniform vec2 sun;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 col = mix(vec3(0.20, 0.42, 0.78), vec3(0.93, 0.88, 0.82), pow(uv.y, 2.2));
  float d = length((uv - sun) * vec2(3.46, 1.0)); // sky rect is 1280 x 370
  col += vec3(1.0, 0.95, 0.8) * (0.6 * exp(-d * 8.0) + 0.25 * exp(-d * 2.0));
  col = mix(col, vec3(1.0), smoothstep(0.09, 0.075, d));
  return vec4(col, 1.0);
}
]]

local SHIMMER = [[
uniform float time;
uniform float horizon;   // 0..1 screen y of the horizon
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float band = exp(-pow((uv.y - horizon) * 9.0, 2.0));
  float off = sin(uv.y * 260.0 + time * 7.0) * 0.0018 + sin(uv.y * 97.0 - time * 4.0) * 0.0012;
  return Texel(tex, uv + vec2(off * band, 0.0)) * color;
}
]]

local function dunePoints(base, amp, freq, seed)
  local pts = {}
  for x = -12, 1400, 6 do
    local n = gfx.fbm(x * freq + seed, seed * 0.7, 4)
    local r = 1 - math.abs(math.sin(x * freq * 2.2 + seed + n * 3))
    pts[#pts + 1] = x
    pts[#pts + 1] = base - (n * 0.55 + r ^ 2.5 * 0.45) * amp
  end
  return pts
end

-- Two meshes per dune: a band under the crest where light and shadow are strongest
-- (vertex alpha = how much the slope faces the sun, fading to neutral at the band's
-- bottom), and a plain fill below it.
local BAND, SKEW = 130, 90
local function duneMeshes(pts, bottom)
  local band, fill = {}, {}
  for i = 1, #pts - 1, 2 do
    local ia, ib = math.max(1, i - 10), math.min(#pts - 1, i + 10)
    local slope = (pts[ib + 1] - pts[ia + 1]) / (pts[ib] - pts[ia] + 0.001)
    -- sun on the right: a slope that rises toward the right faces it
    local lit = gfx.clamp(0.5 - slope * 3, 0, 1)
    local x, y = pts[i], pts[i + 1]
    band[#band + 1] = { x, y, 0, 0, 1, 1, 1, lit }
    -- the band's lower edge is shifted away from the sun, so light/shadow edges slant
    band[#band + 1] = { x - SKEW, y + BAND, 0, 1, 1, 1, 1, 0.58 }
    fill[#fill + 1] = { x - SKEW, y + BAND - 1, 0, 0, 1, 1, 1, 0.58 }
    fill[#fill + 1] = { x - SKEW, bottom, 0, 1, 1, 1, 1, 0.58 }
  end
  return { lg.newMesh(band, "strip", "static"), lg.newMesh(fill, "strip", "static") }
end

function S:load()
  self.t = 0
  self.sun = { 0.78, 0.16 }
  self.sand = lg.newShader(SAND)
  self.skyShader = lg.newShader(SKY)
  self.shimmer = lg.newShader(SHIMMER)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  self.white = lg.newImage(white)
  self.glow = gfx.radialTexture(128, 2)
  self.scene = lg.newCanvas(1280, 720)

  local specs = {
    { HZ + 10, 50, 0.004, 3.0, 0.75, 0.5 },
    { HZ + 60, 90, 0.0032, 7.0, 0.5, 0.7 },
    { HZ + 150, 130, 0.0025, 1.3, 0.28, 1.0 },
    { HZ + 290, 160, 0.0021, 9.4, 0.08, 1.6 },
  }
  self.dunes = {}
  for i, sp in ipairs(specs) do
    local pts = dunePoints(sp[1], sp[2], sp[3], sp[4])
    self.dunes[i] = { pts = pts, meshes = duneMeshes(pts, 720), haze = sp[5], ripple = sp[6] }
  end
  self.caravanRidge = self.dunes[2].pts
  self.fx = moonshine(1280, 720, moonshine.effects.glow)
  self.fx.glow.min_luma = 0.92
  self.fx.glow.strength = 4
end

function S:update(dt)
  self.t = self.t + dt
end

local function ridgeY(pts, x)
  local i = math.floor((x + 12) / 6) * 2 + 1
  i = gfx.clamp(i, 1, #pts - 3)
  local f = (x - pts[i]) / 6
  return pts[i + 1] + (pts[i + 3] - pts[i + 1]) * f
end

function S:drawCamel(x, y, s, phase)
  lg.push()
  lg.translate(x, y)
  lg.scale(s)
  lg.setColor(0.28, 0.18, 0.16)
  for k, lx in ipairs({ -14, -8, 10, 16 }) do
    local sw = math.sin(phase + k * math.pi / 2) * 0.35
    lg.setLineWidth(3)
    lg.line(lx, -16, lx + math.sin(sw) * 9, 0)
  end
  lg.ellipse("fill", 0, -22, 22, 9)
  lg.ellipse("fill", -2, -30, 9, 8)            -- hump
  lg.setLineWidth(5)
  lg.line(18, -24, 28, -38)                    -- neck
  lg.ellipse("fill", 31, -39, 6, 3.5)          -- head
  lg.setColor(0.18, 0.12, 0.12)
  lg.polygon("fill", -6, -36, 2, -36, 1, -50, -5, -50) -- rider
  lg.circle("fill", -2, -53, 4)
  lg.pop()
end

function S:drawScene()
  lg.setShader(self.skyShader)
  self.skyShader:send("sun", self.sun)
  lg.setColor(1, 1, 1)
  lg.draw(self.white, 0, 0, 0, 1280, HZ + 40)
  lg.setShader(self.sand)
  for i, d in ipairs(self.dunes) do
    self.sand:send("haze", d.haze)
    self.sand:send("rippleScale", d.ripple)
    lg.setColor(1, 1, 1)
    lg.draw(d.meshes[2])
    lg.draw(d.meshes[1])
    lg.setShader()
    if i == 2 then
      -- the caravan walks along this ridge, behind the nearer dunes
      for k = 0, 4 do
        local x = (self.t * 14 + 380 - k * 52) % 1500 - 100
        self:drawCamel(x, ridgeY(self.caravanRidge, x) + 2, 0.8, self.t * 4 + k)
      end
    end
    lg.setShader(self.sand)
  end
  lg.setShader()
  -- footprints and a dry shrub in the foreground
  for k = 0, 16 do
    local x = 180 + k * 46 + (k % 2) * 10
    local y = 640 - k * 6
    lg.setColor(0.55, 0.36, 0.3, 0.35)
    lg.ellipse("fill", x, y, 6, 2.5)
  end
  lg.setColor(0.35, 0.25, 0.18)
  lg.setLineWidth(2)
  for k = 0, 9 do
    local a = -math.pi / 2 + (k - 4.5) * 0.25
    lg.line(1080, 660, 1080 + math.cos(a) * 50, 660 + math.sin(a) * 40)
  end
end

function S:drawFlare()
  local sx, sy = self.sun[1] * 1280, self.sun[2] * (HZ + 40)
  local dx, dy = 640 - sx, 360 - sy
  lg.setBlendMode("add")
  local discs = { { 0.4, 26, { 1, 0.8, 0.5 } }, { 0.7, 14, { 0.6, 0.9, 1 } }, { 1.15, 40, { 1, 0.6, 0.4 } }, { 1.5, 22, { 0.7, 1, 0.7 } } }
  for _, d in ipairs(discs) do
    lg.setColor(d[3][1], d[3][2], d[3][3], 0.12)
    lg.circle("fill", sx + dx * d[1], sy + dy * d[1], d[2])
  end
  lg.setColor(1, 0.95, 0.85, 0.4)
  lg.draw(self.glow, sx, sy, 0, 2.2, 2.2, 64, 64)
  lg.setBlendMode("alpha")
end

function S:draw()
  lg.push("all")
  lg.setCanvas(self.scene)
  lg.clear(0, 0, 0, 1)
  self:drawScene()
  lg.pop()
  self.fx(function()
    lg.setShader(self.shimmer)
    self.shimmer:send("time", self.t)
    self.shimmer:send("horizon", (HZ + 20) / 720)
    lg.setColor(1, 1, 1)
    lg.draw(self.scene)
    lg.setShader()
    self:drawFlare()
  end)
end

return S
