-- INK WASH (sumi-e): black ink on rice paper, mostly empty space.
--
-- Two brush techniques do almost everything:
--   * the wash: mountains are meshes whose vertex colours go from dark ink at the
--     ridge to fully transparent lower down, so each range dissolves into mist; farther
--     ranges use thinner ink
--   * the stroke: a brush stroke follows a Bezier curve and becomes a triangle strip
--     whose width follows "pressure" (thin start, full middle, flicked-off end). A few
--     thin, broken lines along the same curve give the dry-brush streaks.
-- Bamboo leaves are strokes, the crane is a handful of strokes, and a red seal stamp
-- is the only colour, as in traditional paintings.

local gfx = require("core.gfx")

local lg = love.graphics

local S = {
  title = "Ink Wash",
  subtitle = "Misty Peaks",
  blurb = "Sumi-e: ink mountains dissolving into mist, pressure-sensitive brush strokes, swaying bamboo, a crane and a red seal on rice paper.",
  techniques = {
    "Mountain ranges as vertex-coloured meshes: dark ridge fading to clear",
    "Brush stroke = Bezier curve -> triangle strip with a pressure width profile",
    "Dry-brush streaks: thin broken lines along the same curve",
    "Rice paper baked once: warm base, mottling and stray fibres",
    "Negative space: the mist is simply unpainted paper",
  },
  libs = {
    "(none: love.math.newBezierCurve, Mesh and ImageData)",
  },
  genres = { "Martial arts and wuxia action", "Meditative and narrative games", "Rhythm / calligraphy games", "Strategy games with a historical setting" },
  warmup = 3,
}

local INK = { 0.08, 0.08, 0.1 }

-- Width profile of a real brush: press in, hold, lift off.
local function pressure(t, flick)
  local inn = math.min(1, t / 0.18)
  local out = math.min(1, (1 - t) / (flick or 0.35))
  return math.sqrt(inn) * out ^ 0.7
end

-- One reusable streaming mesh: strokes change every frame (bamboo sways), so we
-- refill it instead of creating new Mesh objects.
local shared

