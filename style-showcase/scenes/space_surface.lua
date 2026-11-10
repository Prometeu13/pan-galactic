-- SPACE, scene 3: standing on another world.
--
-- A landscape is the cheapest "sci-fi" there is: change the sky colours, hang something
-- impossible in it (two suns and a banded giant), and make the plants glow. The giant
-- in the sky is a small shader whose alpha is its own brightness, so its night side
-- simply dissolves into the sky the way the Moon does in daytime.
--
-- The rover drives over real terrain: the ground is a height function (noise), each
-- wheel sits at the height under it, and the body is tilted to the line between the
-- first and last wheel. The same function draws the ground, so they always agree.

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics

local S = {
  title = "Space Sci-Fi",
  subtitle = "Dawn on Tessera IV",
  blurb = "An alien dawn: two suns, a giant in the sky, crystal spires, glowing flora and a six-wheeled rover that follows the terrain.",
  techniques = {
    "Sky giant: a sphere shader whose alpha = brightness, so its dark side fades into the sky",
    "Terrain as a height function: the ground mesh and the rover's wheels share it",
    "Rover body tilt = angle between its front and rear wheel contact points",
    "Crystals: faceted polygons with a lit side, a dark side and an additive core",
    "Layered mesas tinted toward the horizon haze; dust drifting in the wind",
    "Scanner HUD: typed read-outs, a sweeping line, target brackets",
  },
  libs = {
    "moonshine: glow (bloom) for suns, crystals and plants",
  },
  genres = { "Planetary exploration and survival", "Rover / mining sims", "Sci-fi walking simulators", "Base-building on alien worlds" },
  warmup = 4,
}

local MOON = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 p = (uv - 0.5) * 2.0;
  float d2 = dot(p, p);
  if (d2 > 1.0) return vec4(0.0);
  vec3 n = vec3(p.x, p.y, sqrt(1.0 - d2));
  vec3 L = normalize(vec3(0.62, 0.52, 0.35));
  float day = smoothstep(-0.05, 0.4, dot(n, L));
  float q = n.y * 0.95 + n.x * 0.32;
  float band = 0.5 + 0.5 * sin(q * 17.0 + sin(n.x * 5.0 + q * 9.0) * 0.6);
  vec3 col = mix(vec3(0.98, 0.80, 0.70), vec3(0.80, 0.50, 0.58), band);
  col = mix(col, vec3(1.0, 0.93, 0.85), 0.5 + 0.5 * sin(q * 41.0));
  float edge = smoothstep(1.0, 0.97, d2);
  return vec4(col, edge * (0.06 + 0.94 * day)) * color;
}
]]

local GROUND_Y = 560
local function ground(x)
  return GROUND_Y - gfx.fbm(x * 0.0015 + 3.1, 0.7, 3) * 60 + 30 - math.sin(x * 0.004) * 10
end

local function crystal(x, y, h, w, lean, hue, glow, t)
  local tipx, tipy = x + lean * h, y - h
  local sh = y - h * 0.72
  local colA, colB, colC
  if hue == 1 then
    colA, colB, colC = gfx.rgb("#7ff2e0"), gfx.rgb("#2fa8b8"), gfx.rgb("#1a5f7a")
  else
    colA, colB, colC = gfx.rgb("#f2a8ff"), gfx.rgb("#b85fe0"), gfx.rgb("#5a2f8a")
  end
  local lx = x + lean * h * 0.72
  lg.setColor(colC)
  lg.polygon("fill", x, y, x + w, y, lx + w * 0.8, sh, tipx, tipy)
  lg.setColor(colB)
  lg.polygon("fill", x - w, y, x, y, tipx, tipy, lx - w * 0.8, sh)
  lg.setColor(colA)
  lg.polygon("fill", x - w * 0.25, y, x + w * 0.2, y, lx + w * 0.1, sh, tipx, tipy, lx - w * 0.3, sh)
  lg.setBlendMode("add")
  lg.setColor(colA[1], colA[2], colA[3], 0.28 + 0.12 * math.sin(t * 1.5 + x))
  lg.draw(glow, x + lean * h * 0.5, y - h * 0.5, 0, w / 22, h / 60, 64, 64)
  lg.setBlendMode("alpha")
