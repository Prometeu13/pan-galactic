-- LOW-POLY, scene 3: a faceted stag in a triangle forest.
--
-- Characters work the same way as landscapes. The stag is a handful of outlines typed
-- as coordinate lists (torso + neck + head, four legs, an ear); core/facets.lua fills
-- each with triangles, and a colour function shades them: lighter where the light
-- hits (upper left), a cream chest and rump, darker far-side legs. Antlers are tapered
-- quads along a few polylines. The forest is three stacked triangles per pine, each
-- split into a lit half and a shaded half: the smallest possible "3D" tree.

local gfx = require("core.gfx")
local facets = require("core.facets")
local hsluv = require("hsluv")
local vivid = require("vivid")

local lg = love.graphics
local GROUND = 588

local S = {
  title = "Low-Poly",
  subtitle = "The Forest King",
  blurb = "A low-poly stag made from typed outlines filled with facets, standing in a forest of two-tone triangle pines at golden hour.",
  techniques = {
    "Character from outlines: each body part is a coordinate list -> facets",
    "Colour function = art direction: light from upper left, cream chest, dark far legs",
    "Antlers: tapered quads along polylines, mirrored and darkened for the far one",
    "Pines: three stacked triangles, each split into a lit and a shaded half",
    "Depth by layers: far trees are small, pale and warm; near ones big and dark",
    "Backdrop: a triangle grid coloured by distance from the sun",
  },
  libs = {
    "delaunay: triangulates the stag's outlines and the backdrop (via core/facets.lua)",
    "hsluv: palette with controlled lightness",
    "vivid: per-facet lightness jitter",
  },
  genres = { "Stylised wildlife / nature games", "Low-poly adventure and walking sims", "Card art and character portraits", "Calm puzzle games" },
  controls = "click: the stag lifts its head and the facets reroll.",
  warmup = 2,
}

local function hsl(h, s, l)
  local c = hsluv.hsluv_to_rgb({ h % 360, gfx.clamp(s, 0, 100), gfx.clamp(l, 0, 100) })
  return c[1], c[2], c[3]
end

-- Stag outlines. Origin = ground under the body; x right, y up is negative.
local TORSO = {
  -165, -172, -150, -192, -92, -206, -20, -208, 24, -216, 52, -228,     -- tail, rump, back, withers
  78, -262, 96, -302, 104, -336, 126, -348, 150, -334, 170, -318,        -- neck, crown, brow, nose bridge
  188, -304, 186, -292, 168, -288, 140, -288, 122, -274,                -- nose, chin, jaw, throat
  108, -236, 100, -196, 94, -150, 66, -122,                             -- neck front, chest
  -36, -114, -100, -124, -150, -142,                                    -- belly, flank
}
local LEGS = {
  { pts = { 58, -134, 88, -144, 84, -74, 79, -8, 92, 0, 64, 0, 62, -66 }, far = false },
  { pts = { 24, -126, 48, -126, 44, -66, 40, -6, 50, 0, 26, 0, 28, -64 }, far = true },
  { pts = { -152, -154, -104, -138, -110, -88, -94, -62, -98, -6, -86, 0, -122, 0, -120, -56, -140, -88 }, far = false },
  { pts = { -118, -132, -86, -130, -84, -82, -70, -62, -74, -6, -62, 0, -98, 0, -94, -56, -108, -84 }, far = true },
}
local EAR = { 100, -334, 76, -356, 112, -346 }
-- antler: a main beam and tines, as polylines {x, y, ...} with a starting width
local ANTLER = {
  { 112, -346, 102, -392, 76, -430, 44, -452, 20, -456, w = 9 },
  { 104, -380, 128, -412, 134, -436, w = 5 },
  { 90, -412, 112, -448, 110, -470, w = 5 },
  { 72, -432, 84, -474, 78, -492, w = 4.5 },
  { 48, -450, 46, -488, w = 4 },
}

local function ribbon(line, ox, oy, shade)
  local n = #line / 2
  for i = 1, n - 1 do
    local x1, y1, x2, y2 = line[i * 2 - 1] + ox, line[i * 2] + oy, line[i * 2 + 1] + ox, line[i * 2 + 2] + oy
    local w1 = line.w * (1 - (i - 1) / (n - 1) * 0.75)
    local w2 = line.w * (1 - i / (n - 1) * 0.75)
    if i == n - 1 then w2 = 0.6 end
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / len, dx / len
    local r, g, b = hsl(52, 34, (i % 2 == 0 and 78 or 68) * shade)
    lg.setColor(r, g, b)
    lg.polygon("fill", x1 + nx * w1 / 2, y1 + ny * w1 / 2, x2 + nx * w2 / 2, y2 + ny * w2 / 2, x2, y2, x1, y1)
    r, g, b = hsl(45, 38, (i % 2 == 0 and 58 or 50) * shade)
    lg.setColor(r, g, b)
    lg.polygon("fill", x1 - nx * w1 / 2, y1 - ny * w1 / 2, x2 - nx * w2 / 2, y2 - ny * w2 / 2, x2, y2, x1, y1)
  end
