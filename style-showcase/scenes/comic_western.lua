-- COMIC, scene 3: a showdown told in five panels.
--
-- Comics control time with panel size. One wide establishing shot, then the "camera"
-- cuts closer and closer (eyes, eyes, a hand over a holster) in small tense panels,
-- and the last panel explodes out of its frame. Each panel is a scissor rectangle with
-- its own little drawing; backgrounds are printed in halftone, figures are flat colour
-- with heavy black inks. A single clock drives everything: eyelids narrow and fingers
-- twitch as it runs, then BANG, and it starts over.

local gfx = require("core.gfx")
local kit = require("core.comickit")
local flux = require("flux")
local shack = require("shack")

local lg = love.graphics
local P1 = { 30, 24, 1220, 270 }
local P2 = { 30, 308, 604, 150 }
local P3 = { 646, 308, 604, 150 }
local P4 = { 30, 472, 480, 224 }
local P5 = { 522, 472, 728, 224 }
local CYCLE = 5

local S = {
  title = "Comic Book",
  subtitle = "High Noon at Dry Gulch",
  blurb = "A western showdown in five panels: wide shot, two extreme close-ups, a hand over a holster, and a BANG that bursts out of its frame.",
  techniques = {
    "Pacing with layout: one wide panel, three tight ones, one that breaks the border",
    "Each panel = a scissor rectangle with its own small scene",
    "Halftone backgrounds, flat-colour figures, heavy spot blacks",
    "One clock drives the tension: eyelids narrow, fingers twitch, sweat rolls",
    "Extreme close-ups are just big simple shapes: hat brim, brow, eye, scar",
    "SFX lettering pops with a tween and shakes the whole page",
  },
  libs = {
    "flux: the BANG pop",
    "shack: page shake on the shot",
  },
  genres = { "Western and duel games (quick-draw)", "Interactive comics and visual novels", "Cutscenes between levels", "Reaction-time party games" },
  controls = "click: draw! (fires the last panel early).",
  warmup = 4.2,
}

local INK = { 0.04, 0.04, 0.05 }

local function inside(p, f)
  lg.setScissor(p[1], p[2], p[3], p[4])
  f(p[1], p[2], p[3], p[4])
  lg.setScissor()
end

function S:load()
  self.t = 0
  self.clock = 0
  self.flux = flux.group()
  self.halftone = kit.halftone(5)
  self.colorCanvas = lg.newCanvas(1280, 720)
  self.font = lg.newFont(18)
  self.bold = lg.newFont(24)
  self.sign = lg.newFont(20)
  self.sfxFont = lg.newFont(110)
  self.tickFont = lg.newFont(30)
  self.sfx = { s = 0 }
  self.fired = false
  self.hat = { x = 0, y = 0, r = 0 }
  shack:setDimensions(1280, 720)
end

function S:fire()
  self.fired = true
  self.sfx.s = 0.2
  self.flux:to(self.sfx, 0.3, { s = 1 }):ease("backout")
  shack:setShake(16)
  self.hat = { x = 0, y = 0, r = 0, vx = 260, vy = -420 }
end

function S:mousepressed()
  if not self.fired then self.clock = CYCLE * 0.72 end
end

function S:update(dt)
  self.t = self.t + dt
  self.clock = self.clock + dt
  self.flux:update(dt)
  shack:update(dt)
  if not self.fired and self.clock >= CYCLE * 0.72 then self:fire() end
  if self.clock >= CYCLE then
    self.clock = 0
    self.fired = false
    self.sfx.s = 0
  end
  if self.fired then
    local h = self.hat
    h.x, h.y = h.x + h.vx * dt, h.y + h.vy * dt
    h.vy = h.vy + 900 * dt
    h.r = h.r + dt * 9
  end
end

-- tension 0..1 over the cycle (until the shot)
function S:tension() return gfx.clamp(self.clock / (CYCLE * 0.72), 0, 1) end

