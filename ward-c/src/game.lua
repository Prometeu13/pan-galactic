-- Rules of the night round. No drawing in here: the renderer reads this state, and the
-- self-test can play thousands of frames of it without a window.
--
-- The whole game is one rule: IT ONLY MOVES IN THE DARK.
--   dark = a blackout, a stretch of corridor whose lamps have died, or any moment you
--          are not looking (when you lean into a room to check a patient)
--   your torch counts as light: hold it on the figure and it freezes; keep it there for
--   a second and it recoils back down the corridor. The battery is small.

local sfx = require("src.sfx")

local G = {}
G.__index = G

G.LEN = 30            -- the double doors at the far end
G.HOME = 29           -- where the figure waits
G.CATCH = 1.3         -- closer than this and it has you
G.PEEK_TIME = 2.2     -- seconds spent looking into a room
G.DRAIN = 0.2         -- battery per second of torch
G.REPEL_TIME = 1.0    -- seconds of torch on the figure before it recoils
G.REPEL_DIST = 9
G.TORCH_REACH = 13

local ROOMS = {
  { bed = 1, side = -1, z = 4, line = "Bed 1. Asleep. Snoring like a handsaw." },
  { bed = 2, side = 1, z = 8, awake = true, line = "Bed 2. Awake. \"Nurse... who is that, standing at the end of the hall?\"" },
  { bed = 3, side = -1, z = 12, battery = true, line = "Bed 3. Asleep. A torch on the bedside table: you take its batteries." },
  { bed = 4, side = 1, z = 16, line = "Bed 4. Talking in her sleep: \"...it only walks in the dark...\"" },
  { bed = 5, side = -1, z = 20, empty = true, line = "Bed 5. Empty. The sheets are still warm." },
  { bed = 6, side = 1, z = 24, battery = true, line = "Bed 6. Asleep. Spare batteries in the drawer. You pocket them." },
}
-- each checked room costs the ward one more ceiling lamp (lamp numbers, near to far)
-- (single dead lamps only dim the corridor; from the fourth on they pair up into
-- stretches dark enough for it to walk through while you watch)
local DYING = { 8, 5, 2, 9, 6, 3 }

function G.new(seed)
  local g = setmetatable({}, G)
  g.rng = love.math.newRandomGenerator(seed or os.time())
  g.t = 0
  g.mode = "play"                 -- play / caught / dead / won
  g.z = 1                         -- where you stand along the corridor
  g.walk = 0                      -- distance walked (drives the head bob and footsteps)
  g.vel = 0
  g.battery = 1
  g.light = false
  g.fig = { z = G.HOME, exposure = 0, state = "still", moving = false, stepT = 0 }
  g.lamps = {}
  for k = 0, 9 do
    g.lamps[k + 1] = { z = 1.5 + 3 * k, I = 1, dead = false, flicky = (k == 3 or k == 6), seed = k * 17.3 }
  end
  g.rooms = {}
  for i, r in ipairs(ROOMS) do
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    c.checked = false
    g.rooms[i] = c
  end
  g.checked = 0
  g.blackout = 0
  g.nextBlackout = 7
  g.msg, g.msgT = "Night round: check all six beds, then come back and clock out.", 6
  g.stats = { repels = 0, blackouts = 0 }
  g.heartT = 0
  return g
end

-- Brightness of the corridor at depth z (0..1). withoutTorch = lamps only.
function G:lightAt(z, withoutTorch)
  local sum = 0.03
  for _, l in ipairs(self.lamps) do
    local d = z - l.z
    sum = sum + l.I * 0.95 / (1 + d * d * 1.2)
  end
  if self.light and not withoutTorch then
    local d = z - self.z
    if d > 0 then sum = sum + 0.8 / (1 + (d / 6) ^ 2) end
  end
  return math.min(1, sum)
end

function G:say(text, seconds)
  self.msg, self.msgT = text, seconds or 5
end

-- The unchecked room you are standing next to, if any.
function G:nearRoom()
  local best
  for _, r in ipairs(self.rooms) do
    local d = r.z - self.z
    if not r.checked and d > 0.4 and d < 2.4 and (not best or d < best.z - self.z) then best = r end
  end
  return best
end

function G:allChecked() return self.checked == #self.rooms end
function G:atStation() return self.z < 1.7 end