end

function S:buildStag(seed)
  local function coat(far)
    return function(cx, cy, r)
      -- light from the upper left
      local lit = gfx.clamp(0.55 - cx / 520 - (cy + 200) / 300, 0, 1)
      local L = 30 + lit * 30 + (r - 0.5) * 10
      local h, s = 30, 62
      -- cream chest / throat and rump patch
      local chest = math.max(0, 1 - math.sqrt((cx - 96) ^ 2 + (cy + 190) ^ 2) / 60)
      local rump = math.max(0, 1 - math.sqrt((cx + 160) ^ 2 + (cy + 160) ^ 2) / 44)
      local belly = gfx.clamp((cy + 138) / 30, 0, 1) * 0.5
      local cream = math.max(chest, rump, belly)
      L = L + cream * 26
      s = s - cream * 30
      h = h + cream * 16
      if cy > -60 then L = L - 14 s = s - 20 end                -- lower legs are dark
      if cx > 160 and cy < -280 then L = 14 s = 20 end          -- muzzle
      if far then L = L * 0.62 end
      return hsl(h, s, L)
    end
  end
  self.legs = {}
  for i, leg in ipairs(LEGS) do
    self.legs[i] = { tris = facets.fromOutline(leg.pts, 26, coat(leg.far), seed + i), far = leg.far }
  end
  self.torso = facets.fromOutline(TORSO, 30, coat(false), seed)
  self.ear = facets.fromOutline(EAR, 30, coat(false), seed + 9)
end

