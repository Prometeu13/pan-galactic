-- ROMANTIC, scene 2: two coffees by a rainy café window at night.
--
-- Photography tricks, faked in 2D:
--   * shallow depth of field: the city outside is drawn sharp once, then blurred once
--     with a gaussian blur and kept as a texture
--   * bokeh: out-of-focus lights become soft discs with a brighter rim, added on top
--   * raindrops on the glass are tiny lenses: each one shows the blurred city behind it,
--     upside down and shrunk (draw the texture with a negative scale, clipped to a circle)
--   * the candle is the only warm light inside, so the table glows around it

local gfx = require("core.gfx")
local hsluv = require("hsluv")
local moonshine = require("moonshine")

local lg = love.graphics
local WX, WY, WW, WH = 120, 30, 1040, 440 -- window opening

local S = {
  title = "Romantic",
  subtitle = "Rainy Café Window",
  blurb = "Night rain on a café window: a blurred city full of bokeh, raindrops that refract the street, and candlelight on two cups.",
  techniques = {
    "City drawn sharp once, then gaussian-blurred once (depth of field)",
    "Bokeh discs: generated texture with a soft edge and a brighter rim",
    "Raindrops as lenses: blurred city drawn inverted inside a stencil circle",
    "Drops run down and leave trails; small beads stay put",
    "Candle glow added to the table; steam is wobbling Bezier curves",
  },
  libs = {
    "moonshine: gaussian blur (baked), glow and a warm vignette",
    "hsluv: bokeh colours with even brightness",
  },
  genres = { "Cosy narrative and visual novels", "Café / cooking management sims", "Lo-fi 'study with me' style ambient apps", "Slice-of-life adventure" },
  warmup = 4,
}

local function bokehTexture(size)
  local d = love.image.newImageData(size, size)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
    local r = math.sqrt(dx * dx + dy * dy)
    local a = 1 - gfx.clamp((r - 0.82) / 0.18, 0, 1)        -- soft edge
    local rim = math.exp(-((r - 0.82) / 0.08) ^ 2) * 0.5   -- brighter ring
    return 1, 1, 1, a * (0.55 + rim)
  end)
  return lg.newImage(d)
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(14)
  self.glow = gfx.radialTexture(128, 2)
  self.bokeh = bokehTexture(96)

  -- 1) The city outside, sharp, into a canvas...
  local sharp = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(sharp)
  lg.draw(gfx.vgradient(1280, 720, { { 0, gfx.rgb("#0b1030") }, { 0.6, gfx.rgb("#2a1a4a") }, { 1, gfx.rgb("#3a2238") } }))
  for i = 0, 24 do
    local x = WX - 40 + i * 48 + love.math.random(-10, 10)
    local top = WY + 60 + love.math.random(0, 220)
    lg.setColor(0.06, 0.06, 0.12)
    lg.rectangle("fill", x, top, 44 + love.math.random(0, 30), 720)
    for wy = top + 10, WY + WH - 40, 18 do
      for wx = x + 6, x + 38, 12 do
        if love.math.random() < 0.45 then
          local warm = love.math.random() < 0.7
          lg.setColor(warm and 1 or 0.5, warm and 0.75 or 0.9, warm and 0.4 or 1, 0.9)
          lg.rectangle("fill", wx, wy, 6, 9)
        end
      end
    end
  end
  lg.setColor(0.12, 0.1, 0.14)
  lg.rectangle("fill", 0, WY + WH - 60, 1280, 200) -- the street
  lg.pop()
  -- 2) ...then blur it once and keep the result.
  self.city = lg.newCanvas(1280, 720)
  local blur = moonshine(1280, 720, moonshine.effects.gaussianblur)
  blur.gaussianblur.sigma = 7
  lg.push("all")
  lg.setCanvas(self.city)
  blur(function() lg.setColor(1, 1, 1); lg.draw(sharp) end)
  lg.pop()

  -- Bokeh lights: static ones (shops, lamps) and moving ones (cars).
  self.lights = {}
  for i = 1, 70 do
    local h = love.math.random() < 0.65 and love.math.random(20, 70) or love.math.random(190, 320)
    local c = hsluv.hsluv_to_rgb({ h, 85, 70 })
    self.lights[i] = {
      x = love.math.random(WX, WX + WW), y = love.math.random(WY + 40, WY + WH - 30),
      r = love.math.random(14, 46), c = c, p = love.math.random() * 6,
    }
  end
  self.cars = {}
  for i = 1, 8 do
    self.cars[i] = { x = love.math.random(0, 1400), lane = i % 2, v = love.math.random(90, 160) }
  end

  -- Rain on the glass.
  self.beads, self.runners = {}, {}
  for i = 1, 140 do
    self.beads[i] = { x = love.math.random(WX + 6, WX + WW - 6), y = love.math.random(WY + 6, WY + WH - 6), r = love.math.random(2, 6) }
  end
  for i = 1, 12 do self.runners[i] = self:newRunner(true) end

  self.haze = gfx.vgradient(WW, WH, { { 0, { 1, 1, 1, 0 } }, { 0.7, { 0.9, 0.9, 1, 0.04 } }, { 1, { 0.9, 0.9, 1, 0.16 } } })
  -- The window is drawn into its own canvas first: the drop lenses need a stencil
  -- buffer, and moonshine's internal canvases don't have one.
  self.windowCanvas = lg.newCanvas(1280, 720)
  self.behind = lg.newCanvas(1280, 720) -- blurred city + bokeh: what the drops refract
  self.fx = moonshine(1280, 720, moonshine.effects.glow).chain(moonshine.effects.vignette)
  self.fx.glow.min_luma = 0.86
  self.fx.glow.strength = 4
  self.fx.vignette.color = { 40, 18, 8 }
  self.fx.vignette.opacity = 0.7
  self.fx.vignette.radius = 0.85
