-- LÖVE Style Showcase: twelve art styles drawn with nothing but code.
--
--   love style-showcase              open the gallery
--   love style-showcase --scene neon start on one scene (use the scene id)
--   love style-showcase --snapshots  save a PNG of every scene, then quit
--   love style-showcase --tour 8     slideshow: next style every 8 seconds
--   love style-showcase --selftest   load, poke and draw every scene, then quit (exit 0 = ok)
--   add `--only <id>` to load just one scene (faster while you tweak it)
--
-- Every scene lives in scenes/<id>.lua and is self-contained: read one top to bottom
-- to see how that look is built. Third-party libraries are in lib/ (see README.md).

-- Let `require "flux"` find lib/flux.lua, and `require "moonshine"` find lib/moonshine/init.lua.
io.stdout:setvbuf("line") -- print() shows up immediately in the terminal
love.filesystem.setRequirePath("lib/?.lua;lib/?/init.lua;?.lua;?/init.lua")

local view = require("core.view")
local ui = require("core.ui")

local SCENE_IDS = {
  "cartoon", "pixel", "noir", "romantic", "adventure", "realistic",
  "space", "neon", "horror", "lowpoly", "sketch", "isometric",
}

local scenes = {}        -- loaded scene modules, in order
local current = nil      -- index of the scene on screen, nil = gallery
local showInfo = false  -- the "How it's made" panel; toggle with I
local thumbs = {}        -- small canvases for the gallery
local galleryHover = nil
local time = 0
local tour = nil         -- { every = seconds, left = seconds } when --tour is on

local function argValue(name)
  for i, a in ipairs(arg or {}) do
    if a == name then return arg[i + 1] or true end
  end
end

local function ensureLoaded(s)
  if not s._loaded then
    s._loaded = true
    if s.load then s:load() end
  end
end

-- Run a scene for a while so particles, tweens and camera pans have somewhere to be.
local function warmUp(s, seconds)
  ensureLoaded(s)
  local dt = 1 / 60
  for _ = 1, math.floor(seconds / dt) do
    if s.update then s:update(dt) end
  end
end

local function drawScene(s)
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  love.graphics.clear(0, 0, 0, 1)
  s:draw()
  love.graphics.pop()
end

local function makeThumbs()
  for i, s in ipairs(scenes) do
    warmUp(s, s.warmup or 2)
    drawScene(s)
    -- Downscale in two steps so the thumbnail isn't aliased.
    local half = love.graphics.newCanvas(640, 360)
    love.graphics.push("all")
    love.graphics.setCanvas(half)
    love.graphics.clear()
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(view.canvas, 0, 0, 0, 0.5, 0.5)
    local t = love.graphics.newCanvas(ui.THUMB_W, ui.THUMB_H)
    love.graphics.setCanvas(t)
    love.graphics.clear()
    love.graphics.draw(half, 0, 0, 0, ui.THUMB_W / 640, ui.THUMB_H / 360)
    love.graphics.pop()
    thumbs[i] = t
  end
end

