-- WARD C: NIGHT SHIFT. A game mock-up grown out of the showcase's second Horror scene.
--
--   love ward-c              play
--   love ward-c --mute       play without sound
--   love ward-c --selftest   rule checks, then bots play the round and the escape
--   love ward-c --snapshots  save screenshots of key moments, then quit
--
-- Code map: src/game.lua (all the rules, no drawing), src/render.lua (the first-person
-- corridors, the room and hiding views, HUD, ward plan and screens), src/sfx.lua
-- (synthesized sounds), src/selftest.lua (rule checks + bots).
-- lib/ holds moonshine (film look) and shack (shake).

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

local function newAttract()
  attract = Game.new(3)             -- the title screen is the corridor with nobody in it
  attract.z = 2.2
  attract.figs[1].p = 13.8
  attract.nextBlackout = 4
end

local function newGame(seed)
  g = Game.new(seed)
  wasMode = "play"
  state = "play"
  R.lastSeen = {}
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
  local A, B
  local function place(seg, z, dir, aP, aSeg)     -- put you and figure A somewhere, standing still
    g.seg, g.z, g.dir, g.turn, g.fade = seg, z, dir, nil, nil
    A.seg, A.p, A.state, A.exposure = aSeg or "main", aP, "still", 0
    g.nextBlackout = 99
    g.blackout = 0
  end
  local function check(bed)
    g.z = g.rooms[bed].z - g.dir * 1.3
    g:use()
  end
  for _ = 1, 120 do attract:update(1 / 60) end
  titleT = 0.5
  shot("01_title")

  newGame(7)
  A, B = g.figs[1], g.figs[2]
  g.nextBlackout = 99
  run(1.2, { fwd = true })
  shot("02_start_of_round")
  place("main", 2.7, 1, Game.FAR_HOME)
  check(1)
  run(1.1)
  shot("03_checking_bed_1")
  run(1.4)
  place("main", 6.7, 1, Game.FAR_HOME)
  check(2)
  run(2.5)
  shot("04_bed_2_asks_for_water")
  place("main", 9.4, 1, 14.2)
  run(0.3)
  shot("05_it_is_closer")
  g.blackout = 2
  run(0.4)
  shot("06_blackout_eyes")
  run(0.5, { light = true })
  shot("07_torch_in_the_dark")
  run(1.2, { light = true })
  -- turned around: walking away from it, the station ahead
  place("main", 7.5, -1, 15)
  run(0.6, { fwd = true })
  shot("08_back_turned_station_ahead")
  -- the side corridor
  place("main", 11.3, 1, 24)
  run(0.2)
  shot("09_side_corridor_opening")
  g.z = 12.4
  g:use()
  run(1.6, { fwd = true })
  shot("10_in_the_side_corridor")
  place("annex", Game.ANNEX - 1.6, 1, 24)
  run(0.2)
  shot("11_supply_shelves")
  g:use()
  run(1.5)
  -- coming back out: it is standing in the junction
  place("annex", 4.6, -1, Game.J + 0.4)
  run(0.3)
  shot("12_it_waits_at_the_junction")
  -- hide in Bed 1's room; it comes to the door
  place("main", 2.7, 1, 9.5)
  g:use()
  run(1.0)
  shot("13_hiding_it_is_coming")
  run(4.4)
  shot("14_hiding_it_is_outside")
  run(3.5)
  shot("15_hiding_it_walks_on")
  run(5)
  g:use()
  -- deeper in: the empty bed, and what was under it
  A.home.p = Game.FAR_HOME
  place("main", 18.7, 1, 27.5)
  check(5)
  run(1.1)
  shot("16_bed_5_is_empty")
  run(1.4)
  for _, k in ipairs({ 8, 9, 5 }) do g.lamps.main[k].dead = true end
  place("main", 23.4, -1, Game.FAR_HOME)
  B.inside, B.seg, B.p, B.state = false, "main", 19.4, "still"
  run(0.3)
  shot("17_the_second_one")
  -- the EXIT, with it gone to the other end
  B.inside = true
  A.home.p = Game.NEAR_HOME
  place("main", Game.LEN - 1.8, 1, Game.NEAR_HOME)
  run(0.3)
  shot("18_the_exit")
  -- caught
  place("main", 20.6, 1, 21.85)
  run(0.55)
  shot("19_caught")
  run(3)
  shot("20_game_over")
  -- the two endings
  newGame(7)
  for _, r in ipairs(g.rooms) do r.checked = true if r.request then r.request = "done" end end
  g.checked = #g.rooms
  g.t, g.battery, g.stats.repels, g.stats.blackouts, g.stats.hides = 131, 0.35, 5, 14, 2
  g:use()
  shot("21_shift_over")
  newGame(7)
  g.rooms[1].checked, g.rooms[2].checked, g.checked = true, true, 2
  g.t, g.battery, g.stats.repels, g.stats.blackouts, g.stats.hides = 83, 0.1, 4, 9, 1
  g:win("exit")
  shot("22_left_by_the_exit")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

function love.load()
  lg.setDefaultFilter("linear", "linear")
  canvas = lg.newCanvas(W, H)
  resize(lg.getDimensions())
  R.load()
  sfx.load()
  newAttract()

  if hasArg("--selftest") then
    local ok = require("src.selftest").run(Game, R, render)
    lg.setCanvas()
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
    if attract.mode ~= "play" or attract.figs[1].p < 6 then newAttract() end
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
      newAttract()
    else
      love.event.quit()
    end
  elseif state == "title" then
    newGame()
  elseif key == "r" and (g.mode == "dead" or g.mode == "won") then
    newGame()
  elseif key == "e" or key == "return" then
    g:use()
  elseif key == "q" or key == "a" or key == "d" or key == "left" or key == "right" or key == "tab" then
    g:turnAround()
  end
end

function love.mousepressed(_, _, button)
  if state == "title" then newGame()
  elseif button == 2 then g:use()
  elseif button == 3 then g:turnAround() end
end
