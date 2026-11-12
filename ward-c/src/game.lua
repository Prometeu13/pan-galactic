-- Rules of the night round. No drawing in here: the renderer reads this state, and the
-- self-test can play thousands of frames of it without a window.
--
-- The whole game is one rule: THEY ONLY MOVE IN THE DARK.
--   dark = a blackout, a stretch of corridor whose lamps have died, or any moment you
--          are not looking: leaning into a room, rummaging on a shelf, unlocking a
--          door, turning around, or simply having your back to them
--   your torch counts as light: hold it on a figure and it freezes; keep it there for
--   a second and it recoils toward wherever it came from. The battery is small.
--
-- The ward is two straight corridors: the main one (station at 0, EXIT at 30) and a
-- side corridor to the supply room, which opens off the main one at z = 14.
-- A position is (segment, distance along it); distances between two positions run
-- through that junction.

local sfx = require("src.sfx")

local G = {}
G.__index = G

G.LEN = 30            -- main corridor: the EXIT doors are at this end
G.J = 14              -- where the side corridor opens off the main one (right-hand wall)
G.ANNEX = 10          -- length of the side corridor; the supply shelves are at its end
G.FAR_HOME = 28.6     -- where a figure waits at the EXIT end
G.NEAR_HOME = 0.9     -- ...and at the station end
G.CATCH = 1.3         -- closer than this and it has you
G.PEEK_TIME = 2.2     -- looking into a room
G.DELIVER_TIME = 1.5  -- handing something over
G.RUMMAGE_TIME = 1.2  -- taking things off the supply shelf
G.UNLOCK_TIME = 2.5   -- the EXIT chain
G.TURN_TIME = 0.25    -- turning around
G.DRAIN = 0.2         -- battery per second of torch
G.REPEL_TIME = 1.0    -- seconds of torch on a figure before it recoils
G.REPEL_DIST = 9
G.TORCH_REACH = 13
G.LINGER = 2.5        -- how long it waits outside the door you are hiding behind
G.SEE_YOU = 3.0       -- you can't hide with one of them this close: it would see you
G.CORNER = 1.2        -- how far round the corner of the junction you can see
G.WALK, G.BACK = 2.4, 1.6                 -- your speed forward / backing away
G.V_UNSEEN, G.V_BLACKOUT, G.V_CREEP = 1.4, 2.4, 1.3
G.V_FLEE, G.V_WANDER = 11, 3.2

local ROOMS = {
  { bed = 1, side = -1, z = 4, line = "Bed 1. Asleep. Snoring like a handsaw." },
  { bed = 2, side = 1, z = 8, awake = true, asks = "water",
    line = "Bed 2. Awake. \"Could I have some water, nurse? ...Who is that, at the end of the hall?\"",
    thanks = "Bed 2 drinks. \"Thank you. Don't let it catch you looking away.\"" },
  { bed = 3, side = -1, z = 12, battery = true, line = "Bed 3. Asleep. A torch on the bedside table: you take its batteries." },
  { bed = 4, side = 1, z = 16, asks = "blanket",
    line = "Bed 4. Shivering in her sleep: \"...so cold... it only walks in the dark...\" She needs a blanket.",
    thanks = "Bed 4, tucked in. The shivering stops." },
  { bed = 5, side = -1, z = 20, empty = true, line = "Bed 5. Empty. The sheets are still warm. Under the bed, something shifts." },
  { bed = 6, side = 1, z = 24, battery = true, line = "Bed 6. Asleep. Spare batteries in the drawer. You pocket them." },
}
-- each checked room costs the ward one more ceiling lamp (lamp numbers, near to far);
-- single dead lamps only dim the corridor, from the fourth on they pair up into
-- stretches dark enough for a figure to walk through while you watch
local DYING = { 8, 5, 2, 9, 6, 3 }

