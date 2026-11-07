-- The black stork: movement (walk, wade, flap, glide, peck) and its ink portrait.
--
-- Real black storks: glossy black, white belly, red bill, red legs, red skin around
-- the eye; they fly with the neck stretched forward and the legs trailing behind.
-- That's exactly what gets drawn, with brush strokes.

local ink = require("src.ink")
local world = require("src.world")
local sfx = require("src.sfx")

local lg = love.graphics
local Stork = {}
Stork.__index = Stork

local WALK, WADE, AIR = 170, 115, 240
local GRAVITY, GLIDE_FALL, FLAP = 620, 75, 255

function Stork.new(x)
  local s = setmetatable({}, Stork)
  s.x, s.y = x, world.ground(x)
  s.vx, s.vy = 0, 0
  s.dir = 1
  s.air = false
  s.flapCooldown = 0
  s.wing = 0         -- 0..1 flap animation
  s.walk = 0         -- walk cycle phase
  s.peck = 0         -- > 0 while pecking
  s.carry = { twigs = 0, fish = 0, lantern = false }
  return s
end

function Stork:inWater()
  local level = world.water(self.x)
  return level and self.y > level - 2
end

-- input = { left, right, flapHeld, flapPressed }
function Stork:update(dt, input)
  local move = (input.right and 1 or 0) - (input.left and 1 or 0)
  if move ~= 0 then self.dir = move end
  local speed = self.air and AIR or (self:inWater() and WADE or WALK)
  local target = move * speed
  self.vx = self.vx + (target - self.vx) * math.min(1, dt * (self.air and 3 or 10))

  self.flapCooldown = math.max(0, self.flapCooldown - dt)
  if (input.flapPressed or (input.flapHeld and self.vy > 40)) and self.flapCooldown == 0 then
    self.vy = math.min(self.vy, -FLAP)
    self.air = true
    self.flapCooldown = 0.34
    self.wing = 1
    sfx.play("flap", 0.9 + love.math.random() * 0.2, 0.6)
  end
  self.wing = math.max(0, self.wing - dt * 3)

  if self.air then
    if input.flapHeld and self.vy > 0 then
      self.vy = math.min(self.vy + GRAVITY * 0.25 * dt, GLIDE_FALL) -- glide
    else
      self.vy = self.vy + GRAVITY * dt
    end
  end

  -- Steep rises are walls: you can't walk up a cliff, you have to fly.
  local nx = ink.clamp(self.x + self.vx * dt, 40, world.W - 40)
  if self.y - world.ground(nx) > 16 then
    self.vx = 0
  else
    self.x = nx
  end
  local gy = world.ground(self.x)
  if self.air then
    self.y = self.y + self.vy * dt
    if self.y < 70 then self.y, self.vy = 70, math.max(0, self.vy) end
    if self.y >= gy and self.vy >= 0 then
      self.y, self.vy, self.air = gy, 0, false
      if self:inWater() then sfx.play("splash", 1.2, 0.4) end
    end
  else
    if gy - self.y > 14 then
      self.air = true            -- walked off an edge: start falling
    else
      self.y = gy
    end
  end

  if not self.air and math.abs(self.vx) > 10 then
    self.walk = self.walk + dt * math.abs(self.vx) * 0.05
  end
  if self.peck > 0 then self.peck = math.max(0, self.peck - dt) end
end

function Stork:startPeck()
  if self.peck > 0 then return false end
  self.peck = 0.38
  sfx.play("peck", 0.9 + love.math.random() * 0.2, 0.35)
  return true
end

-- Where the beak can reach right now (used for picking things up and fishing).
function Stork:reach()
  if self.air then return self.x + self.dir * 62, self.y - 40 end
  return self.x + self.dir * 52, self.y - 8
end

-- 0 -> 1 -> 0 over the peck
function Stork:peckAmount()
  if self.peck <= 0 then return 0 end
  local p = 1 - self.peck / 0.38
  return math.sin(p * math.pi)
end

local function bill(hx, hy, angle, len, carry, t)
  local ca, sa = math.cos(angle), math.sin(angle)
  local tipx, tipy = hx + ca * len, hy + sa * len
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.95)
  lg.polygon("fill", hx - sa * 4, hy + ca * 4, tipx, tipy, hx + sa * 4, hy - ca * 4)
  -- whatever we carry dangles from the bill tip
  if carry.lantern then
    local sway = math.sin(t * 3) * 3
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.8)
    lg.setLineWidth(1.5)
    lg.line(tipx, tipy, tipx + sway, tipy + 16)
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9)
    lg.ellipse("fill", tipx + sway, tipy + 26, 9, 12)
  elseif carry.fish > 0 then
    ink.stroke({ tipx - 6, tipy + 2, tipx + 4, tipy + 10, tipx - 2, tipy + 22 }, 7, 0.75, 0.5)
  elseif carry.twigs > 0 then
    ink.stroke({ tipx - 18 * ca, tipy - 4, tipx, tipy, tipx + 18 * ca, tipy + 6 }, 3, 0.85, 0.5, nil, false)
  end
