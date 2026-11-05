-- REALISTIC: an alpine lake at golden hour, built from noise and shaders.
--
-- "Realistic" in 2D is mostly about light:
--   * the sky is a fragment shader: gradient + sun disk + forward-scattering glow + clouds
--     made of fractal noise that are lit brighter on the side facing the sun
--   * mountains get rock texture and snow from a shader, and fade into the haze with
--     distance (aerial perspective), so the farthest ridge is almost sky-coloured
--   * the lake is the whole upper image drawn mirrored through a ripple shader, with
--     Fresnel: more reflective far away, darker and clearer close to the viewer
--   * god rays (moonshine) streak out where the sun peeks past the peaks

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics
local HORIZON = 440

local S = {
  title = "Realistic",
  subtitle = "Alpine Lake, Golden Hour",
  blurb = "Physically-inspired lighting with fragment shaders: scattering sky, noise clouds, hazy mountain layers and a Fresnel lake reflection.",
  techniques = {
    "Sky shader: gradient + sun disk + Mie-style glow + fbm clouds lit toward the sun",
    "4 mountain ridges from fractal noise, textured by a rock/snow shader",
    "Aerial perspective: each farther ridge blends more into the haze colour",
    "Lake: the scene above the horizon, mirrored through a ripple + Fresnel shader",
    "God rays from the sun as a post-process, then a gentle vignette",
  },
  libs = {
    "moonshine: godsray and vignette",
    "(the rest is love.graphics.newShader, Mesh and Canvas: GLSL written inline)",
  },
  genres = { "Atmospheric exploration and walking sims", "Fishing, sailing and nature games", "Strategy / city-builder backdrops", "Menu and title screens with a 'premium' feel" },
  warmup = 2,
}

local NOISE_GLSL = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
  float s = 0.0; float a = 0.5;
  for (int i = 0; i < 6; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(17.0, 9.0); a *= 0.5; }
  return s;
}
]]

local SKY_SHADER = NOISE_GLSL .. [[
uniform vec2 sun;      // in 0..1 of the sky rectangle
uniform float time;
uniform float aspect;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 zenith = vec3(0.24, 0.40, 0.68);
  vec3 horizon = vec3(1.00, 0.70, 0.42);
  float h = pow(uv.y, 1.6);
  vec3 col = mix(zenith, horizon, h);
  vec2 d = (uv - sun) * vec2(aspect, 1.0);
  float dist = length(d);
  col += vec3(1.0, 0.65, 0.3) * 0.55 * exp(-dist * 3.5);     // wide forward scattering
  col += vec3(1.0, 0.85, 0.6) * 0.6 * exp(-dist * 18.0);     // tight halo
  // clouds: stretched fbm drifting sideways, thinner near the horizon
  vec2 cp = vec2(uv.x * 3.0 * aspect + time * 0.01, uv.y * 9.0);
  float c = fbm(cp);
  c = smoothstep(0.48, 0.78, c) * (1.0 - smoothstep(0.55, 0.95, uv.y)) ;
  float lit = exp(-dist * 2.2);
  vec3 cloudCol = mix(vec3(0.55, 0.42, 0.50), vec3(1.0, 0.78, 0.55), lit);
  col = mix(col, cloudCol, c * 0.85);
  float disk = smoothstep(0.035, 0.030, dist);
  col = mix(col, vec3(1.0, 0.97, 0.88), disk);
  return vec4(col, 1.0);
}
]]

local ROCK_SHADER = NOISE_GLSL .. [[
uniform vec3 haze;
uniform float hazeAmount;
uniform float snowLine;  // screen y above which snow appears
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float n = fbm(sc * vec2(0.012, 0.05));          // horizontal rock strata
  float n2 = fbm(sc * 0.03 + 7.0);
  vec3 rock = color.rgb * (0.7 + 0.6 * n);
  // snow: high up (above snowLine) AND close to the crest (uv.y is 0 on the ridge line)
  float snow = smoothstep(snowLine + 30.0 * n2, snowLine - 10.0 + 30.0 * n2, sc.y)
             * smoothstep(0.22 + 0.1 * n2, 0.08, uv.y);
  vec3 snowCol = mix(vec3(0.75, 0.72, 0.85), vec3(1.0, 0.86, 0.7), color.a); // alpha carries "faces the sun"
  vec3 col = mix(rock, snowCol, snow * (0.6 + 0.4 * n));
  col = mix(col, haze, hazeAmount);
  return vec4(col, 1.0);
}
]]

