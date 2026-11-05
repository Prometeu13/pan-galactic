-- NOIR (black & white): hard light, long shadows, rain, film grain.
--
-- The trick: the scene is authored in COLOUR (red bricks, warm lamp, orange cigarette)
-- and a moonshine post-processing chain turns it into a graded black & white film frame.
-- That means one game can switch between "colour" and "noir" with a single flag.
--
-- Shadows are real: `lighter` casts rays from each light past every occluder polygon
-- (the detective, the fire escape) and builds a visibility polygon. The resulting light
-- map is multiplied over the scene.

local gfx = require("core.gfx")
local moonshine = require("moonshine")
local Lighter = require("lighter")

local lg = love.graphics

local S = {
  title = "Noir",
  subtitle = "Rain on Fifth Street",
  blurb = "Black and white with hard shadows. Everything is drawn in colour first; the monochrome look is a post-processing pass you can toggle.",
  techniques = {
    "Light map: a canvas cleared to near-black, lights added, then multiplied over the scene",
    "Shadow casting from occluder polygons (coat, hat, fire escape bars)",
    "Brick wall baked once into a Canvas with noise-varied bricks and grime",
    "Rain = hundreds of short slanted lines; smoke = ParticleSystem with a generated texture",
    "Post chain: desaturate -> film grain -> vignette, plus letterbox bars",
  },
  libs = {
    "lighter: 2D dynamic lights with ray-cast shadows",
    "moonshine: desaturate, filmgrain and vignette effects",
  },
  genres = { "Detective / mystery adventures", "Stealth games (light = danger)", "Narrative games and visual novels", "Puzzle-platformers with a moody tone" },
  controls = "press C to toggle the black & white grade and see the colour original.",
  warmup = 3,
}

local DET_X, GROUND = 610, 612
local DY = GROUND - 652 -- the detective was laid out for a ground line at y=652

local function rect(x, y, w, h) return { x, y, x + w, y, x + w, y + h, x, y + h } end