----------------------------------------------------------------------------------
-- colour pass (printed in halftone)
----------------------------------------------------------------------------------
function S:drawColor()
  local t = self.t
  inside(P1, function(x, y, w, h)
    lg.setColor(1, 1, 1)
    self.sky = self.sky or gfx.vgradient(w, h, { { 0, gfx.rgb("#ffd84a") }, { 0.6, gfx.rgb("#ff9a3a") }, { 1, gfx.rgb("#e8643a") } })
    lg.draw(self.sky, x, y)
    lg.setColor(gfx.hex("#fff6c8"))
    lg.circle("fill", 640, y + 62, 44)
    -- mesas on the horizon
    lg.setColor(gfx.hex("#c8553a"))
    lg.polygon("fill", x, y + 190, x + 60, y + 130, x + 220, y + 126, x + 260, y + 190)
    lg.polygon("fill", 960, y + 190, 1000, y + 112, 1130, y + 108, 1180, y + 150, 1250, y + 150, 1250, y + 190)
    -- street
    lg.setColor(gfx.hex("#e8b46a"))
    lg.rectangle("fill", x, y + 186, w, 90)
    -- buildings: left row and right row
    local B = { { 60, 150, 120, "#a8502a" }, { 216, 130, 150, "#3f8a8a" }, { 352, 120, 110, "#c88a3a" },
      { 800, 120, 110, "#b8452a" }, { 926, 150, 140, "#d8a84a" }, { 1082, 150, 116, "#5a7fa8" } }
    for _, b in ipairs(B) do
      lg.setColor(gfx.hex(b[4]))
      lg.rectangle("fill", b[1], y + 190 - b[3], b[2], b[3])
    end
    -- clock tower far down the street
    lg.setColor(gfx.hex("#f2dca0"))
    lg.rectangle("fill", 616, y + 104, 48, 86)
    lg.setColor(gfx.hex("#b8452a"))
    lg.polygon("fill", 608, y + 104, 672, y + 104, 640, y + 70)
  end)
  inside(P2, function(x, y, w, h)
    lg.setColor(gfx.hex("#e8a878"))
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(gfx.hex("#c8845a"))
    lg.rectangle("fill", x, y, w, 46)
  end)
  inside(P3, function(x, y, w, h)
    lg.setColor(gfx.hex("#c98a64"))
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(gfx.hex("#a86a48"))
    lg.rectangle("fill", x, y, w, 46)
  end)
  inside(P4, function(x, y, w, h)
    lg.setColor(gfx.hex("#f2c46a"))
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(gfx.hex("#5a6a9a"))
    lg.polygon("fill", x, y, x + 250, y, x + 200, y + h, x, y + h)
  end)
  inside(P5, function(x, y, w, h)
    lg.setColor(gfx.hex("#e0322a"))
    lg.rectangle("fill", x, y, w, h)
    if self.fired then
      lg.setColor(gfx.hex("#ff9a2e"))
      lg.circle("fill", x + 250, y + 120, 260)
      lg.setColor(gfx.hex("#ffe14a"))
      lg.circle("fill", x + 250, y + 120, 150)
    else
      lg.setColor(gfx.hex("#7a1a2a"))
      lg.rectangle("fill", x, y, w, h)
    end
  end)
end

----------------------------------------------------------------------------------
-- ink pass
----------------------------------------------------------------------------------
local function gunslinger(x, y, s, face, coat)
  -- a full figure in a duster coat, legs apart, hand hovering by the hip
  lg.push()
  lg.translate(x, y)
  lg.scale(s * face, s)
  lg.setColor(INK)
  lg.polygon("fill", -20, 0, -6, 0, -2, -60, -16, -60)          -- legs
  lg.polygon("fill", 6, 0, 22, 0, 16, -60, 2, -60)
  lg.setColor(coat)
  lg.polygon("fill", -18, -120, 18, -120, 30, -40, -30, -40)    -- coat
  lg.setColor(INK)
  lg.setLineWidth(3 / s)
  lg.polygon("line", -18, -120, 18, -120, 30, -40, -30, -40)
  lg.polygon("fill", 14, -116, 24, -110, 40, -66, 32, -62)      -- gun arm, bent outward
  lg.polygon("fill", -14, -116, -24, -110, -30, -70, -22, -68)
  lg.circle("fill", 0, -134, 12)
  lg.polygon("fill", -30, -140, 30, -140, 24, -146, -24, -146)  -- hat brim
  lg.polygon("fill", -14, -146, -11, -164, 11, -164, 14, -146)
  lg.pop()
