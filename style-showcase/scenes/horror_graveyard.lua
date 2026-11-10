-- HORROR, scene 3: a graveyard under a full moon.
--
-- Gothic horror is silhouette work: a big pale light at the back (the moon) and black
-- shapes in front of it. The dead tree is a recursive function: a branch draws itself,
-- then calls itself twice with a shorter length and a bent angle. Tombstones are a few
-- shape recipes (round top, cross, obelisk) leaned at random angles. Fog is layers of
-- soft blobs sliding at different speeds, drawn between the rows of stones so that it
-- hides their bases. Lightning replaces the palette for a few frames.

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local shack = require("shack")

local lg = love.graphics

local S = {
  title = "Horror",
  subtitle = "Hollow Hill Cemetery",
  blurb = "Gothic silhouettes against a huge moon: a recursive dead tree, leaning tombstones, drifting fog, crows, wisps and lightning.",
  techniques = {
    "Recursive tree: each branch draws itself, then two shorter, bent copies",
    "Tombstone recipes (round, cross, obelisk, angel) leaned by a hash",
    "Fog layers between the rows of stones hide their bases (depth for free)",
    "Moon: disc + craters + additive halo; clouds slide across it",
    "Will-o'-wisps: additive glows on wandering sine paths, lighting nearby stones",
    "Lightning: a jagged recursive bolt, a white flash and a screen shake",
  },
  libs = {
    "moonshine: film grain and a heavy vignette",
    "shack: thunder shake",
  },
  genres = { "Gothic action-platformers", "Halloween / spooky-cute games", "Tower defence at night", "Title screens and game-over screens" },
  controls = "click: call down lightning.",
  warmup = 3,
}

local INK = { 0.02, 0.03, 0.045 }