function S:load()
  self.t = 0
  self.look = 0
  self:buildStag(11)
  -- backdrop: big facets, gold near the sun, teal-green in the shade
  self.back = facets.mesh(facets.grid(0, 0, 1280, 720, 86, function(cx, cy, r)
    local d = math.sqrt((cx - 860) ^ 2 + (cy - 250) ^ 2) / 760
    local k = gfx.clamp(1 - d, 0, 1) ^ 1.6
    local rr, gg, bb = hsl(150 - k * 20, 50, 30 + cy / 720 * 6)
    rr, gg, bb = gfx.lerp(rr, 1, k), gfx.lerp(gg, 0.86, k), gfx.lerp(bb, 0.55, k)
    local j = (r - 0.5) * 0.06
    if j > 0 then return vivid.lighten(j, rr, gg, bb) end
    return vivid.darken(-j, rr, gg, bb)
  end, 4))
  -- ground: a knoll the stag stands on
  local knoll = { 0, 720, 0, 640 }
  for i = 0, 20 do
    local x = i * 64
    knoll[#knoll + 1] = x
    knoll[#knoll + 1] = GROUND + 44 - math.exp(-((x - 640) / 330) ^ 2) * 46 + gfx.fbm(i * 0.6, 3, 2) * 16
  end
  knoll[#knoll + 1] = 1280
  knoll[#knoll + 1] = 720
  self.knollOutline = knoll
  self.ground = facets.mesh(facets.fromOutline(knoll, 44, function(cx, cy, r)
    local lit = gfx.clamp(1 - math.abs(cx - 700) / 600, 0, 1)
    return hsl(125 - lit * 30, 55, 16 + lit * 22 + (GROUND + 60 - cy) * 0.08 + (r - 0.5) * 8)
  end, 8))
  -- pines: x, base y, height, layer (1 far .. 3 near)
  love.math.setRandomSeed(6)
  self.pines = {}
  for layer = 1, 3 do
    local n = ({ 18, 12, 7 })[layer]
    for i = 1, n do
      local x = (i - 0.5) / n * 1400 - 60 + love.math.random(-40, 40)
      local h = ({ 190, 330, 560 })[layer] * (0.75 + love.math.random() * 0.5)
      -- keep the middle clear in the near layers so the stag reads
      if not (layer >= 2 and x > 380 and x < 960) then
        self.pines[#self.pines + 1] = { x = x, y = ({ 520, 570, 700 })[layer] + love.math.random(-10, 10), h = h, layer = layer, p = love.math.random() * 6 }
      end
    end
  end
  self.leaves = {}
  for i = 1, 26 do
    self.leaves[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), v = 20 + love.math.random() * 30, p = love.math.random() * 6, s = 4 + love.math.random() * 6 }
  end
  self.flies = {}
  for i = 1, 16 do self.flies[i] = { x = love.math.random(200, 1100), y = love.math.random(380, 640), p = love.math.random() * 6 } end
end

function S:mousepressed()
  self.look = 1
  self:buildStag(love.math.random(1, 9999))
end

function S:update(dt)
  self.t = self.t + dt
  self.look = math.max(0, self.look - dt * 0.5)
  for _, l in ipairs(self.leaves) do
    l.y = l.y + l.v * dt
    l.x = l.x + math.sin(self.t * 1.3 + l.p) * 24 * dt
    if l.y > 730 then l.y = -10 l.x = love.math.random(0, 1280) end
  end
end

local function pine(x, y, h, layer, sway)
  local tint = ({ 0.62, 0.3, 0 })[layer]
  local warm = { 1, 0.84, 0.56 }
  local function col(hh, s, l)
    local r, g, b = hsl(hh, s, l)
    return gfx.lerp(r, warm[1], tint), gfx.lerp(g, warm[2], tint), gfx.lerp(b, warm[3], tint)
  end
  local w = h * 0.2
  -- trunk
  lg.setColor(col(30, 40, 16))
  lg.polygon("fill", x - w * 0.12, y, x + w * 0.12, y, x + w * 0.06, y - h * 0.3, x - w * 0.06, y - h * 0.3)
  for k = 0, 3 do
    local by = y - h * (0.16 + k * 0.2)
    local hw = w * (1 - k * 0.2)
    local top = by - h * 0.3
    local sx = sway * (k + 1) * 0.5
    lg.setColor(col(150, 60, 30 - layer * 4 + k * 3))          -- lit half
    lg.polygon("fill", x - hw, by, x, by, x + sx, top)
    lg.setColor(col(165, 60, 18 - layer * 3 + k * 2))          -- shaded half
    lg.polygon("fill", x, by, x + hw, by, x + sx, top)
  end
end

function S:drawStag(x, y, s)
  local t = self.t
  local breath = 1 + math.sin(t * 1.4) * 0.006
  lg.push()
  lg.translate(x, y)
  lg.scale(s * breath, s / breath)
  local function tris(list)
    for _, tr in ipairs(list) do
      lg.setColor(tr[7], tr[8], tr[9])
      lg.polygon("fill", tr[1], tr[2], tr[3], tr[4], tr[5], tr[6])
    end
  end
  -- far legs, far antler, then the body, near legs, near antler
  for _, leg in ipairs(self.legs) do if leg.far then tris(leg.tris) end end
  for _, line in ipairs(ANTLER) do ribbon(line, 14, 4, 0.62) end
  tris(self.torso)
  for _, leg in ipairs(self.legs) do if not leg.far then tris(leg.tris) end end
  -- hooves
  lg.setColor(0.07, 0.06, 0.06)
  lg.polygon("fill", 64, 0, 92, 0, 80, -10, 66, -10)
  lg.polygon("fill", -122, 0, -86, 0, -98, -10, -120, -10)
  -- ear twitch
  lg.push()
  lg.translate(100, -338)
  lg.rotate(math.max(0, math.sin(t * 1.7) - 0.9) * 3)
  lg.translate(-100, 338)
  tris(self.ear)
  lg.pop()
  for _, line in ipairs(ANTLER) do ribbon(line, 0, 0, 1) end
  -- eye with a highlight, nostril
  lg.setColor(0.05, 0.04, 0.04)
  lg.polygon("fill", 132, -328, 141, -332, 146, -325, 138, -320)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", 138, -329, 142, -329, 140, -326)
  lg.setColor(0.05, 0.04, 0.04)
  lg.polygon("fill", 180, -302, 186, -300, 182, -296)
  -- breath in the cold air: a few fading triangles
  for k = 0, 3 do
    local u = (t * 0.5 + k / 4) % 1
    lg.setColor(1, 1, 1, 0.4 * (1 - u))
    local bx, by = 196 + u * 50, -300 - u * 14 + math.sin(k * 2) * 6
    lg.polygon("fill", bx, by - 6 - u * 8, bx + 12 + u * 12, by, bx, by + 6 + u * 8)
  end
  lg.pop()
end

function S:draw()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.back)
  -- sun: nested polygons
  for ring = 3, 1, -1 do
    local r = ({ 44, 78, 124 })[ring]
    local pts = {}
    for i = 0, 8 do
      local a = i / 9 * math.pi * 2 + t * 0.04 * (ring % 2 == 0 and -1 or 1)
      pts[#pts + 1] = 860 + math.cos(a) * r
      pts[#pts + 1] = 250 + math.sin(a) * r
    end
    lg.setColor(1, 0.95, 0.75, ({ 1, 0.4, 0.2 })[ring])
    lg.polygon("fill", pts)
  end
  -- light shafts: long translucent triangles fanning down from the sun
  lg.setBlendMode("add")
  for k = 0, 6 do
    local a = math.pi * 0.5 + (k - 3) * 0.24 + math.sin(t * 0.2 + k) * 0.03
    local a2 = a + 0.08
    lg.setColor(1, 0.9, 0.6, 0.06 + 0.03 * math.sin(t * 0.6 + k * 2))
    lg.polygon("fill", 860, 250, 860 + math.cos(a) * 900, 250 + math.sin(a) * 900, 860 + math.cos(a2) * 900, 250 + math.sin(a2) * 900)
  end
  lg.setBlendMode("alpha")
  -- far and middle pines
  for layer = 1, 2 do
    for _, p in ipairs(self.pines) do
      if p.layer == layer then pine(p.x, p.y, p.h, layer, math.sin(t * 0.8 + p.p) * 3) end
    end
    -- a band of mist between layers
    lg.setColor(1, 0.9, 0.66, layer == 1 and 0.22 or 0.12)
    lg.polygon("fill", 0, 470 + layer * 40, 1280, 450 + layer * 40, 1280, 600, 0, 600)
  end
  lg.setColor(1, 1, 1)
  lg.draw(self.ground)
  -- rim of light along the knoll
  lg.setColor(1, 0.9, 0.6, 0.5)
  lg.setLineWidth(2)
  local rim = {}
  for i = 5, #self.knollOutline - 2 do rim[#rim + 1] = self.knollOutline[i] end
  lg.line(rim)
  -- ferns and rocks on the knoll
  for k = 0, 16 do
    local x = 120 + k * 66 + gfx.hash(k) * 30
    local y = GROUND + 46 - math.exp(-((x - 640) / 330) ^ 2) * 46 + 12
    if k % 4 == 0 then
      lg.setColor(hsl(250, 12, 36))
      lg.polygon("fill", x - 20, y + 8, x - 8, y - 14, x + 12, y - 10, x + 22, y + 8)
      lg.setColor(hsl(250, 12, 52))
      lg.polygon("fill", x - 20, y + 8, x - 8, y - 14, x, y + 8)
    else
      for j = -2, 2 do
        lg.setColor(hsl(120 + j * 8, 60, 30 + (j + 2) * 5))
        lg.polygon("fill", x, y + 6, x + j * 12 + math.sin(t + k) * 2, y - 26 + math.abs(j) * 6, x + j * 6 + 4, y + 6)
      end
    end
  end
  self:drawStag(600, GROUND + 2, 1.0)
  -- near pines frame the picture
  for _, p in ipairs(self.pines) do
    if p.layer == 3 then pine(p.x, p.y, p.h, 3, math.sin(t * 0.8 + p.p) * 4) end
  end
  -- drifting leaves (triangles) and fireflies (diamonds)
  for _, l in ipairs(self.leaves) do
    local a = t * 2 + l.p
    lg.setColor(1, 0.72, 0.28, 0.85)
    lg.polygon("fill", l.x + math.cos(a) * l.s, l.y + math.sin(a) * l.s, l.x + math.cos(a + 2.2) * l.s, l.y + math.sin(a + 2.2) * l.s, l.x + math.cos(a + 4.2) * l.s * 0.6, l.y + math.sin(a + 4.2) * l.s * 0.6)
  end
  lg.setBlendMode("add")
  for _, f in ipairs(self.flies) do
    local x = f.x + math.sin(t * 0.6 + f.p) * 30
    local y = f.y + math.cos(t * 0.8 + f.p * 2) * 16
    local a = 0.5 + 0.5 * math.sin(t * 3 + f.p)
    lg.setColor(1, 1, 0.6, a)
    lg.polygon("fill", x, y - 4, x + 4, y, x, y + 4, x - 4, y)
    lg.setColor(1, 1, 0.6, a * 0.2)
    lg.polygon("fill", x, y - 12, x + 12, y, x, y + 12, x - 12, y)
  end
  lg.setBlendMode("alpha")
end

return S
