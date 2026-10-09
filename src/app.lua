-- LÖVE callbacks and startup.
local vp = require("src.core.viewport")
local scenes = require("src.core.scenes")
local rng = require("src.core.rng")
local fx = require("src.ui.fx")
local Guide = require("src.ui.guide")
local T = require("src.ui.theme")

local function hasArg(name)
  for _, a in ipairs(arg or {}) do
    if a == name then return true end
  end
  return false
end

local function argValue(name)
  for i, a in ipairs(arg or {}) do
    if a == name then return arg[i + 1] end
  end
end

function love.load()
  local seed = tonumber(argValue("--seed") or "") or os.time()
  rng.seed(seed)

  if hasArg("--selftest") then
    local ok = require("src.dev.selftest").run()
    love.event.quit(ok and 0 or 1)
    return
  end

  vp.resize(love.graphics.getDimensions())
  pcall(require("src.core.sfx").load)

  if hasArg("--snapshots") then
    require("src.dev.snapshots").run()
    love.event.quit(0)
    return
  end

  scenes.switch(require("src.scenes.title"))
end

function love.resize(w, h) vp.resize(w, h) end

function love.update(dt)
  dt = math.min(dt, 1 / 20)
  scenes.update(dt)
  fx.update(dt)
  Guide.update(dt)
end

function love.draw()
  love.graphics.clear(0, 0, 0)
  love.graphics.push()
  vp.apply()
  love.graphics.setScissor(vp.ox, vp.oy, vp.w * vp.scale, vp.h * vp.scale)
  love.graphics.push()
  love.graphics.translate(fx.offset())
  scenes.call("draw")
  fx.draw()
  love.graphics.pop()
  if scenes.fade > 0 then
    love.graphics.setColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], scenes.fade)
    love.graphics.rectangle("fill", 0, 0, vp.w, vp.h)
  end
  love.graphics.setScissor()
  love.graphics.pop()
end

function love.mousepressed(x, y, b)
  if scenes.busy() then return end
  local vx, vy = vp.toVirtual(x, y)
  scenes.call("mousepressed", vx, vy, b)
end

function love.mousereleased(x, y, b)
  local vx, vy = vp.toVirtual(x, y)
  scenes.call("mousereleased", vx, vy, b)
end

function love.wheelmoved(dx, dy) scenes.call("wheelmoved", dx, dy) end

function love.keypressed(key)
  if key == "escape" then
    if scenes.current == require("src.scenes.title") then love.event.quit() return end
    scenes.switch(require("src.scenes.title"))
    return
  end
  if key == "f11" then love.window.setFullscreen(not love.window.getFullscreen()) return end
  if scenes.busy() then return end
  scenes.call("keypressed", key)
end
