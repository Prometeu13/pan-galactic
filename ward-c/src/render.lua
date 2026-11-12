-- Everything you see. First-person corridor in one-point perspective, done by hand:
--   screen = vanishing point + (x, y) * size / depth
--   depth  = facing * (z - your z)           (facing is +1 or -1: you can turn around)
-- A corridor is cut into thin slices along z; each slice asks the game how bright the
-- corridor is there (lamps + torch) and is painted in that brightness. Doors, lamps,
-- props and figures are sorted far-to-near and drawn the same way. Turning around is
-- nothing more than flipping the sign of `facing`: left and right swap by themselves.

local moonshine = require("moonshine")
local shack = require("shack")
local G = require("src.game")

local lg = love.graphics
local R = {}

local VX, VY = 640, 330          -- vanishing point
local HX, HY = 700, 470          -- half-size of the corridor's cross-section at depth 1
local NEAR, FAR = 0.7, 15
local STEP = 0.25
local view = { seg = "main", cam = 0, dir = 1 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function hash(n)
  local s = math.sin(n * 127.1 + 311.7) * 43758.5453
  return s - math.floor(s)
end

local function depth(z) return view.dir * (z - view.cam) end

-- x is a side of the corridor (-1 or +1 are the walls), y is height (-1 ceiling, 1 floor)
local function P(x, y, z)
  local d = math.max(NEAR, depth(z))
  return VX + x * view.dir * HX / d, VY + y * HY / d
end

local function quad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  local a, b = P(x1, y1, z1)
  local c, d = P(x2, y2, z2)
  local e, f = P(x3, y3, z3)
  local g, h = P(x4, y4, z4)
  lg.polygon("fill", a, b, c, d, e, f, g, h)
end

-- distance fog: the far end of a corridor is simply not there
local function fogD(d) return clamp((FAR - d) / 6, 0, 1) end
local function fog(z) return fogD(depth(z)) end
-- what the eye sees: dim is lifted a little, so dead-lamp stretches are murky, not blank
local function see(L) return L ^ 0.72 end

-- brightness of the corridor you are looking down, at z
local function lightAt(g, z)
  if view.seg == "annex" and z < 0 then return g:lightAt("main", G.J, true) end
  return g:lightAt(view.seg, z)
end

function R.load()
  R.fonts = { tiny = lg.newFont(11), small = lg.newFont(14), body = lg.newFont(20), big = lg.newFont(54), plate = lg.newFont(40), title = lg.newFont(88) }
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
  R.lastSeen = {}
end

function R.shake(amount) shack:setShake(amount) end
function R.update(dt) shack:update(dt) end

---------------------------------------------------------------------------------------
-- the corridor shell
---------------------------------------------------------------------------------------
local LOOK = {
  main = { wall = { 0.55, 0.6, 0.52 }, wain = { 0.33, 0.4, 0.35 }, rail = { 0.9, 0.9, 0.82 }, fa = { 0.48, 0.5, 0.46 }, fb = { 0.3, 0.33, 0.31 }, ceil = { 0.6, 0.61, 0.56 }, cols = 4, tile = 0.5 },
  annex = { wall = { 0.5, 0.49, 0.45 }, wain = { 0.36, 0.33, 0.28 }, rail = { 0.2, 0.2, 0.2 }, fa = { 0.4, 0.4, 0.38 }, fb = { 0.34, 0.34, 0.33 }, ceil = { 0.42, 0.42, 0.4 }, cols = 2, tile = 1 },
}

local function extent()
  if view.seg == "main" then return 0, G.LEN end
  return -2, G.ANNEX            -- the side corridor's view runs on across the main one
end

local function drawShell(g)
  local look = LOOK[view.seg]
  local lo, hi = extent()
  local a, b = view.cam + view.dir * NEAR, view.cam + view.dir * FAR
  local vmin, vmax = math.max(lo, math.min(a, b)), math.min(hi, math.max(a, b))
  if vmax <= vmin then return end
  local i0, i1 = math.floor(vmin / STEP), math.floor((vmax - 1e-6) / STEP)
  local from, to, inc = i1, i0, -1
  if view.dir < 0 then from, to, inc = i0, i1, 1 end
  for i = from, to, inc do
    local z1, z2 = math.max(i * STEP, vmin), math.min((i + 1) * STEP, vmax)
    if z2 > z1 then
      local mid = (z1 + z2) / 2
      local L = see(lightAt(g, mid)) * fog(mid)
      local crossing = (view.seg == "annex" and mid < 0)       -- where it crosses the main corridor
      local lk = crossing and LOOK.main or look
      lg.setColor(lk.ceil[1] * L, lk.ceil[2] * L, lk.ceil[3] * L)
      quad(-1, -1, z1, 1, -1, z1, 1, -1, z2, -1, -1, z2)
      if not crossing then
        for s = -1, 1, 2 do
          local stain = 0.85 + 0.15 * hash(i * 3.7 + s)
          lg.setColor(lk.wall[1] * L * stain, lk.wall[2] * L * stain, lk.wall[3] * L * stain)
          quad(s, -1, z1, s, 0.3, z1, s, 0.3, z2, s, -1, z2)
          lg.setColor(lk.wain[1] * L, lk.wain[2] * L, lk.wain[3] * L)
          quad(s, 0.3, z1, s, 1, z1, s, 1, z2, s, 0.3, z2)
          lg.setColor(lk.rail[1] * L, lk.rail[2] * L, lk.rail[3] * L)
          quad(s, 0.27, z1, s, 0.33, z1, s, 0.33, z2, s, 0.27, z2)
        end
        if view.seg == "annex" then
          -- pipes under the ceiling
          lg.setColor(0.22 * L, 0.2 * L, 0.18 * L)
          quad(-0.98, -0.86, z1, -0.98, -0.78, z1, -0.98, -0.78, z2, -0.98, -0.86, z2)
          lg.setColor(0.5 * L, 0.3 * L, 0.2 * L)
          quad(0.98, -0.9, z1, 0.98, -0.84, z1, 0.98, -0.84, z2, 0.98, -0.9, z2)
        end
      end
      local tile = math.floor(mid / lk.tile)
      for c = 0, lk.cols - 1 do
        local x1, x2 = -1 + c * 2 / lk.cols, -1 + (c + 1) * 2 / lk.cols
        local col = ((tile + c) % 2 == 0) and lk.fa or lk.fb
        lg.setColor(col[1] * L, col[2] * L, col[3] * L)
        quad(x1, 1, z1, x2, 1, z1, x2, 1, z2, x1, 1, z2)
      end
    end
  end
end

-- the rectangle of an end wall on screen, or nil if it is out of sight
local function endRect(z)
  local d = depth(z)
  if d <= NEAR or d > FAR then return nil end
  local x1, y1 = P(-1, -1, z)
  local x2, y2 = P(1, 1, z)
  if x1 > x2 then x1, x2 = x2, x1 end
  return x1, y1, x2 - x1, y2 - y1, 1 / d
end

-- EXIT end: double doors, chained, under a sign that never goes out
local function drawExitWall(g)
  local x, y, w, h, s = endRect(G.LEN)
  if not x then return end
  local L = see(lightAt(g, G.LEN)) * fog(G.LEN)
  lg.setColor(0.3 * L, 0.34 * L, 0.3 * L)
  lg.rectangle("fill", x, y, w, h)
  local dx, dw = x + w * 0.2, w * 0.6
  local dy, dh = y + h * 0.25, h * 0.75
  lg.setColor(0.2 * L + 0.01, 0.22 * L + 0.01, 0.2 * L + 0.01)
  lg.rectangle("fill", dx, dy, dw, dh)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", dx + dw / 2 - 1, dy, 2, dh)
  lg.circle("fill", dx + dw * 0.25, dy + 260 * s, 90 * s)
  lg.circle("fill", dx + dw * 0.75, dy + 260 * s, 90 * s)
  -- push bars, a chain and a padlock
  lg.setColor(0.5 * L, 0.5 * L, 0.5 * L)
  lg.rectangle("fill", dx + dw * 0.06, dy + dh * 0.55, dw * 0.38, 24 * s)
  lg.rectangle("fill", dx + dw * 0.56, dy + dh * 0.55, dw * 0.38, 24 * s)
  lg.setColor(0.62 * L + 0.03, 0.6 * L + 0.03, 0.5 * L + 0.02)
  lg.setLineWidth(math.max(1, 16 * s))
  lg.line(dx + dw * 0.3, dy + dh * 0.5, dx + dw * 0.5, dy + dh * 0.62, dx + dw * 0.7, dy + dh * 0.5)
  lg.rectangle("fill", dx + dw * 0.5 - 36 * s, dy + dh * 0.62, 72 * s, 60 * s, 8 * s)
  local ex, ey = x + w / 2, y + h * 0.17
  lg.setColor(0.9, 0.1, 0.08)
  lg.rectangle("fill", ex - 200 * s, ey - 70 * s, 400 * s, 140 * s, 2)
  if s > 0.12 then
    lg.setFont(R.fonts.plate)
    lg.setColor(1, 0.9, 0.85)
    lg.printf("EXIT", ex - 200 * s, ey - 58 * s, 400 / 2.6, "center", 0, s * 2.6, s * 2.6)
  end
  lg.setBlendMode("add")
  lg.setColor(1, 0.1, 0.05, 0.5)
  lg.draw(R.glow, ex, ey, 0, 16 * s, 12 * s, 64, 64)
  lg.setBlendMode("alpha")
end

-- station end: a desk under a warm lamp, the wall clock, the time-clock machine
local function drawStationWall(g)
  local x, y, w, h, s = endRect(0)
  if not x then return end
  local L = see(lightAt(g, 0.3)) * fog(0)
  local warm = (g.blackout > 0) and 0.25 or 1
  lg.setColor(0.42 * L + 0.05 * warm, 0.44 * L + 0.04 * warm, 0.4 * L + 0.02 * warm)
  lg.rectangle("fill", x, y, w, h)
  -- notice board
  lg.setColor(0.36 * L + 0.05 * warm, 0.26 * L + 0.03 * warm, 0.16 * L + 0.02 * warm)
  lg.rectangle("fill", x + w * 0.08, y + h * 0.2, w * 0.3, h * 0.26)
  for k = 0, 5 do
    lg.setColor(0.8 * L + 0.08 * warm, 0.8 * L + 0.08 * warm, 0.7 * L + 0.06 * warm)
    lg.rectangle("fill", x + w * (0.1 + (k % 3) * 0.09), y + h * (0.22 + math.floor(k / 3) * 0.12), w * 0.07, h * 0.09)
  end
  -- wall clock: the night is long
  local cx, cy, cr = x + w * 0.5, y + h * 0.22, h * 0.07
  lg.setColor(0.85 * L + 0.1 * warm, 0.85 * L + 0.1 * warm, 0.8 * L + 0.08 * warm)
  lg.circle("fill", cx, cy, cr)
  lg.setColor(0.05, 0.05, 0.05)
  lg.setLineWidth(math.max(1, 10 * s))
  local hrs = 3.2 + g.t / 300
  lg.line(cx, cy, cx + math.sin(hrs / 12 * math.pi * 2) * cr * 0.5, cy - math.cos(hrs / 12 * math.pi * 2) * cr * 0.5)
  lg.line(cx, cy, cx + math.sin(hrs * math.pi * 2) * cr * 0.8, cy - math.cos(hrs * math.pi * 2) * cr * 0.8)
  -- time-clock machine with a green light
  lg.setColor(0.2 * L + 0.03, 0.22 * L + 0.03, 0.24 * L + 0.03)
  lg.rectangle("fill", x + w * 0.68, y + h * 0.3, w * 0.14, h * 0.2, 6 * s)
  lg.setColor(0.2, 0.9, 0.4)
  lg.circle("fill", x + w * 0.75, y + h * 0.34, 14 * s)
  lg.setBlendMode("add")
  lg.setColor(0.2, 0.9, 0.4, 0.35)
  lg.draw(R.glow, x + w * 0.75, y + h * 0.34, 0, 3 * s, 3 * s, 64, 64)
  lg.setBlendMode("alpha")
  -- the desk and its lamp
  lg.setColor(0.3 * L + 0.07 * warm, 0.22 * L + 0.05 * warm, 0.14 * L + 0.03 * warm)
  lg.rectangle("fill", x + w * 0.04, y + h * 0.66, w * 0.92, h * 0.34)
  lg.setColor(0.42 * L + 0.1 * warm, 0.32 * L + 0.07 * warm, 0.2 * L + 0.04 * warm)
  lg.rectangle("fill", x + w * 0.02, y + h * 0.63, w * 0.96, h * 0.05)
  lg.setColor(0.1, 0.1, 0.1)
  lg.rectangle("fill", x + w * 0.3, y + h * 0.56, w * 0.12, h * 0.07, 4 * s)        -- telephone
  lg.setColor(0.2, 0.45, 0.3)
  lg.polygon("fill", x + w * 0.56, y + h * 0.52, x + w * 0.7, y + h * 0.52, x + w * 0.74, y + h * 0.58, x + w * 0.52, y + h * 0.58)
  lg.rectangle("fill", x + w * 0.62, y + h * 0.58, w * 0.012, h * 0.05)
  lg.setBlendMode("add")
  lg.setColor(1, 0.8, 0.45, 0.5 * warm)
  lg.draw(R.glow, x + w * 0.63, y + h * 0.62, 0, 9 * s, 5 * s, 64, 64)
  lg.setBlendMode("alpha")
  if s > 0.1 then
    lg.setFont(R.fonts.plate)
    lg.setColor(0.08, 0.08, 0.08, clamp(L * 3 + 0.3 * warm, 0, 1))
    lg.printf("NURSES' STATION", x, y + h * 0.06, w / (s * 1.6), "center", 0, s * 1.6, s * 1.6)
  end
end

-- end of the side corridor: the supply shelves
local function drawShelfWall(g)
  local x, y, w, h, s = endRect(G.ANNEX)
  if not x then return end
  local L = see(lightAt(g, G.ANNEX - 0.5)) * fog(G.ANNEX)
  lg.setColor(0.3 * L, 0.3 * L, 0.28 * L)
  lg.rectangle("fill", x, y, w, h)
  -- steel shelving: uprights, four shelves
  lg.setColor(0.45 * L, 0.47 * L, 0.5 * L)
  for k = 0, 3 do lg.rectangle("fill", x + w * (0.05 + k * 0.2), y + h * 0.1, w * 0.02, h * 0.9) end
  for k = 0, 3 do lg.rectangle("fill", x + w * 0.05, y + h * (0.28 + k * 0.2), w * 0.62, h * 0.025) end
  -- boxes
  for k = 0, 8 do
    local bx = x + w * (0.08 + (k % 3) * 0.2)
    local by = y + h * (0.28 + math.floor(k / 3) * 0.2)
    local bh = h * (0.08 + hash(k) * 0.07)
    lg.setColor((0.5 + hash(k + 3) * 0.2) * L, (0.4 + hash(k + 5) * 0.15) * L, 0.28 * L)
    lg.rectangle("fill", bx, by - bh, w * 0.15, bh)
  end
  -- water jugs (blue) and folded blankets
  local waterNeeded, blanketNeeded = false, false
  for _, r in ipairs(g.rooms) do
    if r.request == "asked" then
      if r.asks == "water" then waterNeeded = true else blanketNeeded = true end
    end
  end
  for k = 0, 2 do
    lg.setColor(0.3 * L + 0.02, 0.55 * L + 0.04, 0.8 * L + 0.06)
    lg.rectangle("fill", x + w * (0.09 + k * 0.06), y + h * 0.86 - h * 0.12, w * 0.045, h * 0.12, 6 * s)
  end
  for k = 0, 2 do
    lg.setColor((0.7 - k * 0.08) * L, (0.5 + k * 0.05) * L, (0.5 + k * 0.08) * L)
    lg.rectangle("fill", x + w * 0.3, y + h * (0.86 - 0.035 * (k + 1)), w * 0.3, h * 0.03, 4 * s)
  end
  if g.shelfBattery then
    lg.setColor(0.85 * L + 0.05, 0.75 * L + 0.05, 0.2 * L)
    lg.rectangle("fill", x + w * 0.5, y + h * 0.66 - h * 0.04, w * 0.1, h * 0.04, 3 * s)
  end
  -- key cabinet on the wall to the right
  lg.setColor(0.7 * L + 0.06, 0.12 * L + 0.01, 0.1 * L + 0.01)
  lg.rectangle("fill", x + w * 0.74, y + h * 0.3, w * 0.18, h * 0.24, 6 * s)
  lg.setColor(0.1, 0.1, 0.1)
  lg.rectangle("fill", x + w * 0.76, y + h * 0.33, w * 0.14, h * 0.18)
  if not g.items.key then
    lg.setColor(0.9 * L + 0.1, 0.8 * L + 0.08, 0.3 * L + 0.03)
    lg.circle("fill", x + w * 0.83, y + h * 0.38, 20 * s)
    lg.rectangle("fill", x + w * 0.83 - 6 * s, y + h * 0.38, 12 * s, 70 * s)
    lg.rectangle("fill", x + w * 0.83, y + h * 0.38 + 50 * s, 26 * s, 10 * s)
  end
  -- highlight what you came for
  if (waterNeeded or blanketNeeded or not g.items.key) and s > 0.1 then
    lg.setBlendMode("add")
    local a = 0.2 + 0.15 * math.sin(g.t * 5)
    if waterNeeded then lg.setColor(0.4, 0.7, 1, a) lg.draw(R.glow, x + w * 0.17, y + h * 0.8, 0, 6 * s, 5 * s, 64, 64) end
    if blanketNeeded then lg.setColor(1, 0.7, 0.7, a) lg.draw(R.glow, x + w * 0.45, y + h * 0.8, 0, 7 * s, 4 * s, 64, 64) end
    if not g.items.key then lg.setColor(1, 0.8, 0.3, a) lg.draw(R.glow, x + w * 0.83, y + h * 0.42, 0, 5 * s, 5 * s, 64, 64) end
    lg.setBlendMode("alpha")
  end
end

-- looking out of the side corridor: the far wall of the main one
local function drawAcrossWall(g)
  local x, y, w, h = endRect(-2)
  if not x then return end
  local L = see(g:lightAt("main", G.J, true)) * fog(-2)
  local lk = LOOK.main
  lg.setColor(lk.wall[1] * L, lk.wall[2] * L, lk.wall[3] * L)
  lg.rectangle("fill", x, y, w, h * 0.65)
  lg.setColor(lk.wain[1] * L, lk.wain[2] * L, lk.wain[3] * L)
  lg.rectangle("fill", x, y + h * 0.65, w, h * 0.35)
  lg.setColor(lk.rail[1] * L, lk.rail[2] * L, lk.rail[3] * L)
  lg.rectangle("fill", x, y + h * 0.635, w, h * 0.03)
end

---------------------------------------------------------------------------------------
-- things in the corridor (depth sorting happens in corridor())
---------------------------------------------------------------------------------------
local function drawDoor(g, r)
  local s, z1, z2 = r.side, r.z - 0.45, r.z + 0.45
  if math.max(depth(z1), depth(z2)) <= NEAR then return end
  local L = see(lightAt(g, r.z)) * fog(r.z)
  lg.setColor(0.2 * L, 0.22 * L, 0.18 * L)
  quad(s, -0.42, z1 - 0.06, s, 1, z1 - 0.06, s, 1, z2 + 0.06, s, -0.42, z2 + 0.06)
  lg.setColor(0.4 * L, 0.36 * L, 0.28 * L)
  quad(s, -0.36, z1, s, 1, z1, s, 1, z2, s, -0.36, z2)
  -- window slot and handle
  lg.setColor(0.02, 0.03, 0.03)
  quad(s, -0.24, z1 + 0.2, s, 0.02, z1 + 0.2, s, 0.02, z1 + 0.5, s, -0.24, z1 + 0.5)
  lg.setColor(0.6 * L, 0.6 * L, 0.55 * L)
  quad(s, 0.36, z1 + 0.08, s, 0.42, z1 + 0.08, s, 0.42, z1 + 0.18, s, 0.36, z1 + 0.18)
  -- call light above the door:
  --   amber, blinking = bed not checked yet        blue = the patient is waiting for something
  --   green = checked, and you can still hide here  dark = checked, lock broken
  local d = depth(r.z)
  if d > NEAR then
    local cx, cy = P(s * 0.985, -0.52, r.z)
    local rad = 26 / d
    local f = fog(r.z)
    local col, pulse
    if not r.checked then col, pulse = { 1, 0.7, 0.15 }, 0.55 + 0.45 * math.sin(g.t * 5 + r.bed)
    elseif r.request == "asked" or r.request == "carried" then col, pulse = { 0.3, 0.6, 1 }, 0.7 + 0.3 * math.sin(g.t * 3)
    elseif not r.lockUsed then col, pulse = { 0.2, 0.8, 0.35 }, 0.35
    else col, pulse = { 0.12, 0.14, 0.12 }, 0 end
    lg.setColor(col[1], col[2], col[3], f)
    lg.circle("fill", cx, cy, rad)
    if pulse > 0 then
      lg.setBlendMode("add")
      lg.setColor(col[1], col[2], col[3], 0.55 * pulse * f)
      lg.draw(R.glow, cx, cy, 0, rad / 9, rad / 9, 64, 64)
      lg.setBlendMode("alpha")
    end
  end
  -- bed number plate on the wall, on the side of the door that is nearer to you
  local za, zb = r.z - view.dir * 0.77, r.z - view.dir * 0.53
  if depth(za) > NEAR then
    lg.setColor(0.8 * L, 0.78 * L, 0.66 * L)
    quad(s, -0.33, za, s, -0.19, za, s, -0.19, zb, s, -0.33, zb)
    local xa, ya = P(s, -0.33, za)
    local xb = P(s, -0.33, zb)
    local ph = 0.14 * HY / depth((za + zb) / 2)
    lg.setColor(0.08, 0.08, 0.08, clamp(L * 3, 0, 1))
    lg.setFont(R.fonts.plate)
    local sc = ph / 46
    lg.print(tostring(r.bed), math.min(xa, xb) + math.abs(xb - xa) * 0.28, ya + ph * 0.02, 0, sc * 0.8, sc)
  end
end

-- the opening of the side corridor in the right-hand wall
local function drawOpening(g)
  local z1, z2 = G.J - 0.6, G.J + 0.6
  if math.max(depth(z1), depth(z2)) <= NEAR then return end
  local L = see(lightAt(g, G.J)) * fog(G.J)
  local inner = see(g:lightAt("annex", 1.5, true)) * fog(G.J) * 0.75
  lg.setColor(0.2 * L, 0.2 * L, 0.18 * L)
  quad(1, -0.62, z1 - 0.08, 1, 1, z1 - 0.08, 1, 1, z2 + 0.08, 1, -0.62, z2 + 0.08)
  -- the passage itself: x beyond 1 is "through the wall", so the same projection draws
  -- a little way into it: darkness further in, its far-side wall, its floor
  local zf = (depth(z1) > depth(z2)) and z1 or z2           -- the edge farther from you
  local ak = LOOK.annex
  lg.setColor(0.015 + 0.1 * inner, 0.015 + 0.1 * inner, 0.015 + 0.09 * inner)
  quad(1, -0.55, z1, 1, 1, z1, 1, 1, z2, 1, -0.55, z2)
  lg.setColor(ak.wall[1] * inner, ak.wall[2] * inner, ak.wall[3] * inner)
  quad(1, -0.55, zf, 1.7, -0.55, zf, 1.7, 0.3, zf, 1, 0.3, zf)
  lg.setColor(ak.wain[1] * inner, ak.wain[2] * inner, ak.wain[3] * inner)
  quad(1, 0.3, zf, 1.7, 0.3, zf, 1.7, 1, zf, 1, 1, zf)
  lg.setColor(ak.fa[1] * inner * 1.2, ak.fa[2] * inner * 1.2, ak.fa[3] * inner * 1.2)
  quad(1, 1, z1, 1.7, 1, z1, 1.7, 1, z2, 1, 1, z2)
  -- sign above it
  local d = depth(G.J)
  if math.min(depth(z1), depth(z2)) > NEAR + 0.3 then
    lg.setColor(0.15 * L + 0.02, 0.3 * L + 0.04, 0.5 * L + 0.06)
    quad(1, -0.78, z1 + 0.1, 1, -0.64, z1 + 0.1, 1, -0.64, z2 - 0.1, 1, -0.78, z2 - 0.1)
    local xa, ya = P(1, -0.78, z1 + 0.1)
    local xb = P(1, -0.78, z2 - 0.1)
    local wpx = math.abs(xb - xa)
    if wpx > 34 then
      lg.setFont(R.fonts.plate)
      lg.setColor(1, 1, 1, clamp(L * 2 + 0.3, 0, 1) * fog(G.J))
      local sc = wpx / 250
      lg.print("SUPPLIES", math.min(xa, xb) + wpx * 0.08, ya + 0.02 * HY / d, 0, sc, 0.13 * HY / d / 46)
    end
  end
end

local function drawLamp(g, l)
  if math.max(depth(l.z - 0.16), depth(l.z + 0.16)) <= NEAR then return end
  local f = fog(l.z)
  local I = l.I
  lg.setColor((0.12 + 0.88 * I) * f, (0.13 + 0.87 * I) * f, (0.11 + 0.8 * I) * f)
  quad(-0.3, -0.985, l.z - 0.16, 0.3, -0.985, l.z - 0.16, 0.3, -0.985, l.z + 0.16, -0.3, -0.985, l.z + 0.16)
  if I > 0.05 and depth(l.z) > NEAR then
    local x, y = P(0, -0.985, l.z)
    local s = 1 / depth(l.z)
    lg.setBlendMode("add")
    lg.setColor(0.85, 1, 0.85, 0.5 * I * f)
    lg.draw(R.glow, x, y, 0, 6 * s, 3 * s, 64, 64)
    local fx, fy = P(0, 1, l.z)                          -- its reflection in the floor
    lg.setColor(0.8, 0.95, 0.85, 0.3 * I * f)
    lg.draw(R.glow, fx, fy + 30 * s, 0, 5.5 * s, 2.2 * s, 64, 64)
    lg.setBlendMode("alpha")
  end
end

-- a box on legs against a wall: the gurney (main) and the trolley (side corridor)
local function drawCart(g, x1, x2, zc, len, top, sheet)
  local za, zb = zc, zc + len
  if math.max(depth(za), depth(zb)) <= NEAR + 0.05 then return end
  local L = see(lightAt(g, zc)) * fog(zc)
  local zn = (depth(za) < depth(zb)) and za or zb          -- the end nearer to you
  local xin = (math.abs(x1) < math.abs(x2)) and x1 or x2   -- the side facing the corridor
  if depth(zn) > NEAR then
    lg.setColor(0.12 * L, 0.12 * L, 0.12 * L)
    lg.setLineWidth(clamp(10 / depth(zn), 1, 12))
    for _, x in ipairs({ x1, x2 }) do
      local ax, ay = P(x, top + 0.08, zn)
      local bx, by = P(x, 1, zn)
      lg.line(ax, ay, bx, by)
    end
  end
  lg.setColor(0.6 * L, 0.62 * L, 0.6 * L)
  quad(x1, top, za, x2, top, za, x2, top, zb, x1, top, zb)
  lg.setColor(0.4 * L, 0.42 * L, 0.4 * L)
  quad(xin, top, za, xin, top + 0.08, za, xin, top + 0.08, zb, xin, top, zb)
  lg.setColor(0.75 * L, 0.76 * L, 0.72 * L)
  quad(x1, top, zn, x2, top, zn, x2, top + 0.08, zn, x1, top + 0.08, zn)
  if sheet then
    lg.setColor(0.7 * L, 0.72 * L, 0.68 * L)
    quad(xin, top, za + len * 0.2, xin, top, za + len * 0.85, xin, 0.86, za + len * 0.75, xin, 0.8, za + len * 0.3)
  end
end

local function drawWheelchair(g, wz)
  local d = depth(wz)
  if d <= NEAR then return end
  local L = see(lightAt(g, wz)) * fog(wz)
  local x, y = P(-0.72, 1, wz)
  local u = HY / d
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

-- Figure A: too tall, arms too long, head tilted. Sizes are in corridor units.
-- d = how far away it is, wx = where across the corridor it stands (-1..1).
local function drawTall(g, f, d, wx, lit)
  local t = g.t
  local dd = math.max(0.45, d)
  local u = HY / dd
  local fx, fy = VX + wx * view.dir * HX / dd, VY + HY / dd
  -- when it is on top of you it stoops, so its face (not its chest) fills your view
  local stoop = clamp(1 - (d - 0.5) / 1.3, 0, 1)
  fy = fy + stoop * ((VY + 60 + 1.45 * u) - fy)
  local frozen = g.light and not f.moving and f.state == "still"
  local tw = frozen and math.sin(t * 40) * 0.006 * u * (f.exposure * 2) or 0     -- it shudders in the beam
  local sway = math.sin(t * 0.9) * 0.02 * u + tw
  local gown = { 0.02 + 0.5 * lit, 0.02 + 0.56 * lit, 0.03 + 0.52 * lit }
  local skin = { 0.02 + 0.42 * lit, 0.02 + 0.4 * lit, 0.03 + 0.38 * lit }
  lg.setColor(skin)
  lg.polygon("fill", fx - 0.07 * u, fy, fx - 0.03 * u, fy, fx + sway, fy - 0.72 * u, fx - 0.06 * u + sway, fy - 0.72 * u)
  lg.polygon("fill", fx + 0.03 * u, fy, fx + 0.07 * u, fy, fx + 0.06 * u + sway, fy - 0.72 * u, fx + sway, fy - 0.72 * u)
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
  lg.setColor(0.01, 0.01, 0.012)
  lg.ellipse("fill", -0.022 * u, -0.03 * u, 0.018 * u, 0.02 * u)
  lg.ellipse("fill", 0.022 * u, -0.03 * u, 0.018 * u, 0.02 * u)
  lg.ellipse("fill", 0, 0.03 * u, 0.02 * u, 0.012 * u + reach * 0.02 * u)
  lg.setLineWidth(math.max(1, 0.012 * u))
  for k = -2, 2 do lg.line(k * 0.02 * u, -0.07 * u, k * 0.034 * u, 0.12 * u + math.abs(k) * 0.02 * u) end
  -- the eyes: the only light it has, so you see them even in a blackout
  local a = 0.5 + 0.5 * love.math.noise(t * 2)
  lg.setColor(0.95, 1, 0.9, (0.6 + 0.4 * a) * clamp(fogD(d) * 2, 0, 1))
  lg.circle("fill", -0.022 * u, -0.03 * u, math.max(1.2, 0.0085 * u))
  lg.circle("fill", 0.022 * u, -0.03 * u, math.max(1.2, 0.0085 * u))
  lg.pop()
end

-- Figure B: what was under Bed 5. Low, on all fours, elbows above its back.
local function drawCrawler(g, f, d, wx, lit)
  local t = g.t
  local dd = math.max(0.45, d)
  local u = HY / dd
  local fx, fy = VX + wx * view.dir * HX / dd, VY + HY / dd
  local rise = clamp(1 - (d - 0.5) / 1.5, 0, 1)                 -- it rears up when it has you
  fy = fy + rise * ((VY + 40 + 0.5 * u) - fy)
  local crawl = f.moving and math.sin(t * 9) or math.sin(t * 1.3) * 0.3
  local skin = { 0.02 + 0.3 * lit, 0.02 + 0.33 * lit, 0.03 + 0.3 * lit }
  local dark = { skin[1] * 0.6, skin[2] * 0.6, skin[3] * 0.6 }
  local w = math.max(1.5, 0.04 * u)
  -- hind legs, knees out
  lg.setColor(dark)
  lg.setLineWidth(w)
  for s = -1, 1, 2 do
    lg.line(fx + s * 0.1 * u, fy - 0.24 * u, fx + s * 0.3 * u, fy - 0.42 * u - s * crawl * 0.03 * u, fx + s * 0.27 * u, fy)
  end
  -- body: a hump
  lg.setColor(skin)
  lg.ellipse("fill", fx, fy - 0.28 * u, 0.2 * u, 0.15 * u)
  lg.setColor(dark)
  for k = -2, 2 do lg.circle("fill", fx + k * 0.05 * u, fy - 0.41 * u + math.abs(k) * 0.02 * u, 0.018 * u) end   -- spine
  -- arms: elbows high above the back, hands flat on the floor in front
  lg.setColor(skin)
  for s = -1, 1, 2 do
    local step = s * crawl * 0.05 * u
    lg.line(fx + s * 0.14 * u, fy - 0.3 * u, fx + s * 0.34 * u, fy - 0.62 * u + step, fx + s * 0.2 * u, fy - 0.02 * u - rise * 0.5 * u)
    lg.circle("fill", fx + s * 0.2 * u, fy - 0.02 * u - rise * 0.5 * u, 0.03 * u)
  end
  -- head: hangs low between the arms, upside-down-ish; hair drags
  local hx, hy = fx + math.sin(t * 0.8) * 0.02 * u, fy - 0.2 * u - rise * 0.25 * u
  lg.setColor(skin)
  lg.ellipse("fill", hx, hy, 0.075 * u, 0.09 * u)
  lg.setColor(0.01, 0.01, 0.012)
  lg.setLineWidth(math.max(1, 0.012 * u))
  for k = -3, 3 do lg.line(hx + k * 0.02 * u, hy - 0.06 * u, hx + k * 0.03 * u, hy + 0.2 * u) end
  lg.ellipse("fill", hx, hy + 0.045 * u, 0.03 * u, 0.012 * u + rise * 0.03 * u)
  -- amber eyes
  local a = 0.5 + 0.5 * love.math.noise(t * 3 + 9)
  lg.setColor(1, 0.75, 0.25, (0.65 + 0.35 * a) * clamp(fogD(d) * 2, 0, 1))
  lg.circle("fill", hx - 0.028 * u, hy - 0.01 * u, math.max(1.2, 0.01 * u))
  lg.circle("fill", hx + 0.028 * u, hy - 0.01 * u, math.max(1.2, 0.01 * u))
end

local function drawFigure(g, f, d, wx)
  if d <= 0.3 or d > FAR + 1 then return end
  local lit = clamp(g:lightAt(f.seg, f.p) * fogD(d) * 1.1, 0, 1)
  if g.mode == "caught" then lit = math.max(lit, 0.55) end     -- your dropped torch, from below
  if f.kind == "B" then drawCrawler(g, f, d, wx, lit) else drawTall(g, f, d, wx, lit) end
end

---------------------------------------------------------------------------------------
-- the corridor view
---------------------------------------------------------------------------------------
local function corridor(g)
  view.seg, view.cam, view.dir = g.seg, g.z, g.dir
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
  local things = {}
  local function add(z, fn) things[#things + 1] = { d = depth(z), fn = fn } end
  if view.seg == "main" then
    drawExitWall(g)
    drawStationWall(g)
    for _, r in ipairs(g.rooms) do add(r.z + view.dir * 0.45, function() drawDoor(g, r) end) end
    add(G.J + view.dir * 0.6, function() drawOpening(g) end)
    add(10.4 + (view.dir > 0 and 0.95 or 0), function() drawCart(g, 0.55, 0.98, 10.4, 0.95, 0.52, true) end)
    add(21.6, function() drawWheelchair(g, 21.6) end)
  else
    drawShelfWall(g)
    drawAcrossWall(g)
    add(4.2 + (view.dir > 0 and 0.7 or 0), function() drawCart(g, -0.98, -0.6, 4.2, 0.7, 0.45, false) end)
  end
  for _, l in ipairs(g.lamps[view.seg]) do add(l.z, function() drawLamp(g, l) end) end
  for _, f in ipairs(g.figs) do
    if f.active and not f.inside then
      if f.seg == view.seg then
        things[#things + 1] = { d = depth(f.p), fn = function() drawFigure(g, f, depth(f.p), f.kind == "B" and -0.1 or 0.06) end }
      elseif view.seg == "annex" and math.abs(f.p - G.J) < G.CORNER + 0.5 then
        -- standing in the junction, seen from inside the side corridor
        local d = depth(0) + 0.6
        things[#things + 1] = { d = d, fn = function() drawFigure(g, f, d, clamp((f.p - G.J) * 0.55, -0.8, 0.8)) end }
      elseif view.seg == "main" and f.seg == "annex" and f.p < G.CORNER + 0.5 then
        -- standing in the mouth of the side corridor
        local d = depth(G.J)
        things[#things + 1] = { d = d, fn = function() drawFigure(g, f, d, 0.8) end }
      end
    end
  end
  table.sort(things, function(a, b) return a.d > b.d end)
  for _, th in ipairs(things) do
    if th.d > 0.3 and th.d < FAR + 1 then th.fn() end
  end
  -- dust in the light
  lg.setBlendMode("add")
  for k = 0, 50 do
    local d = 1 + ((hash(k) * 9 - view.dir * g.z) % 9)
    local z = view.cam + view.dir * d
    local x = (hash(k + 50) - 0.5) * 1.6 + math.sin(t * 0.3 + k) * 0.05
    local y = -0.9 + ((hash(k + 90) + t * 0.02) % 1) * 1.6
    local px, py = P(x, y, z)
    lg.setColor(1, 1, 0.9, 0.35 * lightAt(g, z))
    lg.circle("fill", px, py, 2.4 / d)
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
  -- one of them is close: the edges of your vision pulse (even if it is behind you)
  local _, gap = g:nearest()
  if gap < 7 and g.mode == "play" then
    local k = (1 - gap / 7) * (0.5 + 0.5 * math.sin(t * (6 + (7 - gap))))
    lg.setColor(0.5, 0, 0, 0.16 * k)
    lg.setLineWidth(70)
    lg.rectangle("line", 0, 0, 1280, 720, 60)
    lg.setLineWidth(30)
    lg.rectangle("line", 0, 0, 1280, 720, 30)
  end
  -- turning around: the view swings through black
  if g.turn then
    lg.setColor(0, 0, 0, math.sin((1 - g.turn / G.TURN_TIME) * math.pi))
    lg.rectangle("fill", 0, 0, 1280, 720)
  end
end

local function progress(g, text)
  local b = g.busy
  local p = clamp(b.t / b.dur, 0, 1)
  lg.setColor(1, 1, 1, 0.25)
  lg.rectangle("fill", 440, 664, 400, 4)
  lg.setColor(1, 0.8, 0.3)
  lg.rectangle("fill", 440, 664, 400 * p, 4)
  lg.setFont(R.fonts.small)
  lg.setColor(1, 1, 1, 0.75)
  lg.printf(text, 0, 636, 1280, "center")
end

---------------------------------------------------------------------------------------
-- looking into a room (checking a bed, or bringing something)
---------------------------------------------------------------------------------------
local function room(g)
  local pk = g.busy
  local r = pk.room
  local t = g.t
  local open = clamp(pk.t / 0.35, 0, 1)
  lg.clear(0.015, 0.02, 0.03, 1)
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
    lg.setColor(0.46, 0.5, 0.54)
    lg.polygon("fill", 470, 432, 640, 400, 760, 424, 844, 432, 844, 474, 470, 474)
    lg.setColor(0.3, 0.33, 0.37)
    lg.polygon("fill", 470, 432, 640, 400, 600, 440)
    -- under the bed: two points of amber, if it is at home
    local bfig = g.figs[2]
    if not bfig.active or bfig.inside then
      lg.setColor(1, 0.75, 0.25, 0.5 + 0.4 * love.math.noise(t * 3))
      lg.circle("fill", 560, 536, 3)
      lg.circle("fill", 580, 537, 3)
    end
  else
    local breathe = math.sin(t * 1.6) * 5
    local tucked = (pk.kind == "deliver" and r.asks == "blanket") or (r.asks == "blanket" and r.request == "done")
    lg.setColor(tucked and { 0.55, 0.4, 0.42 } or { 0.36, 0.42, 0.5 })
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
  -- bedside table: batteries if this room has them, the water once you've brought it
  lg.setColor(0.14, 0.13, 0.12)
  lg.rectangle("fill", 150, 450, 80, 110)
  if r.battery and pk.kind == "check" then
    lg.setColor(0.8, 0.7, 0.2)
    lg.rectangle("fill", 170, 436, 30, 14, 3)
    lg.setColor(0.2, 0.2, 0.2)
    lg.rectangle("fill", 200, 440, 5, 6)
    lg.setBlendMode("add")
    lg.setColor(1, 0.9, 0.4, 0.3 + 0.2 * math.sin(t * 6))
    lg.draw(R.glow, 186, 442, 0, 0.9, 0.6, 64, 64)
    lg.setBlendMode("alpha")
  end
  if r.asks == "water" and (pk.kind == "deliver" or r.request == "done") then
    lg.setColor(0.4, 0.65, 0.9, 0.9)
    lg.rectangle("fill", 172, 414, 26, 36, 5)
    lg.setColor(0.8, 0.9, 1, 0.8)
    lg.rectangle("fill", 172, 414, 26, 6, 3)
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
  if pk.kind == "deliver" then
    progress(g, ("bringing Bed %d the %s ...   (you can't see the corridor from here)"):format(r.bed, r.asks))
  else
    progress(g, ("checking Bed %d ...   (you can't see the corridor from here)"):format(r.bed))
  end
end

---------------------------------------------------------------------------------------
-- hiding: inside a room, back to the wall, watching the door
---------------------------------------------------------------------------------------
local function hideStatus(g)
  local closest, cgap
  for _, f in ipairs(g.figs) do
    if f.active and not f.inside then
      local gap = g:gap(f)
      if not closest or gap < cgap then closest, cgap = f, gap end
    end
  end
  if not closest or closest.lost then return "quiet", closest, cgap or math.huge end
  if closest.state == "linger" or (closest.state ~= "wander" and cgap < 0.9) then return "outside", closest, cgap end
  if closest.state == "wander" then return (cgap < 9) and "leaving" or "quiet", closest, cgap end
  if cgap < 12 then return "coming", closest, cgap end
  return "quiet", closest, cgap
end

local function hideView(g)
  local h = g.hide
  local r = h.room
  local t = g.t
  local status, fig, gap = hideStatus(g)
  local L = see(g:lightAt("main", r.z, true))                  -- how bright the corridor is outside
  lg.clear(0.01, 0.012, 0.018, 1)
  -- the wall with the door in it
  lg.setColor(0.05, 0.06, 0.075)
  lg.rectangle("fill", 0, 0, 1280, 640)
  lg.setColor(0.03, 0.035, 0.045)
  lg.rectangle("fill", 0, 640, 1280, 80)
  -- the bed, at the edge of your eye; someone asleep in it (not in Bed 5)
  lg.setColor(0.07, 0.08, 0.1)
  lg.rectangle("fill", 0, 470, 330, 30)
  lg.rectangle("fill", 316, 400, 14, 200)
  if not r.empty then
    lg.setColor(0.1, 0.12, 0.15)
    lg.ellipse("fill", 120, 462, 200, 36 + math.sin(t * 1.6) * 4)
  end
  -- door
  local dx, dy, dw, dh = 470, 70, 340, 574
  lg.setColor(0.09, 0.085, 0.07)
  lg.rectangle("fill", dx - 14, dy - 14, dw + 28, dh + 14)
  lg.setColor(0.13, 0.12, 0.095)
  lg.rectangle("fill", dx, dy, dw, dh)
  -- light under the door, and the slot window: your only view of the corridor
  local sx, sy, sw, sh = dx + 95, dy + 70, 150, 190
  lg.setColor(0.5 * L, 0.56 * L, 0.5 * L)
  lg.rectangle("fill", sx, sy, sw, sh)
  lg.rectangle("fill", dx, dy + dh, dw, 7)
  lg.setBlendMode("add")
  lg.setColor(0.5, 0.6, 0.5, 0.1 * L)
  lg.polygon("fill", dx, dy + dh + 7, dx + dw, dy + dh + 7, dx + dw + 120, 720, dx - 120, 720)
  lg.draw(R.soft, sx + sw / 2, sy + sh / 2, 0, 5, 5, 64, 64)
  lg.setBlendMode("alpha")
  -- wire glass in the slot
  lg.setColor(0, 0, 0, 0.35)
  lg.setLineWidth(1)
  for k = 1, 5 do lg.line(sx + k * sw / 6, sy, sx + k * sw / 6, sy + sh) end
  for k = 1, 7 do lg.line(sx, sy + k * sh / 8, sx + sw, sy + k * sh / 8) end
  -- something walking up: a shadow sliding across the strip of light under the door
  if fig and gap < 6 and status ~= "leaving" then
    local side = (fig.p >= r.z) and 1 or -1
    local px = dx + dw / 2 + side * clamp(gap / 6, 0, 1) * dw * 0.6
    lg.setColor(0, 0, 0, 0.9)
    lg.rectangle("fill", clamp(px - 40, dx, dx + dw - 30), dy + dh, 30, 7)
    lg.rectangle("fill", clamp(px + 10, dx, dx + dw - 30), dy + dh, 30, 7)
  end
  if status == "outside" then
    -- it is right there: a head in the slot, two eyes, and the handle moves
    lg.setScissor(sx, sy, sw, sh)
    lg.setColor(0.01, 0.01, 0.012)
    if fig.kind == "B" then
      lg.ellipse("fill", sx + sw / 2, sy + sh + 10, 70, 60)
      lg.setColor(1, 0.75, 0.25, 0.7 + 0.3 * love.math.noise(t * 3))
      lg.circle("fill", sx + sw / 2 - 20, sy + sh - 26, 5)
      lg.circle("fill", sx + sw / 2 + 20, sy + sh - 24, 5)
    else
      lg.push()
      lg.translate(sx + sw / 2 + math.sin(t * 0.8) * 6, sy + 90)
      lg.rotate(0.4)
      lg.ellipse("fill", 0, 0, 52, 70)
      lg.rectangle("fill", -70, 60, 140, 140)
      lg.setColor(0.95, 1, 0.9, 0.7 + 0.3 * love.math.noise(t * 2))
      lg.circle("fill", -18, -10, 5)
      lg.circle("fill", 18, -10, 5)
      lg.pop()
    end
    lg.setScissor()
  end
  -- handle
  lg.push()
  lg.translate(dx + dw - 46, dy + 330)
  lg.rotate(status == "outside" and math.sin(t * 17) * 0.25 * (0.5 + 0.5 * math.sin(t * 2.3)) or 0)
  lg.setColor(0.3, 0.3, 0.28)
  lg.rectangle("fill", -6, -6, 44, 12, 5)
  lg.circle("fill", 0, 0, 10)
  lg.pop()
end

-- what you can tell from behind the door (drawn with the HUD, so it stays readable)
local function hideText(g)
  local status = hideStatus(g)
  local text = ({
    quiet = "Quiet out there.",
    coming = "Something is coming down the corridor.",
    outside = "It is right outside the door. Don't move. No light.",
    leaving = "Steps, moving away.",
  })[status]
  lg.setFont(R.fonts.body)
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", 320, 604, 640, 44, 8)
  lg.setColor(status == "outside" and { 1, 0.5, 0.4 } or { 0.9, 0.9, 0.85 })
  lg.printf(text, 320, 614, 640, "center")
end

---------------------------------------------------------------------------------------
-- HUD: a clipboard, the ward plan, pockets, one line of text
---------------------------------------------------------------------------------------
local function tick(x, y)
  lg.setColor(0.1, 0.4, 0.7)
  lg.setLineWidth(3)
  lg.line(x + 2, y + 8, x + 7, y + 14, x + 18, y - 3)
  lg.setColor(0.15, 0.15, 0.18)
end

local function clipboard(g)
  local f = R.fonts
  lg.setColor(0.36, 0.26, 0.16, 0.92)
  lg.rectangle("fill", 24, 534, 250, 162, 6)
  lg.setColor(0.9, 0.88, 0.8, 0.95)
  lg.rectangle("fill", 34, 550, 230, 138, 3)
  lg.setColor(0.5, 0.5, 0.52)
  lg.rectangle("fill", 122, 528, 54, 16, 4)
  lg.setFont(f.small)
  lg.setColor(0.15, 0.15, 0.18)
  lg.print("NIGHT ROUND  -  WARD C", 44, 556)
  for i, r in ipairs(g.rooms) do
    local x, y = 46 + ((i - 1) % 3) * 74, 580 + math.floor((i - 1) / 3) * 26
    lg.setLineWidth(1.5)
    lg.rectangle("line", x, y, 16, 16)
    lg.print("Bed " .. r.bed, x + 21, y)
    if r.checked then tick(x, y) end
  end
  -- what the patients asked for
  local y = 636
  for _, r in ipairs(g.rooms) do
    if r.request and r.request ~= "none" then
      lg.setLineWidth(1.5)
      lg.rectangle("line", 46, y, 16, 16)
      local label = ({ asked = "fetch %s for Bed %d", carried = "take the %s to Bed %d", done = "%s for Bed %d" })[r.request]
      lg.print(label:format(r.asks, r.bed), 67, y)
      if r.request == "done" then tick(46, y) end
      y = y + 24
    end
  end
end

local function pockets(g)
  local f = R.fonts
  local bx, by = 1090, 656
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", bx - 14, by - 62, 190, 100, 8)
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
  -- what you are carrying
  local x = bx
  local function item(have, label, col)
    lg.setColor(col[1], col[2], col[3], have and 1 or 0.18)
    lg.rectangle("fill", x, by - 54, 12, 20, 3)
    lg.setColor(1, 1, 1, have and 0.85 or 0.25)
    lg.print(label, x + 16, by - 52)
    x = x + 22 + f.small:getWidth(label)
  end
  item(g.items.key, "key", { 0.95, 0.8, 0.3 })
  item(g.items.water, "water", { 0.4, 0.65, 0.95 })
  item(g.items.blanket, "blanket", { 0.8, 0.55, 0.6 })
end

-- The ward plan, top right. They are only drawn where you last SAW them.
local function plan(g)
  local f = R.fonts
  local ox, oy, sc = 930, 46, 10          -- station at ox, EXIT at ox + 300
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", ox - 22, oy - 34, 352, 176, 8)
  lg.setColor(1, 1, 1, 0.16)
  lg.rectangle("fill", ox, oy - 6, G.LEN * sc, 12)
  lg.rectangle("fill", ox + G.J * sc - 6, oy + 6, 12, G.ANNEX * sc)
  -- dead lamps make dark stretches
  for _, l in ipairs(g.lamps.main) do
    if l.dead then
      lg.setColor(0, 0, 0, 0.55)
      lg.rectangle("fill", ox + (l.z - 1.5) * sc, oy - 6, 3 * sc, 12)
    end
  end
  lg.setFont(f.tiny)
  lg.setColor(1, 1, 1, 0.55)
  lg.print("STATION", ox - 14, oy - 28)
  lg.printf("EXIT", ox + G.LEN * sc - 40, oy - 28, 54, "right")
  lg.print("SUPPLIES", ox + G.J * sc + 12, oy + G.ANNEX * sc - 8)
  for _, r in ipairs(g.rooms) do
    local x, y = ox + r.z * sc, oy + ((r.side < 0) and -18 or 8)
    if not r.checked then lg.setColor(1, 0.7, 0.15, 0.9)
    elseif r.request == "asked" or r.request == "carried" then lg.setColor(0.3, 0.6, 1, 0.9)
    elseif not r.lockUsed then lg.setColor(0.2, 0.8, 0.35, 0.8)
    else lg.setColor(1, 1, 1, 0.2) end
    lg.rectangle("fill", x - 6, y, 12, 10, 2)
    lg.setColor(0, 0, 0, 0.8)
    lg.print(tostring(r.bed), x - 3, y - 2)
  end
  local function at(seg, p)
    if seg == "main" then return ox + p * sc, oy end
    return ox + G.J * sc, oy + 6 + p * sc
  end
  -- them: where you last saw each one (fading as the sighting gets old)
  for i, fig in ipairs(g.figs) do
    if fig.active then
      if g.mode == "play" and g:sees(fig) and g:lightAt(fig.seg, fig.p) > 0.12 then
        R.lastSeen[i] = { seg = fig.seg, p = fig.p, t = g.t }
      end
      local m = R.lastSeen[i]
      if m and g.t >= m.t then
        local age = g.t - m.t
        local x, y = at(m.seg, m.p)
        local col = (fig.kind == "B") and { 1, 0.75, 0.25 } or { 1, 0.25, 0.2 }
        lg.setColor(col[1], col[2], col[3], clamp(1 - age / 12, 0.18, 1))
        lg.circle("fill", x, y, 5)
        if age > 0.5 then
          lg.setColor(1, 1, 1, clamp(1 - age / 12, 0.18, 0.8))
          lg.print("?", x - 3, y - 20)
        end
      else
        R.lastSeen[i] = nil
      end
    end
  end
  -- you: an arrow showing which way you face
  local x, y = at(g.seg, g.z)
  lg.setColor(1, 1, 1)
  if g.hide then
    lg.circle("line", x, y + ((g.hide.room.side < 0) and -13 or 13), 5)
  elseif g.seg == "main" then
    lg.polygon("fill", x + g.dir * 9, y, x - g.dir * 5, y - 6, x - g.dir * 5, y + 6)
  else
    lg.polygon("fill", x, y + g.dir * 9, x - 6, y - g.dir * 5, x + 6, y - g.dir * 5)
  end
end

local function hud(g)
  local f = R.fonts
  clipboard(g)
  pockets(g)
  plan(g)
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.6)
  lg.print(g:objective(), 28, 24)
  if g.msgT > 0 and g.msg and not g.hide then
    lg.setFont(f.body)
    local a = clamp(g.msgT, 0, 1)
    local _, lines = f.body:getWrap(g.msg, 716)
    local h = #lines * f.body:getHeight() + 16
    lg.setColor(0, 0, 0, 0.55 * a)
    lg.rectangle("fill", 290, 656 - h, 740, h, 8)
    lg.setColor(0.95, 0.93, 0.85, a)
    lg.printf(g.msg, 302, 664 - h, 716, "center")
  end
  if g.hide then hideText(g) end
  local pr = g:prompt()
  if pr then
    lg.setFont(f.body)
    local w = f.body:getWidth(pr) + 36
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 640 - w / 2, 500, w, 40, 20)
    lg.setColor(1, 0.8, 0.3)
    lg.printf(pr, 640 - w / 2, 508, w, "center")
  end
end

---------------------------------------------------------------------------------------
-- screens
---------------------------------------------------------------------------------------
function R.draw(g)
  R.fx(function()
    if g.hide then
      hideView(g)
    elseif g.busy and (g.busy.kind == "check" or g.busy.kind == "deliver") then
      room(g)
    else
      corridor(g)
      if g.busy and g.busy.kind == "rummage" then progress(g, "searching the shelves ...   (your back is to the corridor)") end
      if g.busy and g.busy.kind == "unlock" then progress(g, "working the padlock ...   (your back is to the corridor)") end
    end
    if g.fade then
      lg.setColor(0, 0, 0, clamp(g.fade / 0.35, 0, 1))
      lg.rectangle("fill", 0, 0, 1280, 720)
    end
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
    local amber = g.by and g.by.kind == "B"
    lg.setColor(0, 0, 0)
    lg.rectangle("fill", 0, 0, 1280, 720)
    if amber then lg.setColor(1, 0.75, 0.25, 0.5 + 0.3 * love.math.noise(g.t * 2))
    else lg.setColor(0.95, 1, 0.9, 0.5 + 0.3 * love.math.noise(g.t * 2)) end
    lg.circle("fill", 610, 300, 5)
    lg.circle("fill", 670, 306, 5)
    lg.setFont(f.big)
    lg.setColor(0.75, 0.1, 0.08)
    lg.printf("They only walk in the dark.", 0, 400, 1280, "center")
    lg.setFont(f.body)
    lg.setColor(1, 1, 1, 0.7)
    lg.printf(("Beds checked: %d / %d      R  try again      Esc  title"):format(g.checked, #g.rooms), 0, 490, 1280, "center")
  elseif g.mode == "won" then
    lg.setColor(0.02, 0.03, 0.04, 0.9)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setFont(f.big)
    lg.setColor(0.9, 0.9, 0.82)
    local left = #g.rooms - g.checked
    if g.ending == "exit" then
      lg.printf("The chain falls. Cold air.", 0, 236, 1280, "center")
    else
      lg.printf("06:00  -  shift over", 0, 236, 1280, "center")
    end
    lg.setFont(f.body)
    lg.setColor(1, 1, 1, 0.75)
    local how = (g.ending == "exit") and "You left by the fire exit" or "You clocked out"
    lg.printf(("%s after %d seconds, with %d%% battery left.\nBlackouts: %d      Torch recoils: %d      Times you hid: %d"):format(
      how, math.floor(g.time or 0), math.floor(g.battery * 100 + 0.5), g.stats.blackouts, g.stats.repels, g.stats.hides), 0, 330, 1280, "center")
    lg.setColor(1, 1, 1, 0.5)
    local last
    if g.ending == "exit" and not g:roundDone() then
      last = (left > 0) and ("%d bed%s never got checked. Nobody blames you."):format(left, left == 1 and "" or "s") or "Someone on the ward is still waiting for what they asked for."
    elseif g.ending == "exit" then
      last = "Round done, and you still didn't want to walk back past it."
    else
      last = "Bed 5 is still empty."
    end
    lg.printf(last, 0, 410, 1280, "center")
    lg.printf("R  another shift      Esc  title", 0, 500, 1280, "center")
  end
end

-- Title: the corridor itself, with nobody walking it.
function R.title(g, blink)
  R.fx(function() corridor(g) end)
  local f = R.fonts
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", 0, 110, 1280, 290)
  lg.setFont(f.title)
  lg.setColor(0.86, 0.9, 0.82)
  lg.printf("WARD C", 0, 118, 1280, "center")
  lg.setFont(f.body)
  lg.setColor(0.86, 0.9, 0.82, 0.8)
  lg.printf("night shift", 0, 222, 1280, "center")
  lg.setColor(1, 1, 1, 0.75)
  lg.printf("W / S  walk / back away        Q  turn around        Space (hold)  torch        E  use what is in front of you", 0, 272, 1280, "center")
  lg.printf("Check six beds, fetch what the patients ask for, clock out. Or find the key and leave.", 0, 306, 1280, "center")
  lg.setColor(0.95, 0.75, 0.6, 0.9)
  lg.printf("They only move in the dark. Blackouts count. So does not looking: a room, a shelf, your own back.", 0, 348, 1280, "center")
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.5 + 0.35 * math.sin(blink * 3))
  lg.printf("press any key to start your round", 0, 660, 1280, "center")
end

return R
