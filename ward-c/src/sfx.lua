-- Sounds synthesized at startup: no audio files.

local sfx = { sounds = {}, enabled = false }
local RATE = 22050

local function make(dur, fn, loop)
  local n = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local st = {}
  for i = 0, n - 1 do
    local t = i / RATE
    sd:setSample(i, math.max(-1, math.min(1, fn(t, t / dur, st))))
  end
  local src = love.audio.newSource(sd, "static")
  src:setLooping(loop or false)
  return src
end

local function sin(f, t) return math.sin(2 * math.pi * f * t) end
local function noise() return love.math.random() * 2 - 1 end

function sfx.load()
  if not love.audio then return end
  sfx.enabled = pcall(function()
    -- fluorescent tubes: mains hum with a little fizz
    sfx.sounds.hum = make(2, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.3
      return sin(100, t) * 0.10 + sin(200, t) * 0.05 + sin(50, t) * 0.06 + s.a * 0.02
    end, true)
    -- a tube stuttering
    sfx.sounds.buzz = make(0.5, function(t, p)
      local gate = (math.floor(t * 34) % 2 == 0) and 1 or 0
      return (sin(120, t) * 0.3 + noise() * 0.25) * gate * (1 - p)
    end)
    -- power dies: a falling thump
    sfx.sounds.out = make(0.7, function(t, p)
      return sin(90 - 60 * p, t) * (1 - p) ^ 2 * 0.8 + noise() * (1 - p) ^ 8 * 0.4
    end)
    sfx.sounds.on = make(0.25, function(t, p) return (sin(880, t) * 0.15 + noise() * 0.3) * (1 - p) ^ 3 end)
    sfx.sounds.click = make(0.05, function(t, p) return noise() * (1 - p) ^ 3 * 0.5 end)
    -- your own footstep (soft shoe on lino), and its: bare, wet, slower
    sfx.sounds.step = make(0.12, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.2
      return s.a * (1 - p) ^ 3 * 0.9
    end)
    sfx.sounds.creep = make(0.3, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.08
      return (s.a * 1.6 + sin(70, t) * 0.5) * (1 - p) ^ 2
    end)
    sfx.sounds.heart = make(0.32, function(t, p)
      local a = math.exp(-((t - 0.04) / 0.025) ^ 2) + 0.7 * math.exp(-((t - 0.19) / 0.03) ^ 2)
      return sin(58, t) * a * 0.9
    end)
    sfx.sounds.door = make(0.8, function(t, p)
      return sin(300 + 260 * math.sin(p * 9) * (1 - p), t) * 0.12 * math.sin(math.pi * p) + noise() * 0.03
    end)
    sfx.sounds.pen = make(0.4, function(t, p) return noise() * 0.12 * math.abs(math.sin(t * 40)) * (1 - p) end)
    -- it recoils from the torch
    sfx.sounds.hiss = make(0.9, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.6
      return s.a * math.sin(math.pi * p) ^ 0.5 * 0.5 + sin(1900 - 900 * p, t) * 0.05 * (1 - p)
    end)
    sfx.sounds.sting = make(1.6, function(t, p)
      return (sin(110, t) + sin(116.5, t) + sin(233, t) * 0.6 + sin(466 + 40 * math.sin(t * 30), t) * 0.4) * 0.22 * (1 - p) ^ 0.6
        + noise() * (1 - p) ^ 6 * 0.5
    end)
    sfx.sounds.relief = make(3, function(t, p)
      local env = math.min(1, p * 4) * (1 - p)
      return (sin(196, t) + sin(246.9, t) + sin(293.7, t) + sin(392, t) * 0.5) * 0.09 * env
    end)
  end)
end

function sfx.play(name, pitch, volume)
  if not sfx.enabled then return end
  local s = sfx.sounds[name]
  if not s then return end
  s:stop()
  s:setPitch(pitch or 1)
  s:setVolume(volume or 1)
  s:play()
end

function sfx.loop(name, volume)
  if not sfx.enabled then return end
  local s = sfx.sounds[name]
  if s then
    s:setVolume(volume or 1)
    if not s:isPlaying() then s:play() end
  end
end

function sfx.stop(name)
  if not sfx.enabled then return end
  local s = sfx.sounds[name]
  if s then s:stop() end
end

return sfx
