-- The play state: survival rules, hazards, narration, camera and HUD.
--
-- Get across town to Old Sal's rooftop coop before dawn. Hunger and warmth drain;
-- wings tire. Crumbs, trash cans and the diner's fries feed you; awnings and steam
-- vents warm you; ledges rest your wings. Cats stalk the alleys, taxis own the road.
-- Three feathers. Street lamps you perch on are where you come back to.

local city = require("src.city")
local Pigeon = require("src.pigeon")
local R = require("src.render")
local text = require("src.content")
local sfx = require("src.sfx")

local lg = love.graphics
local game = {}

game.NIGHT = 360            -- seconds of real time from midnight to dawn (6:00)
local START_X = 200

function game.new()
  local g = setmetatable({}, { __index = game })
  g.c = city.build()
  g.pigeon = Pigeon.new(START_X)
  g.checkpoint = { x = START_X, y = city.SIDEWALK }
  g.t, g.clock, g.camX = 0, 0, 0
  g.hunger, g.warmth, g.feathers = 85, 90, 3
  g.cars, g.carTimer = {}, 5
  g.flash, g.lightning, g.invert = 0, 12, 0
  g.firsts, g.captions, g.capT = {}, {}, 0
  g.mode = "play"           -- play | dead | won
  g.starve = 0
  g.eaten = 0
  g.input = {}
  for _, l in ipairs(text.intro) do g.captions[#g.captions + 1] = l end
  return g
end

-- Narration --------------------------------------------------------------------------------
function game:narrate(key)
  if self.firsts[key] then return end
  self.firsts[key] = true
  self.captions[#self.captions + 1] = text.first[key]
end

-- Damage and death --------------------------------------------------------------------------
function game:hit(reason)
  local p = self.pigeon
  if p.hurt > 0 or self.mode ~= "play" then return false end
  self.feathers = self.feathers - 1
  p.hurt = 2
  p.vy, p.vx, p.on = -220, -p.dir * 160, nil
  self.invert = 0.14
  sfx.play("sting", 1, 0.8)
  if self.feathers <= 0 then
    self:die(reason)
  else
    self:narrate("hit")
  end
  return true
end

function game:die(reason)
  self.mode = "dead"
  self.deathReason = reason
  self.deathT = 0
  sfx.play("sting", 0.7, 1)
end

function game:respawn()
  local cp = self.checkpoint
  self.pigeon = Pigeon.new(cp.x, cp.y)
  self.pigeon.hurt = 2
  self.feathers = 3
  self.hunger = math.max(self.hunger, 60)
  self.warmth = math.max(self.warmth, 60)
  if self.deathReason == "dawn" then self.clock = game.NIGHT - 90 end
  self.cars = {}
  for _, cat in ipairs(self.c.cats) do cat.x, cat.state, cat.y = cat.home, "idle", city.SIDEWALK end
  self.mode = "play"
  self.captions = { text.retry }
  self.capT = 0
end

-- Pecking ------------------------------------------------------------------------------------
function game:peck()
  local p, c = self.pigeon, self.c
  if self.mode ~= "play" then return nil end
  p:startPeck()
  local bx = p.x + p.dir * 24
  for _, cr in ipairs(c.crumbs) do
    if cr.alive and math.abs(cr.x - bx) < 32 and math.abs(cr.y - p.y) < 12 then
      cr.alive = false
      cr.respawn = cr.home and 25 or 0
      self.hunger = math.min(100, self.hunger + cr.food)
      self.eaten = self.eaten + 1
      sfx.play("eat", 1 + love.math.random() * 0.2, 0.6)
      self:narrate(cr.fries and "fries" or "crumb")
      return "eat"
    end
  end
  if p:onGround() and p.on.kind == "sidewalk" then
    for _, tr in ipairs(c.trash) do
      if not tr.knocked and math.abs(tr.x - bx) < 50 then
        tr.knocked, tr.reset = true, 45
        for k = 1, 3 do
          c.crumbs[#c.crumbs + 1] = { x = tr.x + 30 + k * 18, y = city.SIDEWALK, food = 14, alive = true, respawn = 0 }
        end
        sfx.play("step", 0.5, 0.9)
        self:narrate("trash")
        return "trash"
      end
    end
  end
  return "peck"
end

-- Update -------------------------------------------------------------------------------------
function game:readInput()
  local kb = love.keyboard
  self.input.left = kb.isDown("left") or kb.isDown("a")
  self.input.right = kb.isDown("right") or kb.isDown("d")
  self.input.flapHeld = kb.isDown("space") or kb.isDown("w") or kb.isDown("up")
end

function game:keypressed(k)
  if self.mode == "dead" then
    if self.deathT > 1 then self:respawn() end
    return
  end
  if k == "space" or k == "w" or k == "up" then self.input.flapPressed = true
  elseif k == "down" or k == "s" then self.input.dropPressed = true
  elseif k == "e" or k == "j" or k == "return" then self:peck()
  elseif k == "tab" then self.captions = {} end
end

function game:updateCats(dt)
  local p = self.pigeon
  local reachable = p.y >= city.SIDEWALK - 70 and p.hurt == 0
  for _, cat in ipairs(self.c.cats) do
    local dx = p.x - cat.x
    if cat.state == "idle" then
      if reachable and math.abs(dx) < 260 then
        cat.state, cat.t, cat.dir = "stalk", 0.9, dx > 0 and 1 or -1
        sfx.play("hiss", 1, 0.6)
        self:narrate("cat")
      end
    elseif cat.state == "stalk" then
      cat.t = cat.t - dt
      cat.dir = dx > 0 and 1 or -1
      cat.x = cat.x + cat.dir * 30 * dt
      if cat.t <= 0 then
        cat.state, cat.t = "pounce", 0
        cat.from, cat.to = cat.x, p.x + (p.vx * 0.3)
      end
    elseif cat.state == "pounce" then
      cat.t = cat.t + dt / 0.55
      local f = math.min(1, cat.t)
      cat.x = cat.from + (cat.to - cat.from) * f
      cat.y = city.SIDEWALK - math.sin(math.pi * f) * 95
      if math.abs(p.x - cat.x) < 36 and math.abs((p.y - 20) - (cat.y - 25)) < 42 then self:hit("cat") end
      if f >= 1 then cat.state, cat.t, cat.y = "recover", 1.6, city.SIDEWALK end
    elseif cat.state == "recover" then
      cat.t = cat.t - dt
      if cat.t <= 0 then
        local back = cat.home - cat.x
        cat.dir = back > 0 and 1 or -1
        cat.x = cat.x + cat.dir * math.min(math.abs(back), 50 * dt)
        if math.abs(back) < 2 then cat.state = "idle" end
      end
    end
  end
end

function game:updateCars(dt)
  local p = self.pigeon
  self.carTimer = self.carTimer - dt
  if self.carTimer <= 0 then
    self.carTimer = 3 + love.math.random() * 4
    local dir = love.math.random() < 0.5 and 1 or -1
    local x = dir > 0 and self.camX - 700 or self.camX + 1980
    self.cars[#self.cars + 1] = { x = x, dir = dir, speed = 560 + love.math.random() * 160, honked = false }
    sfx.play("car", 0.8 + love.math.random() * 0.4, 0.4)
  end
  local onRoad = p.on and p.on.kind == "road"
  for i = #self.cars, 1, -1 do
    local car = self.cars[i]
    car.x = car.x + car.dir * car.speed * dt
    local ahead = (p.x - car.x) * car.dir
    if onRoad and not car.honked and ahead > 0 and ahead < 900 then
      car.honked = true
      sfx.play("horn", 1, 0.7)
      self:narrate("car")
    end
    if p.y > city.ROAD - 34 and math.abs(p.x - car.x) < 82 then self:hit("car") end
    if car.x < self.camX - 1500 or car.x > self.camX + 2800 then table.remove(self.cars, i) end
  end
end

function game:update(dt, scripted)
  self.t = self.t + dt
  R.updateRain(dt)
  sfx.loop("rain", 0.5)
  self.invert = math.max(0, self.invert - dt)
  self:updateLightning(dt)
  self:updateCaptions(dt)
  if self.mode == "dead" then self.deathT = self.deathT + dt return end
  if self.mode == "won" then self.wonT = self.wonT + dt return end

  if not scripted then self:readInput() end
  local p, c = self.pigeon, self.c
  p:update(dt, self.input, c.platforms)
  self.input.flapPressed, self.input.dropPressed = false, false
  self.clock = self.clock + dt

  -- meters
  self.hunger = math.max(0, self.hunger - 0.85 * dt)
  local shelter = city.sheltered(c, p.x, p.y)
  local vent = city.nearVent(c, p.x, p.y)
  if vent then
    self.warmth = math.min(100, self.warmth + 14 * dt)
    self:narrate("warm")
  elseif shelter then
    self.warmth = math.min(100, self.warmth + 9 * dt)
    self:narrate("shelter")
  else
    self.warmth = math.max(0, self.warmth - 1.1 * dt)
  end
  if self.warmth < 60 then self:narrate("cold") end
  if self.hunger < 35 then self:narrate("hungry") end
  if p.stamina < 15 then self:narrate("tired") end
  if self.hunger <= 0 or self.warmth <= 0 then
    self.starve = self.starve + dt
    if self.starve > 5 then
      self.starve = 0
      self.feathers = self.feathers - 1
      sfx.play("sting", 1.2, 0.5)
      if self.feathers <= 0 then self:die(self.hunger <= 0 and "hunger" or "cold") end
    end
  else
    self.starve = 0
  end
  if p.on and p.on.kind == "road" then self:narrate("road") end
  if p.on and p.on.kind == "lamp" and self.checkpoint.lamp ~= p.on.lamp then
    self.checkpoint = { x = p.on.lamp.x, y = p.on.lamp.y, lamp = p.on.lamp }
    sfx.play("coo", 1, 0.7)
    self:narrate("lamp")
  end

  -- food comes back; the cook throws out fries now and then
  for _, cr in ipairs(c.crumbs) do
    if not cr.alive and cr.home then
      cr.respawn = cr.respawn - dt
      if cr.respawn <= 0 then cr.alive = true end
    end
  end
  for _, tr in ipairs(c.trash) do
    if tr.knocked then
      tr.reset = tr.reset - dt
      if tr.reset <= 0 then tr.knocked = false end
    end
  end
  local d = c.diner
  d.nextThrow = d.nextThrow - dt
  if d.nextThrow <= 0 then
    d.nextThrow = 22
    if math.abs(p.x - d.x) < 900 then
      for k = 1, 4 do
        c.crumbs[#c.crumbs + 1] = { x = d.x + 20 + k * 26, y = city.SIDEWALK, food = 20, alive = true, respawn = 0, fries = true }
      end
      self.door = 1.2
    end
  end
  self.door = math.max(0, (self.door or 0) - dt)

  self:updateCats(dt)
  self:updateCars(dt)

  if self.clock >= game.NIGHT then self:die("dawn") end
  if p.on and p.on.kind == "roof" and p.on.x1 >= 5400 and p.x > c.coop.x - 160 and self.mode == "play" then
    self.mode, self.wonT = "won", 0
    p.hurt = 0             -- no blinking at the finish line
    self.captions, self.capT = {}, 0
    for _, l in ipairs(text.ending) do self.captions[#self.captions + 1] = l end
    sfx.play("chord", 1, 0.8)
    sfx.play("coo", 1.1, 0.8)
  end

  -- camera and captions
  local target = p.x - 640 + p.dir * 120
  self.camX = self.camX + (target - self.camX) * math.min(1, dt * 3)
  self.camX = math.max(0, math.min(city.W - 1280, self.camX))
end

function game:updateCaptions(dt)
  if #self.captions > 0 then
    self.capT = self.capT + dt
    if self.capT > 3.2 + #self.captions[1] * 0.03 then
      table.remove(self.captions, 1)
      self.capT = 0
    end
  end
end

function game:updateLightning(dt)
  self.lightning = self.lightning - dt
  if self.lightning <= 0 then
    self.lightning = 14 + love.math.random() * 14
    self.flashT = 0
    if love.math.random() < 0.4 then sfx.play("siren", 1, 0.8) end
  end
  if self.flashT then
    self.flashT = self.flashT + dt
    local f = self.flashT
    self.flash = (f < 0.1 or (f > 0.18 and f < 0.26)) and 1 or 0
    if f > 0.3 then self.flashT, self.flash = nil, 0 end
  end
end

-- Drawing ------------------------------------------------------------------------------------
function game:drawWorld()
  local c, t, cam = self.c, self.t, self.camX
  R.backdrop(cam, self.flash, t)
  lg.push()
  lg.translate(-math.floor(cam), 0)
  for _, b in ipairs(c.buildings) do
    if b.x2 > cam - 50 and b.x1 < cam + 1330 then R.building(b, t, text.signs, self.flash) end
  end
  if self.flash <= 0 then
    for _, e in ipairs(c.escapes) do R.escape(e) end
    lg.setColor(0.85, 0.85, 0.85)
    lg.setLineWidth(2)
    for _, w in ipairs(c.wires) do lg.line(w.x1, w.y, (w.x1 + w.x2) / 2, w.y + 6, w.x2, w.y) end
  end
  R.street(cam)
  for _, l in ipairs(c.lamps) do R.lamp(l, t) end
  for _, s in ipairs(c.shelters) do R.awning(s) end
  R.reflections(c, cam, t)
  for _, v in ipairs(c.vents) do R.vent(v, t) end
  -- the diner door swings open when the cook throws out fries
  if self.door > 0 then
    lg.setColor(0.9, 0.9, 0.9)
    lg.rectangle("fill", c.diner.x - 20, city.SIDEWALK - 70, 40, 70)
    lg.setColor(0.05, 0.05, 0.05)
    lg.circle("fill", c.diner.x, city.SIDEWALK - 52, 8)
    lg.rectangle("fill", c.diner.x - 10, city.SIDEWALK - 44, 20, 30)
  end
  for _, tr in ipairs(c.trash) do R.trash(tr) end
  for _, cr in ipairs(c.crumbs) do R.crumb(cr, t) end
  R.coop(c.coop, t, self.mode == "won")
  for _, cat in ipairs(c.cats) do
    if cat.x > cam - 80 and cat.x < cam + 1360 then R.cat(cat, t) end
  end
  self.pigeon:draw(t)
  for _, car in ipairs(self.cars) do R.car(car, t) end
  lg.pop()
end

-- HUD text with a black shadow, so it reads on white lightning too
local function shadowText(str, x, y, w, align)
  local r, g, b, a = lg.getColor()
  lg.setColor(0, 0, 0, a)
  lg.printf(str, x + 2, y + 2, w, align)
  lg.setColor(r, g, b, a)
  lg.printf(str, x, y, w, align)
end

local function bar(x, y, w, v, color, label, font)
  lg.setColor(0, 0, 0, 0.85)
  lg.rectangle("fill", x - 2, y - 2, w + 4, 14)
  lg.setColor(color)
  lg.rectangle("fill", x, y, w * v / 100, 10)
  lg.setColor(1, 1, 1)
  lg.rectangle("line", x - 2, y - 2, w + 4, 14)
  lg.setFont(font)
  shadowText(label, x - 110, y - 4, 100, "right")
end

-- comic caption box (narration)
function game:drawCaption(x, y)
  local f = self.fonts
  local cap = self.captions[1]
  if cap then
    local shown = cap:sub(1, math.floor(self.capT * 60))
    lg.setFont(f.caption)
    local w = 560
    local _, lines = f.caption:getWrap(cap, w - 32)
    local h = #lines * f.caption:getHeight() + 26
    lg.setColor(0, 0, 0, 0.92)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(1, 1, 1)
    lg.setLineWidth(2)
    lg.rectangle("line", x, y, w, h)
    lg.printf(shown, x + 16, y + 12, w - 32)
  end
end

function game:drawHUD()
  local f = self.fonts
  if self.mode ~= "won" or self.wonT < 3 then self:drawCaption(24, 24) end
  -- clock, meters, feathers (top right)
  local mins = math.floor(self.clock / game.NIGHT * 360)
  local hh, mm = math.floor(mins / 60), mins % 60
  lg.setFont(f.clock)
  lg.setColor(1, 1, 1)
  shadowText(("%d:%02d AM"):format(hh == 0 and 12 or hh, mm), 0, 20, 1256, "right")
  local x = 1100
  bar(x, 76, 150, self.hunger, { 1, 0.85, 0.1 }, "HUNGER", f.small)
  bar(x, 98, 150, self.warmth, { 1, 1, 1 }, "WARMTH", f.small)
  bar(x, 120, 150, self.pigeon.stamina, { 0.7, 0.7, 0.7 }, "WINGS", f.small)
  for i = 1, 3 do
    local fx = 1250 - (i - 1) * 26
    lg.setColor(i <= self.feathers and { 1, 1, 1 } or { 0.35, 0.35, 0.35 })
    lg.polygon("fill", fx, 150, fx + 7, 160, fx + 4, 182, fx - 4, 182, fx - 7, 160)
  end
  if self.mode == "play" and self.t < 30 then
    lg.setFont(f.small)
    lg.setColor(1, 1, 1, 0.7)
    lg.printf("arrows / A D: walk    Space: flap (hold to glide)    Down: drop off a ledge / into the road    E: peck",
      0, 694, 1280, "center")
  end
end

function game:draw()
  lg.push("all")
  lg.setCanvas(R.scene)
  lg.clear(0, 0, 0, 1)
  self:drawWorld()
  lg.pop()
  R.present(self.t, self.invert > 0 and 1 or 0)
  R.rainDraw()
  self:drawHUD()

  local f = self.fonts
  if self.mode == "dead" then
    local a = math.min(1, self.deathT * 2)
    lg.setColor(1, 1, 1, a)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setColor(0, 0, 0, a)
    lg.setFont(f.big)
    lg.printf("FEATHERED.", 0, 220, 1280, "center")
    lg.setFont(f.caption)
    lg.printf(text.death[self.deathReason] or "", 240, 330, 800, "center")
    lg.setColor(0.8, 0.05, 0.05, a)
    lg.rectangle("fill", 520, 300, 240, 6)
    if self.deathT > 1 then
      lg.setColor(0, 0, 0, 0.5 + 0.3 * math.sin(self.t * 4))
      lg.setFont(f.small)
      lg.printf("press any key to try again from the last lamp", 0, 470, 1280, "center")
    end
  elseif self.mode == "won" then
    -- hold on Gus at the coop for a moment, then fade to the morning card
    local a = math.max(0, math.min(1, (self.wonT - 3) * 0.4))
    lg.setColor(1, 1, 1, a)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setColor(0, 0, 0, a)
    lg.setFont(f.big)
    lg.printf("MORNING.", 0, 230, 1280, "center")
    lg.setFont(f.caption)
    local mins = math.floor(self.clock / game.NIGHT * 360)
    lg.printf(("Made it to Sal's at %d:%02d AM, with %d crumb%s in my belly and %d feather%s to spare.")
      :format(math.floor(mins / 60) == 0 and 12 or math.floor(mins / 60), mins % 60, self.eaten, self.eaten == 1 and "" or "s",
        self.feathers, self.feathers == 1 and "" or "s"), 240, 330, 800, "center")
    lg.setColor(1, 0.85, 0.1, a)
    lg.rectangle("fill", 560, 310, 160, 6)
    if self.wonT >= 3 then self:drawCaption(360, 460) end -- the ending narration, over the dawn
  end
end

return game
