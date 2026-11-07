-- Sounds synthesized at startup: no audio files. Rain is a looping bed of filtered
-- noise; everything else is a short burst built from sine, saw and noise.

local sfx = { sounds = {}, enabled = false }
local RATE = 22050

local function make(dur, fn, loop)
  local n = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local state = {}
  for i = 0, n - 1 do
    local t = i / RATE
    sd:setSample(i, math.max(-1, math.min(1, fn(t, t / dur, state))))
  end
  local src = love.audio.newSource(sd, "static")
  src:setLooping(loop or false)
  return src
end

local function sin(f, t) return math.sin(2 * math.pi * f * t) end
local function saw(f, t) return ((t * f) % 1) * 2 - 1 end
local function noise() return love.math.random() * 2 - 1 end

function sfx.load()
  if not love.audio then return end
  sfx.enabled = pcall(function()
    -- rain: two low-passed noise layers plus random droplet ticks, looped
    sfx.sounds.rain = make(3, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.15
      s.b = (s.b or 0) + (noise() - (s.b or 0)) * 0.6
      local tick = (love.math.random() < 0.002) and noise() * 0.6 or 0
      local edge = math.min(1, p * 30, (1 - p) * 30) * 0.5 + 0.5 -- soften the loop seam
      return (s.a * 0.35 + s.b * 0.08 + tick) * edge
    end, true)
    sfx.sounds.flap = make(0.12, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.3
      return s.a * math.sin(math.pi * p) * 0.9
    end)
    sfx.sounds.peck = make(0.05, function(t, p) return (sin(1800, t) * 0.4 + noise() * 0.3) * (1 - p) end)
    sfx.sounds.step = make(0.06, function(t, p) return noise() * (1 - p) ^ 3 * 0.3 end)
    sfx.sounds.eat = make(0.15, function(t, p) return sin(600 + 500 * p, t) * (1 - p) * 0.3 end)
    sfx.sounds.coo = make(0.6, function(t, p)
      local f = 260 + 40 * math.sin(p * 18) - 60 * p
      return sin(f, t) * math.sin(math.pi * p) * 0.35 + sin(f * 2, t) * 0.08 * math.sin(math.pi * p)
    end)
    sfx.sounds.horn = make(0.7, function(t, p)
      return (saw(311, t) + saw(370, t)) * 0.18 * math.min(1, p * 20) * math.min(1, (1 - p) * 8)
    end)
    sfx.sounds.car = make(1.4, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.05
      return (s.a * 0.8 + saw(48 + 30 * math.sin(math.pi * p), t) * 0.12) * math.sin(math.pi * p)
    end)
    sfx.sounds.hiss = make(0.5, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.7
      return s.a * math.sin(math.pi * p) * 0.6
    end)
    sfx.sounds.sting = make(1.2, function(t, p)
      return (saw(55, t) * 0.3 + sin(110 * (1 - 0.3 * p), t) * 0.3) * (1 - p) ^ 2
    end)
    sfx.sounds.siren = make(4, function(t, p)
      local f = 650 + 180 * math.sin(t * 2.4)
      return sin(f, t) * 0.05 * math.sin(math.pi * p)
    end)
    sfx.sounds.chord = make(2.5, function(t, p)
      return (sin(220, t) + sin(277.2, t) + sin(329.6, t) + sin(440, t)) * 0.08 * (1 - p) * math.min(1, p * 30)
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
  if s and not s:isPlaying() then
    s:setVolume(volume or 1)
    s:play()
  end
end

return sfx
