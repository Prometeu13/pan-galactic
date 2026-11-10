-- PAPERCRAFT, scene 3: a paper-cut light box.
--
-- A light box is a stack of white paper sheets with a lamp behind them. Sheets near
-- the lamp glow warm and pale; sheets near you are in shadow, so they look dark and
-- blue. That gives one rule that colours the whole picture: colour = mix(lamp colour,
-- night colour, how far the sheet is from the lamp). Windows are holes: they show the
-- lamp colour at full strength. Each sheet still casts its soft shadow backward.
-- The sheets shift with the mouse by depth, like looking into a real box.

local gfx = require("core.gfx")
local kit = require("core.paperkit")
local view = require("core.view")

local lg = love.graphics

local S = {
  title = "Papercraft",
  subtitle = "Night Town Light Box",
  blurb = "A backlit paper-cut box: six sheets from glowing moonlit back to dark blue front, lit windows as holes, a paper train, hanging stars and parallax.",
  techniques = {
    "One colour rule: mix(lamp, night, depth), so back sheets glow and front sheets go dark",
    "Windows are 'holes': they simply show the lamp colour, plus an additive halo",
    "Each sheet casts a soft shadow backward; shadows grow with the gap",
    "Parallax by depth from the mouse makes it read as a real box",
    "A train of repeated carriages crosses the viaduct sheet",
    "Stars and moon hang on threads; chimney smoke is a chain of paper curls",
  },
  libs = {
    "vivid: lighter cut edges (through core/paperkit.lua)",
  },
  genres = { "Bedtime-story and cosy games", "Puzzle games with layered dioramas", "Advent calendars and seasonal events", "Title screens and save-room backdrops" },
  controls = "move the mouse to look around inside the box.",
  warmup = 2.4,
}

local LAMP = { 1.0, 0.86, 0.6 }
local NIGHT = { 0.07, 0.1, 0.24 }
local function sheet(d) return gfx.mix(LAMP, NIGHT, d ^ 0.8) end

