-- Tiny synthesized sound effects, so the prototype needs zero asset files.
local S = { sounds = {} }

local function make(dur, fn)
  local rate = 22050
  local n = math.floor(dur * rate)
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do
    local t = i / rate
    local v = fn(t, t / dur)
    sd:setSample(i, math.max(-1, math.min(1, v)))
  end
  return love.audio.newSource(sd, "static")
end

local function sin(f, t) return math.sin(2 * math.pi * f * t) end

function S.load()
  if not love.audio then return end
  S.sounds.pick = make(0.12, function(t, p) return sin(600 + 900 * p, t) * (1 - p) * 0.35 end)
  S.sounds.click = make(0.05, function(t, p) return sin(900, t) * (1 - p) * 0.25 end)
  S.sounds.coin = make(0.25, function(t, p)
    local f = p < 0.35 and 988 or 1319
    return sin(f, t) * (1 - p) * 0.3
  end)
  S.sounds.bad = make(0.35, function(t, p)
    local ph = (t * (180 - 80 * p)) % 1
    return (ph * 2 - 1) * (1 - p) * 0.22
  end)
  S.sounds.boom = make(0.7, function(t, p)
    return (love.math.random() * 2 - 1) * (1 - p) ^ 2 * 0.6 + sin(55, t) * (1 - p) * 0.4
  end)
  S.sounds.bubble = make(0.18, function(t, p) return sin(300 + 500 * p * p, t) * math.sin(math.pi * p) * 0.25 end)
  S.sounds.warp = make(1.2, function(t, p)
    return sin(120 + 900 * p * p, t) * math.sin(math.pi * p) * 0.25 + (love.math.random() - 0.5) * 0.05 * p
  end)
  S.sounds.fine = make(0.3, function(t, p) return sin(p < 0.5 and 440 or 330, t) * (1 - p) * 0.3 end)
end

function S.play(name, pitch)
  local s = S.sounds[name]
  if not s then return end
  s:stop()
  s:setPitch(pitch or 1)
  s:play()
end

return S
