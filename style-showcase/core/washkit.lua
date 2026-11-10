-- Watercolour toolkit shared by the extra Watercolor scenes. (The first scene keeps
-- its own inline copy so it reads as one self-contained recipe.)
--
--   local paint = washkit.new()
--   paint:wash(points, {r,g,b}, { alpha=, layers=, jitter=, step= })   -- a ragged wash
--   paint:blob(x, y, rx, ry, color, opts)                              -- a soft round bloom
--   paint:stroke(points, color, width, alpha)                          -- a brush line
--   paint:splatter(x, y, n, spread, color)                             -- flicked dots
--   paint:fixed(seed, fn)      -- run fn with a fixed seed: live shapes keep their edges
--   washkit.grain()            -- paper texture (multiply it over the painting)
--   washkit.border()           -- deckled margin; washkit.finish() draws grain + margin

local gfx = require("core.gfx")
local vivid = require("vivid")
local lg = love.graphics

local kit = {}
kit.__index = kit

function kit.new() return setmetatable({ seed = 0 }, kit) end

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

-- Several jittered, transparent copies of the shape + a darker pooled edge on each.
function kit:wash(pts, color, opts)
  opts = opts or {}
  local layers, jitter, alpha = opts.layers or 5, opts.jitter or 7, opts.alpha or 0.16
  self.seed = self.seed + 1
  local base = subdivide(pts, opts.step or 14)
  local er, eg, eb = vivid.darken(opts.edge or 0.18, color[1], color[2], color[3])
  for k = 1, layers do
    local p = {}
    for i = 1, #base, 2 do
      local n1 = love.math.noise(base[i] * 0.02, base[i + 1] * 0.02, self.seed * 3.1 + k)
      local n2 = love.math.noise(base[i + 1] * 0.02, base[i] * 0.02, self.seed * 5.7 + k)
      p[#p + 1] = base[i] + (n1 - 0.5) * jitter * 2
      p[#p + 1] = base[i + 1] + (n2 - 0.5) * jitter * 2
    end
    lg.setColor(color[1], color[2], color[3], alpha)
    if opts.convex then lg.polygon("fill", p) else gfx.fillConcave(p) end
    if not opts.noEdge then
      lg.setColor(er, eg, eb, alpha * 0.9)
      lg.setLineWidth(1.6)
      p[#p + 1] = p[1]
      p[#p + 1] = p[2]
      lg.line(p)
    end
  end
end

function kit:blob(x, y, rx, ry, color, opts)
  opts = opts or {}
  local pts = {}
  local n = opts.points or 14
  for a = 0, n - 1 do
    local ang = a / n * math.pi * 2
    local wob = 0.82 + love.math.noise(x * 0.01 + a * 0.7, y * 0.01, self.seed * 1.3) * 0.36
    pts[#pts + 1] = x + math.cos(ang) * rx * wob
    pts[#pts + 1] = y + math.sin(ang) * ry * wob
  end
  opts.convex = false
  self:wash(pts, color, opts)
end

-- A brush line: fat in the middle, thin at the ends, drawn twice (body + darker core).
function kit:stroke(pts, color, width, alpha)
  local n = #pts / 2
  for i = 1, n - 1 do
    local u = (i - 0.5) / (n - 1)
    local w = width * (0.35 + 0.65 * math.sin(u * math.pi))
    lg.setLineWidth(w)
    lg.setColor(color[1], color[2], color[3], alpha or 0.6)
    lg.line(pts[i * 2 - 1], pts[i * 2], pts[i * 2 + 1], pts[i * 2 + 2])
  end
  for i = 1, n do
    local u = (i - 1) / (n - 1)
    local w = width * (0.35 + 0.65 * math.sin(u * math.pi))
    lg.setColor(color[1], color[2], color[3], alpha or 0.6)
    lg.circle("fill", pts[i * 2 - 1], pts[i * 2], w / 2)
  end
end

function kit:splatter(x, y, n, spread, color, rng)
  local function rnd() if rng then return rng:random() end return love.math.random() end
  for _ = 1, n do
    local a, d = rnd() * math.pi * 2, (rnd() ^ 2) * spread
    local r = 1 + rnd() ^ 3 * 5
    lg.setColor(color[1], color[2], color[3], 0.25 + rnd() * 0.35)
    lg.circle("fill", x + math.cos(a) * d, y + math.sin(a) * d * 0.7, r)
  end
end

function kit:fixed(seed, fn)
  local saved = self.seed
  self.seed = seed
  fn()
  self.seed = saved
end

-- cold-press paper grain
function kit.grain()
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local n = love.math.noise(x * 0.35, y * 0.35) * 0.06 + gfx.fbm(x * 0.03, y * 0.03, 3) * 0.05
    return 1 - n * 0.8, 1 - n, 1 - n * 1.3, 1
  end)
  return lg.newImage(d)
end

-- deckled border: runs of quads from the screen edge to a ragged inner line
function kit.border()
  local border = {}
  local k = 0
  local function side(points)
    local run = {}
    for _, p in ipairs(points) do
      local n = gfx.fbm(k * 0.05, 3.3, 3) * 30 + love.math.noise(k * 0.9, 7) * 10
      k = k + 1
      run[#run + 1] = { p[1], p[2], p[1] + p[3] * n, p[2] + p[4] * n }
    end
    border[#border + 1] = run
  end
  local top, bottom, left, right = {}, {}, {}, {}
  for x = 0, 1280, 8 do top[#top + 1] = { x, 0, 0, 1 } bottom[#bottom + 1] = { x, 720, 0, -1 } end
  for y = 0, 720, 8 do left[#left + 1] = { 0, y, 1, 0 } right[#right + 1] = { 1280, y, -1, 0 } end
  side(top) side(bottom) side(left) side(right)
  return border
end

local PAPER = { 0.969, 0.945, 0.902 }
kit.PAPER = PAPER

-- grain over everything, then the unpainted margin, then a pencil caption
function kit.finish(grain, border, caption, font)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(grain, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")
  lg.stencil(function()
    for _, run in ipairs(border) do
      for i = 1, #run - 1 do
        local a, b = run[i], run[i + 1]
        lg.polygon("fill", a[1], a[2], b[1], b[2], b[3], b[4], a[3], a[4])
      end
    end
  end, "replace", 1)
  lg.setStencilTest("greater", 0)
  lg.setColor(PAPER)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(grain, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")
  lg.setStencilTest()
  if caption then
    lg.setColor(0.4, 0.38, 0.35, 0.6)
    lg.setFont(font)
    lg.printf(caption, 780, 690, 460, "right")
  end
end

return kit
