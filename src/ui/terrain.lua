-- Planet scenery, generated from the planet's seed so it always looks the same.
-- groundProps(): top-down (foraging). horizonProps(): side view (behind the shop counter).
local D = require("src.ui.draw")
local rngLib = require("src.core.rng")
local lg = love.graphics

local Tr = {}
local col = D.color

function Tr.groundProps(p)
  local r = rngLib.new(p.seed)
  local props = {}
  for _ = 1, 40 do
    props[#props + 1] = { kind = "blotch", x = r.float(0, 1280), y = r.float(60, 720), rx = r.float(30, 120), ry = r.float(15, 60), shade = r.float(-0.08, 0.08) }
  end
  for _ = 1, 16 do
    props[#props + 1] = { kind = p.terrain, x = r.float(40, 1240), y = r.float(90, 700), size = r.float(16, 40), seed = r.random(1, 1000) }
  end
  return props
end

function Tr.drawGround(p, props, t)
  col(p.ground)
  lg.rectangle("fill", -200, 0, 1680, 720)
  for _, pr in ipairs(props) do
    if pr.kind == "blotch" then
      local s = pr.shade
      lg.setColor(p.ground[1] + s, p.ground[2] + s, p.ground[3] + s)
      lg.ellipse("fill", pr.x, pr.y, pr.rx, pr.ry)
    end
  end
  -- Scenery is muted toward the ground colour so it never reads as a pick-up.
  local prop = D.mix(p.accent, p.ground, 0.6)
  for _, pr in ipairs(props) do
    local x, y, s = pr.x, pr.y, pr.size
    if pr.kind == "craters" then
      col(D.mix(p.ground, { 0, 0, 0 }, 0.3))
      lg.ellipse("fill", x, y, s * 1.4, s * 0.8)
      col(D.mix(p.ground, { 1, 1, 1 }, 0.15))
      lg.setLineWidth(3)
      lg.arc("line", "open", x, y, s * 1.4, math.pi * 0.1, math.pi * 0.9)
    elseif pr.kind == "crystals" then
      for i = -1, 1 do
        col(D.mix(prop, { 1, 1, 1 }, 0.08 * (i + 1)), 0.8)
        lg.polygon("fill", x + i * s * 0.5 - s * 0.2, y, x + i * s * 0.5 + s * 0.2, y, x + i * s * 0.6, y - s * (1.4 - math.abs(i) * 0.5))
      end
    elseif pr.kind == "goo" then
      col(prop, 0.7)
      lg.ellipse("fill", x, y, s * 1.6 + math.sin(t * 2 + pr.seed) * 3, s * 0.7)
      lg.setColor(1, 1, 1, 0.3)
      lg.circle("fill", x - s * 0.5, y - s * 0.15 - ((t * 10 + pr.seed) % 8), 3)
    elseif pr.kind == "fungus" then
      col(prop, 0.8)
      lg.ellipse("fill", x, y, s * 0.9, s * 0.55)
      lg.setColor(1, 1, 1, 0.15)
      for i = 0, 3 do lg.circle("fill", x + math.cos(i * 1.7 + pr.seed) * s * 0.5, y + math.sin(i * 2.3) * s * 0.25, s * 0.1) end
    end
  end
end

function Tr.horizonProps(p)
  local r = rngLib.new(p.seed + 1)
  local hills = {}
  for layer = 1, 2 do
    local pts = {}
    local base = layer == 1 and 220 or 260
    for i = 0, 16 do
      pts[#pts + 1] = -100 + i * 100
      pts[#pts + 1] = base + r.float(-40, 20) / layer
    end
    hills[layer] = pts
  end
  local items = {}
  for _ = 1, 9 do items[#items + 1] = { x = r.float(-50, 1330), size = r.float(20, 50), seed = r.random(1, 999) } end
  local moons = {}
  for i = 1, r.random(1, 3) do moons[i] = { x = r.float(500, 1200), y = r.float(80, 160), r = r.float(10, 40) } end
  return { hills = hills, items = items, moons = moons }
end

-- Draws the planet seen through the serving window, between y0 and y1.
function Tr.drawHorizon(p, hp, y0, y1, t)
  D.gradient(-200, y0, 1680, y1 - y0, D.mix(p.sky, { 0, 0, 0.1 }, 0.4), D.mix(p.sky, { 1, 1, 1 }, 0.35))
  for _, m in ipairs(hp.moons) do
    lg.setColor(1, 1, 1, 0.75)
    lg.circle("fill", m.x, y0 + m.y, m.r)
    col(p.sky, 0.5)
    lg.circle("fill", m.x + m.r * 0.4, y0 + m.y - m.r * 0.2, m.r * 0.85)
  end
  for layer = 1, 2 do
    local pts = {}
    for i = 1, #hp.hills[layer], 2 do
      pts[#pts + 1] = hp.hills[layer][i]
      pts[#pts + 1] = y0 + hp.hills[layer][i + 1] - 60
    end
    col(D.mix(p.ground, layer == 1 and { 0.6, 0.6, 0.8 } or { 0, 0, 0 }, layer == 1 and 0.35 or 0.05))
    for i = 1, #pts - 2, 2 do
      lg.polygon("fill", pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 2], y1, pts[i], y1)
    end
  end
  col(D.mix(p.ground, { 0, 0, 0 }, 0.15))
  lg.rectangle("fill", -200, y1 - 50, 1680, 50)
  for _, it in ipairs(hp.items) do
    local x, s, gy = it.x, it.size, y1 - 40
    if p.terrain == "crystals" then
      col(p.accent, 0.85)
      lg.polygon("fill", x - s * 0.3, gy, x + s * 0.3, gy, x, gy - s * 1.6)
      lg.polygon("fill", x + s * 0.1, gy, x + s * 0.6, gy, x + s * 0.5, gy - s)
    elseif p.terrain == "fungus" then
      lg.setColor(0.95, 0.92, 0.85)
      lg.rectangle("fill", x - s * 0.1, gy - s * 1.2, s * 0.2, s * 1.2)
      col(p.accent)
      lg.arc("fill", x, gy - s * 1.2, s * 0.6, math.pi, math.pi * 2)
    elseif p.terrain == "goo" then
      col(p.accent, 0.7)
      lg.ellipse("fill", x, gy + 8, s * 1.2, s * 0.25)
      lg.circle("fill", x + s * 0.3, gy - ((t * 12 + it.seed) % (s * 1.5)), 4)
    else
      col(D.mix(p.ground, { 0, 0, 0 }, 0.3))
      lg.arc("fill", x, gy + 8, s * 0.8, math.pi, math.pi * 2)
    end
  end
end

return Tr
