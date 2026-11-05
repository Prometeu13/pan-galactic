-- ROMANTIC: soft pastel light, bloom, slow floating motion.
--
-- Softness comes from three things:
--   1. Colour: the sunset gradient is interpolated in HSLuv, a perceptual colour space,
--      so the blend from violet to pink to peach has no muddy or over-bright bands.
--   2. Light: everything bright "blooms" (moonshine glow) and the edges fade (vignette).
--   3. Motion: nothing snaps. Hearts rise and sway, petals drift, a heart beats with
--      a two-pulse rhythm made of chained flux tweens.

local gfx = require("core.gfx")
local hsluv = require("hsluv")
local moonshine = require("moonshine")
local flux = require("flux")

local lg = love.graphics

local S = {
  title = "Romantic",
  subtitle = "Blossom Hill at Dusk",
  blurb = "Pastel gradients, bloom and slow drifting motion. Colour harmony comes from interpolating in a perceptual colour space.",
  techniques = {
    "Sky and sea gradients sampled in HSLuv, then baked into vertex-coloured meshes",
    "Cherry tree grown by a recursive branching function (seeded, so it's stable)",
    "Hill silhouette from a smooth Bezier curve (love.math.newBezierCurve)",
    "Hearts from the parametric heart curve; petals are a ParticleSystem",
    "Bloom (glow) + pink vignette to soften the whole frame",
  },
  libs = {
    "hsluv: perceptually uniform colour interpolation",
    "moonshine: glow (bloom) and vignette",
    "flux: heartbeat pulse and floating heart easing",
  },
  genres = { "Visual novels and dating sims", "Wholesome narrative / walking sims", "Relaxing puzzle games", "Seasonal events and title screens" },
  warmup = 5,
}

local function hsl(h, s, l, a)
  local c = hsluv.hsluv_to_rgb({ h % 360, s, l })
  return { c[1], c[2], c[3], a or 1 }
end