local function octagon(cx, cy, r)
  local p = {}
  for i = 0, 7 do
    local a = i / 8 * math.pi * 2
    p[#p + 1] = cx + math.cos(a) * r
    p[#p + 1] = cy + math.sin(a) * r
  end
  return p
end

-- Detective as a handful of convex pieces: used both to draw and to cast shadows.
local function detectivePieces(x)
  return {
    { x - 50, 436, x + 50, 436, x + 64, 590, x - 64, 590 },      -- trench coat
    { x - 28, 590, x - 8, 590, x - 10, 652, x - 30, 652 },       -- left leg
    { x + 8, 590, x + 28, 590, x + 30, 652, x + 10, 652 },        -- right leg
    octagon(x + 2, 410, 22),                                      -- head
    { x - 54, 386, x + 58, 386, x + 50, 396, x - 46, 396 },      -- hat brim
    { x - 28, 386, x - 22, 352, x + 24, 352, x + 30, 386 },      -- hat crown
    { x - 30, 432, x - 6, 420, x - 2, 452, x - 40, 452 },        -- turned-up collar
    { x + 30, 432, x + 6, 420, x + 2, 452, x + 40, 452 },
  }
end

local function shifted(pieces)
  for _, p in ipairs(pieces) do
    for i = 2, #p, 2 do p[i] = p[i] + DY end
  end
  return pieces
end

local function bakeWall()
  local c = lg.newCanvas(1280, GROUND)
  lg.push("all")
  lg.setCanvas(c)
  lg.clear(gfx.hex("#2a1d1a"))
  local bh, bw = 24, 64
  for row = 0, math.ceil(GROUND / bh) do
    local off = (row % 2) * bw / 2
    for col = -1, math.ceil(1280 / bw) do
      local x, y = col * bw + off, row * bh
      local n = gfx.fbm(x * 0.01, y * 0.01, 3)
      local v = 0.6 + n * 0.35 + love.math.random() * 0.1
      lg.setColor(0.85 * v, 0.42 * v, 0.32 * v)
      lg.rectangle("fill", x + 2, y + 2, bw - 4, bh - 4, 2)
    end
  end
  -- grime: darker toward the ground, plus noisy stains
  for y = 0, GROUND, 4 do
    local t = y / GROUND
    lg.setColor(0.05, 0.03, 0.03, t * t * 0.6)
    lg.rectangle("fill", 0, y, 1280, 4)
  end
  for _ = 1, 600 do
    local x, y = love.math.random(0, 1280), love.math.random(0, GROUND)
    if gfx.fbm(x * 0.004, y * 0.004, 3) > 0.55 then
      lg.setColor(0.08, 0.05, 0.04, 0.12)
      lg.circle("fill", x, y, love.math.random(6, 24))
    end
  end
  lg.pop()
  return c
end

function S:load()
  self.t = 0
  self.bw = true
  love.math.setRandomSeed(11)
  self.wall = bakeWall()
  self.lightCanvas = lg.newCanvas(1280, 720)
  self.glow = gfx.radialTexture(128, 2)

  self.fx = moonshine(1280, 720, moonshine.effects.desaturate)
    .chain(moonshine.effects.filmgrain)
    .chain(moonshine.effects.vignette)
  self.fx.desaturate.strength = 1
  self.fx.desaturate.tint = { 255, 250, 240 }
  self.fx.filmgrain.opacity = 0.32
  self.fx.filmgrain.size = 2
  self.fx.vignette.radius = 0.75
  self.fx.vignette.softness = 0.6
  self.fx.vignette.opacity = 0.6

  -- Lights and occluders.
  self.lighter = Lighter({ litPolygons = true }) -- occluders themselves get lit, but still cast shadows
  self.pieces = shifted(detectivePieces(DET_X))
  for _, p in ipairs(self.pieces) do self.lighter:addPolygon(p) end
  self.escape = {}
  local function occ(p) self.escape[#self.escape + 1] = p; self.lighter:addPolygon(p) end
  occ(rect(860, 236, 380, 12))            -- fire escape platform
  occ(rect(860, 110, 380, 6))             -- upper rail
  for x = 864, 1236, 22 do occ(rect(x, 116, 4, 120)) end
  occ({ 880, 248, 900, 248, 760, 440, 740, 440 }) -- stair stringer
  for i = 0, 7 do
    local sx, sy = 880 - i * 18, 262 + i * 24
    occ(rect(sx - 30, sy, 34, 4))
  end

  self.lamp = self.lighter:addLight(150, 440, 2600, 1, 0.82, 0.6)
  self.bulb = self.lighter:addLight(1010, 330, 700, 0.9, 0.95, 1)

  self.rain = {}
  for i = 1, 380 do
    self.rain[i] = { x = love.math.random(-200, 1300), y = love.math.random(-720, 720), v = love.math.random(900, 1300), l = love.math.random(14, 30) }
  end
  self.splashes = {}

  -- Cigarette smoke: a ParticleSystem using a texture generated in code.
  self.smoke = lg.newParticleSystem(gfx.radialTexture(64, 1.5), 200)
  self.smoke:setParticleLifetime(2.5, 4)
  self.smoke:setEmissionRate(14)
  self.smoke:setDirection(-math.pi / 2 - 0.15)
  self.smoke:setSpeed(25, 45)
  self.smoke:setSpread(0.4)
  self.smoke:setLinearAcceleration(4, -6, 18, -2)
  self.smoke:setSizes(0.12, 0.35, 0.6)
  self.smoke:setSpin(-0.5, 0.5)
  self.smoke:setColors(0.9, 0.9, 0.9, 0.0, 0.85, 0.85, 0.85, 0.22, 0.8, 0.8, 0.8, 0)

  self.font = lg.newFont(20)
end

function S:keypressed(k)
  if k == "c" then
    self.bw = not self.bw
    if self.bw then self.fx.enable("desaturate") else self.fx.disable("desaturate") end
  end
end

function S:update(dt)
  self.t = self.t + dt
  -- Flickering bulb over the door: mostly on, with nervous dropouts.
  local flick = (math.sin(self.t * 37) > 0.93 or math.sin(self.t * 3.1) > 0.97) and 0.15 or 0.9
  self.lighter:updateLight(self.bulb, 1010, 330, 700, flick, flick, flick)
  self.flick = flick

  for _, r in ipairs(self.rain) do
    r.y = r.y + r.v * dt
    r.x = r.x + r.v * 0.18 * dt
    if r.y > 720 then
      if love.math.random() < 0.3 then
        self.splashes[#self.splashes + 1] = { x = r.x, y = love.math.random(GROUND + 4, 715), t = 0 }
      end
      r.y = r.y - 760 - love.math.random(0, 200)
      r.x = love.math.random(-200, 1300)
    end
  end
  for i = #self.splashes, 1, -1 do
    local s = self.splashes[i]
    s.t = s.t + dt
    if s.t > 0.25 then table.remove(self.splashes, i) end
  end
  self.smoke:setPosition(DET_X + 40, 414 + DY)
  self.smoke:update(dt)
end

function S:drawScene()
  lg.setColor(1, 1, 1)
  lg.draw(self.wall)

  -- Window with venetian blinds, lit from inside.
  lg.setColor(gfx.hex("#ffd58a"))
  lg.rectangle("fill", 380, 150, 170, 190)
  lg.setColor(gfx.hex("#2a1a14"))
  for y = 158, 336, 16 do lg.rectangle("fill", 380, y, 170, 8) end
  lg.setLineWidth(10)
  lg.rectangle("line", 375, 145, 180, 200)

  -- Doorway, the flickering bulb's fixture and a vertical hotel sign.
  lg.setColor(gfx.hex("#120c0b"))
  lg.rectangle("fill", 940, 380, 140, GROUND - 380)
  lg.setColor(gfx.hex("#2b201d"))
  lg.rectangle("fill", 925, 365, 170, 18)
  lg.setColor(1, 1, 0.9, self.flick)
  lg.circle("fill", 1010, 344, 8)

  lg.setColor(gfx.hex("#1d1412"))
  lg.rectangle("fill", 1150, 300, 54, 250, 6)

  -- Sidewalk + curb.
  lg.setColor(gfx.hex("#4a4744"))
  lg.rectangle("fill", 0, GROUND, 1280, 720 - GROUND)
  lg.setColor(gfx.hex("#2c2a28"))
  for x = 0, 1280, 160 do lg.rectangle("fill", x, GROUND, 3, 720 - GROUND) end
  lg.rectangle("fill", 0, GROUND, 1280, 6)

  -- Lamp post on the left.
  lg.setColor(gfx.hex("#1b1b1b"))
  lg.rectangle("fill", 104, 440, 14, GROUND - 440)
  lg.polygon("fill", 96, 440, 182, 432, 186, 444, 96, 452)

  -- Fire escape metal (drawn; its shadows come from the light map).
  lg.setColor(gfx.hex("#3a3634"))
  for _, p in ipairs(self.escape) do lg.polygon("fill", p) end

  -- The detective: trench coat, hat, a hint of face. Lit by the lamp like everything else.
  lg.setColor(gfx.hex("#6b5a44"))
  for i, p in ipairs(self.pieces) do
    if i == 4 then lg.setColor(gfx.hex("#c99a7a")) elseif i == 5 then lg.setColor(gfx.hex("#2a2622")) end
    lg.polygon("fill", p)
  end
  lg.setColor(gfx.hex("#3e3428"))
  lg.rectangle("fill", DET_X - 58, 520 + DY, 116, 8)       -- belt
  lg.setColor(gfx.hex("#2a2622"))
  lg.rectangle("fill", DET_X - 30, 382 + DY, 60, 6)        -- hat band
  lg.ellipse("fill", DET_X - 20, GROUND - 2, 16, 6)   -- shoes
  lg.ellipse("fill", DET_X + 22, GROUND - 2, 16, 6)
end

function S:drawLightMap(target)
  lg.setCanvas({ self.lightCanvas, stencil = true })
  lg.clear(0.05, 0.05, 0.06, 1)          -- "global illumination": how dark the shadows are
  lg.setBlendMode("add")
  self.lighter:drawLights()
  lg.setBlendMode("alpha")
  lg.setCanvas(target)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.lightCanvas)
  lg.setBlendMode("alpha")
end

function S:draw()
  self.fx(function()
    local target = lg.getCanvas()
    self:drawScene()
    self:drawLightMap(target)

    -- Glows on top of the light map (additive).
    lg.setBlendMode("add")
    lg.setColor(1, 0.85, 0.6, 0.9)
    lg.draw(self.glow, 160, 438, 0, 1.6, 1.6, 64, 64)
    lg.setColor(1, 0.9, 0.7, 0.5)
    lg.draw(self.glow, 520, 245, 0, 2.6, 2.4, 64, 64)
    lg.setColor(1, 1, 0.9, 0.6 * self.flick)
    lg.draw(self.glow, 1010, 344, 0, 1.3, 1.3, 64, 64)
    -- Puddle reflecting the lamp.
    lg.setColor(1, 0.85, 0.6, 0.35)
    lg.draw(self.glow, 260, 640, 0, 3.2, 0.3, 64, 64)
    lg.setBlendMode("alpha")

    -- Neon sign: emissive, so it is drawn after the light map (shadows don't touch it).
    local on = math.sin(self.t * 1.7) > -0.8
    lg.setFont(self.font)
    for i, ch in ipairs({ "H", "O", "T", "E", "L" }) do
      local y = 300 + (i - 1) * 48 + 12
      lg.setBlendMode("add")
      lg.setColor(1, 0.4, 0.3, on and 0.35 or 0.05)
      lg.draw(self.glow, 1177, y + 12, 0, 0.7, 0.7, 64, 64)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.55, 0.45, on and 1 or 0.25)
      lg.printf(ch, 1150, y, 54, "center")
    end

    -- Cigarette with a glowing tip.
    lg.setColor(0.9, 0.88, 0.85)
    lg.rectangle("fill", DET_X + 20, 416 + DY, 18, 3)
    lg.setColor(1, 0.45, 0.1)
    lg.circle("fill", DET_X + 39, 417.5 + DY, 2.5)
    lg.draw(self.smoke)

    -- Rain and splashes.
    lg.setLineWidth(1.5)
    for _, r in ipairs(self.rain) do
      lg.setColor(0.85, 0.88, 0.95, 0.28)
      lg.line(r.x, r.y, r.x - r.l * 0.18, r.y - r.l)
    end
    for _, s in ipairs(self.splashes) do
      lg.setColor(0.9, 0.9, 1, 0.5 * (1 - s.t / 0.25))
      lg.ellipse("line", s.x, s.y, 3 + s.t * 40, 1 + s.t * 8)
    end

    -- Cinematic letterbox and a caption.
    lg.setColor(0, 0, 0)
    lg.rectangle("fill", 0, 0, 1280, 62)
    lg.rectangle("fill", 0, 720 - 62, 1280, 62)
    lg.setFont(self.font)
    lg.setColor(0.92, 0.92, 0.92)
    lg.printf("\"The rain never washed anything clean in this town. It just moved the dirt around.\"",
      0, 720 - 44, 1280, "center")
  end)
end

return S
