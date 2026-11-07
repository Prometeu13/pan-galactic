-- Painting the valley. Every function draws in WORLD coordinates (the camera
-- translation is already applied) and takes `a(x)`: how inked that spot is (0.25 when
-- still a faint sketch, 1 once its seal stone has been read).

local ink = require("src.ink")
local world = require("src.world")

local lg = love.graphics
local sc = {}

function sc.load()
  sc.far = ink.rangeMesh(3000, 330, 230, 0.0016, 2.2, 0.22, 200)
  sc.mid = ink.rangeMesh(4400, 430, 170, 0.0026, 6.4, 0.32, 160)
  sc.blob = ink.blob(128, 1.6)
  -- the ground as a wash mesh: dark at the surface, fading down
  local v = {}
  for x = 0, world.W, 10 do
    local y = world.ground(x)
    v[#v + 1] = { x, y, 0, 0, ink.INK[1], ink.INK[2], ink.INK[3], 0.28 }
    v[#v + 1] = { x, 720, 0, 1, ink.INK[1], ink.INK[2], ink.INK[3], 0.02 }
  end
  sc.groundMesh = lg.newMesh(v, "strip", "static")
  -- seeded positions for reeds, bamboo and rocks
  love.math.setRandomSeed(17)
  sc.reeds = {}
  for x = 760, 1560, 22 do sc.reeds[#sc.reeds + 1] = { x = x + love.math.random(-8, 8), h = love.math.random(40, 95), p = love.math.random() * 6 } end
  sc.bamboo = {}
  for x = 3060, 3660, 42 do sc.bamboo[#sc.bamboo + 1] = { x = x + love.math.random(-12, 12), h = love.math.random(260, 420), p = love.math.random() * 6, k = 0.6 + love.math.random() * 0.4 } end
  sc.lotus = {}
  for x = 4200, 4720, 70 do sc.lotus[#sc.lotus + 1] = { x = x + love.math.random(-20, 20), r = love.math.random(16, 28), flower = love.math.random() < 0.35 } end
  sc.grass = {}
  for x = 0, world.W, 37 do
    if not world.water(x) then sc.grass[#sc.grass + 1] = { x = x + love.math.random(-10, 10), h = love.math.random(10, 26) } end
  end
end

-- Draw a static mesh in vertical slices so each slice gets its own ink level.
function sc.sliced(mesh, camX, parallax, a, offset)
  local step = 64
  for sx = 0, 1280, step do
    local wx = camX + sx + step / 2
    lg.setScissor(sx, 0, step, 720)
    lg.setColor(1, 1, 1, a(wx))
    lg.draw(mesh, -camX * parallax + camX + (offset or 0), 0)
  end
  lg.setScissor()
end

function sc.backdrop(camX, a, t)
  -- far and mid mountains move slower than the camera (parallax); drawn in screen space
  lg.push()
  lg.origin()
  for sx = 0, 1280, 64 do
    local wx = camX + sx + 32
    lg.setScissor(sx, 0, 64, 720)
    lg.setColor(1, 1, 1, 0.45 + 0.55 * a(wx))
    lg.draw(sc.far, -camX * 0.25 - 100, 0)
    lg.setColor(1, 1, 1, 0.35 + 0.65 * a(wx))
    lg.draw(sc.mid, -camX * 0.5 - 100, 0)
  end
  lg.setScissor()
  -- drifting mist bands
  for k = 0, 5 do
    local x = ((k * 330 + t * (6 + k)) % 1700) - 200
    lg.setColor(ink.PAPER[1], ink.PAPER[2], ink.PAPER[3], 0.55)
    lg.draw(sc.blob, x, 420 + (k % 3) * 40, 0, 4.5, 0.55, 64, 64)
  end
  lg.pop()
end

function sc.terrain(camX, a)
  -- wash under the ground line
  local step = 64
  for sx = 0, 1280, step do
    local wx = camX + sx + step / 2
    lg.setScissor(sx, 0, step, 720)
    lg.setColor(1, 1, 1, a(wx))
    lg.draw(sc.groundMesh)
  end
  lg.setScissor()
  -- the ground line itself: overlapping brush strokes, one per 160px
  local x0 = math.floor(camX / 160) * 160 - 160
  for x = x0, camX + 1440, 160 do
    local ctrl = {}
    for k = 0, 4 do
      local xx = x + k * 50
      ctrl[#ctrl + 1] = xx
      ctrl[#ctrl + 1] = world.ground(xx) + 1
    end
    ink.stroke(ctrl, 7, 0.75 * a(x + 100), 0.3)
  end
  for _, g in ipairs(sc.grass) do
    if g.x > camX - 50 and g.x < camX + 1330 then
      local y = world.ground(g.x)
      ink.stroke({ g.x, y, g.x + 3, y - g.h * 0.6, g.x + 8, y - g.h }, 3, 0.55 * a(g.x), 0.6, nil, false)
    end
  end
end

function sc.cliff(a, t, nest, chickHappy)
  -- rock face of the nest cliff
  for k = 0, 4 do
    local x = 180 + k * 12
    ink.stroke({ x - 40, 560, x - 20, 470 - k * 10, x, 340 }, 14 - k * 2, 0.6 * a(x), 0.4)
    local x2 = 470 - k * 12
    ink.stroke({ x2 + 40, 560, x2 + 20, 460 - k * 10, x2, 340 }, 14 - k * 2, 0.6 * a(x2), 0.4)
  end
  -- the old pine holding the nest
  local px = 330
  ink.stroke({ px - 6, 332, px + 4, 290, px - 4, 250, px + 2, 214 }, 16, 0.85 * a(px), 0.2)
  for k, b in ipairs({ { -1, 270, 70 }, { 1, 250, 80 }, { -1, 228, 55 }, { 1, 300, 60 } }) do
    local dir, by, len = b[1], b[2], b[3]
    local sway = math.sin(t * 0.8 + k) * 3
    ink.stroke({ px, by, px + dir * len * 0.5, by - 12, px + dir * len, by - 4 + sway }, 7, 0.75 * a(px), 0.5)
    for n = 0, 4 do
      local nx = px + dir * (len * 0.35 + n * len * 0.15)
      ink.stroke({ nx - 14, by - 10 + sway, nx, by - 18 + sway, nx + 14, by - 10 + sway }, 9, 0.6 * a(px), 0.5)
    end
  end
  -- the nest: more twigs woven in as you bring them
  local nx, ny = nest.x, nest.y
  local twigs = 3 + nest.twigs * 3
  for k = 1, twigs do
    local w = 30 + (k % 4) * 8
    local yy = ny + 6 - (k % 3) * 3
    ink.stroke({ nx - w, yy + (k % 2) * 2, nx, yy + 8, nx + w, yy - (k % 3) }, 3.5, 0.8 * a(nx), 0.5, nil, false)
  end
  -- the chick: grey fluff, a big red beak that opens when you're near
  local cx, cy = nx + 4, ny - 8
  local bob = math.sin(t * 6) * (chickHappy and 1 or 2.5)
  lg.setColor(0.45, 0.45, 0.48, 0.85 * a(nx))
  lg.circle("fill", cx, cy + bob, 13)
  lg.circle("fill", cx + 10, cy - 14 + bob, 8)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], a(nx))
  lg.circle("fill", cx + 13, cy - 16 + bob, 1.8)
  local open = chickHappy and 0 or (math.sin(t * 10) > 0 and 0.5 or 0.1)
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9 * a(nx))
  lg.polygon("fill", cx + 16, cy - 14 + bob, cx + 28, cy - 12 + bob - open * 8, cx + 17, cy - 10 + bob)
  lg.polygon("fill", cx + 16, cy - 12 + bob, cx + 27, cy - 9 + bob + open * 6, cx + 16, cy - 9 + bob)
end

function sc.reedsDraw(camX, a, t)
  for _, r in ipairs(sc.reeds) do
    if r.x > camX - 60 and r.x < camX + 1340 then
      local base = world.ground(r.x)
      local sway = math.sin(t * 1.2 + r.p) * 8
      ink.stroke({ r.x, base, r.x + sway * 0.4, base - r.h * 0.5, r.x + sway, base - r.h }, 4, 0.7 * a(r.x), 0.6, nil, false)
      lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.7 * a(r.x))
      lg.ellipse("fill", r.x + sway, base - r.h - 8, 3, 10)
    end
  end
end

function sc.house(h, a, t, lanternsLit)
  local gy = world.ground(h.x)
  local top = gy - h.h
  local hw = h.w / 2
  ink.wash({ h.x - hw, gy, h.x + hw, gy, h.x + hw, top, h.x - hw, top }, 0.1 * a(h.x))
  ink.stroke({ h.x - hw, gy, h.x - hw + 2, top + h.h / 2, h.x - hw, top }, 6, 0.75 * a(h.x), 0.2)
  ink.stroke({ h.x + hw, gy, h.x + hw - 2, top + h.h / 2, h.x + hw, top }, 6, 0.75 * a(h.x), 0.2)
  -- curved eaves: the roof is two heavy strokes that flick up at the ends
  ink.wash({ h.x - hw - 26, top + 4, h.x, top - 50, h.x + hw + 26, top + 4 }, 0.45 * a(h.x))
  ink.stroke({ h.x - hw - 30, top - 6, h.x - hw * 0.4, top - 14, h.x, top - 50 }, 12, 0.9 * a(h.x), 0.2)
  ink.stroke({ h.x, top - 50, h.x + hw * 0.4, top - 14, h.x + hw + 30, top - 6 }, 12, 0.9 * a(h.x), 0.5)
  -- door and window
  ink.stroke({ h.x - 12, gy, h.x - 12, gy - 40, h.x + 12, gy - 40, h.x + 12, gy }, 4, 0.7 * a(h.x), 0.4, nil, false)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.5 * a(h.x))
  lg.rectangle("line", h.x + hw - 40, top + 26, 24, 20)
  -- hanging red lantern
  local lx, ly = h.x - hw + 14, top + 18 + math.sin(t * 1.5 + h.x) * 2
  if lanternsLit then
    lg.setColor(1, 0.55, 0.2, 0.35)
    lg.draw(sc.blob, lx, ly, 0, 0.7, 0.7, 64, 64)
  end
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9 * a(h.x))
  lg.ellipse("fill", lx, ly, 7, 10)
  -- chimney smoke
  for k = 0, 6 do
    local p = (t * 0.25 + k / 7) % 1
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.12 * (1 - p) * a(h.x))
    lg.circle("fill", h.x + hw * 0.5 + math.sin(p * 6 + k) * 6 + p * 30, top - 40 - p * 120, 6 + p * 16)
  end
end

function sc.villager(v, a, t)
  local x, y = v.x, v.y
  ink.stroke({ x, y, x - 2, y - 30, x, y - 52 }, 16, 0.8 * a(x), 0.3)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.85 * a(x))
  lg.circle("fill", x, y - 60, 7)
  ink.stroke({ x - 22, y - 62, x, y - 76, x + 22, y - 62 }, 6, 0.9 * a(x), 0.5)  -- conical hat
  -- sweeping broom
  local sw = math.sin(t * 2) * 8
  ink.stroke({ x + 6, y - 40, x + 18 + sw, y - 14, x + 26 + sw, y }, 3, 0.7 * a(x), 0.5, nil, false)
