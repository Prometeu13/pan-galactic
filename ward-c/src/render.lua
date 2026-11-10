-- Everything you see. First-person corridor in one-point perspective, done by hand:
--   screen = vanishing point + (x, y) * size / depth        (depth = z - camera z)
-- The corridor is cut into thin slices along z; each slice asks the game how bright
-- the corridor is there (lamps + torch) and is painted in that brightness. Doors,
-- lamps, props and the figure are sorted far-to-near and drawn the same way.

local moonshine = require("moonshine")
local shack = require("shack")
local G = require("src.game")

local lg = love.graphics
local R = {}

local VX, VY = 640, 330          -- vanishing point
local HX, HY = 700, 470          -- half-size of the corridor's cross-section at depth 1
local NEAR, FAR = 0.7, 15
local STEP = 0.25
local cam = 0                    -- camera z, set each frame

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function hash(n)
  local s = math.sin(n * 127.1 + 311.7) * 43758.5453
  return s - math.floor(s)
end

local function P(x, y, z)
  local d = math.max(NEAR, z - cam)
  return VX + x * HX / d, VY + y * HY / d
end

local function quad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  local a, b = P(x1, y1, z1)
  local c, d = P(x2, y2, z2)
  local e, f = P(x3, y3, z3)
  local g, h = P(x4, y4, z4)
  lg.polygon("fill", a, b, c, d, e, f, g, h)
end

-- distance fog: the far end of the corridor is simply not there
local function fog(z) return clamp((FAR - (z - cam)) / 6, 0, 1) end
-- what the eye sees: dim is lifted a little, so dead-lamp stretches are murky, not blank
local function see(L) return L ^ 0.72 end

function R.load()
  R.fonts = { small = lg.newFont(14), body = lg.newFont(20), big = lg.newFont(54), plate = lg.newFont(40), title = lg.newFont(88) }
  local function radial(size, power)
    local d = love.image.newImageData(size, size)
    d:mapPixel(function(x, y)
      local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
      return 1, 1, 1, (1 - math.min(1, math.sqrt(dx * dx + dy * dy))) ^ power
    end)
    return lg.newImage(d)
  end
  R.glow = radial(128, 2)
  R.soft = radial(128, 1.2)
  R.fx = moonshine(1280, 720, moonshine.effects.filmgrain)
    .chain(moonshine.effects.chromasep)
    .chain(moonshine.effects.vignette)
  R.fx.filmgrain.opacity = 0.45
  R.fx.filmgrain.size = 2.5
  R.fx.chromasep.radius = 2
  R.fx.vignette.radius = 0.78
  R.fx.vignette.softness = 0.55
  R.fx.vignette.opacity = 0.85
  shack:setDimensions(1280, 720)
end

function R.shake(amount) shack:setShake(amount) end
function R.update(dt) shack:update(dt) end

---------------------------------------------------------------------------------------
-- the corridor shell
---------------------------------------------------------------------------------------
local WALL, WAIN, FLOOR_A, FLOOR_B, CEIL = { 0.55, 0.6, 0.52 }, { 0.33, 0.4, 0.35 }, { 0.48, 0.5, 0.46 }, { 0.3, 0.33, 0.31 }, { 0.6, 0.61, 0.56 }

local function drawShell(g)
  local zFar = math.min(G.LEN, cam + FAR)
  local first = math.floor(zFar / STEP) * STEP
  for z = first, cam + NEAR - STEP, -STEP do
    local z1, z2 = math.max(z, cam + NEAR), math.min(z + STEP, G.LEN)
    if z2 > z1 then
      local L = see(g:lightAt((z1 + z2) / 2)) * fog(z1)
      local idx = math.floor(z / STEP + 0.5)
      lg.setColor(CEIL[1] * L, CEIL[2] * L, CEIL[3] * L)
      quad(-1, -1, z1, 1, -1, z1, 1, -1, z2, -1, -1, z2)
      for s = -1, 1, 2 do
        local stain = 0.85 + 0.15 * hash(idx * 3.7 + s)
        lg.setColor(WALL[1] * L * stain, WALL[2] * L * stain, WALL[3] * L * stain)
        quad(s, -1, z1, s, 0.3, z1, s, 0.3, z2, s, -1, z2)
        lg.setColor(WAIN[1] * L, WAIN[2] * L, WAIN[3] * L)
        quad(s, 0.3, z1, s, 1, z1, s, 1, z2, s, 0.3, z2)
        lg.setColor(0.9 * L, 0.9 * L, 0.82 * L)
        quad(s, 0.27, z1, s, 0.33, z1, s, 0.33, z2, s, 0.27, z2)
      end
      local tile = math.floor(z / 0.5)
      for c = 0, 3 do
        local x1, x2 = -1 + c * 0.5, -0.5 + c * 0.5
        local col = ((tile + c) % 2 == 0) and FLOOR_A or FLOOR_B
        lg.setColor(col[1] * L, col[2] * L, col[3] * L)
        quad(x1, 1, z1, x2, 1, z1, x2, 1, z2, x1, 1, z2)
      end
    end
  end
