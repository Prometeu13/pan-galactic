-- LOW-POLY, scene 2: the tip of the iceberg.
--
-- A split view: a little above the waterline, a lot below it. The iceberg is ONE
-- outline, turned into facets by core/facets.lua (outline points + scattered interior
-- points -> Delaunay -> keep the triangles inside). The colour function does the art
-- direction: above the waterline facets are white-to-pale-blue, lit from the upper
-- left; below it they sink into teal and navy with depth. Same recipe for the far
-- mountains, the sea floor and the whale, just different outlines and palettes.

local gfx = require("core.gfx")
local facets = require("core.facets")
local hsluv = require("hsluv")
local vivid = require("vivid")

local lg = love.graphics
local SEA = 250              -- waterline

local S = {
  title = "Low-Poly",
  subtitle = "Tip of the Iceberg",
  blurb = "A split-level arctic scene: one outline becomes a faceted iceberg, bright above the waterline and deep blue below, with a low-poly whale.",
  techniques = {
    "Outline -> facets: edge points + interior points -> Delaunay -> trim outside",
    "Colour function per facet: light direction above water, depth fade below",
    "The whale is five outlines faceted the same way, bent by a sine along its body",
    "Sky and water are jittered triangle grids coloured by height",
    "Waterline: a strip of triangles whose top vertices bob",
    "God rays and bubbles keep to the style: triangles and hexagons only",
  },
  libs = {
    "delaunay: triangulates every outline (through core/facets.lua)",
    "hsluv: even-brightness blues for the depth gradient",
    "vivid: per-facet lightness jitter",
  },
  genres = { "Minimalist exploration / diving games", "Puzzle games with a calm mood", "Educational and data-art pieces", "Mobile wallpapers and menu scenes" },
  controls = "click: reroll the iceberg's facets.",
  warmup = 2,
}

local function hsl(h, s, l)
  local c = hsluv.hsluv_to_rgb({ h % 360, s, l })
  return c[1], c[2], c[3]
end

local function jitter(r, g, b, amount)
  if amount > 0 then return vivid.lighten(amount, r, g, b) end
  return vivid.darken(-amount, r, g, b)
end

-- the iceberg's silhouette: small peaks above SEA, a huge keel below
local BERG = {
  470, SEA, 500, 196, 540, 150, 575, 168, 610, 96, 660, 60, 700, 110, 730, 92, 770, 150, 810, 178, 840, SEA,
  900, 300, 930, 380, 905, 450, 860, 520, 830, 600, 760, 650, 700, 690, 640, 660, 590, 610, 520, 590, 470, 520,
  410, 470, 380, 400, 400, 320, 440, 280,
}

local WHALE_BODY = { -150, 0, -120, -28, -60, -44, 20, -46, 90, -34, 150, -16, 190, -4, 150, 14, 90, 30, 10, 38, -70, 34, -125, 20 }
local WHALE_TAIL = { 186, -4, 230, -40, 262, -46, 244, -8, 262, 30, 228, 28 }
local WHALE_FIN = { -40, 30, -10, 34, 10, 78, -22, 62 }
local WHALE_BELLY = { -146, 6, -125, 20, -70, 34, 10, 38, 60, 33, 0, 20, -80, 14 }