-- recursive dead tree, baked into a list of line segments
local function grow(segs, x, y, angle, len, width, depth, seed)
  if depth == 0 or len < 6 then return end
  local bend = (gfx.hash(seed) - 0.5) * 0.5
  local x2 = x + math.cos(angle + bend) * len
  local y2 = y + math.sin(angle + bend) * len
  segs[#segs + 1] = { x, y, x2, y2, width }
  local spread = 0.38 + gfx.hash(seed + 1) * 0.42
  grow(segs, x2, y2, angle + bend - spread, len * (0.66 + gfx.hash(seed + 2) * 0.14), width * 0.66, depth - 1, seed * 2 + 1)
  grow(segs, x2, y2, angle + bend + spread * 0.8, len * (0.6 + gfx.hash(seed + 3) * 0.18), width * 0.62, depth - 1, seed * 2 + 2)
  if depth > 4 and gfx.hash(seed + 4) > 0.5 then
    grow(segs, x2, y2, angle + bend + (gfx.hash(seed + 5) - 0.5) * 0.3, len * 0.8, width * 0.7, depth - 2, seed * 3 + 7)
  end
end

local function stone(kind, w, h)
  if kind == 1 then          -- round-topped slab
    lg.rectangle("fill", -w / 2, -h + w / 2, w, h - w / 2)
    lg.circle("fill", 0, -h + w / 2, w / 2)
  elseif kind == 2 then      -- cross on a plinth
    lg.rectangle("fill", -w * 0.16, -h, w * 0.32, h)
    lg.rectangle("fill", -w / 2, -h * 0.74, w, w * 0.3)
    lg.rectangle("fill", -w * 0.36, -h * 0.16, w * 0.72, h * 0.16)
  elseif kind == 3 then      -- obelisk
    lg.polygon("fill", -w * 0.3, 0, w * 0.3, 0, w * 0.18, -h * 0.86, 0, -h, -w * 0.18, -h * 0.86)
    lg.rectangle("fill", -w * 0.42, -h * 0.1, w * 0.84, h * 0.1)
  elseif kind == 4 then      -- pointed gothic slab
    lg.polygon("fill", -w / 2, 0, w / 2, 0, w / 2, -h * 0.72, 0, -h, -w / 2, -h * 0.72)
  else                       -- celtic cross: a cross with a ring
    lg.rectangle("fill", -w * 0.14, -h, w * 0.28, h)
    lg.rectangle("fill", -w * 0.46, -h * 0.76, w * 0.92, w * 0.26)
    lg.setLineWidth(w * 0.12)
    lg.circle("line", 0, -h * 0.76 + w * 0.13, w * 0.34)
    lg.rectangle("fill", -w * 0.3, -h * 0.1, w * 0.6, h * 0.1)
  end
end

function S:load()
  self.t = 0
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.1)
  self.font = lg.newFont(11)
  self.fx = moonshine(1280, 720, moonshine.effects.filmgrain).chain(moonshine.effects.vignette)
  self.fx.filmgrain.opacity = 0.35
  self.fx.filmgrain.size = 2
  self.fx.vignette.radius = 0.85
  self.fx.vignette.softness = 0.6
  self.fx.vignette.opacity = 0.7
  shack:setDimensions(1280, 720)
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#070b16") }, { 0.45, gfx.rgb("#142235") }, { 0.75, gfx.rgb("#27405a") }, { 1, gfx.rgb("#35546a") },
  })
  self.tree = {}
  grow(self.tree, 300, 560, -math.pi / 2 + 0.08, 120, 30, 9, 5)
  self.tree2 = {}
  grow(self.tree2, 1180, 520, -math.pi / 2 - 0.2, 70, 14, 7, 31)

  love.math.setRandomSeed(13)
  -- three rows of stones: far (small, pale), middle, near (big, black)
  self.rows = {}
  local rowDefs = {
    { y = 500, n = 13, s = 0.5, tone = 0.42 },
    { y = 560, n = 9, s = 0.8, tone = 0.22 },
    { y = 640, n = 6, s = 1.25, tone = 0.0 },
  }
  for ri, R in ipairs(rowDefs) do
    local row = { y = R.y, s = R.s, tone = R.tone, stones = {} }
    for i = 1, R.n do
      local x = (i - 0.5) / R.n * 1280 + love.math.random(-40, 40)
      -- keep a gap for the path in the middle rows
      if not (ri < 3 and math.abs(x - 700) < 70) then
        row.stones[#row.stones + 1] = {
          x = x, kind = love.math.random(1, 5), w = love.math.random(44, 64), h = love.math.random(74, 130),
          lean = (love.math.random() - 0.5) * 0.3, moss = love.math.random(),
        }
      end
    end
    self.rows[ri] = row
  end
  self.fog = {}
  for i = 1, 36 do
    local layer = (i % 3) + 1
    self.fog[i] = { x = love.math.random(-200, 1480), layer = layer, s = 2.5 + love.math.random() * 3, v = (6 + love.math.random() * 10) * (layer == 2 and -1 or 1), dy = love.math.random(-10, 14) }
  end
  self.clouds = {}
  for i = 1, 7 do
    self.clouds[i] = { x = love.math.random(-200, 1400), y = 60 + love.math.random() * 220, s = 1 + love.math.random() * 1.6, v = 6 + love.math.random() * 8 }
  end
  self.wisps = {}
  for i = 1, 5 do self.wisps[i] = { x = 200 + i * 180, y = 520 + (i % 3) * 40, p = i * 1.7 } end
  self.bats = {}
  for i = 1, 7 do self.bats[i] = { p = love.math.random() * 6, r = 60 + love.math.random() * 120, v = 0.6 + love.math.random() * 0.6 } end
  self.crowFly = { u = 2 }
  self.flash = 0
  self.nextBolt = 5.5
  self.bolt = nil
end

