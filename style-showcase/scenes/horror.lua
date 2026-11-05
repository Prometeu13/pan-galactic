-- HORROR: top-down dark forest, a flashlight, and things that don't like the light.
--
-- What makes it scary is what you CAN'T see:
--   * the light map starts pitch black; lighter adds a light that casts tree shadows,
--     then a cone mask cuts it down to a flashlight beam
--   * mist is drawn into the scene before lighting, so it only appears inside the beam
--     (instant "volumetric" light)
--   * eyes are emissive (drawn after lighting) and vanish when the beam touches them
--   * every few seconds lightning lights everything for a moment, with a screen shake,
--     and reveals something that wasn't visible before

local gfx = require("core.gfx")
local view = require("core.view")
local moonshine = require("moonshine")
local Lighter = require("lighter")
local shack = require("shack")

local lg = love.graphics
local PX, PY = 640, 560 -- player position

local S = {
  title = "Horror",
  subtitle = "Don't Go Into the Woods",
  blurb = "Darkness as a mechanic: a shadow-casting flashlight cone, mist that only exists in the beam, eyes in the dark and lightning reveals.",
  techniques = {
    "Light map = black canvas + ray-cast light, multiplied by a soft cone mask (Mesh fan)",
    "Forest floor baked from noise into ImageData at half resolution",
    "Mist drawn before lighting, so it only shows inside the flashlight beam",
    "Emissive eyes drawn after the light map; they blink and hide from the beam",
    "Lightning: brief full-bright light map + screen shake + a reveal",
  },
  libs = {
    "lighter: ray-cast shadows from every tree trunk",
    "moonshine: film grain, chromatic aberration and a heavy vignette",
    "shack: screen shake on thunder",
  },
  genres = { "Survival horror and stealth", "Top-down shooters with fog of war", "Roguelike dungeon crawlers (limited vision)", "Atmospheric exploration / mystery" },
  controls = "move the mouse to aim the flashlight.",
  warmup = 3.2,
}

