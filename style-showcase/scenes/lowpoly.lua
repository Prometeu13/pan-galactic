-- LOW-POLY / FLAT GEOMETRIC: a landscape made only of flat-coloured triangles.
--
-- Recipe:
--   1. scatter points (a jittered grid, plus extra points along the mountain ridge so
--      the silhouette stays sharp)
--   2. Delaunay-triangulate them
--   3. colour each triangle by sampling an invisible "scene function" at its centre:
--      is this spot sky, sun, snow, rock, lake or forest? The palette comes from HSLuv,
--      so every hue you pick has the same perceived brightness.
--   4. nudge each facet's lightness a little (vivid) so neighbours read as separate faces
-- The vertices drift slightly every frame (same triangles, new positions in a Mesh), so
-- the crystal-like landscape breathes. Click for a new seed and palette.

local gfx = require("core.gfx")
local Delaunay = require("delaunay")
local hsluv = require("hsluv")
local vivid = require("vivid")

local lg = love.graphics

local S = {
  title = "Low-Poly",
  subtitle = "Faceted Peaks",
  blurb = "Flat-shaded triangles from a Delaunay triangulation. Each facet samples a hidden scene to pick its colour.",
  techniques = {
    "Jittered grid + ridge-line points -> Delaunay triangulation",
    "Per-triangle colour from a 'scene function' sampled at the centroid",
    "HSLuv palette: hues rotate while perceived lightness stays constant",
    "Facet shading: small lightness offsets per triangle, lit side vs shadow side",
    "One Mesh in 'triangles' mode; vertices gently drift each frame",
  },
  libs = {
    "delaunay: Bowyer-Watson triangulation of the point set",
    "hsluv: perceptually even palettes",
    "vivid: lighten/darken each facet in HSL",
  },
  genres = { "Minimalist puzzle games", "Mobile casual / hyper-casual", "Stylised flight or exploration games", "Menus, loading screens, data-light UIs" },
  controls = "click to reroll the landscape and palette, W toggles the wireframe.",
  warmup = 1,
}

local function hsl(h, s, l) return hsluv.hsluv_to_rgb({ h % 360, s, l }) end

function S:ridge(x)
  local n = gfx.fbm(x * 0.0024 + self.seed, self.seed * 0.3, 4)
  local r = 1 - math.abs(n * 2 - 1)
  return 470 - (n * 0.5 + r * r * 0.5) * 330
end

function S:hill(x)
  return 590 - gfx.fbm(x * 0.004 + self.seed * 2, 1.3, 3) * 90
end

-- The hidden scene: returns r, g, b for any point.
function S:sample(x, y)
  local H = self.hue
  local ry = self:ridge(x)
  if y > self:hill(x) then
    local t = (y - 520) / 200
    return hsl(H + 150, 70, 38 - t * 14)            -- forest
  elseif y > 500 then
    local t = (y - 500) / 100
    return hsl(H + 230, 60, 52 - t * 12)            -- lake
  elseif y > ry then
    local slope = self:ridge(x + 6) - self:ridge(x - 6)
    local lit = slope < 0 and 1 or 0                -- faces toward the sun (on the right)
    if y < ry + 34 and ry < 300 then
      return hsl(H + 250, 25, 88 + lit * 6)         -- snow caps
    end
    local depth = (y - ry) / 160
    return hsl(H + 260, 35, 40 + lit * 14 - depth * 10) -- rock
  else
    local d = math.sqrt((x - 930) ^ 2 + (y - 210) ^ 2)
    if d < 80 then return hsl(H + 60, 90, 92) end   -- sun
    local t = y / 470
    return hsl(H + 260 + t * 120, 70, 30 + t * 48 + math.max(0, 1 - d / 500) * 12) -- sky
  end
end