-- Sample a gradient whose key colours are given in HSLuv, interpolating in HSLuv.
local function hsluvGradient(w, h, keys, steps)
  local stops = {}
  for i = 0, steps do
    local t = i / steps
    local k = 1
    while keys[k + 1] and keys[k + 1][1] < t do k = k + 1 end
    local a, b = keys[k], keys[k + 1] or keys[k]
    local f = (b[1] == a[1]) and 0 or (t - a[1]) / (b[1] - a[1])
    stops[#stops + 1] = { t, hsl(gfx.lerp(a[2], b[2], f), gfx.lerp(a[3], b[3], f), gfx.lerp(a[4], b[4], f)) }
  end
  return gfx.vgradient(w, h, stops)
end

local function growTree(seg, blossoms, x, y, angle, len, width, depth)
  local x2, y2 = x + math.cos(angle) * len, y + math.sin(angle) * len
  seg[#seg + 1] = { x, y, x2, y2, width }
  if depth == 0 then
    for _ = 1, 6 do
      blossoms[#blossoms + 1] = {
        x = x2 + love.math.random(-26, 26), y = y2 + love.math.random(-20, 16),
        r = love.math.random(8, 16), shade = love.math.random(), phase = love.math.random() * 6,
      }
    end
    return
  end
  local spread = 0.35 + love.math.random() * 0.25
  growTree(seg, blossoms, x2, y2, angle - spread, len * (0.68 + love.math.random() * 0.12), width * 0.68, depth - 1)
  growTree(seg, blossoms, x2, y2, angle + spread, len * (0.66 + love.math.random() * 0.12), width * 0.68, depth - 1)
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  love.math.setRandomSeed(2024)

  self.sky = hsluvGradient(1280, 500, {
    { 0.0, 275, 55, 18 }, { 0.45, 320, 70, 45 }, { 0.8, 355, 80, 60 }, { 1.0, 390, 90, 74 },
  }, 24)
  self.sea = hsluvGradient(1280, 220, {
    { 0.0, 345, 70, 55 }, { 0.4, 300, 55, 32 }, { 1.0, 270, 50, 14 },
  }, 12)
  self.glowTex = gfx.radialTexture(128, 2)

  self.stars = {}
  for i = 1, 60 do self.stars[i] = { love.math.random(0, 1280), love.math.random(0, 220), love.math.random() * 6 } end

  -- Hill: a smooth Bezier, rendered to points and closed off at the bottom.
  local curve = love.math.newBezierCurve(600, 720, 760, 520, 900, 470, 1100, 470, 1300, 520)
  self.hill = curve:render(5)
  self.hill[#self.hill + 1] = 1300
  self.hill[#self.hill + 1] = 720

  self.branches, self.blossoms = {}, {}
  growTree(self.branches, self.blossoms, 1060, 480, -math.pi / 2 - 0.05, 105, 22, 6)

  -- Falling petals.
  local pd = love.image.newImageData(16, 10)
  pd:mapPixel(function(x, y)
    local dx, dy = (x - 7.5) / 8, (y - 4.5) / 5
    local inside = dx * dx + dy * dy < 1
    return 1, 0.82, 0.9, inside and 1 or 0
  end)
  self.petals = lg.newParticleSystem(lg.newImage(pd), 300)
  self.petals:setPosition(1060, 230)
  self.petals:setEmissionArea("ellipse", 260, 120)
  self.petals:setEmissionRate(9)
  self.petals:setParticleLifetime(7, 10)
  self.petals:setDirection(math.pi * 0.85)
  self.petals:setSpeed(30, 70)
  self.petals:setLinearAcceleration(-12, 8, -2, 18)
  self.petals:setRotation(0, 6.28)
  self.petals:setSpin(-2, 2)
  self.petals:setSizes(0.8, 1.1, 0.9)
  self.petals:setColors(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)

  self.hearts = {}
  self.lanterns = {}
  for i = 1, 9 do
    self.lanterns[i] = { x = love.math.random(80, 620), y = love.math.random(80, 470), s = 0.4 + love.math.random() * 0.6, v = love.math.random(6, 14), p = love.math.random() * 6 }
  end

  self.beat = { s = 1 }
  local function heartbeat()
    self.flux:to(self.beat, 0.1, { s = 1.3 }):ease("quadout")
      :after(self.beat, 0.15, { s = 1.05 }):ease("quadin")
      :after(self.beat, 0.1, { s = 1.2 }):ease("quadout")
      :after(self.beat, 0.6, { s = 1 }):ease("sineinout")
      :oncomplete(heartbeat)
  end
  heartbeat()

  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.82
  self.fx.glow.strength = 3
  self.fx.vignette.color = { 60, 10, 50 }
  self.fx.vignette.opacity = 0.55
  self.fx.vignette.radius = 0.85
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  self.petals:update(dt)

  self.heartTimer = (self.heartTimer or 0) - dt
  if self.heartTimer <= 0 then
    self.heartTimer = 0.7 + love.math.random() * 0.6
    local h = { x = 985 + love.math.random(-20, 20), y = 470, size = 10 + love.math.random() * 14, rise = 0, alpha = 0, sway = love.math.random() * 6 }
    self.hearts[#self.hearts + 1] = h
    self.flux:to(h, 0.8, { alpha = 1 }):ease("sineout")
    self.flux:to(h, 6, { rise = 360 }):ease("sineout")
    self.flux:to(h, 1.5, { alpha = 0 }):delay(4.5)
  end
  for i = #self.hearts, 1, -1 do
    local h = self.hearts[i]
    if h.rise >= 359 then table.remove(self.hearts, i) end
  end
  for _, l in ipairs(self.lanterns) do
    l.y = l.y - l.v * dt
    if l.y < -20 then l.y = 480; l.x = love.math.random(80, 620) end
  end
end

function S:drawSilhouettes()
  -- Two people sitting close on the hill, heads leaning together.
  local c = hsl(285, 45, 12)
  lg.setColor(c)
  local bx, by = 955, 478
  gfx.fillConcave({ bx - 40, by + 20, bx - 34, by - 18, bx - 16, by - 30, bx - 6, by - 4, bx - 2, by + 20 })
  lg.circle("fill", bx - 18, by - 44, 15)
  gfx.fillConcave({ bx + 2, by + 20, bx + 6, by - 6, bx + 20, by - 28, bx + 36, by - 18, bx + 40, by + 20 })
  lg.circle("fill", bx + 14, by - 46, 14)
  -- hair bun / ponytail
  lg.circle("fill", bx + 27, by - 52, 8)
  -- the little heart over them, beating
  lg.push()
  lg.translate(bx - 2, by - 92)
  lg.scale(self.beat.s)
  lg.setColor(hsl(0, 90, 65))
  gfx.fillConcave(gfx.heart(0, 0, 26))
  lg.pop()
end

function S:draw()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.sky, 0, 0)

    for _, s in ipairs(self.stars) do
      lg.setColor(1, 0.95, 1, (0.4 + 0.4 * math.sin(self.t * 1.5 + s[3])) * (1 - s[2] / 260))
      lg.circle("fill", s[1], s[2], 1.3)
    end

    -- Sun sinking into the sea, with a soft halo.
    lg.setBlendMode("add")
    lg.setColor(hsl(30, 100, 80, 0.35))
    lg.draw(self.glowTex, 560, 470, 0, 3.4, 3.4, 64, 64)
    lg.setBlendMode("alpha")
    lg.setColor(hsl(55, 100, 92))
    lg.circle("fill", 560, 480, 92)

    lg.setColor(1, 1, 1)
    lg.draw(self.sea, 0, 500)
    -- Sun glitter on the water: short horizontal strokes that shimmer.
    for i = 0, 28 do
      local y = 506 + i * 7
      local w = (120 - i * 3) * (0.6 + 0.4 * math.sin(self.t * 2 + i * 1.3))
      lg.setColor(hsl(40, 100, 90, 0.7 - i * 0.02))
      lg.rectangle("fill", 560 - w / 2 + math.sin(self.t + i) * 10, y, w, 2, 1)
    end

    -- Sky lanterns: a warm dot plus additive glow.
    for _, l in ipairs(self.lanterns) do
      local flick = 0.8 + 0.2 * math.sin(self.t * 9 + l.p)
      lg.setBlendMode("add")
      lg.setColor(1, 0.6, 0.25, 0.5 * flick)
      lg.draw(self.glowTex, l.x, l.y, 0, 0.35 * l.s, 0.35 * l.s, 64, 64)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.85, 0.5)
      lg.rectangle("fill", l.x - 3 * l.s, l.y - 4 * l.s, 6 * l.s, 8 * l.s, 2)
    end

    -- Hill and tree.
    lg.setColor(hsl(290, 45, 14))
    gfx.fillConcave(self.hill)
    lg.setLineStyle("smooth")
    for _, b in ipairs(self.branches) do
      lg.setLineWidth(b[5])
      lg.line(b[1], b[2], b[3], b[4])
      lg.circle("fill", b[3], b[4], b[5] / 2)
    end
    for _, bl in ipairs(self.blossoms) do
      local sway = math.sin(self.t * 0.8 + bl.phase) * 2
      lg.setColor(hsl(345 + bl.shade * 15, 75, 52 + bl.shade * 16, 0.9))
      lg.circle("fill", bl.x + sway, bl.y, bl.r)
    end
    for _, bl in ipairs(self.blossoms) do
      if bl.shade > 0.6 then
        lg.setColor(hsl(350, 70, 80, 0.8))
        lg.circle("fill", bl.x - bl.r * 0.3 + math.sin(self.t * 0.8 + bl.phase) * 2, bl.y - bl.r * 0.3, bl.r * 0.35)
      end
    end
    self:drawSilhouettes()

    for _, h in ipairs(self.hearts) do
      local x = h.x + math.sin(self.t * 1.5 + h.sway) * 18
      lg.setColor(hsl(355, 85, 72, h.alpha * 0.9))
      gfx.fillConcave(gfx.heart(x, h.y - h.rise, h.size))
    end
    lg.setColor(1, 1, 1)
    lg.draw(self.petals)
  end)
end

return S
