-- NOIR, scene 3: a meeting on a foggy pier.
--
-- Noir is mostly backlight: black shapes against something pale. Here the pale thing is
-- fog. The freighter, the crane and two figures are near-black silhouettes in front of
-- a luminous fog bank, and one hanging lamp does the storytelling. It swings on its
-- chain, and the shadows on the deck are *projected*: every corner of every shape is
-- pushed away from the bulb onto the ground plane, so the shadows stretch toward the
-- camera and sway with the lamp. No lighting library, just similar triangles.

local gfx = require("core.gfx")
local kit = require("core.noirkit")

local lg = love.graphics
local HORIZON = 452
local DECK = 548            -- screen y of the deck's far edge
local ZFIG = 0.34           -- how far toward the camera the figures stand (0..1)
local LAMP_H = 318          -- height of the lamp's pivot above the deck

local S = {
  title = "Noir",
  subtitle = "Fog on Pier 19",
  blurb = "Black silhouettes against glowing fog. A swinging dock lamp throws projected shadows that sway across the planks.",
  techniques = {
    "Backlight: near-black shapes in front of a pale fog gradient",
    "Projected shadows: each vertex pushed from the bulb onto the deck plane",
    "The lamp is a pendulum; the cone of light, the pool and the shadows follow it",
    "Rim light: a thin pale strip on whichever side faces the lamp",
    "Lighthouse beam: an additive wedge whose length follows cos(angle)",
    "Fog: drifting soft blobs between the layers; reflections as broken streaks",
  },
  libs = {
    "moonshine: desaturate, filmgrain, vignette",
  },
  genres = { "Crime and smuggling stories", "Stealth missions on the docks", "Atmospheric point-and-click", "Cutscenes and chapter openers" },
  controls = "press C to see the colour version.",
  warmup = 4.6,
}

-- Deck plane: x is screen x at the far edge, z goes 0 (far) .. 1 (near the camera).
local function deck(x, z)
  return 640 + (x - 640) * (1 + z * 0.22), DECK + z * 118
end

-- A standing figure as convex pieces in "x, height above the deck" coordinates.
local function figure(x, f)
  return {
    coat = {
      { x - 17, 172, x + 17, 172, x + 27, 62, x - 27, 62 },             -- coat body
      { x - 27, 62, x + 27, 62, x + 30, 44, x - 30, 44 },               -- coat hem flare
      { x - 26, 170, x - 16, 172, x - 22, 84, x - 34, 88 },             -- arm (back)
      { x + 16, 172, x + 26, 170, x + 34, 88, x + 22, 84 },             -- arm (front)
      { x - 16, 44, x - 3, 44, x - 4, 0, x - 18, 0 },                   -- legs
      { x + 3, 44, x + 16, 44, x + 18, 0, x + 4, 0 },
      { x - 22, 176, x + 22, 176, x + 17, 164, x - 17, 164 },           -- shoulders
      { x - 9, 186, x + 9, 186, x + 12, 172, x - 12, 172 },             -- turned-up collar
    },
    head = { x - 10 + f * 2, 204, x + 10 + f * 2, 204, x + 11 + f * 2, 182, x - 9 + f * 2, 178 },
    hat = {
      { x - 27 + f * 5, 206, x + 27 + f * 5, 206, x + 22 + f * 5, 199, x - 22 + f * 5, 199 },
      { x - 14 + f * 2, 206, x - 11 + f * 2, 228, x + 11 + f * 2, 230, x + 14 + f * 2, 206 },
    },
    x = x, f = f,
  }
end

local function box(x, w, h, base) base = base or 0 return { x, base + h, x + w, base + h, x + w, base, x, base } end

