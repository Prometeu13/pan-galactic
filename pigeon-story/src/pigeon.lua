-- Pigeons: Gus (the one you play) and the painter used for every bird in the story.
--
-- Movement is deliberately simple for a story game: walk along the ground or along a
-- perch, press Up near a perch to flutter onto it (a little arc), Down to hop back
-- down. Birds are painted in colour (iridescent neck, red feet); the film grade turns
-- them grey, and the light map lights them like everything else.

local sfx = require("src.sfx")

local lg = love.graphics
local Pigeon = {}
Pigeon.__index = Pigeon

Pigeon.GROUND = 600
local WALK = 150

function Pigeon.new(x, look)
  local p = setmetatable({}, Pigeon)
  p.x, p.y, p.dir = x, Pigeon.GROUND, 1
  p.perch = nil          -- the perch we're on, or nil for the ground
  p.hop = nil            -- { fromX, fromY, toX, toY, t, perch } while fluttering
  p.walk, p.peck = 0, 0
  p.look = look or {}
  p.moving = false
  return p
end

-- input = { left, right } held; perches = this chapter's perch list
function Pigeon:update(dt, input)
  if self.hop then
    local h = self.hop
    h.t = math.min(1, h.t + dt / 0.45)
    local e = h.t * h.t * (3 - 2 * h.t)
    self.x = h.fromX + (h.toX - h.fromX) * e
    self.y = h.fromY + (h.toY - h.fromY) * e - math.sin(math.pi * h.t) * 50
    if h.t >= 1 then
      self.perch, self.hop, self.y = h.perch, nil, h.toY
    end
    return
  end
  local move = (input.right and 1 or 0) - (input.left and 1 or 0)
  self.moving = move ~= 0
  if move ~= 0 then
    self.dir = move
    self.x = self.x + move * WALK * dt
    self.walk = self.walk + dt * 9
  end
  local lo, hi = 30, 1250
  if self.perch then lo, hi = self.perch.x1, self.perch.x2 end
  self.x = math.max(lo, math.min(hi, self.x))
  self.peck = math.max(0, self.peck - dt)
end

-- Flutter up to the nearest perch within reach. Returns true if it started.
function Pigeon:flyUp(perches)
  if self.hop or self.perch then return false end
  local best, bestD
  for _, p in ipairs(perches) do
    local d = (self.x < p.x1 and p.x1 - self.x) or (self.x > p.x2 and self.x - p.x2) or 0
    if d < 90 and (not bestD or d < bestD) then best, bestD = p, d end
  end
  if not best then return false end
  local tx = math.max(best.x1 + 10, math.min(best.x2 - 10, self.x))
  self.hop = { fromX = self.x, fromY = self.y, toX = tx, toY = best.y, t = 0, perch = best }
  sfx.play("flutter", 1, 0.6)
  return true
end

function Pigeon:hopDown()
  if self.hop or not self.perch then return false end
  self.hop = { fromX = self.x, fromY = self.y, toX = self.x + self.dir * 20, toY = Pigeon.GROUND, t = 0 }
  self.perch = nil
  sfx.play("flutter", 0.85, 0.5)
  return true
end

-- A rough outline for the light map (birds cast shadows too).
function Pigeon.occluder(x, y, dir, s)
  s = s or 1
  local d = dir
  return {
    x - d * 30 * s, y - 20 * s, x - d * 12 * s, y - 32 * s, x + d * 14 * s, y - 50 * s,
    x + d * 24 * s, y - 40 * s, x + d * 16 * s, y - 10 * s, x - d * 10 * s, y - 6 * s,
  }
end

-- Paint a pigeon. look = { scale, body = {r,g,b}, neck = {r,g,b}, chest, fluffed }
function Pigeon.paint(x, y, dir, t, look, walk, flying, peck)
  look = look or {}
  local s = look.scale or 1
  local d = dir
  local body = look.body or { 0.55, 0.58, 0.64 }
  local neck = look.neck or { 0.32, 0.55, 0.45 }
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  -- feet
  if not flying then
    local st = math.sin(walk or 0) * 4
    lg.setColor(0.85, 0.25, 0.2)
    lg.setLineWidth(3)
    lg.line(-4 + st, -8, -4 + st, 0, -4 + st + d * 6, 0)
    lg.line(4 - st, -8, 4 - st, 0, 4 - st + d * 6, 0)
  end
  -- tail and body
  lg.setColor(body[1] * 0.7, body[2] * 0.7, body[3] * 0.75)
  lg.polygon("fill", -d * 16, -26, -d * 40, -20, -d * 16, -12)
  lg.setColor(body)
  local fluff = look.fluffed and 4 or 0
  lg.ellipse("fill", -d * 2, -20, 22 + fluff, 14 + fluff)
  -- chest and the iridescent neck
  lg.setColor(look.chest or { body[1] * 1.08, body[2] * 1.05, body[3] * 1.05 })
  lg.ellipse("fill", d * 10, -18, 10, 11)
  local bob = (walk and (walk % math.pi) < 1) and 5 or 0
  local pk = peck or 0
  local hx, hy = d * (18 + bob + pk * 6), -34 + pk * 22
  lg.setColor(neck)
  lg.setLineWidth(11)
  lg.line(d * 8, -24, hx, hy + 2)
  lg.setColor(neck[1] * 1.2, neck[2] * 0.8, neck[3] * 1.3)
  lg.circle("fill", d * 12, -26, 6)
  lg.setColor(body[1] * 0.9, body[2] * 0.9, body[3] * 0.95)
  lg.circle("fill", hx, hy, 8.5)
  -- wing with two dark bars
  local flap = flying and math.sin(t * 22) * 0.8 or 0
  lg.push()
  lg.translate(-d * 2, -24)
  lg.scale(d, 1)
  lg.rotate(-flap)
  lg.setColor(body[1] * 0.82, body[2] * 0.84, body[3] * 0.88)
  lg.ellipse("fill", -4, 0, 18, 8)
  lg.setColor(0.12, 0.12, 0.14)
  lg.setLineWidth(3)
  lg.line(-12, -3, -12, 6)
  lg.line(-4, -4, -4, 7)
  if flying then
    lg.setColor(body)
    lg.polygon("fill", -2, -4, -30, -24 - flap * 20, -22, -2)
  end
  lg.pop()
  -- beak, cere and the orange eye
  lg.setColor(0.15, 0.13, 0.12)
  lg.polygon("fill", hx + d * 6, hy - 2, hx + d * 15, hy + 1 + pk * 3, hx + d * 6, hy + 3)
  lg.setColor(0.9, 0.88, 0.85)
  lg.circle("fill", hx + d * 6, hy - 3, 2)
  lg.setColor(0.95, 0.5, 0.1)
  lg.circle("fill", hx + d * 2, hy - 3, 2.8)
  lg.setColor(0.05, 0.05, 0.05)
  lg.circle("fill", hx + d * 2.4, hy - 3, 1.2)
  lg.pop()
end

function Pigeon:draw(t)
  Pigeon.paint(self.x, self.y, self.dir, t, self.look, self.moving and self.walk or 0, self.hop ~= nil, 0)
end

return Pigeon
