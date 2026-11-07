-- Breadcrumbs: a noir pigeon story. LÖVE configuration (runs before main.lua).

local function hasArg(name)
  for _, a in ipairs(arg or {}) do
    if a == name then return true end
  end
  return false
end

function love.conf(t)
  t.identity = "breadcrumbs"
  t.version = "11.5"

  t.window.title = "Breadcrumbs (prototype)"
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

  -- Tests, screenshots and --mute run without sound (and on machines without a sound card).
  if hasArg("--selftest") or hasArg("--snapshots") or hasArg("--mute") then
    t.modules.audio = false
    t.modules.sound = false
  end
end