end

function S:newRunner(anywhere)
  return {
    x = love.math.random(WX + 10, WX + WW - 10),
    y = anywhere and love.math.random(WY, WY + WH - 60) or WY,
    r = love.math.random(5, 9), v = love.math.random(30, 90), trail = {},
  }
end

function S:update(dt)
  self.t = self.t + dt
  for _, c in ipairs(self.cars) do
    c.x = c.x + c.v * dt * (c.lane == 0 and 1 or -1)
    if c.x > 1400 then c.x = -100 elseif c.x < -100 then c.x = 1400 end
  end
  for i, r in ipairs(self.runners) do
    -- drops stick, then slip: speed varies with noise
    local slip = love.math.noise(i * 3.1, self.t * 0.8)
    r.y = r.y + r.v * dt * (slip > 0.45 and 1.6 or 0.15)
    r.x = r.x + (love.math.noise(i, self.t * 2) - 0.5) * 12 * dt
    if #r.trail == 0 or r.y - r.trail[#r.trail][2] > 7 then r.trail[#r.trail + 1] = { r.x, r.y } end
    if #r.trail > 18 then table.remove(r.trail, 1) end
    if r.y > WY + WH then self.runners[i] = self:newRunner(false) end
  end
end

-- A raindrop: the blurred city, upside down and shrunk, inside a small circle.
function S:drop(x, y, r)
  lg.setScissor(x - r - 1, y - r - 1, r * 2 + 2, r * 2 + 2)
  lg.stencil(function() lg.ellipse("fill", x, y, r, r * 1.1) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  lg.setColor(1, 1, 1)
  lg.draw(self.behind, x, y, 0, -0.35, -0.35, x, y)
  lg.setStencilTest()
  lg.setScissor()
  lg.setColor(0, 0, 0, 0.3)
  lg.arc("line", "open", x, y, r, math.pi + 0.3, math.pi * 2 - 0.3)
  lg.setColor(1, 0.95, 0.85, 0.35)
  lg.arc("line", "open", x, y, r * 0.9, 0.4, math.pi - 0.4)
  lg.setColor(1, 1, 1, 0.8)
  lg.circle("fill", x - r * 0.35, y - r * 0.4, math.max(1, r * 0.22))
end

function S:drawBehind()
  lg.setColor(1, 1, 1)
  lg.draw(self.city)
  lg.setBlendMode("add")
  for _, l in ipairs(self.lights) do
    local tw = 0.75 + 0.25 * math.sin(self.t * 1.3 + l.p)
    lg.setColor(l.c[1], l.c[2], l.c[3], 0.45 * tw)
    lg.draw(self.bokeh, l.x, l.y, 0, l.r / 48, l.r / 48, 48, 48)
  end
  for _, c in ipairs(self.cars) do
    local y = WY + WH - 40 + c.lane * 16
    local red = c.lane == 0
    lg.setColor(red and 1 or 1, red and 0.2 or 0.95, red and 0.15 or 0.8, 0.6)
    lg.draw(self.bokeh, c.x, y, 0, 0.5, 0.5, 48, 48)
    lg.draw(self.bokeh, c.x + 40, y, 0, 0.5, 0.5, 48, 48)
  end
  lg.setBlendMode("alpha")
end

function S:drawWindow()
  lg.setColor(1, 1, 1)
  lg.setScissor(WX, WY, WW, WH)
  lg.draw(self.behind)
  -- condensation: a pale haze toward the bottom of the glass
  lg.setColor(1, 1, 1)
  lg.draw(self.haze, WX, WY)
  lg.setScissor()
  for _, b in ipairs(self.beads) do self:drop(b.x, b.y, b.r) end
  for _, r in ipairs(self.runners) do
    lg.setColor(0.8, 0.85, 1, 0.18)
    lg.setLineWidth(r.r * 0.7)
    if #r.trail > 1 then
      local pts = {}
      for _, p in ipairs(r.trail) do pts[#pts + 1] = p[1]; pts[#pts + 1] = p[2] end
      lg.line(pts)
    end
    self:drop(r.x, r.y, r.r)
  end
  -- wooden frame and mullions
  lg.setColor(gfx.hex("#3a2216"))
  lg.setLineWidth(22)
  lg.rectangle("line", WX - 11, WY - 11, WW + 22, WH + 22)
  lg.setLineWidth(14)
  lg.line(WX + WW / 2, WY, WX + WW / 2, WY + WH)
  lg.line(WX, WY + WH * 0.42, WX + WW, WY + WH * 0.42)
end

function S:cup(x, y, flip)
  -- saucer, mug, coffee with latte-art heart, handle
  lg.setColor(gfx.hex("#e9e2d6"))
  lg.ellipse("fill", x, y + 52, 110, 30)
  lg.setColor(gfx.hex("#cbbfae"))
  lg.ellipse("fill", x, y + 50, 70, 18)
  lg.setColor(gfx.hex("#ddd3c4"))
  lg.rectangle("fill", x - 62, y - 30, 124, 82)
  lg.ellipse("fill", x, y + 52, 62, 16)
  lg.setLineWidth(12)
  lg.ellipse("line", x + (flip and -78 or 78), y + 8, 20, 24)
  lg.setColor(gfx.hex("#ddd3c4"))
  lg.ellipse("fill", x, y - 30, 62, 18)
  lg.setColor(gfx.hex("#6b3e22"))
  lg.ellipse("fill", x, y - 28, 54, 14)
  lg.setColor(gfx.hex("#f3dcc0"))
  lg.push()
  lg.translate(x, y - 28)
  lg.scale(1, 0.32)
  gfx.fillConcave(gfx.heart(0, 2, 40))
  lg.pop()
  -- steam: three wobbling curves
  for k = 0, 2 do
    local pts = {}
    for i = 0, 8 do
      local yy = y - 44 - i * 18
      pts[#pts + 1] = x - 20 + k * 20 + math.sin(self.t * 1.6 + i * 0.7 + k * 2) * (4 + i * 2)
      pts[#pts + 1] = yy
    end
    lg.setColor(1, 1, 1, 0.12)
    lg.setLineWidth(6)
    lg.line(love.math.newBezierCurve(pts):render(4))
  end
end

function S:draw()
  lg.push("all")
  lg.setCanvas(self.behind)
  lg.clear(0, 0, 0, 1)
  self:drawBehind()
  lg.setCanvas({ self.windowCanvas, stencil = true })
  lg.clear(gfx.hex("#2a1810")) -- warm wall around the window
  self:drawWindow()
  lg.pop()
  self.fx(function()
    lg.setColor(1, 1, 1)
    lg.draw(self.windowCanvas)
    -- table
    local ty = 500
    lg.setColor(gfx.hex("#4a2a18"))
    lg.rectangle("fill", 0, ty, 1280, 220)
    for i = 0, 26 do
      lg.setColor(0.2, 0.1, 0.05, 0.25)
      local y = ty + 6 + i * 8 + math.sin(i * 2.3) * 3
      lg.line(0, y, 1280, y + math.sin(i) * 6)
    end
    lg.setColor(gfx.hex("#2e1a0e"))
    lg.rectangle("fill", 0, ty, 1280, 10)
    -- candle glow on the table
    local flick = 0.85 + love.math.noise(self.t * 7) * 0.3
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.25, 0.32 * flick)
    lg.draw(self.glow, 640, 590, 0, 7, 3.2, 64, 64)
    lg.setBlendMode("alpha")
    self:cup(430, 590, true)
    self:cup(850, 600, false)
    -- candle in a jar
    lg.setColor(1, 0.95, 0.85, 0.25)
    lg.rectangle("fill", 610, 560, 60, 80, 10)
    lg.setColor(gfx.hex("#f5ead6"))
    lg.rectangle("fill", 620, 590, 40, 46, 6)
    lg.setColor(0.1, 0.08, 0.06)
    lg.line(640, 590, 640, 580)
    local fh = 26 * flick
    lg.setColor(1, 0.7, 0.25)
    lg.ellipse("fill", 640, 572 - fh * 0.2, 7, fh * 0.6)
    lg.setColor(1, 0.95, 0.75)
    lg.ellipse("fill", 640, 574, 3.5, fh * 0.3)
    lg.setBlendMode("add")
    lg.setColor(1, 0.65, 0.3, 0.6 * flick)
    lg.draw(self.glow, 640, 566, 0, 1.6, 1.8, 64, 64)
    lg.setBlendMode("alpha")
    -- a single rose in a thin vase
    lg.setColor(0.7, 0.85, 0.95, 0.35)
    lg.rectangle("fill", 1060, 520, 30, 110, 12)
    lg.setColor(gfx.hex("#2f6b35"))
    lg.setLineWidth(4)
    lg.line(1075, 600, 1072, 430)
    lg.ellipse("fill", 1090, 480, 16, 7)
    for i = 0, 6 do
      local a = i * 1.9
      lg.setColor(0.75 - i * 0.04, 0.08, 0.15)
      lg.circle("fill", 1072 + math.cos(a) * (10 - i), 422 + math.sin(a) * (8 - i), 13 - i)
    end
  end)
end

return S
