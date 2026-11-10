-- CARTOON, scene 2: three monsters having a twilight picnic.
--
-- Character design by silhouette: one is a big fuzzy circle, one is a tall noodle, one
-- is a little blob. If you can tell them apart filled in solid black, the design works.
-- Everything is "outline shape, then fill shape" again, but with new tricks:
--   * fur = a circle whose radius wiggles with a sine wave (same shape for outline + fill)
--   * every character breathes (a slow scale on y) and blinks on its own timer
--   * eyes track the mouse; clicking makes the nearest monster jump and yell

local gfx = require("core.gfx")
local view = require("core.view")
local flux = require("flux")
local Timer = require("hump.timer")
local Draft = require("draft")

local lg = love.graphics
local OUT = { gfx.hex("#241a38") }
local LW = 5
local GROUND = 560

local S = {
  title = "Cartoon",
  subtitle = "Monster Picnic",
  blurb = "Three monsters, three silhouettes: a fuzzy giant, a lanky noodle and a tiny blob share a picnic under a big moon.",
  techniques = {
    "Silhouette-first characters: circle, noodle, blob",
    "Fur: a polygon whose radius follows a sine wave, drawn as outline then fill",
    "Breathing (slow y-scale), independent blinks, pupils that follow the mouse",
    "Noodle arms: thick Bezier curves stroked twice (outline colour, then stripes)",
    "Click: the nearest monster jumps (flux) and a speech burst pops (draft star)",
  },
  libs = {
    "flux: jumps, squash on landing, the speech burst",
    "hump.timer: blink timers and idle fidgets",
    "draft: stars in the sky and the speech burst",
  },
  genres = { "Monster-collecting and pet games", "Kids' storybook apps", "Party games with mascot characters", "Friendly tower defence" },
  controls = "click near a monster to make it jump and shout.",
  warmup = 2.2,
}

local draft = Draft("fill")

local function outlined(drawShape, fill)
  lg.setColor(OUT)
  lg.setLineWidth(LW * 2)
  lg.setLineJoin("bevel")
  drawShape("line")
  lg.setColor(fill)
  drawShape("fill")
end