function S:load()
  self.t = 0
  self.bw = true
  self.fx = kit.grade()
  self.fx.filmgrain.opacity = 0.32
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.font = lg.newFont(20)
  -- sky: black at the top, glowing fog at the horizon
  self.sky = gfx.vgradient(1280, HORIZON, {
    { 0, gfx.rgb("#05060a") }, { 0.45, gfx.rgb("#1a1f2a") }, { 0.8, gfx.rgb("#6a7484") }, { 1, gfx.rgb("#b4bcc6") },
  })
  self.sea = gfx.vgradient(1280, DECK - HORIZON, {
    { 0, gfx.rgb("#a2aab4") }, { 0.35, gfx.rgb("#4a525e") }, { 1, gfx.rgb("#1a1e26") },
  })
  self.deckGrad = gfx.vgradient(1280, 720 - DECK, { { 0, gfx.rgb("#2c2a2a") }, { 1, gfx.rgb("#121113") } })
  self.beam = lg.newMesh({
    { 0, 0, 0, 0, 1, 1, 0.92, 0.5 }, { 1, -0.11, 0, 0, 1, 1, 0.92, 0 }, { 1, 0.11, 0, 0, 1, 1, 0.92, 0 },
  }, "fan", "static")
  self.headlight = lg.newMesh({
    { 0, -5, 0, 0, 1, 0.96, 0.82, 0.55 }, { 0, 5, 0, 0, 1, 0.96, 0.82, 0.55 },
    { 430, 64, 0, 0, 1, 0.96, 0.82, 0 }, { 430, -44, 0, 0, 1, 0.96, 0.82, 0 },
  }, "fan", "static")
  self.cone = lg.newMesh({
    { -10, 0, 0, 0, 1, 0.93, 0.76, 0.42 }, { 10, 0, 0, 0, 1, 0.93, 0.76, 0.42 },
    { 250, 1, 0, 0, 1, 0.93, 0.76, 0 }, { -250, 1, 0, 0, 1, 0.93, 0.76, 0 },
  }, "fan", "static")

  self.figs = { figure(560, 1), figure(662, -1) }
  self.case = box(686, 34, 26, 30)
  self.crates = { box(900, 86, 86), box(992, 62, 62), box(918, 70, 70, 86) }
  self.barrels = { box(1076, 44, 64), box(1126, 40, 56) }
  self.bollard = { 398, 34, 424, 34, 428, 0, 394, 0 }

  love.math.setRandomSeed(19)
  self.fog = {}
  for i = 1, 26 do
    self.fog[i] = {
      x = love.math.random(-200, 1400), y = love.math.random(400, 520), s = 3 + love.math.random() * 5,
      v = 6 + love.math.random() * 12, a = 0.05 + love.math.random() * 0.07, front = i > 17,
    }
    if self.fog[i].front then self.fog[i].y = love.math.random(540, 660) end
  end
  self.smoke = {}
end

function S:keypressed(k)
  if k == "c" then
    self.bw = not self.bw
    if self.bw then self.fx.enable("desaturate") else self.fx.disable("desaturate") end
  end
end

-- Lamp: pivot on the post's arm, bulb swinging below it. Returns bulb x, bulb height.
function S:lampPos()
  local a = math.sin(self.t * 1.35) * 0.5
  return 790 + math.sin(a) * 78, LAMP_H - math.cos(a) * 78, a
end

