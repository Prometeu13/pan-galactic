-- WATERCOLOR: a little harbour painted in translucent washes.
--
-- Watercolour has three tells, and each one is a small trick:
--   1. Layered transparency: a shape is painted as 5 slightly different, very
--      transparent copies. Where they overlap the colour is deep; at the ragged edges
--      only one or two layers cover the paper.
--   2. Edge darkening: pigment pools at the edge of a drying wash, so each layer also
--      gets a thin darker outline.
--   3. Paper: a cold-press grain multiplied over everything, white paper left
--      unpainted at the deckled border, and soft "blooms" in the sky.
-- Static washes are painted once into a canvas; boats, gulls and water strokes move.

local gfx = require("core.gfx")
local vivid = require("vivid")

local lg = love.graphics
local SEA = 470

local S = {
  title = "Watercolor",
  subtitle = "Harbour Morning",
  blurb = "Translucent layered washes with ragged edges, pigment pooling, sky blooms and paper grain: a painted harbour.",
  techniques = {
    "Wash = 5 noise-jittered copies of a shape at ~15% opacity each",
    "Edges subdivided first, so the jitter makes organic ragged borders",
    "Pigment pooling: thin darker outline per layer (vivid.darken)",
    "Paper grain multiplied over the painting; deckled unpainted margin",
    "Static washes baked once; boats, gulls and ripples painted live",
  },
  libs = {
    "vivid: darker edge colours and lighter highlights from each wash colour",
  },
  genres = { "Storybook adventures and children's games", "Narrative and journaling games", "Cosy town / travel sims", "Gentle puzzle and hidden-object games" },
  warmup = 2,
}

