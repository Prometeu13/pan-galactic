-- UNDERWATER, scene 3: the midnight zone, 3,800 metres down.
--
-- No sunlight reaches here, so the rule flips: nothing is visible unless something
-- lights it. The scene is drawn normally, then multiplied by a light map that starts
-- almost black and only contains the lights that exist down here: an anglerfish's
-- lure, a submersible's two lamps, the red glow of a vent. Anything alive that makes
-- its own light (plankton, jellyfish, photophores on the fish) is drawn afterwards,
-- additively, so it glows in the dark. Disturb the water (click) and a wave of
-- plankton lights up as it spreads: each speck flashes when the ring passes it.

local gfx = require("core.gfx")
local view = require("core.view")
local moonshine = require("moonshine")

local lg = love.graphics
local FLOOR = 640

local S = {
  title = "Underwater",
  subtitle = "The Midnight Zone",
  blurb = "Pitch-black deep sea lit only by its creatures: an anglerfish's lure, a submersible's lamps, glowing jellies, vents, and plankton that flashes in waves.",
  techniques = {
    "Light map: near-black ambient + only the lights that exist, multiplied over the scene",
    "Emissive pass: plankton, jellies and photophores drawn additively afterwards",
    "Plankton wave: each speck flashes when an expanding ring reaches it",
    "Anglerfish: one body polygon, needle teeth, a Bezier rod ending in the lure",
    "Submersible lamps: additive cones that also exist in the light map",
    "Vent plume: rising soft particles with a heat shimmer of the light behind",
  },
  libs = {
    "moonshine: glow (bloom) for every light source, plus a vignette",
  },
  genres = { "Deep-sea exploration and horror", "Submarine sims", "Creature-collecting in the dark", "Atmospheric puzzle games" },
  controls = "click anywhere: a wave of bioluminescence spreads from that point.",
  warmup = 3.4,
}

function S:load()
  self.t = 0
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.1)
  self.lightCanvas = lg.newCanvas(1280, 720)
  self.font = lg.newFont(13)
  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.strength = 6
  self.fx.glow.min_luma = 0.45
  self.fx.vignette.radius = 0.85
  self.fx.vignette.softness = 0.6
  self.fx.vignette.opacity = 0.7
  self.cone = lg.newMesh({
    { 0, 0, 0, 0, 1, 1, 1, 0.9 }, { 1, -0.2, 0, 0, 1, 1, 1, 0 }, { 1, 0.2, 0, 0, 1, 1, 1, 0 },
  }, "fan", "static")
  love.math.setRandomSeed(88)
  self.plankton = {}
  for i = 1, 320 do
    self.plankton[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 700), p = love.math.random() * 6, flash = 0, hue = love.math.random() }
  end
  self.waves = { { x = 900, y = 260, r = 0 } }
  self.jellies = {}
  for i = 1, 5 do
    self.jellies[i] = { x = ({ 110, 660, 800, 1150, 1230 })[i], y = 120 + love.math.random() * 300, p = love.math.random() * 6, s = 0.6 + love.math.random() * 0.6 }
  end
  self.lantern = {}
  for i = 1, 9 do
    self.lantern[i] = { x = love.math.random(0, 1280), y = 180 + love.math.random() * 360, v = 30 + love.math.random() * 30, p = love.math.random() * 6 }
  end
  self.vent = {}
  self.sub = { x = 980, y = 190 }
  self.nextWave = 4
  self.floor = gfx.ridge(1280, FLOOR + 50, 80, 0.005, 6.1, 14, 4)
end

