-- CARTOON, scene 3: a pirate ship off a treasure island.
--
-- The sea is the trick here: five rows of scalloped waves, each a strip of half
-- circles. Rows slide sideways at different speeds and bob up and down out of phase;
-- the ship is drawn BETWEEN two rows, so its hull looks like it sits in the water.
-- The ship itself rocks around its keel with one rotate() call. Click to fire the
-- cannon: the ball flies on a simple ballistic arc and ends in a splash.

local gfx = require("core.gfx")
local flux = require("flux")
local Draft = require("draft")

local lg = love.graphics
local OUT = { gfx.hex("#1f2a44") }
local LW = 5

local S = {
  title = "Cartoon",
  subtitle = "Pirate Cove",
  blurb = "A rocking pirate ship sandwiched between rows of scalloped waves, a treasure island, a parrot and a cannon you can fire.",
  techniques = {
    "Sea = rows of half-circle scallops sliding at different speeds (parallax)",
    "The ship is drawn between two wave rows, so the hull sinks into the water",
    "Rocking: one rotate() around the keel, driven by two sine waves",
    "Sails bulge with a Bezier edge; the flag is a wavy polygon",
    "Cannonball on a ballistic arc; smoke puffs and a comic splash",
  },
  libs = {
    "flux: cannon recoil, smoke puffs and the splash burst",
    "draft: the star on the flag and sparkles on the treasure",
  },
  genres = { "Kids' adventure and party games", "Casual naval battles", "Fishing and sailing minigames", "Treasure-hunt puzzle games" },
  controls = "click to fire the cannon.",
  warmup = 3,
}

local draft = Draft("fill")

local function outlined(drawShape, fill, width)
  lg.setColor(OUT)
  lg.setLineWidth((width or LW) * 2)
  lg.setLineJoin("bevel")
  drawShape("line")
  lg.setColor(fill)
  drawShape("fill")
end

