-- ROMANTIC, scene 3: a lantern festival on a still lake.
--
-- Built in two halves: everything above the waterline is drawn, then drawn again
-- mirrored under it, squashed a little and darker, with each row nudged sideways by a
-- sine wave (cheap ripples without a shader). Lanterns are the only light source; each
-- is a warm body + an additive glow, and their colours vary in HSLuv so they all stay
-- equally bright. New lanterns float up from the boat on flux tweens.

local gfx = require("core.gfx")
local hsluv = require("hsluv")
local moonshine = require("moonshine")
local flux = require("flux")

local lg = love.graphics
local WATER = 470

local S = {
  title = "Romantic",
  subtitle = "Lantern Lake",
  blurb = "A night lantern festival: hundreds of glowing lanterns rise over a still lake and shimmer in its reflection.",
  techniques = {
    "Scene above the waterline rendered to a canvas, then mirrored below it",
    "Ripples: the reflection is drawn in thin strips shifted by a sine wave",
    "Lanterns: body + additive glow, hue varied in HSLuv at equal lightness",
    "Depth: far lanterns are smaller, dimmer and slower",
    "New lanterns released from the boat with flux tweens",
  },
  libs = {
    "flux: lanterns released from the boat drift up with easing",
    "hsluv: warm lantern palette with even brightness",
    "moonshine: bloom and vignette",
  },
  genres = { "Romance and festival events in life sims", "Narrative adventure finales", "Relaxing / meditative toys", "Ending cutscenes and credits" },
  warmup = 6,
}

