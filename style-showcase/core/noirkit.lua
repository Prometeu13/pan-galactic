-- Shared plumbing for the extra Noir scenes: the film grade, the shadow light map,
-- the letterbox with a caption, and rain. (The first Noir scene keeps its own inline
-- copy so it reads as one self-contained recipe.)

local moonshine = require("moonshine")
local lg = love.graphics
local kit = {}

-- desaturate -> film grain -> vignette
function kit.grade()
  local fx = moonshine(1280, 720, moonshine.effects.desaturate)
    .chain(moonshine.effects.filmgrain)
    .chain(moonshine.effects.vignette)
  fx.desaturate.strength = 1
  fx.desaturate.tint = { 255, 250, 240 }
  fx.filmgrain.opacity = 0.3
  fx.filmgrain.size = 2
  fx.vignette.radius = 0.78
  fx.vignette.softness = 0.6
  fx.vignette.opacity = 0.6
  return fx
end

-- Render the lighter's lights into `canvas` over an ambient level, then multiply the
-- result over whatever has been drawn so far on `target`.
function kit.lightMap(lighter, canvas, ambient, target, passes)
  lg.setCanvas({ canvas, stencil = true })
  lg.clear(ambient, ambient, ambient * 1.1, 1)
  lg.setBlendMode("add")
  for _ = 1, passes or 1 do lighter:drawLights() end
  lg.setBlendMode("alpha")
  lg.setCanvas(target)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(canvas)
  lg.setBlendMode("alpha")
end

-- The same idea without a library: draw your own light shapes into a canvas (additive,
-- over an ambient level), then multiply it over the scene.
--   kit.beginLight(canvas, ambient)  ... draw bright shapes ...  kit.endLight(canvas, target)
function kit.beginLight(canvas, ambient)
  lg.setCanvas(canvas)
  lg.clear(ambient, ambient, ambient * 1.15, 1)
  lg.setBlendMode("add")
end

function kit.endLight(canvas, target)
  lg.setBlendMode("alpha")
  lg.setCanvas(target)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(canvas)
  lg.setBlendMode("alpha")
end

function kit.newRain(n, seed)
  love.math.setRandomSeed(seed or 5)
  local rain = {}
  for i = 1, n do
    rain[i] = { x = love.math.random(-200, 1300), y = love.math.random(-720, 720), v = love.math.random(900, 1300), l = love.math.random(14, 30) }
  end
  return rain
end

function kit.updateRain(rain, dt)
  for _, r in ipairs(rain) do
    r.y = r.y + r.v * dt
    r.x = r.x + r.v * 0.18 * dt
    if r.y > 720 then r.y, r.x = r.y - 780 - love.math.random(0, 200), love.math.random(-200, 1300) end
  end
end

function kit.drawRain(rain, alpha, x1, y1, x2, y2)
  lg.setLineWidth(1.5)
  lg.setColor(0.85, 0.88, 0.95, alpha or 0.28)
  for _, r in ipairs(rain) do
    if not x1 or (r.x > x1 and r.x < x2 and r.y > y1 and r.y < y2) then
      lg.line(r.x, r.y, r.x - r.l * 0.18, r.y - r.l)
    end
  end
end

-- Cinematic bars and a typewritten caption in the lower bar.
function kit.letterbox(caption, font, t)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", 0, 0, 1280, 62)
  lg.rectangle("fill", 0, 720 - 62, 1280, 62)
  lg.setFont(font)
  lg.setColor(0.92, 0.92, 0.92)
  local shown = t and caption:sub(1, math.floor(t * 28)) or caption
  lg.printf(shown, 0, 720 - 44, 1280, "center")
end

return kit
