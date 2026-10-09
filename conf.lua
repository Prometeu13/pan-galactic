-- LÖVE configuration. Runs before main.lua.

local function hasArg(name)
  for _, a in ipairs(arg or {}) do
    if a == name then return true end
  end
  return false
end

function love.conf(t)
  t.identity = "pan-galactic"
  t.version = "11.5"
  t.console = false

  t.window.title = "The Pan-Galactic Gargle Blaster (prototype)"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.resizable = true
  t.window.highdpi = true
  t.window.msaa = 4
  t.window.vsync = 1

  t.modules.physics = false
  t.modules.video = false

  -- `love . --selftest` runs without a window or audio (works on CI).
  if hasArg("--selftest") then
    t.window = false
    t.modules.audio = false
  end
end
