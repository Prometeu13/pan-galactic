-- SPACE, scene 2: a wheel station in orbit around a ringed gas giant.
--
-- The gas giant and its rings are one fragment shader on a single quad. For each pixel
-- it asks two questions: "am I on the sphere?" (then: latitude bands warped by noise, a
-- storm spot, day/night shading, the thin shadow the rings cast on the clouds) and "am
-- I on the ring plane?" (then: hundreds of ringlets from a 1-D noise of the radius, the
-- planet's shadow falling across them). Rings behind the planet are hidden by it, rings
-- in front are drawn over it. That ordering is one comparison in the shader.
--
-- The station is plain geometry: points on a circle, squashed into an ellipse, drawn
-- back half first, then hub and spokes, then front half. Rotating it is adding an angle.

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics

local S = {
  title = "Space Sci-Fi",
  subtitle = "Halcyon Ring",
  blurb = "A banded gas giant with shader-drawn rings and shadows, and a rotating wheel station built from squashed circles.",
  techniques = {
    "Gas giant: latitude bands warped by fbm noise, storm spot, soft terminator",
    "Rings: 1-D noise of the radius = ringlets and gaps; planet shadow on the rings",
    "Front/back ordering of ring vs planet decided per pixel in the shader",
    "Wheel station: circle points squashed to an ellipse, back half / hub / front half",
    "Window lights and beacons are additive dots; bloom makes them glow",
    "HUD callouts: thin leader lines, corner brackets, small caps text",
  },
  libs = {
    "moonshine: glow (bloom) for lights, engines and the planet's limb",
  },
  genres = { "Space station management / colony sims", "Trading and docking games", "Sci-fi visual novels and menus", "Orbital tower-defence" },
  warmup = 2.5,
}

