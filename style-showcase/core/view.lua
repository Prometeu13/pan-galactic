-- Virtual 1280x720 screen, letterboxed into whatever size the window is.
-- Every scene draws in virtual pixels, so the art looks the same at any window size.

local view = {
  W = 1280,
  H = 720,
  scale = 1,
  ox = 0,
  oy = 0,
}

function view.init()
  -- msaa smooths the edges of polygons and lines drawn into the canvas.
  view.canvas = love.graphics.newCanvas(view.W, view.H, { msaa = 4 })
  view.resize(love.graphics.getDimensions())
end

function view.resize(w, h)
  view.scale = math.min(w / view.W, h / view.H)
  view.ox = math.floor((w - view.W * view.scale) / 2)
  view.oy = math.floor((h - view.H * view.scale) / 2)
end

function view.toVirtual(x, y)
  return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

function view.mouse()
  if not love.mouse then return view.W / 2, view.H / 2 end
  return view.toVirtual(love.mouse.getPosition())
end

function view.present()
  love.graphics.setCanvas()
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(view.canvas, view.ox, view.oy, 0, view.scale, view.scale)
  love.graphics.setBlendMode("alpha")
end

return view