local function waveRow(y, r, offset, color, t, phase)
  local bob = math.sin(t * 1.4 + phase) * 6
  local pts = {}
  local x0 = -r * 2 + (offset % (r * 2))
  for x = x0, 1280 + r * 2, r * 2 do
    for k = 0, 8 do
      local a = math.pi + k / 8 * math.pi
      pts[#pts + 1] = x + r + math.cos(a) * r
      pts[#pts + 1] = y + bob + math.sin(a) * r * 0.55
    end
  end
  lg.setColor(color)
  gfx.fillRidge(pts, 720)
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  lg.setLineJoin("bevel")
  lg.line(pts)
  -- foam highlight inside each scallop
  lg.setColor(1, 1, 1, 0.55)
  lg.setLineWidth(4)
  for x = x0, 1280 + r * 2, r * 2 do
    lg.arc("line", "open", x + r, y + bob + 10, r * 0.55, math.pi * 1.15, math.pi * 1.6)
  end
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  self.sky = gfx.vgradient(1280, 720, { { 0, gfx.rgb("#38b6ff") }, { 0.6, gfx.rgb("#aee9ff") }, { 1, gfx.rgb("#e9fbff") } })
  self.clouds = { { x = 200, y = 110, s = 1 }, { x = 760, y = 70, s = 0.7 }, { x = 1100, y = 150, s = 0.85 } }
  self.cannon = { recoil = 0 }
  self.ball = nil
  self.puffs = {}
  self.splash = { scale = 0, alpha = 0, x = 0 }
  self.next = 2.2
  self.font = lg.newFont(40)
end

function S:fire()
  if self.ball then return end
  local c = self.cannon
  c.recoil = 14
  self.flux:to(c, 0.5, { recoil = 0 }):ease("elasticout")
  local sx, sy = self:shipPos()
  self.ball = { x = sx + 150, y = sy - 96, vx = 430, vy = -260 }
  for k = 1, 5 do
    local p = { x = sx + 165 + k * 6, y = sy - 100, r = 8, a = 1 }
    self.puffs[#self.puffs + 1] = p
    self.flux:to(p, 0.9, { r = 26 + k * 6, a = 0, y = p.y - 30 - k * 8, x = p.x + k * 14 }):ease("quadout")
  end
end

function S:mousepressed() self:fire() end

function S:shipPos()
  return 470 + math.sin(self.t * 0.4) * 30, 470 + math.sin(self.t * 1.4 + 1) * 8
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  for _, c in ipairs(self.clouds) do
    c.x = c.x + 10 * c.s * dt
    if c.x > 1450 then c.x = -200 end
  end
  self.next = self.next - dt
  if self.next <= 0 then self.next = 6; self:fire() end
  local b = self.ball
  if b then
    b.x, b.y, b.vy = b.x + b.vx * dt, b.y + b.vy * dt, b.vy + 520 * dt
    if b.y > 560 then
      local s = self.splash
      s.x, s.scale, s.alpha = b.x, 0.2, 1
      self.flux:to(s, 0.35, { scale = 1 }):ease("backout"):after(s, 0.4, { alpha = 0 }):delay(0.3)
      self.ball = nil
    end
  end
  for i = #self.puffs, 1, -1 do if self.puffs[i].a <= 0.01 then table.remove(self.puffs, i) end end
end

local function cloud(c)
  local parts = { { -60, 8, 38 }, { -20, -16, 50 }, { 34, -6, 44 }, { 74, 12, 30 } }
  lg.setColor(OUT)
  for _, p in ipairs(parts) do lg.circle("fill", c.x + p[1] * c.s, c.y + p[2] * c.s, p[3] * c.s + LW) end
  lg.setColor(1, 1, 1)
  for _, p in ipairs(parts) do lg.circle("fill", c.x + p[1] * c.s, c.y + p[2] * c.s, p[3] * c.s) end
end

function S:drawIsland()
  local x, y = 1040, 478
  outlined(function(mode) lg.ellipse(mode, x, y + 30, 210, 62) end, { gfx.hex("#ffd98a") })
  lg.setColor(gfx.hex("#ffe9b3"))
  lg.ellipse("fill", x - 30, y + 12, 120, 22)
  -- palm: curved trunk + fronds
  local sway = math.sin(self.t * 1.1) * 8
  local trunk = love.math.newBezierCurve(x + 60, y, x + 90, y - 100, x + 50 + sway, y - 210):render(4)
  lg.setColor(OUT)
  lg.setLineWidth(30)
  lg.line(trunk)
  lg.setColor(gfx.hex("#a8703a"))
  lg.setLineWidth(20)
  lg.line(trunk)
  local tx, ty = x + 50 + sway, y - 210
  for k = 0, 5 do
    local a = -math.pi * 0.95 + k * (math.pi * 0.9 / 5) + math.sin(self.t * 1.3 + k) * 0.05
    local ex, ey = tx + math.cos(a) * 130, ty + math.sin(a) * 60 + 50
    local mx, my = tx + math.cos(a) * 70, ty + math.sin(a) * 80 - 30
    local leaf = love.math.newBezierCurve(tx, ty, mx, my, ex, ey):render(4)
    lg.setColor(OUT)
    lg.setLineWidth(26)
    lg.line(leaf)
    lg.setColor(gfx.hex(k % 2 == 0 and "#3fbf5a" or "#2fa04a"))
    lg.setLineWidth(16)
    lg.line(leaf)
  end
  outlined(function(mode) lg.circle(mode, tx - 8, ty + 14, 12) end, { gfx.hex("#7a4a22") })
  outlined(function(mode) lg.circle(mode, tx + 12, ty + 18, 12) end, { gfx.hex("#7a4a22") })
  -- treasure chest, lid open, coins and sparkles
  local cx, cy = x - 70, y + 4
  outlined(function(mode) lg.rectangle(mode, cx - 42, cy - 26, 84, 46, 6) end, { gfx.hex("#9b5a2a") })
  outlined(function(mode) lg.polygon(mode, cx - 44, cy - 28, cx - 34, cy - 64, cx + 50, cy - 70, cx + 44, cy - 28) end, { gfx.hex("#b86e34") })
  lg.setColor(gfx.hex("#ffd23f"))
  for k = 0, 5 do lg.circle("fill", cx - 30 + k * 12, cy - 28 - (k % 2) * 6, 9) end
  lg.setColor(OUT)
  lg.setLineWidth(3)
  for k = 0, 5 do lg.circle("line", cx - 30 + k * 12, cy - 28 - (k % 2) * 6, 9) end
  lg.setColor(gfx.hex("#ffd23f"))
  lg.rectangle("fill", cx - 6, cy - 12, 12, 16, 3)
  for k = 0, 2 do
    local s = (math.sin(self.t * 4 + k * 2) * 0.5 + 0.5) * 16 + 4
    lg.setColor(1, 1, 1, 0.95)
    draft:star(cx - 26 + k * 28, cy - 54 - k * 8, s * 2, s * 0.6, 4, 0, "fill")
  end
end

function S:drawShip()
  local x, y = self:shipPos()
  local rock = math.sin(self.t * 1.4) * 0.05 + math.sin(self.t * 0.6) * 0.02
  lg.push()
  lg.translate(x, y)
  lg.rotate(rock)
  -- masts
  for _, mx in ipairs({ -70, 50 }) do
    outlined(function(mode) lg.rectangle(mode, mx - 6, -330, 12, 260) end, { gfx.hex("#8a5a2e") })
  end
  -- sails: left edge straight on the mast, right edge bulging in the wind
  local bulge = 26 + math.sin(self.t * 2) * 6
  for i, sail in ipairs({ { -70, -310, 150, 110 }, { -70, -190, 170, 100 }, { 50, -300, 130, 100 }, { 50, -190, 150, 96 } }) do
    local sx, sy, w, h = sail[1] + 8, sail[2], sail[3] - 30, sail[4]
    local edge = love.math.newBezierCurve(sx + w, sy, sx + w + bulge, sy + h / 2, sx + w, sy + h):render(3)
    local poly = { sx, sy }
    for k = 1, #edge do poly[#poly + 1] = edge[k] end
    poly[#poly + 1] = sx; poly[#poly + 1] = sy + h
    outlined(function(mode) if mode == "fill" then gfx.fillConcave(poly) else lg.polygon("line", poly) end end, { gfx.hex("#fff7e6") })
    lg.setColor(gfx.hex("#ff6b6b"))
    if i % 2 == 1 then lg.rectangle("fill", sx + 4, sy + h * 0.4, w - 6, h * 0.22) end
  end
  -- flag: a wavy polygon with a star
  local flag = {}
  for k = 0, 6 do flag[#flag + 1] = -64 + k * 10; flag[#flag + 1] = -356 + math.sin(self.t * 6 + k * 0.9) * 4 end
  for k = 6, 0, -1 do flag[#flag + 1] = -64 + k * 10; flag[#flag + 1] = -326 + math.sin(self.t * 6 + k * 0.9) * 4 end
  outlined(function(mode) if mode == "fill" then gfx.fillConcave(flag) else lg.polygon("line", flag) end end, { gfx.hex("#2b2b3d") }, 4)
  lg.setColor(gfx.hex("#ffd23f"))
  draft:star(-34, -341, 20, 8, 5, -math.pi / 2, "fill")
  -- hull: a banana shape with a raised stern, plank lines, portholes
  local hull = { -190, -80, -170, -110, -120, -110, -110, -74, 150, -74, 196, -104, 178, -30, 150, 20, -150, 20, -180, -20 }
  outlined(function(mode) if mode == "fill" then gfx.fillConcave(hull) else lg.polygon("line", hull) end end, { gfx.hex("#a8602e") })
  lg.setColor(gfx.hex("#c97a3d"))
  lg.rectangle("fill", -178, -74, 340, 12)
  lg.setColor(gfx.hex("#7a4420"))
  lg.setLineWidth(3)
  lg.line(-176, -40, 172, -40)
  lg.line(-166, -12, 160, -12)
  for k = 0, 3 do
    outlined(function(mode) lg.circle(mode, -100 + k * 62, -26, 11) end, { gfx.hex("#8fd3ff") }, 4)
  end
  -- cannon on deck, recoiling
  local c = self.cannon
  outlined(function(mode) lg.rectangle(mode, 96 - c.recoil, -108, 64, 22, 8) end, { gfx.hex("#3d4257") })
  outlined(function(mode) lg.circle(mode, 104 - c.recoil, -80, 13) end, { gfx.hex("#6b4a2a") }, 4)
  -- the captain: a round fellow with a big hat, and a parrot on the stern rail
  local bob = math.sin(self.t * 3) * 2
  outlined(function(mode) lg.rectangle(mode, -24, -136 + bob, 40, 54, 12) end, { gfx.hex("#e63946") })
  outlined(function(mode) lg.circle(mode, -4, -152 + bob, 20) end, { gfx.hex("#f2c9a0") })
  outlined(function(mode) lg.polygon(mode, -40, -164 + bob, 32, -164 + bob, 16, -196 + bob, -24, -196 + bob) end, { gfx.hex("#2b2b3d") })
  lg.setColor(gfx.hex("#ffd23f"))
  lg.rectangle("fill", -30, -170 + bob, 52, 6)
  lg.setColor(OUT)
  lg.circle("fill", 4, -152 + bob, 3)
  lg.rectangle("fill", -18, -158 + bob, 12, 8)        -- eyepatch
  lg.setLineWidth(3)
  lg.arc("line", "open", -2, -144 + bob, 8, 0.3, math.pi - 0.3)
  local px, py = -150, -128 + math.sin(self.t * 5) * 2
  outlined(function(mode) lg.ellipse(mode, px, py, 13, 18) end, { gfx.hex("#3fbf5a") }, 4)
  outlined(function(mode) lg.circle(mode, px + 2, py - 20, 10) end, { gfx.hex("#ff5d5d") }, 4)
  lg.setColor(gfx.hex("#ffd23f"))
  lg.polygon("fill", px + 10, py - 22, px + 22, py - 18, px + 10, py - 14)
  lg.setColor(OUT)
  lg.circle("fill", px + 4, py - 22, 2)
  lg.pop()
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  outlined(function(mode) lg.circle(mode, 150, 120, 64) end, { gfx.hex("#ffe873") })
  for _, c in ipairs(self.clouds) do cloud(c) end
  -- seagulls
  for k = 0, 2 do
    local gx = (self.t * 40 + k * 300) % 1500 - 100
    local gy = 190 + k * 30 + math.sin(self.t * 2 + k) * 10
    local f = math.sin(self.t * 8 + k) * 8
    lg.setColor(OUT)
    lg.setLineWidth(5)
    lg.line(gx - 16, gy - f, gx, gy, gx + 16, gy - f)
  end
  local t = self.t
  waveRow(440, 46, t * 14, { gfx.hex("#5ad1e6") }, t, 0)
  waveRow(470, 54, -t * 22, { gfx.hex("#38b6d9") }, t, 1.3)
  self:drawIsland()
  self:drawShip()
  for _, p in ipairs(self.puffs) do
    lg.setColor(OUT[1], OUT[2], OUT[3], p.a)
    lg.circle("fill", p.x, p.y, p.r + 4)
    lg.setColor(1, 1, 1, p.a)
    lg.circle("fill", p.x, p.y, p.r)
  end
  if self.ball then outlined(function(mode) lg.circle(mode, self.ball.x, self.ball.y, 11) end, { gfx.hex("#3d4257") }, 4) end
  waveRow(520, 62, t * 34, { gfx.hex("#2a9fd0") }, t, 2.4)
  -- shark fin cruising between the front rows
  local fx = 1280 - (t * 60) % 1500
  outlined(function(mode) lg.polygon(mode, fx - 26, 590, fx + 8, 532, fx + 30, 590) end, { gfx.hex("#6b7a99") })
  local s = self.splash
  if s.alpha > 0.01 then
    lg.push()
    lg.translate(s.x, 540)
    lg.scale(s.scale)
    local pts = draft:star(0, 0, 220, 120, 10, 0, false)
    lg.setColor(OUT[1], OUT[2], OUT[3], s.alpha)
    lg.setLineWidth(LW * 2)
    lg.polygon("line", pts)
    lg.setColor(1, 1, 1, s.alpha)
    draft:polygon(pts, "fill")
    lg.setFont(self.font)
    gfx.outlinedText("SPLOOSH!", -100, -26, { 0.2, 0.6, 0.9, s.alpha }, { OUT[1], OUT[2], OUT[3], s.alpha }, 3)
    lg.pop()
  end
  waveRow(590, 74, -t * 48, { gfx.hex("#1f7fb8") }, t, 3.7)
  waveRow(660, 90, t * 64, { gfx.hex("#165f96") }, t, 5)
end

return S