local GIANT = [[
extern number time;
const float TILT = -0.32;      // lean of the whole system on screen
const float SQUASH = 0.26;     // how edge-on we see the rings

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
  float s = 0.0, a = 0.5;
  for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; }
  return s;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  // quad covers -2.7..2.7 planet radii
  vec2 p = (uv - 0.5) * 5.4;
  float ca = cos(TILT), sa = sin(TILT);
  p = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);
  vec3 L = normalize(vec3(-0.72, -0.3, 0.62));

  // ---- rings -------------------------------------------------------------
  vec2 rp = vec2(p.x, p.y / SQUASH);          // position in the ring plane
  float rr = length(rp);
  vec4 ring = vec4(0.0);
  if (rr > 1.28 && rr < 2.55) {
    float u = (rr - 1.28) / 1.27;
    float lanes = noise(vec2(rr * 46.0, 3.0)) * 0.6 + noise(vec2(rr * 150.0, 9.0)) * 0.4;
    float dens = smoothstep(0.0, 0.05, u) * smoothstep(1.0, 0.92, u);
    dens *= 0.35 + 0.65 * lanes;
    dens *= 1.0 - 0.9 * smoothstep(0.03, 0.0, abs(u - 0.60));     // the big gap
    dens *= 1.0 - 0.7 * smoothstep(0.015, 0.0, abs(u - 0.86));
    dens *= mix(0.55, 1.0, smoothstep(0.0, 0.25, u));
    vec3 rc = mix(vec3(0.82, 0.70, 0.52), vec3(0.96, 0.90, 0.78), lanes);
    rc = mix(rc, vec3(0.62, 0.55, 0.52), smoothstep(0.62, 1.0, u));
    // the planet's shadow: a band stretching away from the sun across the ring plane
    vec2 l2 = normalize(vec2(0.95, 0.31));
    float along = dot(rp, l2);
    float across = abs(rp.x * l2.y - rp.y * l2.x);
    float sh = smoothstep(1.02, 0.94, across) * step(0.0, along);
    rc *= 1.0 - 0.93 * sh;
    ring = vec4(rc, dens);
  }

  // ---- planet ------------------------------------------------------------
  float d2 = dot(p, p);
  vec4 planet = vec4(0.0);
  if (d2 < 1.0) {
    vec3 n = vec3(p.x, p.y, sqrt(1.0 - d2));
    float lon = atan(n.x, n.z) + time * 0.03;
    float lat = asin(n.y);
    float warp = fbm(vec2(lon * 2.2, lat * 9.0)) - 0.5;
    float v = lat * 7.5 + warp * 1.5;
    float b1 = 0.5 + 0.5 * sin(v * 3.1);
    float b2 = 0.5 + 0.5 * sin(v * 7.3 + 1.3);
    vec3 col = mix(vec3(0.80, 0.56, 0.36), vec3(0.96, 0.87, 0.70), b1);
    col = mix(col, vec3(0.62, 0.38, 0.27), b2 * 0.42);
    col = mix(col, vec3(0.93, 0.80, 0.62), fbm(vec2(lon * 6.0 + v, lat * 30.0)) * 0.35);
    // polar haze
    col = mix(col, vec3(0.50, 0.58, 0.70), smoothstep(0.9, 1.45, abs(lat)));
    // a great storm
    vec2 sp = vec2(mod(lon + 0.6, 6.2832) - 3.1416, lat - 0.33);
    float storm = smoothstep(0.24, 0.05, length(sp * vec2(1.0, 2.2)));
    float swirl = 0.5 + 0.5 * sin(length(sp) * 60.0 - atan(sp.y, sp.x) * 2.0);
    col = mix(col, mix(vec3(0.72, 0.30, 0.18), vec3(0.92, 0.62, 0.42), swirl), storm * 0.85);
    // light
    float nl = dot(n, L);
    float day = smoothstep(-0.12, 0.55, nl);
    // the rings' shadow on the cloud tops: a few thin curved lines near the equator
    float sy = n.y + n.x * 0.14 + 0.10;
    float rs = smoothstep(0.045, 0.0, abs(sy - 0.10)) * 0.55 + smoothstep(0.018, 0.0, abs(sy - 0.19)) * 0.4
             + smoothstep(0.03, 0.0, abs(sy - 0.25)) * 0.3;
    vec3 lit = col * 0.86 * (0.03 + 0.97 * day) * (1.0 - rs * day);
    // atmosphere: bluish rim on the lit limb
    float rim = pow(1.0 - n.z, 3.0);
    lit += vec3(0.55, 0.70, 1.0) * rim * (0.15 + 0.85 * day) * 0.55;
    float edge = smoothstep(1.0, 0.985, d2);
    planet = vec4(lit, edge);
  }

  // ---- compose: far half of the ring, planet, near half -----------------
  bool nearSide = p.y > 0.0;
  vec4 outc = vec4(0.0);
  if (!nearSide) outc = ring;
  outc = vec4(mix(outc.rgb, planet.rgb, planet.a), max(outc.a, planet.a));
  if (nearSide) outc = vec4(mix(outc.rgb, ring.rgb, ring.a), max(outc.a, ring.a));
  return outc * color;
}
]]

function S:load()
  self.t = 0
  self.shader = lg.newShader(GIANT)
  local d = love.image.newImageData(1, 1)
  d:setPixel(0, 0, 1, 1, 1, 1)
  self.px = lg.newImage(d)
  self.glow = gfx.radialTexture(128, 2)
  self.font = lg.newFont(13)
  self.fx = moonshine(1280, 720, moonshine.effects.glow)
  self.fx.glow.strength = 5
  self.fx.glow.min_luma = 0.82

  -- star field baked once; the brightest few get drawn live so they can twinkle
  self.stars = lg.newCanvas(1280, 720)
  love.math.setRandomSeed(42)
  lg.push("all")
  lg.setCanvas(self.stars)
  lg.clear(gfx.hex("#03040a"))
  -- a faint band of galactic dust
  lg.setBlendMode("add")
  for i = 1, 90 do
    local u = love.math.random()
    local x, y = u * 1500 - 100, 620 - u * 520 + (love.math.random() - 0.5) * 150
    lg.setColor(0.25, 0.22, 0.4, 0.05)
    lg.draw(self.glow, x, y, 0, 2 + love.math.random() * 3, 1 + love.math.random() * 2, 64, 64)
  end
  for i = 1, 900 do
    local b = love.math.random() ^ 3
    local tint = love.math.random()
    lg.setColor(0.7 + tint * 0.3, 0.75 + 0.2 * (1 - tint), 1 - tint * 0.3, 0.25 + b * 0.75)
    lg.circle("fill", love.math.random() * 1280, love.math.random() * 720, 0.5 + b * 1.1)
  end
  lg.pop()
  self.bright = {}
  for i = 1, 14 do
    self.bright[i] = { x = love.math.random() * 1280, y = love.math.random() * 720, p = love.math.random() * 6, s = 0.6 + love.math.random() * 0.8 }
  end
  self.shuttles = {
    { u = 0.1, v = 0.03, x1 = -80, y1 = 560, x2 = 1360, y2 = 250, s = 1 },
    { u = 0.62, v = 0.045, x1 = 1360, y1 = 640, x2 = -80, y2 = 470, s = 0.7 },
  }
