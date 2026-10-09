-- Foraging: walk around the planet surface, grab ingredients, dodge Form Drones,
-- then head back to the truck to open shop.
local scenes = require("src.core.scenes")
local rng = require("src.core.rng")
local vp = require("src.core.viewport")
local sfx = require("src.core.sfx")
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local A = require("src.ui.art")
local fx = require("src.ui.fx")
local Terrain = require("src.ui.terrain")
local Guide = require("src.ui.guide")
local Run = require("src.game.run")
local ING = require("content.ingredients")
local SPECIES = require("content.species")
local lg = love.graphics

local F = {}
local TRUCK = { x = 130, y = 640 }
local HUD_H = 56

function F:enter()
  local run = Run.current
  self.run, self.planet = run, run.planet
  local q = self.planet.quirk
  self.t = 0
  self.time = 40 + (q.forageTime or 0)
  self.timeLeft = self.time
  self.chef = { x = 260, y = 600, dir = 1, stun = 0, moving = false }
  self.speed = 230 * (Run.has(run, "jetboots") and 1.4 or 1) * (q.forageSpeed or 1)
  self.cap = Run.basketSize(run)
  self.basket = {}
  self.items = {}
  self.drones = {}
  self.props = Terrain.groundProps(self.planet)
  self.leftTruck = false
  self.done = false
  self.fullWarned = false
  for _ = 1, 10 do self:spawnItem() end
  self.spawnT = 3
  local nd = 1 + (q.drones or 0) + (run.day >= 3 and 1 or 0)
  for i = 1, nd do
    self.drones[i] = { x = rng.float(700, 1200), y = rng.float(150, 650), t = rng.float(0, 6) }
  end
  self.btn = { x = 1085, y = 8, w = 180, h = 40, label = "Open shop  >", size = 16 }
  fx.clear()
  Guide.sayKey("forage_start")
end

function F:spawnItem()
  for _ = 1, 30 do
    local x, y = rng.float(60, 1220), rng.float(HUD_H + 50, 690)
    local dt = math.sqrt((x - TRUCK.x) ^ 2 + (y - TRUCK.y) ^ 2)
    local dc = math.sqrt((x - self.chef.x) ^ 2 + (y - self.chef.y) ^ 2)
    if dt > 170 and dc > 120 then
      local id = rng.pick(self.planet.pool)
      local def = ING.byId[id]
      self.items[#self.items + 1] = { id = id, def = def, x = x, y = y, phase = rng.float(0, 6),
        fuse = def.volatile and rng.float(7, 13) or nil, age = 0 }
      return
    end
  end
end

function F:finish()
  if self.done then return end
  self.done = true
  self.run.lastForage = #self.basket
  scenes.switch(require("src.scenes.shop"))
end

