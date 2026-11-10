-- PAPERCRAFT, scene 2: a toy-theatre ocean.
--
-- Old paper theatres made the sea from rows of scalloped card that slid left and
-- right on sticks. Same here: five strips whose top edge is a row of pointed crests
-- (|sin|), each sliding and bobbing out of step with its neighbours. Anything placed
-- *between* two strips is automatically half-hidden by the one in front: that is how
-- the whale breaches and the boat sits in the water, with no masking at all.
-- Things in the sky hang from threads and sway like a mobile.

local gfx = require("core.gfx")
local kit = require("core.paperkit")
local view = require("core.view")

local lg = love.graphics

local S = {
  title = "Papercraft",
  subtitle = "Toy-Theatre Ocean",
  blurb = "A paper sea of sliding scalloped strips, a breaching whale, a bobbing sailboat, a lighthouse, and a sun and clouds hanging from threads.",
  techniques = {
    "Wave strip: top edge = base + |sin|, giving rounded troughs and pointed crests",
    "Strips slide and bob out of phase, like card waves on sticks",
    "Free occlusion: whale, boat and fish are drawn between strips",
    "Mobile physics: hanging pieces swing as damped pendulums",
    "Every sheet: soft offset shadow, fill, lighter cut edge, fibre texture",
    "A shadow-box frame closes the stage",
  },
  libs = {
    "vivid: lighter cut edges and darker folds (through core/paperkit.lua)",
  },
  genres = { "Storybook adventures", "Toy-like puzzle games", "Children's games and e-books", "Level-select maps and title screens" },
  controls = "move the mouse left/right to push the waves; click to make the whale jump.",
  warmup = 3.3,
}

local function c(h) return { gfx.hex(h) } end

local STRIPS = {
  { y = 400, amp = 22, period = 120, col = "#bfe0ee", speed = 0.5, slide = 40 },
  { y = 450, amp = 26, period = 150, col = "#8fc6e2", speed = -0.62, slide = 54 },
  { y = 510, amp = 30, period = 180, col = "#5fa4d2", speed = 0.74, slide = 60 },
  { y = 580, amp = 34, period = 210, col = "#3f7fb8", speed = -0.86, slide = 70 },
  { y = 650, amp = 38, period = 250, col = "#2a5a96", speed = 1.0, slide = 80 },
}

function S:load()
  self.t = 0
  self.fibre = kit.fibre()
  self.push = 0
  self.whale = { u = 1.37 }
  self.swing = {}
  for i = 1, 6 do self.swing[i] = { a = 0.1 * ((i % 2) * 2 - 1), v = 0 } end
  self.fish = { u = 0.4 }
end

function S:mousepressed()
  if self.whale.u > 1 then self.whale.u = 0 end
end

function S:update(dt)
  self.t = self.t + dt
  local mx = view.mouse()
  local target = 0
  if mx and love.window.hasMouseFocus() then target = (mx - 640) / 640 end
  self.push = self.push + (target - self.push) * math.min(1, dt * 3)
  -- hanging pieces: pendulums nudged by the "wind"
  for i, s in ipairs(self.swing) do
    local wind = math.sin(self.t * 0.7 + i * 1.7) * 0.5 + self.push * 0.8
    s.v = s.v + (-s.a * 6 + wind * 0.6) * dt
    s.v = s.v * (1 - dt * 0.6)
    s.a = s.a + s.v * dt
  end
  self.whale.u = self.whale.u + dt / 3.2
  if self.whale.u > 1.9 then self.whale.u = 0 end
  self.fish.u = (self.fish.u + dt / 2.2) % 1.6
end