function S:update(dt)
  self.t = self.t + dt
  for _, f in ipairs(self.fog) do
    f.x = f.x + f.v * dt
    if f.x > 1500 then f.x = -300 end
  end
  if love.math.random() < dt * 5 then self.smoke[#self.smoke + 1] = { x = 352, y = 196, life = 0 } end
  for i = #self.smoke, 1, -1 do
    local s = self.smoke[i]
    s.life = s.life + dt
    s.y, s.x = s.y - 12 * dt, s.x + 22 * dt
    if s.life > 7 then table.remove(self.smoke, i) end
  end
end

-- Figure-plane polygon (x, height) -> screen polygon.
local function stand(p, z)
  local q = {}
  for k = 1, #p, 2 do
    local sx, sy = deck(p[k], z)
    q[k], q[k + 1] = sx, sy - p[k + 1] * (1 + z * 0.22)
  end
  return q
end

-- The same polygon, projected from the bulb (lx, lh, at z = 0.05) onto the deck.
local function shadow(p, z, lx, lh)
  local q = {}
  for k = 1, #p, 2 do
    local h = math.min(p[k + 1], lh - 30)
    local s = lh / (lh - h)
    q[k], q[k + 1] = deck(lx + (p[k] - lx) * s, 0.05 + (z - 0.05) * s)
  end
  return q
end

function S:drawFar()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  lg.draw(self.sea, 0, HORIZON)
  -- a far shore of warehouses, almost lost in the fog
  lg.setColor(gfx.hex("#8b94a0"))
  for k = 0, 15 do
    local w = 50 + gfx.hash(k) * 60
    local h = 18 + gfx.hash(k + 9) * 34
    lg.rectangle("fill", 660 + k * 44, HORIZON - h, w, h)
  end
  lg.rectangle("fill", 980, HORIZON - 96, 10, 96)
  lg.rectangle("fill", 1010, HORIZON - 80, 8, 80)
  -- lighthouse on its rock
  lg.setColor(gfx.hex("#59626e"))
  lg.polygon("fill", 1090, HORIZON, 1118, 428, 1186, 424, 1226, HORIZON)
  lg.polygon("fill", 1138, 428, 1168, 428, 1162, 300, 1144, 300)
  lg.rectangle("fill", 1136, 286, 34, 14)
  lg.polygon("fill", 1140, 274, 1166, 274, 1153, 256)
  lg.setColor(gfx.hex("#3a424c"))
  lg.rectangle("fill", 1140, 370, 26, 14)
  -- its beam: cos() makes it stretch, shrink and flip sides
  lg.setBlendMode("add")
  local c = math.cos(t * 0.6)
  local len = math.abs(c) * 900 + 60
  lg.push()
  lg.translate(1153, 280)
  lg.scale((c < 0 and -1 or 1) * len, len * 0.5)
  lg.setColor(1, 1, 1, 0.55)
  lg.draw(self.beam)
  lg.pop()
  local flash = math.max(0, 1 - math.abs(c) * 6)
  lg.setColor(1, 1, 0.92, 0.7 + flash * 0.3)
  lg.draw(self.glow, 1153, 280, 0, 0.6 + flash * 2.6, 0.6 + flash * 2.6, 64, 64)
  lg.setBlendMode("alpha")
  -- fog behind the ship
  for _, f in ipairs(self.fog) do
    if not f.front then
      lg.setColor(0.82, 0.86, 0.92, f.a * 1.6)
      lg.draw(self.soft, f.x, f.y - 40, 0, f.s * 1.8, f.s * 0.6, 64, 64)
    end
  end
end

function S:drawShip()
  local t = self.t
  local bob = math.sin(t * 0.7) * 2
  lg.push()
  lg.translate(0, bob)
  -- smoke from the funnel
  for _, s in ipairs(self.smoke) do
    lg.setColor(0.1, 0.11, 0.13, 0.3 * (1 - s.life / 7))
    lg.circle("fill", s.x, s.y, 9 + s.life * 9)
  end
  local ink = gfx.rgb("#0b0c10")
  lg.setColor(ink)
  -- hull with a raked bow, sheer line and a stern counter
  lg.polygon("fill", 0, 386, 60, 380, 520, 380, 612, 352, 640, 348, 606, 470, 0, 470)
  -- forecastle and anchor
  lg.polygon("fill", 520, 380, 612, 352, 612, 340, 530, 364)
  -- superstructure in three tiers
  lg.rectangle("fill", 200, 318, 230, 64)
  lg.rectangle("fill", 226, 276, 170, 44)
  lg.rectangle("fill", 250, 246, 110, 32)
  -- funnel, raked back, with a band
  lg.polygon("fill", 318, 248, 356, 248, 366, 186, 334, 186)
  -- masts, derrick and rigging
  lg.setLineWidth(5)
  lg.line(470, 380, 470, 210)
  lg.line(120, 382, 120, 250)
  lg.setLineWidth(3.5)
  lg.line(470, 240, 568, 300)
  lg.line(120, 270, 60, 316)
  lg.setLineWidth(1.2)
  lg.line(470, 212, 640, 348)
  lg.line(470, 212, 360, 248)
  lg.line(120, 252, 250, 262)
  lg.line(120, 252, 0, 360)
  lg.line(568, 300, 568, 340)
  lg.rectangle("fill", 558, 340, 20, 14)
  -- railings
  for x = 60, 200, 14 do lg.line(x, 380, x, 370) end
  lg.line(60, 370, 200, 370)
  for x = 430, 520, 14 do lg.line(x, 380, x, 370) end
  lg.line(430, 370, 520, 370)
  -- lifeboat
  lg.polygon("fill", 150, 356, 196, 356, 190, 368, 156, 368)
  lg.setColor(gfx.hex("#3a2420"))
  lg.polygon("fill", 320, 236, 358, 236, 360, 224, 322, 224)
  -- lit portholes and bridge windows
  for k = 0, 8 do
    if k ~= 3 and k ~= 6 then
      lg.setColor(1, 0.86, 0.6)
      lg.circle("fill", 70 + k * 58, 418, 4.5)
    end
  end
  for k = 0, 4 do
    lg.setColor(1, 0.9, 0.66, (k == 2) and 0.35 or 1)
    lg.rectangle("fill", 262 + k * 19, 256, 12, 10)
  end
  for k = 0, 5 do
    lg.setColor(1, 0.88, 0.62, (k % 3 == 1) and 0.2 or 0.9)
    lg.rectangle("fill", 240 + k * 26, 290, 14, 12)
  end
  lg.setBlendMode("add")
  for k = 0, 8 do
    lg.setColor(1, 0.8, 0.5, 0.3)
    lg.draw(self.glow, 70 + k * 58, 418, 0, 0.35, 0.35, 64, 64)
  end
  lg.setColor(1, 0.85, 0.6, 0.35)
  lg.draw(self.glow, 300, 262, 0, 1.6, 0.6, 64, 64)
  lg.setBlendMode("alpha")
  lg.pop()
  -- reflections: broken streaks under each porthole, darker hull reflection
  lg.setColor(0.04, 0.05, 0.07, 0.55)
  for i = 0, 9 do
    local y = 472 + i * 7
    local w = 600 - i * 22 + math.sin(t * 1.4 + i) * 12
    lg.rectangle("fill", 0, y, w, 4)
  end
  for k = 0, 8 do
    if k ~= 3 and k ~= 6 then
      for i = 0, 4 do
        lg.setColor(1, 0.86, 0.6, 0.5 - i * 0.09)
        lg.rectangle("fill", 67 + k * 58 + math.sin(t * 2 + k + i * 1.3) * 3, 476 + i * 9, 6, 3)
      end
    end
  end
  -- glints on the open water
  for i = 0, 40 do
    local x = 620 + gfx.hash(i) * 660
    local y = HORIZON + 6 + gfx.hash(i + 50) * 84
    local a = 0.25 + 0.25 * math.sin(t * 1.6 + i * 2.1)
    lg.setColor(0.9, 0.93, 0.97, a)
    lg.rectangle("fill", x, y, 14 + gfx.hash(i + 7) * 30, 1.5)
  end
end

function S:drawDeck(lx, lh)
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.deckGrad, 0, DECK)
  -- planks running toward the camera, and the far edge with its kerb
  lg.setColor(0.03, 0.03, 0.04, 0.7)
  lg.setLineWidth(2)
  for x = -400, 1700, 58 do
    local x1, y1 = deck(x, 0)
    local x2, y2 = deck(x, 1.5)
    lg.line(x1, y1, x2, y2)
  end
  -- the pool of lamplight on the planks
  local px, py = deck(lx, 0.2)
  lg.setBlendMode("add")
  lg.setColor(1, 0.92, 0.74, 0.6)
  lg.draw(self.glow, px, py + 8, 0, 5.4, 1.5, 64, 64)
  lg.setColor(1, 0.92, 0.74, 0.35)
  lg.draw(self.soft, px, py + 20, 0, 9, 2.4, 64, 64)
  lg.setBlendMode("alpha")
  -- projected shadows: everything that stands on the deck
  lg.setColor(gfx.hex("#0a0a0c"))
  for _, f in ipairs(self.figs) do
    for _, p in ipairs(f.coat) do lg.polygon("fill", shadow(p, ZFIG, lx, lh)) end
    lg.polygon("fill", shadow(f.head, ZFIG, lx, lh))
    for _, p in ipairs(f.hat) do lg.polygon("fill", shadow(p, ZFIG, lx, lh)) end
  end
  lg.polygon("fill", shadow(self.case, ZFIG, lx, lh))
  for _, p in ipairs(self.crates) do lg.polygon("fill", shadow(p, 0.3, lx, lh)) end
  for _, p in ipairs(self.barrels) do lg.polygon("fill", shadow(p, 0.3, lx, lh)) end
  lg.polygon("fill", shadow(self.bollard, 0.4, lx, lh))
  lg.polygon("fill", shadow({ 746, 200, 756, 200, 756, 0, 746, 0 }, 0.12, lx, lh))
  -- kerb along the water side
  lg.setColor(gfx.hex("#0c0c0e"))
  lg.rectangle("fill", 0, DECK - 8, 1280, 10)
  for x = 30, 1280, 150 do lg.rectangle("fill", x, DECK - 30, 14, 26) end
  lg.setLineWidth(2.5)
  for x = 30, 1130, 150 do
    lg.line(love.math.newBezierCurve(x + 7, DECK - 26, x + 82, DECK - 6, x + 157, DECK - 26):render(3))
  end