end

function sc.boat(f, a, t, hasLantern)
  local x, y = f.x, f.y + math.sin(t * 1.3) * 2
  ink.wash({ x - 70, y - 8, x + 70, y - 8, x + 50, y + 10, x - 50, y + 10 }, 0.5 * a(x))
  ink.stroke({ x - 80, y - 14, x - 30, y - 6, x + 30, y - 6, x + 80, y - 14 }, 7, 0.85 * a(x), 0.4)
  -- fisherman sitting, rod over the water
  ink.stroke({ x - 10, y - 10, x - 14, y - 30, x - 8, y - 46 }, 16, 0.8 * a(x), 0.3)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.85 * a(x))
  lg.circle("fill", x - 6, y - 54, 7)
  ink.stroke({ x - 28, y - 56, x - 6, y - 70, x + 16, y - 56 }, 6, 0.9 * a(x), 0.5)
  lg.setLineWidth(1.5)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.7 * a(x))
  lg.line(x - 2, y - 36, x + 60, y - 90, x + 110, y - 70)
  lg.line(x + 110, y - 70, x + 112, y + math.sin(t * 2) * 3)
  -- the lantern pole at the bow
  lg.line(x + 62, y - 10, x + 62, y - 60)
  if hasLantern then
    lg.setColor(1, 0.55, 0.2, 0.3 + 0.1 * math.sin(t * 6))
    lg.draw(sc.blob, x + 62, y - 60, 0, 0.8, 0.8, 64, 64)
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9 * a(x))
    lg.ellipse("fill", x + 62, y - 52, 9, 12)
  end
