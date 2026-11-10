-- ADVENTURE, scene 2: the moment of discovery.
--
-- A lost temple in a jungle clearing. The picture is built like a theatre set: hazy
-- canopy layers at the back, a waterfall and a stepped temple in the middle, and big
-- dark leaves in the foreground that frame the view. Everything organic is generated:
-- canopies are clumps of circles along a noise ridge, palm fronds are a curved spine
-- with leaflets, vines are hanging Bezier curves that sway. The temple's stone courses
-- come from two nested loops and a hash for the missing/mossy blocks.

local gfx = require("core.gfx")
local flux = require("flux")
local Timer = require("hump.timer")

local lg = love.graphics

local S = {
  title = "Adventure",
  subtitle = "The Sunken Temple",
  blurb = "A lost temple in a jungle clearing: layered canopy, waterfall, light shafts, swaying vines and a 'location discovered' banner.",
  techniques = {
    "Theatre-set depth: hazy back layers, lit middle, near-black framing leaves",
    "Canopy = circles clumped along a noise ridge; palm fronds = a spine plus leaflets",
    "Temple masonry from loops; a hash decides which blocks are mossy or cracked",
    "Waterfall: scrolling noise streaks, a mist of soft particles, ripple ellipses",
    "Light shafts: additive gradient quads that slowly breathe",
    "Discovery banner eased in and out with tweens",
  },
  libs = {
    "flux: the 'location discovered' banner and relic pop-in",
    "hump.timer: sends the macaws across and replays the banner",
  },
  genres = { "Exploration and treasure-hunting games", "Puzzle-adventure temples", "Platformers with set-piece backdrops", "Metroidvania area intros" },
  controls = "click: replay the discovery banner.",
  warmup = 3.4,
}

local HAZE = gfx.rgb("#cfeecb")