end

local function drawEndWall(g)
  if G.LEN - cam > FAR then return end
  local L = see(g:lightAt(G.LEN)) * fog(G.LEN)
  local x1, y1 = P(-1, -1, G.LEN)
  local x2, y2 = P(1, 1, G.LEN)
  lg.setColor(0.3 * L, 0.34 * L, 0.3 * L)
  lg.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
  local dx1, dy1 = P(-0.6, -0.5, G.LEN)
  local dx2, dy2 = P(0.6, 1, G.LEN)
  lg.setColor(0.2 * L + 0.01, 0.22 * L + 0.01, 0.2 * L + 0.01)
  lg.rectangle("fill", dx1, dy1, dx2 - dx1, dy2 - dy1)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", (dx1 + dx2) / 2 - 1, dy1, 2, dy2 - dy1)
  local s = 1 / (G.LEN - cam)
  lg.circle("fill", (dx1 * 3 + dx2) / 4, dy1 + 260 * s, 90 * s)
  lg.circle("fill", (dx1 + dx2 * 3) / 4, dy1 + 260 * s, 90 * s)
  -- EXIT: chained shut, but its sign never goes out
  local ex, ey = P(0, -0.66, G.LEN)
  lg.setColor(0.9, 0.1, 0.08)
  lg.rectangle("fill", ex - 200 * s, ey - 70 * s, 400 * s, 140 * s, 2)
  lg.setBlendMode("add")
  lg.setColor(1, 0.1, 0.05, 0.5)
  lg.draw(R.glow, ex, ey, 0, 16 * s, 12 * s, 64, 64)
  lg.setBlendMode("alpha")
end

---------------------------------------------------------------------------------------
-- things in the corridor (each returns nothing; depth sorting happens in R.corridor)
---------------------------------------------------------------------------------------
local function drawDoor(g, r)
  local s, z1, z2 = r.side, r.z - 0.45, r.z + 0.45
  if z2 <= cam + NEAR then return end
  local L = see(g:lightAt(r.z)) * fog(r.z)
  lg.setColor(0.2 * L, 0.22 * L, 0.18 * L)
  quad(s, -0.42, z1 - 0.06, s, 1, z1 - 0.06, s, 1, z2 + 0.06, s, -0.42, z2 + 0.06)
  lg.setColor(0.4 * L, 0.36 * L, 0.28 * L)
  quad(s, -0.36, z1, s, 1, z1, s, 1, z2, s, -0.36, z2)
  -- window slot and handle
  lg.setColor(0.02, 0.03, 0.03)
  quad(s, -0.24, z1 + 0.2, s, 0.02, z1 + 0.2, s, 0.02, z1 + 0.5, s, -0.24, z1 + 0.5)
  lg.setColor(0.6 * L, 0.6 * L, 0.55 * L)
  quad(s, 0.36, z1 + 0.08, s, 0.42, z1 + 0.08, s, 0.42, z1 + 0.18, s, 0.36, z1 + 0.18)
  -- call light above the door: amber and blinking until you've checked the bed
  local cx, cy = P(s * 0.985, -0.52, r.z)
  local d = math.max(NEAR, r.z - cam)
  local rad = 26 / d
  if r.checked then
    lg.setColor(0.15, 0.5, 0.25, fog(r.z))
    lg.circle("fill", cx, cy, rad)
  else
    local blink = 0.55 + 0.45 * math.sin(g.t * 5 + r.bed)
    lg.setColor(1, 0.7, 0.15, fog(r.z))
    lg.circle("fill", cx, cy, rad)
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.1, 0.55 * blink * fog(r.z))
    lg.draw(R.glow, cx, cy, 0, rad / 9, rad / 9, 64, 64)
    lg.setBlendMode("alpha")
  end
  -- bed number plate beside the door (on the wall, on the side nearer to you)
  local px, py = P(s, -0.3, z1 - 0.3)
  local px2 = P(s, -0.3, z1 - 0.1)
  local ph = 0.12 * HY / math.max(NEAR, z1 - 0.2 - cam)
  if z1 - 0.3 > cam + NEAR then
    lg.setColor(0.8 * L, 0.78 * L, 0.66 * L)
    quad(s, -0.33, z1 - 0.32, s, -0.19, z1 - 0.32, s, -0.19, z1 - 0.08, s, -0.33, z1 - 0.08)
    lg.setColor(0.08, 0.08, 0.08, clamp(L * 3, 0, 1))
    lg.setFont(R.fonts.plate)
    local sc = ph / 44
    lg.print(tostring(r.bed), math.min(px, px2) + math.abs(px2 - px) * 0.3, py - ph * 0.72, 0, sc * 0.8, sc)
  end