local WATER_SHADER = NOISE_GLSL .. [[
uniform Image reflection;
uniform float time;
uniform float sunX;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float depth = uv.y;                 // 0 at the horizon, 1 at the bottom of the screen
  float k = mix(0.0015, 0.03, depth);
  vec2 rp = vec2(sc.x * 0.01, sc.y * 0.12 / (0.15 + depth) - time * 1.5);
  vec2 offs = vec2(fbm(rp) - 0.5, fbm(rp + 4.0) - 0.5) * k;
  vec2 ruv = vec2(uv.x, 1.0 - depth * 0.62) + offs;
  vec3 refl = Texel(reflection, ruv).rgb;
  vec3 water = mix(vec3(0.10, 0.20, 0.24), vec3(0.02, 0.06, 0.08), depth);
  float fresnel = mix(0.92, 0.35, pow(depth, 0.6));
  vec3 col = mix(water, refl * 0.9, fresnel);
  // sun glitter: bright sparkles in a column below the sun
  float col_mask = exp(-pow((uv.x - sunX) * 6.0 / (0.25 + depth), 2.0));
  float sparkle = smoothstep(0.72, 0.9, fbm(rp * vec2(6.0, 1.5) + time));
  col += vec3(1.0, 0.8, 0.5) * sparkle * col_mask * 0.9;
  return vec4(col, 1.0);
}
]]