end

function Stork:draw(t, alpha)
  alpha = alpha or 1
  local x, y, d = self.x, self.y, self.dir
  local A = function(a) return a * alpha end

  if self.air then
    -- FLIGHT: body level, neck forward, legs trailing, wings beating
    local beat = math.sin(t * 9) * (0.35 + self.wing * 0.6)
    if self.vy > 0 and self.wing == 0 then beat = -0.15 end   -- gliding: wings held flat
    local bx, by = x, y - 48
    -- legs trailing behind
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], A(0.9))
    lg.setLineWidth(3)
    lg.line(bx - d * 18, by + 4, bx - d * 70, by + 10)
    -- far wing
    local wy = -math.sin(beat) * 55
    ink.stroke({ bx + d * 6, by - 4, bx - d * 10, by + wy * 0.6 - 14, bx - d * 40, by + wy }, 22, A(0.55), 0.6)
    -- body
    ink.stroke({ bx - d * 30, by + 2, bx, by - 4, bx + d * 30, by }, 26, A(0.9), 0.3)
    lg.setColor(ink.PAPER[1], ink.PAPER[2], ink.PAPER[3], A(0.95))
    lg.ellipse("fill", bx + d * 4, by + 6, 16, 5)
    -- neck and head
    ink.stroke({ bx + d * 26, by - 2, bx + d * 42, by - 8, bx + d * 58, by - 10 }, 9, A(0.9), 0.2)
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], A(0.95))
    lg.circle("fill", bx + d * 60, by - 10, 7)
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], A(0.9))
    lg.circle("fill", bx + d * 62, by - 12, 2.2)
    bill(bx + d * 64, by - 9, d > 0 and 0.12 or math.pi - 0.12, 28, self.carry, t)
    -- near wing on top, with fingered primary feathers
    local tipx, tipy = bx - d * 46, by + wy * 1.1
    ink.stroke({ bx + d * 10, by - 2, bx - d * 6, by + wy * 0.6 - 10, tipx, tipy }, 28, A(0.85), 0.5)
    for f = 0, 3 do
      local fx, fy = tipx + d * f * 6, tipy + f * 4
      ink.stroke({ fx, fy, fx - d * 10, fy + wy * 0.08 + 2, fx - d * 22, fy + 4 + f * 2 }, 5, A(0.8), 0.6, nil, false)
    end
    return
  end

  -- STANDING / WALKING
  local wade = self:inWater()
  local step = math.sin(self.walk * math.pi)
  local hipx, hipy = x, y - 62
  for leg = 0, 1 do
    local ph = leg == 0 and step or -step
    local kneex, kneey = hipx + d * ph * 10 + (leg - 0.5) * 6, y - 32
    local footx = hipx + d * ph * 18 + (leg - 0.5) * 8
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], A(0.9))
    lg.setLineWidth(3)
    lg.line(hipx, hipy, kneex, kneey, footx, y)
    lg.line(footx, y, footx + d * 8, y)
  end
  -- body: a fat brush stroke, tail down and back
  local bob = math.abs(step) * 2
  local bx, by = x, y - 76 + bob
  ink.stroke({ bx - d * 34, by + 12, bx - d * 4, by - 6, bx + d * 26, by - 4 }, 30, A(0.9), 0.35)
  lg.setColor(ink.PAPER[1], ink.PAPER[2], ink.PAPER[3], A(0.95))
  lg.ellipse("fill", bx + d * 8, by + 6, 15, 8)     -- white belly
  -- folded wing over the back
  ink.stroke({ bx + d * 14, by - 10, bx - d * 10, by - 6, bx - d * 40, by + 14 }, 16, A(0.6), 0.7)

  -- neck: an S curve up to the head; pecking pulls the head down to the reach point
  local pk = self:peckAmount()
  local hx = ink.lerp(bx + d * 30, bx + d * 46, pk)
  local hy = ink.lerp(by - 44, y - 30, pk)
  ink.stroke({ bx + d * 20, by - 6, bx + d * (30 - 12 * pk), by - 20, bx + d * 20, by - 34 + 20 * pk, hx, hy }, 10, A(0.9), 0.2)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], A(0.95))
  lg.circle("fill", hx, hy, 7.5)
  lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], A(0.9))
  lg.circle("fill", hx + d * 2, hy - 2, 2.4)
  lg.setColor(ink.PAPER[1], ink.PAPER[2], ink.PAPER[3], A(1))
  lg.circle("fill", hx + d * 2.4, hy - 2.4, 0.9)
  local ang = ink.lerp(0.25, 1.1, pk)
  bill(hx + d * 5, hy + 1, d > 0 and ang or math.pi - ang, 30, self.carry, t)
  return wade
end

return Stork