-- A lens-shaped leaf from (0,0) pointing along +x.
local function leaf(len, wid, color, vein)
  local pts = {}
  for i = 0, 10 do
    local u = i / 10
    pts[#pts + 1] = u * len
    pts[#pts + 1] = -math.sin(u * math.pi) ^ 0.8 * wid
  end
  for i = 9, 1, -1 do
    local u = i / 10
    pts[#pts + 1] = u * len
    pts[#pts + 1] = math.sin(u * math.pi) ^ 0.8 * wid
  end
  lg.setColor(color)
  lg.polygon("fill", pts)
  if vein then
    lg.setColor(vein)
    lg.setLineWidth(2)
    lg.line(0, 0, len, 0)
    for i = 1, 6 do
      local u = i / 7
      local w = math.sin(u * math.pi) ^ 0.8 * wid * 0.8
      lg.line(u * len, 0, u * len + len * 0.1, -w)
      lg.line(u * len, 0, u * len + len * 0.1, w)
    end
  end
end

-- A palm frond: a drooping spine with leaflets on both sides.
local function frond(x, y, angle, len, color, sway)
  lg.push()
  lg.translate(x, y)
  lg.rotate(angle + sway)
  local n = 16
  for i = 1, n do
    local u = i / n
    local px, py = u * len, u * u * len * 0.35
    local l = math.sin(u * math.pi * 0.9 + 0.3) * len * 0.3
    lg.setColor(color)
    lg.polygon("fill", px, py, px + l * 0.5, py - l, px + l * 0.25, py - 2)
    lg.polygon("fill", px, py, px + l * 0.6, py + l, px + l * 0.25, py + 2)
  end
  lg.setLineWidth(4)
  lg.line(0, 0, len * 0.5, len * 0.0875, len, len * 0.35)
  lg.pop()
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  self.timer = Timer.new()
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.titleFont = lg.newFont(34)
  self.font = lg.newFont(16)
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#e9f7d2") }, { 0.4, gfx.rgb("#bfe6c0") }, { 1, gfx.rgb("#7fc0a0") },
  })
  self.shaft = lg.newMesh({
    { 0, 0, 0, 0, 1, 0.98, 0.8, 0.34 }, { 1, 0, 0, 0, 1, 0.98, 0.8, 0.34 },
    { 1, 1, 0, 0, 1, 0.98, 0.8, 0 }, { 0, 1, 0, 0, 1, 0.98, 0.8, 0 },
  }, "fan", "static")

  -- canopy layers baked once (hundreds of circles each)
  self.canopy = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.canopy)
  lg.clear(0, 0, 0, 0)
  local layers = {
    { y = 330, amp = 120, col = gfx.mix(gfx.rgb("#3f8f6a"), HAZE, 0.62), seed = 3, r = 30 },
    { y = 400, amp = 130, col = gfx.mix(gfx.rgb("#2f7f56"), HAZE, 0.36), seed = 11, r = 34 },
    { y = 470, amp = 110, col = gfx.mix(gfx.rgb("#256b45"), HAZE, 0.14), seed = 27, r = 38 },
  }
  for li, L in ipairs(layers) do
    -- a tepui mesa behind the first layer
    if li == 1 then
      lg.setColor(gfx.mix(gfx.rgb("#5f8f8a"), HAZE, 0.6))
      lg.polygon("fill", 760, 400, 800, 150, 850, 132, 1010, 138, 1060, 160, 1100, 400)
      lg.setColor(gfx.mix(gfx.rgb("#4f7f7a"), HAZE, 0.6))
      for k = 0, 6 do lg.polygon("fill", 812 + k * 40, 150, 824 + k * 40, 150, 830 + k * 40, 400, 806 + k * 40, 400) end
      lg.setColor(1, 1, 1, 0.5)
      lg.rectangle("fill", 920, 140, 5, 260)
    end
    local pts = gfx.ridge(1280, L.y, L.amp, 0.004, L.seed, 22, 4)
    lg.setColor(L.col)
    gfx.fillRidge(pts, 720)
    for i = 1, #pts, 2 do
      local x, y = pts[i], pts[i + 1]
      for k = 0, 2 do
        local h = gfx.hash(i * 7 + k + L.seed)
        lg.setColor(gfx.mix(L.col, { 1, 1, 0.7 }, h * 0.12))
        lg.circle("fill", x + (h - 0.5) * 40, y + k * 12 - 4, L.r * (0.6 + h * 0.7))
      end
    end
    -- a few emergent trees poking above the canopy
    for k = 1, 5 do
      local x = gfx.hash(k * 3 + L.seed) * 1280
      local idx = math.floor(x / 22) * 2 + 1
      local y = pts[math.min(idx + 1, #pts)] or L.y
      lg.setColor(gfx.mix(L.col, { 0.1, 0.2, 0.1 }, 0.25))
      lg.rectangle("fill", x - 3, y - 60, 6, 70)
      lg.setColor(L.col)
      lg.ellipse("fill", x, y - 70, 46, 20)
      lg.ellipse("fill", x - 18, y - 60, 26, 14)
      lg.ellipse("fill", x + 22, y - 62, 28, 14)
    end
  end
  lg.pop()

  self.mist = {}
  love.math.setRandomSeed(8)
  for i = 1, 26 do self.mist[i] = { x = 150 + love.math.random() * 180, y = 520 + love.math.random() * 40, p = love.math.random() * 6, s = 0.5 + love.math.random() } end
  self.motes = {}
  for i = 1, 46 do self.motes[i] = { x = love.math.random() * 1280, y = 100 + love.math.random() * 520, p = love.math.random() * 6, v = 6 + love.math.random() * 14 } end
  self.birds = {}
  self.banner = { a = 0, w = 0, y = -20 }
  self.relic = { s = 0 }
  self:discover()
  self.timer:every(9, function() self:discover() end)
  self.timer:every(6.5, function() self:flock() end)
  self:flock()
end

function S:discover()
  local b = self.banner
  b.a, b.w, b.y = 0, 0, -20
  self.relic.s = 0
  self.flux:to(b, 0.7, { a = 1, y = 0 }):ease("quadout")
  self.flux:to(b, 1.1, { w = 1 }):ease("quartout"):delay(0.2)
  self.flux:to(self.relic, 0.6, { s = 1 }):ease("backout"):delay(1.0)
  self.flux:to(b, 0.8, { a = 0 }):delay(6.5)
end

function S:flock()
  local y = 150 + love.math.random() * 120
  for k = 0, 1 do
    self.birds[#self.birds + 1] = { x = -60 - k * 70, y = y + k * 26, v = 150 + k * 8, p = k * 1.3, col = k == 0 and gfx.rgb("#e2442f") or gfx.rgb("#f2b632") }
  end
end

function S:mousepressed() self:discover() end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  self.timer:update(dt)
  for i = #self.birds, 1, -1 do
    local b = self.birds[i]
    b.x = b.x + b.v * dt
    if b.x > 1400 then table.remove(self.birds, i) end
  end
  for _, m in ipairs(self.motes) do
    m.y = m.y - m.v * dt * 0.5
    m.x = m.x + math.sin(self.t + m.p) * 8 * dt
    if m.y < 80 then m.y = 640 end
  end
end

-- one tier of the pyramid: stone courses with offset joints, moss along the top
function S:tier(x, y, w, h, shade, seed)
  local base = gfx.mix(gfx.rgb("#a89f84"), gfx.rgb("#5f6652"), shade)
  lg.setColor(base)
  lg.rectangle("fill", x, y, w, h)
  local rows = math.floor(h / 20)
  local bh = h / rows
  for r = 0, rows - 1 do
    local off = (r % 2) * 22
    for bx = x - off, x + w, 44 do
      local hsh = gfx.hash(bx * 0.37 + r * 13 + seed)
      local x1, x2 = math.max(x, bx), math.min(x + w, bx + 44)
      if x2 - x1 > 3 then
        if hsh > 0.8 then
          lg.setColor(gfx.mix(base, gfx.rgb("#4f8a3f"), 0.5))
          lg.rectangle("fill", x1, y + r * bh, x2 - x1, bh)
        elseif hsh < 0.22 then
          lg.setColor(gfx.mix(base, { 0.2, 0.2, 0.18 }, 0.22))
          lg.rectangle("fill", x1, y + r * bh, x2 - x1, bh)
        elseif hsh > 0.6 then
          lg.setColor(gfx.mix(base, { 1, 0.97, 0.85 }, 0.16))
          lg.rectangle("fill", x1, y + r * bh, x2 - x1, bh)
        end
        lg.setColor(0.2, 0.22, 0.16, 0.45)
        lg.rectangle("fill", x1, y + r * bh, 2, bh)
      end
    end
    lg.setColor(0.2, 0.22, 0.16, 0.45)
    lg.rectangle("fill", x, y + r * bh, w, 2)
  end
  -- sunlit top edge, shadow under the tier above, and the dark right side
  lg.setColor(1, 0.97, 0.82, 0.6)
  lg.rectangle("fill", x, y, w, 4)
  lg.setColor(0.1, 0.14, 0.1, 0.3)
  lg.rectangle("fill", x + w * 0.62, y, w * 0.38, h)
  -- moss creeping over the edge, with hanging tendrils
  for k = 0, math.floor(w / 26) do
    local hsh = gfx.hash(k * 5.1 + seed * 3)
    if hsh > 0.35 then
      local mx = x + k * 26 + hsh * 10
      lg.setColor(gfx.mix(gfx.rgb("#3f8a3a"), gfx.rgb("#7fbf4a"), hsh))
      lg.ellipse("fill", mx, y + 2, 16 + hsh * 10, 6 + hsh * 4)
      if hsh > 0.7 then
        lg.setLineWidth(2.5)
        lg.line(mx, y + 4, mx + math.sin(self.t * 1.2 + k) * 2, y + 12 + hsh * 26)
      end
    end
  end
end

function S:drawTemple()
  local t = self.t
  local cx, base = 800, 580
  local tiers = { { 520, 78 }, { 420, 70 }, { 320, 64 }, { 224, 58 } }
  local y = base
  for i, tr in ipairs(tiers) do
    y = y - tr[2]
    self:tier(cx - tr[1] / 2, y, tr[1], tr[2], (i - 1) * 0.08, i * 17)
  end
  -- the shrine on top, with a doorway and a carved face over it
  local sy = y - 96
  self:tier(cx - 76, sy, 152, 96, 0.3, 91)
  lg.setColor(gfx.hex("#8f8770"))
  lg.polygon("fill", cx - 92, sy, cx + 92, sy, cx + 70, sy - 20, cx - 70, sy - 20)
  lg.polygon("fill", cx - 56, sy - 20, cx + 56, sy - 20, cx + 40, sy - 38, cx - 40, sy - 38)
  lg.setColor(gfx.hex("#1a1410"))
  lg.polygon("fill", cx - 24, sy + 96, cx - 20, sy + 40, cx + 20, sy + 40, cx + 24, sy + 96)
  lg.setBlendMode("add")
  lg.setColor(1, 0.7, 0.25, 0.55 + 0.15 * math.sin(t * 2))
  lg.draw(self.glow, cx, sy + 80, 0, 0.5, 0.6, 64, 64)
  lg.setBlendMode("alpha")
  -- carved face: brow, eyes that glow, a stepped mouth
  lg.setColor(gfx.hex("#6f6a56"))
  lg.rectangle("fill", cx - 34, sy + 6, 68, 28)
  lg.setColor(gfx.hex("#4a4638"))
  lg.rectangle("fill", cx - 30, sy + 10, 24, 6)
  lg.rectangle("fill", cx + 6, sy + 10, 24, 6)
  lg.rectangle("fill", cx - 12, sy + 26, 24, 5)
  lg.setColor(0.4, 1, 0.8, 0.75 + 0.25 * math.sin(t * 1.5))
  lg.rectangle("fill", cx - 24, sy + 17, 12, 5)
  lg.rectangle("fill", cx + 12, sy + 17, 12, 5)
  -- the grand staircase
  local top = y + 0
  lg.setColor(gfx.hex("#b8b093"))
  lg.polygon("fill", cx - 34, top, cx + 34, top, cx + 66, base, cx - 66, base)
  local steps = 22
  for i = 0, steps do
    local u = i / steps
    local yy = gfx.lerp(top, base, u)
    local hw = gfx.lerp(34, 66, u)
    lg.setColor(0.25, 0.26, 0.2, 0.55)
    lg.rectangle("fill", cx - hw, yy, hw * 2, 2)
  end
  lg.setColor(gfx.hex("#8a8370"))
  lg.polygon("fill", cx - 34, top, cx - 46, top, cx - 82, base, cx - 66, base)
  lg.polygon("fill", cx + 34, top, cx + 46, top, cx + 82, base, cx + 66, base)
  -- guardian statues at the foot of the stairs, and a toppled pillar
  for _, side in ipairs({ -1, 1 }) do
    local gx = cx + side * 124
    lg.setColor(gfx.hex("#7a7562"))
    lg.rectangle("fill", gx - 24, base - 30, 48, 30)
    lg.setColor(gfx.hex("#948c74"))
    lg.polygon("fill", gx - 18, base - 30, gx + 18, base - 30, gx + 14, base - 92, gx - 14, base - 92)
    lg.rectangle("fill", gx - 20, base - 112, 40, 22, 4)
    lg.setColor(gfx.hex("#4a4638"))
    lg.rectangle("fill", gx - 12, base - 104, 8, 5)
    lg.rectangle("fill", gx + 4, base - 104, 8, 5)
    lg.rectangle("fill", gx - 8, base - 70, 16, 4)
    lg.setColor(gfx.hex("#4f8a3f"))
    lg.ellipse("fill", gx - side * 8, base - 112, 18, 6)
  end
  lg.push()
  lg.translate(1090, base - 14)
  lg.rotate(-0.12)
  lg.setColor(gfx.hex("#9a927a"))
  lg.rectangle("fill", -70, -16, 140, 32, 5)
  lg.setColor(0.25, 0.26, 0.2, 0.5)
  for k = -2, 2 do lg.rectangle("fill", k * 26, -16, 2, 32) end
  lg.setColor(gfx.hex("#4f8a3f"))
  lg.ellipse("fill", 10, -16, 34, 7)
  lg.pop()
end

function S:drawWaterfall()
  local t = self.t
  -- the cliff
  lg.setColor(gfx.hex("#5d6a5c"))
  lg.polygon("fill", 0, 200, 150, 196, 330, 214, 372, 250, 392, 580, 0, 580)
  lg.setColor(gfx.hex("#4c574c"))
  for k = 0, 7 do
    local y = 250 + k * 44
    lg.polygon("fill", 0, y, 120 + gfx.hash(k) * 60, y + 6, 372 + k * 2, y + 14 + gfx.hash(k + 3) * 10, 372 + k * 2, y + 24, 0, y + 18)
  end
  lg.setColor(gfx.hex("#6f7d6a"))
  lg.polygon("fill", 0, 200, 150, 196, 330, 214, 372, 250, 300, 236, 140, 222, 0, 228)
  -- the falling water: bright streaks scrolling down
  lg.setColor(gfx.hex("#bfe9ee"))
  lg.rectangle("fill", 170, 222, 120, 340)
  for k = 0, 23 do
    local x = 170 + k * 5
    for j = 0, 5 do
      local y = 222 + ((t * (260 + gfx.hash(k) * 120) + j * 70 + gfx.hash(k * 3) * 300) % 340)
      local l = 30 + gfx.hash(k + j) * 50
      lg.setColor(1, 1, 1, 0.55)
      lg.rectangle("fill", x, y, 3, math.min(l, 562 - y))
    end
  end
  lg.setColor(1, 1, 1, 0.8)
  lg.ellipse("fill", 230, 224, 64, 7)
  -- the pool with ripples
  lg.setColor(gfx.hex("#4fa7a2"))
  lg.ellipse("fill", 250, 590, 300, 40)
  lg.setColor(gfx.hex("#7fd0c6"))
  lg.ellipse("fill", 240, 584, 230, 26)
  for k = 0, 3 do
    local r = ((t * 0.35 + k / 4) % 1)
    lg.setColor(1, 1, 1, 0.5 * (1 - r))
    lg.setLineWidth(2)
    lg.ellipse("line", 230, 580, 60 + r * 170, 8 + r * 22)
  end
  -- mist where the water lands
  for _, m in ipairs(self.mist) do
    local a = 0.22 + 0.12 * math.sin(t * 1.4 + m.p)
    lg.setColor(1, 1, 1, a)
    lg.draw(self.soft, m.x + math.sin(t * 0.7 + m.p) * 14, m.y - ((t * 14 + m.p * 20) % 50), 0, m.s, m.s * 0.7, 64, 64)
  end
  -- rocks in the pool
  lg.setColor(gfx.hex("#55604f"))
  lg.ellipse("fill", 420, 594, 46, 20)
  lg.ellipse("fill", 96, 600, 60, 24)
  lg.setColor(gfx.hex("#6f8a4a"))
  lg.ellipse("fill", 414, 582, 34, 9)
  lg.ellipse("fill", 92, 586, 44, 10)
end

function S:drawExplorer(x, y)
  local t = self.t
  local bob = math.sin(t * 2) * 1.5
  lg.push()
  lg.translate(x, y + bob)
  -- backpack with a bedroll
  lg.setColor(gfx.hex("#7a4a2a"))
  lg.rectangle("fill", -24, -72, 20, 36, 5)
  lg.setColor(gfx.hex("#c9b27a"))
  lg.rectangle("fill", -26, -82, 24, 11, 5)
  -- legs, boots
  lg.setColor(gfx.hex("#5a4a3a"))
  lg.rectangle("fill", -10, -32, 9, 28)
  lg.rectangle("fill", 2, -32, 9, 28)
  lg.setColor(gfx.hex("#2f241c"))
  lg.rectangle("fill", -12, -6, 13, 8, 3)
  lg.rectangle("fill", 1, -6, 14, 8, 3)
  -- jacket, belt, scarf
  lg.setColor(gfx.hex("#c98a3a"))
  lg.polygon("fill", -13, -76, 13, -76, 15, -30, -15, -30)
  lg.setColor(gfx.hex("#3a2a1e"))
  lg.rectangle("fill", -15, -40, 30, 5)
  lg.setColor(gfx.hex("#d84a3a"))
  lg.polygon("fill", -12, -78, 12, -78, 8, -68, -8, -68)
  lg.polygon("fill", -10, -74, -30 - math.sin(t * 3) * 4, -64 + math.sin(t * 4) * 3, -26, -58, -8, -68)
  -- head and a wide-brimmed hat
  lg.setColor(gfx.hex("#e0b08a"))
  lg.circle("fill", 0, -90, 12)
  lg.setColor(gfx.hex("#6a4a2a"))
  lg.ellipse("fill", 0, -98, 24, 6)
  lg.polygon("fill", -12, -98, -9, -114, 9, -114, 12, -98)
  lg.setColor(gfx.hex("#2a1e14"))
  lg.circle("fill", 5, -90, 1.6)
  -- arm raised, holding a torch
  lg.setColor(gfx.hex("#c98a3a"))
  lg.polygon("fill", 8, -74, 16, -72, 34, -96, 28, -102)
  lg.setColor(gfx.hex("#4a3424"))
  lg.setLineWidth(5)
  lg.line(30, -94, 38, -126)
  local f = love.math.noise(t * 6) * 6
  lg.setColor(1, 0.55, 0.15)
  lg.polygon("fill", 30, -126, 46, -126, 38 + math.sin(t * 9) * 3, -152 - f)
  lg.setColor(1, 0.9, 0.4)
  lg.polygon("fill", 34, -126, 43, -126, 38 + math.sin(t * 11) * 2, -140 - f * 0.5)
  lg.setBlendMode("add")
  lg.setColor(1, 0.7, 0.3, 0.5)
  lg.draw(self.glow, 38, -134, 0, 1.3, 1.3, 64, 64)
  lg.setBlendMode("alpha")
  lg.pop()
end

function S:drawForeground()
  local t = self.t
  local dark = gfx.rgb("#0f2a1c")
  local dark2 = gfx.rgb("#17402a")
  -- hanging vines with little leaves
  for k = 0, 8 do
    local x = 60 + k * 150 + gfx.hash(k) * 60
    local len = 120 + gfx.hash(k + 5) * 240
    local sway = math.sin(t * 0.8 + k * 1.7) * 18
    local curve = love.math.newBezierCurve(x, 0, x + sway * 0.3, len * 0.5, x + sway, len)
    lg.setColor(dark)
    lg.setLineWidth(4)
    lg.line(curve:render(3))
    for i = 1, 7 do
      local px, py = curve:evaluate(i / 7)
      lg.push()
      lg.translate(px, py)
      lg.rotate((i % 2 == 0 and 0.5 or math.pi - 0.5) + sway * 0.01)
      leaf(22, 7, i % 3 == 0 and dark2 or dark)
      lg.pop()
    end
  end
  -- big framing leaves in the corners
  local function bigLeaf(x, y, a, len, wid, phase)
    lg.push()
    lg.translate(x, y)
    lg.rotate(a + math.sin(t * 0.9 + phase) * 0.04)
    leaf(len, wid, dark, dark2)
    lg.pop()
  end
  bigLeaf(-30, 720, -0.9, 330, 70, 0)
  bigLeaf(-40, 640, -0.35, 300, 60, 1)
  bigLeaf(40, 740, -1.35, 280, 60, 2)
  bigLeaf(1310, 720, -2.25, 340, 72, 3)
  bigLeaf(1320, 620, -2.85, 280, 56, 4)
  bigLeaf(1230, 750, -1.8, 290, 62, 5)
  frond(-10, 120, 0.35, 330, dark, math.sin(t * 0.7) * 0.04)
  frond(-10, 60, 0.05, 380, dark2, math.sin(t * 0.8 + 1) * 0.04)
  frond(1290, 90, math.pi - 0.3, 340, dark, math.sin(t * 0.75 + 2) * 0.04)
  frond(1290, 30, math.pi - 0.02, 300, dark2, math.sin(t * 0.6 + 3) * 0.04)
end

function S:drawHud()
  local b = self.banner
  if b.a > 0.01 then
    lg.setFont(self.titleFont)
    gfx.outlinedText("The Sunken Temple", 0, 96 + b.y, { 1, 0.95, 0.78, b.a }, { 0.08, 0.14, 0.1, b.a * 0.9 }, 2, 1280, "center")
    lg.setColor(1, 0.95, 0.78, b.a)
    lg.rectangle("fill", 640 - 230 * b.w, 142 + b.y, 460 * b.w, 2)
    lg.polygon("fill", 640, 136 + b.y, 648, 143 + b.y, 640, 150 + b.y, 632, 143 + b.y)
    lg.setFont(self.font)
    gfx.outlinedText("- LOCATION DISCOVERED -", 0, 156 + b.y, { 0.85, 0.95, 0.8, b.a * b.w }, { 0.08, 0.14, 0.1, b.a * 0.8 }, 1, 1280, "center")
  end
  -- relic tracker, bottom centre: five sockets, two filled
  local s = self.relic.s
  for k = 0, 4 do
    local x = 560 + k * 40
    lg.setColor(0.06, 0.1, 0.08, 0.7)
    lg.circle("fill", x, 676, 15)
    lg.setColor(0.85, 0.8, 0.6, 0.9)
    lg.setLineWidth(2)
    lg.circle("line", x, 676, 15)
    if k < 2 or (k == 2 and s > 0) then
      local sc = (k == 2) and s or 1
      lg.setColor(k == 2 and gfx.rgb("#5fe8c0") or gfx.rgb("#f2c84a"))
      lg.polygon("fill", x, 676 - 10 * sc, x + 8 * sc, 676, x, 676 + 10 * sc, x - 8 * sc, 676)
    end
  end
end

function S:draw()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  lg.draw(self.canopy)
  -- macaws
  for _, b in ipairs(self.birds) do
    local flap = math.sin(t * 9 + b.p)
    local y = b.y + math.sin(t * 2 + b.p) * 8
    lg.setColor(b.col)
    lg.ellipse("fill", b.x, y, 13, 5)
    lg.polygon("fill", b.x - 10, y, b.x - 34, y + 3, b.x - 10, y + 4)
    lg.setColor(gfx.hex("#2f6fd0"))
    lg.polygon("fill", b.x - 6, y, b.x + 6, y, b.x - 4, y - flap * 22)
    lg.setColor(gfx.hex("#f4efe0"))
    lg.circle("fill", b.x + 12, y - 1, 4)
  end
  -- clearing floor
  lg.setColor(gfx.hex("#4f8f4a"))
  lg.rectangle("fill", 0, 570, 1280, 150)
  lg.setColor(gfx.hex("#6aa856"))
  lg.ellipse("fill", 800, 600, 520, 40)
  self:drawWaterfall()
  self:drawTemple()
  -- flagstone path from the stairs toward the camera
  for k = 0, 6 do
    local u = k / 6
    lg.setColor(gfx.mix(gfx.rgb("#b8b093"), gfx.rgb("#8a8f6a"), u * 0.5))
    lg.ellipse("fill", 800 - u * 150 + math.sin(k * 2.3) * 24, 596 + u * 74, 30 + u * 30, 8 + u * 9)
  end
  -- grass tufts and flowers
  for k = 0, 50 do
    local x = gfx.hash(k) * 1280
    local y = 590 + gfx.hash(k + 20) * 90
    if x > 480 or y > 640 then
      local sw = math.sin(t * 1.5 + k) * 3
      lg.setColor(gfx.mix(gfx.rgb("#3f7f3a"), gfx.rgb("#8fc85a"), gfx.hash(k + 40)))
      lg.polygon("fill", x - 5, y, x + 5, y, x + sw, y - 18)
      lg.polygon("fill", x + 2, y, x + 10, y, x + 10 + sw, y - 13)
      if k % 6 == 0 then
        lg.setColor(k % 12 == 0 and gfx.rgb("#ff7aa8") or gfx.rgb("#ffe066"))
        lg.circle("fill", x + sw, y - 20, 4)
      end
    end
  end
  self:drawExplorer(470, 640)
  -- shafts of light through the canopy
  lg.setBlendMode("add")
  for k = 0, 5 do
    local a = 0.5 + 0.5 * math.sin(t * 0.5 + k * 1.9)
    lg.push()
    lg.translate(330 + k * 150, -20)
    lg.shear(0.42, 0)
    lg.scale(60 + (k % 3) * 34, 640)
    lg.setColor(1, 1, 1, 0.35 + a * 0.4)
    lg.draw(self.shaft)
    lg.pop()
  end
  for _, m in ipairs(self.motes) do
    lg.setColor(1, 1, 0.75, 0.3 + 0.3 * math.sin(t * 2 + m.p))
    lg.circle("fill", m.x, m.y, 1.8)
  end
  lg.setBlendMode("alpha")
  self:drawForeground()
  self:drawHud()
end

return S