function S:generate(seed, hue)
  self.seed = seed
  love.math.setRandomSeed(seed)
  self.hue = hue or love.math.random(0, 359)
  local pts = {}
  local function add(x, y) pts[#pts + 1] = Delaunay.Point(x, y) end
  local cols, rows = 24, 14
  for i = 0, cols do
    for j = 0, rows do
      local x = i / cols * 1280
      local y = j / rows * 720
      local edge = (i == 0 or i == cols or j == 0 or j == rows)
      if not edge then
        x = x + (love.math.random() - 0.5) * 1280 / cols * 0.9
        y = y + (love.math.random() - 0.5) * 720 / rows * 0.9
      end
      add(x, y)
    end
  end
  for x = 10, 1270, 26 do
    local ry = self:ridge(x)
    add(x, ry - 3)
    add(x + 13, ry + 3)
    add(x + 6, self:hill(x) + 2)
  end
  for x = 0, 1280, 40 do add(x, 500 + love.math.random() * 4) end
  for a = 0, 11 do add(930 + math.cos(a / 12 * math.pi * 2) * 82, 210 + math.sin(a / 12 * math.pi * 2) * 82) end

  self.points = pts
  self.base = {}
  for i, p in ipairs(pts) do self.base[i] = { p.x, p.y, love.math.random() * 6 } end
  local tris = Delaunay.triangulate(unpack(pts))

  -- One vertex per triangle corner, so every triangle can have its own flat colour.
  self.tris = {}
  local verts = {}
  for _, t in ipairs(tris) do
    local cx = (t.p1.x + t.p2.x + t.p3.x) / 3
    local cy = (t.p1.y + t.p2.y + t.p3.y) / 3
    local c = self:sample(cx, cy)
    local jitter = (love.math.random() - 0.5) * 0.06
    local r, g, b
    if jitter > 0 then r, g, b = vivid.lighten(jitter, c[1], c[2], c[3]) else r, g, b = vivid.darken(-jitter, c[1], c[2], c[3]) end
    self.tris[#self.tris + 1] = { t.p1.id, t.p2.id, t.p3.id }
    for _, p in ipairs({ t.p1, t.p2, t.p3 }) do
      verts[#verts + 1] = { p.x, p.y, 0, 0, r, g, b, 1 }
    end
  end
  self.verts = verts
  self.mesh = lg.newMesh(verts, "triangles", "stream")
end

function S:load()
  self.t = 0
  self.wire = false
  self:generate(17, 0) -- hue 0 = a violet-to-orange sunset palette
end

function S:mousepressed()
  self:generate(love.math.random(1, 99999))
end

function S:keypressed(k)
  if k == "w" then self.wire = not self.wire end
end

function S:update(dt)
  self.t = self.t + dt
  -- Breathe: move every vertex a little around its home position.
  local pos = {}
  for i, p in ipairs(self.points) do
    local b = self.base[i]
    local edge = b[1] <= 0 or b[1] >= 1280 or b[2] <= 0 or b[2] >= 720
    local amp = edge and 0 or 2.5
    pos[p.id] = { b[1] + math.sin(self.t * 0.9 + b[3]) * amp, b[2] + math.cos(self.t * 0.7 + b[3] * 1.3) * amp }
  end
  local k = 1
  for _, t in ipairs(self.tris) do
    for c = 1, 3 do
      local v = self.verts[k]
      local p = pos[t[c]]
      v[1], v[2] = p[1], p[2]
      k = k + 1
    end
  end
  self.mesh:setVertices(self.verts)
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.mesh)
  if self.wire then
    lg.setColor(1, 1, 1, 0.35)
    lg.setLineWidth(1)
    for i = 1, #self.verts, 3 do
      local a, b, c = self.verts[i], self.verts[i + 1], self.verts[i + 2]
      lg.polygon("line", a[1], a[2], b[1], b[2], c[1], c[2])
    end
  end
  -- Two flat birds: just polylines.
  for i = 0, 2 do
    local x = (self.t * 40 + i * 70) % 1500 - 100
    local y = 140 + i * 22 + math.sin(self.t + i) * 6
    local f = math.sin(self.t * 6 + i) * 6
    lg.setColor(hsl(self.hue + 270, 40, 20))
    lg.setLineWidth(3)
    lg.line(x - 12, y - f, x, y, x + 12, y - f)
  end
end

return S