end

function sc.bambooDraw(camX, a, t)
  for _, b in ipairs(sc.bamboo) do
    if b.x > camX - 120 and b.x < camX + 1400 then
      local base = world.ground(b.x)
      local sway = math.sin(t * 0.7 + b.p) * 12 * b.k
      local seg = b.h / 6
      for s = 0, 5 do
        local f1, f2 = s / 6, (s + 1) / 6
        local x1, x2 = b.x + sway * f1 * f1, b.x + sway * f2 * f2
        local y1, y2 = base - seg * s, base - seg * (s + 1) + 5
        ink.stroke({ x1, y1, (x1 + x2) / 2 + 2, (y1 + y2) / 2, x2, y2 }, 12 * b.k, (0.45 + 0.3 * b.k) * a(b.x), 0.08, nil, false)
        ink.stroke({ x2 - 7, y2, x2, y2 - 2, x2 + 7, y2 }, 3, 0.85 * a(b.x), 0.5, nil, false)
        if s >= 3 and (s + math.floor(b.x)) % 2 == 0 then
          for l = 0, 1 do
            local dir = l == 0 and 1 or -1
            local wob = math.sin(t * 1.3 + s + b.p) * 5
            ink.stroke({ x2, y2, x2 + dir * 30, y2 + 8 + wob, x2 + dir * 64, y2 + 24 + wob }, 11 * b.k, 0.65 * a(b.x), 0.5, nil, false)
          end
        end
      end
    end
  end
