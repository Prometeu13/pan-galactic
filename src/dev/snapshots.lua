-- `love . --snapshots`: renders every screen to <save folder>/snapshots/*.png.
-- Handy for checking visuals without playing (and on a headless box via xvfb-run).
local scenes = require("src.core.scenes")
local rngLib = require("src.core.rng")
local rng = require("src.core.rng")
local fx = require("src.ui.fx")
local Guide = require("src.ui.guide")
local Run = require("src.game.run")
local Galaxy = require("src.game.galaxy")

local M = {}

local function step(n)
  for _ = 1, n do
    scenes.update(1 / 60)
    fx.update(1 / 60)
    Guide.update(1 / 60)
  end
end

local function shot(name)
  local c = love.graphics.newCanvas(1280, 720)
  love.graphics.setCanvas({ c, stencil = true })
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.origin()
  scenes.call("draw")
  fx.draw()
  love.graphics.setCanvas()
  c:newImageData():encode("png", "snapshots/" .. name .. ".png")
  print("  snapshots/" .. name .. ".png")
end

local function freshRun()
  local run = Run.new()
  run.day = 2
  run.flurbos = 85
  run.planet = Galaxy.planet(rngLib.new(4242))
  for _, id in ipairs(run.planet.pool) do Run.add(run, id, 2) end
  Run.learn(run, run.planet.pool[1])
  return run
end

function M.run()
  love.filesystem.createDirectory("snapshots")
  print("Writing snapshots to " .. love.filesystem.getSaveDirectory())
  rng.seed(4242)

  scenes.instant(require("src.scenes.title"))
  step(60); shot("01_title")

  freshRun()
  local H = require("src.scenes.hitchhike")
  scenes.instant(H)
  step(60); shot("02_hitchhike")
  for _, r in ipairs(H.rides) do
    if r.poem then H:choose(r) break end
  end
  step(90); shot("03_poetry_barge")

  local run = freshRun()
  local F = require("src.scenes.forage")
  scenes.instant(F)
  step(90); shot("04_forage_arrival")
  F.chef.x, F.chef.y = F.items[1].x - 60, F.items[1].y
  step(400); shot("05_forage")

  local S = require("src.scenes.shop")
  run = freshRun()
  scenes.instant(S)
  local guard = 0
  while not (S.queue[1] and S.queue[1].order) and guard < 900 do step(1); guard = guard + 1 end
  step(30)
  local sol = S.queue[1].order.solution
  for i = 1, math.min(2, #sol) do S:addToPot(sol[i]) end
  step(20); shot("06_shop_order")

  S:dump()
  for _, id in ipairs(sol) do S:addToPot(id) end
  S:serve()
  step(100); shot("07_shop_result")
  step(200)

  -- force a kaboom for the screenshot
  guard = 0
  while not (S.queue[1] and S.queue[1].order and S.queue[1].state == "wait") and guard < 1200 do step(1); guard = guard + 1 end
  Run.add(run, "joyberry"); Run.add(run, "panicpepper")
  S:dump()
  S:addToPot("joyberry"); S:addToPot("panicpepper")
  S:serve()
  step(84); shot("08_shop_kaboom")

  S.over = true
  S.shift = { served = 5, earned = 142, walkouts = 1, explosions = 1, transcendent = 2, stars = 22, count = 6 }
  step(5); shot("09_shift_over")

  run.lastShift = S.shift
  run.rumors = 1
  scenes.instant(require("src.scenes.outfitter"))
  step(60); shot("10_outfitter")
end

return M