function G.new(seed)
  local g = setmetatable({}, G)
  g.rng = love.math.newRandomGenerator(seed or os.time())
  g.t = 0
  g.mode = "play"                 -- play / caught / dead / won
  g.seg = "main"                  -- which corridor you are in
  g.z = 1                         -- how far along it
  g.dir = 1                       -- which way you face: +1 = away from the station / into the side corridor
  g.entryDir = 1                  -- which way you faced when you turned into the side corridor
  g.walk = 0                      -- distance walked (drives the head bob and footsteps)
  g.vel = 0
  g.battery = 1
  g.light = false
  g.items = { water = false, blanket = false, key = false }
  g.shelfBattery = true
  -- A: the patient from Bed 5. Starts in front of the EXIT.
  -- B: whatever is under Bed 5. Wakes when you check that bed; comes out during blackouts.
  g.figs = {
    { kind = "A", seg = "main", p = G.FAR_HOME, home = { seg = "main", p = G.FAR_HOME }, active = true, inside = false, state = "still", exposure = 0, stepT = 0 },
    { kind = "B", seg = "main", p = 20, home = { seg = "main", p = 20 }, active = false, inside = true, state = "still", exposure = 0, stepT = 0, rest = 0 },
  }
  g.fig = g.figs[1]
  g.lamps = { main = {}, annex = {} }
  for k = 0, 9 do
    g.lamps.main[k + 1] = { z = 1.5 + 3 * k, I = 1, dead = false, flicky = (k == 3 or k == 6), seed = k * 17.3 }
  end
  for k = 0, 2 do
    g.lamps.annex[k + 1] = { z = 2 + 3 * k, I = 1, dead = false, flicky = (k == 1), seed = 60 + k * 11.1 }
  end
  g.rooms = {}
  for i, r in ipairs(ROOMS) do
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    c.checked = false
    c.lockUsed = false            -- each room hides you once
    c.request = c.asks and "none" or nil    -- none -> asked -> carried -> done
    g.rooms[i] = c
  end
  g.checked = 0
  g.blackout = 0
  g.nextBlackout = 7
  g.msg, g.msgT = "Night round: check all six beds, then come back and clock out.", 6
  g.stats = { repels = 0, blackouts = 0, hides = 0 }
  g.heartT = 0
  return g
end

---------------------------------------------------------------------------------------
-- geometry of the ward
---------------------------------------------------------------------------------------
function G:len(seg) return seg == "main" and G.LEN or G.ANNEX end

-- distance on foot between two positions
function G:pathDist(seg1, p1, seg2, p2)
  if seg1 == seg2 then return math.abs(p1 - p2) end
  if seg1 == "main" then return math.abs(p1 - G.J) + p2 end
  return p1 + math.abs(p2 - G.J)
end

-- Move a figure `dist` along the path toward (seg, p). Returns what is left to walk.
function G:stepToward(f, seg, p, dist)
  local guard = 0
  while dist > 1e-6 and guard < 4 do
    guard = guard + 1
    if f.seg == seg then
      local d = p - f.p
      local s = math.min(dist, math.abs(d))
      f.p = f.p + (d >= 0 and 1 or -1) * s
      dist = dist - s
      break
    elseif f.seg == "main" then                 -- head for the junction, then turn in
      local d = G.J - f.p
      local s = math.min(dist, math.abs(d))
      f.p = f.p + (d >= 0 and 1 or -1) * s
      dist = dist - s
      if math.abs(G.J - f.p) < 1e-6 then f.seg, f.p = "annex", 0 end
    else                                        -- walk out of the side corridor
      local s = math.min(dist, f.p)
      f.p = f.p - s
      dist = dist - s
      if f.p < 1e-6 then f.seg, f.p = "main", G.J end
    end
  end
  return self:pathDist(f.seg, f.p, seg, p)
end

-- Brightness at a spot (0..1). withoutTorch = lamps only.
function G:lightAt(seg, p, withoutTorch)
  local sum = 0.03
  for _, l in ipairs(self.lamps[seg]) do
    local d = p - l.z
    sum = sum + l.I * 0.95 / (1 + d * d * 1.2)
  end
  if self.light and not withoutTorch and seg == self.seg then
    local d = self.dir * (p - self.z)
    if d > 0 then sum = sum + 0.8 / (1 + (d / 6) ^ 2) end
  end
  return math.min(1, sum)
end

---------------------------------------------------------------------------------------
-- what you can see, and what you can do
---------------------------------------------------------------------------------------
function G:lookingAway() return self.busy ~= nil or self.hide ~= nil or self.turn ~= nil end

