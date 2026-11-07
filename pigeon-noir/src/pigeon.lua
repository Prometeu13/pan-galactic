-- Gus the pigeon: movement and his comic-book portrait.
--
-- Movement is a small platformer: walk, flap (costs wing stamina), a short glide,
-- land on one-way perches, Down to drop off a ledge (or hop off the curb into the
-- road). Pigeons bob their heads when they walk, so Gus does too.
-- Drawing: white fill with a heavy black outline, so he reads on both black night and
-- white lamp light after the two-tone shader. Feet and eye are spot red.

local city = require("src.city")
local sfx = require("src.sfx")

local lg = love.graphics
local Pigeon = {}
Pigeon.__index = Pigeon

local WALK, AIR = 135, 215
local GRAVITY, FLAP, GLIDE_FALL = 760, 245, 150

function Pigeon.new(x, y)
  local p = setmetatable({}, Pigeon)
  p.x, p.y = x, y or city.SIDEWALK
  p.vx, p.vy, p.dir = 0, 0, 1
  p.on = nil              -- platform we're standing on
  p.ignore = nil          -- platform we're dropping through
  p.stamina = 100
  p.flapCd, p.wing, p.walk, p.peck = 0, 0, 0, 0
  p.hurt = 0              -- invulnerable while > 0
  return p
end

-- input = { left, right, flapHeld, flapPressed, dropPressed }
function Pigeon:update(dt, input, platforms)
  local move = (input.right and 1 or 0) - (input.left and 1 or 0)
  if move ~= 0 then self.dir = move end
  local target = move * (self.on and WALK or AIR)
  self.vx = self.vx + (target - self.vx) * math.min(1, dt * (self.on and 12 or 4))

  self.flapCd = math.max(0, self.flapCd - dt)
  if (input.flapPressed or (input.flapHeld and self.vy > 60)) and self.flapCd == 0 and self.stamina > 6 then
    self.vy = -FLAP
    self.on = nil
    self.flapCd = 0.24
    self.wing = 1
    self.stamina = self.stamina - 7
    sfx.play("flap", 0.9 + love.math.random() * 0.25, 0.5)
  end
  self.wing = math.max(0, self.wing - dt * 4)

  if input.dropPressed and self.on and self.on.kind ~= "road" then
    self.ignore = self.on
    self.on = nil
    self.vy = 40
  end

  local prevY = self.y
  self.x = math.max(20, math.min(city.W - 20, self.x + self.vx * dt))
  if self.on then
    if self.x < self.on.x1 or self.x > self.on.x2 then self.on = nil end -- walked off the edge
    self.stamina = math.min(100, self.stamina + 30 * dt)
  end
  if not self.on then
    if input.flapHeld and self.vy > 0 then
      self.vy = math.min(self.vy + GRAVITY * 0.35 * dt, GLIDE_FALL)
    else
      self.vy = self.vy + GRAVITY * dt
    end
    self.y = self.y + self.vy * dt
    if self.y < 40 then self.y, self.vy = 40, 0 end
    if self.vy >= 0 then
      local land = city.landing(platforms, self.x, prevY, self.y, self.ignore)
      if land then
        self.y, self.vy, self.on = land.y, 0, land
        if land.kind == "road" or land.kind == "sidewalk" then sfx.play("step", 1, 0.3) end
      end
    end
    if self.ignore and self.y > self.ignore.y + 6 then self.ignore = nil end
  end
  if self.on and math.abs(self.vx) > 10 then self.walk = self.walk + dt * 9 end
  self.peck = math.max(0, self.peck - dt)
  self.hurt = math.max(0, self.hurt - dt)
end

function Pigeon:startPeck()
  if self.peck > 0 then return false end
  self.peck = 0.3
  sfx.play("peck", 0.9 + love.math.random() * 0.2, 0.5)
  return true
end

function Pigeon:onGround()
  return self.on and (self.on.kind == "sidewalk" or self.on.kind == "road")
end

-- Draw Gus. Colours are greys + spot red; the two-tone shader does the rest.
function Pigeon:draw(t)
  if self.hurt > 0 and math.floor(self.hurt * 12) % 2 == 0 then return end
  local x, y, d = self.x, self.y, self.dir
  local OUT = 0.03
  local function body(grow, shade)
    lg.setColor(shade, shade, shade)
    lg.ellipse("fill", x - d * 2, y - 20, 22 + grow, 14 + grow)                              -- body
    lg.polygon("fill", x - d * (18 + grow), y - 26 - grow, x - d * (40 + grow * 2), y - 20, x - d * (18 + grow), y - 12 + grow) -- tail
  end
  local flying = not self.on
  -- feet (spot red), drawn first so the body sits on them
  if not flying then
    local step = math.sin(self.walk) * 4
    lg.setColor(0.9, 0.15, 0.1)
    lg.setLineWidth(3)
    lg.line(x - 4 + step, y - 8, x - 4 + step, y, x - 4 + step + d * 6, y)
    lg.line(x + 4 - step, y - 8, x + 4 - step, y, x + 4 - step + d * 6, y)
  end
  -- head bob: the head jerks forward, then holds still while the body catches up
  local bob = flying and 0 or ((self.walk % math.pi) < 1 and 6 or 0)
  local pk = self.peck > 0 and math.sin((1 - self.peck / 0.3) * math.pi) or 0
  local hx, hy = x + d * (20 + bob + pk * 8), y - 36 + pk * 26
  -- outline pass (black, slightly bigger) then fill pass (white)
  body(3, OUT)
  lg.setColor(OUT, OUT, OUT)
  lg.circle("fill", hx, hy, 12)
  lg.setLineWidth(12)
  lg.line(x + d * 10, y - 26, hx, hy)
  body(0, 0.92)
  lg.setColor(0.92, 0.92, 0.92)
  lg.setLineWidth(6)
  lg.line(x + d * 10, y - 26, hx, hy)
  lg.circle("fill", hx, hy, 9)
  -- dark wing with two bars
  local flap = flying and math.sin(t * 22) * (0.4 + self.wing) or 0
  lg.push()
  lg.translate(x - d * 2, y - 26)
  lg.scale(d, 1)
  lg.rotate(-flap * 0.9)
  lg.setColor(0.35, 0.35, 0.35)
  lg.ellipse("fill", -4, 0, 18, 8)
  lg.setColor(OUT, OUT, OUT)
  lg.setLineWidth(3)
  lg.line(-12, -3, -12, 6)
  lg.line(-4, -4, -4, 7)
  if flying then
    lg.setColor(0.92, 0.92, 0.92)
    lg.polygon("fill", -2, -4, -30, -26 - flap * 20, -22, -2)
    lg.setColor(OUT, OUT, OUT)
    lg.setLineWidth(2)
    lg.polygon("line", -2, -4, -30, -26 - flap * 20, -22, -2)
  end
  lg.pop()
  -- beak and the red eye
  lg.setColor(OUT, OUT, OUT)
  lg.polygon("fill", hx + d * 7, hy - 2, hx + d * 17, hy + 2 + pk * 4, hx + d * 7, hy + 4)
  lg.setColor(0.95, 0.2, 0.1)
  lg.circle("fill", hx + d * 3, hy - 3, 3)
  lg.setColor(OUT, OUT, OUT)
  lg.circle("fill", hx + d * 3.5, hy - 3, 1.3)
end

return Pigeon