end

local function drawLamp(g, l)
  if l.z + 0.16 <= cam + NEAR then return end
  local f = fog(l.z)
  local z1, z2 = math.max(l.z - 0.16, cam + NEAR), l.z + 0.16
  local I = l.I
  lg.setColor((0.12 + 0.88 * I) * f, (0.13 + 0.87 * I) * f, (0.11 + 0.8 * I) * f)
  quad(-0.3, -0.985, z1, 0.3, -0.985, z1, 0.3, -0.985, z2, -0.3, -0.985, z2)
  if I > 0.05 then
    local x, y = P(0, -0.985, l.z)
    local s = 1 / math.max(NEAR, l.z - cam)
    lg.setBlendMode("add")
    lg.setColor(0.85, 1, 0.85, 0.5 * I * f)
    lg.draw(R.glow, x, y, 0, 6 * s, 3 * s, 64, 64)
    -- its reflection in the polished floor
    local fx, fy = P(0, 1, l.z)
    lg.setColor(0.8, 0.95, 0.85, 0.3 * I * f)
    lg.draw(R.glow, fx, fy + 30 * s, 0, 5.5 * s, 2.2 * s, 64, 64)
    lg.setBlendMode("alpha")
  end
end

local function drawGurney(g, gz)
  if gz <= cam + NEAR then return end
  local L = see(g:lightAt(gz)) * fog(gz)
  local z2 = gz + 0.95
  lg.setColor(0.12 * L, 0.12 * L, 0.12 * L)
  lg.setLineWidth(clamp(10 / (gz - cam), 1, 12))
  for _, c in ipairs({ { 0.58, gz + 0.05 }, { 0.95, gz + 0.05 }, { 0.58, gz + 0.9 } }) do
    local x1, y1 = P(c[1], 0.6, c[2])
    local x2, y2 = P(c[1], 1, c[2])
    lg.line(x1, y1, x2, y2)
  end
  lg.setColor(0.6 * L, 0.62 * L, 0.6 * L)
  quad(0.55, 0.52, gz, 0.98, 0.52, gz, 0.98, 0.52, z2, 0.55, 0.52, z2)
  lg.setColor(0.75 * L, 0.76 * L, 0.72 * L)
  quad(0.55, 0.52, gz, 0.98, 0.52, gz, 0.98, 0.6, gz, 0.55, 0.6, gz)
  lg.setColor(0.4 * L, 0.42 * L, 0.4 * L)
  quad(0.55, 0.52, gz, 0.55, 0.6, gz, 0.55, 0.6, z2, 0.55, 0.52, z2)
  lg.setColor(0.7 * L, 0.72 * L, 0.68 * L)
  quad(0.55, 0.52, gz + 0.2, 0.55, 0.52, gz + 0.8, 0.55, 0.86, gz + 0.7, 0.55, 0.8, gz + 0.3)
end

local function drawWheelchair(g, wz)
  if wz <= cam + NEAR then return end
  local L = see(g:lightAt(wz)) * fog(wz)
  local x, y = P(-0.72, 1, wz)
  local u = HY / (wz - cam)
  lg.setColor(0.1 * L, 0.1 * L, 0.11 * L)
  lg.setLineWidth(math.max(1, 0.03 * u))
  lg.circle("line", x - 0.1 * u, y - 0.2 * u, 0.2 * u)
  lg.circle("line", x + 0.12 * u, y - 0.08 * u, 0.08 * u)
  lg.line(x - 0.1 * u, y - 0.2 * u, x - 0.14 * u, y - 0.72 * u)
  lg.line(x - 0.14 * u, y - 0.72 * u, x - 0.22 * u, y - 0.74 * u)
  lg.setColor(0.2 * L, 0.24 * L, 0.3 * L)
  lg.polygon("fill", x - 0.16 * u, y - 0.36 * u, x + 0.14 * u, y - 0.36 * u, x + 0.14 * u, y - 0.3 * u, x - 0.16 * u, y - 0.3 * u)
  lg.polygon("fill", x - 0.17 * u, y - 0.7 * u, x - 0.11 * u, y - 0.7 * u, x - 0.11 * u, y - 0.34 * u, x - 0.17 * u, y - 0.34 * u)