function S:load()
  self.t = 0
  self.fibre = kit.fibre()
  self.glow = gfx.radialTexture(128, 2)
  self.soft = gfx.radialTexture(128, 1.2)
  self.par = { x = 0, y = 0 }
  love.math.setRandomSeed(31)
  -- far town: a run of little houses and a church
  self.far = {}
  local x = -60
  while x < 1340 do
    local w = love.math.random(46, 80)
    self.far[#self.far + 1] = { x = x, w = w, h = love.math.random(50, 110), roof = love.math.random(1, 3), lit = love.math.random() }
    x = x + w + love.math.random(0, 10)
  end
  -- near houses
  self.near = {}
  x = -40
  while x < 1320 do
    local w = love.math.random(110, 170)
    self.near[#self.near + 1] = { x = x, w = w, h = love.math.random(110, 176), roof = love.math.random(1, 2), seed = love.math.random(1, 999), chimney = love.math.random() < 0.6 }
    x = x + w + love.math.random(6, 30)
  end
  self.stars = {}
  for i = 1, 11 do
    self.stars[i] = { x = 90 + i * 100 + love.math.random(-20, 20), len = love.math.random(50, 190), p = love.math.random() * 6, s = 0.7 + love.math.random() * 0.6 }
  end
  self.snow = {}
  for i = 1, 60 do self.snow[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), v = 14 + love.math.random() * 20, p = love.math.random() * 6, d = love.math.random() } end
end

function S:update(dt)
  self.t = self.t + dt
  local tx, ty
  if love.window and love.window.hasMouseFocus() then
    local mx, my = view.mouse()
    tx, ty = (mx - 640) / 640, (my - 360) / 360
  else
    tx, ty = math.sin(self.t * 0.4), math.sin(self.t * 0.3) * 0.5
  end
  self.par.x = self.par.x + (tx - self.par.x) * math.min(1, dt * 3)
  self.par.y = self.par.y + (ty - self.par.y) * math.min(1, dt * 3)
  for _, s in ipairs(self.snow) do
    s.y = s.y + s.v * dt
    s.x = s.x + math.sin(self.t + s.p) * 10 * dt
    if s.y > 730 then s.y = -10 end
  end
end

-- a window: a hole that shows the lamp, with a halo
function S:window(x, y, w, h, on, round)
  if on then
    lg.setColor(LAMP[1], LAMP[2], LAMP[3])
  else
    lg.setColor(NIGHT[1] * 1.6, NIGHT[2] * 1.6, NIGHT[3] * 1.6)
  end
  if round then lg.circle("fill", x + w / 2, y + h / 2, w / 2) else lg.rectangle("fill", x, y, w, h, 2) end
  if on then
    lg.setBlendMode("add")
    lg.setColor(1, 0.7, 0.3, 0.3)
    lg.draw(self.glow, x + w / 2, y + h / 2, 0, w / 22, h / 22, 64, 64)
    lg.setBlendMode("alpha")
  end
end

function S:layer(depth, fn)
  lg.push()
  lg.translate(-self.par.x * depth * 34, -self.par.y * depth * 14)
  fn(sheet(depth))
  lg.pop()
end

function S:draw()
  local t = self.t
  -- the lamp behind everything
  lg.setColor(LAMP)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setColor(1, 1, 1, 0.9)
  lg.draw(self.soft, 640, 330, 0, 9, 6, 64, 64)

  -- sheet 1: the sky sheet, with the moon and stars cut out of it
  self:layer(0.16, function(col)
    kit.cutout(function() lg.rectangle("fill", -100, -100, 1480, 920) end, col, nil, 0.3, 0)
    lg.setColor(1, 0.97, 0.86)
    lg.circle("fill", 820, 190, 96)
    lg.setColor(col)
    lg.circle("fill", 862, 164, 80)                      -- crescent: a second disc covers part
    for k = 0, 60 do
      local sx, sy = gfx.hash(k) * 1280, gfx.hash(k + 99) * 380
      lg.setColor(1, 0.97, 0.86, 0.6 + 0.4 * math.sin(t * 2 + k))
      lg.circle("fill", sx, sy, 1.5 + gfx.hash(k + 7) * 2)
    end
    lg.setBlendMode("add")
    lg.setColor(1, 0.9, 0.6, 0.35)
    lg.draw(self.glow, 800, 196, 0, 4, 4, 64, 64)
    lg.setBlendMode("alpha")
  end)

  -- sheet 2: mountains
  self:layer(0.3, function(col)
    local pts = gfx.ridge(1480, 430, 260, 0.0026, 7.7, 10, 4)
    for i = 1, #pts, 2 do pts[i] = pts[i] - 100 end
    local shape, edge = kit.ridgeShape(pts, 800)
    kit.cutout(shape, col, edge, 1.2)
    -- snow caps: paler paper glued on the peaks
    lg.setColor(kit.shade(col, 0.1))
    for i = 5, #pts - 4, 2 do
      if pts[i + 1] < pts[i - 1] and pts[i + 1] < pts[i + 3] and pts[i + 1] < 330 then
        lg.polygon("fill", pts[i], pts[i + 1], pts[i] - 34, pts[i + 1] + 44, pts[i] - 12, pts[i + 1] + 34, pts[i], pts[i + 1] + 50, pts[i] + 14, pts[i + 1] + 32, pts[i] + 36, pts[i + 1] + 46)
      end
    end
  end)

  -- sheet 3: the far town
  self:layer(0.46, function(col)
    kit.cutout(function()
      lg.rectangle("fill", -100, 470, 1480, 300)
      for _, h in ipairs(self.far) do
        lg.rectangle("fill", h.x, 474 - h.h, h.w, h.h)
        if h.roof == 1 then
          lg.polygon("fill", h.x - 4, 474 - h.h, h.x + h.w + 4, 474 - h.h, h.x + h.w / 2, 474 - h.h - h.w * 0.5)
        elseif h.roof == 2 then
          lg.polygon("fill", h.x - 4, 474 - h.h, h.x + h.w + 4, 474 - h.h, h.x + h.w - 8, 474 - h.h - 20, h.x + 8, 474 - h.h - 20)
        end
      end
      -- church with a spire
      lg.rectangle("fill", 560, 330, 60, 150)
      lg.polygon("fill", 552, 332, 628, 332, 590, 230)
      lg.rectangle("fill", 588, 210, 4, 24)
      lg.rectangle("fill", 582, 216, 16, 4)
      lg.rectangle("fill", 620, 390, 110, 90)
      lg.polygon("fill", 614, 392, 736, 392, 675, 346)
    end, col, nil, 1.3)
    for _, h in ipairs(self.far) do
      for wy = 474 - h.h + 12, 450, 26 do
        for wx = h.x + 9, h.x + h.w - 18, 20 do
          self:window(wx, wy, 9, 12, gfx.hash(wx * 0.7 + wy * 0.3 + h.lit) > 0.42)
        end
      end
    end
    self:window(580, 360, 20, 20, true, true)
    for k = 0, 2 do self:window(636 + k * 30, 420, 14, 30, true) end
  end)

  -- sheet 4: a viaduct with a little train
  self:layer(0.62, function(col)
    local top = 456
    kit.cutout(function()
      lg.rectangle("fill", -100, top, 1480, 26)
      for ax = -60, 1340, 130 do lg.rectangle("fill", ax, top, 34, 260) end
      lg.rectangle("fill", -100, 610, 1480, 200)
    end, col, function() lg.line(-100, top, 1380, top) end, 1.4)
    -- arches: lighter curved cut edges under the deck
    lg.setColor(kit.shade(col, 0.1))
    lg.setLineWidth(3)
    for ax = -60, 1340, 130 do lg.arc("line", "open", ax + 82, top + 74, 50, math.pi, math.pi * 2) end
    lg.setColor(col)
    for ax = -60, 1340, 130 do
      lg.polygon("fill", ax + 34, top + 26, ax + 54, top + 26, ax + 34, top + 60)
      lg.polygon("fill", ax + 130, top + 26, ax + 110, top + 26, ax + 130, top + 60)
    end
    -- the train: engine + four carriages, wrapping around
    local tx = (t * 70) % 1900 - 420
    kit.cutout(function()
      for k = 0, 3 do lg.rectangle("fill", tx + k * 76, top - 40, 68, 36, 4) end
      lg.rectangle("fill", tx + 304, top - 46, 70, 42, 4)
      lg.rectangle("fill", tx + 350, top - 62, 16, 20)
      lg.polygon("fill", tx + 374, top - 4, tx + 374, top - 26, tx + 392, top - 4)
      for k = 0, 4 do
        lg.circle("fill", tx + k * 76 + 16, top - 2, 7)
        lg.circle("fill", tx + k * 76 + 52, top - 2, 7)
      end
    end, kit.shade(col, -0.08), nil, 0.5)
    for k = 0, 3 do
      for w = 0, 2 do self:window(tx + k * 76 + 8 + w * 19, top - 34, 13, 14, true) end
    end
    self:window(tx + 318, top - 38, 18, 16, true)
    -- steam puffs: paper circles trailing behind the funnel
    for k = 0, 5 do
      local u = k / 5
      kit.cutout(function() lg.circle("fill", tx + 356 - u * 130, top - 76 - u * 40 + math.sin(t * 2 + k) * 4, 8 + u * 14) end, gfx.mix(col, LAMP, 0.3), nil, 0.4)
    end
  end)

  -- sheet 5: the near street
  self:layer(0.8, function(col)
    kit.cutout(function()
      lg.rectangle("fill", -100, 650, 1480, 200)
      for _, h in ipairs(self.near) do
        lg.rectangle("fill", h.x, 654 - h.h, h.w, h.h)
        if h.roof == 1 then
          lg.polygon("fill", h.x - 10, 654 - h.h, h.x + h.w + 10, 654 - h.h, h.x + h.w / 2, 654 - h.h - h.w * 0.42)
        else
          lg.polygon("fill", h.x - 10, 654 - h.h, h.x + h.w + 10, 654 - h.h, h.x + h.w - 16, 654 - h.h - 44, h.x + 16, 654 - h.h - 44)
        end
        if h.chimney then lg.rectangle("fill", h.x + h.w * 0.7, 654 - h.h - 66, 18, 60) end
      end
    end, col, nil, 1.6)
    for _, h in ipairs(self.near) do
      local top = 654 - h.h
      local cols = math.floor((h.w - 30) / 36)
      for r = 0, math.floor((h.h - 80) / 52) do
        for cidx = 0, cols - 1 do
          local on = gfx.hash(h.seed + r * 7 + cidx * 3) > 0.35
          local wx, wy = h.x + 18 + cidx * 36, top + 22 + r * 52
          self:window(wx, wy, 22, 30, on)
          -- window cross and sill, in the sheet's colour
          lg.setColor(col)
          lg.rectangle("fill", wx + 10, wy, 2, 30)
          lg.rectangle("fill", wx, wy + 13, 22, 2)
          lg.setColor(kit.shade(col, 0.1))
          lg.rectangle("fill", wx - 3, wy + 30, 28, 3)
          -- someone at home now and then
          if on and gfx.hash(h.seed + r + cidx * 11) > 0.8 then
            lg.setColor(col)
            lg.circle("fill", wx + 11, wy + 18, 5)
            lg.rectangle("fill", wx + 5, wy + 22, 12, 8, 3)
          end
        end
      end
      -- door with a fanlight
      lg.setColor(kit.shade(col, -0.1))
      lg.rectangle("fill", h.x + h.w / 2 - 12, 654 - 44, 24, 44, 3)
      self:window(h.x + h.w / 2 - 9, 654 - 54, 18, 8, true)
      -- chimney smoke: a chain of curls
      if h.chimney then
        local cx, cy = h.x + h.w * 0.7 + 9, top - 70
        for k = 0, 4 do
          local u = (t * 0.25 + k / 5) % 1
          local px, py = cx + math.sin(u * 5 + h.seed) * 14 + u * 20, cy - u * 90
          kit.cutout(function() lg.circle("fill", px, py, 6 + u * 12) end, gfx.mix(col, LAMP, 0.22), nil, 0.3)
        end
      end
    end
    -- street lamps
    for lx = 150, 1200, 350 do
      lg.setColor(kit.shade(col, -0.1))
      lg.rectangle("fill", lx, 560, 5, 94)
      lg.rectangle("fill", lx - 8, 548, 21, 14, 3)
      self:window(lx - 5, 551, 15, 8, true)
      lg.setBlendMode("add")
      lg.setColor(1, 0.8, 0.4, 0.3)
      lg.draw(self.glow, lx + 2, 566, 0, 1.6, 1.6, 64, 64)
      lg.setBlendMode("alpha")
    end
  end)

  -- falling snow between the sheets
  for _, s in ipairs(self.snow) do
    lg.setColor(1, 1, 1, 0.5 + s.d * 0.4)
    lg.circle("fill", s.x - self.par.x * s.d * 30, s.y, 1.5 + s.d * 2)
  end

  -- sheet 6: the front frame: trees, a fence, a cat, and stars on threads
  self:layer(1, function(col)
    kit.cutout(function()
      -- ground and an arch across the top
      lg.rectangle("fill", -100, 684, 1480, 100)
      lg.rectangle("fill", -100, -60, 1480, 86)
      for k = 0, 16 do lg.circle("fill", -40 + k * 86, 26, 44) end
      -- two big trees: trunks and round crowns built from circles
      for _, side in ipairs({ 0, 1 }) do
        local bx = side == 0 and 70 or 1210
        local dir = side == 0 and 1 or -1
        lg.polygon("fill", bx - 34, 720, bx + 34, 720, bx + 16 + dir * 30, 300, bx - 10 + dir * 30, 300)
        lg.polygon("fill", bx + dir * 20, 440, bx + dir * 150, 330, bx + dir * 156, 344, bx + dir * 30, 470)
        for k = 0, 8 do
          local a = k / 9 * math.pi * 2
          lg.circle("fill", bx + dir * 40 + math.cos(a) * 110, 250 + math.sin(a) * 90, 70)
        end
        lg.circle("fill", bx + dir * 40, 250, 110)
        lg.circle("fill", bx + dir * 170, 320, 50)
      end
      -- picket fence
      for fx = 160, 1120, 26 do
        lg.polygon("fill", fx, 690, fx + 14, 690, fx + 14, 652, fx + 7, 642, fx, 652)
      end
      lg.rectangle("fill", 150, 662, 990, 6)
      -- a cat sitting on the fence
      local cx, cy = 760, 644
      lg.ellipse("fill", cx, cy - 14, 15, 20)
      lg.circle("fill", cx + 2, cy - 40, 12)
      lg.polygon("fill", cx - 8, cy - 46, cx - 6, cy - 60, cx + 1, cy - 50)
      lg.polygon("fill", cx + 4, cy - 50, cx + 11, cy - 60, cx + 13, cy - 46)
    end, col, nil, 2)
    -- the cat's tail swishes; its eyes catch the light
    local cx, cy = 760, 644
    lg.setColor(col)
    lg.setLineWidth(5)
    lg.line(love.math.newBezierCurve(cx - 12, cy - 4, cx - 34, cy + 6, cx - 30 + math.sin(t * 2) * 10, cy + 30):render(3))
    lg.setColor(LAMP)
    lg.circle("fill", cx - 2, cy - 42, 1.8)
    lg.circle("fill", cx + 6, cy - 42, 1.8)
    -- stars hanging from the arch
    for i, s in ipairs(self.stars) do
      local sw = math.sin(t * 0.9 + s.p) * 0.12
      lg.push()
      lg.translate(s.x, 40)
      lg.rotate(sw)
      kit.string(0, 0, s.len)
      lg.translate(0, s.len)
      local pts = {}
      for k = 0, 9 do
        local r = ((k % 2 == 0) and 15 or 6.5) * s.s
        local a = k / 10 * math.pi * 2 - math.pi / 2
        pts[#pts + 1] = math.cos(a) * r
        pts[#pts + 1] = math.sin(a) * r
      end
      kit.cutout(function() gfx.fillConcave(pts) end, { 1, 0.9, 0.62 }, nil, 0.5)
      lg.setBlendMode("add")
      lg.setColor(1, 0.8, 0.4, 0.25 + 0.15 * math.sin(t * 2 + s.p))
      lg.draw(self.glow, 0, 0, 0, 1.1 * s.s, 1.1 * s.s, 64, 64)
      lg.setBlendMode("alpha")
      lg.pop()
    end
  end)
  kit.finish(self.fibre)
  kit.frame(22, { 0.05, 0.06, 0.14 })
end

return S
