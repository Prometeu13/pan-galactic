-- Hand-drawn stroke helpers: wobbly double strokes, circles, hatching and handwriting.
-- Used by the chalkboard and blueprint scenes (the notebook scene has its own copy,
-- written out inline so it reads as one self-contained recipe).
--
--   local pen = sketchy.new({ wobble = 3.2, double = true })
--   pen:setSeed(math.floor(time * 8))   -- change the seed to make lines "boil"
--   pen:line(x1, y1, x2, y2, color, width)

local sketchy = {}
sketchy.__index = sketchy
local lg = love.graphics

function sketchy.new(opts)
  opts = opts or {}
  return setmetatable({
    wobble = opts.wobble or 3.2,   -- how far strokes drift sideways, in pixels
    double = opts.double ~= false, -- draw a second, fainter pass
    seed = 0,
  }, sketchy)
end

function sketchy:setSeed(s) self.seed = s end

function sketchy:stroke(x1, y1, x2, y2, pass)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy) + 0.001
  local n = math.max(2, math.floor(len / 14))
  local nx, ny = -dy / len, dx / len
  local pts = {}
  local s = self.seed * 13.7 + (pass or 0) * 51.3 + x1 * 0.37 + y1 * 0.71
  for i = 0, n do
    local f = i / n
    local off = (love.math.noise(s, i * 0.35) - 0.5) * self.wobble
    local e = (i == 0 and -1 or (i == n and 1 or 0)) * (love.math.noise(s + 5) - 0.3) * self.wobble
    pts[#pts + 1] = x1 + dx * f + nx * off + dx / len * e
    pts[#pts + 1] = y1 + dy * f + ny * off + dy / len * e
  end
  lg.line(pts)
end

function sketchy:line(x1, y1, x2, y2, color, width)
  local c = color or { 1, 1, 1, 0.9 }
  lg.setColor(c)
  lg.setLineWidth(width or 2)
  self:stroke(x1, y1, x2, y2, 0)
  if self.double then
    lg.setColor(c[1], c[2], c[3], (c[4] or 1) * 0.5)
    lg.setLineWidth((width or 2) * 0.7)
    self:stroke(x1, y1, x2, y2, 1)
  end
end

function sketchy:poly(pts, color, width, open)
  local last = open and #pts - 2 or #pts
  for i = 1, last, 2 do
    local j = (i + 2 > #pts) and 1 or i + 2
    self:line(pts[i], pts[i + 1], pts[j], pts[j + 1], color, width)
  end
end

-- A polyline through many points (for curves), without closing it.
function sketchy:path(pts, color, width)
  self:poly(pts, color, width, true)
end

function sketchy:circle(cx, cy, r, color, width, from, to)
  from, to = from or 0, to or math.pi * 2
  local n = math.max(10, math.floor(r * (to - from) / 18))
  local prev
  for i = 0, n do
    local a = from + (to - from) * i / n + 0.3
    local wob = 1 + (love.math.noise(self.seed * 3.1 + cx * 0.01, i * 0.3) - 0.5) * 0.025 * self.wobble
    local x, y = cx + math.cos(a) * r * wob, cy + math.sin(a) * r * wob
    if prev then self:line(prev[1], prev[2], x, y, color, width) end
    prev = { x, y }
  end
end

-- Diagonal hatching clipped to a shape (needs a canvas with a stencil buffer).
function sketchy:hatch(drawShape, x, y, w, h, color, gap, width)
  lg.stencil(drawShape, "replace", 1)
  lg.setStencilTest("greater", 0)
  for k = -h, w, gap or 9 do
    self:line(x + k, y + h, x + k + h, y, color, width or 1.6)
  end
  lg.setStencilTest()
end

-- Handwriting: each letter gets its own tilt and baseline offset.
function sketchy:write(text, x, y, font, color, seed, jitter)
  jitter = jitter or 1
  lg.setFont(font)
  lg.setColor(color)
  local cx = x
  for i = 1, #text do
    local ch = text:sub(i, i)
    local n1 = love.math.noise(i * 0.7, seed or 1)
    local n2 = love.math.noise(i * 0.7, (seed or 1) + 9)
    lg.print(ch, cx, y + (n1 - 0.5) * 6 * jitter, (n2 - 0.5) * 0.25 * jitter)
    cx = cx + font:getWidth(ch) * (0.92 + n1 * 0.12 * jitter)
  end
  return cx
end

return sketchy