end

function S:update(dt)
  self.t = self.t + dt
  for _, s in ipairs(self.shuttles) do
    s.u = (s.u + s.v * dt) % 1
  end
end

-- point on the station wheel: angle a, radius r, lifted by h (screen px)
local K = 0.34
local function wheel(a, r, h) return math.cos(a) * r, math.sin(a) * r * K - (h or 0) end

function S:ringHalf(spin, front)
  local R1, R2, H = 178, 214, 20
  local seg = 48
  for i = 0, seg - 1 do
    local a1 = spin + i / seg * math.pi * 2
    local a2 = a1 + math.pi * 2 / seg
    local mid = (a1 + a2) / 2
    local isFront = math.sin(mid) > 0
    if isFront == front then
      local ox1, oy1 = wheel(a1, R2)
      local ox2, oy2 = wheel(a2, R2)
      local ix1, iy1 = wheel(a1, R1)
      local ix2, iy2 = wheel(a2, R1)
      -- lighting: the sun is on the left
      local lit = 0.5 - 0.5 * math.cos(mid)
      local panel = (i % 4 == 0)
      if front then
        -- outer wall (faces us), then the roof
        local c = gfx.mix(gfx.rgb("#39414f"), gfx.rgb("#c9d2de"), lit)
        if panel then c = gfx.mix(c, gfx.rgb("#e28a3a"), 0.55) end
        lg.setColor(c)
        lg.polygon("fill", ox1, oy1, ox2, oy2, ox2, oy2 + H, ox1, oy1 + H)
        lg.setColor(0.05, 0.06, 0.09, 0.7)
        lg.setLineWidth(1)
        lg.line(ox1, oy1, ox1, oy1 + H)
        -- windows
        if not panel then
          local wx, wy = wheel(mid, R2)
          local on = gfx.hash(i * 7.7) > 0.3
          lg.setColor(on and { 1, 0.9, 0.6, 1 } or { 0.2, 0.25, 0.3, 1 })
          lg.rectangle("fill", wx - 3, wy + 7, 6, 5)
        end
      else
        -- on the far side we see the inner wall
        local c = gfx.mix(gfx.rgb("#1d222c"), gfx.rgb("#6f7a8a"), 1 - lit)
        lg.setColor(c)
        lg.polygon("fill", ix1, iy1, ix2, iy2, ix2, iy2 + H, ix1, iy1 + H)
        if not panel then
          local wx, wy = wheel(mid, R1)
          lg.setColor(0.6, 0.9, 1, gfx.hash(i * 3.1) > 0.4 and 0.9 or 0.15)
          lg.rectangle("fill", wx - 2, wy + 8, 4, 4)
        end
      end
      -- roof
      local c = gfx.mix(gfx.rgb("#4a5261"), gfx.rgb("#e6ebf2"), lit * 0.9)
      if panel then c = gfx.mix(c, gfx.rgb("#2a3140"), 0.5) end
      lg.setColor(c)
      lg.polygon("fill", ox1, oy1, ox2, oy2, ix2, iy2, ix1, iy1)
    end
  end
end

