-- Ink toolkit: rice paper, pressure-sensitive brush strokes, washes and mist.
-- Everything in the game is painted with these few functions.

local ink = {}
local lg = love.graphics

ink.INK = { 0.08, 0.08, 0.1 }
ink.RED = { 0.78, 0.14, 0.1 }
ink.PAPER = { 0.94, 0.9, 0.81 }

function ink.lerp(a, b, t) return a + (b - a) * t end
function ink.clamp(v, a, b) return math.max(a, math.min(b, v)) end
function ink.smooth(e0, e1, x)
  local t = ink.clamp((x - e0) / (e1 - e0), 0, 1)
  return t * t * (3 - 2 * t)
end

function ink.fbm(x, y, oct)
  local s, a, f, n = 0, 1, 1, 0
  for _ = 1, oct or 4 do
    s = s + a * love.math.noise(x * f, y * f)
    n = n + a
    a, f = a * 0.5, f * 2
  end
  return s / n
end

function ink.hash(n)
  local s = math.sin(n * 127.1 + 311.7) * 43758.5453
  return s - math.floor(s)
end

-- Width profile of a real brush: press in, hold, lift off.
local function pressure(t, flick)
  local inn = math.min(1, t / 0.18)
  local out = math.min(1, (1 - t) / (flick or 0.35))
  return math.sqrt(inn) * out ^ 0.7
end

-- One streaming mesh is refilled for every stroke (strokes move every frame).
local shared

-- A brush stroke along a Bezier curve, as a tapered triangle strip.
-- ctrl = {x1,y1,x2,y2,...}; color defaults to ink.
function ink.stroke(ctrl, width, alpha, flick, color, dry)
  local c = color or ink.INK
  local ok, curve = pcall(love.math.newBezierCurve, ctrl)
  if not ok then return end
  local pts = curve:render(4)
  local n = #pts / 2
  if n < 2 then return end
  local v = {}
  for i = 1, n do
    local x, y = pts[i * 2 - 1], pts[i * 2]
    local j, k = math.min(n, i + 1), math.max(1, i - 1)
    local dx, dy = pts[j * 2 - 1] - pts[k * 2 - 1], pts[j * 2] - pts[k * 2]
    local len = math.sqrt(dx * dx + dy * dy) + 0.0001
    local nx, ny = -dy / len, dx / len
    local w = width * pressure((i - 1) / (n - 1), flick) * 0.5
    v[#v + 1] = { x + nx * w, y + ny * w, 0, 0, c[1], c[2], c[3], alpha }
    v[#v + 1] = { x - nx * w, y - ny * w, 0, 0, c[1], c[2], c[3], alpha }
  end
  shared = shared or lg.newMesh(1024, "strip", "stream")
  shared:setVertices(v)
  shared:setDrawRange(1, #v)
  lg.setColor(1, 1, 1)
  lg.draw(shared)
  -- dry-brush streaks: thin broken lines riding along the stroke
  if dry ~= false and width > 6 then
    lg.setLineWidth(1)
    lg.setColor(c[1], c[2], c[3], alpha * 0.45)
    local off = width * 0.32
    local seg = {}
    for i = 1, #pts - 2, 2 do
      if love.math.noise(i * 0.2, pts[1] * 0.01) > 0.6 then
        if #seg >= 4 then lg.line(seg) end
        seg = {}
      else
        seg[#seg + 1] = pts[i]
        seg[#seg + 1] = pts[i + 1] + off
      end
    end
    if #seg >= 4 then lg.line(seg) end
  end
end

-- A soft wash: a filled shape at low alpha, drawn a few times with small offsets so
-- the edges blur like wet ink.
function ink.wash(pts, alpha, color)
  local c = color or ink.INK
  local ok, tris = pcall(love.math.triangulate, pts)
  if not ok then return end
  for k = 0, 2 do
    lg.setColor(c[1], c[2], c[3], alpha * (k == 0 and 1 or 0.35))
    lg.push()
    lg.translate((k - 1) * 2, (k == 2) and 2 or 0)
    for _, t in ipairs(tris) do lg.polygon("fill", t) end
    lg.pop()
  end
end

-- Mountain range mesh: dark at the ridge, fading to nothing below (mist).
function ink.rangeMesh(width, baseY, amp, freq, seed, alpha, fade)
  local v = {}
  for x = -20, width + 20, 8 do
    local n = ink.fbm(x * freq + seed, seed, 5)
    local r = (1 - math.abs(n * 2 - 1)) ^ 2
    local y = baseY - (n * 0.4 + r * 0.6) * amp
    v[#v + 1] = { x, y, 0, 0, ink.INK[1], ink.INK[2], ink.INK[3], alpha }
    v[#v + 1] = { x, y + fade, 0, 1, ink.INK[1], ink.INK[2], ink.INK[3], 0 }
  end
  return lg.newMesh(v, "strip", "static")
end

-- Rice paper, baked once.
function ink.paper(w, h)
  local d = love.image.newImageData(math.floor(w / 2), math.floor(h / 2))
  d:mapPixel(function(x, y)
    local n = ink.fbm(x * 0.015, y * 0.015, 4) * 0.06 + love.math.noise(x * 0.5, y * 0.5) * 0.02
    return 0.94 - n, 0.9 - n, 0.81 - n, 1
  end)
  local c = lg.newCanvas(w, h)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(lg.newImage(d), 0, 0, 0, 2, 2)
  for _ = 1, 260 do
    local x, y = love.math.random(0, w), love.math.random(0, h)
    local a = love.math.random() * math.pi
    lg.setColor(0.6, 0.55, 0.45, 0.12)
    lg.setLineWidth(1)
    lg.line(love.math.newBezierCurve(x, y, x + math.cos(a) * 20, y + math.sin(a) * 20 + 6, x + math.cos(a) * 40, y + math.sin(a) * 40):render(3))
  end
  lg.pop()
  return c
end

-- Soft round texture (glows, mist puffs, lantern light).
function ink.blob(size, power)
  local d = love.image.newImageData(size, size)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
    local r = math.min(1, math.sqrt(dx * dx + dy * dy))
    return 1, 1, 1, (1 - r) ^ (power or 2)
  end)
  return lg.newImage(d)
end

-- The red seal stamp with a small geometric mark.
function ink.seal(x, y, s, alpha)
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], alpha or 0.9)
  lg.rectangle("fill", x - s / 2, y - s / 2, s, s, s * 0.08)
  lg.setColor(ink.PAPER[1], ink.PAPER[2], ink.PAPER[3], alpha or 1)
  lg.setLineWidth(math.max(2, s * 0.08))
  local h = s / 2 - s * 0.2
  lg.line(x - h, y - h, x + h, y - h, x + h, y, x - h * 0.7, y, x - h * 0.7, y + h, x + h, y + h)
end

return ink