-- Is this figure in front of your eyes right now? (Lit or not is a separate question.)
function G:sees(f)
  if not f.active or f.inside or self:lookingAway() then return false end
  if f.seg == self.seg then return self.dir * (f.p - self.z) > 0 end
  -- round the corner: you see one that stands in the junction itself
  if self.seg == "annex" then return self.dir == -1 and math.abs(f.p - G.J) < G.CORNER end
  return f.p < G.CORNER and self.dir * (G.J - self.z) > 0
end

-- where the figures think you are (the door, while you hide behind it)
function G:spot()
  if self.hide then return "main", self.hide.room.z end
  return self.seg, self.z
end

function G:gap(f)
  local seg, p = self:spot()
  return self:pathDist(f.seg, f.p, seg, p)
end

-- the nearest figure that is out in the corridors, and how far away it is on foot
function G:nearest()
  local best, bestGap
  for _, f in ipairs(self.figs) do
    if f.active and not f.inside then
      local gap = self:gap(f)
      if not best or gap < bestGap then best, bestGap = f, gap end
    end
  end
  return best, bestGap or math.huge
end

function G:say(text, seconds)
  self.msg, self.msgT = text, seconds or 5
end

function G:requestFor(room) return room.request end

function G:roundDone()
  if self.checked < #self.rooms then return false end
  for _, r in ipairs(self.rooms) do
    if r.request and r.request ~= "done" then return false end
  end
  return true
end

function G:atStation() return self.seg == "main" and self.z < 1.7 end

-- What E would do right now: the nearest usable thing in front of you.
-- Returns { kind = check / deliver / hide / annex / shelf / exit / clock, room = ..., d = distance }
function G:ahead()
  if self.mode ~= "play" or self.busy or self.hide or self.turn then return nil end
  local best
  local function offer(kind, d, room)
    if d > 0.4 and d < 2.4 and (not best or d < best.d) then best = { kind = kind, d = d, room = room } end
  end
  if self.seg == "main" then
    for _, r in ipairs(self.rooms) do
      local d = self.dir * (r.z - self.z)
      if not r.checked then offer("check", d, r)
      elseif r.request == "carried" then offer("deliver", d, r)
      elseif not r.lockUsed then offer("hide", d, r) end
    end
    offer("annex", self.dir * (G.J - self.z))
    if self.dir == 1 and G.LEN - self.z < 3.2 then offer("exit", 1) end
    if self:atStation() and self:roundDone() and (not best or best.kind == "hide") then best = { kind = "clock", d = 0 } end
  else
    if self.dir == 1 and G.ANNEX - self.z < 2.4 then offer("shelf", 1) end
  end
  return best
end

function G:prompt()
  local a = self:ahead()
  if not a then
    if self.hide then return "E   step out" end
    return nil
  end
  if a.kind == "check" then return ("E   check Bed %d"):format(a.room.bed) end
  if a.kind == "deliver" then return ("E   bring Bed %d the %s"):format(a.room.bed, a.room.asks) end
  if a.kind == "hide" then return ("E   hide in Bed %d's room"):format(a.room.bed) end
  if a.kind == "annex" then return "E   into the side corridor (supplies)" end
  if a.kind == "shelf" then return "E   search the shelves" end
  if a.kind == "exit" then return self.items.key and "E   unlock the EXIT" or "The EXIT is chained shut" end
  if a.kind == "clock" then return "E   clock out" end
end