end

-- The figure: too tall, arms too long, head tilted. Sizes are in corridor units.
local function drawFigure(g)
  local f = g.fig
  local d = f.z - cam
  if d <= 0.3 or d > FAR + 1 then return end
  local t = g.t
  local u = HY / math.max(0.45, d)
  local fx, fy = VX + 0.06 * HX / math.max(0.45, d), VY + HY / math.max(0.45, d)
  -- when it is on top of you it stoops, so its face (not its chest) fills your view
  local stoop = clamp(1 - (d - 0.5) / 1.3, 0, 1)
  fy = fy + stoop * ((VY + 60 + 1.45 * u) - fy)
  local lit = clamp(g:lightAt(f.z) * fog(f.z) * 1.1, 0, 1)
  if g.mode == "caught" then lit = math.max(lit, 0.55) end     -- your dropped torch, from below
  local frozen = g.light and not f.moving and f.state ~= "flee"
  local tw = frozen and math.sin(t * 40) * 0.006 * u * (f.exposure * 2) or 0     -- it shudders in the beam
  local sway = math.sin(t * 0.9) * 0.02 * u + tw
  local gown = { 0.02 + 0.5 * lit, 0.02 + 0.56 * lit, 0.03 + 0.52 * lit }
  local skin = { 0.02 + 0.42 * lit, 0.02 + 0.4 * lit, 0.03 + 0.38 * lit }
  -- legs
  lg.setColor(skin)
  lg.polygon("fill", fx - 0.07 * u, fy, fx - 0.03 * u, fy, fx + sway, fy - 0.72 * u, fx - 0.06 * u + sway, fy - 0.72 * u)
  lg.polygon("fill", fx + 0.03 * u, fy, fx + 0.07 * u, fy, fx + 0.06 * u + sway, fy - 0.72 * u, fx + sway, fy - 0.72 * u)
  -- hospital gown
  lg.setColor(gown)
  lg.polygon("fill", fx - 0.11 * u + sway, fy - 0.56 * u, fx + 0.11 * u + sway, fy - 0.56 * u, fx + 0.085 * u + sway * 1.5, fy - 1.3 * u, fx - 0.085 * u + sway * 1.5, fy - 1.3 * u)
  lg.setColor(gown[1] * 0.6, gown[2] * 0.6, gown[3] * 0.6)
  lg.polygon("fill", fx + 0.02 * u + sway, fy - 0.56 * u, fx + 0.11 * u + sway, fy - 0.56 * u, fx + 0.085 * u + sway * 1.5, fy - 1.3 * u, fx + 0.03 * u + sway * 1.5, fy - 1.3 * u)
  -- arms that reach almost to the knees (they lift toward you when it is close)
  local reach = clamp(1 - (d - 1) / 4, 0, 1)
  lg.setColor(skin)
  lg.setLineWidth(math.max(1.5, 0.035 * u))
  lg.line(fx - 0.085 * u + sway * 1.5, fy - 1.27 * u, fx - 0.15 * u + sway, fy - 0.85 * u - reach * 0.1 * u, fx - 0.13 * u - reach * 0.06 * u, fy - 0.42 * u - reach * 0.5 * u)
  lg.line(fx + 0.085 * u + sway * 1.5, fy - 1.27 * u, fx + 0.15 * u + sway, fy - 0.85 * u - reach * 0.1 * u, fx + 0.14 * u + reach * 0.06 * u, fy - 0.42 * u - reach * 0.5 * u)
  -- neck and a head tilted too far
  local hx, hy = fx + sway * 1.8 + 0.035 * u, fy - 1.45 * u
  lg.polygon("fill", fx - 0.025 * u + sway * 1.5, fy - 1.3 * u, fx + 0.025 * u + sway * 1.5, fy - 1.3 * u, hx + 0.02 * u, hy, hx - 0.02 * u, hy)
  lg.push()
  lg.translate(hx, hy)
  lg.rotate(0.42 + math.sin(t * 0.6) * 0.05 + tw * 0.01)
  lg.ellipse("fill", 0, -0.02 * u, 0.062 * u, 0.085 * u)
  -- eye sockets, a mouth that hangs open, stringy hair
  lg.setColor(0.01, 0.01, 0.012)
  lg.ellipse("fill", -0.022 * u, -0.03 * u, 0.018 * u, 0.02 * u)
  lg.ellipse("fill", 0.022 * u, -0.03 * u, 0.018 * u, 0.02 * u)
  lg.ellipse("fill", 0, 0.03 * u, 0.02 * u, 0.012 * u + reach * 0.02 * u)
  lg.setLineWidth(math.max(1, 0.012 * u))
  for k = -2, 2 do lg.line(k * 0.02 * u, -0.07 * u, k * 0.034 * u, 0.12 * u + math.abs(k) * 0.02 * u) end
  -- the eyes: the only light it has, so you see them even in a blackout
  local a = 0.5 + 0.5 * love.math.noise(t * 2)
  lg.setColor(0.95, 1, 0.9, (0.6 + 0.4 * a) * clamp(fog(f.z) * 2, 0, 1))
  lg.circle("fill", -0.022 * u, -0.03 * u, math.max(1.2, 0.0085 * u))
  lg.circle("fill", 0.022 * u, -0.03 * u, math.max(1.2, 0.0085 * u))
  lg.pop()
