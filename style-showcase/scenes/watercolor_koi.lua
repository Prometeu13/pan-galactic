-- WATERCOLOR, scene 3: a koi pond seen from above.
--
-- Fish are a moving-paint problem: a wash that changes shape every frame would
-- "boil" if its ragged edge were re-randomised each time. So every koi segment gets a
-- fixed seed (paint:fixed), and only the positions change. A koi is a spine: a chain
-- of points that follow the head along its path with a delay, plus a sideways wiggle
-- that grows toward the tail. Body, patches and fins are small washes hung on that
-- spine. Fish under a lily pad or deeper in the pond are simply painted earlier, so
-- the water glaze on top of them turns them blue-green.

local gfx = require("core.gfx")
local washkit = require("core.washkit")

local lg = love.graphics

local S = {
  title = "Watercolor",
  subtitle = "Koi Pond",
  blurb = "A top-down pond: koi built on wiggling spines, lily pads and lotus flowers, ripple rings and glazes of blue-green water.",
  techniques = {
    "Koi = a spine of points trailing the head, wiggling more toward the tail",
    "Live washes keep a fixed seed, so edges stay ragged without boiling",
    "Depth by glazing: deep fish are painted before a translucent water wash",
    "Lily pads: a disc with a wedge cut out, veins as thin dark strokes",
    "Lotus: rings of petal-shaped washes, pale at the tip",
    "Ripples: expanding rings of white gouache and a darker echo",
  },
  libs = {
    "vivid: pooled darker edges for every wash (through core/washkit.lua)",
  },
  genres = { "Zen / relaxation games", "Fish-keeping and garden sims", "Top-down puzzle games", "Ambient screensavers and menus" },
  controls = "click the water: ripples spread and the koi come to look.",
  warmup = 3,
}

local function c(h) return { gfx.hex(h) } end

local KOI = {
  { body = "#f4efe6", patch = "#e2562a", n = 3, size = 1.5, speed = 0.5, phase = 0.0, cx = 500, cy = 330, rx = 300, ry = 170, deep = false },
  { body = "#f0862a", patch = "#f4efe6", n = 2, size = 1.3, speed = -0.62, phase = 2.0, cx = 800, cy = 400, rx = 260, ry = 150, deep = false },
  { body = "#f4efe6", patch = "#2a2a30", n = 4, size = 1.4, speed = 0.44, phase = 4.0, cx = 660, cy = 300, rx = 380, ry = 120, deep = false },
  { body = "#e8b23a", patch = "#e2562a", n = 2, size = 1.1, speed = -0.5, phase = 1.0, cx = 380, cy = 470, rx = 200, ry = 110, deep = true },
  { body = "#d8452a", patch = "#f4efe6", n = 3, size = 1.6, speed = 0.36, phase = 3.2, cx = 880, cy = 300, rx = 230, ry = 190, deep = true },
}

local PADS = {
  { 250, 210, 62, 0.4 }, { 330, 270, 44, 2.2 }, { 1010, 180, 70, 4.0 }, { 1080, 262, 46, 1.2 }, { 960, 540, 66, 5.2 },
  { 250, 560, 54, 3.1 }, { 640, 600, 40, 0.9 }, { 720, 150, 36, 2.8 }, { 1120, 470, 40, 0.2 }, { 170, 400, 38, 4.6 },
}
local LOTUS = { { 262, 200, 1 }, { 1004, 170, 1.1 }, { 968, 548, 0.9 }, { 244, 566, 0.8 } }

