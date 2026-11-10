-- UNDERWATER, scene 2: a shipwreck in clear blue water.
--
-- Water is a colour filter that gets stronger with distance. Every object is drawn in
-- its own colours and then pulled toward the water colour by how far away it is
-- (the `fog` helper below), which is all the "depth" there is. On top of that: light
-- shafts from the surface, drifting "marine snow", kelp ribbons that sway with a
-- phase delay along their length, and a shark whose body is a spine bent by a
-- travelling sine wave. The diver's torch is an additive cone.

local gfx = require("core.gfx")
local moonshine = require("moonshine")

local lg = love.graphics
local FLOOR = 610
local WATER = gfx.rgb("#1d6f9c")
local DEEP = gfx.rgb("#0a2a4a")

local S = {
  title = "Underwater",
  subtitle = "The Wreck of the Marigold",
  blurb = "A sunken sailing ship in blue water: distance fog, light shafts, swaying kelp, a patrolling shark, a diver with a torch and a glint of treasure.",
  techniques = {
    "Depth = colour: every object is mixed toward the water colour by its distance",
    "Shark: a spine bent by a travelling sine wave; outline built around it",
    "Kelp: ribbons whose sway lags along their length (phase delay)",
    "Ship: one hull polygon, plank lines, ribs showing through a dark breach",
    "Light shafts and the diver's torch are additive gradient wedges",
    "Marine snow and bubbles: two tiny particle lists going opposite ways",
  },
  libs = {
    "moonshine: glow (bloom) and a deep-blue vignette",
  },
  genres = { "Diving and treasure-hunting games", "Underwater metroidvanias", "Stealth with a predator (avoid the shark)", "Relaxing exploration" },
  controls = "move the mouse: the diver aims the torch at it.",
  warmup = 4,
}

-- pull a colour toward the water colour: d = 0 (close) .. 1 (lost in the blue)
local function fog(hex, d)
  return gfx.mix(gfx.rgb(hex), WATER, d)
end