local function octagon(cx, cy, r)
  local p = {}
  for i = 0, 7 do
    local a = i / 8 * math.pi * 2
    p[#p + 1] = cx + math.cos(a) * r
    p[#p + 1] = cy + math.sin(a) * r
  end
  return p
end

local function bakeFloor()
  local w, h = 640, 360
  local d = love.image.newImageData(w, h)
  d:mapPixel(function(x, y)
    local n = gfx.fbm(x * 0.02, y * 0.02, 5)
    local m = gfx.fbm(x * 0.08 + 9, y * 0.08, 3)
    local r = 0.16 + n * 0.14 + m * 0.05
    local g = 0.15 + n * 0.16
    local b = 0.10 + n * 0.06
    if m > 0.62 then r, g, b = r * 0.6, g * 0.75, b * 0.6 end -- damp patches
    return r, g, b, 1
  end)
  local img = lg.newImage(d)
  local c = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(img, 0, 0, 0, 2, 2)
  -- leaf litter
  for _ = 1, 900 do
    local x, y = love.math.random(0, 1280), love.math.random(0, 720)
    local k = love.math.random()
    lg.setColor(0.35 + k * 0.25, 0.22 + k * 0.12, 0.08, 0.8)
    lg.push()
    lg.translate(x, y)
    lg.rotate(love.math.random() * 6.28)
    lg.ellipse("fill", 0, 0, 5 + k * 4, 2 + k * 1.5)
    lg.pop()
  end
  -- a fallen log and some rocks
  lg.setColor(0.28, 0.18, 0.1)
  lg.push()
  lg.translate(330, 420)
  lg.rotate(0.35)
  lg.rectangle("fill", -120, -16, 240, 32, 14)
  lg.setColor(0.4, 0.28, 0.16)
  lg.ellipse("fill", 120, 0, 10, 16)
  lg.pop()
  for _ = 1, 14 do
    local x, y = love.math.random(0, 1280), love.math.random(0, 720)
    lg.setColor(0.35, 0.35, 0.33)
    lg.ellipse("fill", x, y, love.math.random(8, 20), love.math.random(6, 14))
  end
  lg.pop()
  return c
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(666)
  self.floor = bakeFloor()
  self.lightCanvas = lg.newCanvas(1280, 720)
  self.maskCanvas = lg.newCanvas(1280, 720)
  self.glow = gfx.radialTexture(128, 2)
  self.lighter = Lighter()

  self.trees = {}
  local tries = 0
  while #self.trees < 34 and tries < 2000 do
    tries = tries + 1
    local x, y, r = love.math.random(20, 1260), love.math.random(20, 700), love.math.random(14, 30)
    local ok = (x - PX) ^ 2 + (y - PY) ^ 2 > 140 ^ 2
    for _, t in ipairs(self.trees) do
      if (x - t.x) ^ 2 + (y - t.y) ^ 2 < (r + t.r + 60) ^ 2 then ok = false end
    end
    if ok then
      local tr = { x = x, y = y, r = r, poly = octagon(x, y, r) }
      self.trees[#self.trees + 1] = tr
      self.lighter:addPolygon(tr.poly)
    end
  end
  self.light = self.lighter:addLight(PX, PY, 1800, 1, 0.92, 0.75)

  self.mist = {}
  for i = 1, 26 do
    self.mist[i] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), s = 1.5 + love.math.random() * 2.5, v = 6 + love.math.random() * 10 }
  end
  self.eyes = {}
  for i = 1, 7 do
    self.eyes[i] = { x = love.math.random(60, 1220), y = love.math.random(40, 420), p = love.math.random() * 10, hidden = 0 }
  end

  self.flash = 0
  self.nextFlash = 2.6
  self.aim = -math.pi / 2

  self.fx = moonshine(1280, 720, moonshine.effects.filmgrain)
    .chain(moonshine.effects.chromasep)
    .chain(moonshine.effects.vignette)
  self.fx.filmgrain.opacity = 0.22
  self.fx.chromasep.radius = 1.5
  self.fx.vignette.radius = 0.7
  self.fx.vignette.softness = 0.55
  self.fx.vignette.opacity = 0.8
  self.font = lg.newFont(14)
end

function S:update(dt)
  self.t = self.t + dt
  -- Aim at the mouse when the window has it; otherwise sweep slowly (for demos/screenshots).
  if love.window and love.window.hasMouseFocus() then
    local mx, my = view.mouse()
    self.aim = math.atan2(my - PY, mx - PX)
  else
    self.aim = -math.pi / 2 + math.sin(self.t * 0.5) * 0.75
  end
  -- Flashlight wobble: a hand is never perfectly still.
  self.aimJitter = love.math.noise(self.t * 1.5) * 0.06 - 0.03
  for _, m in ipairs(self.mist) do
    m.x = m.x + m.v * dt
    if m.x > 1400 then m.x = -120 end
  end
  for _, e in ipairs(self.eyes) do
    local ang = math.atan2(e.y - PY, e.x - PX)
    local diff = math.abs((ang - self.aim + math.pi) % (2 * math.pi) - math.pi)
    if diff < 0.45 then e.hidden = 1.5 end -- caught in the beam: hide for a while
    e.hidden = math.max(0, e.hidden - dt)
  end

  self.nextFlash = self.nextFlash - dt
  if self.nextFlash <= 0 then
    self.nextFlash = 6 + love.math.random() * 4
    self.flashT = 0
    shack:setDimensions(1280, 720)
    shack:setShake(18)
  end
  if self.flashT then
    self.flashT = self.flashT + dt
    local f = self.flashT
    -- two quick strobes, then darkness
    self.flash = (f < 0.08 and 1) or (f < 0.16 and 0.1) or (f < 0.24 and 0.8) or math.max(0, 0.8 - (f - 0.24) * 3)
    if f > 1 then self.flashT = nil; self.flash = 0 end
  end
  shack:update(dt)
end

function S:coneMesh()
  local aim = self.aim + self.aimJitter
  local spread, len, n = 0.42, 1100, 24
  local v = { { PX, PY, 0, 0, 1, 1, 1, 1 } }
  for i = 0, n do
    local k = i / n * 2 - 1
    local a = aim + k * spread
    local edge = 1 - math.abs(k) ^ 3 -- soft edges
    v[#v + 1] = { PX + math.cos(a) * len, PY + math.sin(a) * len, 0, 0, edge, edge, edge, 1 }
  end
  if not self.cone then
    self.cone = lg.newMesh(v, "fan", "stream")
  else
    self.cone:setVertices(v)
  end
  return self.cone
end

function S:drawLightMap(target)
  -- 1) cone mask: black everywhere, white inside the beam
  lg.setCanvas(self.maskCanvas)
  lg.clear(0, 0, 0, 1)
  lg.setColor(1, 1, 1)
  lg.draw(self:coneMesh())
  -- 2) light with tree shadows, multiplied by the mask
  lg.setCanvas({ self.lightCanvas, stencil = true })
  lg.clear(0, 0, 0, 1)
  lg.setBlendMode("add")
  self.lighter:drawLights()
  self.lighter:drawLights() -- a second additive pass = a brighter, harsher beam
  lg.setBlendMode("multiply", "premultiplied")
  lg.draw(self.maskCanvas)
  -- 3) a little light around the player, plus moonlight ambience and lightning
  lg.setBlendMode("add")
  lg.setColor(0.6, 0.56, 0.5)
  lg.draw(self.glow, PX, PY, 0, 3, 3, 64, 64)
  local amb = 0.055 + self.flash * 0.9
  lg.setColor(amb * 0.8, amb * 0.9, amb)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setBlendMode("alpha")
  lg.setCanvas(target)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.lightCanvas)
  lg.setBlendMode("alpha")