end

function S:load()
  self.t = 0
  self.moon = lg.newShader(MOON)
  local d = love.image.newImageData(1, 1)
  d:setPixel(0, 0, 1, 1, 1, 1)
  self.px = lg.newImage(d)
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.1)
  self.font = lg.newFont(13)
  self.fx = moonshine(1280, 720, moonshine.effects.glow)
  self.fx.glow.strength = 4
  self.fx.glow.min_luma = 0.9
  self.sky = gfx.vgradient(1280, 600, {
    { 0, gfx.rgb("#14143a") }, { 0.3, gfx.rgb("#3a2a6a") }, { 0.58, gfx.rgb("#a8487a") },
    { 0.8, gfx.rgb("#f08a5a") }, { 1, gfx.rgb("#ffd89a") },
  })
  local HAZE = gfx.rgb("#f6a878")
  -- mesas: three layers of flat-topped rock, built from a quantised noise ridge
  self.mesas = {}
  for li, L in ipairs({
    { y = 470, amp = 150, seed = 2.3, col = gfx.mix(gfx.rgb("#5a2f5a"), HAZE, 0.6), step = 40 },
    { y = 510, amp = 190, seed = 9.1, col = gfx.mix(gfx.rgb("#4a2450"), HAZE, 0.32), step = 54 },
  }) do
    local pts = {}
    for x = -20, 1300, 10 do
      local n = gfx.fbm(x * 0.0026 + L.seed, L.seed, 3)
      local h = math.floor(n * L.amp / L.step + 0.5) * L.step     -- terraces
      h = h + gfx.fbm(x * 0.03 + L.seed, 1, 2) * 10
      pts[#pts + 1] = x
      pts[#pts + 1] = L.y - h
    end
    self.mesas[li] = { mesh = gfx.ridgeMesh(pts, 640, L.col, gfx.mix(L.col, HAZE, 0.55)), pts = pts, col = L.col }
  end
  -- foreground terrain as a gradient mesh that follows ground(x)
  local pts = {}
  for x = -10, 1290, 8 do pts[#pts + 1] = x pts[#pts + 1] = ground(x) end
  self.groundPts = pts
  self.groundMesh = gfx.ridgeMesh(pts, 720, gfx.rgb("#7a3458"), gfx.rgb("#2a1030"))
  love.math.setRandomSeed(12)
  self.dust = {}
  for i = 1, 70 do
    self.dust[i] = { x = love.math.random() * 1280, y = 380 + love.math.random() * 320, v = 40 + love.math.random() * 90, s = 0.4 + love.math.random() }
  end
  self.stars = {}
  for i = 1, 90 do self.stars[i] = { love.math.random() * 1280, love.math.random() ^ 2 * 300, love.math.random() } end
  self.rover = { x = 300 }
  self.tracks = {}
  self.meteor = { u = 2 }
  self.plants = {}
  for i = 1, 12 do
    local x = 30 + i * 100 + love.math.random() * 50
    self.plants[i] = { x = x, h = 22 + love.math.random() * 34, p = love.math.random() * 6, n = 2 + love.math.random(0, 2) }
  end
end

function S:update(dt)
  self.t = self.t + dt
  local r = self.rover
  r.x = r.x + 26 * dt
  if r.x > 1420 then r.x = -160 self.tracks = {} end
  if #self.tracks == 0 or r.x - self.tracks[#self.tracks] > 9 then self.tracks[#self.tracks + 1] = r.x - 62 end
  for _, d in ipairs(self.dust) do
    d.x = d.x + d.v * dt
    if d.x > 1300 then d.x = -20 end
  end
  local m = self.meteor
  m.u = m.u + dt * 0.9
  if m.u > 5 then m.u, m.x, m.y = 0, 200 + love.math.random() * 700, 30 + love.math.random() * 120 end
end

function S:drawRover()
  local t = self.t
  local r = self.rover
  local wx = { -62, 0, 62 }
  local wy = {}
  for i, dx in ipairs(wx) do wy[i] = ground(r.x + dx) - 15 end
  local ang = math.atan2(wy[3] - wy[1], 124)
  local cy = (wy[1] + wy[3]) / 2
  -- dust kicked up behind
  for k = 1, 6 do
    local u = (t * 0.8 + k / 6) % 1
    lg.setColor(0.95, 0.65, 0.55, 0.3 * (1 - u))
    lg.circle("fill", r.x - 80 - u * 60, ground(r.x - 80) - 6 - u * 22, 6 + u * 16)
  end
  lg.push()
  lg.translate(r.x, cy)
  lg.rotate(ang)
  -- suspension arms
  lg.setColor(gfx.hex("#3a3f4a"))
  lg.setLineWidth(5)
  for i, dx in ipairs(wx) do
    local ly = (wy[i] - cy) - math.sin(ang) * dx
    lg.line(dx * 0.6, -18, dx, ly * math.cos(ang))
  end
  -- chassis
  lg.setColor(gfx.hex("#e8e4dc"))
  lg.polygon("fill", -74, -24, 70, -24, 86, -40, 70, -56, -66, -56, -80, -40)
  lg.setColor(gfx.hex("#b8b4ac"))
  lg.polygon("fill", -74, -24, 70, -24, 86, -40, -80, -40)
  lg.setColor(gfx.hex("#e2703a"))
  lg.rectangle("fill", -66, -44, 132, 6)
  -- cabin with a gold visor window
  lg.setColor(gfx.hex("#d8d4cc"))
  lg.polygon("fill", 6, -56, 60, -56, 52, -84, 14, -84)
  lg.setColor(gfx.hex("#f2b23a"))
  lg.polygon("fill", 28, -60, 56, -60, 50, -80, 30, -80)
  lg.setColor(1, 1, 1, 0.5)
  lg.polygon("fill", 34, -62, 42, -62, 38, -78, 33, -78)
  -- solar panel on the back, tilted
  lg.setColor(gfx.hex("#3a3f4a"))
  lg.rectangle("fill", -40, -70, 4, 14)
  lg.setColor(gfx.hex("#24459a"))
  lg.polygon("fill", -80, -66, -6, -76, -4, -70, -78, -60)
  lg.setColor(0.6, 0.8, 1, 0.6)
  lg.setLineWidth(1)
  for k = 1, 5 do lg.line(-80 + k * 12.4, -66 - k * 1.66, -78 + k * 12.4, -60 - k * 1.66) end
  -- mast with a camera head that pans, and a dish
  lg.setColor(gfx.hex("#8a8f9a"))
  lg.rectangle("fill", -22, -112, 4, 56)
  lg.setColor(gfx.hex("#e8e4dc"))
  local pan = math.sin(t * 0.8) * 6
  lg.rectangle("fill", -34 + pan, -122, 28, 12, 3)
  lg.setColor(gfx.hex("#1a1e26"))
  lg.circle("fill", -10 + pan, -116, 4)
  lg.setColor(gfx.hex("#c8c4bc"))
  lg.arc("fill", 62, -92, 15, math.pi * 0.75, math.pi * 1.75)
  lg.setLineWidth(2)
  lg.line(56, -84, 52, -84)
  -- headlight
  lg.setColor(1, 0.95, 0.75)
  lg.circle("fill", 84, -40, 4)
  lg.setBlendMode("add")
  lg.setColor(1, 0.9, 0.6, 0.22)
  lg.polygon("fill", 84, -42, 84, -38, 230, -6, 230, -64)
  lg.setColor(1, 0.9, 0.6, 0.7)
  lg.draw(self.glow, 84, -40, 0, 0.5, 0.5, 64, 64)
  lg.setColor(1, 0.25, 0.2, (t % 1 < 0.15) and 1 or 0.1)
  lg.draw(self.glow, -20, -114, 0, 0.3, 0.3, 64, 64)
  lg.setBlendMode("alpha")
  lg.pop()
  -- wheels (drawn in world space so each one hugs the ground)
  for i, dx in ipairs(wx) do
    local x, y = r.x + dx, wy[i]
    lg.setColor(gfx.hex("#22252c"))
    lg.circle("fill", x, y, 17)
    lg.setColor(gfx.hex("#6a7080"))
    lg.circle("fill", x, y, 9)
    lg.setColor(gfx.hex("#22252c"))
    lg.setLineWidth(2)
    for k = 0, 4 do
      local a = r.x * 0.06 + k * math.pi * 2 / 5
      lg.line(x, y, x + math.cos(a) * 9, y + math.sin(a) * 9)
    end
    lg.setColor(gfx.hex("#4a4f5a"))
    for k = 0, 9 do
      local a = r.x * 0.06 + k * math.pi / 5
      lg.circle("fill", x + math.cos(a) * 17, y + math.sin(a) * 17, 2.4)
    end
  end
end

function S:drawAstronaut(x)
  local t = self.t
  local y = ground(x)
  -- beacon with a flag
  lg.setColor(gfx.hex("#c8c4bc"))
  lg.rectangle("fill", x + 44, y - 110, 4, 112)
  lg.setColor(gfx.hex("#e2703a"))
  local w = math.sin(t * 3) * 4
  lg.polygon("fill", x + 48, y - 110, x + 92, y - 104 + w, x + 90, y - 84 + w * 0.5, x + 48, y - 82)
  lg.setColor(1, 1, 1)
  lg.circle("fill", x + 66, y - 96 + w * 0.5, 6)
  -- astronaut: backpack, suit, helmet with gold visor
  lg.setColor(gfx.hex("#a8a4a0"))
  lg.rectangle("fill", x - 20, y - 66, 16, 36, 4)
  lg.setColor(gfx.hex("#f2efe8"))
  lg.rectangle("fill", x - 10, y - 34, 10, 30, 4)
  lg.rectangle("fill", x + 2, y - 34, 10, 30, 4)
  lg.rectangle("fill", x - 13, y - 68, 28, 40, 9)
  lg.setColor(gfx.hex("#e2703a"))
  lg.rectangle("fill", x - 13, y - 44, 28, 4)
  lg.setColor(gfx.hex("#8a8680"))
  lg.rectangle("fill", x - 12, y - 8, 13, 9, 3)
  lg.rectangle("fill", x + 2, y - 8, 14, 9, 3)
  lg.setColor(gfx.hex("#f2efe8"))
  lg.circle("fill", x + 1, y - 80, 16)
  lg.setColor(gfx.hex("#f2b23a"))
  lg.ellipse("fill", x + 6, y - 80, 10, 9)
  lg.setColor(1, 1, 1, 0.7)
  lg.ellipse("fill", x + 9, y - 84, 3, 4)
  -- arm holding a scanner
  lg.setColor(gfx.hex("#f2efe8"))
  lg.setLineWidth(8)
  lg.line(x + 10, y - 58, x + 28, y - 50)
  lg.setColor(gfx.hex("#3a3f4a"))
  lg.rectangle("fill", x + 26, y - 58, 12, 16, 2)
  lg.setColor(0.4, 1, 0.8, 0.6 + 0.4 * math.sin(t * 5))
  lg.rectangle("fill", x + 28, y - 56, 8, 6)
end

function S:draw()
  local t = self.t
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.sky)
    for _, s in ipairs(self.stars) do
      lg.setColor(1, 1, 1, (1 - s[2] / 300) * (0.4 + 0.6 * s[3]) * (0.7 + 0.3 * math.sin(t * 2 + s[1])))
      lg.circle("fill", s[1], s[2], 0.6 + s[3])
    end
    -- meteor
    local m = self.meteor
    if m.u < 1 and m.x then
      local x, y = m.x + m.u * 260, m.y + m.u * 110
      lg.setBlendMode("add")
      for k = 0, 10 do
        lg.setColor(1, 0.95, 0.8, (1 - k / 10) * (1 - m.u))
        lg.circle("fill", x - k * 9, y - k * 3.8, 2.4 - k * 0.2)
      end
      lg.setBlendMode("alpha")
    end
    -- the banded giant and one of its moons
    lg.setShader(self.moon)
    lg.setColor(0.86, 0.84, 0.86, 0.9)
    lg.draw(self.px, 150, -10, 0, 360, 360)
    lg.setColor(0.9, 0.95, 1)
    lg.draw(self.px, 640, 96, 0, 44, 44)
    lg.setShader()
    -- two suns: a big orange one on the horizon, a small white one higher up
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.3, 0.9)
    lg.draw(self.soft, 930, 462, 0, 7, 3.4, 64, 64)
    lg.setColor(1, 0.75, 0.45, 0.9)
    lg.draw(self.glow, 930, 452, 0, 3, 3, 64, 64)
    lg.setColor(0.8, 0.9, 1, 0.9)
    lg.draw(self.glow, 1090, 300, 0, 1.3, 1.3, 64, 64)
    lg.setBlendMode("alpha")
    lg.setColor(1, 0.93, 0.75)
    lg.circle("fill", 930, 452, 46)
    lg.setColor(0.95, 0.98, 1)
    lg.circle("fill", 1090, 300, 13)
    -- thin cloud streaks crossing the low sun
    for k = 0, 5 do
      lg.setColor(0.75, 0.36, 0.5, 0.55)
      lg.ellipse("fill", 760 + k * 90 + math.sin(t * 0.1 + k) * 20, 420 + (k % 3) * 22, 150 - k * 12, 5)
    end

    -- mesas, with a natural arch punched in the nearer layer
    for li, M in ipairs(self.mesas) do
      lg.setColor(1, 1, 1)
      lg.draw(M.mesh)
      -- sunlit rims on the terraces
      lg.setColor(1, 0.8, 0.6, li == 1 and 0.35 or 0.5)
      lg.setLineWidth(2)
      lg.line(M.pts)
    end
    lg.setColor(gfx.hex("#3f1f48"))
    lg.polygon("fill", 50, 560, 66, 400, 60, 352, 84, 318, 130, 300, 196, 292, 262, 304, 300, 330, 312, 372, 304, 420, 322, 560)
    lg.setColor(1, 0.8, 0.6, 0.5)
    lg.line(60, 352, 84, 318, 130, 300, 196, 292, 262, 304, 300, 330, 312, 372)
    lg.setColor(gfx.hex("#4f2858"))
    lg.polygon("fill", 60, 352, 84, 318, 130, 300, 196, 292, 262, 304, 300, 330, 250, 326, 190, 316, 120, 324)
    -- the hole of the arch shows the hazy sky and the far mesas behind it
    lg.setColor(gfx.hex("#f2a070"))
    lg.ellipse("fill", 186, 428, 54, 62)
    lg.rectangle("fill", 132, 428, 108, 132)
    lg.setColor(gfx.hex("#c8707a"))
    lg.polygon("fill", 132, 560, 132, 476, 170, 470, 200, 484, 240, 480, 240, 560)

    -- ground
    lg.setColor(1, 1, 1)
    lg.draw(self.groundMesh)
    lg.setColor(1, 0.72, 0.56, 0.75)
    lg.setLineWidth(2.5)
    lg.line(self.groundPts)
    -- craters and pebbles
    for k = 0, 9 do
      local x = gfx.hash(k * 3.3) * 1280
      local y = ground(x) + 40 + gfx.hash(k + 30) * 90
      local w = 26 + gfx.hash(k + 5) * 50
      lg.setColor(1, 0.7, 0.55, 0.3)
      lg.ellipse("fill", x, y + 3, w + 4, w * 0.22 + 2)
      lg.setColor(0.16, 0.06, 0.18, 0.9)
      lg.ellipse("fill", x, y, w, w * 0.2)
    end
    for k = 0, 40 do
      local x = gfx.hash(k * 1.7 + 9) * 1280
      local y = ground(x) + 8 + gfx.hash(k + 70) * 130
      lg.setColor(0.2, 0.08, 0.22)
      lg.ellipse("fill", x, y, 4 + gfx.hash(k) * 8, 3 + gfx.hash(k) * 3)
      lg.setColor(1, 0.7, 0.55, 0.5)
      lg.ellipse("fill", x + 2, y - 2, 2 + gfx.hash(k) * 3, 1.2)
    end
    -- rover tracks
    lg.setColor(0.14, 0.05, 0.16, 0.55)
    for _, x in ipairs(self.tracks) do
      lg.rectangle("fill", x, ground(x) + 2, 5, 3)
    end

    -- crystal clusters
    local g = self.glow
    crystal(590, ground(590) + 6, 170, 26, 0.12, 1, g, t)
    crystal(630, ground(630) + 6, 110, 20, 0.3, 1, g, t)
    crystal(556, ground(556) + 6, 90, 18, -0.25, 1, g, t)
    crystal(1120, ground(1120) + 8, 210, 30, -0.08, 2, g, t)
    crystal(1160, ground(1160) + 8, 120, 22, 0.28, 2, g, t)
    crystal(1082, ground(1082) + 8, 100, 18, -0.34, 2, g, t)
    crystal(1200, ground(1200) + 8, 70, 14, 0.5, 2, g, t)
    -- glowing bulb plants
    for _, p in ipairs(self.plants) do
      local y = ground(p.x) + 3
      for k = 1, p.n do
        local a = (k - (p.n + 1) / 2) * 0.5 + math.sin(t * 1.2 + p.p + k) * 0.08
        local hx, hy = p.x + math.sin(a) * p.h, y - math.cos(a) * p.h
        lg.setColor(gfx.hex("#2a6a6a"))
        lg.setLineWidth(3)
        lg.line(p.x, y, (p.x + hx) / 2 + math.sin(a) * 5, (y + hy) / 2, hx, hy)
        lg.setColor(0.45, 0.9, 0.75)
        lg.circle("fill", hx, hy, 5)
        lg.setBlendMode("add")
        lg.setColor(0.4, 1, 0.8, 0.28 + 0.14 * math.sin(t * 2 + p.p + k))
        lg.draw(self.glow, hx, hy, 0, 0.45, 0.45, 64, 64)
        lg.setBlendMode("alpha")
      end
    end

    self:drawAstronaut(800)
    self:drawRover()

    -- dust on the wind
    for _, d in ipairs(self.dust) do
      lg.setColor(1, 0.8, 0.65, 0.25)
      lg.rectangle("fill", d.x, d.y, 10 * d.s, 1.4)
    end

    -- scanner HUD
    lg.setFont(self.font)
    local lines = { "TESSERA IV  /  SOL 212", "TEMP  -41 C     WIND 14 m/s", "O2 0.3 %     GRAV 0.72 g", "SCAN: silicate lattice  92 %" }
    lg.setColor(0.05, 0.02, 0.1, 0.5)
    lg.rectangle("fill", 28, 28, 260, 96, 6)
    for i, l in ipairs(lines) do
      local n = math.floor(gfx.clamp(t * 26 - i * 16, 0, #l))
      lg.setColor(0.6, 1, 0.9, i == 1 and 1 or 0.75)
      lg.print(l:sub(1, n), 40, 18 + i * 20)
    end
    -- target brackets around the tall crystal, with a sweeping scan line
    local bx, by, bw, bh = 1070, ground(1120) - 220, 110, 236
    lg.setColor(0.6, 1, 0.9, 0.8)
    lg.setLineWidth(2)
    for _, c in ipairs({ { bx, by, 1, 1 }, { bx + bw, by, -1, 1 }, { bx, by + bh, 1, -1 }, { bx + bw, by + bh, -1, -1 } }) do
      lg.line(c[1] + 16 * c[3], c[2], c[1], c[2], c[1], c[2] + 16 * c[4])
    end
    local sy = by + (t * 0.5 % 1) * bh
    lg.setColor(0.6, 1, 0.9, 0.5)
    lg.line(bx, sy, bx + bw, sy)
  end)
end

return S