function S:load()
  self.t = 0
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.strength = 4
  self.fx.glow.min_luma = 0.8
  self.fx.vignette.radius = 0.9
  self.fx.vignette.softness = 0.6
  self.fx.vignette.opacity = 0.55
  self.bg = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#49b8d8") }, { 0.3, gfx.rgb("#2389b8") }, { 0.7, WATER }, { 1, DEEP },
  })
  self.shaft = lg.newMesh({
    { 0, 0, 0, 0, 0.7, 0.95, 1, 0.3 }, { 1, 0, 0, 0, 0.7, 0.95, 1, 0.3 },
    { 1.6, 1, 0, 0, 0.7, 0.95, 1, 0 }, { -0.6, 1, 0, 0, 0.7, 0.95, 1, 0 },
  }, "fan", "static")
  self.torch = lg.newMesh({
    { 0, 0, 0, 0, 1, 0.97, 0.8, 0.7 }, { 1, -0.24, 0, 0, 1, 0.97, 0.8, 0 }, { 1, 0.24, 0, 0, 1, 0.97, 0.8, 0 },
  }, "fan", "static")
  love.math.setRandomSeed(51)
  self.snow = {}
  for i = 1, 120 do
    self.snow[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), v = 6 + love.math.random() * 12, p = love.math.random() * 6, s = 0.6 + love.math.random() * 1.4 }
  end
  self.kelp = {}
  for i = 1, 16 do
    local x = love.math.random(20, 1260)
    if x < 330 or x > 1010 or love.math.random() < 0.25 then
      self.kelp[#self.kelp + 1] = { x = x, h = 160 + love.math.random() * 260, p = love.math.random() * 6, d = love.math.random() * 0.5, w = 8 + love.math.random() * 8 }
    end
  end
  table.sort(self.kelp, function(a, b) return a.d > b.d end)
  self.fishes = {}
  for i = 1, 34 do
    self.fishes[i] = { a = love.math.random() * 6, r = 40 + love.math.random() * 90, v = 0.5 + love.math.random() * 0.5, y = love.math.random(-30, 30), col = i % 3 }
  end
  self.bubbles = {}
  self.shark = { x = 40, dir = 1, y = 190 }
  self.diver = { x = 860, y = 330, aim = 2.6 }
  -- sand floor profile
  self.sand = gfx.ridge(1280, FLOOR + 40, 60, 0.004, 3.3, 16, 3)
end

function S:update(dt)
  self.t = self.t + dt
  local t = self.t
  for _, s in ipairs(self.snow) do
    s.y = s.y + s.v * dt
    s.x = s.x + math.sin(t * 0.5 + s.p) * 6 * dt
    if s.y > 730 then s.y = -10 end
  end
  local sh = self.shark
  sh.x = sh.x + sh.dir * 62 * dt
  if sh.x > 1600 then sh.dir = -1 sh.y = 150 + love.math.random() * 160 end
  if sh.x < -320 then sh.dir = 1 sh.y = 150 + love.math.random() * 160 end
  -- the diver hovers and aims the torch at the mouse (or sweeps it over the wreck)
  local d = self.diver
  d.y = 330 + math.sin(t * 0.8) * 14
  d.x = 860 + math.sin(t * 0.3) * 30
  local mx, my = require("core.view").mouse()
  local target
  if mx and love.window.hasMouseFocus() then
    target = math.atan2(my - d.y, mx - d.x)
  else
    target = 2.55 + math.sin(t * 0.5) * 0.3
  end
  local diff = (target - d.aim + math.pi) % (math.pi * 2) - math.pi
  d.aim = d.aim + diff * math.min(1, dt * 3)
  if love.math.random() < dt * 7 then
    self.bubbles[#self.bubbles + 1] = { x = d.x - 4, y = d.y - 22, r = 2 + love.math.random() * 5, p = love.math.random() * 6 }
  end
  for i = #self.bubbles, 1, -1 do
    local b = self.bubbles[i]
    b.y = b.y - (50 + b.r * 6) * dt
    b.x = b.x + math.sin(t * 4 + b.p) * 14 * dt
    if b.y < -10 then table.remove(self.bubbles, i) end
  end
end

function S:drawShark()
  local t = self.t
  local sh = self.shark
  local d = 0.42
  local back, belly = fog("#3a4a5c", d), fog("#b8c4cc", d)
  lg.push()
  lg.translate(sh.x, sh.y)
  lg.scale(sh.dir * 1.25, 1.25)
  -- spine from nose (x = 150) to tail (x = -170); the wave grows toward the tail
  local N = 16
  local top, bot, mid = {}, {}, {}
  for i = 0, N do
    local u = i / N
    local x = 150 - u * 320
    local wave = math.sin(t * 3.2 - u * 4.2) * 16 * u * u
    local girth = math.sin(math.min(1, u * 1.15 + 0.04) * math.pi) ^ 0.6 * 34 * (1 - u * 0.35) + 2
    top[#top + 1] = { x, wave - girth }
    bot[#bot + 1] = { x, wave + girth * 0.82 }
    mid[#mid + 1] = { x, wave }
  end
  -- tail fin (tall upper lobe) behind the body
  local tx, ty = mid[N + 1][1], mid[N + 1][2]
  local sw = math.sin(t * 3.2 - 4.2) * 14
  lg.setColor(back)
  lg.polygon("fill", tx + 14, ty - 4, tx - 60, ty - 78 + sw, tx - 26, ty + sw * 0.4, tx - 46, ty + 44 + sw, tx + 14, ty + 6)
  -- body: quads between spine samples, dark back and pale belly
  for i = 1, N do
    local a, b, c, e = top[i], top[i + 1], mid[i + 1], mid[i]
    lg.setColor(back)
    lg.polygon("fill", a[1], a[2], b[1], b[2], c[1], c[2] + 6, e[1], e[2] + 6)
    a, b = bot[i], bot[i + 1]
    lg.setColor(belly)
    lg.polygon("fill", e[1], e[2] + 6, c[1], c[2] + 6, b[1], b[2], a[1], a[2])
  end
  -- dorsal and pectoral fins
  local m = mid[6]
  lg.setColor(back)
  lg.polygon("fill", m[1] + 30, m[2] - 30, m[1] - 20, m[2] - 86, m[1] - 40, m[2] - 28)
  local pf = mid[5]
  lg.setColor(gfx.mix(back, { 0, 0, 0 }, 0.2))
  lg.polygon("fill", pf[1] + 16, pf[2] + 20, pf[1] - 50, pf[2] + 70 + math.sin(t * 1.6) * 6, pf[1] - 30, pf[2] + 22)
  -- gills, eye, mouth
  lg.setColor(gfx.mix(back, { 0, 0, 0 }, 0.4))
  lg.setLineWidth(2)
  for k = 0, 3 do lg.line(82 - k * 9, -12, 78 - k * 9, 10) end
  lg.line(142, 12, 112, 20, 100, 14)
  lg.setColor(0.03, 0.04, 0.06)
  lg.circle("fill", 118, -6, 4)
  lg.pop()
end

function S:drawShip()
  local t = self.t
  local function col(hex, d) return fog(hex, 0.18 + (d or 0)) end
  lg.push()
  lg.translate(560, FLOOR + 6)
  lg.rotate(-0.13)
  -- masts and rigging behind the hull
  lg.setColor(col("#4a3a2a", 0.1))
  lg.polygon("fill", -40, -150, -26, -150, -30, -470, -38, -470)          -- main mast (whole)
  lg.polygon("fill", 150, -170, 164, -170, 160, -330, 152, -322)          -- fore mast, snapped
  lg.polygon("fill", -230, -190, -218, -190, -221, -360, -228, -360)      -- mizzen
  lg.rectangle("fill", -120, -400, 170, 8)
  lg.rectangle("fill", -96, -300, 130, 7)
  lg.rectangle("fill", -270, -320, 96, 6)
  -- crow's nest
  lg.polygon("fill", -52, -420, -14, -420, -20, -440, -46, -440)
  -- tattered sails: ragged strips that wave
  for i, sail in ipairs({ { -116, -392, 150, 84 }, { -92, -293, 118, 70 }, { -266, -314, 84, 80 } }) do
    local x, y, w, h = sail[1], sail[2], sail[3], sail[4]
    local n = 7
    for k = 0, n - 1 do
      local len = h * (0.35 + gfx.hash(k * 3 + i) * 0.65)
      local sway = math.sin(t * 1.1 + k * 0.8 + i) * 9
      lg.setColor(col(k % 2 == 0 and "#c8c0a0" or "#a8a488", 0.16))
      lg.polygon("fill", x + k * w / n, y, x + (k + 1) * w / n, y, x + (k + 0.8) * w / n + sway, y + len, x + (k + 0.3) * w / n + sway, y + len * 0.86)
    end
  end
  -- hanging ropes
  lg.setColor(col("#3a3024", 0.1))
  lg.setLineWidth(2)
  for k = 0, 5 do
    local x1, x2 = -220 + k * 76, -180 + k * 70
    local pts = {}
    for i = 0, 10 do
      local u = i / 10
      pts[#pts + 1] = gfx.lerp(x1, x2, u)
      pts[#pts + 1] = gfx.lerp(-360 + k * 20, -170, u) + math.sin(u * math.pi) * 34 + math.sin(t + k) * 3 * math.sin(u * math.pi)
    end
    lg.line(pts)
  end
  -- hull: bow to the right, raised stern castle to the left
  local hull = { -330, -250, -310, -256, -250, -200, -110, -176, 120, -176, 250, -196, 330, -236, 388, -248,
    350, -160, 300, -80, 220, -24, 80, 6, -120, 8, -250, -20, -310, -90, -336, -170 }
  lg.setColor(col("#5a4632"))
  gfx.fillConcave(hull)
  -- lower hull darker and greener (weed and shadow)
  lg.setColor(col("#3a4a3a", 0.06))
  gfx.fillConcave({ -326, -130, 340, -130, 300, -80, 220, -24, 80, 6, -120, 8, -250, -20, -310, -90 })
  -- planking
  lg.setColor(col("#2e2418", 0.05))
  lg.setLineWidth(2)
  for k = 0, 6 do
    local y = -164 + k * 24
    local inset = k * k * 2.6
    lg.line(-322 + inset * 0.6, y, 350 - inset * 1.6 - k * 6, y)
  end
  for k = 0, 14 do
    local x = -300 + k * 44
    lg.line(x, -168 + (k % 2) * 24, x, -144 + (k % 2) * 24)
  end
  -- gunwale and stern castle rail
  lg.setColor(col("#7a6244"))
  lg.polygon("fill", -250, -200, -110, -176, 120, -176, 250, -196, 330, -236, 388, -248, 384, -238, 328, -224, 250, -186, 120, -166, -110, -166, -250, -190)
  lg.polygon("fill", -334, -252, -250, -202, -250, -190, -336, -240)
  for k = 0, 5 do lg.rectangle("fill", -326 + k * 14, -270 + k * 8, 4, 22) end
  -- stern windows, faintly lit from inside
  for k = 0, 2 do
    lg.setColor(col("#1a1410"))
    lg.rectangle("fill", -306 + k * 22, -204 + k * 6, 14, 20, 3)
    lg.setColor(1, 0.8, 0.4, 0.14 + 0.06 * math.sin(t * 2 + k))
    lg.rectangle("fill", -304 + k * 22, -202 + k * 6, 10, 16, 2)
  end
  -- bowsprit and a figurehead
  lg.setColor(col("#4a3a2a"))
  lg.polygon("fill", 372, -250, 384, -240, 470, -292, 466, -298)
  lg.setColor(col("#c8a84a", 0.1))
  lg.polygon("fill", 380, -236, 400, -244, 396, -206, 378, -196)
  -- the breach: black hole with ribs across it and treasure inside
  local hole = { -60, -130, 20, -150, 120, -128, 150, -70, 90, -24, -10, -18, -80, -60 }
  lg.setColor(0.02, 0.05, 0.08)
  gfx.fillConcave(hole)
  -- chest and coins glint in there
  lg.setColor(col("#6a4a22"))
  lg.rectangle("fill", 10, -70, 60, 36, 4)
  lg.setColor(col("#c8a030"))
  lg.rectangle("fill", 10, -76, 60, 10, 4)
  lg.rectangle("fill", 36, -66, 8, 12)
  for k = 0, 6 do
    lg.setColor(1, 0.85, 0.3)
    lg.ellipse("fill", 4 + k * 12 + gfx.hash(k) * 6, -30 - gfx.hash(k + 3) * 6, 5, 2.5)
  end
  lg.setBlendMode("add")
  lg.setColor(1, 0.8, 0.3, 0.35 + 0.2 * math.sin(t * 2.5))
  lg.draw(self.glow, 40, -58, 0, 1.3, 0.9, 64, 64)
  for k = 0, 3 do
    local a = (t * 0.8 + k * 1.7) % 1
    lg.setColor(1, 1, 0.8, math.sin(a * math.pi))
    local gx, gy = 14 + k * 16, -74 + (k % 2) * 34
    lg.line(gx - 6, gy, gx + 6, gy)
    lg.line(gx, gy - 6, gx, gy + 6)
  end
  lg.setBlendMode("alpha")
  lg.setColor(col("#4a3a28"))
  lg.setLineWidth(9)
  for k = 0, 3 do
    lg.line(love.math.newBezierCurve(-40 + k * 50, -144 + math.abs(k - 1.5) * 6, -30 + k * 50, -80, -36 + k * 46, -18):render(3))
  end
  -- jagged plank ends around the breach
  lg.setColor(col("#6a5238"))
  for i = 1, #hole, 2 do
    local x, y = hole[i], hole[i + 1]
    local dx, dy = x - 40, y + 84
    local len = math.sqrt(dx * dx + dy * dy)
    lg.polygon("fill", x - dy / len * 9, y + dx / len * 9, x + dy / len * 9, y - dx / len * 9, x - dx / len * 22, y - dy / len * 22)
  end
  -- barnacles and weed on the hull
  for k = 0, 40 do
    local x, y = -300 + gfx.hash(k) * 620, -120 + gfx.hash(k + 50) * 110
    lg.setColor(col(k % 3 == 0 and "#8fa88a" or "#4f7a5a", 0.05))
    lg.circle("fill", x, y, 2 + gfx.hash(k + 9) * 4)
  end
  lg.pop()
  -- anchor and chain lying in the sand
  lg.setColor(fog("#2e3a40", 0.15))
  lg.setLineWidth(7)
  lg.arc("line", "open", 1010, FLOOR + 18, 34, 0.2, math.pi - 0.2)
  lg.line(1010, FLOOR - 40, 1010, FLOOR + 52)
  lg.line(990, FLOOR - 30, 1030, FLOOR - 30)
  lg.circle("line", 1010, FLOOR - 50, 9)
  lg.setLineWidth(3)
  for k = 0, 12 do
    lg.ellipse("line", 1000 - k * 12, FLOOR - 58 - math.sin(k * 0.5) * 26 - k * 8, 6, 4)
  end
end

function S:drawKelp(k, front)
  local t = self.t
  local c1 = fog("#2f7a4a", k.d)
  local c2 = fog("#5aa85a", k.d)
  local pts = {}
  local n = 14
  for i = 0, n do
    local u = i / n
    pts[#pts + 1] = k.x + math.sin(t * 0.9 + k.p - u * 2.6) * 34 * u
    pts[#pts + 1] = FLOOR + 30 - u * k.h
  end
  lg.setColor(c1)
  lg.setLineWidth(k.w * (front and 1.3 or 1))
  lg.line(pts)
  lg.setColor(c2)
  lg.setLineWidth(k.w * 0.3)
  lg.line(pts)
  -- blades alternate left and right
  for i = 2, n, 1 do
    local x, y = pts[i * 2 + 1], pts[i * 2 + 2]
    local dir = (i % 2 == 0) and 1 or -1
    local sw = math.sin(t * 1.2 + k.p + i) * 6
    lg.setColor(i % 3 == 0 and c2 or c1)
    lg.polygon("fill", x, y, x + dir * 26, y - 10 + sw, x + dir * 44, y + 6 + sw, x + dir * 20, y + 8)
  end
end

function S:drawDiver()
  local t = self.t
  local d = self.diver
  -- torch cone first, so it lights what's behind the diver
  lg.setBlendMode("add")
  lg.push()
  lg.translate(d.x - 18, d.y + 6)
  lg.rotate(d.aim)
  lg.scale(460, 460)
  lg.setColor(1, 1, 1, 0.8)
  lg.draw(self.torch)
  lg.pop()
  lg.setBlendMode("alpha")
  lg.push()
  lg.translate(d.x, d.y)
  lg.rotate(0.25 + math.sin(t * 0.8) * 0.05)
  local kick = math.sin(t * 3)
  -- fins and legs
  lg.setColor(gfx.hex("#16222e"))
  lg.setLineWidth(9)
  lg.line(34, 2, 70, 6 + kick * 12)
  lg.line(34, 8, 68, 16 - kick * 12)
  lg.setColor(gfx.hex("#e2c22a"))
  lg.polygon("fill", 68, 0 + kick * 12, 104, -8 + kick * 18, 104, 14 + kick * 18, 70, 12 + kick * 12)
  lg.polygon("fill", 66, 10 - kick * 12, 102, 6 - kick * 18, 102, 28 - kick * 18, 68, 22 - kick * 12)
  -- tank, body, head with mask
  lg.setColor(gfx.hex("#e2c22a"))
  lg.rectangle("fill", -6, -22, 40, 13, 6)
  lg.setColor(gfx.hex("#16222e"))
  lg.rectangle("fill", -18, -12, 58, 24, 11)
  lg.setColor(gfx.hex("#e23a2a"))
  lg.rectangle("fill", 6, -12, 6, 24)
  lg.setColor(gfx.hex("#16222e"))
  lg.circle("fill", -26, -4, 13)
  lg.setColor(gfx.hex("#7fd8f0"))
  lg.ellipse("fill", -33, -3, 6, 8)
  -- arm holding the torch
  lg.setColor(gfx.hex("#16222e"))
  lg.setLineWidth(7)
  lg.line(-8, 6, -24, 14)
  lg.setColor(gfx.hex("#c8c8c8"))
  lg.rectangle("fill", -34, 10, 14, 8, 2)
  lg.pop()
  lg.setBlendMode("add")
  lg.setColor(1, 0.97, 0.8, 0.9)
  lg.draw(self.glow, d.x - 20, d.y + 6, 0, 0.5, 0.5, 64, 64)
  lg.setBlendMode("alpha")
end

function S:draw()
  local t = self.t
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.bg)
    -- the surface, seen from below: a bright rippling band
    for k = 0, 30 do
      lg.setColor(0.8, 0.97, 1, 0.25 + 0.2 * math.sin(t * 1.3 + k * 1.1))
      lg.ellipse("fill", k * 46 + math.sin(t * 0.6 + k) * 20, 4 + math.sin(t + k * 2) * 4, 40, 7)
    end
    -- light shafts
    lg.setBlendMode("add")
    for k = 0, 8 do
      lg.push()
      lg.translate(40 + k * 150 + math.sin(t * 0.25 + k * 1.3) * 40, -10)
      lg.shear(0.3, 0)
      lg.scale(50 + (k % 3) * 30, 560)
      lg.setColor(1, 1, 1, 0.55 + 0.35 * math.sin(t * 0.6 + k * 2.1))
      lg.draw(self.shaft)
      lg.pop()
    end
    lg.setBlendMode("alpha")
    -- far rock arches, nearly lost in the blue
    lg.setColor(fog("#1a3a4a", 0.72))
    lg.polygon("fill", -20, 720, 0, 420, 90, 350, 190, 390, 250, 520, 300, 720)
    lg.polygon("fill", 1000, 720, 1040, 470, 1130, 380, 1230, 400, 1300, 500, 1300, 720)
    lg.setColor(fog("#1a3a4a", 0.6))
    lg.polygon("fill", 380, 720, 420, 560, 520, 530, 600, 580, 640, 720)
    self:drawShark()
    for _, k in ipairs(self.kelp) do if k.d > 0.25 then self:drawKelp(k, false) end end
    -- sand
    lg.setColor(fog("#c8b88a", 0.3))
    gfx.fillRidge(self.sand, 720)
    lg.setColor(fog("#e8dcb0", 0.3))
    lg.setLineWidth(3)
    lg.line(self.sand)
    for k = 0, 22 do
      local x = k * 60 + 10
      lg.setColor(fog("#a8986a", 0.3))
      lg.setLineWidth(2)
      lg.line(love.math.newBezierCurve(x, FLOOR + 50 + (k % 3) * 22, x + 30, FLOOR + 42 + (k % 3) * 22, x + 60, FLOOR + 52 + (k % 3) * 22):render(2))
    end
    self:drawShip()
    -- a school of small fish circling the main mast
    for _, f in ipairs(self.fishes) do
      local a = f.a + t * f.v
      local x, y = 520 + math.cos(a) * f.r * 1.7, 250 + math.sin(a) * f.r * 0.5 + f.y
      local dir = (-math.sin(a) > 0) and 1 or -1
      local depth = (math.sin(a) + 1) / 2
      lg.setColor(fog(({ "#ffb83a", "#ff7a4a", "#f2f2f2" })[f.col + 1], 0.1 + (1 - depth) * 0.3))
      lg.ellipse("fill", x, y, 8, 3.6)
      lg.polygon("fill", x - dir * 7, y, x - dir * 14, y - 4, x - dir * 14, y + 4)
    end
    self:drawDiver()
    for _, b in ipairs(self.bubbles) do
      lg.setColor(0.85, 0.97, 1, 0.6)
      lg.setLineWidth(1.5)
      lg.circle("line", b.x, b.y, b.r)
      lg.setColor(1, 1, 1, 0.7)
      lg.circle("fill", b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.2)
    end
    for _, k in ipairs(self.kelp) do if k.d <= 0.25 then self:drawKelp(k, true) end end
    -- marine snow
    for _, s in ipairs(self.snow) do
      lg.setColor(0.9, 0.97, 1, 0.22 + 0.2 * math.sin(t + s.p))
      lg.circle("fill", s.x, s.y, s.s)
    end
  end)
end

return S