function S:build(seed)
  self.seed = seed
  -- sky: warm near the horizon, cool above
  self.skyTris = facets.grid(0, 0, 1280, SEA, 70, function(cx, cy, r)
    local u = cy / SEA
    local sun = math.max(0, 1 - math.sqrt((cx - 980) ^ 2 + (cy - 150) ^ 2) / 420)
    local rr, gg, bb = hsl(252 - u * 14, 72, 46 + u * 30)
    -- warm toward the sun (mixed in RGB so it never passes through green)
    local k = sun ^ 1.5
    rr, gg, bb = gfx.lerp(rr, 1, k), gfx.lerp(gg, 0.84, k), gfx.lerp(bb, 0.62, k)
    return jitter(rr, gg, bb, (r - 0.5) * 0.05)
  end, seed)
  -- water: light teal at the surface, navy in the deep
  self.seaTris = facets.grid(0, SEA, 1280, 720 - SEA, 80, function(cx, cy, r)
    local d = (cy - SEA) / (720 - SEA)
    local rr, gg, bb = hsl(236 + d * 26, 88, 56 - d * 40)
    return jitter(rr, gg, bb, (r - 0.5) * 0.045)
  end, seed + 1)
  -- far mountains on the horizon
  local mount = { 0, SEA }
  for i = 0, 16 do
    local x = i * 44
    mount[#mount + 1] = x
    mount[#mount + 1] = SEA - 26 - gfx.fbm(i * 0.5 + 3, 1, 3) * 120 * (1 - i / 22)
  end
  mount[#mount + 1] = 740
  mount[#mount + 1] = SEA
  self.mountTris = facets.fromOutline(mount, 34, function(cx, cy, r)
    local h = (SEA - cy) / 140
    local rr, gg, bb = hsl(255, 34, 62 + h * 30 + (r - 0.5) * 12)
    return rr, gg, bb
  end, seed + 2)
  -- the iceberg
  self.bergTris = facets.fromOutline(BERG, 36, function(cx, cy, r)
    if cy < SEA then
      -- lit from the upper left: facets on the left/top are whiter
      local lit = gfx.clamp(0.5 + (640 - cx) / 500 + (150 - cy) / 300, 0, 1)
      local rr, gg, bb = hsl(240, 60 - lit * 48, 74 + lit * 24)
      return jitter(rr, gg, bb, (r - 0.5) * 0.07)
    end
    local d = (cy - SEA) / (700 - SEA)
    local side = gfx.clamp(0.5 + (640 - cx) / 600, 0, 1)
    local rr, gg, bb = hsl(222 + d * 30, 80, 80 - d * 46 + side * 8)
    return jitter(rr, gg, bb, (r - 0.5) * 0.09)
  end, seed + 3)
  -- sea floor
  local floor = { 0, 720, 0, 640 }
  for i = 1, 20 do
    floor[#floor + 1] = i * 64
    floor[#floor + 1] = 650 + gfx.fbm(i * 0.4 + 7, 2, 3) * 60 - 30
  end
  floor[#floor + 1] = 1280
  floor[#floor + 1] = 720
  self.floorTris = facets.fromOutline(floor, 40, function(cx, cy, r)
    local rr, gg, bb = hsl(262, 60, 10 + r * 7)
    return rr, gg, bb
  end, seed + 4)
  self.backMesh = facets.mesh(self.skyTris, self.mountTris, self.seaTris)
  self.frontMesh = facets.mesh(self.floorTris)
  self.bergMesh = facets.mesh(self.bergTris)

  -- the whale, in its own coordinates (nose at the left)
  local function whaleCol(light)
    return function(cx, cy, r)
      local top = gfx.clamp(0.5 - cy / 80, 0, 1)
      local rr, gg, bb = hsl(258, 44, light + top * 16 + (r - 0.5) * 8)
      return rr, gg, bb
    end
  end
  self.whale = {
    facets.fromOutline(WHALE_TAIL, 22, whaleCol(22), 5),
    facets.fromOutline(WHALE_BODY, 24, whaleCol(26), 6),
    facets.fromOutline(WHALE_BELLY, 22, function(cx, cy, r) local a, b, c = hsl(245, 26, 74 + r * 12) return a, b, c end, 7),
    facets.fromOutline(WHALE_FIN, 20, whaleCol(18), 8),
  }
end

function S:load()
  self.t = 0
  self:build(7)
  love.math.setRandomSeed(3)
  self.bubbles = {}
  for i = 1, 26 do self.bubbles[i] = { x = love.math.random(0, 1280), y = love.math.random(SEA, 720), v = 16 + love.math.random() * 26, r = 3 + love.math.random() * 7, p = love.math.random() * 6 } end
  self.floes = {}
  for i = 1, 9 do
    local x = love.math.random(0, 1280)
    if math.abs(x - 655) > 230 then self.floes[#self.floes + 1] = { x = x, w = 30 + love.math.random() * 70, p = love.math.random() * 6 } end
  end
end

function S:mousepressed()
  self:build(love.math.random(1, 9999))
end

function S:update(dt)
  self.t = self.t + dt
  for _, b in ipairs(self.bubbles) do
    b.y = b.y - b.v * dt
    if b.y < SEA + 6 then b.y = 720 b.x = love.math.random(0, 1280) end
  end
end

local function hexagon(x, y, r)
  local p = {}
  for i = 0, 5 do
    p[#p + 1] = x + math.cos(i / 6 * math.pi * 2) * r
    p[#p + 1] = y + math.sin(i / 6 * math.pi * 2) * r
  end
  return p
end

function S:drawWhale(x, y, scale)
  local t = self.t
  lg.push()
  lg.translate(x, y + math.sin(t * 0.8) * 10)
  lg.scale(scale)
  lg.rotate(math.sin(t * 0.8 + 1) * 0.04)
  for _, part in ipairs(self.whale) do
    for _, tr in ipairs(part) do
      -- bend: vertices further toward the tail swing more
      local function bend(px, py)
        local k = math.max(0, (px + 20) / 280)
        return px, py + math.sin(t * 1.6 - px * 0.012) * 22 * k * k
      end
      local x1, y1 = bend(tr[1], tr[2])
      local x2, y2 = bend(tr[3], tr[4])
      local x3, y3 = bend(tr[5], tr[6])
      lg.setColor(tr[7], tr[8], tr[9])
      lg.polygon("fill", x1, y1, x2, y2, x3, y3)
    end
  end
  -- eye
  lg.setColor(0.04, 0.05, 0.12)
  lg.polygon("fill", hexagon(-112, -2, 4))
  lg.pop()
end

function S:draw()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.backMesh)
  -- low-poly sun: a decagon with a paler ring of triangles
  for ring = 2, 1, -1 do
    local r = ring == 2 and 74 or 48
    local pts = {}
    for i = 0, 9 do
      local a = i / 10 * math.pi * 2 + t * 0.05 * (ring == 2 and 1 or -1)
      pts[#pts + 1] = 980 + math.cos(a) * r
      pts[#pts + 1] = 150 + math.sin(a) * r
    end
    lg.setColor(1, ring == 2 and 0.86 or 0.96, ring == 2 and 0.62 or 0.84, ring == 2 and 0.5 or 1)
    lg.polygon("fill", pts)
  end
  -- god rays under water: long translucent triangles from the surface
  lg.setBlendMode("add")
  for k = 0, 6 do
    local x = 80 + k * 190 + math.sin(t * 0.3 + k) * 30
    local a = 0.05 + 0.03 * math.sin(t * 0.7 + k * 1.3)
    lg.setColor(0.5, 0.75, 1, a)
    lg.polygon("fill", x, SEA, x + 70, SEA, x - 60, 700)
    lg.polygon("fill", x + 70, SEA, x + 30, 700, x - 60, 700)
  end
  lg.setBlendMode("alpha")
  self:drawWhale(1030, 520, 0.95)
  lg.setColor(1, 1, 1)
  lg.draw(self.frontMesh)
  -- kelp-like crystal shards on the sea floor
  for k = 0, 14 do
    local x = 40 + k * 88 + gfx.hash(k) * 30
    local h = 26 + gfx.hash(k + 4) * 50
    local sw = math.sin(t + k) * 5
    local r, g, b = hsl(200 + gfx.hash(k) * 40, 70, 34)
    lg.setColor(r, g, b)
    lg.polygon("fill", x - 7, 690, x + 7, 690, x + sw, 690 - h)
    lg.setColor(r * 1.4, g * 1.4, b * 1.4)
    lg.polygon("fill", x - 7, 690, x, 690, x + sw, 690 - h)
  end
  lg.setColor(1, 1, 1)
  lg.draw(self.bergMesh)
  -- wireframe hint on the iceberg's facets (thin, pale)
  lg.setColor(1, 1, 1, 0.16)
  lg.setLineWidth(1)
  for _, tr in ipairs(self.bergTris) do lg.polygon("line", tr[1], tr[2], tr[3], tr[4], tr[5], tr[6]) end

  -- small floes and the surface strip: triangles whose top corners bob
  for _, f in ipairs(self.floes) do
    local y = SEA + math.sin(t * 1.3 + f.p) * 2
    lg.setColor(0.96, 0.98, 1)
    lg.polygon("fill", f.x, y, f.x + f.w * 0.3, y - f.w * 0.26, f.x + f.w * 0.7, y - f.w * 0.16, f.x + f.w, y)
    lg.setColor(0.78, 0.88, 0.98)
    lg.polygon("fill", f.x + f.w * 0.3, y - f.w * 0.26, f.x + f.w * 0.7, y - f.w * 0.16, f.x + f.w * 0.5, y)
    lg.setColor(0.45, 0.78, 0.9, 0.8)
    lg.polygon("fill", f.x + 4, y, f.x + f.w - 4, y, f.x + f.w * 0.5, y + f.w * 0.3)
  end
  local step = 40
  for x = -step, 1280, step do
    local y1 = SEA + math.sin(t * 1.5 + x * 0.02) * 4
    local y2 = SEA + math.sin(t * 1.5 + (x + step) * 0.02) * 4
    local ym = SEA + 12 + math.sin(t * 1.1 + x * 0.05) * 3
    lg.setColor(0.86, 0.97, 1, 0.75)
    lg.polygon("fill", x, y1, x + step, y2, x + step / 2, ym)
    lg.setColor(0.5, 0.85, 0.95, 0.5)
    lg.polygon("fill", x + step / 2, ym, x + step * 1.5, ym + 2, x + step, y2)
  end
  -- a kayak on the surface with a paddler
  local kx = 240 + math.sin(t * 0.2) * 60
  local ky = SEA + math.sin(t * 1.5 + kx * 0.02) * 4 - 2
  lg.setColor(0.92, 0.36, 0.2)
  lg.polygon("fill", kx - 54, ky - 4, kx + 54, ky - 4, kx + 30, ky + 8, kx - 30, ky + 8)
  lg.setColor(0.72, 0.24, 0.14)
  lg.polygon("fill", kx - 54, ky - 4, kx, ky - 4, kx - 30, ky + 8)
  lg.setColor(0.14, 0.2, 0.34)
  lg.polygon("fill", kx - 9, ky - 4, kx + 9, ky - 4, kx + 6, ky - 28, kx - 6, ky - 28)
  lg.setColor(0.98, 0.8, 0.62)
  lg.polygon("fill", hexagon(kx, ky - 36, 8))
  lg.setColor(0.98, 0.86, 0.3)
  lg.polygon("fill", kx - 9, ky - 40, kx + 9, ky - 40, kx, ky - 50)
  local pa = math.sin(t * 2) * 0.5
  lg.setColor(0.2, 0.16, 0.14)
  lg.setLineWidth(3)
  lg.line(kx - math.cos(pa) * 40, ky - 18 - math.sin(pa) * 26, kx + math.cos(pa) * 40, ky - 18 + math.sin(pa) * 26)
  -- penguins on the berg: two triangles and a hexagon each
  for i, p in ipairs({ { 596, 126 }, { 742, 104 }, { 716, 108 } }) do
    local px, py = p[1], p[2] + ((i == 3) and math.abs(math.sin(t * 3)) * -6 or 0)
    lg.setColor(0.1, 0.12, 0.2)
    lg.polygon("fill", px - 8, py, px + 8, py, px, py - 26)
    lg.setColor(0.97, 0.97, 1)
    lg.polygon("fill", px - 4, py - 1, px + 5, py - 1, px + 1, py - 17)
    lg.setColor(0.1, 0.12, 0.2)
    lg.polygon("fill", hexagon(px, py - 27, 6))
    lg.setColor(1, 0.7, 0.2)
    lg.polygon("fill", px + 4, py - 28, px + 12, py - 26, px + 4, py - 24)
  end
  -- bubbles
  for _, b in ipairs(self.bubbles) do
    local d = (b.y - SEA) / (720 - SEA)
    lg.setColor(0.8, 0.95, 1, 0.16 + (1 - d) * 0.25)
    lg.setLineWidth(1.5)
    lg.polygon("line", hexagon(b.x + math.sin(t * 2 + b.p) * 5, b.y, b.r))
  end
  -- depth scale on the left, like an infographic
  lg.setColor(1, 1, 1, 0.55)
  lg.setLineWidth(1)
  lg.line(34, SEA, 34, 690)
  for k = 0, 4 do
    lg.line(34, SEA + k * 110, 46, SEA + k * 110)
    lg.print(k == 0 and "0 m" or ("-" .. k * 50 .. " m"), 52, SEA + k * 110 - 7)
  end
  lg.print("10 % above", 860, SEA - 60)
  lg.line(850, SEA - 52, 800, SEA - 70)
  lg.print("90 % below", 930, 400)
  lg.line(924, 408, 890, 420)
end

return S