function S:drawStation(x, y)
  local t = self.t
  local spin = t * 0.22
  lg.push()
  lg.translate(x, y)
  lg.rotate(-0.16)
  -- lower spire and dish (behind everything)
  lg.setColor(gfx.hex("#5a6373"))
  lg.rectangle("fill", -6, 30, 12, 96)
  lg.setColor(gfx.hex("#c9d2de"))
  lg.polygon("fill", -30, 126, 30, 126, 12, 146, -12, 146)
  lg.setColor(gfx.hex("#39414f"))
  lg.ellipse("fill", 0, 126, 30, 7)
  lg.setLineWidth(2)
  lg.line(0, 126, 0, 106)
  self:ringHalf(spin, false)
  -- spokes: far ones first
  local function spoke(a)
    local x1, y1 = wheel(a, 34)
    local x2, y2 = wheel(a, 180)
    lg.setColor(gfx.hex("#7a8494"))
    lg.setLineWidth(9)
    lg.line(x1, y1 + 8, x2, y2 + 8)
    lg.setColor(gfx.hex("#c9d2de"))
    lg.setLineWidth(3)
    lg.line(x1, y1 + 5, x2, y2 + 5)
  end
  for k = 0, 3 do
    local a = spin + k * math.pi / 2
    if math.sin(a) <= 0 then spoke(a) end
  end
  -- hub: a drum with lit bands
  lg.setColor(gfx.hex("#5a6373"))
  lg.rectangle("fill", -40, -26, 80, 52)
  lg.ellipse("fill", 0, 26, 40, 13)
  lg.setColor(gfx.hex("#c9d2de"))
  lg.rectangle("fill", -40, -26, 26, 52)
  lg.setColor(gfx.hex("#8a94a4"))
  lg.rectangle("fill", -14, -26, 22, 52)
  lg.setColor(gfx.hex("#e28a3a"))
  lg.rectangle("fill", -40, -6, 80, 6)
  lg.setColor(0.4, 0.9, 1)
  for k = 0, 6 do lg.rectangle("fill", -34 + k * 11, 8, 6, 4) end
  lg.setColor(gfx.hex("#e6ebf2"))
  lg.ellipse("fill", 0, -26, 40, 13)
  lg.setColor(gfx.hex("#39414f"))
  lg.ellipse("fill", 0, -26, 22, 7)
  for k = 0, 3 do
    local a = spin + k * math.pi / 2
    if math.sin(a) > 0 then spoke(a) end
  end
  -- upper mast with solar wings (these don't spin)
  lg.setColor(gfx.hex("#8a94a4"))
  lg.rectangle("fill", -5, -150, 10, 126)
  lg.setLineWidth(3)
  lg.line(-150, -112, 150, -112)
  for _, side in ipairs({ -1, 1 }) do
    for k = 0, 1 do
      local px = side * (40 + k * 60) - (side < 0 and 50 or 0)
      lg.setColor(gfx.hex("#1f3f8a"))
      lg.rectangle("fill", px, -138, 50, 52)
      lg.setColor(gfx.hex("#4f8fe0"))
      lg.rectangle("fill", px, -138, 50, 18)
      lg.setColor(0.8, 0.9, 1, 0.5)
      lg.setLineWidth(1)
      for g = 1, 4 do lg.line(px + g * 10, -138, px + g * 10, -86) end
      lg.line(px, -112, px + 50, -112)
      lg.rectangle("line", px, -138, 50, 52)
    end
  end
  lg.setColor(gfx.hex("#c9d2de"))
  lg.polygon("fill", -9, -150, 9, -150, 0, -176)
  lg.setLineWidth(1.5)
  lg.line(0, -176, 0, -206)
  self:ringHalf(spin, true)
  -- beacons
  lg.setBlendMode("add")
  local blink = (t % 1.4 < 0.12) and 1 or 0.12
  lg.setColor(1, 0.2, 0.2, blink)
  lg.draw(self.glow, 0, -206, 0, 0.5, 0.5, 64, 64)
  lg.circle("fill", 0, -206, 3)
  for k = 0, 3 do
    local bx, by = wheel(spin + k * math.pi / 2 + 0.3, 214)
    lg.setColor(0.3, 1, 0.5, (t * 1.3 + k * 0.25) % 1 < 0.2 and 1 or 0.15)
    lg.circle("fill", bx, by, 2.5)
    lg.draw(self.glow, bx, by, 0, 0.25, 0.25, 64, 64)
  end
  lg.setBlendMode("alpha")
  lg.pop()
end

function S:drawShuttle(s)
  local x = gfx.lerp(s.x1, s.x2, s.u)
  local y = gfx.lerp(s.y1, s.y2, s.u)
  local a = math.atan2(s.y2 - s.y1, s.x2 - s.x1)
  lg.push()
  lg.translate(x, y)
  lg.rotate(a)
  lg.scale(s.s)
  -- engine trail
  lg.setBlendMode("add")
  for k = 1, 9 do
    lg.setColor(0.4, 0.8, 1, 0.5 / k)
    lg.draw(self.glow, -22 - k * 12, 0, 0, 0.5 - k * 0.035, 0.16, 64, 64)
  end
  lg.setBlendMode("alpha")
  lg.setColor(gfx.hex("#dfe5ee"))
  lg.polygon("fill", 30, 0, 8, -8, -20, -8, -24, 0, -20, 8, 8, 8)
  lg.setColor(gfx.hex("#8a94a4"))
  lg.polygon("fill", -6, -8, -22, -20, -24, -8)
  lg.polygon("fill", -6, 8, -22, 20, -24, 8)
  lg.setColor(gfx.hex("#e28a3a"))
  lg.rectangle("fill", -12, -8, 6, 16)
  lg.setColor(gfx.hex("#2a4a7a"))
  lg.polygon("fill", 24, -1, 12, -6, 6, -6, 6, -1)
  lg.setColor(0.6, 0.95, 1)
  lg.circle("fill", -24, 0, 3.5)
  lg.pop()
  return x, y
end

local function callout(x, y, tx, ty, lines, font)
  lg.setColor(0.5, 0.95, 1, 0.85)
  lg.setLineWidth(1)
  lg.circle("line", x, y, 5)
  lg.line(x + 4, y - 4, tx, ty + 16, tx + 150, ty + 16)
  lg.setFont(font)
  for i, l in ipairs(lines) do
    lg.setColor(0.5, 0.95, 1, i == 1 and 1 or 0.65)
    lg.print(l, tx + 4, ty + (i - 1) * 18 - (i == 1 and 2 or -2))
  end
end

function S:draw()
  local t = self.t
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.stars)
    lg.setBlendMode("add")
    for _, b in ipairs(self.bright) do
      local a = 0.5 + 0.5 * math.sin(t * 1.7 + b.p)
      lg.setColor(0.85, 0.9, 1, 0.5 + a * 0.5)
      lg.draw(self.glow, b.x, b.y, 0, 0.12 * b.s, 0.12 * b.s, 64, 64)
      lg.setLineWidth(1)
      lg.setColor(0.85, 0.9, 1, 0.25 + a * 0.35)
      lg.line(b.x - 9 * b.s, b.y, b.x + 9 * b.s, b.y)
      lg.line(b.x, b.y - 9 * b.s, b.x, b.y + 9 * b.s)
    end
    lg.setBlendMode("alpha")
    -- a small icy moon, far out
    lg.setColor(gfx.hex("#9fb4c8"))
    lg.circle("fill", 1130, 560, 26)
    lg.setColor(gfx.hex("#6f8298"))
    lg.circle("fill", 1122, 552, 5)
    lg.circle("fill", 1138, 566, 7)
    lg.setColor(0.012, 0.016, 0.04, 0.85)
    lg.circle("fill", 1142, 568, 27)

    -- the gas giant with its rings
    self.shader:send("time", t)
    lg.setShader(self.shader)
    lg.setColor(1, 1, 1)
    lg.draw(self.px, 380 - 650, 300 - 650, 0, 1300, 1300)
    lg.setShader()

    self:drawShuttle(self.shuttles[2])
    self:drawStation(850, 430)
    local sx, sy = self:drawShuttle(self.shuttles[1])

    callout(850 + 150, 430 - 60, 1040, 250, { "HALCYON RING", "POP 4,210   SPIN 1.1 RPM", "BAY 3 OPEN" }, self.font)
    callout(sx, sy, sx + 40, sy + 40, { "FERRY 07", "INBOUND" }, self.font)
    -- corner brackets, like a viewport
    lg.setColor(0.5, 0.95, 1, 0.5)
    lg.setLineWidth(2)
    for _, c in ipairs({ { 24, 24, 1, 1 }, { 1256, 24, -1, 1 }, { 24, 696, 1, -1 }, { 1256, 696, -1, -1 } }) do
      lg.line(c[1] + 30 * c[3], c[2], c[1], c[2], c[1], c[2] + 30 * c[4])
    end
  end)
end

return S