end

function sc.pond(a, t)
  for _, l in ipairs(sc.lotus) do
    local wl = world.WATER[3].level
    lg.setColor(0.2, 0.32, 0.25, 0.35 * a(l.x))
    lg.ellipse("fill", l.x, wl, l.r, l.r * 0.3)
    if l.flower then
      lg.setColor(0.9, 0.5, 0.55, 0.6 * a(l.x))
      for k = -1, 1 do lg.ellipse("fill", l.x + k * 6, wl - 10 - (1 - math.abs(k)) * 4, 5, 9) end
    end
  end
  -- waterfall off the high ledge
  local x = 5070
  for k = 0, 8 do
    local yy = (t * 140 + k * 40) % 280
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.25 * a(x))
    lg.setLineWidth(2)
    lg.line(x + (k % 3) * 6, 300 + yy, x + (k % 3) * 6 + 2, 300 + yy + 30)
  end
  ink.stroke({ 4880, 300, 4960, 296, 5060, 302 }, 10, 0.8 * a(4960), 0.4)
  ink.stroke({ 5060, 302, 5070, 420, 5090, 560 }, 18, 0.6 * a(5060), 0.3)
end

function sc.frog(f, a, t)
  local x, y = f.x, f.y
  lg.setColor(0.2, 0.32, 0.25, 0.45 * a(x))
  lg.ellipse("fill", x, y, 30, 8)
  local puff = math.max(0, math.sin(t * 3)) * 3
  lg.setColor(0.25, 0.38, 0.2, 0.85 * a(x))
  lg.ellipse("fill", x, y - 10, 14, 10)
  lg.setColor(0.4, 0.55, 0.3, 0.7 * a(x))
  lg.ellipse("fill", x + 6, y - 6, 6 + puff, 4 + puff)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], a(x))
  lg.circle("fill", x - 4, y - 18, 3)
  lg.circle("fill", x + 6, y - 18, 3)
