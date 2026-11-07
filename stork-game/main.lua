-- Inkwing: a cozy ink-wash adventure prototype. You are a black stork.
--
--   love stork-game              play
--   love stork-game --selftest   headless-ish checks: a bot finishes the game (exit 0 = pass)
--   love stork-game --snapshots  save screenshots of the title and key moments, then quit
--
-- Code map: src/game.lua (rules, quests, HUD), src/stork.lua (the bird), src/scenery.lua
-- (painting the valley), src/world.lua (layout), src/ink.lua (brush toolkit),
-- src/content.lua (all the writing), src/sfx.lua (synthesized sounds).

io.stdout:setvbuf("line")

local ink = require("src.ink")
local scenery = require("src.scenery")
local game = require("src.game")
local Stork = require("src.stork")
local text = require("src.content")
local sfx = require("src.sfx")

local lg = love.graphics
local W, H = 1280, 720
local canvas, scale, ox, oy
local state, play
local drawTitle, snapshots, newGame -- defined below
local title = { t = 0 }

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
  lg.clear(ink.PAPER)
  if state == "title" then drawTitle() else play:draw() end
  lg.pop()
end

-- `--snapshots`: stage a few moments of the game and save them as PNGs.
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
  local function place(g, x, air, y)
    local s = g.stork
    s.x, s.air, s.vx, s.vy = x, air, 0, 0
    s.y = y or require("src.world").ground(x)
    g.camX = math.max(0, math.min(require("src.world").W - 1280, x - 640 + s.dir * 140))
  end

  state = "title"
  for _ = 1, 150 do love.update(1 / 60) end
  shot("01_title")

  newGame()
  step(play, 2.5)
  shot("02_intro")

  -- reading the marsh seal: haiku + the ink spreading
  while #play.dialogue > 0 do play:advance() end
  place(play, play.w.seals[1].x - 30, false)
  play:interact()
  step(play, 2.2)
  shot("03_seal_reveal")

  play.haiku = nil
  -- flying past the nest cliff, carrying a twig
  play.stork.carry.twigs = 1
  play.stork.dir = -1
  place(play, 520, true, 260)
  step(play, 0.4, { left = true, flapHeld = true })
  shot("04_flight_nest")

  -- the village and the fisherman
  play.revealTarget[2], play.reveal[2] = 1, 1
  play.stork.dir = 1
  place(play, 2600, false)
  step(play, 0.2)
  play:interact()
  step(play, 2.5)
  shot("05_fisherman")
  while #play.dialogue > 0 do play:advance() end

  play.haiku = nil
  -- bamboo grove, wading the river toward it
  place(play, 3380, false)
  step(play, 0.5, { right = true })
  shot("06_bamboo")

  play.haiku = nil
  -- the pond, painted in
  play.revealTarget[3], play.reveal[3] = 1, 1
  place(play, 4330, false)
  step(play, 1, { right = true })
  shot("07_pond")

  play.haiku = nil
  -- the ending at dusk
  play.nest.twigs, play.nest.fed = 5, 2
  play.stork.carry.fish = 1
  place(play, play.nest.x - 20, true, play.nest.y + 50)
  play:interact()
  while #play.dialogue > 0 do play:advance() end
  play.revealTarget[1], play.reveal[1] = 1, 1
  place(play, 1900, true, 300)
  step(play, 9, { flapHeld = true })
  place(play, 2050, true, 280)
  shot("08_ending_dusk")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

function newGame()
  play = game.new()
  state = "play"
end

function love.load()
  lg.setDefaultFilter("linear", "linear")
  canvas = lg.newCanvas(W, H, { msaa = 4 })
  resize(lg.getDimensions())
  love.math.setRandomSeed(os.time())
  game.paper = ink.paper(W, H)
  game.fonts = {
    small = lg.newFont(16), body = lg.newFont(22), region = lg.newFont(30),
    haiku = lg.newFont(30), title = lg.newFont(110), sub = lg.newFont(22),
  }
  scenery.load()
  sfx.load()
  title.stork = Stork.new(-100)
  title.stork.air, title.stork.y, title.stork.dir = true, 300, 1
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
    local s = title.stork
    s:update(dt, { right = true, flapPressed = (title.t % 1.6) < dt, flapHeld = true })
    if s.x > W + 120 then s.x, s.y = -120, 260 + love.math.random(0, 80) end
  else
    play:update(dt)
  end
end

function drawTitle()
  lg.setColor(1, 1, 1)
  lg.draw(game.paper)
  scenery.backdrop(title.t * 20, function() return 1 end, title.t)
  title.stork:draw(title.t)
  local f = game.fonts
  lg.setFont(f.title)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.92)
  lg.printf(text.title, 0, 110, W, "center")
  ink.stroke({ 400, 250, 640, 238, 880, 252 }, 14, 0.8, 0.4)
  ink.seal(930, 160, 46, 0.9)
  lg.setFont(f.sub)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.7)
  lg.printf(text.subtitle, 0, 278, W, "center")
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.45 + 0.3 * math.sin(title.t * 3))
  lg.printf("press any key", 0, 600, W, "center")
  lg.setFont(f.small)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.5)
  lg.printf("arrows / A D: walk     Space: fly (hold to glide)     E: peck & talk     Esc: title", 0, 660, W, "center")
end

function love.draw()
  render()
  lg.setCanvas()
  lg.clear(0.05, 0.05, 0.06)
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
    sfx.play("chime", 1, 0.6)
    newGame()
  else
    play:keypressed(k)
  end
end