end

local function eye(cx, cy, w, h, lid, look, iris)
  -- white, iris, pupil, then the upper lid coming down (lid 0..1)
  lg.setColor(1, 1, 1)
  lg.ellipse("fill", cx, cy, w, h)
  lg.setColor(iris)
  lg.circle("fill", cx + look, cy + 2, h * 0.9)
  lg.setColor(INK)
  lg.circle("fill", cx + look, cy + 2, h * 0.45)
  lg.setColor(1, 1, 1)
  lg.circle("fill", cx + look - h * 0.3, cy - h * 0.2, h * 0.16)
  lg.setColor(INK)
  lg.setLineWidth(5)
  lg.ellipse("line", cx, cy, w, h)
end

function S:drawInk()
  local t = self.t
  local tension = self:tension()
  -- P1: the street ------------------------------------------------------------
  inside(P1, function(x, y, w, h)
    lg.setColor(INK)
    lg.setLineWidth(3)
    local B = { { 60, 150, 120, "SALOON" }, { 216, 130, 150, "BANK" }, { 352, 120, 110, "" },
      { 800, 120, 110, "" }, { 926, 150, 140, "HOTEL" }, { 1082, 150, 116, "FEED" } }
    lg.setFont(self.sign)
    for _, b in ipairs(B) do
      local top = y + 190 - b[3]
      lg.rectangle("line", b[1], top, b[2], b[3])
      -- false front, planks, door, windows, porch roof
      lg.rectangle("fill", b[1] - 4, top - 6, b[2] + 8, 8)
      for py = top + 40, y + 186, 14 do lg.line(b[1], py, b[1] + b[2], py) end
      lg.rectangle("fill", b[1] + b[2] / 2 - 12, y + 150, 24, 40)
      lg.rectangle("fill", b[1] + 14, top + 46, 22, 26)
      lg.rectangle("fill", b[1] + b[2] - 36, top + 46, 22, 26)
      lg.polygon("fill", b[1] - 10, y + 140, b[1] + b[2] + 10, y + 140, b[1] + b[2] + 2, y + 132, b[1] - 2, y + 132)
      lg.line(b[1] + 2, y + 140, b[1] + 2, y + 190)
      lg.line(b[1] + b[2] - 2, y + 140, b[1] + b[2] - 2, y + 190)
      if b[4] ~= "" then
        lg.setColor(1, 0.95, 0.8)
        lg.rectangle("fill", b[1] + 12, top + 8, b[2] - 24, 26)
        lg.setColor(INK)
        lg.rectangle("line", b[1] + 12, top + 8, b[2] - 24, 26)
        lg.printf(b[4], b[1] + 12, top + 10, b[2] - 24, "center")
      end
    end
    -- clock tower: both hands at twelve
    lg.rectangle("line", 616, y + 104, 48, 86)
    lg.polygon("line", 608, y + 104, 672, y + 104, 640, y + 70)
    lg.setColor(1, 1, 1)
    lg.circle("fill", 640, y + 126, 15)
    lg.setColor(INK)
    lg.circle("line", 640, y + 126, 15)
    lg.line(640, y + 126, 640, y + 114)
    lg.setLineWidth(2)
    lg.line(640, y + 126, 640 + math.sin(t * 6) * 1, y + 116)
    -- heat rays around the sun, mesa outlines, horizon
    lg.setLineWidth(3)
    for k = 0, 15 do
      local a = k / 16 * math.pi * 2 + t * 0.2
      lg.line(640 + math.cos(a) * 54, y + 62 + math.sin(a) * 54, 640 + math.cos(a) * (70 + (k % 2) * 12), y + 62 + math.sin(a) * (70 + (k % 2) * 12))
    end
    lg.circle("line", 640, y + 62, 44)
    lg.line(x, y + 190, x + w, y + 190)
    lg.polygon("line", x, y + 190, x + 60, y + 130, x + 220, y + 126, x + 260, y + 190)
    -- wheel ruts in the street converge toward the tower
    lg.setLineWidth(2)
    for k = -3, 3 do
      if k ~= 0 then lg.line(640 + k * 16, y + 196, 640 + k * 150, y + h) end
    end
    -- the two gunslingers and their long noon... well, dramatic shadows
    lg.setColor(INK)
    lg.polygon("fill", 470, y + 244, 496, y + 244, 560, y + 270, 500, y + 270)
    lg.polygon("fill", 790, y + 244, 816, y + 244, 790, y + 270, 730, y + 270)
    gunslinger(482, y + 246, 0.62, 1, { gfx.hex("#c8a060") })
    gunslinger(802, y + 246, 0.62, -1, { gfx.hex("#5a2a2a") })
    -- tumbleweed rolling through
    local tx = x + ((t * 90) % (w + 120)) - 60
    local ty = y + 250 - math.abs(math.sin(t * 3)) * 16
    lg.setLineWidth(2)
    for k = 0, 6 do
      local a = t * 4 + k * 0.9
      lg.ellipse("line", tx, ty, 18, 18 - k * 2.2)
      lg.line(tx + math.cos(a) * 18, ty + math.sin(a) * 18, tx - math.cos(a + 1) * 14, ty - math.sin(a + 1) * 14)
    end
    kit.caption("DRY GULCH. THE CLOCK STRIKES TWELVE.", x + 14, y + 12, 430, self.font)
  end)

  -- P2 / P3: the eyes -----------------------------------------------------------
  local lid = 0.25 + tension * 0.45
  local function closeup(p, iris, scar, bandana)
    inside(p, function(x, y, w, h)
      local cx = x + w / 2
      -- hat brim: one big black shape across the top
      lg.setColor(INK)
      lg.polygon("fill", x, y, x + w, y, x + w, y + 30, cx, y + 50, x, y + 34)
      for _, sx in ipairs({ -1, 1 }) do
        local ex, ey = cx + sx * 150, y + 92
        eye(ex, ey, 74, 26, lid, sx * 6 - 4, iris)
        -- upper lid and brow press down as the tension rises
        lg.setColor(p == P2 and { gfx.hex("#e8a878") } or { gfx.hex("#c98a64") })
        lg.polygon("fill", ex - 84, ey - 34, ex + 84, ey - 34, ex + 84, ey - 26 + lid * 34, ex - 84, ey - 20 + lid * 34 - sx * 6)
        lg.setColor(INK)
        lg.setLineWidth(6)
        lg.line(ex - 80, ey - 20 + lid * 34 - sx * 6, ex + 80, ey - 26 + lid * 34)
        lg.polygon("fill", ex - 90, ey - 50 + lid * 14 + sx * 8, ex + 90, ey - 50 + lid * 14 - sx * 8, ex + 84, ey - 36 + lid * 14 - sx * 6, ex - 84, ey - 34 + lid * 14 + sx * 6)
        -- crow's feet and a bag under the eye
        lg.setLineWidth(2.5)
        for k = 0, 2 do lg.line(ex + sx * 82, ey - 6 + k * 8, ex + sx * 106, ey - 12 + k * 14) end
        lg.arc("line", "open", ex, ey + 14, 70, 0.5, math.pi - 0.5)
      end
      -- nose bridge shadow
      lg.setColor(INK)
      lg.polygon("fill", cx - 10, y + 60, cx + 4, y + 60, cx + 16, y + h, cx - 2, y + h)
      if scar then
        lg.setLineWidth(4)
        lg.line(cx + 96, y + 44, cx + 130, y + 132)
        lg.setLineWidth(2)
        for k = 0, 4 do lg.line(cx + 96 + k * 8, y + 62 + k * 16, cx + 112 + k * 8, y + 58 + k * 16) end
      end
      if bandana then
        lg.setColor(gfx.hex("#b8262a"))
        lg.polygon("fill", x, y + h - 22, cx, y + h - 34, x + w, y + h - 22, x + w, y + h, x, y + h)
        lg.setColor(INK)
        lg.setLineWidth(4)
        lg.line(x, y + h - 22, cx, y + h - 34, x + w, y + h - 22)
      else
        -- a bead of sweat rolling down
        local sy = y + 50 + ((t * 26) % 110)
        lg.setColor(0.75, 0.9, 1)
        lg.polygon("fill", x + 60, sy - 12, x + 67, sy + 4, x + 53, sy + 4)
        lg.circle("fill", x + 60, sy + 4, 7)
        lg.setColor(INK)
        lg.setLineWidth(2)
        lg.circle("line", x + 60, sy + 4, 7)
      end
    end)
  end
  closeup(P2, { gfx.hex("#4a8ac8") }, false, false)
  closeup(P3, { gfx.hex("#6a4a2a") }, true, true)

  -- P4: the hand over the holster ------------------------------------------------
  inside(P4, function(x, y, w, h)
    -- hip and gun belt
    lg.setColor(INK)
    lg.setLineWidth(4)
    lg.polygon("line", x, y, x + 250, y, x + 200, y + h, x, y + h)
    lg.setColor(gfx.hex("#6a3a1e"))
    lg.polygon("fill", x, y + 70, x + 236, y + 54, x + 230, y + 86, x, y + 104)
    lg.setColor(INK)
    lg.polygon("line", x, y + 70, x + 236, y + 54, x + 230, y + 86, x, y + 104)
    for k = 0, 7 do
      lg.setColor(gfx.hex("#e8c84a"))
      lg.rectangle("fill", x + 14 + k * 20, y + 72 - k * 1.2, 10, 24, 3)
      lg.setColor(INK)
      lg.setLineWidth(2)
      lg.rectangle("line", x + 14 + k * 20, y + 72 - k * 1.2, 10, 24, 3)
    end
    -- holster and the revolver's grip
    lg.setColor(gfx.hex("#4a2814"))
    lg.polygon("fill", x + 150, y + 84, x + 236, y + 78, x + 220, y + 204, x + 172, y + 210)
    lg.setColor(gfx.hex("#8a5a34"))
    lg.polygon("fill", x + 196, y + 30, x + 252, y + 44, x + 236, y + 96, x + 190, y + 84)
    lg.setColor(INK)
    lg.setLineWidth(4)
    lg.polygon("line", x + 150, y + 84, x + 236, y + 78, x + 220, y + 204, x + 172, y + 210)
    lg.polygon("line", x + 196, y + 30, x + 252, y + 44, x + 236, y + 96, x + 190, y + 84)
    lg.setLineWidth(2)
    for k = 0, 3 do lg.line(x + 204 + k * 10, y + 40 + k * 3, x + 198 + k * 10, y + 80 + k * 3) end
    -- the hand: palm + four fingers + thumb, fingers twitching more as tension rises
    local hx, hy = x + 330, y + 96
    local skin = { gfx.hex("#e8a878") }
    lg.setColor(gfx.hex("#c8a060"))
    lg.polygon("fill", x + w, y, x + w, y + 80, hx + 20, hy - 20, hx + 40, hy - 70)   -- sleeve
    lg.setColor(INK)
    lg.polygon("line", x + w, y, x + w, y + 80, hx + 20, hy - 20, hx + 40, hy - 70)
    lg.setColor(skin)
    lg.polygon("fill", hx - 30, hy - 40, hx + 40, hy - 62, hx + 56, hy - 4, hx - 10, hy + 26)
    lg.setColor(INK)
    lg.polygon("line", hx - 30, hy - 40, hx + 40, hy - 62, hx + 56, hy - 4, hx - 10, hy + 26)
    for k = 0, 3 do
      local tw = math.sin(t * (14 + k * 3) + k * 2) * tension * 0.18
      lg.push()
      lg.translate(hx - 24 + k * 16, hy - 20 + k * 12)
      lg.rotate(2.35 + k * 0.1 + tw)
      lg.setColor(skin)
      lg.rectangle("fill", 0, -9, 62 - k * 4, 18, 9)
      lg.setColor(INK)
      lg.setLineWidth(4)
      lg.rectangle("line", 0, -9, 62 - k * 4, 18, 9)
      lg.setLineWidth(2)
      lg.line(30, -9, 30, 9)
      lg.pop()
    end
    lg.push()
    lg.translate(hx - 20, hy - 36)
    lg.rotate(2.9 + math.sin(t * 11) * tension * 0.1)
    lg.setColor(skin)
    lg.rectangle("fill", 0, -10, 52, 20, 10)
    lg.setColor(INK)
    lg.setLineWidth(4)
    lg.rectangle("line", 0, -10, 52, 20, 10)
    lg.pop()
    -- nervous little marks around the fingers
    lg.setLineWidth(3)
    for k = 0, 4 do
      local a = 2.2 + k * 0.32
      local r1 = 96 + math.sin(t * 20 + k) * 4
      lg.line(hx - 14 + math.cos(a) * r1, hy + math.sin(a) * r1, hx - 14 + math.cos(a) * (r1 + 14 + tension * 14), hy + math.sin(a) * (r1 + 14 + tension * 14))
    end
    -- tick... tick...
    lg.setFont(self.tickFont)
    local n = math.floor(self.clock * 2)
    for k = 0, math.min(n, 3) do
      lg.setColor(0, 0, 0, (k == math.min(n, 3)) and 1 or 0.45)
      lg.print("tick", x + 20 + k * 8, y + 126 + k * 22, -0.08)
    end
  end)

  -- P5: BANG ------------------------------------------------------------------------
  local p = P5
  if self.fired then
    inside(p, function(x, y, w, h)
      kit.speedLines(x + 250, y + 120, 56, 120, 900, 0.02 * math.sin(t * 30))
    end)
  else
    inside(p, function(x, y, w, h)
      -- before the shot: two silhouettes and a held breath
      lg.setColor(INK)
      lg.rectangle("fill", x, y + h - 30, w, 30)
      gunslinger(x + 170, y + h - 28, 1.1, 1, INK)
      gunslinger(x + w - 170, y + h - 28, 1.1, -1, INK)
      lg.setFont(self.bold)
      lg.setColor(1, 0.9, 0.8)
      local dots = string.rep(". ", 1 + math.floor(self.clock * 1.6) % 4)
      lg.printf(dots, x, y + 60, w, "center")
    end)
  end
  -- panel borders (drawn before the SFX so the SFX can break out of P5)
  lg.setColor(INK)
  lg.setLineWidth(6)
  for _, q in ipairs({ P1, P2, P3, P4, P5 }) do lg.rectangle("line", q[1], q[2], q[3], q[4]) end
  if self.fired then
    local cx, cy = p[1] + 250, p[2] + 120
    lg.push()
    lg.translate(cx, cy)
    lg.rotate(-0.1)
    lg.scale(self.sfx.s)
    local burst = kit.burst(0, 0, 300, 190, 16, 0.62)
    kit.fillBurst(burst, 0, 0, { 1, 1, 1 })
    kit.ink(burst, 5)
    kit.sfx("BANG!", -260, -66, self.sfxFont, { 1, 0.85, 0.1 }, { 0.6, 0.08, 0.08 }, 9, 520, "center")
    lg.pop()
    -- the hat, shot clean off and spinning away
    local hh = self.hat
    lg.push()
    lg.translate(p[1] + 560 + hh.x, p[2] + 150 + hh.y)
    lg.rotate(hh.r)
    lg.setColor(gfx.hex("#6a4a2a"))
    lg.polygon("fill", -46, 8, 46, 8, 36, -2, -36, -2)
    lg.polygon("fill", -20, -2, -16, -30, 16, -30, 20, -2)
    lg.setColor(INK)
    lg.setLineWidth(4)
    lg.polygon("line", -46, 8, 46, 8, 36, -2, -36, -2)
    lg.polygon("line", -20, -2, -16, -30, 16, -30, 20, -2)
    lg.circle("fill", 0, -14, 4)
    lg.pop()
  end
end

function S:draw()
  lg.push()
  shack:apply()
  kit.page(self.colorCanvas, self.halftone, function() self:drawColor() end, function() self:drawInk() end)
  lg.pop()
end

return S