end

---------------------------------------------------------------------------------------
-- the corridor view
---------------------------------------------------------------------------------------
local function corridor(g)
  cam = g.z
  local t = g.t
  lg.clear(0, 0, 0, 1)
  lg.push()
  shack:apply()
  -- breathing and head bob
  local bob = math.sin(g.walk * 5.7) * 5
  lg.translate(640, 360)
  lg.rotate(math.sin(t * 0.7) * 0.01 + math.sin(g.walk * 2.85) * 0.006)
  lg.scale(1.03 + math.sin(t * 1.1) * 0.006)
  lg.translate(-640, -360 + math.sin(t * 1.1) * 4 + bob)

  drawShell(g)
  drawEndWall(g)
  -- far to near
  local things = {}
  for _, r in ipairs(g.rooms) do things[#things + 1] = { z = r.z + 0.45, fn = function() drawDoor(g, r) end } end
  for _, l in ipairs(g.lamps) do
    if l.z - cam < FAR then things[#things + 1] = { z = l.z, fn = function() drawLamp(g, l) end } end
  end
  things[#things + 1] = { z = 10.4 + 0.9, fn = function() drawGurney(g, 10.4) end }
  things[#things + 1] = { z = 21.6, fn = function() drawWheelchair(g, 21.6) end }
  things[#things + 1] = { z = g.fig.z, fn = function() drawFigure(g) end }
  table.sort(things, function(a, b) return a.z > b.z end)
  for _, th in ipairs(things) do
    if th.z > cam + 0.3 and th.z - cam < FAR + 1 then th.fn() end
  end
  -- dust in the light
  lg.setBlendMode("add")
  for k = 0, 50 do
    local z = cam + 1 + ((hash(k) * 9 - g.z) % 9)
    local x = (hash(k + 50) - 0.5) * 1.6 + math.sin(t * 0.3 + k) * 0.05
    local y = -0.9 + ((hash(k + 90) + t * 0.02) % 1) * 1.6
    local px, py = P(x, y, z)
    lg.setColor(1, 1, 0.9, 0.35 * g:lightAt(z))
    lg.circle("fill", px, py, 2.4 / (z - cam))
  end
  -- the torch: a hot spot and a soft ring in the middle of the view
  if g.light then
    lg.setColor(1, 0.96, 0.82, 0.1)
    lg.draw(R.soft, VX, VY + 20, 0, 7, 5, 64, 64)
    lg.setColor(1, 0.96, 0.82, 0.14)
    lg.draw(R.glow, VX, VY + 10, 0, 2.6, 2.2, 64, 64)
  end
  lg.setBlendMode("alpha")
  lg.pop()
  -- it is close: the edges of your vision pulse
  local gap = g.fig.z - g.z
  if gap < 7 and g.mode == "play" then
    local k = (1 - gap / 7) * (0.5 + 0.5 * math.sin(t * (6 + (7 - gap))))
    lg.setColor(0.5, 0, 0, 0.16 * k)
    lg.setLineWidth(70)
    lg.rectangle("line", 0, 0, 1280, 720, 60)
    lg.setLineWidth(30)
    lg.rectangle("line", 0, 0, 1280, 720, 30)
  end
end

---------------------------------------------------------------------------------------
-- looking into a room
---------------------------------------------------------------------------------------
local function room(g)
  local pk = g.peek
  local r = pk.room
  local t = g.t
  local open = clamp(pk.t / 0.35, 0, 1)
  lg.clear(0.015, 0.02, 0.03, 1)
  -- back wall and floor
  lg.setColor(0.08, 0.1, 0.13)
  lg.rectangle("fill", 0, 0, 1280, 470)
  lg.setColor(0.05, 0.06, 0.08)
  lg.rectangle("fill", 0, 470, 1280, 250)
  -- window with blinds, moonlight outside
  lg.setColor(0.32, 0.42, 0.56)
  lg.rectangle("fill", 760, 110, 300, 230)
  lg.setColor(0.06, 0.07, 0.1)
  for k = 0, 11 do lg.rectangle("fill", 752, 110 + k * 20, 316, 9) end
  lg.rectangle("fill", 752, 100, 316, 12)
  lg.rectangle("fill", 752, 338, 316, 12)
  lg.rectangle("fill", 906, 100, 8, 250)
  -- the moonlight falls in stripes across the floor and the bed
  lg.setBlendMode("add")
  for k = 0, 10 do
    lg.setColor(0.3, 0.42, 0.6, 0.16)
    lg.polygon("fill", 760 - k * 26, 490 + k * 17, 1060 - k * 26, 490 + k * 17, 1050 - k * 26 - 13, 500 + k * 17, 750 - k * 26 - 13, 500 + k * 17)
  end
  lg.setBlendMode("alpha")
  -- bed: frame, mattress, pillow, and whoever is (or is not) in it
  lg.setColor(0.16, 0.18, 0.2)
  lg.rectangle("fill", 300, 470, 560, 26)
  lg.rectangle("fill", 300, 360, 16, 200)
  lg.rectangle("fill", 844, 420, 16, 140)
  lg.setColor(0.4, 0.44, 0.48)
  lg.rectangle("fill", 316, 430, 528, 44, 8)
  lg.setColor(0.55, 0.58, 0.62)
  lg.ellipse("fill", 380, 424, 60, 22)
  if r.empty then
    -- sheets thrown back, an IV line pulled out and dripping
    lg.setColor(0.46, 0.5, 0.54)
    lg.polygon("fill", 470, 432, 640, 400, 760, 424, 844, 432, 844, 474, 470, 474)
    lg.setColor(0.3, 0.33, 0.37)
    lg.polygon("fill", 470, 432, 640, 400, 600, 440)
  else
    local breathe = math.sin(t * 1.6) * 5
    lg.setColor(0.36, 0.42, 0.5)
    lg.ellipse("fill", 610, 428, 220, 44 + breathe)
    lg.rectangle("fill", 420, 428, 424, 46)
    lg.setColor(0.24, 0.2, 0.18)
    lg.ellipse("fill", 388, 408, 30, 26)                 -- head on the pillow
    if r.awake then
      lg.setColor(0.9, 0.95, 1)
      lg.circle("fill", 396, 404, 3.5)
      lg.circle("fill", 410, 406, 3.5)
    end
  end
  -- IV stand and a monitor
  lg.setColor(0.3, 0.32, 0.34)
  lg.rectangle("fill", 250, 220, 5, 340)
  lg.rectangle("fill", 226, 220, 54, 5)
  lg.setColor(0.5, 0.6, 0.66, 0.6)
  lg.rectangle("fill", 262, 232, 22, 46, 6)
  lg.setLineWidth(1.5)
  if r.empty then
    lg.line(273, 278, 276, 400, 300, 520)
    lg.setColor(0.6, 0.7, 0.8, 0.8)
    lg.circle("fill", 300, 520 + (t * 60 % 40), 2.5)
  else
    lg.line(273, 278, 300, 400, 420, 440)
  end
  lg.setColor(0.07, 0.09, 0.08)
  lg.rectangle("fill", 880, 380, 120, 80, 6)
  lg.rectangle("fill", 934, 460, 12, 100)
  if not r.empty then
    lg.setColor(0.3, 1, 0.5)
    lg.setLineWidth(2)
    local pts = {}
    for i = 0, 50 do
      local u = i / 50
      local ph = (u * 2.2 - t * 1.1) % 1
      local y = 0
      if ph > 0.42 and ph < 0.46 then y = -24 elseif ph >= 0.46 and ph < 0.5 then y = 14 end
      pts[#pts + 1] = 890 + u * 100
      pts[#pts + 1] = 424 + y
    end
    lg.line(pts)
  else
    lg.setColor(0.3, 1, 0.5, 0.5)
    lg.rectangle("fill", 890, 423, 100, 2)
  end
  -- bedside table, with batteries if this room has them
  lg.setColor(0.14, 0.13, 0.12)
  lg.rectangle("fill", 150, 450, 80, 110)
  if r.battery then
    lg.setColor(0.8, 0.7, 0.2)
    lg.rectangle("fill", 170, 436, 30, 14, 3)
    lg.setColor(0.2, 0.2, 0.2)
    lg.rectangle("fill", 200, 440, 5, 6)
    lg.setBlendMode("add")
    lg.setColor(1, 0.9, 0.4, 0.3 + 0.2 * math.sin(t * 6))
    lg.draw(R.glow, 186, 442, 0, 0.9, 0.6, 64, 64)
    lg.setBlendMode("alpha")
  end
  -- the corridor light spilling in around you, and the door frame you lean through
  lg.setBlendMode("add")
  lg.setColor(0.5, 0.6, 0.5, 0.08 * open)
  lg.polygon("fill", 400, 720, 880, 720, 760, 520, 520, 520)
  lg.setBlendMode("alpha")
  lg.setColor(0, 0, 0)
  local w = 150 + (1 - open) * 490
  lg.rectangle("fill", 0, 0, w, 720)
  lg.rectangle("fill", 1280 - w * 0.6, 0, w * 0.6, 720)
  lg.setColor(0.12, 0.1, 0.08)
  lg.rectangle("fill", w - 16, 0, 16, 720)
  -- pen on the chart: a progress tick
  local p = clamp(pk.t / G.PEEK_TIME, 0, 1)
  lg.setColor(1, 1, 1, 0.25)
  lg.rectangle("fill", 440, 664, 400, 4)
  lg.setColor(1, 0.8, 0.3)
  lg.rectangle("fill", 440, 664, 400 * p, 4)
  lg.setFont(R.fonts.small)
  lg.setColor(1, 1, 1, 0.7)
  lg.printf(("checking Bed %d ...   (you can't see the corridor from here)"):format(r.bed), 0, 636, 1280, "center")
end

---------------------------------------------------------------------------------------
-- HUD: a clipboard, a battery, one line of text
---------------------------------------------------------------------------------------
local function hud(g)
  local f = R.fonts
  -- clipboard, bottom left
  lg.setColor(0.36, 0.26, 0.16, 0.92)
  lg.rectangle("fill", 24, 580, 250, 116, 6)
  lg.setColor(0.9, 0.88, 0.8, 0.95)
  lg.rectangle("fill", 34, 596, 230, 92, 3)
  lg.setColor(0.5, 0.5, 0.52)
  lg.rectangle("fill", 122, 574, 54, 16, 4)
  lg.setFont(f.small)
  lg.setColor(0.15, 0.15, 0.18)
  lg.print("NIGHT ROUND  -  WARD C", 44, 602)
  for i, r in ipairs(g.rooms) do
    local x, y = 46 + ((i - 1) % 3) * 74, 628 + math.floor((i - 1) / 3) * 28
    lg.setLineWidth(1.5)
    lg.rectangle("line", x, y, 16, 16)
    lg.print("Bed " .. r.bed, x + 21, y)
    if r.checked then
      lg.setColor(0.1, 0.4, 0.7)
      lg.setLineWidth(3)
      lg.line(x + 2, y + 8, x + 7, y + 14, x + 18, y - 3)
      lg.setColor(0.15, 0.15, 0.18)
    end
  end
  -- torch battery, bottom right
  local bx, by = 1090, 656
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", bx - 14, by - 30, 190, 68, 8)
  lg.setColor(1, 1, 1, 0.8)
  lg.setLineWidth(2)
  lg.rectangle("line", bx, by, 120, 26, 4)
  lg.rectangle("fill", bx + 122, by + 7, 6, 12, 2)
  local low = g.battery < 0.25
  for k = 0, 9 do
    if g.battery > k / 10 + 0.001 then
      lg.setColor(low and { 1, 0.3, 0.2 } or (g.light and { 1, 0.95, 0.6 } or { 0.7, 0.85, 0.7 }))
      lg.rectangle("fill", bx + 4 + k * 11.4, by + 4, 9, 18, 2)
    end
  end
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.75)
  lg.print(g.light and "TORCH  on" or "TORCH  (hold Space)", bx, by - 22)
  -- objective, top left
  lg.setColor(1, 1, 1, 0.6)
  lg.print(g:objective(), 28, 24)
  -- message line and prompt
  if g.msgT > 0 and g.msg then
    lg.setFont(f.body)
    local a = clamp(g.msgT, 0, 1)
    lg.setColor(0, 0, 0, 0.55 * a)
    lg.rectangle("fill", 290, 596, 740, 62, 8)
    lg.setColor(0.95, 0.93, 0.85, a)
    lg.printf(g.msg, 302, 604, 716, "center")
  end
  local pr = g:prompt()
  if pr then
    lg.setFont(f.body)
    local w = f.body:getWidth(pr) + 36
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 640 - w / 2, 520, w, 40, 20)
    lg.setColor(1, 0.8, 0.3)
    lg.printf(pr, 640 - w / 2, 528, w, "center")
  end
end

---------------------------------------------------------------------------------------
-- screens
---------------------------------------------------------------------------------------
function R.draw(g)
  R.fx(function()
    if g.peek then room(g) else corridor(g) end
    if g.mode == "caught" then
      -- everything goes, except its eyes
      local k = clamp(g.caughtT / 2.3, 0, 1)
      lg.setColor(0.4, 0, 0, 0.35 * math.sin(k * math.pi))
      lg.rectangle("fill", 0, 0, 1280, 720)
      lg.setColor(0, 0, 0, clamp((k - 0.75) * 4, 0, 1))
      lg.rectangle("fill", 0, 0, 1280, 720)
    end
  end)
  if g.mode == "play" then hud(g) end       -- after the film grade, so it stays crisp
  local f = R.fonts
  if g.mode == "dead" then
    lg.setColor(0, 0, 0)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setColor(0.95, 1, 0.9, 0.5 + 0.3 * love.math.noise(g.t * 2))
    lg.circle("fill", 610, 300, 5)
    lg.circle("fill", 670, 306, 5)
    lg.setFont(f.big)
    lg.setColor(0.75, 0.1, 0.08)
    lg.printf("It only walks in the dark.", 0, 400, 1280, "center")
    lg.setFont(f.body)
    lg.setColor(1, 1, 1, 0.7)
    lg.printf(("Beds checked: %d / %d      R  try again      Esc  title"):format(g.checked, #g.rooms), 0, 490, 1280, "center")
  elseif g.mode == "won" then
    lg.setColor(0.02, 0.03, 0.04, 0.9)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setFont(f.big)
    lg.setColor(0.9, 0.9, 0.82)
    lg.printf("06:00  -  shift over", 0, 250, 1280, "center")
    lg.setFont(f.body)
    lg.setColor(1, 1, 1, 0.75)
    lg.printf(("You clocked out after %d seconds, with %d%% battery left.\nBlackouts survived: %d      Times you drove it back: %d"):format(
      math.floor(g.time or 0), math.floor(g.battery * 100 + 0.5), g.stats.blackouts, g.stats.repels), 0, 340, 1280, "center")
    lg.setColor(1, 1, 1, 0.5)
    lg.printf("Bed 5 is still empty.", 0, 420, 1280, "center")
    lg.printf("R  another shift      Esc  title", 0, 500, 1280, "center")
  end
end

-- Title: the corridor itself, with nobody walking it.
function R.title(g, blink)
  R.fx(function() corridor(g) end)
  local f = R.fonts
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", 0, 120, 1280, 250)
  lg.setFont(f.title)
  lg.setColor(0.86, 0.9, 0.82)
  lg.printf("WARD C", 0, 132, 1280, "center")
  lg.setFont(f.body)
  lg.setColor(0.86, 0.9, 0.82, 0.8)
  lg.printf("night shift", 0, 236, 1280, "center")
  lg.setColor(1, 1, 1, 0.7)
  lg.printf("W / S  walk forward / back away        Space (hold)  torch        E  check a bed", 0, 290, 1280, "center")
  lg.printf("It only moves in the dark. Blackouts count. So does looking away.", 0, 322, 1280, "center")
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.5 + 0.35 * math.sin(blink * 3))
  lg.printf("press any key to start your round", 0, 660, 1280, "center")
end

return R