local function furBall(cx, cy, r, spikes, t, wobble)
  local pts = {}
  local n = spikes * 2
  for i = 0, n - 1 do
    local a = i / n * math.pi * 2
    local rr = r + ((i % 2 == 0) and 9 or -3) + math.sin(t * 3 + i) * (wobble or 1.5)
    pts[#pts + 1] = cx + math.cos(a) * rr
    pts[#pts + 1] = cy + math.sin(a) * rr * 0.96
  end
  return pts
end

local function eye(x, y, r, look, blink)
  if blink then
    lg.setColor(OUT)
    lg.setLineWidth(4)
    lg.arc("line", "open", x, y - 2, r * 0.7, 0.2, math.pi - 0.2)
    return
  end
  lg.setColor(OUT)
  lg.circle("fill", x, y, r + 3.5)
  lg.setColor(1, 1, 1)
  lg.circle("fill", x, y, r)
  lg.setColor(OUT)
  lg.circle("fill", x + look[1] * r * 0.38, y + look[2] * r * 0.38, r * 0.48)
  lg.setColor(1, 1, 1)
  lg.circle("fill", x + look[1] * r * 0.38 - r * 0.16, y + look[2] * r * 0.38 - r * 0.18, r * 0.16)
end

local function noodle(points, width, colorA, colorB)
  local curve = love.math.newBezierCurve(points):render(4)
  lg.setLineJoin("none")
  lg.setColor(OUT)
  lg.setLineWidth(width + LW * 2)
  lg.line(curve)
  lg.circle("fill", curve[1], curve[2], width / 2 + LW)
  lg.circle("fill", curve[#curve - 1], curve[#curve], width / 2 + LW)
  -- stripes: draw the curve in short alternating pieces
  local seg = 10
  for i = 1, #curve - 3, seg do
    lg.setColor((math.floor(i / seg) % 2 == 0) and colorA or colorB)
    lg.setLineWidth(width)
    local piece = {}
    for k = i, math.min(#curve, i + seg + 1) do piece[#piece + 1] = curve[k] end
    if #piece >= 4 then lg.line(piece) end
  end
  return curve[#curve - 1], curve[#curve]
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  self.timer = Timer.new()
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#3b2a7a") }, { 0.5, gfx.rgb("#b0559e") }, { 0.8, gfx.rgb("#ff9a76") }, { 1, gfx.rgb("#ffcf8a") },
  })
  self.glow = gfx.radialTexture(128, 2)
  love.math.setRandomSeed(12)
  self.stars = {}
  for i = 1, 14 do self.stars[i] = { x = love.math.random(40, 1240), y = love.math.random(30, 260), s = love.math.random(10, 22), p = love.math.random() * 6 } end
  self.mon = {
    { id = "fuzz", x = 330, jump = 0, sy = 1, blink = false },
    { id = "noodle", x = 700, jump = 0, sy = 1, blink = false },
    { id = "blob", x = 990, jump = 0, sy = 1, blink = false },
  }
  for i, m in ipairs(self.mon) do
    local function loop()
      self.timer:after(1.2 + love.math.random() * 3, function()
        m.blink = true
        self.timer:after(0.13, function() m.blink = false; loop() end)
      end)
    end
    loop()
  end
  self.burst = { scale = 0, alpha = 0, x = 0, y = 0, text = "" }
  self.font = lg.newFont(34)
  -- the blob hops on its own
  self.timer:every(2.4, function() self:hop(self.mon[3], 70) end)
end

function S:hop(m, height, shout)
  if m.busy then return end
  m.busy = true
  self.flux:to(m, 0.12, { sy = 0.8 }):ease("quadout")
    :after(m, 0.28, { jump = height, sy = 1.12 }):ease("quadout")
    :after(m, 0.28, { jump = 0, sy = 1 }):ease("quadin")
    :after(m, 0.1, { sy = 0.82 })
    :after(m, 0.5, { sy = 1 }):ease("elasticout")
    :oncomplete(function() m.busy = false end)
  if shout then
    local b = self.burst
    b.x, b.y, b.text, b.scale, b.alpha = m.x + 110, 250, shout, 0, 1
    self.flux:to(b, 0.3, { scale = 1 }):ease("backout"):after(b, 0.4, { alpha = 0 }):delay(0.6)
  end
end

function S:mousepressed(x, y)
  local best, bd
  for _, m in ipairs(self.mon) do
    local d = math.abs(m.x - x)
    if not bd or d < bd then best, bd = m, d end
  end
  local shouts = { fuzz = "RAWR!", noodle = "BLORP!", blob = "meep!" }
  self:hop(best, 110, shouts[best.id])
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  self.timer:update(dt)
end

local function lookAt(x, y)
  local mx, my = view.mouse()
  local dx, dy = mx - x, my - y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  return { dx / len, dy / len }
end

function S:drawFuzz(m)
  local t = self.t
  local breathe = 1 + math.sin(t * 1.8) * 0.02
  local x, y = m.x, GROUND - m.jump
  lg.setColor(0.1, 0.05, 0.2, 0.3)
  lg.ellipse("fill", x, GROUND + 6, 120 * (1 - m.jump / 400), 16)
  lg.push()
  lg.translate(x, y)
  lg.scale(1 / m.sy ^ 0.5, m.sy * breathe)
  -- feet
  for _, fx in ipairs({ -55, 55 }) do
    outlined(function(mode) lg.ellipse(mode, fx, -6, 38, 18) end, { gfx.hex("#3567c9") })
  end
  -- arms wave
  local wave = math.sin(t * 2.2) * 0.3
  for side = -1, 1, 2 do
    lg.push()
    lg.translate(side * 105, -150)
    lg.rotate(side * (0.5 + wave * (side == 1 and 1 or 0.3)))
    outlined(function(mode) lg.ellipse(mode, side * 34, 0, 44, 20) end, { gfx.hex("#3f7be0") })
    lg.pop()
  end
  -- horns
  for side = -1, 1, 2 do
    outlined(function(mode) lg.polygon(mode, side * 46, -246, side * 82, -318, side * 86, -238) end, { gfx.hex("#fff1c9") })
  end
  local fur = furBall(0, -140, 118, 18, t)
  outlined(function(mode) if mode == "fill" then gfx.fillConcave(fur) else lg.polygon("line", fur) end end, { gfx.hex("#4a8cf0") })
  lg.setColor(gfx.hex("#7fb3ff"))
  lg.ellipse("fill", -8, -95, 70, 58)              -- lighter belly
  local look = lookAt(x, y - 170)
  eye(0, -178, 40, look, m.blink)
  -- big grin with two teeth
  lg.setColor(OUT)
  lg.arc("fill", "closed", 0, -112, 52, 0.15, math.pi - 0.15)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", -30, -106, -14, -106, -22, -88)
  lg.polygon("fill", 14, -106, 30, -106, 22, -88)
  lg.setColor(gfx.hex("#ff6b8b"))
  lg.ellipse("fill", 0, -74, 22, 9)
  lg.pop()
end

function S:drawNoodle(m)
  local t = self.t
  local x, y = m.x, GROUND - m.jump
  lg.setColor(0.1, 0.05, 0.2, 0.3)
  lg.ellipse("fill", x, GROUND + 6, 60, 12)
  lg.push()
  lg.translate(x, y)
  lg.scale(1, m.sy)
  local sway = math.sin(t * 1.3) * 14
  -- legs
  for side = -1, 1, 2 do
    noodle({ side * 16, -110, side * 30, -60, side * 22, -4 }, 16, { gfx.hex("#ff8a3d") }, { gfx.hex("#ffd166") })
    outlined(function(mode) lg.ellipse(mode, side * 30, -2, 22, 10) end, { gfx.hex("#7a3a1a") })
  end
  -- body: a tall rounded pill that sways at the top
  local body = {}
  for i = 0, 20 do
    local f = i / 20
    body[#body + 1] = -36 + sway * f * f - 6 * math.sin(f * math.pi)
    body[#body + 1] = -100 - f * 250
  end
  for i = 20, 0, -1 do
    local f = i / 20
    body[#body + 1] = 36 + sway * f * f + 6 * math.sin(f * math.pi)
    body[#body + 1] = -100 - f * 250
  end
  outlined(function(mode) if mode == "fill" then gfx.fillConcave(body) else lg.polygon("line", body) end end, { gfx.hex("#ff8a3d") })
  outlined(function(mode) lg.circle(mode, sway, -352, 42) end, { gfx.hex("#ff8a3d") })
  lg.setColor(gfx.hex("#ffb066"))
  for k = 0, 3 do lg.ellipse("fill", sway * (0.2 + k * 0.2) ^ 2, -150 - k * 48, 24, 12) end
  -- arms: one holds a sandwich up
  local hx, hy = noodle({ 34 + sway * 0.6, -280, 110, -300 + math.sin(t * 2) * 10, 120, -220 }, 14, { gfx.hex("#ff8a3d") }, { gfx.hex("#ffd166") })
  noodle({ -34 + sway * 0.6, -280, -100, -250, -90 + math.sin(t * 2.4) * 16, -190 }, 14, { gfx.hex("#ff8a3d") }, { gfx.hex("#ffd166") })
  outlined(function(mode) lg.polygon(mode, hx - 26, hy + 14, hx + 26, hy + 14, hx, hy - 22) end, { gfx.hex("#f6e3b0") })
  lg.setColor(gfx.hex("#7ed957"))
  lg.rectangle("fill", hx - 20, hy + 4, 40, 5)
  -- three eyes on stalks? no: two, close together, plus eyebrows that give it attitude
  local look = lookAt(x + sway, y - 360)
  eye(sway - 15, -362, 13, look, m.blink)
  eye(sway + 15, -362, 13, look, m.blink)
  lg.setColor(OUT)
  lg.setLineWidth(5)
  lg.line(sway - 30, -386, sway - 6, -380)
  lg.line(sway + 30, -386, sway + 6, -380)
  lg.arc("line", "open", sway, -338, 10, 0.3, math.pi - 0.3)
  lg.pop()
end

function S:drawBlob(m)
  local t = self.t
  local x, y = m.x, GROUND - m.jump
  lg.setColor(0.1, 0.05, 0.2, 0.3)
  lg.ellipse("fill", x, GROUND + 6, 52 * (1 - m.jump / 300), 9)
  lg.push()
  lg.translate(x, y)
  lg.scale(1 / m.sy, m.sy)
  outlined(function(mode) lg.ellipse(mode, 0, -34, 50, 36) end, { gfx.hex("#63d471") })
  lg.setColor(gfx.hex("#a2f0a0"))
  lg.ellipse("fill", -14, -50, 16, 9)
  -- antennae with glowing tips
  for side = -1, 1, 2 do
    local tipx, tipy = side * 30 + math.sin(t * 4 + side) * 4, -98
    lg.setColor(OUT)
    lg.setLineWidth(6)
    lg.line(side * 16, -62, tipx, tipy)
    lg.setBlendMode("add")
    lg.setColor(1, 0.9, 0.4, 0.5)
    lg.draw(self.glow, x * 0 + tipx, tipy, 0, 0.5, 0.5, 64, 64)
    lg.setBlendMode("alpha")
    outlined(function(mode) lg.circle(mode, tipx, tipy, 8) end, { gfx.hex("#ffe873") })
  end
  local look = lookAt(x, y - 40)
  eye(-20, -40, 10, look, m.blink)
  eye(0, -46, 10, look, m.blink)
  eye(20, -40, 10, look, m.blink)
  lg.setColor(OUT)
  lg.ellipse("fill", 0, -18, 8, 5 + (m.jump > 5 and 5 or 0))
  lg.pop()
end

function S:drawPicnic()
  -- checkered blanket in perspective: rows get shorter toward the back
  local x0, x1, y0, y1 = 420, 920, GROUND + 6, GROUND + 100
  for r = 0, 3 do
    for c = 0, 9 do
      local ya, yb = gfx.lerp(y0, y1, r / 4), gfx.lerp(y0, y1, (r + 1) / 4)
      local ina, inb = 40 * (1 - r / 4), 40 * (1 - (r + 1) / 4)
      local xa1, xa2 = gfx.lerp(x0 + ina, x1 - ina, c / 10), gfx.lerp(x0 + ina, x1 - ina, (c + 1) / 10)
      local xb1, xb2 = gfx.lerp(x0 + inb, x1 - inb, c / 10), gfx.lerp(x0 + inb, x1 - inb, (c + 1) / 10)
      lg.setColor(((r + c) % 2 == 0) and { gfx.hex("#ff5d6c") } or { gfx.hex("#fff4e0") })
      lg.polygon("fill", xa1, ya, xa2, ya, xb2, yb, xb1, yb)
    end
  end
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  lg.polygon("line", x0 + 40, y0, x1 - 40, y0, x1, y1, x0, y1)
  -- basket
  outlined(function(mode) lg.polygon(mode, 520, 600, 610, 600, 600, 650, 530, 650) end, { gfx.hex("#c98b4a") })
  lg.setColor(OUT)
  lg.setLineWidth(4)
  lg.arc("line", "open", 565, 600, 36, math.pi, math.pi * 2)
  for k = 0, 3 do lg.line(532 + k * 22, 606, 536 + k * 20, 646) end
  -- cake with a cherry
  outlined(function(mode) lg.rectangle(mode, 760, 598, 90, 44, 10) end, { gfx.hex("#ffd9e6") })
  lg.setColor(gfx.hex("#ff8fb3"))
  for k = 0, 4 do lg.circle("fill", 770 + k * 18, 600, 10) end
  outlined(function(mode) lg.circle(mode, 805, 584, 9) end, { gfx.hex("#ff3d5a") })
  -- cups
  for _, cx in ipairs({ 660, 700 }) do
    outlined(function(mode) lg.polygon(mode, cx - 10, 630, cx + 10, 630, cx + 13, 606, cx - 13, 606) end, { gfx.hex("#8fd3ff") })
  end
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  -- moon
  lg.setBlendMode("add")
  lg.setColor(1, 0.95, 0.7, 0.35)
  lg.draw(self.glow, 1010, 170, 0, 5, 5, 64, 64)
  lg.setBlendMode("alpha")
  outlined(function(mode) lg.circle(mode, 1010, 170, 86) end, { gfx.hex("#fff6c2") })
  lg.setColor(gfx.hex("#f0dd9a"))
  lg.circle("fill", 980, 150, 16)
  lg.circle("fill", 1040, 200, 22)
  lg.circle("fill", 1030, 130, 9)
  for _, s in ipairs(self.stars) do
    local tw = 0.8 + 0.2 * math.sin(self.t * 3 + s.p)
    local pts = draft:star(s.x, s.y, s.s * 2 * tw, s.s * 0.9 * tw, 4, self.t * 0.3 + s.p, false)
    outlined(function(mode) if mode == "fill" then draft:polygon(pts, "fill") else lg.polygon("line", pts) end end, { gfx.hex("#fff1a8") })
  end
  -- hills
  for layer, spec in ipairs({ { 470, "#5a3f8f", 0.004 }, { 520, "#43317a", 0.006 } }) do
    local pts = {}
    for x = -20, 1300, 20 do
      pts[#pts + 1] = x
      pts[#pts + 1] = spec[1] + math.sin(x * spec[3] + layer * 2) * 30 + math.sin(x * spec[3] * 2.7) * 10
    end
    lg.setColor(gfx.hex(spec[2]))
    gfx.fillRidge(pts, 720)
    lg.setColor(OUT)
    lg.setLineWidth(LW)
    lg.line(pts)
  end
  -- mushroom houses with lit windows
  for _, h in ipairs({ { 130, 500, 1 }, { 1180, 520, 0.8 } }) do
    local x, y, s = h[1], h[2], h[3]
    outlined(function(mode) lg.rectangle(mode, x - 34 * s, y - 70 * s, 68 * s, 80 * s, 14) end, { gfx.hex("#f7e7c6") })
    outlined(function(mode) lg.arc(mode, "closed", x, y - 66 * s, 78 * s, math.pi, math.pi * 2) end, { gfx.hex("#ff5d6c") })
    lg.setColor(1, 1, 1)
    lg.circle("fill", x - 30 * s, y - 100 * s, 11 * s)
    lg.circle("fill", x + 26 * s, y - 110 * s, 14 * s)
    outlined(function(mode) lg.rectangle(mode, x - 12 * s, y - 44 * s, 24 * s, 26 * s, 6) end, { gfx.hex("#ffe873") })
  end
  -- ground
  lg.setColor(gfx.hex("#2f6b5a"))
  lg.rectangle("fill", 0, GROUND - 6, 1280, 200)
  lg.setColor(gfx.hex("#3f8a6c"))
  lg.rectangle("fill", 0, GROUND - 6, 1280, 14)
  lg.setColor(OUT)
  lg.setLineWidth(LW)
  lg.line(0, GROUND - 6, 1280, GROUND - 6)
  self:drawPicnic()
  self:drawNoodle(self.mon[2])
  self:drawFuzz(self.mon[1])
  self:drawBlob(self.mon[3])
  local b = self.burst
  if b.alpha > 0.01 and b.scale > 0.01 then
    lg.push()
    lg.translate(b.x, b.y)
    lg.scale(b.scale)
    lg.rotate(-0.1)
    local pts = draft:star(0, 0, 230, 150, 12, 0, false)
    lg.setColor(OUT[1], OUT[2], OUT[3], b.alpha)
    lg.setLineWidth(LW * 2)
    lg.polygon("line", pts)
    lg.setColor(1, 1, 1, b.alpha)
    draft:polygon(pts, "fill")
    lg.setFont(self.font)
    local w = self.font:getWidth(b.text)
    gfx.outlinedText(b.text, -w / 2, -22, { 1, 0.36, 0.42, b.alpha }, { OUT[1], OUT[2], OUT[3], b.alpha }, 3)
    lg.pop()
  end
end

return S
