-- Gutter Wings: a noir pigeon survival prototype.
--
--   love pigeon-noir              play
--   love pigeon-noir --mute       play without sound
--   love pigeon-noir --selftest   a bot plays through the rules and hazards (exit 0 = pass)
--   love pigeon-noir --snapshots  save screenshots of key moments, then quit
--
-- Code map: src/game.lua (rules, hazards, HUD), src/pigeon.lua (Gus), src/render.lua
-- (drawing + the two-tone shader), src/city.lua (layout), src/content.lua (all the
-- writing), src/sfx.lua (synthesized sound), src/selftest.lua.

io.stdout:setvbuf("line")

local R = require("src.render")
local game = require("src.game")
local Pigeon = require("src.pigeon")
local text = require("src.content")
local sfx = require("src.sfx")

local lg = love.graphics
local W, H = 1280, 720
local canvas, scale, ox, oy
local state, play
local title = { t = 0 }
local drawTitle, render, snapshots, newGame

local function hasArg(name)
  for _, a in ipairs(arg or {}) do if a == name then return true end end
  return false
end

local function resize(w, h)
  scale = math.min(w / W, h / H)
  ox, oy = math.floor((w - W * scale) / 2), math.floor((h - H * scale) / 2)
end

function newGame()
  play = game.new()
  state = "play"
end

function drawTitle()
  lg.push("all")
  lg.setCanvas(R.scene)
  lg.clear(0, 0, 0, 1)
  R.backdrop(title.t * 30, 0, title.t, 1170, 90) -- moon in the top-right corner, clear of the title
  -- a lamp, a wire, and Gus sitting on it
  R.lamp({ x = 1150, y = 380 }, title.t)
  lg.setColor(0.85, 0.85, 0.85)
  lg.setLineWidth(2)
  lg.line(0, 470, 640, 488, 1280, 470)
  title.pigeon:draw(title.t)
  lg.pop()
  R.present(title.t, 0)
  R.rainDraw()
  local f = game.fonts
  lg.setFont(f.title)
  lg.setColor(1, 1, 1)
  lg.printf(text.title, 0, 110, W, "center")
  lg.setColor(0.9, 0.08, 0.08)
  lg.rectangle("fill", 330, 232, 620, 8)
  lg.setFont(f.caption)
  lg.setColor(1, 1, 1)
  lg.printf(text.subtitle, 0, 256, W, "center")
  lg.setColor(1, 1, 1, 0.5 + 0.35 * math.sin(title.t * 3))
  lg.printf("press any key", 0, 610, W, "center")
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.6)
  lg.printf("arrows / A D: walk     Space: flap (hold to glide)     Down: drop     E: peck     Esc: title", 0, 662, W, "center")
end

function render()
  lg.push("all")
  lg.setCanvas(canvas)
  lg.clear(0, 0, 0, 1)
  if state == "title" then drawTitle() else play:draw() end
  lg.pop()
end

-- `--snapshots`: stage a few moments and save them as PNGs.
function snapshots()
  love.filesystem.createDirectory("snapshots")
  local function shot(name)
    render()
    canvas:newImageData():encode("png", "snapshots/" .. name .. ".png")
    print("  snapshots/" .. name .. ".png")
  end
  local function step(g, seconds, input)
    g.input = input or {}
    for _ = 1, math.floor(seconds * 60) do g:update(1 / 60, true); g.input.flapPressed = false end
  end
  local function place(g, x, y, dir)
    local p = g.pigeon
    p.x, p.y, p.vx, p.vy, p.dir = x, y, 0, 0, dir or 1
    p.on = nil
    g.camX = math.max(0, math.min(6400 - 1280, x - 640 + p.dir * 120))
  end

  state = "title"
  for _ = 1, 120 do love.update(1 / 60) end
  shot("01_title")

  newGame()
  step(play, 3)
  shot("02_start_diner")

  -- the alley cat stalking
  play.captions = {}
  place(play, 760, 600, -1)
  step(play, 0.6, { left = true })
  shot("03_alley_cat")

  -- fluttering up the fire escape
  play.captions, play.firsts.cat = {}, true
  for _, cat in ipairs(play.c.cats) do cat.state, cat.x = "idle", cat.home end
  place(play, 830, 450, 1)
  step(play, 0.25, { flapPressed = true, flapHeld = true, right = true })
  shot("04_fire_escape")

  -- down in the road for fat crumbs, a taxi coming
  play.captions = {}
  place(play, 2990, 668, 1)
  step(play, 0.3)
  play.cars = { { x = 2990 - 520, dir = 1, speed = 0, honked = true } }
  play.lightning = 99
  step(play, 0.1)
  shot("05_road_taxi")

  -- under the hotel's neon, by a steam vent and a lamp
  play.cars = {}
  place(play, 3420, 600, 1)
  step(play, 1.2, { right = true })
  shot("06_bar_vent")

  -- a lightning flash over the rooftops
  play.captions = {}
  place(play, 2400, 200, 1)
  step(play, 0.1, { flapHeld = true })
  play.flashT, play.flash = 0.02, 1
  play:updateLightning(0)
  shot("07_lightning")

  -- death screen
  play.flashT, play.flash = nil, 0
  play:die("cat")
  step(play, 1.5)
  shot("08_feathered")

  -- the ending at Sal's
  play:respawn()
  play.captions = {}
  place(play, 6000, 260, 1)
  step(play, 0.8, { right = true })
  step(play, 1.5)
  shot("09_sals_coop")
  step(play, 8)
  shot("10_morning")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

function love.load()
  lg.setDefaultFilter("linear", "linear")
  canvas = lg.newCanvas(W, H, { msaa = 4 })
  resize(lg.getDimensions())
  game.fonts = {
    small = lg.newFont(15), caption = lg.newFont(22), clock = lg.newFont(40),
    big = lg.newFont(84), title = lg.newFont(104),
  }
  R.load()
  sfx.load()
  title.pigeon = Pigeon.new(620, 486)
  title.pigeon.on = { kind = "wire", x1 = 0, x2 = 1280, y = 486 }
  state = "title"

  if hasArg("--selftest") then
    require("src.selftest").run(game)
    love.event.quit(0)
  elseif hasArg("--snapshots") then
    snapshots()
    love.event.quit(0)
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)
  if state == "title" then
    title.t = title.t + dt
    R.updateRain(dt)
    sfx.loop("rain", 0.5)
    -- Gus shuffles along the wire now and then
    local p = title.pigeon
    p.walk = p.walk + dt * ((math.sin(title.t * 0.7) > 0.6) and 9 or 0)
  else
    play:update(dt)
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

function love.keypressed(k)
  if k == "f11" then
    love.window.setFullscreen(not love.window.getFullscreen())
  elseif k == "escape" then
    if state == "play" then state = "title" else love.event.quit() end
  elseif state == "title" then
    sfx.play("coo", 1, 0.8)
    newGame()
  else
    play:keypressed(k)
  end
end