-- Split each edge into short pieces so jitter can bend it.
local function subdivide(pts, step)
  local out = {}
  for i = 1, #pts, 2 do
    local j = (i + 2 > #pts) and 1 or i + 2
    local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[j], pts[j + 1]
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = math.max(1, math.floor(len / step))
    for k = 0, n - 1 do
      out[#out + 1] = x1 + (x2 - x1) * k / n
      out[#out + 1] = y1 + (y2 - y1) * k / n
    end
  end
  return out
end

-- Paint a wash: several jittered, transparent copies + darker pooled edges.
function S:wash(pts, color, opts)
  opts = opts or {}
  local layers, jitter, alpha = opts.layers or 5, opts.jitter or 7, opts.alpha or 0.16
  self.seed = (self.seed or 0) + 1
  local base = subdivide(pts, opts.step or 14)
  local er, eg, eb = vivid.darken(0.18, color[1], color[2], color[3])
  for k = 1, layers do
    local p = {}
    for i = 1, #base, 2 do
      local n1 = love.math.noise(base[i] * 0.02, base[i + 1] * 0.02, self.seed * 3.1 + k)
      local n2 = love.math.noise(base[i + 1] * 0.02, base[i] * 0.02, self.seed * 5.7 + k)
      p[#p + 1] = base[i] + (n1 - 0.5) * jitter * 2
      p[#p + 1] = base[i + 1] + (n2 - 0.5) * jitter * 2
    end
    lg.setColor(color[1], color[2], color[3], alpha)
    gfx.fillConcave(p)
    lg.setColor(er, eg, eb, alpha * 0.9)
    lg.setLineWidth(1.6)
    p[#p + 1] = p[1]; p[#p + 1] = p[2]
    lg.line(p)
  end
end

local function rect(x, y, w, h) return { x, y, x + w, y, x + w, y + h, x, y + h } end

function S:paintStatic()
  local c = function(h) return { gfx.hex(h) } end
  -- sky: big loose wash, then wet-in-wet blooms of warm and cool colour
  self:wash(rect(40, 40, 1200, 460), c("#8fbde0"), { alpha = 0.12, jitter = 16, step = 30 })
  for k = 1, 9 do
    local x, y, r = love.math.random(80, 1200), love.math.random(60, 330), love.math.random(60, 140)
    local blob = {}
    for a = 0, 11 do
      local ang = a / 12 * math.pi * 2
      blob[#blob + 1] = x + math.cos(ang) * r * (0.8 + love.math.random() * 0.4)
      blob[#blob + 1] = y + math.sin(ang) * r * 0.6
    end
    self:wash(blob, k % 3 == 0 and c("#f2b8a0") or c("#a9c9ea"), { alpha = 0.07, jitter = 18 })
  end
  self:wash(rect(40, 330, 1200, 170), c("#f6d2a8"), { alpha = 0.1, jitter = 14, step = 30 })
  -- distant hills, two layers
  local hills = gfx.closeRidge(gfx.ridge(1200, 430, 110, 0.004, 2.0, 30, 3), 480)
  for i = 1, #hills, 2 do hills[i] = hills[i] + 40 end
  self:wash(hills, c("#9aa6cf"), { alpha = 0.14 })
  local hills2 = gfx.closeRidge(gfx.ridge(1200, 455, 60, 0.006, 6.0, 30, 3), 480)
  for i = 1, #hills2, 2 do hills2[i] = hills2[i] + 40 end
  self:wash(hills2, c("#7f9a9a"), { alpha = 0.16 })
  -- harbour houses along the quay
  local houses = {
    { 120, 70, 60, "#e8a87c", "#b5554a" }, { 196, 60, 80, "#f1d38a", "#6b7fb5" },
    { 262, 74, 66, "#9fc7b0", "#b5554a" }, { 342, 64, 90, "#e6b8c8", "#7a5a8a" },
    { 412, 70, 70, "#f0e2c0", "#b5554a" },
  }
  for _, h in ipairs(houses) do
    local x, w, ht = h[1], h[2], h[3]
    local base = SEA
    self:wash(rect(x, base - ht, w, ht), c(h[4]), { alpha = 0.22, jitter = 3, step = 10 })
    self:wash({ x - 6, base - ht, x + w / 2, base - ht - 34, x + w + 6, base - ht }, c(h[5]), { alpha = 0.24, jitter = 3, step = 10 })
    for wx = x + 10, x + w - 18, 20 do
      self:wash(rect(wx, base - ht + 16, 10, 14), c("#4a5a7a"), { alpha = 0.25, layers = 3, jitter = 1.5, step = 6 })
    end
  end
  -- lighthouse on the breakwater
  self:wash({ 1010, SEA, 1050, SEA, 1042, SEA - 170, 1018, SEA - 170 }, c("#f4f0e8"), { alpha = 0.3, jitter = 2.5 })
  for k = 0, 2 do
    self:wash({ 1012 + k * 1.5, SEA - 40 - k * 50, 1048 - k * 1.5, SEA - 40 - k * 50, 1047 - k * 1.5, SEA - 62 - k * 50, 1013 + k * 1.5, SEA - 62 - k * 50 }, c("#c24a42"), { alpha = 0.25, jitter = 2, layers = 4 })
  end
  self:wash({ 1006, SEA - 170, 1054, SEA - 170, 1030, SEA - 200 }, c("#c24a42"), { alpha = 0.3, jitter = 2 })
  self:wash(rect(920, SEA - 6, 220, 14), c("#8a8478"), { alpha = 0.25, jitter = 3 })
  -- quay
  self:wash(rect(90, SEA - 4, 420, 16), c("#9a8a72"), { alpha = 0.25, jitter = 3 })
  -- sea: overlapping horizontal bands with wavy tops, deeper colour toward the viewer
  local bands = { { SEA, "#7fb2c2", 0.12 }, { SEA + 40, "#5f9fb4", 0.1 }, { SEA + 95, "#4f8faa", 0.1 }, { SEA + 150, "#3f7f9a", 0.1 } }
  for k, b in ipairs(bands) do
    local pts = {}
    for x = 40, 1240, 40 do
      pts[#pts + 1] = x
      pts[#pts + 1] = b[1] + math.sin(x * 0.012 + k * 2) * 8 + love.math.random(-4, 4)
    end
    pts[#pts + 1] = 1240; pts[#pts + 1] = 690
    pts[#pts + 1] = 40; pts[#pts + 1] = 690
    self:wash(pts, c(b[2]), { alpha = b[3], jitter = 10, step = 24 })
  end
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(321)
  -- paper with cold-press grain
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local n = love.math.noise(x * 0.35, y * 0.35) * 0.06 + gfx.fbm(x * 0.03, y * 0.03, 3) * 0.05
    return 1 - n * 0.8, 1 - n, 1 - n * 1.3, 1
  end)
  self.grain = lg.newImage(d)

  self.painting = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.painting)
  lg.clear(0, 0, 0, 0)
  self:paintStatic()
  lg.pop()

  -- deckled border: an irregular inner edge where the paint stops
  -- Each side is a run of quads from the screen edge to a ragged inner line.
  self.border = {}
  local k = 0
  local function side(points)
    local run = {}
    for _, p in ipairs(points) do
      local n = gfx.fbm(k * 0.05, 3.3, 3) * 30 + love.math.noise(k * 0.9, 7) * 10
      k = k + 1
      run[#run + 1] = { p[1], p[2], p[1] + p[3] * n, p[2] + p[4] * n }
    end
    self.border[#self.border + 1] = run
  end
  local top, bottom, left, right = {}, {}, {}, {}
  for x = 0, 1280, 8 do top[#top + 1] = { x, 0, 0, 1 }; bottom[#bottom + 1] = { x, 720, 0, -1 } end
  for y = 0, 720, 8 do left[#left + 1] = { 0, y, 1, 0 }; right[#right + 1] = { 1280, y, -1, 0 } end
  side(top); side(bottom); side(left); side(right)
  self.boatSeed = 1000
  self.sig = lg.newFont(16)
end

function S:update(dt)
  self.t = self.t + dt
end

-- Live washes reuse the same seeds every frame, so shapes keep their ragged edges
-- but don't boil.
function S:liveWash(seed, pts, color, opts)
  local saved = self.seed
  self.seed = seed
  self:wash(pts, color, opts)
  self.seed = saved
end

function S:draw()
  lg.setColor(gfx.hex("#f7f1e6"))
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.painting)
  lg.setBlendMode("alpha")

  -- boats bobbing, with their reflections
  local boats = { { 610, "#c24a42", 0 }, { 760, "#e8b84a", 1.7 }, { 880, "#4a6fa8", 3.1 } }
  for k, b in ipairs(boats) do
    local x = b[1] + math.sin(self.t * 0.3 + k) * 6
    local y = SEA + 22 + math.sin(self.t * 1.2 + b[3]) * 3
    local col = { gfx.hex(b[2]) }
    self:liveWash(self.boatSeed + k * 10, { x - 50, y, x + 50, y, x + 36, y + 18, x - 36, y + 18 }, col, { alpha = 0.3, jitter = 2.5, step = 10 })
    self:liveWash(self.boatSeed + k * 10 + 1, { x, y - 4, x, y - 70, x + 34, y - 8 }, { gfx.hex("#f4efe4") }, { alpha = 0.35, jitter = 2, step = 10 })
    lg.setColor(0.25, 0.2, 0.18, 0.7)
    lg.setLineWidth(2)
    lg.line(x, y, x, y - 74)
    -- reflection: broken horizontal strokes in the boat colour
    for r = 0, 4 do
      local w = 70 - r * 10 + math.sin(self.t * 2 + r + k) * 8
      lg.setColor(col[1], col[2], col[3], 0.18)
      lg.setLineWidth(4)
      lg.line(x - w / 2 + math.sin(self.t + r) * 4, y + 26 + r * 9, x + w / 2 + math.sin(self.t + r) * 4, y + 26 + r * 9)
    end
  end
  -- light dancing on the water: dry-brush strokes that come and go
  for k = 0, 30 do
    local x = (k * 97) % 1160 + 60
    local y = SEA + 30 + (k * 37) % 170
    local a = 0.5 + 0.5 * math.sin(self.t * 1.5 + k * 2.1)
    lg.setColor(1, 1, 1, 0.35 * a)
    lg.setLineWidth(3)
    lg.line(x, y, x + 26 + (k % 3) * 10, y)
  end
  -- gulls: two curved brush strokes each
  for k = 0, 3 do
    local x = (self.t * 18 + k * 230) % 1300 - 40
    local y = 150 + k * 28 + math.sin(self.t + k) * 12
    local f = math.sin(self.t * 4 + k) * 6
    lg.setColor(0.25, 0.25, 0.32, 0.75)
    lg.setLineWidth(2.5)
    lg.line(love.math.newBezierCurve(x - 16, y - f, x - 8, y - 8, x, y):render(3))
    lg.line(love.math.newBezierCurve(x, y, x + 8, y - 8, x + 16, y - f):render(3))
  end

  -- paper grain multiplied over the whole painting
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.grain, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")

  -- deckled white margin: the paint stops unevenly before the paper's edge
  lg.stencil(function()
    for _, run in ipairs(self.border) do
      for i = 1, #run - 1 do
        local a, b = run[i], run[i + 1]
        lg.polygon("fill", a[1], a[2], b[1], b[2], b[3], b[4], a[3], a[4])
      end
    end
  end, "replace", 1)
  lg.setStencilTest("greater", 0)
  lg.setColor(gfx.hex("#f7f1e6"))
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.grain, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")
  lg.setStencilTest()
  -- artist's pencil signature
  lg.setColor(0.4, 0.38, 0.35, 0.6)
  lg.setFont(self.sig)
  lg.print("harbour, morning  -  love2d", 1040, 690)
end

return S
