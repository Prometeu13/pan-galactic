-- LÖVE Style Showcase: art styles drawn with nothing but code.
--
--   love style-showcase                     open the gallery
--   love style-showcase --scene pixel_gameboy  start on one scene (use the scene id)
--   love style-showcase --snapshots         save a PNG of every scene, then quit
--   love style-showcase --tour 8            slideshow: next scene every 8 seconds
--   love style-showcase --selftest          load, poke and draw every scene, then quit (exit 0 = ok)
--   add `--only <id>` to load just one scene (faster while you tweak it)
--
-- Every scene lives in scenes/<id>.lua and is self-contained: read one top to bottom
-- to see how that look is built. A style can have several scenes (see STYLES below).
-- Third-party libraries are in lib/ (see README.md).

io.stdout:setvbuf("line") -- print() shows up immediately in the terminal
-- Let `require "flux"` find lib/flux.lua, and `require "moonshine"` find lib/moonshine/init.lua.
love.filesystem.setRequirePath("lib/?.lua;lib/?/init.lua;?.lua;?/init.lua")

local view = require("core.view")
local ui = require("core.ui")

-- Each line is one style; the first scene id is the one shown in the gallery.
local STYLES = {
  { "cartoon" },
  { "pixel", "pixel_dungeon", "pixel_gameboy" },
  { "noir" },
  { "romantic", "romantic_cafe", "romantic_lanterns" },
  { "adventure" },
  { "realistic", "realistic_aurora", "realistic_dunes" },
  { "space" },
  { "neon" },
  { "horror" },
  { "lowpoly" },
  { "sketch", "sketch_chalk", "sketch_blueprint" },
  { "isometric", "isometric_city", "isometric_tactics" },
  { "watercolor" },
  { "inkwash" },
  { "comic" },
  { "papercraft" },
  { "underwater" },
}

local styles = {}        -- { title = ..., scenes = { scene modules } }
local allScenes = {}     -- every scene in gallery order (for --tour, --snapshots, --selftest)
local cur = nil          -- { s = style index, v = scene index } or nil for the gallery
local showInfo = false   -- the "How it's made" panel; toggle with I
local thumbs = {}        -- one small canvas per style for the gallery
local galleryHover = nil
local time = 0
local tour = nil         -- { every = seconds, left = seconds, i = index into allScenes }

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

local function currentScene()
  return cur and styles[cur.s].scenes[cur.v]
end