function G:objective()
  if self.mode ~= "play" then return "" end
  if self:allChecked() then return "Round done. Walk back to the station and clock out." end
  return ("Beds checked: %d / %d"):format(self.checked, #self.rooms)
end

function G:prompt()
  if self.mode ~= "play" or self.peek then return nil end
  local r = self:nearRoom()
  if r then return ("E   check Bed %d"):format(r.bed) end
  if self:allChecked() and self:atStation() then return "E   clock out" end
end

function G:use()
  if self.mode ~= "play" or self.peek then return end
  local r = self:nearRoom()
  if r then
    self.peek = { room = r, t = 0 }
    self.light = false
    sfx.play("door", 0.9 + self.rng:random() * 0.2, 0.7)
  elseif self:allChecked() and self:atStation() then
    self.mode = "won"
    self.time = self.t
    sfx.stop("hum")
    sfx.play("relief")
  end
end

function G:finishPeek()
  local r = self.peek.room
  r.checked = true
  self.checked = self.checked + 1
  self.peek = nil
  if r.battery then self.battery = math.min(1, self.battery + 0.5) end
  self:say(r.line, 5)
  sfx.play("pen")
  -- another lamp gives up
  local k = DYING[self.checked]
  if k and self.lamps[k] then
    self.lamps[k].dead = true
    sfx.play("buzz", 0.8, 0.6)
  end
end

function G:updateLamps(dt)
  local t = self.t
  local warn = self.blackout <= 0 and self.nextBlackout < 0.6     -- stutter before the power drops
  for i, l in ipairs(self.lamps) do
    local n = love.math.noise(t * 9 + l.seed)
    local v = 0.86 + n * 0.14
    if l.flicky then
      v = (love.math.noise(t * 3.1, l.seed) > 0.5) and (0.25 + n * 0.75) or 0.05
    end
    if warn then v = v * ((math.floor(t * 22) % 2 == 0) and 1 or 0.15) end
    if l.dead or self.blackout > 0 or self.mode == "caught" or self.mode == "dead" then v = 0 end
    l.I = v
  end
end

function G:updateFigure(dt)
  local f = self.fig
  f.moving = false
  if f.state == "flee" then
    f.z = math.min(f.target, f.z + 11 * dt)
    if f.z >= f.target then f.state = "still" end
    return
  end
  local gap = f.z - self.z
  local torchOnIt = self.light and not self.peek and gap < G.TORCH_REACH
  if torchOnIt then
    f.exposure = f.exposure + dt
    if f.exposure >= G.REPEL_TIME then
      f.state, f.target, f.exposure = "flee", math.min(G.HOME, f.z + G.REPEL_DIST), 0
      self.stats.repels = self.stats.repels + 1
      sfx.play("hiss")
    end
    return
  end
  f.exposure = math.max(0, f.exposure - dt * 0.5)
  local speed = 0
  if self.peek then
    speed = 1.6                                   -- you aren't looking
  else
    local L = self:lightAt(f.z, true)
    -- pitch black (a blackout): it walks. Merely dim (dead lamps): it creeps.
    if L < 0.2 then speed = ((self.blackout > 0) and 2.4 or 1.3) * (1 - L / 0.2) end
  end
  if speed > 0.05 then
    f.z = f.z - speed * dt
    f.moving = true
    f.stepT = f.stepT - dt * speed
    if f.stepT <= 0 then
      f.stepT = 0.9
      sfx.play("creep", 0.8 + self.rng:random() * 0.3, math.max(0.15, math.min(1, 1.2 - gap / 14)))
    end
  end
end

-- input = { fwd, back, light } held this frame. Call g:use() for the action key.
function G:update(dt, input)
  input = input or {}
  self.t = self.t + dt
  if self.mode == "caught" then
    self.caughtT = self.caughtT + dt
    self.fig.z = self.fig.z + (self.z + 0.4 - self.fig.z) * math.min(1, dt * 7)
    self:updateLamps(dt)
    if self.caughtT > 2.3 then self.mode = "dead" end
    return
  end
  if self.mode ~= "play" then return end
  if self.msgT > 0 then self.msgT = self.msgT - dt end

  -- the power comes and goes
  if self.blackout > 0 then
    self.blackout = self.blackout - dt
    if self.blackout <= 0 then sfx.play("on") end
  else
    self.nextBlackout = self.nextBlackout - dt
    if self.nextBlackout <= 0 then
      self.blackout = 0.9 + self.rng:random() * 0.6
      self.nextBlackout = math.max(3.5, 6 + self.rng:random() * 3 - self.checked * 0.5)
      self.stats.blackouts = self.stats.blackouts + 1
      sfx.play("out")
    elseif self.nextBlackout < 0.6 and self.nextBlackout + dt >= 0.6 then
      sfx.play("buzz")
    end
  end
  self:updateLamps(dt)

  if self.peek then
    self.peek.t = self.peek.t + dt
    self.vel = 0
    if self.peek.t >= G.PEEK_TIME then self:finishPeek() end
  else
    local was = self.light
    self.light = input.light and self.battery > 0 or false
    if self.light ~= was then sfx.play("click", self.light and 1.2 or 0.9) end
    if self.light then self.battery = math.max(0, self.battery - G.DRAIN * dt) end
    local v = 0
    if input.fwd then v = 2.2 elseif input.back then v = -1.7 end
    local before = self.walk
    self.z = math.max(0.8, math.min(self.z + v * dt, G.LEN - 2.5, self.fig.z - 1.0))
    self.vel = v
    self.walk = self.walk + math.abs(v) * dt
    if math.floor(self.walk / 1.1) ~= math.floor(before / 1.1) then sfx.play("step", 0.9 + self.rng:random() * 0.2, 0.35) end
  end

  self:updateFigure(dt)
  local gap = self.fig.z - self.z
  -- your pulse, faster as it gets closer
  self.heartT = self.heartT - dt
  if gap < 10 and self.heartT <= 0 then
    self.heartT = 0.35 + gap * 0.07
    sfx.play("heart", 1, math.min(1, 1.3 - gap / 10))
  end
  if gap < G.CATCH then
    self.mode = "caught"
    self.caughtT = 0
    self.peek = nil
    self.light = false
    sfx.stop("hum")
    sfx.play("sting")
  end
end

return G