local function jag(pts, x1, y1, x2, y2, disp, depth)
  if depth == 0 then
    pts[#pts + 1] = x2
    pts[#pts + 1] = y2
    return
  end
  local mx = (x1 + x2) / 2 + (love.math.random() - 0.5) * disp
  local my = (y1 + y2) / 2 + (love.math.random() - 0.5) * disp * 0.3
  jag(pts, x1, y1, mx, my, disp / 2, depth - 1)
  jag(pts, mx, my, x2, y2, disp / 2, depth - 1)
end

function S:strike()
  local x = 500 + love.math.random() * 600
  local pts = { x, 0 }
  jag(pts, x, 0, x + love.math.random(-160, 160), 430, 180, 5)
  local fork = { pts[21], pts[22] }
  jag(fork, pts[21], pts[22], pts[21] + love.math.random(-200, 200), pts[22] + 180, 90, 4)
  self.bolt = { pts, fork }
  self.flash = 1
  shack:setShake(14)
  self.crowFly.u = 0
end

function S:mousepressed() self:strike() end

function S:update(dt)
  self.t = self.t + dt
  shack:update(dt)
  for _, f in ipairs(self.fog) do
    f.x = f.x + f.v * dt
    if f.x > 1500 then f.x = -220 elseif f.x < -220 then f.x = 1500 end
  end
  for _, c in ipairs(self.clouds) do
    c.x = c.x + c.v * dt
    if c.x > 1500 then c.x = -300 end
  end
  self.flash = math.max(0, self.flash - dt * 2.4)
  self.nextBolt = self.nextBolt - dt
  if self.nextBolt <= 0 then
    self:strike()
    self.nextBolt = 6 + love.math.random() * 4
  end
  if self.crowFly.u < 2 then self.crowFly.u = self.crowFly.u + dt * 0.45 end
end

function S:drawTree(segs, flashAmt)
  lg.setColor(INK[1] + flashAmt * 0.25, INK[2] + flashAmt * 0.27, INK[3] + flashAmt * 0.3)
  for _, s in ipairs(segs) do
    lg.setLineWidth(math.max(1, s[5]))
    lg.line(s[1], s[2], s[3], s[4])
    if s[5] > 5 then lg.circle("fill", s[3], s[4], s[5] / 2) end
  end
end

local function crow(x, y, s, flip, peck)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * flip, s)
  lg.setColor(INK)
  lg.ellipse("fill", 0, -10, 13, 8)
  lg.polygon("fill", -10, -12, -28, -6, -10, -5)
  lg.push()
  lg.translate(9, -15)
  lg.rotate(peck)
  lg.circle("fill", 3, -3, 6)
  lg.polygon("fill", 7, -5, 18, -2, 7, 0)
  lg.pop()
  lg.setLineWidth(1.5)
  lg.line(-2, -3, -3, 3)
  lg.line(3, -3, 3, 3)
  lg.pop()
end

function S:drawFog(layer, alpha)
  lg.setBlendMode("add")
  for _, f in ipairs(self.fog) do
    if f.layer == layer then
      lg.setColor(0.42, 0.56, 0.62, alpha)
      lg.draw(self.soft, f.x, self.rows[layer].y + f.dy, 0, f.s * 1.9, f.s * 0.42, 64, 64)
    end
  end
  lg.setBlendMode("alpha")
end

function S:draw()
  local t = self.t
  local fl = self.flash
  self.fx(function()
    shack:apply()
    lg.setColor(1, 1, 1)
    lg.draw(self.sky)
    if fl > 0 then
      lg.setColor(0.75, 0.8, 1, fl * 0.55)
      lg.rectangle("fill", 0, 0, 1280, 720)
    end
    -- stars
    for k = 0, 80 do
      lg.setColor(0.8, 0.9, 1, 0.25 + 0.3 * math.sin(t * 1.5 + k))
      lg.circle("fill", gfx.hash(k) * 1280, gfx.hash(k + 100) * 330, 1)
    end
    -- the moon: halo, disc, maria and craters
    local mx, my, mr = 760, 250, 150
    lg.setBlendMode("add")
    lg.setColor(0.55, 0.75, 0.7, 0.42)
    lg.draw(self.soft, mx, my, 0, 9, 9, 64, 64)
    lg.setColor(0.7, 0.85, 0.75, 0.3)
    lg.draw(self.glow, mx, my, 0, 5, 5, 64, 64)
    lg.setBlendMode("alpha")
    lg.setColor(gfx.hex("#e6edd2"))
    lg.circle("fill", mx, my, mr)
    lg.setColor(gfx.hex("#c9d4b8"))
    lg.circle("fill", mx - 46, my - 40, 44)
    lg.circle("fill", mx + 40, my + 50, 54)
    lg.circle("fill", mx + 60, my - 60, 26)
    lg.circle("fill", mx - 70, my + 60, 24)
    lg.setColor(gfx.hex("#b6c2a6"))
    for k = 0, 9 do
      local a, r = gfx.hash(k * 2.3) * 6.28, gfx.hash(k + 3) * (mr - 24)
      lg.circle("fill", mx + math.cos(a) * r, my + math.sin(a) * r, 4 + gfx.hash(k + 9) * 9)
    end
    lg.setColor(1, 1, 0.92, 0.5)
    lg.setLineWidth(3)
    lg.arc("line", "open", mx, my, mr - 2, -2.6, -0.6)
    -- bats circling in front of the moon
    for _, b in ipairs(self.bats) do
      local a = t * b.v + b.p
      local bx, by = mx + math.cos(a) * b.r * 1.5, my + math.sin(a * 1.3) * b.r * 0.6
      local flap = math.sin(t * 14 + b.p) * 7
      lg.setColor(INK)
      lg.polygon("fill", bx, by, bx - 14, by - 4 - flap, bx - 8, by + 3)
      lg.polygon("fill", bx, by, bx + 14, by - 4 - flap, bx + 8, by + 3)
      lg.circle("fill", bx, by, 3)
    end
    -- clouds sliding across (dark, with a moonlit rim)
    for _, c in ipairs(self.clouds) do
      for k = 0, 4 do
        local cx = c.x + (k - 2) * 50 * c.s
        local r = (26 + math.sin(k * 1.9) * 9) * c.s
        lg.setColor(0.42, 0.55, 0.6, 0.35)
        lg.ellipse("fill", cx, c.y - 4, r * 1.5, r * 0.55)
        lg.setColor(0.05, 0.08, 0.13, 0.82)
        lg.ellipse("fill", cx, c.y, r * 1.5, r * 0.55)
      end
    end
    -- lightning bolt
    if self.bolt and fl > 0.15 then
      for i, pts in ipairs(self.bolt) do
        lg.setColor(0.7, 0.8, 1, 0.3 * fl)
        lg.setLineWidth(i == 1 and 14 or 8)
        lg.line(pts)
        lg.setColor(1, 1, 1, fl)
        lg.setLineWidth(i == 1 and 3.5 or 2)
        lg.line(pts)
      end
    end

    -- the hill with a chapel, and an iron fence along its crest
    local hill = gfx.rgb("#0e1a26")
    lg.setColor(hill[1] + fl * 0.2, hill[2] + fl * 0.2, hill[3] + fl * 0.22)
    lg.polygon("fill", 0, 480, 160, 440, 420, 420, 700, 440, 900, 400, 1080, 360, 1280, 390, 1280, 720, 0, 720)
    -- chapel
    lg.polygon("fill", 990, 380, 1130, 362, 1130, 280, 990, 290)
    lg.polygon("fill", 980, 292, 1140, 280, 1060, 226)
    lg.rectangle("fill", 1090, 190, 44, 100)
    lg.polygon("fill", 1084, 192, 1140, 192, 1112, 120)
    lg.rectangle("fill", 1110, 96, 4, 28)
    lg.rectangle("fill", 1103, 104, 18, 4)
    -- one lit window: someone is in there
    local wa = 0.75 + 0.25 * love.math.noise(t * 3)
    lg.setColor(1, 0.72, 0.3, wa)
    lg.polygon("fill", 1030, 356, 1050, 354, 1050, 322, 1040, 312, 1030, 324)
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.2, 0.35 * wa)
    lg.draw(self.glow, 1040, 336, 0, 1.2, 1.2, 64, 64)
    lg.setBlendMode("alpha")
    lg.setColor(INK)
    lg.rectangle("fill", 1039, 314, 2, 42)
    lg.rectangle("fill", 1030, 336, 20, 2)
    -- fence: spear-topped bars following the hill
    lg.setColor(hill[1] * 0.6, hill[2] * 0.6, hill[3] * 0.6)
    local function hillY(x)
      if x < 160 then return gfx.lerp(480, 440, x / 160)
      elseif x < 420 then return gfx.lerp(440, 420, (x - 160) / 260)
      elseif x < 700 then return gfx.lerp(420, 440, (x - 420) / 280)
      elseif x < 900 then return gfx.lerp(440, 400, (x - 700) / 200)
      else return gfx.lerp(400, 360, (x - 900) / 180) end
    end
    for x = 0, 960, 14 do
      local y = hillY(x)
      lg.rectangle("fill", x, y - 34, 2.5, 36)
      lg.polygon("fill", x - 2, y - 34, x + 4.5, y - 34, x + 1.2, y - 42)
    end
    lg.setLineWidth(2.5)
    for x = 0, 946, 14 do
      lg.line(x, hillY(x) - 26, x + 14, hillY(x + 14) - 26)
      lg.line(x, hillY(x) - 8, x + 14, hillY(x + 14) - 8)
    end

    self:drawTree(self.tree2, fl)
    -- rows of stones with fog between them
    for ri, row in ipairs(self.rows) do
      local base = gfx.mix(INK, gfx.rgb("#4a6474"), row.tone)
      -- ground band for this row
      lg.setColor(base[1] * 0.8 + fl * 0.15, base[2] * 0.8 + fl * 0.15, base[3] * 0.8 + fl * 0.17)
      lg.rectangle("fill", 0, row.y - 6, 1280, 720 - row.y + 6)
      if ri == 2 then self:drawTree(self.tree, fl) end
      for _, st in ipairs(row.stones) do
        lg.push()
        lg.translate(st.x, row.y)
        lg.rotate(st.lean)
        lg.scale(row.s)
        -- moonlit edge first (offset toward the moon), then the dark face
        lg.setColor(0.62, 0.78, 0.76, 0.5 + fl * 0.5)
        lg.push()
        lg.translate(st.x < 760 and 3 or -3, -2)
        stone(st.kind, st.w, st.h)
        lg.pop()
        lg.setColor(base[1] + fl * 0.3, base[2] + fl * 0.3, base[3] + fl * 0.33)
        stone(st.kind, st.w, st.h)
        -- inscription lines and moss on the plain slabs
        if st.kind == 1 or st.kind == 4 then
          lg.setColor(0, 0, 0, 0.45)
          lg.rectangle("fill", -st.w * 0.28, -st.h * 0.66, st.w * 0.56, 3)
          lg.rectangle("fill", -st.w * 0.2, -st.h * 0.56, st.w * 0.4, 3)
          lg.rectangle("fill", -st.w * 0.24, -st.h * 0.42, st.w * 0.48, 2)
          if st.moss > 0.5 then
            lg.setColor(0.2, 0.36, 0.22, 0.7)
            lg.ellipse("fill", -st.w * 0.2, -st.h * 0.1, st.w * 0.34, st.h * 0.1)
          end
        end
        lg.pop()
        -- grass tufts at the foot
        lg.setColor(base[1] * 0.6, base[2] * 0.6, base[3] * 0.6)
        for k = -2, 2 do
          lg.polygon("fill", st.x + k * 12 * row.s - 4, row.y + 2, st.x + k * 12 * row.s + 4, row.y + 2, st.x + k * 13 * row.s + math.sin(t + k) * 2, row.y - 14 * row.s)
        end
      end
      -- crows perched on two stones of the middle row
      if ri == 2 then
        local a, b = row.stones[2], row.stones[#row.stones - 1]
        if a then crow(a.x, row.y - a.h * row.s + 4, 1, 1, math.max(0, math.sin(t * 2)) * 0.5) end
        if b and self.crowFly.u >= 2 then crow(b.x, row.y - b.h * row.s + 4, 1, -1, 0) end
        if b and self.crowFly.u < 2 then
          local u = self.crowFly.u
          local cx, cy = b.x - u * 420, row.y - b.h * row.s - u * 260 + math.sin(u * 8) * 10
          local flap = math.sin(t * 16) * 16
          lg.setColor(INK)
          lg.ellipse("fill", cx, cy, 14, 6)
          lg.polygon("fill", cx - 4, cy, cx + 6, cy, cx + 2, cy - 22 - flap)
          lg.polygon("fill", cx - 4, cy, cx + 6, cy, cx - 6, cy - 16 + flap)
          lg.polygon("fill", cx - 12, cy - 2, cx - 24, cy + 1, cx - 12, cy + 3)
        end
      end
      self:drawFog(ri, ri == 1 and 0.14 or 0.2)
      -- the path: pale flagstones winding down the middle
      if ri == 1 then
        for k = 0, 9 do
          local u = k / 9
          lg.setColor(0.36, 0.46, 0.5, 0.5 - u * 0.15)
          lg.ellipse("fill", 700 + math.sin(u * 4) * 40 - u * 60, 470 + u * 240, 16 + u * 40, 4 + u * 9)
        end
      end
    end
    -- an open grave in the foreground with a lantern beside it
    lg.setColor(0, 0, 0)
    lg.polygon("fill", 800, 668, 990, 660, 1010, 700, 790, 708)
    lg.setColor(0.12, 0.16, 0.18)
    lg.polygon("fill", 1010, 668, 1120, 640, 1160, 690, 1030, 702)
    lg.setColor(INK)
    lg.setLineWidth(5)
    lg.line(1100, 600, 1076, 690)
    lg.polygon("fill", 1090, 592, 1112, 596, 1108, 624, 1088, 618)
    local la = 0.8 + 0.2 * love.math.noise(t * 6)
    lg.rectangle("fill", 752, 662, 20, 26, 3)
    lg.setLineWidth(2)
    lg.arc("line", "open", 762, 662, 8, math.pi, math.pi * 2)
    lg.setColor(1, 0.75, 0.3, la)
    lg.rectangle("fill", 756, 667, 12, 16, 2)
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.2, 0.4 * la)
    lg.draw(self.glow, 762, 676, 0, 2.2, 1.6, 64, 64)
    -- will-o'-wisps
    for _, w in ipairs(self.wisps) do
      local x = w.x + math.sin(t * 0.5 + w.p) * 70
      local y = w.y + math.sin(t * 0.9 + w.p * 2) * 26
      local a = 0.55 + 0.45 * math.sin(t * 2.2 + w.p)
      lg.setColor(0.35, 1, 0.75, 0.55 * a)
      lg.draw(self.glow, x, y, 0, 1.3, 1.3, 64, 64)
      lg.setColor(0.8, 1, 0.9, a)
      lg.draw(self.glow, x, y, 0, 0.3, 0.3, 64, 64)
      for k = 1, 5 do
        lg.setColor(0.35, 1, 0.75, 0.25 * a / k)
        lg.circle("fill", x - math.cos(t * 0.5 + w.p) * k * 7, y + k * 5, 3 - k * 0.4)
      end
    end
    lg.setBlendMode("alpha")
  end)
end

return S
