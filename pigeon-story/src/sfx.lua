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

-- A soft piano-ish note: a few decaying harmonics.
local function piano(f, t, p)
  local env = math.exp(-t * 3) * math.min(1, t * 200)
  return (sin(f, t) * 0.6 + sin(f * 2, t) * 0.25 + sin(f * 3, t) * 0.1) * env
end

function sfx.load()
  if not love.audio then return end
  sfx.enabled = pcall(function()
    sfx.sounds.rain = make(3, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.12
      s.b = (s.b or 0) + (noise() - (s.b or 0)) * 0.5
      local tick = (love.math.random() < 0.0015) and noise() * 0.5 or 0
      local edge = math.min(1, p * 30, (1 - p) * 30) * 0.5 + 0.5
      return (s.a * 0.32 + s.b * 0.06 + tick) * edge
    end, true)
    sfx.sounds.flutter = make(0.35, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.35
      return s.a * math.abs(math.sin(t * 60)) * (1 - p) * 0.8
    end)
    sfx.sounds.coo = make(0.7, function(t, p)
      local f = 250 + 40 * math.sin(p * 16) - 50 * p
      return (sin(f, t) * 0.35 + sin(f * 2, t) * 0.07) * math.sin(math.pi * p)
    end)
    sfx.sounds.type = make(0.03, function(t, p) return noise() * (1 - p) ^ 4 * 0.25 end)
    sfx.sounds.tap = make(0.12, function(t, p) return (sin(2200, t) * 0.4 + noise() * 0.2) * (1 - p) ^ 3 end)
    sfx.sounds.purr = make(1.2, function(t, p, s)
      s.a = (s.a or 0) + (noise() - (s.a or 0)) * 0.05
      return s.a * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 24)) * math.sin(math.pi * p) * 0.9
    end)
    -- a lonely little phrase for chapter cards (A minor)
    sfx.sounds.card = make(3.2, function(t)
      local notes = { { 0, 220 }, { 0.5, 261.6 }, { 1.0, 329.6 }, { 1.6, 293.7 } }
      local v = 0
      for _, n in ipairs(notes) do
        if t >= n[1] then v = v + piano(n[2], t - n[1]) end
      end
      return v * 0.35
    end)
    -- dawn: a warm major chord that swells in
    sfx.sounds.dawn = make(6, function(t, p)
      local env = math.min(1, p * 3) * (1 - p) ^ 0.5
      return (sin(261.6, t) + sin(329.6, t) + sin(392, t) + sin(523.3, t) * 0.5) * 0.07 * env
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

return sfx
