-- Sounds synthesized at startup (no audio files).
-- Plucked notes use Karplus-Strong: a burst of noise fed through a short delay line
-- that averages itself, which rings like a plucked string (here: zither-like).

local sfx = { sounds = {}, enabled = false }
local RATE = 22050

local function source(samples)
  local sd = love.sound.newSoundData(#samples, RATE, 16, 1)
  for i, v in ipairs(samples) do sd:setSample(i - 1, math.max(-1, math.min(1, v))) end
  return love.audio.newSource(sd, "static")
end

local function pluck(freq, dur, bright)
  local n = math.floor(dur * RATE)
  local period = math.floor(RATE / freq)
  local buf = {}
  for i = 1, period do buf[i] = love.math.random() * 2 - 1 end
  local out, idx = {}, 1
  local damp = 0.996 - (1 - (bright or 0.5)) * 0.006
  for i = 1, n do
    local nxt = idx % period + 1
    local v = (buf[idx] + buf[nxt]) * 0.5 * damp
    buf[idx] = v
    out[i] = v * 0.45 * math.min(1, i / 40)
    idx = nxt
  end
  return out
end

local function mix(...)
  local parts, out = { ... }, {}
  for _, p in ipairs(parts) do
    for i, v in ipairs(p) do out[i] = (out[i] or 0) + v end
  end
  return out
end

local function noise(dur, shape)
  local out, n, lp = {}, math.floor(dur * RATE), 0
  for i = 1, n do
    local p = i / n
    lp = lp + ((love.math.random() * 2 - 1) - lp) * 0.08 -- low-pass: soft, airy
    out[i] = lp * shape(p)
  end
  return out
end

-- Pentatonic notes (D major pentatonic) so any sequence sounds pleasant.
local SCALE = { 293.7, 329.6, 370.0, 440.0, 493.9, 587.3, 659.3, 740.0 }

function sfx.load()
  if not love.audio then return end
  local ok = pcall(function()
    for i, f in ipairs(SCALE) do sfx.sounds["note" .. i] = source(pluck(f, 1.2, 0.6)) end
    sfx.sounds.chime = source(mix(pluck(SCALE[1], 2.2, 0.7), pluck(SCALE[3], 2.2, 0.7), pluck(SCALE[5], 2.2, 0.7), pluck(SCALE[6], 2.2, 0.7)))
    sfx.sounds.flap = source(noise(0.22, function(p) return math.sin(math.pi * p) * 0.5 end))
    sfx.sounds.splash = source(noise(0.35, function(p) return (1 - p) ^ 2 * 0.9 end))
    sfx.sounds.peck = source(pluck(880, 0.12, 1))
  end)
  sfx.enabled = ok
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

-- A random pleasant note (for pickups, dialogue blips).
function sfx.note(k, volume)
  sfx.play("note" .. (k or love.math.random(1, #SCALE)), 1, volume)
end

return sfx