end

-- pale strip on the side of a silhouette that faces the lamp
local function rim(x, y, h, side, a)
  lg.setColor(0.95, 0.9, 0.78, a)
  lg.polygon("fill", x, y, x + side * 5, y + 3, x + side * 5, y + h, x, y + h)
end

function S:drawProps(lx, lh)
  local t = self.t
  local ink = gfx.rgb("#0c0c0f")
  -- lamp post with a swan-neck arm
  lg.setColor(ink)
  local bx, by = deck(751, 0.12)
  lg.polygon("fill", bx - 5, by, bx + 5, by, bx + 4, by - 330, bx - 4, by - 330)
  lg.polygon("fill", bx - 12, by, bx + 12, by, bx + 7, by - 22, bx - 7, by - 22)
  lg.setLineWidth(6)
  local hx, hy = deck(790, 0.05)
  hy = hy - LAMP_H
  lg.line(love.math.newBezierCurve(bx, by - 326, bx + 4, hy - 30, hx - 6, hy - 26, hx, hy):render(3))

  -- sedan parked on the left, lights on
  local cx, cy = deck(96, 0.42)
  lg.setColor(ink)
  lg.polygon("fill", cx, cy - 14, cx + 4, cy - 62, cx + 56, cy - 70, cx + 96, cy - 112, cx + 196, cy - 112, cx + 236, cy - 72, cx + 292, cy - 62, cx + 300, cy - 14)
  lg.polygon("fill", cx + 236, cy - 72, cx + 304, cy - 60, cx + 308, cy - 22, cx + 292, cy - 14)
  lg.circle("fill", cx + 62, cy - 14, 24)
  lg.circle("fill", cx + 238, cy - 14, 24)
  lg.setColor(gfx.hex("#2b3038"))
  lg.circle("fill", cx + 62, cy - 14, 10)
  lg.circle("fill", cx + 238, cy - 14, 10)
  lg.setColor(gfx.hex("#59626e"))
  lg.polygon("fill", cx + 102, cy - 104, cx + 142, cy - 104, cx + 142, cy - 74, cx + 76, cy - 74)
  lg.polygon("fill", cx + 150, cy - 104, cx + 192, cy - 104, cx + 222, cy - 74, cx + 150, cy - 74)
  lg.setColor(0.95, 0.9, 0.78, 0.5)
  lg.setLineWidth(2)
  lg.line(cx + 98, cy - 112, cx + 196, cy - 112, cx + 236, cy - 72, cx + 292, cy - 62)
  -- a driver's silhouette behind the glass
  lg.setColor(ink)
  lg.circle("fill", cx + 176, cy - 86, 9)
  lg.rectangle("fill", cx + 164, cy - 80, 24, 8)

  -- crates, barrels, bollard: black, with a lit edge toward the lamp
  for i, p in ipairs(self.crates) do
    local q = stand(p, 0.3)
    lg.setColor(gfx.hex("#17161a"))
    lg.polygon("fill", q)
    lg.setColor(gfx.hex("#2e2b2c"))
    lg.setLineWidth(2)
    lg.polygon("line", q[1] + 5, q[2] + 5, q[3] - 5, q[4] + 5, q[5] - 5, q[6] - 5, q[7] + 5, q[8] - 5)
    lg.line(q[1] + 5, q[2] + 5, q[5] - 5, q[6] - 5)
    rim(q[1], q[2], q[8] - q[2], 1, 0.55)
    lg.setColor(0.95, 0.9, 0.78, 0.4)
    lg.rectangle("fill", q[1], q[2], q[3] - q[1], 3)
  end
  for _, p in ipairs(self.barrels) do
    local q = stand(p, 0.3)
    lg.setColor(gfx.hex("#141316"))
    lg.polygon("fill", q)
    lg.setColor(gfx.hex("#2e2b2c"))
    lg.rectangle("fill", q[1], q[2] + 12, q[3] - q[1], 4)
    lg.rectangle("fill", q[1], q[6] - 16, q[3] - q[1], 4)
    rim(q[1], q[2], q[8] - q[2], 1, 0.4)
  end
  local q = stand(self.bollard, 0.4)
  lg.setColor(ink)
  lg.polygon("fill", q)
  lg.rectangle("fill", q[1] - 6, q[2] - 6, q[3] - q[1] + 12, 9, 3)
  rim(q[3], q[4], q[6] - q[4], -1, 0.5)
  -- mooring rope from the bollard to the ship
  lg.setColor(gfx.hex("#17161a"))
  lg.setLineWidth(3.5)
  lg.line(love.math.newBezierCurve(q[1] + 14, q[2], 470, 620, 520, 470, 560, 400):render(3))

  -- the two figures
  for i, f in ipairs(self.figs) do
    local side = (lx > f.x) and 1 or -1
    lg.setColor(ink)
    for _, p in ipairs(f.coat) do lg.polygon("fill", stand(p, ZFIG)) end
    lg.setColor(gfx.hex("#4a4038"))
    lg.polygon("fill", stand(f.head, ZFIG))
    lg.setColor(ink)
    for _, p in ipairs(f.hat) do lg.polygon("fill", stand(p, ZFIG)) end
    -- rim light down the lamp-facing side: hat, shoulder, coat edge
    local dist = math.abs(lx - f.x)
    local a = gfx.clamp(1.1 - dist / 400, 0.25, 0.9)
    local sx, sy = deck(f.x, ZFIG)
    local k = 1 + ZFIG * 0.22
    lg.setColor(0.95, 0.9, 0.78, a)
    lg.polygon("fill", sx + side * 17 * k, sy - 172 * k, sx + side * 27 * k, sy - 62 * k, sx + side * 30 * k, sy - 44 * k, sx + side * 25 * k, sy - 44 * k, sx + side * 22 * k, sy - 62 * k, sx + side * 13 * k, sy - 168 * k)
    lg.polygon("fill", sx + (f.f * 5 + side * 27) * k, sy - 206 * k, sx + (f.f * 5 + side * 22) * k, sy - 199 * k, sx + (f.f * 5 + side * 8) * k, sy - 199 * k, sx + (f.f * 5 + side * 8) * k, sy - 202 * k)
    lg.polygon("fill", sx + (f.f * 2 + side * 11) * k, sy - 229 * k, sx + (f.f * 2 + side * 14) * k, sy - 206 * k, sx + (f.f * 2 + side * 10) * k, sy - 206 * k, sx + (f.f * 2 + side * 8) * k, sy - 226 * k)
    lg.setColor(0.95, 0.85, 0.7, a * 0.8)
    lg.polygon("fill", sx + (f.f * 2 + side * 11) * k, sy - 199 * k, sx + (f.f * 2 + side * 11) * k, sy - 182 * k, sx + (f.f * 2 + side * 6) * k, sy - 184 * k, sx + (f.f * 2 + side * 6) * k, sy - 199 * k)
  end
  lg.setColor(gfx.hex("#141316"))
  local c = stand(self.case, ZFIG)
  lg.polygon("fill", c)
  lg.setColor(0.95, 0.9, 0.78, 0.6)
  lg.rectangle("fill", c[1], c[2], c[3] - c[1], 2.5)
  lg.rectangle("fill", (c[1] + c[3]) / 2 - 3, c[2] + 8, 6, 5)

  -- a gull asleep on a mooring post, far right
  lg.setColor(ink)
  lg.rectangle("fill", 1204, 470, 22, 90)
  lg.setColor(gfx.hex("#c2c6cc"))
  lg.ellipse("fill", 1215, 460, 15, 9)
  lg.circle("fill", 1226, 452, 6)
  lg.setColor(gfx.hex("#5c6470"))
  lg.polygon("fill", 1202, 458, 1222, 456, 1200, 466)
