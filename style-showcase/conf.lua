-- LÖVE configuration for the style showcase. Runs before main.lua.

function love.conf(t)
  t.identity = "love2d-style-showcase"
  t.version = "11.5"

  t.window.title = "LÖVE Style Showcase: code-only art"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.resizable = true
  t.window.highdpi = true
  t.window.msaa = 4
  t.window.vsync = 1

  -- The showcase is visual only: no sound, video or physics modules needed.
  -- (Leaving audio off also lets it start on machines without a sound device.)
  t.modules.audio = false
  t.modules.sound = false
  t.modules.video = false
  t.modules.physics = false
end