local function hudInfo()
  local st = styles[cur.s]
  return { index = cur.s, count = #styles, variant = cur.v, variants = #st.scenes }
end

local function drawHudFor(s, info, open)
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  ui.drawHud(s, info, open)
  love.graphics.pop()
end

local function makeThumbs()
  for i, st in ipairs(styles) do
    local s = st.scenes[1]
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
  for _, s in ipairs(allScenes) do
    warmUp(s, s.snapshotTime or s.warmup or 3)
    drawScene(s)
    local letter = s._variant > 1 and string.char(96 + s._variant) or ""
    local name = ("snapshots/%02d%s_%s.png"):format(s._style, letter, s.id)
    view.canvas:newImageData():encode("png", name)
    print("  " .. name)
  end
  -- The gallery itself, and one scene with the info panel open.
  makeThumbs()
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  ui.drawGallery(styles, thumbs, nil, 0)
  love.graphics.pop()
  view.canvas:newImageData():encode("png", "snapshots/00_gallery.png")
  print("  snapshots/00_gallery.png")
  local k = math.min(4, #styles)
  cur = { s = k, v = 1 }
  drawScene(styles[k].scenes[1])
  drawHudFor(styles[k].scenes[1], hudInfo(), true)
  cur = nil
  view.canvas:newImageData():encode("png", "snapshots/00_info_panel.png")
  print("  snapshots/00_info_panel.png")
  print("Saved to " .. love.filesystem.getSaveDirectory() .. "/snapshots")
end

-- Smoke test: every scene loads, updates, handles input and draws without errors.
local function selftest()
  for i, s in ipairs(allScenes) do
    warmUp(s, 1)
    if s.mousepressed then
      s:mousepressed(640, 500, 1)
      s:mousepressed(300, 300, 2)
    end
    if s.keypressed then for _, k in ipairs({ "c", "w", "space" }) do s:keypressed(k) end end
    if s.wheelmoved then s:wheelmoved(0, 1) end
    warmUp(s, 0.5)
    drawScene(s)
    cur = { s = s._style, v = s._variant }
    drawHudFor(s, hudInfo(), true)
    cur = nil
    print(("  ok  %02d %s"):format(i, s.id))
  end
  print("selftest passed: " .. #allScenes .. " scenes in " .. #styles .. " styles")
end

local function enterScene(s)
  ensureLoaded(s)
  if s.enter then s:enter() end
end

local function goTo(si, vi)
  if si then
    si = (si - 1) % #styles + 1
    local st = styles[si]
    vi = ((vi or 1) - 1) % #st.scenes + 1
    cur = { s = si, v = vi }
    enterScene(st.scenes[vi])
  else
    cur = nil
  end
end

function love.load()
  love.graphics.setDefaultFilter("linear", "linear")
  view.init()
  ui.init()
  local only = argValue("--only") -- e.g. `--only neon --snapshots` while iterating on one scene
  for si, ids in ipairs(STYLES) do
    local st = { scenes = {} }
    for vi, id in ipairs(ids) do
      if type(only) ~= "string" or only == id then
        local s = require("scenes." .. id)
        s.id = id
        s._variant = vi
        st.scenes[#st.scenes + 1] = s
      end
    end
    if #st.scenes > 0 then
      styles[#styles + 1] = st
      st.title = st.scenes[1].title
      for _, s in ipairs(st.scenes) do
        s._style = #styles
        allScenes[#allScenes + 1] = s
      end
    end
  end
  -- With --only, keep the real style number in snapshot file names.
  if type(only) == "string" then
    for si, ids in ipairs(STYLES) do
      for _, id in ipairs(ids) do
        if id == only then allScenes[1]._style = si end
      end
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
    tour = { every = every, left = every, i = 1 }
    goTo(1, 1)
  end
  local start = argValue("--scene")
  if type(start) == "string" then
    for si, st in ipairs(styles) do
      for vi, s in ipairs(st.scenes) do
        if s.id == start then goTo(si, vi) end
      end
    end
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 20) -- avoid huge jumps after a window drag
  time = time + dt
  if tour then
    tour.left = tour.left - dt
    if tour.left <= 0 then
      tour.left = tour.every
      tour.i = tour.i % #allScenes + 1
      local s = allScenes[tour.i]
      goTo(s._style, s._variant)
      print(("tour: %02d %s"):format(tour.i, s.id))
    end
  end
  local s = currentScene()
  if s then
    ensureLoaded(s)
    if s.update then s:update(dt) end
  else
    local mx, my = view.mouse()
    galleryHover = ui.galleryHit(mx, my, #styles)
  end
end

function love.draw()
  love.graphics.push("all")
  love.graphics.setCanvas({ view.canvas, stencil = true })
  love.graphics.clear(0, 0, 0, 1)
  local s = currentScene()
  if s then
    s:draw()
    love.graphics.push("all")
    love.graphics.setCanvas({ view.canvas, stencil = true })
    ui.drawHud(s, hudInfo(), showInfo)
    love.graphics.pop()
  else
    ui.drawGallery(styles, thumbs, galleryHover, time)
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
    local s = currentScene()
    local name = ("screenshots/%s_%d.png"):format(s and s.id or "gallery", os.time())
    view.canvas:newImageData():encode("png", name)
    print("Saved " .. love.filesystem.getSaveDirectory() .. "/" .. name)
  elseif key == "escape" then
    if cur then goTo(nil) else love.event.quit() end
  elseif cur then
    if key == "right" then goTo(cur.s + 1, 1)
    elseif key == "left" then goTo(cur.s - 1, 1)
    elseif key == "down" or key == "pagedown" then goTo(cur.s, cur.v + 1)
    elseif key == "up" or key == "pageup" then goTo(cur.s, cur.v - 1)
    elseif key == "i" or key == "tab" then showInfo = not showInfo
    else
      local s = currentScene()
      if s.keypressed then s:keypressed(key) end
    end
  else
    if key == "return" or key == "space" then goTo(galleryHover or 1, 1) end
  end
end

function love.mousepressed(x, y, button)
  local vx, vy = view.toVirtual(x, y)
  if cur then
    local hit = ui.hudHit(vx, vy)
    if hit == "info" then showInfo = not showInfo return end
    if hit == "variant" then goTo(cur.s, cur.v + 1) return end
    local s = currentScene()
    if s.mousepressed then s:mousepressed(vx, vy, button) end
  else
    local i = ui.galleryHit(vx, vy, #styles)
    if i then goTo(i, 1) end
  end
end

function love.wheelmoved(x, y)
  local s = currentScene()
  if s and s.wheelmoved then s:wheelmoved(x, y) end
end