function S:strip(i)
  local st = STRIPS[i]
  local off = math.sin(self.t * st.speed + i) * st.slide + self.push * st.slide * 1.2
  local bob = math.sin(self.t * 1.1 + i * 1.3) * 5
  local pts = {}
  for x = -100, 1380, 6 do
    pts[#pts + 1] = x
    pts[#pts + 1] = st.y + bob + math.abs(math.sin((x + off) * math.pi / st.period)) * st.amp - st.amp
  end
  local shape, edge = kit.ridgeShape(pts, 760)
  kit.cutout(shape, c(st.col), edge, 1 + i * 0.12)
  -- little foam curls stuck on some crests
  for k = -1, 9 do
    local cx = k * st.period - off
    if (k + i) % 2 == 0 and cx > -40 and cx < 1320 then
      lg.setColor(0.97, 0.98, 1)
      lg.arc("fill", cx + 6, st.y + bob - st.amp + 5, 9, math.pi * 0.9, math.pi * 2.2)
      lg.setColor(c(st.col))
      lg.circle("fill", cx + 8, st.y + bob - st.amp + 6, 4)
    end
  end
  return st.y + bob, off
end

-- waterline of strip i at screen x (so things can float on it)
local function surface(i, x, t, push)
  local st = STRIPS[i]
  local off = math.sin(t * st.speed + i) * st.slide + push * st.slide * 1.2
  local bob = math.sin(t * 1.1 + i * 1.3) * 5
  return st.y + bob + math.abs(math.sin((x + off) * math.pi / st.period)) * st.amp - st.amp
end

function S:hang(i, x, len, draw)
  local s = self.swing[i]
  lg.push()
  lg.translate(x, 22)
  lg.rotate(s.a * 0.5)
  kit.string(0, 0, len)
  lg.translate(0, len)
  lg.rotate(-s.a * 0.2)
  draw()
  lg.pop()
end

local function cloudShape(s)
  return function()
    lg.circle("fill", -40 * s, 6 * s, 26 * s)
    lg.circle("fill", 0, -8 * s, 36 * s)
    lg.circle("fill", 44 * s, 6 * s, 28 * s)
    lg.rectangle("fill", -64 * s, 6 * s, 132 * s, 26 * s, 13 * s)
  end
end

function S:drawWhale()
  local t = self.t
  local u = self.whale.u
  if u > 1 then return end
  -- a breach: a parabola from the left to the right, nose following the velocity
  local x = 360 + u * 420
  local y = 640 - math.sin(u * math.pi) * 320
  local ang = math.atan2(-math.cos(u * math.pi) * 320 * math.pi, 420)
  lg.push()
  lg.translate(x, y)
  lg.rotate(ang)
  local body = function()
    lg.ellipse("fill", 0, 0, 140, 62)
    lg.polygon("fill", -110, -24, -200, -70 + math.sin(t * 6) * 8, -176, -10, -206, 44 + math.sin(t * 6) * 8, -110, 22)
  end
  kit.cutout(body, c("#2f4a86"), nil, 1.4)
  -- belly: a paler sheet with pleats
  lg.setColor(c("#e6eef8"))
  lg.arc("fill", 14, 8, 124, 0.12, math.pi - 0.3)
  lg.setColor(c("#2f4a86"))
  lg.ellipse("fill", 14, -8, 130, 44)
  lg.setColor(c("#b8c8e0"))
  lg.setLineWidth(1.5)
  for k = 0, 6 do
    lg.arc("line", "open", 14, 8, 60 + k * 10, 0.5, math.pi - 0.6)
  end
  -- flipper, eye, smile
  kit.cutout(function() lg.polygon("fill", 10, 30, 60, 40, 20, 96, -8, 70) end, c("#243a6e"), nil, 0.6)
  lg.setColor(1, 1, 1)
  lg.circle("fill", 96, -10, 9)
  lg.setColor(0.08, 0.1, 0.2)
  lg.circle("fill", 98, -9, 5)
  lg.setLineWidth(3)
  lg.arc("line", "open", 104, 14, 26, 0.3, 1.9)
  lg.pop()
  -- spout: three paper teardrops on wires above the blowhole, at the top of the jump
  if u > 0.3 and u < 0.75 then
    local k = math.sin((u - 0.3) / 0.45 * math.pi)
    for d = -1, 1 do
      local sx, sy = x + 30 + d * 26 * k, y - 80 - k * 60 - math.abs(d) * -14
      lg.setColor(0.25, 0.2, 0.25, 0.6)
      lg.setLineWidth(1.2)
      lg.line(x + 30, y - 50, sx, sy)
      kit.cutout(function()
        lg.circle("fill", sx, sy, 10)
        lg.polygon("fill", sx - 9, sy - 4, sx + 9, sy - 4, sx, sy - 24)
      end, c("#d8f0fa"), nil, 0.5)
    end
  end
  -- splash: paper drops flung out when leaving and re-entering the water
  for _, su in ipairs({ 0.12, 0.9 }) do
    local k = (u - su) / 0.2
    if k > 0 and k < 1 then
      local bx = 360 + su * 420
      for d = -3, 3 do
        local dx, dy = d * 30 * k, -math.sin(k * math.pi) * (90 - math.abs(d) * 12)
        kit.cutout(function() lg.circle("fill", bx + dx, 560 + dy, 7 - math.abs(d)) end, c("#eaf6fc"), nil, 0.4)
      end
    end
  end
end

function S:drawBoat()
  local t = self.t
  local x = 930 + math.sin(t * 0.25) * 60
  local y = surface(2, x, t, self.push) + 16
  local y2 = surface(2, x + 40, t, self.push) + 16
  lg.push()
  lg.translate(x, y)
  lg.rotate(math.atan2(y2 - y, 40) * 0.6 + math.sin(t * 1.3) * 0.04)
  kit.cutout(function() lg.polygon("fill", -70, -22, 70, -22, 48, 14, -48, 14) end, c("#d8553a"), function() lg.line(-70, -22, 70, -22) end, 0.8)
  lg.setColor(c("#f2e2c0"))
  lg.rectangle("fill", -56, -22, 112, 7)
  lg.setColor(c("#6a4a34"))
  lg.rectangle("fill", -3, -150, 6, 130)
  kit.cutout(function() lg.polygon("fill", 6, -146, 6, -34, 84, -34) end, c("#fdf6e6"), nil, 0.7)
  kit.cutout(function() lg.polygon("fill", -6, -128, -6, -34, -58, -34) end, c("#f4d98a"), nil, 0.7)
  -- fold lines on the sails
  lg.setColor(0.6, 0.55, 0.45, 0.4)
  lg.setLineWidth(1.5)
  lg.line(6, -146, 46, -34)
  lg.line(-6, -128, -32, -34)
  local fl = math.sin(t * 5) * 5
  lg.setColor(c("#3f7fb8"))
  lg.polygon("fill", 3, -150, 34, -160 + fl, 3, -168)
  lg.pop()
end

function S:draw()
  local t = self.t
  -- backdrop sheet: warm sky with a paler band near the horizon
  lg.setColor(c("#fbe3c4"))
  lg.rectangle("fill", 0, 0, 1280, 720)
  kit.cutout(function() lg.ellipse("fill", 640, 440, 900, 260) end, c("#fdf0da"), nil, 0.5, 0.05)

  -- the sun: a folded-ray disc on a thread
  self:hang(1, 330, 120, function()
    for k = 0, 13 do
      local a = k / 14 * math.pi * 2 + t * 0.15
      local a2 = a + math.pi / 14
      lg.setColor(c("#ffd25a"))
      lg.polygon("fill", 0, 0, math.cos(a - 0.2) * 60, math.sin(a - 0.2) * 60, math.cos(a) * 104, math.sin(a) * 104)
      lg.setColor(c("#f2a83a"))
      lg.polygon("fill", 0, 0, math.cos(a) * 104, math.sin(a) * 104, math.cos(a + 0.2) * 60, math.sin(a + 0.2) * 60)
    end
    kit.cutout(function() lg.circle("fill", 0, 0, 64) end, c("#ffbf4a"), nil, 0.6)
    lg.setColor(c("#ffd98a"))
    lg.circle("fill", 0, 0, 50)
    -- a sleepy face
    lg.setColor(c("#c8762a"))
    lg.setLineWidth(3)
    lg.arc("line", "open", -20, -6, 9, 0.2, math.pi - 0.2)
    lg.arc("line", "open", 20, -6, 9, 0.2, math.pi - 0.2)
    lg.arc("line", "open", 0, 12, 16, 0.3, math.pi - 0.3)
  end)
  -- clouds on threads
  self:hang(2, 620, 90, function() kit.cutout(cloudShape(1.1), c("#ffffff"), nil, 1) end)
  self:hang(3, 860, 160, function() kit.cutout(cloudShape(0.8), c("#fff6ec"), nil, 1) end)
  self:hang(4, 1080, 70, function() kit.cutout(cloudShape(0.95), c("#ffffff"), nil, 1) end)
  -- gulls: folded Vs on threads
  for i, g in ipairs({ { 500, 220 }, { 740, 250 } }) do
    self:hang(4 + i, g[1], g[2], function()
      local f = math.sin(t * 3 + i) * 8
      kit.cutout(function()
        lg.polygon("fill", 0, 0, -34, -14 - f, -30, -4 - f)
        lg.polygon("fill", 0, 0, 34, -14 - f, 30, -4 - f)
        lg.circle("fill", 0, 0, 5)
      end, c("#5a6a80"), nil, 0.6)
    end)
  end

  -- far headland with a lighthouse
  local cliff = { 900, 760, 930, 400, 980, 356, 1090, 340, 1190, 352, 1300, 380, 1300, 760 }
  kit.cutout(function() gfx.fillConcave(cliff) end, c("#9a86b8"), function() lg.line(930, 400, 980, 356, 1090, 340, 1190, 352, 1300, 380) end, 0.8)
  -- beam: a translucent paper wedge that swings
  local ba = math.sin(t * 0.6) * 0.5 + math.pi
  lg.setColor(1, 0.95, 0.6, 0.35)
  lg.polygon("fill", 1110, 196, 1110 + math.cos(ba - 0.1) * 700, 196 + math.sin(ba - 0.1) * 700, 1110 + math.cos(ba + 0.1) * 700, 196 + math.sin(ba + 0.1) * 700)
  kit.cutout(function() lg.polygon("fill", 1084, 344, 1136, 344, 1126, 214, 1094, 214) end, c("#fdf6ea"), nil, 0.7)
  lg.setColor(c("#d8553a"))
  lg.polygon("fill", 1087, 310, 1133, 310, 1131, 284, 1089, 284)
  lg.polygon("fill", 1091, 254, 1129, 254, 1127, 228, 1093, 228)
  kit.cutout(function() lg.rectangle("fill", 1088, 180, 44, 34, 4) end, c("#ffd98a"), nil, 0.5)
  kit.cutout(function() lg.polygon("fill", 1082, 182, 1138, 182, 1110, 150) end, c("#d8553a"), nil, 0.5)
  lg.setColor(c("#6a4a34"))
  lg.rectangle("fill", 1102, 318, 16, 26, 6)
  -- a tiny house on the headland
  kit.cutout(function()
    lg.rectangle("fill", 1180, 322, 50, 32)
    lg.polygon("fill", 1174, 324, 1236, 324, 1205, 298)
  end, c("#f2e2c0"), nil, 0.5)
  lg.setColor(c("#d8553a"))
  lg.polygon("fill", 1174, 324, 1236, 324, 1205, 298)

  -- the sea, back to front, with things slotted between the strips
  self:strip(1)
  self:drawBoat()
  self:strip(2)
  self:drawWhale()
  self:strip(3)
  -- a fish leaping in an arc between the front strips
  local fu = self.fish.u
  if fu < 1 then
    local fx, fy = 180 + fu * 200, 640 - math.sin(fu * math.pi) * 130
    lg.push()
    lg.translate(fx, fy)
    lg.rotate(math.atan2(-math.cos(fu * math.pi) * 130 * math.pi, 200))
    kit.cutout(function()
      lg.ellipse("fill", 0, 0, 30, 13)
      lg.polygon("fill", -24, 0, -46, -14, -46, 14)
    end, c("#ff9a4a"), nil, 0.6)
    lg.setColor(c("#fdf6ea"))
    lg.polygon("fill", -6, -11, 6, -11, 4, 11, -4, 11)
    lg.setColor(0.1, 0.1, 0.2)
    lg.circle("fill", 18, -3, 2.5)
    lg.pop()
  end
  self:strip(4)
  self:strip(5)
  kit.finish(self.fibre)
  kit.frame(24, c("#3a2a3a"))
end

return S
