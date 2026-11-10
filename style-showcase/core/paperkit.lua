-- Papercraft toolkit shared by the extra Papercraft scenes. (The first scene keeps its
-- own inline copy so it reads as one self-contained recipe.)
--
--   kit.cutout(shape, color, edge, lift)  -- soft shadow, fill, lit cut edge
--   kit.fibre()                           -- paper fibre texture
--   kit.finish(fibre)                     -- multiply the fibre over the whole frame
--   kit.frame(w, color)                   -- a shadow-box frame around the diorama
--   kit.string(x, y1, y2)                 -- a thread something hangs from
--   kit.shade(color, amount)              -- lighter (+) or darker (-) paper

local gfx = require("core.gfx")
local vivid = require("vivid")
local lg = love.graphics
local kit = {}

function kit.shade(c, amt)
  local r, g, b
  if amt >= 0 then r, g, b = vivid.lighten(amt, c[1], c[2], c[3]) else r, g, b = vivid.darken(-amt, c[1], c[2], c[3]) end
  return { r, g, b }
end

-- shape(): draws the filled silhouette with the current colour.
-- edge(): optional, draws lines along the top edges (they get a lighter colour).
-- lift: how far this sheet floats above the one behind (scales the shadow).
function kit.cutout(shape, color, edge, lift, shadowAlpha)
  lift = lift or 1
  for k = 3, 1, -1 do
    lg.push()
    lg.translate(k * 3 * lift, k * 4 * lift)
    lg.setColor(0.08, 0.04, 0.14, shadowAlpha or 0.09)
    shape()
    lg.pop()
  end
  lg.setColor(color)
  shape()
  if edge then
    lg.setColor(kit.shade(color, 0.12))
    lg.setLineWidth(3)
    edge()
  end
end

function kit.fibre()
  local d = love.image.newImageData(640, 360)
  d:mapPixel(function(x, y)
    local fib = love.math.noise(x * 0.9, y * 0.12) * 0.05 + love.math.noise(x * 0.12, y * 0.9) * 0.04
    local v = 1 - fib - gfx.fbm(x * 0.02, y * 0.02, 2) * 0.04
    return v, v, v, 1
  end)
  return lg.newImage(d)
end

function kit.finish(fibre)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(fibre, 0, 0, 0, 2, 2)
  lg.setBlendMode("alpha")
end

function kit.frame(w, color)
  -- the frame's shadow falling into the box
  for k = 1, 5 do
    lg.setColor(0.05, 0.02, 0.1, 0.07)
    lg.rectangle("fill", 0, 0, 1280, w + k * 6)
    lg.rectangle("fill", 0, 0, w + k * 6, 720)
  end
  lg.setColor(color)
  lg.rectangle("fill", 0, 0, 1280, w)
  lg.rectangle("fill", 0, 720 - w, 1280, w)
  lg.rectangle("fill", 0, 0, w, 720)
  lg.rectangle("fill", 1280 - w, 0, w, 720)
  lg.setColor(kit.shade(color, 0.1))
  lg.setLineWidth(2)
  lg.rectangle("line", w, w, 1280 - w * 2, 720 - w * 2)
  lg.setColor(kit.shade(color, -0.2))
  lg.rectangle("line", 4, 4, 1272, 712)
end

function kit.string(x, y1, y2)
  lg.setColor(0.25, 0.2, 0.25, 0.7)
  lg.setLineWidth(1.2)
  lg.line(x, y1, x, y2)
end

-- A ridge (list of points) closed down to the bottom of the screen, as a filled shape
-- function and an edge function, ready for kit.cutout.
function kit.ridgeShape(pts, bottom)
  return function() gfx.fillRidge(pts, bottom or 760) end, function() lg.line(pts) end
end

return kit