-- Turn a list of control points into a tapered stroke Mesh.
local function strokeMesh(ctrl, width, alpha, flick)
  local pts = love.math.newBezierCurve(ctrl):render(5)
  local n = #pts / 2
  local v = {}
  for i = 1, n do
    local x, y = pts[i * 2 - 1], pts[i * 2]
    local j = math.min(n, i + 1)
    local k = math.max(1, i - 1)
    local dx, dy = pts[j * 2 - 1] - pts[k * 2 - 1], pts[j * 2] - pts[k * 2]
    local len = math.sqrt(dx * dx + dy * dy) + 0.0001
    local nx, ny = -dy / len, dx / len
    local w = width * pressure((i - 1) / math.max(1, n - 1), flick) * 0.5
    v[#v + 1] = { x + nx * w, y + ny * w, 0, 0, INK[1], INK[2], INK[3], alpha }
    v[#v + 1] = { x - nx * w, y - ny * w, 0, 0, INK[1], INK[2], INK[3], alpha }
  end
  if #v < 4 then return nil, pts end
  shared = shared or lg.newMesh(512, "strip", "stream")
  shared:setVertices(v)
  shared:setDrawRange(1, #v)
  return shared, pts
end

-- A full stroke: body plus dry-brush bristle streaks.
local function brush(ctrl, width, alpha, flick)
  local mesh, pts = strokeMesh(ctrl, width, alpha, flick)
  if mesh then
    lg.setColor(1, 1, 1)
    lg.draw(mesh)
  end
  lg.setLineWidth(1)
  for b = 1, 3 do
    local off = (b - 2) * width * 0.35
    local seg = {}
    for i = 1, #pts - 2, 2 do
      local gap = love.math.noise(i * 0.15, b * 3.3 + #pts) > 0.62
      if not gap then
        seg[#seg + 1] = pts[i] + off * 0.3
        seg[#seg + 1] = pts[i + 1] + off
      elseif #seg >= 4 then
        lg.setColor(INK[1], INK[2], INK[3], alpha * 0.5)
        lg.line(seg)
        seg = {}
      else
        seg = {}
      end
    end
    if #seg >= 4 then
      lg.setColor(INK[1], INK[2], INK[3], alpha * 0.5)
      lg.line(seg)
    end
  end
end

local function bakePaper()
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local n = gfx.fbm(x * 0.015, y * 0.015, 4) * 0.06 + love.math.noise(x * 0.5, y * 0.5) * 0.02
    return 0.94 - n, 0.9 - n, 0.81 - n, 1
  end)
  local c = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(lg.newImage(d), 0, 0, 0, 2, 2)
  for _ = 1, 220 do
    local x, y = love.math.random(0, 1280), love.math.random(0, 720)
    local a = love.math.random() * math.pi
    lg.setColor(0.6, 0.55, 0.45, 0.12)
    lg.setLineWidth(1)
    lg.line(love.math.newBezierCurve(x, y, x + math.cos(a) * 20, y + math.sin(a) * 20 + 6, x + math.cos(a) * 40, y + math.sin(a) * 40):render(3))
  end
  lg.pop()
  return c
end

-- Mountain range: steep peaks, dark at the ridge, transparent below.
local function rangeMesh(baseY, amp, freq, seed, ink, fade)
  local v = {}
  for x = -10, 1290, 6 do
    local n = gfx.fbm(x * freq + seed, seed, 5)
    local r = (1 - math.abs(n * 2 - 1)) ^ 2
    local y = baseY - (n * 0.4 + r * 0.6) * amp
    v[#v + 1] = { x, y, 0, 0, INK[1], INK[2], INK[3], ink }
    v[#v + 1] = { x, y + fade, 0, 1, INK[1], INK[2], INK[3], 0 }
  end
  return lg.newMesh(v, "strip", "static")
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(8)
  self.paper = bakePaper()
  self.ranges = {
    rangeMesh(330, 280, 0.0022, 1.2, 0.18, 190),
    rangeMesh(440, 240, 0.0019, 4.5, 0.32, 170),
    rangeMesh(560, 190, 0.0028, 9.3, 0.55, 150),
  }
  -- static strokes: rocks in the foreground, the calligraphy column
  self.static = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.static)
  lg.clear(0, 0, 0, 0)
  -- a shoreline rock: a pale wash, then a few heavy strokes along its top edge
  lg.setColor(INK[1], INK[2], INK[3], 0.25)
  gfx.fillConcave({ 40, 720, 70, 640, 150, 600, 250, 610, 330, 660, 360, 720 })
  brush({ 50, 700, 80, 630, 150, 598, 250, 608 }, 20, 0.85, 0.3)
  brush({ 250, 608, 300, 630, 330, 660, 356, 716 }, 14, 0.7, 0.4)
  brush({ 150, 640, 190, 650, 230, 690 }, 6, 0.5)
  -- reeds: quick upward flicks
  for k = 0, 9 do
    local x = 330 + k * 16
    brush({ x, 720, x + 6, 660 - k % 3 * 20, x + 20 + k % 2 * 10, 600 - k % 4 * 18 }, 6, 0.75, 0.6)
  end
  -- an abstract "calligraphy" column (not real characters: just brush rhythm)
  for k = 0, 5 do
    local y = 90 + k * 52
    brush({ 1196, y, 1214, y + 6, 1232, y + 2 }, 9, 0.85)
    brush({ 1212, y - 8, 1210, y + 16, 1214, y + 34 }, 8, 0.85, 0.5)
    if k % 2 == 0 then brush({ 1198, y + 26, 1214, y + 20, 1228, y + 30 }, 6, 0.8) end
  end
  lg.pop()
end

function S:update(dt)
  self.t = self.t + dt
end

function S:drawBamboo()
  for s, stalk in ipairs({ { 930, 1.0 }, { 990, 0.85 }, { 1050, 0.7 } }) do
    local x0, k = stalk[1], stalk[2]
    local sway = math.sin(self.t * 0.7 + s) * 10 * k
    local segH = 90 * k
    local y = 730
    for seg = 0, 6 do
      local f = seg / 7
      local x1 = x0 + sway * f * f
      local x2 = x0 + sway * (f + 1 / 7) ^ 2
      brush({ x1, y, (x1 + x2) / 2 + 2, y - segH / 2, x2, y - segH + 6 }, 15 * k, 0.55 * k + 0.15, 0.08)
      -- node: a short dark dash
      brush({ x2 - 9 * k, y - segH + 4, x2, y - segH + 1, x2 + 9 * k, y - segH + 4 }, 4, 0.9)
      if seg >= 3 and seg % 2 == 1 then
        for l = 0, 2 do
          local dir = (l % 2 == 0) and 1 or -1
          local lx, ly = x2, y - segH
          local wob = math.sin(self.t * 1.3 + seg + l) * 6
          brush({ lx, ly, lx + dir * 40 * k, ly + 10 + wob, lx + dir * 90 * k, ly + 30 + l * 14 + wob }, 14 * k, 0.75, 0.5)
        end
      end
      y = y - segH
    end
  end
end

function S:drawCrane()
  local t = self.t
  local x = 380 + math.sin(t * 0.15) * 160
  local y = 210 + math.sin(t * 0.4) * 20
  local flap = math.sin(t * 2.2) * 30
  brush({ x - 50, y, x, y - 4, x + 40, y + 2 }, 9, 0.85)            -- body and neck
  brush({ x + 40, y + 2, x + 62, y - 6, x + 80, y - 4 }, 4, 0.9)     -- head and beak
  brush({ x - 50, y, x - 80, y + 6, x - 96, y + 14 }, 3, 0.8)        -- legs trailing
  brush({ x - 10, y - 2, x - 30, y - 40 - flap, x - 70, y - 60 - flap }, 12, 0.7, 0.6)
  brush({ x - 4, y + 2, x - 20, y + 24 + flap * 0.4, x - 60, y + 30 + flap * 0.6 }, 10, 0.45, 0.6)
  lg.setColor(0.75, 0.12, 0.1)
  lg.circle("fill", x + 66, y - 7, 2.5)                              -- red crown
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.paper)
  -- pale moon with a soft ink halo around it (painted around, not on, the moon)
  self.halo = self.halo or gfx.radialTexture(128, 1.4, INK)
  lg.setColor(1, 1, 1, 0.16)
  lg.draw(self.halo, 760, 150, 0, 2.2, 2.2, 64, 64)
  lg.setColor(0.95, 0.91, 0.82)
  lg.circle("fill", 760, 150, 54)
  for _, m in ipairs(self.ranges) do
    lg.setColor(1, 1, 1)
    lg.draw(m)
  end
  -- a fisherman's boat on the misty water: three tiny strokes
  local bx = 560 + math.sin(self.t * 0.2) * 30
  brush({ bx - 36, 520, bx, 528, bx + 40, 518 }, 6, 0.8)
  brush({ bx - 4, 518, bx - 2, 498, bx, 486 }, 4, 0.85)
  brush({ bx - 14, 488, bx - 2, 480, bx + 12, 488 }, 5, 0.8)
  brush({ bx + 2, 494, bx + 40, 478, bx + 80, 470 }, 1.5, 0.6)
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.static)
  lg.setBlendMode("alpha")
  self:drawBamboo()
  self:drawCrane()
  -- the seal: a red stamp with a geometric mark
  lg.setColor(0.78, 0.12, 0.1, 0.9)
  lg.rectangle("fill", 1190, 420, 52, 52, 4)
  lg.setColor(0.95, 0.9, 0.82)
  lg.setLineWidth(4)
  lg.line(1200, 432, 1232, 432, 1232, 446, 1204, 446, 1204, 462, 1232, 462)
  lg.circle("fill", 1214, 454, 3)
end

return S