local function snapshots()
  love.filesystem.createDirectory("snapshots")
  for i, s in ipairs(scenes) do
    warmUp(s, s.snapshotTime or s.warmup or 3)
    drawScene(s)
    local name = ("snapshots/%02d_%s.png"):format(i, s.id)
    view.canvas:newImageData():encode("png", name)
    print("  " .. name)
  end
  -- The gallery itself, and one scene with the info panel open.
  makeThumbs()
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  ui.drawGallery(scenes, thumbs, nil, 0)
  love.graphics.pop()
  view.canvas:newImageData():encode("png", "snapshots/00_gallery.png")
  print("  snapshots/00_gallery.png")
  local k = math.min(4, #scenes)
  local s = scenes[k]
  drawScene(s)
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  ui.drawHud(s, k, #scenes, true)
  love.graphics.pop()
  view.canvas:newImageData():encode("png", "snapshots/00_info_panel.png")
  print("  snapshots/00_info_panel.png")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

-- Smoke test: every scene loads, updates, handles input and draws without errors.
local function selftest()
  for i, s in ipairs(scenes) do
    warmUp(s, 1)
    if s.mousepressed then s:mousepressed(640, 500, 1) end
    if s.keypressed then for _, k in ipairs({ "c", "w", "space" }) do s:keypressed(k) end end
    if s.wheelmoved then s:wheelmoved(0, 1) end
    warmUp(s, 0.5)
    drawScene(s)
    love.graphics.push("all")
    love.graphics.setCanvas({ view.canvas, stencil = true })
    ui.drawHud(s, i, #scenes, true)
    love.graphics.pop()
    print(("  ok  %02d %s"):format(i, s.id))
  end
  print("selftest passed: " .. #scenes .. " scenes")
end

function love.load()
  love.graphics.setDefaultFilter("linear", "linear")
  view.init()
  ui.init()
  local only = argValue("--only") -- e.g. `--only neon --snapshots` while iterating on one scene
  for _, id in ipairs(SCENE_IDS) do
    if type(only) ~= "string" or only == id then
      local s = require("scenes." .. id)
      s.id = id
      scenes[#scenes + 1] = s
    end
  end

  if argValue("--selftest") then
    selftest()
    love.event.quit(0)
    return
  end

  if argValue("--snapshots") then
    snapshots()
    love.event.quit(0)
    return
  end

  makeThumbs()
  local t = argValue("--tour")
  if t then
    local every = tonumber(t) or 8
    tour = { every = every, left = every }
    current = 1
    ensureLoaded(scenes[1])
  end
  local start = argValue("--scene")
  if type(start) == "string" then
    for i, s in ipairs(scenes) do
      if s.id == start then current = i end
    end
  end
end

local function goTo(i)
  if i then
    i = (i - 1) % #scenes + 1
    ensureLoaded(scenes[i])
    if scenes[i].enter then scenes[i]:enter() end
  end
  current = i
end

function love.update(dt)
  dt = math.min(dt, 1 / 20) -- avoid huge jumps after a window drag
  time = time + dt
  if tour then
    tour.left = tour.left - dt
    if tour.left <= 0 then
      tour.left = tour.every
      local nextIndex = (current or 0) % #scenes + 1
      ensureLoaded(scenes[nextIndex])
      if scenes[nextIndex].enter then scenes[nextIndex]:enter() end
      current = nextIndex
      print(("tour: %02d %s"):format(current, scenes[current].id))
    end
  end
  if current then
    local s = scenes[current]
    ensureLoaded(s)
    if s.update then s:update(dt) end
  else
    local mx, my = view.mouse()
    galleryHover = ui.galleryHit(mx, my, #scenes)
  end
end

function love.draw()
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  love.graphics.clear(0, 0, 0, 1)
  if current then
    local s = scenes[current]
    s:draw()
    love.graphics.push("all")
    ui.drawHud(s, current, #scenes, showInfo)
    love.graphics.pop()
  else
    ui.drawGallery(scenes, thumbs, galleryHover, time)
  end
  love.graphics.pop()
  view.present()
end

function love.resize(w, h)
  view.resize(w, h)
end

function love.keypressed(key)
  if key == "f11" then
    love.window.setFullscreen(not love.window.getFullscreen())
  elseif key == "f12" then
    love.filesystem.createDirectory("screenshots")
    local name = ("screenshots/%s_%d.png"):format(current and scenes[current].id or "gallery", os.time())
    view.canvas:newImageData():encode("png", name)
    print("Saved " .. love.filesystem.getSaveDirectory() .. "/" .. name)
  elseif key == "escape" then
    if current then goTo(nil) else love.event.quit() end
  elseif current then
    if key == "right" or key == "d" then goTo(current + 1)
    elseif key == "left" or key == "a" then goTo(current - 1)
    elseif key == "i" or key == "tab" then showInfo = not showInfo
    else
      local s = scenes[current]
      if s.keypressed then s:keypressed(key) end
    end
  else
    if key == "return" or key == "space" then goTo(galleryHover or 1) end
  end
end

function love.mousepressed(x, y, button)
  local vx, vy = view.toVirtual(x, y)
  if current then
    if ui.hudHit(vx, vy) == "info" then showInfo = not showInfo return end
    local s = scenes[current]
    if s.mousepressed then s:mousepressed(vx, vy, button) end
  else
    local i = ui.galleryHit(vx, vy, #scenes)
    if i then goTo(i) end
  end
end

function love.wheelmoved(x, y)
  local s = current and scenes[current]
  if s and s.wheelmoved then s:wheelmoved(x, y) end
end