function S:mousepressed(x, y)
  if x then self.waves[#self.waves + 1] = { x = x, y = y, r = 0 } end
end

function S:update(dt)
  self.t = self.t + dt
  local t = self.t
  self.sub.x = 960 + math.sin(t * 0.22) * 150
  self.sub.y = 190 + math.sin(t * 0.37) * 40
  self.nextWave = self.nextWave - dt
  if self.nextWave <= 0 then
    self.nextWave = 5
    self.waves[#self.waves + 1] = { x = self.sub.x - 60, y = self.sub.y + 40, r = 0 }
  end
  for i = #self.waves, 1, -1 do
    local w = self.waves[i]
    w.r = w.r + 260 * dt
    if w.r > 1500 then table.remove(self.waves, i) end
  end
  for _, p in ipairs(self.plankton) do
    p.flash = math.max(0, p.flash - dt * 0.9)
    p.x = p.x + math.sin(t * 0.3 + p.p) * 4 * dt
    p.y = p.y + math.cos(t * 0.23 + p.p) * 3 * dt
    for _, w in ipairs(self.waves) do
      local d = math.sqrt((p.x - w.x) ^ 2 + (p.y - w.y) ^ 2)
      if math.abs(d - w.r) < 26 then p.flash = math.max(p.flash, 1 - w.r / 1500) end
    end
  end
  for _, f in ipairs(self.lantern) do
    f.x = f.x - f.v * dt
    if f.x < -60 then f.x = 1340 f.y = 180 + love.math.random() * 360 end
  end
  if love.math.random() < dt * 14 then
    self.vent[#self.vent + 1] = { x = 1080 + love.math.random(-10, 10), y = FLOOR - 60, life = 0, d = love.math.random() - 0.5 }
  end
  for i = #self.vent, 1, -1 do
    local v = self.vent[i]
    v.life = v.life + dt
    v.y = v.y - (70 - v.life * 10) * dt
    v.x = v.x + (v.d * 24 + math.sin(t + v.life * 2) * 10) * dt
    if v.life > 4 then table.remove(self.vent, i) end
  end
end

local AX, AY = 400, 400          -- anglerfish position

function S:lurePos()
  local t = self.t
  return AX + 180 + math.sin(t * 1.1) * 14, AY - 150 + math.cos(t * 0.9) * 10 + math.sin(t * 0.6) * 12
end

function S:drawAngler()
  local t = self.t
  local bob = math.sin(t * 0.6) * 12
  local lx, ly = self:lurePos()
  local jaw = 0.5 + 0.5 * math.sin(t * 0.5)          -- slow gape
  lg.push()
  lg.translate(AX, AY + bob)
  -- tail and fins behind the body
  local tw = math.sin(t * 1.4) * 14
  lg.setColor(gfx.hex("#6a4458"))
  lg.polygon("fill", -150, -10, -240, -70 + tw, -216, 0 + tw * 0.5, -244, 64 + tw, -150, 22)
  lg.polygon("fill", -60, -96, -120, -150 + tw * 0.4, -130, -80)
  lg.polygon("fill", -40, 92, -100, 140 - tw * 0.4, -112, 78)
  -- body: a lumpy ball
  local body = {}
  for i = 0, 27 do
    local a = i / 28 * math.pi * 2
    local r = 1 + gfx.fbm(i * 0.4, 3.1, 3) * 0.16
    body[#body + 1] = math.cos(a) * 168 * r - 10
    body[#body + 1] = math.sin(a) * 118 * r
  end
  lg.setColor(gfx.hex("#8a5a6c"))
  lg.polygon("fill", body)
  lg.setColor(gfx.hex("#a67486"))
  lg.ellipse("fill", -30, -44, 110, 54)
  -- warts and scars
  for k = 0, 16 do
    lg.setColor(gfx.hex("#6a4456"))
    lg.circle("fill", -130 + gfx.hash(k) * 200, -80 + gfx.hash(k + 20) * 150, 3 + gfx.hash(k + 40) * 6)
  end
  -- the mouth: a dark wedge that opens and closes, with needle teeth
  local gape = 34 + jaw * 30
  lg.setColor(0.03, 0.01, 0.03)
  lg.polygon("fill", 40, -14, 166, -30 - gape * 0.4, 176, 0, 166, 30 + gape, 40, 26)
  lg.setColor(gfx.hex("#f2ecd8"))
  for k = 0, 8 do
    local u = k / 8
    local ux, uy = gfx.lerp(60, 166, u), gfx.lerp(-16, -30 - gape * 0.4, u)
    local len = 16 + (k % 3) * 12
    lg.polygon("fill", ux - 4, uy, ux + 4, uy, ux + 1, uy + len)
    local bx, by = gfx.lerp(60, 166, u), gfx.lerp(26, 30 + gape, u)
    local len2 = 20 + ((k + 1) % 3) * 14
    lg.polygon("fill", bx - 4, by, bx + 4, by, bx - 1, by - len2)
  end
  -- lower jaw juts out
  lg.setColor(gfx.hex("#7a4e62"))
  lg.polygon("fill", 30, 30, 166, 30 + gape, 180, 44 + gape, 100, 70 + gape * 0.6, 20, 60)
  -- small pale eye with a dead stare
  lg.setColor(gfx.hex("#d8e8e0"))
  lg.circle("fill", 78, -52, 13)
  lg.setColor(0.02, 0.02, 0.03)
  lg.circle("fill", 82, -51, 6)
  lg.setColor(1, 1, 1)
  lg.circle("fill", 85, -55, 2)
  lg.setColor(gfx.hex("#3a2434"))
  lg.setLineWidth(5)
  lg.arc("line", "open", 78, -52, 20, math.pi * 1.1, math.pi * 1.9)
  -- pectoral fin flapping
  lg.setColor(gfx.hex("#472c3c"))
  lg.polygon("fill", -30, 30, -90, 60 + math.sin(t * 2) * 14, -70, 20)
  lg.pop()
  -- the rod: from the forehead up and forward to the lure
  lg.setColor(gfx.hex("#6f4a58"))
  lg.setLineWidth(5)
  lg.line(love.math.newBezierCurve(AX + 40, AY + bob - 100, AX + 60, AY - 230, AX + 170, AY - 230, lx, ly):render(4))
end

function S:drawSub()
  local t = self.t
  local s = self.sub
  lg.push()
  lg.translate(s.x, s.y)
  lg.rotate(math.sin(t * 0.37) * 0.06)
  -- propeller
  lg.setColor(gfx.hex("#4a4a52"))
  lg.rectangle("fill", 74, -6, 16, 12)
  lg.ellipse("fill", 94, 0, 4, 22 * math.abs(math.sin(t * 20)) + 3)
  -- hull
  lg.setColor(gfx.hex("#e8b830"))
  lg.ellipse("fill", 0, 0, 82, 44)
  lg.setColor(gfx.hex("#c8962a"))
  lg.arc("fill", 0, 0, 82, 0.1, math.pi - 0.1)
  lg.setColor(gfx.hex("#e8b830"))
  lg.ellipse("fill", 0, -4, 80, 34)
  lg.rectangle("fill", -22, -60, 40, 24, 6)
  lg.setColor(gfx.hex("#4a4a52"))
  lg.rectangle("fill", -6, -74, 6, 16)
  -- skids and a robot arm
  lg.setLineWidth(5)
  lg.line(-50, 44, 50, 44)
  lg.line(-36, 36, -40, 44)
  lg.line(36, 36, 40, 44)
  lg.setLineWidth(4)
  lg.line(-66, 20, -96, 38, -110, 30)
  lg.line(-110, 30, -122, 24)
  lg.line(-110, 30, -118, 40)
  -- viewport with a face-sized glow
  lg.setColor(gfx.hex("#2a3a4a"))
  lg.circle("fill", -42, -4, 24)
  lg.setColor(gfx.hex("#9fe0f0"))
  lg.circle("fill", -42, -4, 19)
  lg.setColor(gfx.hex("#2a3a4a"))
  lg.circle("fill", -40, -2, 7)
  lg.rectangle("fill", -48, 4, 16, 8, 3)
  lg.setColor(1, 1, 1, 0.6)
  lg.arc("line", "open", -42, -4, 15, math.pi * 1.1, math.pi * 1.6)
  -- name plate, rivets
  lg.setColor(gfx.hex("#2a3a4a"))
  lg.setFont(self.font)
  lg.print("NAUTILA 3", 2, -8)
  for k = 0, 7 do lg.circle("fill", -70 + k * 20, 26 - math.abs(k - 3.5) * 3, 2) end
  lg.pop()
end

-- the sub's two lamps: positions and directions
function S:lamps()
  local t = self.t
  local s = self.sub
  return {
    { s.x - 78, s.y + 14, math.pi * 0.86 + math.sin(t * 0.5) * 0.18 },
    { s.x - 70, s.y + 30, math.pi * 0.66 + math.sin(t * 0.4 + 1) * 0.16 },
  }
end

function S:drawScene()
  local t = self.t
  lg.clear(0.02, 0.05, 0.1, 1)
  -- distant giant squid: visible only when a lamp sweeps across it
  local qx, qy = 300 + math.sin(t * 0.1) * 200, 190
  lg.setColor(gfx.hex("#3a2a4a"))
  lg.polygon("fill", qx + 120, qy, qx + 40, qy - 34, qx - 40, qy - 26, qx - 60, qy, qx - 40, qy + 26, qx + 40, qy + 34)
  lg.polygon("fill", qx + 120, qy, qx + 170, qy - 40, qx + 190, qy, qx + 170, qy + 40)
  lg.setLineWidth(7)
  for k = -3, 3 do
    lg.line(love.math.newBezierCurve(qx - 56, qy + k * 6, qx - 140, qy + k * 22 + math.sin(t + k) * 14, qx - 240, qy + k * 30 + math.sin(t * 1.3 + k) * 26):render(3))
  end
  lg.setColor(gfx.hex("#e8e0c8"))
  lg.circle("fill", qx - 30, qy - 6, 12)
  lg.setColor(0, 0, 0)
  lg.circle("fill", qx - 32, qy - 6, 6)
  -- sea floor with rocks, tube worms and vent chimneys
  lg.setColor(gfx.hex("#3a3a44"))
  gfx.fillRidge(self.floor, 720)
  lg.setColor(gfx.hex("#5a5a66"))
  lg.setLineWidth(3)
  lg.line(self.floor)
  for k = 0, 18 do
    local x = 30 + k * 70 + gfx.hash(k) * 30
    lg.setColor(gfx.hex("#2c2c36"))
    lg.ellipse("fill", x, FLOOR + 36 + gfx.hash(k + 5) * 30, 20 + gfx.hash(k + 9) * 30, 10 + gfx.hash(k + 3) * 10)
  end
  -- chimneys of the vent field
  for i, c in ipairs({ { 1080, 96, 34 }, { 1010, 60, 24 }, { 1150, 70, 28 }, { 950, 36, 18 } }) do
    local x, h, w = c[1], c[2], c[3]
    lg.setColor(gfx.hex("#4a4038"))
    lg.polygon("fill", x - w, FLOOR + 20, x + w, FLOOR + 20, x + w * 0.4, FLOOR - h, x - w * 0.4, FLOOR - h)
    lg.setColor(gfx.hex("#6a5a48"))
    lg.polygon("fill", x - w, FLOOR + 20, x - w * 0.3, FLOOR + 20, x - w * 0.1, FLOOR - h, x - w * 0.4, FLOOR - h)
    lg.setColor(gfx.hex("#c8502a"))
    lg.ellipse("fill", x, FLOOR - h, w * 0.4, 4)
  end
  -- tube worms: white stalks with red plumes that retract and extend
  for k = 0, 22 do
    local x = 840 + k * 17 + gfx.hash(k) * 8
    local h = 26 + gfx.hash(k + 30) * 40
    local sw = math.sin(t * 1.3 + k) * 4
    lg.setColor(gfx.hex("#e8e4d8"))
    lg.setLineWidth(5)
    lg.line(x, FLOOR + 26, x + sw * 0.5, FLOOR + 26 - h)
    lg.setColor(gfx.hex("#d8302a"))
    lg.ellipse("fill", x + sw * 0.6, FLOOR + 22 - h, 5, 8 + math.sin(t * 2 + k) * 3)
  end
  -- a whale skeleton half-buried on the left: ribs as arcs
  lg.setColor(gfx.hex("#c8c4b4"))
  lg.setLineWidth(6)
  for k = 0, 7 do
    lg.arc("line", "open", 150 + k * 30, FLOOR + 40, 46 - k * 3, math.pi * 1.08, math.pi * 1.92)
  end
  lg.setLineWidth(9)
  lg.line(110, FLOOR + 30, 400, FLOOR + 36)
  lg.polygon("fill", 40, FLOOR + 40, 110, FLOOR + 4, 120, FLOOR + 40)
  self:drawAngler()
  self:drawSub()
  -- lanternfish bodies (their lights come later)
  for _, f in ipairs(self.lantern) do
    lg.setColor(gfx.hex("#4a5a6a"))
    lg.ellipse("fill", f.x, f.y, 22, 8)
    lg.polygon("fill", f.x + 18, f.y, f.x + 34, f.y - 9, f.x + 34, f.y + 9)
    lg.setColor(gfx.hex("#d8e8f0"))
    lg.circle("fill", f.x - 13, f.y - 2, 3.5)
  end
end

function S:drawLight()
  local t = self.t
  lg.setCanvas(self.lightCanvas)
  lg.clear(0.045, 0.06, 0.09, 1)
  lg.setBlendMode("add")
  -- the lure
  local lx, ly = self:lurePos()
  local pulse = 0.8 + 0.2 * math.sin(t * 3)
  lg.setColor(0.5 * pulse, 1 * pulse, 0.85 * pulse)
  lg.draw(self.soft, lx, ly, 0, 8, 8, 64, 64)
  lg.draw(self.soft, lx - 80, ly + 120, 0, 5, 4, 64, 64)
  lg.draw(self.glow, lx, ly, 0, 3, 3, 64, 64)
  -- submersible lamps
  for _, l in ipairs(self:lamps()) do
    lg.push()
    lg.translate(l[1], l[2])
    lg.rotate(l[3])
    lg.scale(760, 760)
    lg.setColor(1, 0.97, 0.85)
    lg.draw(self.cone)
    lg.pop()
  end
  lg.setColor(0.7, 0.9, 1)
  lg.draw(self.soft, self.sub.x - 30, self.sub.y, 0, 2.6, 2, 64, 64)
  -- vents: a dull red glow
  lg.setColor(1, 0.35, 0.15)
  lg.draw(self.soft, 1080, FLOOR - 70, 0, 3.4, 3, 64, 64)
  lg.setColor(0.6, 0.2, 0.1)
  lg.draw(self.soft, 1000, FLOOR - 30, 0, 3, 2, 64, 64)
  -- jellies light their surroundings a little
  for _, j in ipairs(self.jellies) do
    lg.setColor(0.5, 0.2, 0.5)
    lg.draw(self.soft, j.x, j.y, 0, 2 * j.s, 2 * j.s, 64, 64)
  end
  -- plankton flashes light the water around them
  for _, p in ipairs(self.plankton) do
    if p.flash > 0.05 then
      lg.setColor(0.2 * p.flash, 0.6 * p.flash, 0.7 * p.flash)
      lg.draw(self.glow, p.x, p.y, 0, 0.9, 0.9, 64, 64)
    end
  end
  lg.setBlendMode("alpha")
end

function S:drawEmissive()
  local t = self.t
  lg.setBlendMode("add")
  -- vent plume
  for _, v in ipairs(self.vent) do
    local u = v.life / 4
    lg.setColor(1, 0.5 - u * 0.3, 0.2, 0.14 * (1 - u))
    lg.draw(self.soft, v.x, v.y, 0, 0.3 + u * 1.4, 0.3 + u * 1.4, 64, 64)
  end
  -- lamp cones, visibly, in the water
  for _, l in ipairs(self:lamps()) do
    lg.push()
    lg.translate(l[1], l[2])
    lg.rotate(l[3])
    lg.scale(700, 700)
    lg.setColor(0.9, 0.95, 1, 0.16)
    lg.draw(self.cone)
    lg.pop()
    lg.setColor(1, 1, 0.9, 0.9)
    lg.draw(self.glow, l[1], l[2], 0, 0.5, 0.5, 64, 64)
  end
  -- the lure
  local lx, ly = self:lurePos()
  local pulse = 0.8 + 0.2 * math.sin(t * 3)
  lg.setColor(0.5, 1, 0.85, 0.9 * pulse)
  lg.draw(self.glow, lx, ly, 0, 1.3, 1.3, 64, 64)
  lg.setColor(1, 1, 1, pulse)
  lg.draw(self.glow, lx, ly, 0, 0.35, 0.35, 64, 64)
  -- jellyfish: bell, inner organs, trailing tentacles
  for _, j in ipairs(self.jellies) do
    local beat = math.sin(t * 1.6 + j.p)
    local x, y = j.x + math.sin(t * 0.3 + j.p) * 30, j.y - ((t * 10 + j.p * 40) % 500) * 0.3 + 60
    local w, h = (46 - beat * 8) * j.s, (30 + beat * 6) * j.s
    lg.setColor(0.9, 0.3, 0.7, 0.35)
    lg.arc("fill", x, y, w, math.pi, math.pi * 2)
    lg.ellipse("fill", x, y, w, h * 0.3)
    lg.setColor(1, 0.6, 0.85, 0.7)
    lg.setLineWidth(2)
    lg.arc("line", "open", x, y, w, math.pi, math.pi * 2)
    lg.setColor(1, 0.8, 0.9, 0.6)
    for k = -1, 1 do lg.ellipse("fill", x + k * w * 0.3, y - h * 0.4, w * 0.12, h * 0.3) end
    for k = -3, 3 do
      local pts = {}
      for i = 0, 8 do
        pts[#pts + 1] = x + k * w * 0.26 + math.sin(t * 1.6 + j.p - i * 0.6 + k) * (3 + i * 1.4)
        pts[#pts + 1] = y + i * 12 * j.s
      end
      lg.setColor(1, 0.5, 0.8, 0.35)
      lg.setLineWidth(1.5)
      lg.line(pts)
    end
    lg.setColor(0.9, 0.3, 0.7, 0.25)
    lg.draw(self.glow, x, y - 6, 0, 1.6 * j.s, 1.6 * j.s, 64, 64)
  end
  -- lanternfish photophores: a row of blue dots along the belly
  for _, f in ipairs(self.lantern) do
    for k = 0, 5 do
      lg.setColor(0.4, 0.8, 1, 0.6 + 0.4 * math.sin(t * 4 + k + f.p))
      lg.circle("fill", f.x - 12 + k * 6, f.y + 5, 1.8)
    end
    lg.setColor(0.4, 0.8, 1, 0.25)
    lg.draw(self.glow, f.x, f.y + 4, 0, 0.6, 0.25, 64, 64)
  end
  -- plankton: faint always, bright when a wave passes
  for _, p in ipairs(self.plankton) do
    local a = 0.1 + 0.08 * math.sin(t * 2 + p.p) + p.flash
    lg.setColor(0.3 + p.hue * 0.2, 0.9, 0.9 - p.hue * 0.3, math.min(1, a))
    lg.circle("fill", p.x, p.y, 1.2 + p.flash * 2)
    if p.flash > 0.1 then
      lg.setColor(0.3, 0.9, 0.9, p.flash * 0.5)
      lg.draw(self.glow, p.x, p.y, 0, 0.3, 0.3, 64, 64)
    end
  end
  lg.setBlendMode("alpha")
end

function S:draw()
  local t = self.t
  self.fx(function()
    local target = lg.getCanvas()
    self:drawScene()
    self:drawLight()
    lg.setCanvas(target)
    lg.setBlendMode("multiply", "premultiplied")
    lg.setColor(1, 1, 1)
    lg.draw(self.lightCanvas)
    lg.setBlendMode("alpha")
    self:drawEmissive()
    -- depth read-out, like the sub's HUD
    lg.setFont(self.font)
    lg.setColor(0.5, 1, 0.9, 0.8)
    lg.print(string.format("DEPTH  %d m", 3800 + math.floor(math.sin(t * 0.37) * -40)), 40, 34)
    lg.print("TEMP  2.1 C      PRESSURE  381 atm", 40, 54)
    lg.setColor(0.5, 1, 0.9, 0.4)
    lg.rectangle("line", 30, 26, 290, 52)
  end)
end

return S
