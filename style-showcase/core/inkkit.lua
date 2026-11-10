-- Ink-wash toolkit shared by the extra Ink Wash scenes. (The first scene keeps its own
-- inline copy so it reads as one self-contained recipe.)
--
--   ink.paper()                                   -- rice paper canvas
--   ink.brush(ctrl, width, alpha, flick, progress)-- a pressure-profiled stroke along a
--                                                    Bezier; progress 0..1 paints only
--                                                    the first part (for "being drawn")
--   ink.fade(points, depth, alpha)                -- wash: dark along a ridge line,
--                                                    dissolving downward over `depth` px
--   ink.dot(x, y, r, alpha)                       -- a soft wet blot
--   ink.pine(x, y, size, lean, sway)              -- trunk stroke + fans of needles
--   ink.column(x, y, n) / ink.seal(x, y, s)       -- abstract calligraphy and a red seal

local gfx = require("core.gfx")
local lg = love.graphics

local ink = {}
ink.INK = { 0.08, 0.08, 0.1 }
local INK = ink.INK

local function pressure(t, flick)
  local inn = math.min(1, t / 0.18)
  local out = math.min(1, (1 - t) / (flick or 0.35))
  return math.sqrt(inn) * out ^ 0.7
end

local shared
local blot

function ink.brush(ctrl, width, alpha, flick, progress, color)
  local col = color or INK
  local pts = love.math.newBezierCurve(ctrl):render(5)
  local n = #pts / 2
  local shown = n
  if progress then shown = math.max(2, math.floor(n * gfx.clamp(progress, 0, 1) + 0.5)) end
  if progress and progress <= 0 then return end
  local v = {}
  for i = 1, shown do
    local x, y = pts[i * 2 - 1], pts[i * 2]
    local j = math.min(n, i + 1)
    local k = math.max(1, i - 1)
    local dx, dy = pts[j * 2 - 1] - pts[k * 2 - 1], pts[j * 2] - pts[k * 2]
    local len = math.sqrt(dx * dx + dy * dy) + 0.0001
    local nx, ny = -dy / len, dx / len
    local w = width * pressure((i - 1) / math.max(1, n - 1), flick) * 0.5
    v[#v + 1] = { x + nx * w, y + ny * w, 0, 0, col[1], col[2], col[3], alpha }
    v[#v + 1] = { x - nx * w, y - ny * w, 0, 0, col[1], col[2], col[3], alpha }
  end
  if #v >= 4 then
    shared = shared or lg.newMesh(1024, "strip", "stream")
    shared:setVertices(v)
    shared:setDrawRange(1, #v)
    lg.setColor(1, 1, 1)
    lg.draw(shared)
  end
  -- dry-brush streaks: thin broken lines along the same path
  lg.setLineWidth(1)
  for b = 1, 3 do
    local off = (b - 2) * width * 0.35
    local seg = {}
    for i = 1, shown * 2 - 2, 2 do
      local gap = love.math.noise(i * 0.15, b * 3.3 + #pts) > 0.62
      if not gap then
        seg[#seg + 1] = pts[i] + off * 0.3
        seg[#seg + 1] = pts[i + 1] + off
      else
        if #seg >= 4 then
          lg.setColor(col[1], col[2], col[3], alpha * 0.5)
          lg.line(seg)
        end
        seg = {}
      end
    end
    if #seg >= 4 then
      lg.setColor(col[1], col[2], col[3], alpha * 0.5)
      lg.line(seg)
    end
  end
end

-- points = {x1,y1,x2,y2,...} along a ridge; ink fades to nothing `depth` px below it.
-- Returns a static Mesh (draw it with white colour).
function ink.fade(points, depth, alpha, dx, dy)
  local v = {}
  for i = 1, #points, 2 do
    v[#v + 1] = { points[i], points[i + 1], 0, 0, INK[1], INK[2], INK[3], alpha }
    v[#v + 1] = { points[i] + (dx or 0), points[i + 1] + (dy or depth), 0, 1, INK[1], INK[2], INK[3], 0 }
  end
  return lg.newMesh(v, "strip", "static")
end

function ink.dot(x, y, r, alpha, color)
  blot = blot or gfx.radialTexture(64, 0.7)
  local c = color or INK
  lg.setColor(c[1], c[2], c[3], alpha)
  lg.draw(blot, x, y, 0, r / 32, r / 32, 32, 32)
end

function ink.paper(seed)
  love.math.setRandomSeed(seed or 8)
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local n = gfx.fbm(x * 0.015, y * 0.015, 4) * 0.06 + love.math.noise(x * 0.5, y * 0.5) * 0.02
    return 0.94 - n, 0.9 - n, 0.81 - n, 1
  end)
  local c = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(lg.newImage(d), 0, 0, 0, 2, 2)
  for _ = 1, 220 do
    local x, y = love.math.random(0, 1280), love.math.random(0, 720)
    local a = love.math.random() * math.pi
    lg.setColor(0.6, 0.55, 0.45, 0.12)
    lg.setLineWidth(1)
    lg.line(love.math.newBezierCurve(x, y, x + math.cos(a) * 20, y + math.sin(a) * 20 + 6, x + math.cos(a) * 40, y + math.sin(a) * 40):render(3))
  end
  lg.pop()
  return c
end

-- A pine in a few strokes: a crooked trunk, side branches, fans of needles.
function ink.pine(x, y, size, lean, sway)
  sway = sway or 0
  local tx, ty = x + lean * size, y - size
  -- trunk in two bent strokes, so it never looks like a pole
  local kx, ky = x + lean * size * 0.5 - size * 0.14, y - size * 0.5
  ink.brush({ x, y, x - size * 0.1, y - size * 0.25, kx, ky }, size * 0.1 + 2, 0.88, 0.15)
  ink.brush({ kx, ky, kx + size * 0.16, ky - size * 0.2, tx, ty }, size * 0.07 + 2, 0.85, 0.3)
  for k = 0, 3 do
    local u = 0.42 + k * 0.19
    local bx, by = gfx.lerp(kx, tx, (u - 0.42) / 0.6) , gfx.lerp(y, ty, u)
    local dir = (k % 2 == 0) and 1 or -1
    local len = size * (0.5 - k * 0.07)
    local ex, ey = bx + dir * len + sway * (k + 1) * 0.4, by + size * 0.04 + math.abs(sway) * 0.2
    -- branch: out and slightly up, then drooping at the tip
    ink.brush({ bx, by, bx + dir * len * 0.5, by - size * 0.12, ex, ey }, size * 0.03 + 1.5, 0.8, 0.5)
    -- flat pads of needles sitting on top of the branch
    for f = 1, 3 do
      local fx, fy = gfx.lerp(bx, ex, f / 3), gfx.lerp(by - size * 0.06, ey, f / 3) - size * 0.05
      ink.dot(fx, fy, size * 0.17, 0.5)
      ink.dot(fx - dir * size * 0.06, fy - size * 0.03, size * 0.11, 0.55)
      lg.setColor(INK[1], INK[2], INK[3], 0.8)
      lg.setLineWidth(1.2)
      for n = -5, 5 do
        local a = -math.pi / 2 + n * 0.24
        lg.line(fx, fy + size * 0.03, fx + math.cos(a) * size * 0.14, fy + size * 0.03 + math.sin(a) * size * 0.09)
      end
    end
  end
end

-- abstract "calligraphy": brush rhythm, not real characters
function ink.column(x, y, n, progress)
  for k = 0, n - 1 do
    local p = progress and gfx.clamp(progress * n - k, 0, 1) or nil
    if not p or p > 0 then
      local yy = y + k * 52
      ink.brush({ x - 16, yy, x + 2, yy + 6, x + 20, yy + 2 }, 9, 0.85, nil, p)
      ink.brush({ x, yy - 8, x - 2, yy + 16, x + 2, yy + 34 }, 8, 0.85, 0.5, p)
      if k % 2 == 0 then ink.brush({ x - 14, yy + 26, x + 2, yy + 20, x + 16, yy + 30 }, 6, 0.8, nil, p) end
    end
  end
end

function ink.seal(x, y, s, alpha)
  s = s or 52
  lg.setColor(0.78, 0.12, 0.1, 0.9 * (alpha or 1))
  lg.rectangle("fill", x, y, s, s, 4)
  lg.setColor(0.95, 0.9, 0.82, alpha or 1)
  lg.setLineWidth(s / 13)
  local u = s / 52
  lg.line(x + 10 * u, y + 12 * u, x + 42 * u, y + 12 * u, x + 42 * u, y + 26 * u, x + 14 * u, y + 26 * u, x + 14 * u, y + 42 * u, x + 42 * u, y + 42 * u)
  lg.circle("fill", x + 24 * u, y + 34 * u, 3 * u)
end

return ink