function S:paintStatic()
  local paint = self.paint
  local rng = love.math.newRandomGenerator(41)
  -- the bank: warm stones and moss around the edge, pond in the middle
  paint:wash({ 40, 40, 1240, 40, 1240, 690, 40, 690 }, c("#b7a88a"), { alpha = 0.12, jitter = 12, step = 30 })
  -- pond outline: an organic blob
  local pond = {}
  for a = 0, 35 do
    local ang = a / 36 * math.pi * 2
    local r = 1 + (love.math.noise(a * 0.35, 2.2) - 0.5) * 0.22
    pond[#pond + 1] = 640 + math.cos(ang) * 540 * r
    pond[#pond + 1] = 372 + math.sin(ang) * 300 * r
  end
  self.pond = pond
  paint:wash(pond, c("#7fc4c0"), { alpha = 0.13, jitter = 10, step = 26 })
  paint:wash(pond, c("#4fa3b0"), { alpha = 0.07, jitter = 14, step = 26 })
  -- deeper water: blooms of teal and indigo toward the middle
  for i = 1, 16 do
    local x, y = rng:random(300, 980), rng:random(220, 520)
    paint:blob(x, y, 100 + rng:random() * 120, 60 + rng:random() * 70, c(i % 3 == 0 and "#2f6f9a" or "#3f8f9a"), { alpha = 0.05, jitter = 14, layers = 4, noEdge = true })
  end
  -- stones on the bank
  for i = 1, 30 do
    local ang = i / 30 * math.pi * 2 + rng:random() * 0.1
    local x = 640 + math.cos(ang) * (600 + rng:random(-10, 30))
    local y = 372 + math.sin(ang) * (336 + rng:random(-10, 24))
    if x > 60 and x < 1220 and y > 56 and y < 670 then
      local r = 20 + rng:random() * 26
      paint:blob(x, y, r, r * 0.75, c(({ "#8a8478", "#a39a88", "#6f6a66", "#b0a898" })[rng:random(1, 4)]), { alpha = 0.2, jitter = 4, layers = 4 })
      paint:blob(x - r * 0.25, y - r * 0.25, r * 0.4, r * 0.25, c("#f4efe6"), { alpha = 0.12, jitter = 2, layers = 2, noEdge = true })
    end
  end
  -- moss and reeds between the stones
  for i = 1, 26 do
    local ang = rng:random() * math.pi * 2
    local x = 640 + math.cos(ang) * 580
    local y = 372 + math.sin(ang) * 325
    if x > 60 and x < 1220 and y > 56 and y < 670 then
      paint:blob(x, y, 26 + rng:random() * 20, 14 + rng:random() * 12, c("#6a9a4a"), { alpha = 0.12, jitter = 6, layers = 3 })
    end
  end
  paint:splatter(640, 372, 40, 520, c("#3f8f9a"), rng)
end

function S:load()
  self.t = 0
  self.paint = washkit.new()
  self.grain = washkit.grain()
  self.border = washkit.border()
  self.sig = lg.newFont(16)
  self.painting = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.painting)
  lg.clear(0, 0, 0, 0)
  self:paintStatic()
  lg.pop()
  self.ripples = { { x = 520, y = 400, life = 0.6 }, { x = 860, y = 300, life = 1.6 } }
  self.attract = nil
  self.nextRipple = 2.5
  -- each koi keeps a trail of its head positions; the body is read back from it
  for _, k in ipairs(KOI) do
    k.a = k.phase
    k.trail = {}
    k.hx = k.cx + math.cos(k.a) * k.rx
    k.hy = k.cy + math.sin(k.a * 1.0) * k.ry
    for i = 1, 60 do k.trail[i] = { k.hx, k.hy } end
  end
end

function S:mousepressed(x, y)
  if gfx and x then
    self.ripples[#self.ripples + 1] = { x = x, y = y, life = 0 }
    self.attract = { x = x, y = y, t = 4 }
  end
end

function S:update(dt)
  self.t = self.t + dt
  for i = #self.ripples, 1, -1 do
    self.ripples[i].life = self.ripples[i].life + dt
    if self.ripples[i].life > 3.2 then table.remove(self.ripples, i) end
  end
  self.nextRipple = self.nextRipple - dt
  if self.nextRipple <= 0 then
    self.nextRipple = 1.6 + love.math.random() * 2
    self.ripples[#self.ripples + 1] = { x = 300 + love.math.random() * 680, y = 200 + love.math.random() * 340, life = 0 }
  end
  if self.attract then
    self.attract.t = self.attract.t - dt
    if self.attract.t <= 0 then self.attract = nil end
  end
  for _, k in ipairs(KOI) do
    k.a = k.a + k.speed * dt
    -- home path: a wobbly loop; when attracted, steer toward the click instead
    local tx = k.cx + math.cos(k.a) * k.rx + math.sin(k.a * 2.3) * 40
    local ty = k.cy + math.sin(k.a) * k.ry + math.cos(k.a * 1.7) * 30
    if self.attract then
      tx = gfx.lerp(tx, self.attract.x + math.cos(k.phase * 3) * 60, 0.8)
      ty = gfx.lerp(ty, self.attract.y + math.sin(k.phase * 3) * 60, 0.8)
    end
    k.hx = k.hx + (tx - k.hx) * math.min(1, dt * 1.6)
    k.hy = k.hy + (ty - k.hy) * math.min(1, dt * 1.6)
    local last = k.trail[1]
    local d = math.sqrt((k.hx - last[1]) ^ 2 + (k.hy - last[2]) ^ 2)
    if d > 4 then
      table.insert(k.trail, 1, { k.hx, k.hy })
      k.trail[#k.trail] = nil
    end
  end
end

-- body half-width along the fish, u = 0 (nose) .. 1 (tail root)
local function girth(u)
  return math.sin(math.min(1, u * 1.25 + 0.08) * math.pi) ^ 0.7 * 17 + 2
end

function S:drawKoi(idx, k, alphaMul)
  local paint = self.paint
  local t = self.t
  local body, patch = c(k.body), c(k.patch)
  -- spine: sample the trail every few entries; wiggle grows toward the tail
  local N = 9
  local sp = {}
  for i = 0, N do
    local e = k.trail[math.min(#k.trail, 1 + math.floor(i * 3.2 * k.size))]
    sp[i] = { e[1], e[2] }
  end
  sp[0] = { k.hx, k.hy }
  local nrm = {}
  for i = 0, N do
    local a, b = sp[math.max(0, i - 1)], sp[math.min(N, i + 1)]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then dx, dy, len = 1, 0, 1 end
    nrm[i] = { -dy / len, dx / len, dx / len, dy / len }
    local wig = math.sin(t * 5 * math.abs(k.speed) * 2 - i * 0.7 + k.phase) * (i / N) ^ 1.6 * 12 * k.size
    sp[i][1] = sp[i][1] + nrm[i][1] * wig
    sp[i][2] = sp[i][2] + nrm[i][2] * wig
  end
  local function side(i, s, extra)
    local w = girth(i / N) * k.size * (extra or 1)
    return sp[i][1] + nrm[i][1] * w * s, sp[i][2] + nrm[i][2] * w * s
  end
  paint:fixed(5000 + idx * 100, function()
    -- pectoral fins: translucent, swept back
    for _, s in ipairs({ -1, 1 }) do
      local x1, y1 = side(2, s)
      local x2, y2 = side(3, s)
      local flap = 1.9 + math.sin(t * 3 + idx) * 0.3
      local fx, fy = sp[3][1] + nrm[3][1] * girth(0.3) * k.size * flap * s + nrm[3][3] * 16 * k.size, sp[3][2] + nrm[3][2] * girth(0.3) * k.size * flap * s + nrm[3][4] * 16 * k.size
      paint:wash({ x1, y1, fx, fy, x2, y2 }, body, { alpha = 0.16 * alphaMul, jitter = 1.5, step = 8, layers = 3, convex = true })
    end
    -- tail fin: two lobes from the last spine point
    local tx, ty = sp[N][1], sp[N][2]
    local dx, dy = nrm[N][3], nrm[N][4]
    local swing = math.sin(t * 5 * math.abs(k.speed) * 2 - N * 0.7 + k.phase) * 0.5
    for _, s in ipairs({ -1, 1 }) do
      local a = math.atan2(dy, dx) + s * 0.5 + swing
      local ex, ey = tx + math.cos(a) * 34 * k.size, ty + math.sin(a) * 34 * k.size
      local mx, my = tx + math.cos(a - s * 0.5) * 16 * k.size, ty + math.sin(a - s * 0.5) * 16 * k.size
      local bx, by = side(N - 1, s)
      paint:wash({ bx, by, ex, ey, mx, my }, body, { alpha = 0.2 * alphaMul, jitter = 1.5, step = 8, layers = 3, convex = true })
    end
    -- body: one quad per spine segment (robust for any bend)
    for i = 0, N - 1 do
      local x1, y1 = side(i, -1)
      local x2, y2 = side(i, 1)
      local x3, y3 = side(i + 1, 1)
      local x4, y4 = side(i + 1, -1)
      paint:wash({ x1, y1, x2, y2, x3, y3, x4, y4 }, body, { alpha = 0.3 * alphaMul, jitter = 1.2, step = 9, layers = 3, convex = true, noEdge = true })
    end
    -- head: a rounded cap
    paint:blob(sp[0][1] - nrm[0][3] * 2, sp[0][2] - nrm[0][4] * 2, 13 * k.size, 13 * k.size, body, { alpha = 0.3 * alphaMul, jitter = 1.2, layers = 3, noEdge = true })
    -- colour patches riding on the spine
    for p = 1, k.n do
      local i = math.floor(1 + (p - 0.5) / k.n * (N - 3))
      local w = girth(i / N) * k.size
      paint:blob(sp[i][1] + nrm[i][1] * w * 0.25 * ((p % 2 == 0) and 1 or -1), sp[i][2] + nrm[i][2] * w * 0.25 * ((p % 2 == 0) and 1 or -1), w * 0.95, w * 0.8, patch, { alpha = 0.26 * alphaMul, jitter = 2, layers = 4 })
    end
  end)
  -- pooled edge down both flanks, eyes, and a dorsal line
  local left, right, mid = {}, {}, {}
  for i = 0, N do
    local x, y = side(i, -1)
    left[#left + 1] = x
    left[#left + 1] = y
    x, y = side(i, 1)
    right[#right + 1] = x
    right[#right + 1] = y
    mid[#mid + 1] = sp[i][1]
    mid[#mid + 1] = sp[i][2]
  end
  lg.setColor(0.35, 0.22, 0.16, 0.3 * alphaMul)
  lg.setLineWidth(1.4)
  lg.line(left)
  lg.line(right)
  lg.setColor(1, 1, 1, 0.25 * alphaMul)
  lg.setLineWidth(2)
  lg.line(mid)
  lg.setColor(0.1, 0.1, 0.12, 0.8 * alphaMul)
  for _, s in ipairs({ -1, 1 }) do
    lg.circle("fill", sp[0][1] + nrm[0][1] * 8 * k.size * s + nrm[0][3] * 3, sp[0][2] + nrm[0][2] * 8 * k.size * s + nrm[0][4] * 3, 2.2 * k.size)
  end
end

function S:drawPad(i, x, y, r, rot)
  local paint = self.paint
  local t = self.t
  x = x + math.sin(t * 0.5 + i) * 3
  y = y + math.cos(t * 0.4 + i * 2) * 2
  rot = rot + math.sin(t * 0.3 + i) * 0.05
  -- shadow on the water below the pad
  lg.setColor(0.1, 0.25, 0.3, 0.14)
  lg.circle("fill", x + 7, y + 9, r)
  local pts = { x, y }
  for a = 0, 22 do
    local ang = rot + 0.22 + a / 22 * (math.pi * 2 - 0.44)
    pts[#pts + 1] = x + math.cos(ang) * r
    pts[#pts + 1] = y + math.sin(ang) * r
  end
  paint:fixed(8000 + i * 10, function()
    paint:wash(pts, c(i % 3 == 0 and "#6aa84a" or "#4f9a50"), { alpha = 0.26, jitter = 2.5, step = 12, layers = 4 })
    paint:blob(x - r * 0.25, y - r * 0.25, r * 0.5, r * 0.4, c("#b8d86a"), { alpha = 0.1, jitter = 3, layers = 3, noEdge = true })
  end)
  lg.setColor(0.16, 0.36, 0.2, 0.4)
  lg.setLineWidth(1.3)
  for a = 0, 7 do
    local ang = rot + 0.5 + a / 8 * (math.pi * 2 - 0.6)
    lg.line(x, y, x + math.cos(ang) * r * 0.86, y + math.sin(ang) * r * 0.86)
  end
end

function S:drawLotus(i, x, y, s)
  local paint = self.paint
  local t = self.t
  x = x + math.sin(t * 0.5 + i) * 3
  paint:fixed(9000 + i * 40, function()
    for ring = 1, 3 do
      local n = ({ 9, 7, 5 })[ring]
      local len = ({ 46, 34, 20 })[ring] * s
      for p = 0, n - 1 do
        local a = p / n * math.pi * 2 + ring * 0.4 + math.sin(t * 0.4) * 0.03
        local tx, ty = x + math.cos(a) * len, y + math.sin(a) * len
        local nx, ny = -math.sin(a) * len * 0.3, math.cos(a) * len * 0.3
        local mx, my = x + math.cos(a) * len * 0.5, y + math.sin(a) * len * 0.5
        paint:wash({ x, y, mx + nx, my + ny, tx, ty, mx - nx, my - ny }, c(ring == 3 and "#f2a0b8" or "#f8c8d4"), { alpha = 0.26, jitter = 1.5, step = 8, layers = 3, convex = true })
      end
    end
    paint:blob(x, y, 8 * s, 8 * s, c("#f2c230"), { alpha = 0.4, jitter = 1, layers = 3 })
  end)
end

function S:draw()
  local paint = self.paint
  local t = self.t
  lg.setColor(washkit.PAPER)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.painting)
  lg.setBlendMode("alpha")
  -- deep koi first, then a glaze of water over them
  for i, k in ipairs(KOI) do
    if k.deep then self:drawKoi(i, k, 0.8) end
  end
  paint:fixed(700, function()
    paint:wash(self.pond, c("#3f8fa0"), { alpha = 0.075, jitter = 8, step = 26, layers = 3, noEdge = true })
  end)
  -- caustic light: pale wavy strokes drifting over the bottom
  for k = 0, 26 do
    local x = 220 + (k * 137) % 840
    local y = 170 + (k * 71) % 400
    local a = 0.5 + 0.5 * math.sin(t * 1.1 + k * 1.7)
    lg.setColor(1, 1, 1, 0.16 * a)
    lg.setLineWidth(3)
    lg.line(love.math.newBezierCurve(x, y, x + 20, y - 10 + math.sin(t + k) * 6, x + 44, y + 8, x + 66, y):render(3))
  end
  for i, k in ipairs(KOI) do
    if not k.deep then self:drawKoi(i, k, 1) end
  end
  -- ripples: white rings with a darker echo
  for _, r in ipairs(self.ripples) do
    for ring = 0, 2 do
      local u = r.life / 3.2 - ring * 0.12
      if u > 0 and u < 1 then
        local rad = 10 + u * 110
        lg.setColor(1, 1, 1, 0.55 * (1 - u))
        lg.setLineWidth(2.5)
        lg.ellipse("line", r.x, r.y, rad, rad * 0.92)
        lg.setColor(0.15, 0.4, 0.5, 0.2 * (1 - u))
        lg.setLineWidth(1.5)
        lg.ellipse("line", r.x + 2, r.y + 3, rad, rad * 0.92)
      end
    end
  end
  for i, p in ipairs(PADS) do self:drawPad(i, p[1], p[2], p[3], p[4]) end
  for i, l in ipairs(LOTUS) do self:drawLotus(i, l[1], l[2], l[3]) end
  -- a dragonfly skimming around
  local dx, dy = 640 + math.sin(t * 0.7) * 380, 330 + math.sin(t * 1.1 + 1) * 200
  local da = math.atan2(math.cos(t * 1.1 + 1) * 220, math.cos(t * 0.7) * 266)
  lg.push()
  lg.translate(dx, dy)
  lg.rotate(da)
  lg.setColor(0.1, 0.25, 0.3, 0.12)
  lg.ellipse("fill", 6, 14, 24, 5)
  lg.setColor(0.75, 0.9, 1, 0.5)
  local flap = 0.7 + 0.3 * math.sin(t * 40)
  lg.ellipse("fill", 4, -11 * flap, 5, 13)
  lg.ellipse("fill", 4, 11 * flap, 5, 13)
  lg.ellipse("fill", -4, -9 * flap, 4, 10)
  lg.ellipse("fill", -4, 9 * flap, 4, 10)
  lg.setColor(0.15, 0.45, 0.6, 0.9)
  lg.setLineWidth(3)
  lg.line(-24, 0, 10, 0)
  lg.circle("fill", 12, 0, 3.5)
  lg.pop()
  -- petals floating on the surface
  for k = 0, 11 do
    local x = 200 + (k * 173 + t * 6) % 880
    local y = 160 + (k * 97) % 420 + math.sin(t * 0.6 + k) * 6
    lg.setColor(0.97, 0.76, 0.82, 0.75)
    lg.push()
    lg.translate(x, y)
    lg.rotate(k + t * 0.1)
    lg.ellipse("fill", 0, 0, 7, 4)
    lg.pop()
  end
  washkit.finish(self.grain, self.border, "koi pond  -  love2d", self.sig)
end

return S
