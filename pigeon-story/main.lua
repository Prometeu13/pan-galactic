-- BREADCRUMBS: a noir pigeon story, in the style of the showcase's Noir scene.
--
--   love pigeon-story              play
--   love pigeon-story --mute       play without sound
--   love pigeon-story --selftest   a bot plays the whole story twice (tender and hard-boiled)
--   love pigeon-story --snapshots  save screenshots of key moments, then quit
--
-- Code map: src/story.lua (ALL the writing and the story logic as data), src/game.lua
-- (story engine, dialogue, film look), src/scenes.lua (the four painted scenes),
-- src/pigeon.lua (Gus and every other bird), src/sfx.lua, src/selftest.lua.
-- lib/ holds moonshine (film grade) and lighter (shadows), same as the style showcase.

io.stdout:setvbuf("line")
love.filesystem.setRequirePath("lib/?.lua;lib/?/init.lua;?.lua;?/init.lua")

local game = require("src.game")
local scenes = require("src.scenes")
local story = require("src.story")
local sfx = require("src.sfx")

local lg = love.graphics
local W, H = 1280, 720
local canvas, scale, ox, oy
local state, play, title
local titleT = 0

local function hasArg(name)
  for _, a in ipairs(arg or {}) do if a == name then return true end end
  return false
end

local function resize(w, h)
  scale = math.min(w / W, h / H)
  ox, oy = math.floor((w - W * scale) / 2), math.floor((h - H * scale) / 2)
end

local function drawTitle()
  title:draw()                     -- the alley and Sal's empty bench, graded
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", 0, 0, W, 62)
  lg.rectangle("fill", 0, H - 62, W, 62)
  local f = game.fonts
  lg.setColor(0, 0, 0, 0.55)                      -- a dark band so the title reads over the wall
  lg.rectangle("fill", 0, 104, W, 170)
  lg.setFont(f.title)
  lg.setColor(0, 0, 0, 0.55)
  lg.printf(story.title, 4, 124, W, "center")
  lg.setColor(1, 1, 1)
  lg.printf(story.title, 0, 120, W, "center")
  lg.setFont(f.body)
  lg.setColor(0.85, 0.85, 0.85)
  lg.printf(story.subtitle, 0, 230, W, "center")
  lg.setFont(f.small)
  lg.setColor(1, 1, 1, 0.5 + 0.35 * math.sin(titleT * 3))
  lg.printf("press any key", 0, H - 42, W, "center")
end

local function render()
  lg.push("all")
  lg.setCanvas({ canvas, stencil = true })
  lg.clear(0, 0, 0, 1)
  if state == "title" then drawTitle() else play:draw() end
  lg.pop()
end

local function newGame()
  play = game.new()
  state = "play"
end

-- `--snapshots`: walk through the story and save key moments as PNGs.
local function snapshots()
  love.filesystem.createDirectory("snapshots")
  local function shot(name)
    render()
    canvas:newImageData():encode("png", "snapshots/" .. name .. ".png")
    print("  snapshots/" .. name .. ".png")
  end
  local T = require("src.selftest")
  local function step(s) for _ = 1, math.floor(s * 60) do play:update(1 / 60, true) end end
  local function finishTalk() T.closeAll(play) end

  for _ = 1, 90 do title:update(1 / 60, true) end
  titleT = 1.5
  shot("01_title")

  newGame()
  step(1.6)
  shot("02_chapter_card")
  play:beginPlay()
  finishTalk()
  T.goTo(play, "vinnie")
  play:interact()
  step(2)
  shot("03_alley_vinnie")
  play:advance()
  shot("04_alley_choice")
  T.finishChapter(play, { 2, 1 })

  -- chapter two: listening in from the dumpster
  play:beginPlay()
  finishTalk()
  T.goTo(play, "backdoor")
  play:interact()
  step(0.4)
  play:advance(); play:advance(); step(1.5)
  shot("05_diner_overheard")
  T.finishChapter(play, { 1 })

  -- chapter three: the flock gathers on the roof
  play:beginPlay()
  finishTalk()
  for _, id in ipairs({ "rosa", "tony" }) do
    T.goTo(play, id)
    play:interact()
    T.answer(play, { 2 })
  end
  T.goTo(play, "coop")
  play.gus.perch, play.gus.y = nil, 600
  step(1.2)
  shot("06_roof_flock")
  T.finishChapter(play, { 1 })

  -- chapter four: the ledge, the window, the dawn
  play:beginPlay()
  finishTalk()
  T.goTo(play, "window")
  step(1.0)
  shot("07_hospital_ledge")
  play:interact()
  T.closeAll(play)
  step(4)
  shot("08_dawn_begins")
  step(6)
  shot("09_dawn_colour")
  for _ = 1, 10 do play:nextEpilogue() end
  step(2)
  shot("10_the_end")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

function love.load()
  lg.setDefaultFilter("linear", "linear")
  canvas = lg.newCanvas(W, H, { msaa = 4 })
  resize(lg.getDimensions())
  game.fonts = { small = lg.newFont(15), body = lg.newFont(21), card = lg.newFont(46), title = lg.newFont(96) }
  scenes.load()
  sfx.load()
  title = game.new({ title = true })
  title.gus.x = 300
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
    titleT = titleT + dt
    title:update(dt, true)
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
    sfx.play("coo", 1, 0.7)
    newGame()
  else
    play:keypressed(k)
  end
end