local function lanternColor(seed)
  local c = hsluv.hsluv_to_rgb({ 20 + seed * 35, 95, 72 })
  return c
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  love.math.setRandomSeed(888)
  self.glow = gfx.radialTexture(128, 2)
  self.sky = gfx.vgradient(1280, WATER, {
    { 0, gfx.rgb("#050818") }, { 0.6, gfx.rgb("#13163a") }, { 1, gfx.rgb("#3a2a4e") },
  })
  self.top = lg.newCanvas(1280, WATER)
  self.stars = {}
  for i = 1, 160 do self.stars[i] = { love.math.random(0, 1280), love.math.random(0, WATER - 60), love.math.random() * 6, love.math.random() } end

  self.hills = gfx.ridge(1280, WATER - 10, 120, 0.003, 4.2, 8, 4)
  self.hills2 = gfx.ridge(1280, WATER, 60, 0.006, 9.1, 8, 3)

  self.lanterns = {}
  for i = 1, 160 do
    local depth = love.math.random()
    self.lanterns[i] = {
      x = love.math.random(-40, 1320), y = love.math.random(-20, WATER - 30),
      depth = depth, c = lanternColor(love.math.random()), p = love.math.random() * 6,
      v = 6 + depth * 14, size = 3 + depth * 9,
    }
  end
  self.released = {}

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.6
  self.fx.glow.strength = 5
  self.fx.vignette.opacity = 0.6
  self.fx.vignette.color = { 10, 5, 30 }
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  for _, l in ipairs(self.lanterns) do
    l.y = l.y - l.v * dt
    l.x = l.x + math.sin(self.t * 0.3 + l.p) * 4 * dt
    if l.y < -30 then l.y = WATER - 20; l.x = love.math.random(-40, 1320) end
  end
  self.releaseTimer = (self.releaseTimer or 0) - dt
  if self.releaseTimer <= 0 then
    self.releaseTimer = 2.2
    local l = { x = 660, y = 560, size = 14, alpha = 0, c = lanternColor(love.math.random()), p = love.math.random() * 6 }
    self.released[#self.released + 1] = l
    self.flux:to(l, 1, { alpha = 1, y = 520 }):ease("sineout")
      :after(l, 14, { y = -40, x = 660 + love.math.random(-260, 260), size = 7 }):ease("sinein")
    if #self.released > 8 then table.remove(self.released, 1) end
  end
end

function S:drawLantern(x, y, size, c, alpha, p)
  local flick = 0.85 + 0.15 * math.sin(self.t * 9 + p)
  lg.setBlendMode("add")
  lg.setColor(c[1], c[2] * 0.8, c[3] * 0.6, 0.35 * alpha * flick)
  lg.draw(self.glow, x, y, 0, size * 0.09, size * 0.09, 64, 64)
  lg.setBlendMode("alpha")
  lg.setColor(c[1], c[2], c[3], alpha)
  lg.polygon("fill", x - size * 0.45, y - size * 0.6, x + size * 0.45, y - size * 0.6, x + size * 0.38, y + size * 0.55, x - size * 0.38, y + size * 0.55)
  lg.setColor(1, 0.95, 0.7, alpha * flick)
  lg.ellipse("fill", x, y + size * 0.35, size * 0.22, size * 0.15)
end

function S:drawTop()
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  for _, s in ipairs(self.stars) do
    lg.setColor(1, 1, 0.95, (0.3 + 0.5 * s[4]) * (0.6 + 0.4 * math.sin(self.t * 2 + s[3])))
    lg.circle("fill", s[1], s[2], 0.8 + s[4])
  end
  -- crescent moon: a circle with a sky-coloured circle bitten out of it
  lg.setBlendMode("add")
  lg.setColor(0.9, 0.85, 1, 0.25)
  lg.draw(self.glow, 1050, 110, 0, 1.6, 1.6, 64, 64)
  lg.setBlendMode("alpha")
  lg.stencil(function() lg.circle("fill", 1064, 100, 38) end, "replace", 1)
  lg.setStencilTest("equal", 0)
  lg.setColor(1, 0.97, 0.88)
  lg.circle("fill", 1050, 110, 40)
  lg.setStencilTest()
  lg.setColor(gfx.hex("#0d0e24"))
  gfx.fillRidge(self.hills, WATER)
  lg.setColor(gfx.hex("#08091a"))
  gfx.fillRidge(self.hills2, WATER)
  -- far lanterns first (sorted by depth when created would be nicer; small ones are faint anyway)
  for _, l in ipairs(self.lanterns) do
    self:drawLantern(l.x, l.y, l.size, l.c, 0.35 + l.depth * 0.65, l.p)
  end
  for _, l in ipairs(self.released) do self:drawLantern(l.x, l.y, l.size, l.c, l.alpha, l.p) end
end

function S:drawBoat()
  local x, y = 640, 560 + math.sin(self.t * 1.2) * 2
  local tilt = math.sin(self.t * 0.9) * 0.02
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt)
  lg.setColor(gfx.hex("#06060f"))
  lg.polygon("fill", -150, -10, 150, -10, 120, 22, -120, 22)
  lg.polygon("fill", -150, -10, -170, -26, -140, -10)
  lg.polygon("fill", 150, -10, 170, -26, 140, -10)
  -- the couple: one holding a lantern up between them
  lg.circle("fill", -24, -78, 13)
  lg.polygon("fill", -46, -10, -40, -62, -10, -66, -6, -10)
  lg.circle("fill", 22, -74, 12)
  lg.polygon("fill", 4, -10, 10, -60, 36, -60, 44, -10)
  lg.setLineWidth(6)
  lg.line(-12, -52, 8, -96)
  lg.line(16, -50, 10, -96)
  lg.pop()
  self:drawLantern(x + 9, y - 112, 16, lanternColor(0.3), 1, 0)
end

function S:draw()
  lg.push("all")
  lg.setCanvas({ self.top, stencil = true })
  lg.clear(0, 0, 0, 1)
  self:drawTop()
  lg.pop()

  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.top)
    -- Reflection: strips of the mirrored image, each shifted by a sine ripple.
    local strip = 3
    for y = 0, 720 - WATER, strip do
      local srcY = WATER - y * 1.15
      if srcY < 0 then break end
      local depth = y / (720 - WATER)
      local shift = math.sin(y * 0.08 - self.t * 2.2) * (1 + depth * 6) + math.sin(y * 0.21 + self.t * 1.3) * 1.5
      self.quad = self.quad or lg.newQuad(0, 0, 1280, strip, 1280, WATER)
      self.quad:setViewport(0, math.max(0, srcY - strip), 1280, strip)
      lg.setColor(0.55 - depth * 0.25, 0.55 - depth * 0.25, 0.75 - depth * 0.3, 1)
      lg.draw(self.top, self.quad, shift, WATER + y, 0, 1, -1, 0, strip)
    end
    lg.setColor(0.6, 0.6, 0.9, 0.25)
    lg.rectangle("fill", 0, WATER, 1280, 2)
    self:drawBoat()
  end)
end

return S