local function ridgePoints(baseY, amp, freq, seed, octaves)
  local pts = {}
  for x = -10, 1290, 6 do
    local n = gfx.fbm(x * freq + seed, seed, octaves)
    -- sharpen peaks: ridged noise looks more like real mountains than smooth noise
    local r = 1 - math.abs(n * 2 - 1)
    pts[#pts + 1] = x
    pts[#pts + 1] = baseY - (n * 0.55 + r * r * 0.45) * amp
  end
  return pts
end

-- Mesh with per-vertex colour: alpha stores "how much this slope faces the sun".
local function ridgeMesh(pts, bottom, rgb)
  local v = {}
  for i = 1, #pts - 2, 2 do
    local x, y = pts[i], pts[i + 1]
    -- slope over a wide window, so lighting changes smoothly along the ridge
    local ia = math.max(1, i - 24)           -- odd indices are x, the next one is y
    local ib = math.min(#pts - 1, i + 24)
    local slope = (pts[ib + 1] - pts[ia + 1]) / (pts[ib] - pts[ia] + 0.001) -- positive = going down to the right
    local lit = gfx.clamp(0.5 - slope * 0.9, 0, 1) -- sun on the right: faces rising to the right are lit
    local b = 0.75 + lit * 0.5
    v[#v + 1] = { x, y, 0, 0, rgb[1] * b, rgb[2] * b, rgb[3] * b, lit }
    v[#v + 1] = { x, bottom, 0, 1, rgb[1] * 0.6, rgb[2] * 0.6, rgb[3] * 0.65, 0 }
  end
  return lg.newMesh(v, "strip", "static")
end

function S:load()
  self.t = 0
  self.sun = { 0.655, 0.43 }
  self.skyShader = lg.newShader(SKY_SHADER)
  self.rockShader = lg.newShader(ROCK_SHADER)
  self.waterShader = lg.newShader(WATER_SHADER)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  self.white = lg.newImage(white)
  self.top = lg.newCanvas(1280, HORIZON)
  self.glow = gfx.radialTexture(128, 2)

  love.math.setRandomSeed(5)
  local haze = { 0.88, 0.72, 0.66 }
  self.haze = haze
  self.ridges = {
    { mesh = ridgeMesh(ridgePoints(430, 310, 0.0019, 3.1, 6), HORIZON, { 0.56, 0.56, 0.74 }), haze = 0.38, snow = 250 },
    { mesh = ridgeMesh(ridgePoints(440, 220, 0.0026, 8.4, 6), HORIZON, { 0.36, 0.36, 0.48 }), haze = 0.2, snow = 290 },
    { mesh = ridgeMesh(ridgePoints(445, 110, 0.0042, 1.7, 5), HORIZON, { 0.20, 0.22, 0.24 }), haze = 0.06, snow = 0 },
  }

  -- Treeline on the near shore: hundreds of thin conifers, baked once.
  self.trees = lg.newCanvas(1280, HORIZON)
  lg.push("all")
  lg.setCanvas(self.trees)
  lg.clear(0, 0, 0, 0)
  for x = -10, 1290, 5 do
    local h = 18 + gfx.fbm(x * 0.01, 2.2, 3) * 50 + love.math.random() * 14
    if x > 500 and x < 820 then h = h * 0.35 end -- a gap so the lake opens up toward the sun
    local base = HORIZON - 4
    lg.setColor(0.06 + love.math.random() * 0.03, 0.09 + love.math.random() * 0.03, 0.08, 1)
    lg.polygon("fill", x - h * 0.16, base, x, base - h, x + h * 0.16, base)
  end
  lg.setColor(0.05, 0.07, 0.06, 1)
  lg.rectangle("fill", 0, HORIZON - 6, 1280, 6)
  lg.pop()

  -- God rays run on an OCCLUSION MASK (bright sun, black mountains), not on the scene:
  -- the radial blur smears the sun's light past the peaks, then it's added on top.
  self.rays = moonshine(1280, 720, moonshine.effects.godsray)
  self.rays.godsray.light_position = { self.sun[1], self.sun[2] * HORIZON / 720 }
  self.rays.godsray.exposure = 0.22
  self.rays.godsray.decay = 0.97
  self.rays.godsray.density = 0.4
  self.rays.godsray.weight = 0.5
  self.rayCanvas = lg.newCanvas(1280, 720)
  self.fx = moonshine(1280, 720, moonshine.effects.vignette)
  self.fx.vignette.opacity = 0.35
  self.fx.vignette.radius = 0.9

  self.reeds = {}
  for i = 1, 70 do
    self.reeds[i] = { x = 1040 + love.math.random() * 260, h = 60 + love.math.random() * 110, p = love.math.random() * 6 }
  end
end

function S:update(dt)
  self.t = self.t + dt
end

function S:drawTop()
  lg.push("all")
  lg.setCanvas(self.top)
  lg.clear(0, 0, 0, 1)
  lg.setShader(self.skyShader)
  self.skyShader:send("sun", self.sun)
  self.skyShader:send("time", self.t)
  self.skyShader:send("aspect", 1280 / HORIZON)
  lg.draw(self.white, 0, 0, 0, 1280, HORIZON)
  lg.setShader(self.rockShader)
  self.rockShader:send("haze", self.haze)
  for _, r in ipairs(self.ridges) do
    self.rockShader:send("hazeAmount", r.haze)
    self.rockShader:send("snowLine", r.snow)
    lg.draw(r.mesh)
  end
  lg.setShader()
  -- low mist in front of the farthest ridges
  lg.setBlendMode("add")
  for i = 0, 6 do
    lg.setColor(1, 0.75, 0.55, 0.06)
    lg.draw(self.glow, 120 + i * 180 + math.sin(self.t * 0.2 + i) * 30, HORIZON - 40, 0, 4, 0.5, 64, 64)
  end
  lg.setBlendMode("alpha")
  lg.setColor(1, 1, 1)
  lg.draw(self.trees)
  lg.pop()
end

function S:drawRays()
  lg.push("all")
  lg.setCanvas(self.rayCanvas)
  lg.clear(0, 0, 0, 1)
  self.rays(function()
    lg.clear(0, 0, 0, 1)
    local sx, sy = self.sun[1] * 1280, self.sun[2] * HORIZON
    lg.setColor(1, 0.8, 0.55)
    lg.draw(self.glow, sx, sy, 0, 1.4, 1.4, 64, 64)
    lg.circle("fill", sx, sy, 16)
    lg.setColor(0, 0, 0)
    for _, r in ipairs(self.ridges) do lg.draw(r.mesh) end
    lg.draw(self.trees)
    lg.rectangle("fill", 0, HORIZON, 1280, 720 - HORIZON)
  end)
  lg.pop()
end

function S:draw()
  self:drawTop()
  self:drawRays()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.top, 0, 0)
    -- The lake: mirror the top canvas through the water shader.
    lg.setShader(self.waterShader)
    self.waterShader:send("reflection", self.top)
    self.waterShader:send("time", self.t)
    self.waterShader:send("sunX", self.sun[1])
    lg.draw(self.white, 0, HORIZON, 0, 1280, 720 - HORIZON)
    lg.setShader()

    lg.setBlendMode("add")
    lg.setColor(1, 1, 1, 0.8)
    lg.draw(self.rayCanvas)
    lg.setBlendMode("alpha")

    -- Foreground reeds swaying, dark against the bright water.
    lg.setLineWidth(3)
    for _, r in ipairs(self.reeds) do
      local sway = math.sin(self.t * 1.2 + r.p) * 6
      lg.setColor(0.05, 0.06, 0.04, 1)
      local x0, y0 = r.x, 730
      local cx, cy = r.x + sway * 0.5, 730 - r.h * 0.5
      local x1, y1 = r.x + sway, 730 - r.h
      lg.line(love.math.newBezierCurve(x0, y0, cx, cy, x1, y1):render(3))
    end
    for i = 1, #self.reeds, 6 do
      local r = self.reeds[i]
      local sway = math.sin(self.t * 1.2 + r.p) * 6
      lg.setColor(0.12, 0.08, 0.05, 1)
      lg.ellipse("fill", r.x + sway, 730 - r.h, 4, 14)
    end
  end)
end

return S