function G:objective()
  if self.mode ~= "play" then return "" end
  if self:roundDone() then
    return "Round done. Clock out at the station" .. (self.items.key and ", or leave by the EXIT." or ".")
  end
  local parts = { ("Beds checked: %d / %d"):format(self.checked, #self.rooms) }
  for _, r in ipairs(self.rooms) do
    if r.request == "asked" then parts[#parts + 1] = ("Bed %d wants %s (supply room)"):format(r.bed, r.asks == "blanket" and "a blanket" or "water") end
    if r.request == "carried" then parts[#parts + 1] = ("take the %s to Bed %d"):format(r.asks, r.bed) end
  end
  return table.concat(parts, "     ")
end

function G:turnAround()
  if self.mode ~= "play" or self.busy or self.hide or self.turn then return end
  self.turn = G.TURN_TIME
  self.light = false
end

local function startBusy(g, kind, dur, room)
  g.busy = { kind = kind, t = 0, dur = dur, room = room }
  g.peek = (kind == "check" or kind == "deliver") and g.busy or nil
  g.light = false
end

function G:use()
  if self.mode ~= "play" or self.busy or self.turn then return end
  if self.hide then return self:leaveHide() end
  local a = self:ahead()
  if not a then
    if self:atStation() and not self:roundDone() then self:say("You can't clock out yet: the round isn't done.", 3) end
    return
  end
  if a.kind == "check" then
    startBusy(self, "check", G.PEEK_TIME, a.room)
    sfx.play("door", 0.9 + self.rng:random() * 0.2, 0.7)
  elseif a.kind == "deliver" then
    startBusy(self, "deliver", G.DELIVER_TIME, a.room)
    sfx.play("door", 1.1, 0.6)
  elseif a.kind == "hide" then
    local _, gap = self:nearest()
    if gap < G.SEE_YOU then
      self:say("Too close. It would see where you went.", 2.5)
    else
      self.hide = { room = a.room, t = 0 }
      self.z = a.room.z               -- you are at that door now, and that is where you step out
      self.light = false
      self.stats.hides = self.stats.hides + 1
      a.room.lockUsed = true
      sfx.play("door", 0.7, 0.8)
    end
  elseif a.kind == "annex" then
    self.entryDir = self.dir
    self.seg, self.z, self.dir = "annex", 0.7, 1
    self.fade = 0.35
  elseif a.kind == "shelf" then
    startBusy(self, "rummage", G.RUMMAGE_TIME)
    sfx.play("pen", 0.7)
  elseif a.kind == "exit" then
    if self.items.key then
      startBusy(self, "unlock", G.UNLOCK_TIME)
      sfx.play("door", 0.5, 0.8)
    else
      self:say("Chained and padlocked. The spare keys are kept in the supply room.", 4)
    end
  elseif a.kind == "clock" then
    self:win("clock")
  end
end

function G:win(how)
  self.mode = "won"
  self.ending = how
  self.time = self.t
  sfx.stop("hum")
  sfx.play("relief")
end

function G:leaveHide()
  self.hide = nil
  for _, f in ipairs(self.figs) do f.lost = false end      -- out in the open again: they hunt again
  self.fade = 0.25
  sfx.play("door", 1.0, 0.6)
end

function G:finishBusy()
  local b = self.busy
  self.busy, self.peek = nil, nil
  if b.kind == "check" then
    local r = b.room
    r.checked = true
    self.checked = self.checked + 1
    if r.battery then self.battery = math.min(1, self.battery + 0.5) end
    if r.asks then r.request = "asked" end
    if r.empty then self.figs[2].active = true end
    self:say(r.line, 6)
    sfx.play("pen")
    local k = DYING[self.checked]           -- another lamp gives up
    if k and self.lamps.main[k] then
      self.lamps.main[k].dead = true
      sfx.play("buzz", 0.8, 0.6)
    end
  elseif b.kind == "deliver" then
    b.room.request = "done"
    self.items[b.room.asks] = false
    self:say(b.room.thanks, 5)
  elseif b.kind == "rummage" then
    local got = {}
    for _, r in ipairs(self.rooms) do
      if r.request == "asked" then
        r.request = "carried"
        self.items[r.asks] = true
        got[#got + 1] = (r.asks == "blanket") and "a blanket" or "a jug of water"
      end
    end
    if not self.items.key then
      self.items.key = true
      got[#got + 1] = "the EXIT key"
    end
    if self.shelfBattery then
      self.shelfBattery = false
      self.battery = math.min(1, self.battery + 0.5)
      got[#got + 1] = "batteries"
    end
    if #got > 0 then self:say("You take " .. table.concat(got, ", ") .. ".", 5)
    else self:say("Nothing else you need here.", 3) end
    sfx.play("click", 0.8)
  elseif b.kind == "unlock" then
    self:win("exit")
  end
end

---------------------------------------------------------------------------------------
-- lamps and the two figures
---------------------------------------------------------------------------------------
function G:updateLamps(dt)
  local t = self.t
  local warn = self.blackout <= 0 and self.nextBlackout < 0.6     -- stutter before the power drops
  local off = self.blackout > 0 or self.mode == "caught" or self.mode == "dead"
  for _, list in pairs(self.lamps) do
    for _, l in ipairs(list) do
      local n = love.math.noise(t * 9 + l.seed)
      local v = 0.86 + n * 0.14
      if l.flicky then
        v = (love.math.noise(t * 3.1, l.seed) > 0.5) and (0.25 + n * 0.75) or 0.05
      end
      if warn then v = v * ((math.floor(t * 22) % 2 == 0) and 1 or 0.15) end
      if l.dead or off then v = 0 end
      l.I = v
    end
  end
end

local function goHome(g, f)
  f.state = "still"
  if f.kind == "B" then
    f.inside = true
    f.rest = 9                      -- it stays under the bed for a while
  end
end

function G:updateFigure(f, dt)
  f.moving = false
  if not f.active then return end
  if f.inside then
    f.rest = math.max(0, (f.rest or 0) - dt)
    return
  end
  if f.state == "flee" then                       -- recoiling from the torch
    local step = math.min(G.V_FLEE * dt, f.budget)
    f.budget = f.budget - step
    local left = self:stepToward(f, f.home.seg, f.home.p, step)
    if left < 0.01 then goHome(self, f) elseif f.budget <= 0 then f.state = "still" end
    return
  end
  if f.state == "wander" then                     -- it has lost you and is walking off
    local left = self:stepToward(f, f.home.seg, f.home.p, G.V_WANDER * dt)
    f.moving = true
    if left < 0.01 then goHome(self, f) end
    return
  end
  if f.state == "linger" then                     -- outside the door you are hiding behind
    f.lingerT = f.lingerT - dt
    if not self.hide then f.state = "still" return end
    if f.lingerT <= 0 then
      if f.kind == "A" then
        -- it searches on past the door and settles at the other end of the ward
        local cameFromFar = f.p >= self.hide.room.z
        f.home = { seg = "main", p = cameFromFar and G.NEAR_HOME or G.FAR_HOME }
        self:say(cameFromFar and "Its steps go on past the door, toward the station." or "Its steps go on past the door, toward the EXIT.", 5)
      else
        self:say("Something crawls away from the door.", 4)
      end
      f.state = "wander"
      f.lost = true                 -- it won't come back to this door while you stay behind it
    end
    return
  end
  if f.lost then
    if self.hide then return end
    f.lost = false
  end

  local seg, p = self:spot()
  local gap = self:pathDist(f.seg, f.p, seg, p)
  local seen = self:sees(f)
  if seen and self.light and gap < G.TORCH_REACH then
    f.exposure = f.exposure + dt
    if f.exposure >= G.REPEL_TIME then
      f.state, f.budget, f.exposure = "flee", G.REPEL_DIST, 0
      self.stats.repels = self.stats.repels + 1
      sfx.play("hiss", f.kind == "B" and 1.3 or 1)
    end
    return
  end
  f.exposure = math.max(0, f.exposure - dt * 0.5)
  local speed = 0
  if not seen then
    speed = (self.blackout > 0) and G.V_BLACKOUT or G.V_UNSEEN
  else
    -- pitch black (a blackout): it walks. Merely dim (dead lamps): it creeps.
    local L = self:lightAt(f.seg, f.p, true)
    if L < 0.2 then speed = ((self.blackout > 0) and G.V_BLACKOUT or G.V_CREEP) * (1 - L / 0.2) end
  end
  if self.hide then
    if gap <= 0.6 then
      f.state, f.lingerT = "linger", G.LINGER
      sfx.play("creep", 0.6, 1)
      return
    end
    speed = math.min(speed, (gap - 0.5) / dt)
  end
  if speed > 0.05 then
    self:stepToward(f, seg, p, speed * dt)
    f.moving = true
    f.stepT = f.stepT - dt * speed
    if f.stepT <= 0 then
      f.stepT = 0.9
      sfx.play("creep", (f.kind == "B" and 1.3 or 0.8) + self.rng:random() * 0.3, math.max(0.15, math.min(1, 1.2 - gap / 14)))
    end
  end
end

-- B comes out from under Bed 5 when the lights go, if you aren't standing at its door
function G:wakeB()
  local b = self.figs[2]
  if not (b.active and b.inside) or (b.rest or 0) > 0 then return end
  local seg, p = self:spot()
  if self:pathDist("main", 20, seg, p) < 3.5 then return end
  if self.rng:random() < 0.7 then
    b.inside, b.seg, b.p, b.state, b.exposure, b.lost = false, "main", 20, "still", 0, false
  end
end

local function caught(g)
  g.mode = "caught"
  g.caughtT = 0
  g.busy, g.peek, g.turn = nil, nil, nil
  g.light = false
  sfx.stop("hum")
  sfx.play("sting")
end

-- input = { fwd, back, light } held this frame. Call g:use() / g:turnAround() for the keys.
function G:update(dt, input)
  input = input or {}
  self.t = self.t + dt
  if self.fade then
    self.fade = self.fade - dt
    if self.fade <= 0 then self.fade = nil end
  end
  if self.mode == "caught" then
    self.caughtT = self.caughtT + dt
    local f = self.by
    if f and not self.hide then
      f.seg = self.seg
      f.p = f.p + (self.z + self.dir * 0.4 - f.p) * math.min(1, dt * 7)
    end
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
      self.nextBlackout = math.max(4.5, 7 + self.rng:random() * 3 - self.checked * 0.4)
      self.stats.blackouts = self.stats.blackouts + 1
      sfx.play("out")
      self:wakeB()
    elseif self.nextBlackout < 0.6 and self.nextBlackout + dt >= 0.6 then
      sfx.play("buzz")
    end
  end
  self:updateLamps(dt)

  if self.hide then
    self.hide.t = self.hide.t + dt
    self.vel = 0
    -- a light under the door while one of them stands outside it: found
    if input.light and self.battery > 0 then
      for _, f in ipairs(self.figs) do
        if f.active and not f.inside and f.state == "linger" then
          self.by = f
          self.hide = nil
          caught(self)
          return
        end
      end
    end
  elseif self.busy then
    self.busy.t = self.busy.t + dt
    self.vel = 0
    if self.busy.t >= self.busy.dur then self:finishBusy() end
    if self.mode ~= "play" then return end
  elseif self.turn then
    local before = self.turn
    self.turn = self.turn - dt
    if before > G.TURN_TIME / 2 and self.turn <= G.TURN_TIME / 2 then self.dir = -self.dir end
    if self.turn <= 0 then self.turn = nil end
    self.vel = 0
  else
    local was = self.light
    self.light = input.light and self.battery > 0 or false
    if self.light ~= was then sfx.play("click", self.light and 1.2 or 0.9) end
    if self.light then self.battery = math.max(0, self.battery - G.DRAIN * dt) end
    local v = 0
    if input.fwd then v = G.WALK * self.dir elseif input.back then v = -G.BACK * self.dir end
    local before = self.walk
    local lo, hi = 0.8, self:len(self.seg) - 1.4
    if self.seg == "annex" then lo = 0 end
    -- you can't walk through them
    for _, f in ipairs(self.figs) do
      if f.active and not f.inside and f.seg == self.seg then
        if f.p > self.z then hi = math.min(hi, f.p - 1.0) else lo = math.max(lo, f.p + 1.0) end
      end
    end
    self.z = math.max(lo, math.min(hi, self.z + v * dt))
    self.vel = v
    self.walk = self.walk + math.abs(v) * dt
    if math.floor(self.walk / 1.1) ~= math.floor(before / 1.1) then sfx.play("step", 0.9 + self.rng:random() * 0.2, 0.35) end
    -- stepping back out of the side corridor
    if self.seg == "annex" and self.z < 0.25 then
      self.seg, self.z, self.dir = "main", G.J, self.entryDir
      self.fade = 0.35
    end
  end

  for _, f in ipairs(self.figs) do self:updateFigure(f, dt) end
  local near, gap = self:nearest()
  -- your pulse, faster as one of them gets closer
  self.heartT = self.heartT - dt
  if gap < 10 and self.heartT <= 0 then
    self.heartT = 0.35 + gap * 0.07
    sfx.play("heart", 1, math.min(1, 1.3 - gap / 10))
  end
  if near and gap < G.CATCH and not self.hide then
    self.by = near
    caught(self)
  end
end

return G