end

function sc.sealStone(s, read, a, t)
  local x, y = s.x, s.y
  ink.wash({ x - 26, y, x - 22, y - 46, x - 4, y - 60, x + 18, y - 52, x + 26, y }, 0.35 * a(x))
  ink.stroke({ x - 28, y, x - 20, y - 50, x, y - 62, x + 20, y - 50 }, 6, 0.85 * a(x), 0.3)
  local glow = read and 0.9 or (0.65 + 0.25 * math.sin(t * 2.5))
  ink.seal(x, y - 30, 20, glow)
end

function sc.twig(tw, t)
  if tw.taken then return end
  local x, y = tw.x, tw.y + math.sin(t * 2 + tw.x) * 1.5
  -- a faint red shimmer so items are findable without UI arrows
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.15 + 0.1 * math.sin(t * 3 + tw.x))
  lg.draw(sc.blob, x, y - 4, 0, 0.45, 0.2, 64, 64)
  ink.stroke({ x - 20, y, x, y - 4, x + 20, y - 2 }, 4, 0.9, 0.5, nil, false)
  ink.stroke({ x - 4, y - 3, x + 4, y - 10, x + 10, y - 14 }, 2.5, 0.85, 0.5, nil, false)
end

function sc.lantern(l, t)
  if l.taken then return end
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.15 + 0.1 * math.sin(t * 3))
  lg.draw(sc.blob, l.x, l.y - 8, 0, 0.4, 0.3, 64, 64)
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9)
  lg.ellipse("fill", l.x, l.y - 10, 9, 12)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.8)
  lg.rectangle("fill", l.x - 5, l.y - 25, 10, 4)
  lg.rectangle("fill", l.x - 5, l.y + 1, 10, 3)
end

function sc.fish(f, a, t)
  if f.caught then return end
  local wl = f.water.level
  local y = wl + 16 + math.sin(t * 1.5 + f.phase) * 4
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.35 * a(f.x))
  lg.ellipse("fill", f.x, y, 16, 5)
  local tail = math.sin(t * 8 + f.phase) * 3
  lg.polygon("fill", f.x - f.dir * 14, y, f.x - f.dir * 24, y - 6 + tail, f.x - f.dir * 24, y + 6 + tail)
end

-- Water surface, drawn AFTER the stork so wading legs look submerged.
function sc.water(camX, a, t)
  for _, w in ipairs(world.WATER) do
    if w.x2 > camX - 50 and w.x1 < camX + 1330 then
      local pts = {}
      for x = w.x1 - 20, w.x2 + 20, 20 do
        pts[#pts + 1] = x
        pts[#pts + 1] = w.level + math.sin(x * 0.03 + t * 1.5) * 1.5
      end
      for x = w.x2 + 20, w.x1 - 20, -20 do
        pts[#pts + 1] = x
        pts[#pts + 1] = math.max(w.level + 3, world.ground(x))
      end
      local mid = (w.x1 + w.x2) / 2
      ink.wash(pts, 0.1 * a(mid), { 0.25, 0.35, 0.45 })
      for k = 0, 10 do
        local x = w.x1 + ((k * 97 + t * 14) % (w.x2 - w.x1))
        lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.25 * a(x))
        lg.setLineWidth(1.5)
        lg.line(x, w.level + 3 + (k % 3) * 6, x + 24 + (k % 2) * 16, w.level + 3 + (k % 3) * 6)
      end
    end
  end
end

return sc