end

function S:drawLightFx(lx, lh)
  local t = self.t
  -- the hanging lamp itself: chain, shade, bulb
  local hx, hy = deck(790, 0.05)
  hy = hy - LAMP_H
  local sx, sy = deck(lx, 0.05)
  sy = sy - lh
  lg.setColor(gfx.hex("#0c0c0f"))
  lg.setLineWidth(2)
  lg.line(hx, hy, sx, sy - 14)
  lg.polygon("fill", sx - 22, sy, sx + 22, sy, sx + 8, sy - 16, sx - 8, sy - 16)
  lg.setColor(1, 0.96, 0.84)
  lg.ellipse("fill", sx, sy + 2, 8, 5)
  lg.setBlendMode("add")
  -- the cone of light in the fog, hanging from the shade and swinging with it
  local gx, gy = deck(lx + (lx - 790) * 0.9, 0.2)
  lg.push()
  lg.translate(sx, sy)
  lg.shear((gx - sx) / (gy - sy), 0)
  lg.scale(1, gy - sy + 30)
  lg.setColor(1, 1, 1, 0.75)
  lg.draw(self.cone)
  lg.pop()
  lg.setColor(1, 0.92, 0.74, 0.9)
  lg.draw(self.glow, sx, sy + 4, 0, 1.5, 1.5, 64, 64)
  lg.setColor(1, 0.92, 0.74, 0.3)
  lg.draw(self.soft, sx, sy + 20, 0, 5, 4, 64, 64)
  -- car headlights cutting into the fog
  local cx, cy = deck(96, 0.42)
  lg.setColor(1, 1, 1, 0.8)
  lg.draw(self.headlight, cx + 304, cy - 42)
  lg.setColor(1, 0.96, 0.84)
  lg.circle("fill", cx + 304, cy - 42, 6)
  lg.setColor(1, 0.92, 0.74, 0.6)
  lg.draw(self.glow, cx + 304, cy - 42, 0, 0.8, 0.8, 64, 64)
  -- fog in front of everything
  for _, f in ipairs(self.fog) do
    if f.front then
      lg.setColor(0.78, 0.82, 0.88, f.a * 0.8)
      lg.draw(self.soft, f.x, f.y, 0, f.s * 2, f.s * 0.6, 64, 64)
    end
  end
  lg.setBlendMode("alpha")
  -- cigarette ember, and a thread of smoke
  local fx, fy = deck(560, ZFIG)
  local k = 1 + ZFIG * 0.22
  lg.setColor(1, 0.55, 0.2, 0.7 + 0.3 * math.sin(t * 2.5))
  lg.circle("fill", fx + 16 * k, fy - 186 * k, 2.6)
  lg.setColor(0.85, 0.87, 0.9, 0.25)
  lg.setLineWidth(1.5)
  local pts = {}
  for i = 0, 10 do
    pts[#pts + 1] = fx + 16 * k + math.sin(t * 1.3 + i * 0.7) * i * 1.4
    pts[#pts + 1] = fy - 186 * k - i * 7
  end
  lg.line(pts)
end

function S:draw()
  self.fx(function()
    local lx, lh = self:lampPos()
    self:drawFar()
    self:drawShip()
    self:drawDeck(lx, lh)
    self:drawProps(lx, lh)
    self:drawLightFx(lx, lh)
    kit.letterbox("\"The fog rolled in off the bay like it had something to hide. Down here, everybody did.\"", self.font)
  end)
end

return S