function F:update(dt)
  self.t = self.t + dt
  if self.done then return end
  local c = self.chef
  self.timeLeft = self.timeLeft - dt
  if self.timeLeft <= 0 then
    self.timeLeft = 0
    self:finish()
    return
  end

  -- movement: keys, or hold the mouse / finger
  local dx, dy = 0, 0
  if love.keyboard.isDown("left", "a") then dx = dx - 1 end
  if love.keyboard.isDown("right", "d") then dx = dx + 1 end
  if love.keyboard.isDown("up", "w") then dy = dy - 1 end
  if love.keyboard.isDown("down", "s") then dy = dy + 1 end
  if dx == 0 and dy == 0 and self.mouseHeld then
    local mx, my = vp.mouse()
    local ddx, ddy = mx - c.x, my - c.y
    if ddx * ddx + ddy * ddy > 100 then dx, dy = ddx, ddy end
  end
  c.moving = false
  if c.stun > 0 then
    c.stun = c.stun - dt
  elseif dx ~= 0 or dy ~= 0 then
    local l = math.sqrt(dx * dx + dy * dy)
    c.x = math.max(30, math.min(1250, c.x + dx / l * self.speed * dt))
    c.y = math.max(HUD_H + 40, math.min(700, c.y + dy / l * self.speed * dt))
    c.moving = true
    if dx ~= 0 then c.dir = dx > 0 and 1 or -1 end
  end

  -- truck: leave once you've wandered off and come back
  local dTruck = math.sqrt((c.x - TRUCK.x) ^ 2 + (c.y - (TRUCK.y - 40)) ^ 2)
  if dTruck > 200 then self.leftTruck = true end
  if self.leftTruck and dTruck < 90 then self:finish() return end

  -- items
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    it.age = it.age + dt
    local d = math.sqrt((c.x - it.x) ^ 2 + (c.y - it.y) ^ 2)
    if it.fuse then it.fuse = it.fuse - dt end
    if d < 34 and c.stun <= 0 then
      if #self.basket < self.cap then
        table.remove(self.items, i)
        table.insert(self.basket, it.id)
        local revealed = Run.add(self.run, it.id)
        fx.pop("+ " .. it.def.name, it.x, it.y - 30, it.def.color, 16)
        fx.burst(it.x, it.y, 10, it.def.color, 120, { grav = 0, life = 0.5 })
        sfx.play("pick", 0.9 + #self.basket * 0.05)
        if revealed then Guide.sayKey("discover", { name = it.def.name, tag = revealed }) end
        if #self.basket >= self.cap then Guide.sayKey("basket_full") end
      elseif not self.fullWarned then
        self.fullWarned = true
        fx.pop("Basket full!", c.x, c.y - 50, T.c.bad, 18)
      end
    elseif it.fuse and it.fuse <= 0 then
      table.remove(self.items, i)
      fx.burst(it.x, it.y, 30, { 1, 0.6, 0.2 }, 260, { grav = 0, life = 0.6, size = 7 })
      fx.burst(it.x, it.y, 14, it.def.color, 160, { grav = 0, life = 0.8 })
      fx.shake(5, 0.25)
      sfx.play("boom", 1.4)
      if d < 100 then
        c.stun = 0.7
        Guide.sayKey("volatile_pop")
      end
    end
  end
  self.spawnT = self.spawnT - dt
  if self.spawnT <= 0 then
    if #self.items < 12 then self:spawnItem() end
    self.spawnT = rng.float(2.5, 4.5)
  end

  -- drones drift toward you and fine you on contact
  local ds = 75 + self.run.day * 6
  for _, d in ipairs(self.drones) do
    d.t = d.t + dt
    local ddx, ddy = c.x - d.x, c.y - d.y
    local l = math.sqrt(ddx * ddx + ddy * ddy) + 0.01
    d.x = d.x + (ddx / l * ds + math.sin(d.t * 2) * 40) * dt
    d.y = d.y + (ddy / l * ds + math.cos(d.t * 1.7) * 40) * dt
    if l < 38 and c.stun <= 0 then
      local fine = math.min(8, self.run.flurbos)
      self.run.flurbos = self.run.flurbos - fine
      c.stun = 0.8
      fx.pop("-" .. fine .. "F  Form 99-Z: Loitering", c.x, c.y - 50, T.c.bad, 16)
      sfx.play("fine")
      Guide.sayKey("fined")
      d.x = (c.x < 640) and 1220 or 60
      d.y = rng.float(150, 650)
    end
  end
end

function F:draw()
  local t = self.t
  local p = self.planet
  Terrain.drawGround(p, self.props, t)

  -- truck parked at the drop-off point
  lg.setColor(1, 1, 1, 0.15 + 0.1 * math.sin(t * 4))
  lg.circle("fill", TRUCK.x, TRUCK.y - 40, 90)
  A.truck(TRUCK.x, TRUCK.y, 0.6, t, { noFlame = true })
  if self.leftTruck then
    D.text("back to truck = open shop", TRUCK.x - 100, TRUCK.y + 18, 13, T.c.ink, "center", 200)
  end

  for _, it in ipairs(self.items) do
    local bob = math.sin(t * 3 + it.phase) * 4
    local pulse = 1
    if it.fuse and it.fuse < 3 then
      pulse = 1 + 0.15 * math.sin(t * (30 - it.fuse * 6))
      lg.setColor(1, 0.3, 0.2, 0.35)
      lg.circle("fill", it.x, it.y + bob, 34)
    end
    lg.setColor(0, 0, 0, 0.25)
    lg.ellipse("fill", it.x, it.y + 22, 16, 5)
    lg.setColor(1, 1, 1, 0.12)
    lg.circle("fill", it.x, it.y + bob, 28)
    A.ingredient(it.x, it.y + bob, 22 * pulse * math.min(1, it.age * 4), it.def, t)
  end

  for _, d in ipairs(self.drones) do A.drone(d.x, d.y, d.t) end
  A.chef(self.chef.x, self.chef.y, t, self.chef.moving, self.chef.dir, self.chef.stun > 0)

  self:drawHud()

  -- arrival card
  if self.t < 6 then
    local a = math.min(1, (6 - self.t) / 0.6)
    lg.push()
    D.panel(340, 90, 600, 170, { T.c.panel[1], T.c.panel[2], T.c.panel[3], 0.92 * a }, { T.c.edge[1], T.c.edge[2], T.c.edge[3], a })
    D.text("ARRIVED: " .. p.name, 360, 104, 26, { T.c.gold[1], T.c.gold[2], T.c.gold[3], a })
    D.text(p.epithet, 360, 138, 15, { T.c.dim[1], T.c.dim[2], T.c.dim[3], a })
    D.text("Local quirk: " .. p.quirk.text, 360, 164, 14, { T.c.teal[1], T.c.teal[2], T.c.teal[3], a }, "left", 560)
    local names = {}
    for _, id in ipairs(p.residents) do names[#names + 1] = SPECIES.byId[id].plural end
    D.text("Locals: " .. table.concat(names, ", "), 360, 190, 14, { T.c.ink[1], T.c.ink[2], T.c.ink[3], a }, "left", 560)
    D.text("WASD / arrows, or hold the mouse to walk. Grab ingredients, avoid Form Drones.", 360, 222, 13, { T.c.faint[1] + 0.2, T.c.faint[2] + 0.2, T.c.faint[3] + 0.2, a }, "left", 560)
    lg.pop()
  end

  Guide.draw(260, 630, 760, 80, 0.92)
end

function F:drawHud()
  D.panel(-10, -10, 1300, HUD_H + 10, T.c.panel, T.c.edge, 0)
  D.text("DAY " .. self.run.day .. "  -  " .. self.planet.name, 16, 6, 18, T.c.ink)
  -- timer bar
  local k = self.timeLeft / self.time
  lg.setColor(0.2, 0.18, 0.3)
  D.rrect("fill", 16, 32, 300, 12, 6)
  D.color(k > 0.3 and T.c.teal or T.c.bad)
  D.rrect("fill", 16, 32, 300 * k, 12, 6)
  D.text(string.format("%ds", math.ceil(self.timeLeft)), 324, 28, 14, T.c.dim)
  -- basket
  D.text("Basket " .. #self.basket .. "/" .. self.cap, 400, 16, 16, T.c.ink)
  for i, id in ipairs(self.basket) do
    A.ingredient(520 + (i - 1) * 34, 28, 13, ING.byId[id], self.t)
  end
  D.coin(940, 28, 11)
  D.text(tostring(self.run.flurbos), 958, 18, 18, T.c.gold)
  local mx, my = vp.mouse()
  self.btn.enabled = not self.done
  D.button(self.btn, mx, my)
end

function F:mousepressed(x, y, b)
  if D.inside(self.btn, x, y) then self:finish() return end
  if b == 1 then self.mouseHeld = true end
end

function F:mousereleased() self.mouseHeld = false end

function F:keypressed(k)
  if k == "return" then self:finish() end
end

return F