end

function S:drawPlayer()
  lg.push()
  lg.translate(PX, PY)
  lg.rotate(self.aim + math.pi / 2)
  lg.setColor(0.22, 0.25, 0.3)
  lg.ellipse("fill", 0, 4, 22, 13)            -- shoulders / jacket
  lg.setColor(0.3, 0.22, 0.16)
  lg.circle("fill", 0, 2, 10)                 -- head (hair)
  lg.setColor(0.75, 0.6, 0.5)
  lg.rectangle("fill", 8, -24, 6, 22, 3)      -- arm
  lg.setColor(0.15, 0.15, 0.15)
  lg.rectangle("fill", 7, -38, 8, 16, 2)      -- flashlight
  lg.pop()
end

function S:draw()
  self.fx(function()
    local target = lg.getCanvas()
    lg.push()
    shack:apply()
    lg.setColor(1, 1, 1)
    lg.draw(self.floor)
    for _, m in ipairs(self.mist) do
      lg.setColor(0.75, 0.8, 0.8, 0.16)
      lg.draw(self.glow, m.x, m.y, 0, m.s * 1.6, m.s, 64, 64)
    end
    for _, tr in ipairs(self.trees) do
      lg.setColor(0.18, 0.12, 0.08)
      lg.circle("fill", tr.x, tr.y, tr.r + 6)    -- roots
      lg.setColor(0.3, 0.2, 0.12)
      lg.circle("fill", tr.x, tr.y, tr.r)
      lg.setColor(0.4, 0.29, 0.18)
      lg.setLineWidth(1.5)
      lg.circle("line", tr.x, tr.y, tr.r * 0.6)  -- growth rings
      lg.circle("line", tr.x, tr.y, tr.r * 0.3)
    end
    -- the thing between the trees, only there when lightning shows it
    if self.flash > 0.05 then
      lg.setColor(0.02, 0.02, 0.02, math.min(1, self.flash * 1.4))
      lg.ellipse("fill", 905, 210, 26, 16)
      lg.circle("fill", 905, 196, 11)
      lg.setLineWidth(5)
      lg.line(880, 214, 846, 262)
      lg.line(930, 214, 966, 258)
    end
    self:drawPlayer()
    lg.pop()

    self:drawLightMap(target)

    -- Emissive eyes in the dark.
    for _, e in ipairs(self.eyes) do
      local open = math.sin(self.t * 0.9 + e.p) > -0.6 and e.hidden <= 0
      if open then
        local blink = (math.sin(self.t * 3 + e.p * 3) > 0.97) and 0.15 or 1
        lg.setBlendMode("add")
        lg.setColor(1, 0.1, 0.05, 0.35)
        lg.draw(self.glow, e.x, e.y, 0, 0.5, 0.25, 64, 64)
        lg.setBlendMode("alpha")
        lg.setColor(1, 0.25, 0.15)
        lg.ellipse("fill", e.x - 8, e.y, 4, 2.6 * blink)
        lg.ellipse("fill", e.x + 8, e.y, 4, 2.6 * blink)
      end
    end

    -- Thunder flash tint
    if self.flash > 0 then
      lg.setColor(0.8, 0.85, 1, self.flash * 0.35)
      lg.rectangle("fill", 0, 0, 1280, 720)
    end
  end)

  -- Battery HUD, drawn after post-processing so it stays crisp (it flickers when low...)
  local bat = 0.23
  local x, y = 30, 640
  lg.setFont(self.font)
  lg.setColor(0.8, 0.8, 0.75, 0.8)
  lg.print("BATTERY", x, y - 20)
  lg.rectangle("line", x, y, 120, 18, 3)
  lg.rectangle("fill", x + 120, y + 5, 5, 8)
  if math.sin(self.t * 13) > -0.7 then
    lg.setColor(0.85, 0.25, 0.2, 0.9)
    lg.rectangle("fill", x + 3, y + 3, 114 * bat, 12, 2)
  end
end

return S
