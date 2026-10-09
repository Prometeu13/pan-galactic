-- Particles, floating text and screen shake. Shared by all scenes.
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local lg = love.graphics

local fx = { parts = {}, pops = {}, shakeT = 0, shakeAmp = 0 }

function fx.clear()
  fx.parts, fx.pops, fx.shakeT = {}, {}, 0
end

function fx.burst(x, y, n, color, speed, opts)
  opts = opts or {}
  for _ = 1, n do
    local a = love.math.random() * math.pi * 2
    local v = (0.3 + love.math.random() * 0.7) * (speed or 200)
    local life = (opts.life or 0.8) * (0.6 + love.math.random() * 0.6)
    fx.parts[#fx.parts + 1] = {
      x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v - (opts.up or 0),
      life = life, max = life, size = (opts.size or 5) * (0.5 + love.math.random()),
      color = color, grav = opts.grav or 300,
    }
  end
end

function fx.pop(text, x, y, color, size)
  fx.pops[#fx.pops + 1] = { text = text, x = x, y = y, color = color or T.c.ink, size = size or 20, life = 1.6, max = 1.6 }
end

function fx.shake(amp, dur)
  fx.shakeAmp, fx.shakeT = amp, dur or 0.4
end

function fx.offset()
  if fx.shakeT <= 0 then return 0, 0 end
  local a = fx.shakeAmp * (fx.shakeT / 0.4)
  return (love.math.random() * 2 - 1) * a, (love.math.random() * 2 - 1) * a
end

function fx.update(dt)
  fx.shakeT = math.max(0, fx.shakeT - dt)
  for i = #fx.parts, 1, -1 do
    local p = fx.parts[i]
    p.life = p.life - dt
    p.vy = p.vy + p.grav * dt
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    if p.life <= 0 then table.remove(fx.parts, i) end
  end
  for i = #fx.pops, 1, -1 do
    local p = fx.pops[i]
    p.life = p.life - dt
    p.y = p.y - 40 * dt
    if p.life <= 0 then table.remove(fx.pops, i) end
  end
end

function fx.draw()
  for _, p in ipairs(fx.parts) do
    D.color(p.color, math.min(1, p.life / p.max * 1.5))
    lg.circle("fill", p.x, p.y, p.size * (0.4 + 0.6 * p.life / p.max))
  end
  for _, p in ipairs(fx.pops) do
    local a = math.min(1, p.life / p.max * 2)
    local f = T.font(p.size)
    local w = f:getWidth(p.text)
    lg.setFont(f)
    lg.setColor(0, 0, 0, 0.6 * a)
    lg.print(p.text, p.x - w / 2 + 2, p.y + 2)
    D.color(p.color, a)
    lg.print(p.text, p.x - w / 2, p.y)
  end
end

return fx
