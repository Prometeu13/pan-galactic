-- WARD C: NIGHT SHIFT. A quick game mock-up of the showcase's second Horror scene.
--
--   love ward-c              play
--   love ward-c --mute       play without sound
--   love ward-c --selftest   bots play the round (careful, reckless, idle) and the rules are checked
--   love ward-c --snapshots  save screenshots of key moments, then quit
--
-- Code map: src/game.lua (all the rules, no drawing), src/render.lua (the first-person
-- corridor, the room view, HUD and screens), src/sfx.lua (synthesized sounds),
-- src/selftest.lua (bots + checks). lib/ holds moonshine (film look) and shack (shake).

io.stdout:setvbuf("line")
love.filesystem.setRequirePath("lib/?.lua;lib/?/init.lua;?.lua;?/init.lua")

local Game = require("src.game")
local R = require("src.render")
local sfx = require("src.sfx")

local lg = love.graphics
local W, H = 1280, 720
local canvas, scale, ox, oy
local state = "title"          -- title / play
local g, attract
local titleT = 0
local wasMode

local function hasArg(name)
  for _, a in ipairs(arg or {}) do if a == name then return true end end
  return false
end

local function resize(w, h)
  scale = math.min(w / W, h / H)
  ox, oy = math.floor((w - W * scale) / 2), math.floor((h - H * scale) / 2)
end

local function render()
  lg.push("all")
  lg.setCanvas({ canvas, stencil = true })
  lg.clear(0, 0, 0, 1)
  if state == "title" then R.title(attract, titleT) else R.draw(g) end
  lg.pop()
end

local function newGame(seed)
  g = Game.new(seed)
  wasMode = "play"
  state = "play"
  sfx.loop("hum", 0.5)
end

-- `--snapshots`: stage a few moments and save them as PNGs.
local function snapshots()
  love.filesystem.createDirectory("snapshots")
  local function shot(name)
    render()
    canvas:newImageData():encode("png", "snapshots/" .. name .. ".png")
    print("  snapshots/" .. name .. ".png")
  end
  local function run(seconds, input)
    for _ = 1, math.floor(seconds * 60) do g:update(1 / 60, input) R.update(1 / 60) end
  end
  local function place(z, itZ)                 -- put you and it somewhere, standing still
    g.z, g.fig.z, g.fig.state, g.fig.exposure = z, itZ, "still", 0
    g.nextBlackout = 99
  end
  for _ = 1, 120 do attract:update(1 / 60) end
  titleT = 0.5
  shot("01_title")

  newGame(7)
  g.nextBlackout = 99
  run(1.2, { fwd = true })
  shot("02_start_of_round")
  g.z = 2.7
  g:use()
  run(1.1)
  shot("03_checking_bed_1")
  run(1.4)
  g.nextBlackout = 99
  -- walk on; let it come close, then catch it in the torch
  place(9.4, 14.2)
  run(0.3)
  shot("04_it_is_closer")
  g.blackout = 2
  run(0.4)
  shot("05_blackout_eyes")
  run(0.5, { light = true })
  shot("06_torch_in_the_dark")
  g.blackout = 0
  run(1.2, { light = true })
  g.nextBlackout = 99
  -- deeper in: the empty bed
  place(18.3, 27.5)
  run(0.4)
  g:use()
  run(1.1)
  shot("07_bed_5_is_empty")
  run(1.4)
  -- far end, dead lamps
  for _, k in ipairs({ 8, 9, 5 }) do g.lamps[k].dead = true end
  place(20.6, 25.2)
  run(0.6)
  shot("08_dead_lamps_far_end")
  -- caught
  g.fig.z = g.z + 1.25
  run(0.55)
  shot("09_caught")
  run(3)
  shot("10_game_over")
  -- a won shift
  newGame(7)
  for _, r in ipairs(g.rooms) do r.checked = true end
  g.checked = #g.rooms
  g.t, g.battery, g.stats.repels, g.stats.blackouts = 94, 0.35, 5, 11
  g:use()
  shot("11_shift_over")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

function love.load()
  lg.setDefaultFilter("linear", "linear")
  canvas = lg.newCanvas(W, H)
  resize(lg.getDimensions())
  R.load()
  sfx.load()
  attract = Game.new(3)             -- the title screen is the corridor with nobody in it
  attract.z = 2.2
  attract.fig.z = 13.8
  attract.nextBlackout = 4

  if hasArg("--selftest") then
    local ok = require("src.selftest").run(Game, R, render)
    love.event.quit(ok and 0 or 1)
  elseif hasArg("--snapshots") then
    snapshots()
    love.event.quit(0)
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)
  R.update(dt)
  if state == "title" then
    titleT = titleT + dt
    attract:update(dt)
    -- on the title it never arrives: it comes close in each blackout, then is gone again
    if attract.mode ~= "play" or attract.fig.z < 6 then
      attract = Game.new(3)
      attract.z, attract.fig.z, attract.nextBlackout = 2.2, 13.8, 4
    end
    return
  end
  local k = love.keyboard
  g:update(dt, {
    fwd = k.isDown("w", "up"),
    back = k.isDown("s", "down"),
    light = k.isDown("space", "lshift", "rshift") or love.mouse.isDown(1),
  })
  if g.mode ~= wasMode then
    if g.mode == "caught" then R.shake(30) end
    wasMode = g.mode
  end
end

function love.draw()
  render()
  lg.setCanvas()
  lg.clear(0, 0, 0)
  lg.setColor(1, 1, 1)
  lg.draw(canvas, ox, oy, 0, scale, scale)
end

function love.resize(w, h) resize(w, h) end

function love.keypressed(key)
  if key == "f11" then
    love.window.setFullscreen(not love.window.getFullscreen())
  elseif key == "escape" then
    if state == "play" then
      state = "title"
      sfx.stop("hum")
    else
      love.event.quit()
    end
  elseif state == "title" then
    newGame()
  elseif key == "r" and (g.mode == "dead" or g.mode == "won") then
    newGame()
  elseif key == "e" or key == "return" then
    g:use()
  end
end

function love.mousepressed(_, _, button)
  if state == "title" then newGame() elseif button == 2 then g:use() end
end
