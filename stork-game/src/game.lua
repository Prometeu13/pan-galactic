-- The play state: input, interactions, quests, camera, dialogue and HUD.
--
-- The loop: wander the valley, peck up twigs, fish in the shallows, bring them to the
-- nest. Seal stones "paint in" their part of the valley (the world starts as a faint
-- sketch). A fisherman lost his lantern. When the nest is mended and the chick fed,
-- dusk falls and the village lanterns go up.

local ink = require("src.ink")
local world = require("src.world")
local Stork = require("src.stork")
local scenery = require("src.scenery")
local text = require("src.content")
local sfx = require("src.sfx")

local lg = love.graphics
local game = {}

local TWIGS_NEEDED, FISH_NEEDED = 5, 3

function game.new()
  local g = setmetatable({}, { __index = game })
  g.w = world.build()
  g.stork = Stork.new(560)
  g.t = 0
  g.camX = 0
  g.reveal = { 0, 0, 0 }      -- shown amount per region (animated)
  g.revealTarget = { 0, 0, 0 }
  g.sealsRead = 0
  g.nest = g.w.nest
  g.nest.twigs, g.nest.fed = 0, 0
  g.quest = { asked = false, returned = false, frogLine = 0, villagerLine = 0 }
  g.dialogue = {}            -- queue of lines; the first one is on screen
  g.typed = 0
  g.haiku = nil
  g.toasts, g.ripples, g.drops, g.leaves, g.lanterns = {}, {}, {}, {}, {}
  g.region, g.regionShow = 0, 0
  g.dusk, g.ended = 0, false
  g.rippleTimer = 0
  for k = 1, 18 do
    g.leaves[k] = { x = love.math.random(0, 1280), y = love.math.random(0, 720), p = love.math.random() * 6, s = 0.6 + love.math.random() * 0.6 }
  end
  g.input = { left = false, right = false, flapHeld = false, flapPressed = false }
  g:say(text.intro)
  return g
end

-- Dialogue ------------------------------------------------------------------------------
function game:say(lines, speaker)
  for _, l in ipairs(lines) do self.dialogue[#self.dialogue + 1] = { text = l, speaker = speaker } end
  self.typed = 0
end

function game:advance()
  local line = self.dialogue[1]
  if not line then return end
  if self.typed < #line.text then
    self.typed = #line.text          -- first press finishes the line
  else
    table.remove(self.dialogue, 1)
    self.typed = 0
    sfx.note(nil, 0.25)
  end
end

function game:toast(msg, x, y)
  self.toasts[#self.toasts + 1] = { msg = msg, x = x, y = y, life = 2 }
end

-- How inked a spot is: 0.25 = faint sketch, 1 = fully painted.
function game:inkAt(x)
  local f = 0
  for i, s in ipairs(self.w.seals) do
    local R = self.reveal[i] * 1500
    if R > 0 then f = math.max(f, ink.smooth(R, R - 300, math.abs(x - s.x))) end
  end
  return 0.25 + 0.75 * f
end

-- Interactions ------------------------------------------------------------------------------
local function dist(x1, y1, x2, y2) return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) end

function game:interact()
  if #self.dialogue > 0 then self:advance() return "dialogue" end
  local s, w = self.stork, self.w
  s:startPeck()
  local rx, ry = s:reach()

  -- 1) things the beak can pick up
  for _, tw in ipairs(w.twigs) do
    if not tw.taken and dist(rx, ry, tw.x, tw.y) < 55 then
      tw.taken = true
      s.carry.twigs = s.carry.twigs + 1
      self:toast("+1 twig", tw.x, tw.y - 30)
      sfx.note(5, 0.6)
      return "twig"
    end
  end
  local l = w.lantern
  if not l.taken and dist(rx, ry, l.x, l.y) < 55 then
    l.taken = true
    s.carry.lantern = true
    self:toast("a red paper lantern", l.x, l.y - 30)
    sfx.note(6, 0.6)
    return "lantern"
  end
  local level = world.water(rx)
  if level and ry > level - 20 and not s.air then
    for _, f in ipairs(w.fish) do
      if not f.caught and math.abs(f.x - rx) < 42 and f.water == select(2, world.water(rx)) then
        f.caught, f.respawn = true, 8
        s.carry.fish = s.carry.fish + 1
        self:toast("+1 fish", rx, level - 40)
        self:splash(rx, level)
        sfx.play("splash", 1, 0.6)
        sfx.note(4, 0.6)
        return "fish"
      end
    end
    self:splash(rx, level)
    sfx.play("splash", 1.4, 0.3)
  end

  -- 2) the nest
  if dist(s.x, s.y - 40, self.nest.x, self.nest.y) < 110 then return self:atNest() end

  -- 3) seal stones
  for i, seal in ipairs(w.seals) do
    if not seal.read and math.abs(s.x - seal.x) < 70 and not s.air then
      seal.read = true
      self.revealTarget[i] = 1
      self.sealsRead = self.sealsRead + 1
      self.haiku = { lines = text.haiku[i], t = 0 }
      sfx.play("chime", 1, 0.8)
      return "seal"
    end
  end

  -- 4) people and frogs
  local f = w.fisherman
  if math.abs(s.x - f.x) < 140 then
    if s.carry.lantern then
      s.carry.lantern = false
      self.quest.returned = true
      s.carry.fish = s.carry.fish + 1
      self:say(text.fisherman.thanks, "Fisherman")
      self:toast("+1 fish", f.x, f.y - 90)
      sfx.play("chime", 1.25, 0.6)
    elseif self.quest.returned then
      self:say(text.fisherman.after, "Fisherman")
    elseif self.quest.asked then
      self:say(text.fisherman.waiting, "Fisherman")
    else
      self.quest.asked = true
      self:say(text.fisherman.ask, "Fisherman")
    end
    return "fisherman"
  end
  if math.abs(s.x - w.frog.x) < 110 then
    self.quest.frogLine = self.quest.frogLine % #text.frog + 1
    self:say({ text.frog[self.quest.frogLine] }, "Frog")
    return "frog"
  end
  if math.abs(s.x - w.villager.x) < 90 then
    self.quest.villagerLine = self.quest.villagerLine % #text.villager + 1
    self:say({ text.villager[self.quest.villagerLine] }, "Villager")
    return "villager"
  end
  return "peck"
end

function game:atNest()
  local s, n = self.stork, self.nest
  if self.ended then self:say(text.chick.full) return "nest" end
  local gave = false
  if s.carry.twigs > 0 then
    n.twigs = math.min(TWIGS_NEEDED, n.twigs + s.carry.twigs)
    s.carry.twigs = 0
    self:say(text.chick.twig)
    gave = true
  end
  if s.carry.fish > 0 then
    n.fed = math.min(FISH_NEEDED, n.fed + s.carry.fish)
    s.carry.fish = 0
    self:say(text.chick.fed)
    gave = true
  end
  if gave then
    sfx.note(7, 0.7)
    self:toast(("nest %d/%d  fed %d/%d"):format(n.twigs, TWIGS_NEEDED, n.fed, FISH_NEEDED), n.x, n.y - 50)
  else
    self:say(text.chick.hungry)
  end
  if n.twigs >= TWIGS_NEEDED and n.fed >= FISH_NEEDED and not self.ended then
    self.ended = true
    self:say(text.ending)
    sfx.play("chime", 0.75, 0.9)
  end
  return "nest"
end

function game:splash(x, y)
  for _ = 1, 8 do
    self.drops[#self.drops + 1] = { x = x, y = y, vx = love.math.random(-60, 60), vy = -love.math.random(80, 160), life = 0.6 }
  end
  self.ripples[#self.ripples + 1] = { x = x, y = y, r = 4, life = 1 }
end

-- Update ------------------------------------------------------------------------------
function game:keypressed(k)
  if k == "e" or k == "j" or k == "down" or k == "return" then
    self:interact()
  elseif (k == "space" or k == "w" or k == "up" or k == "k") then
    if #self.dialogue > 0 then self:advance() else self.input.flapPressed = true end
  end
end

function game:readInput()
  local kb = love.keyboard
  local talking = #self.dialogue > 0
  self.input.left = not talking and (kb.isDown("left") or kb.isDown("a"))
  self.input.right = not talking and (kb.isDown("right") or kb.isDown("d"))
  self.input.flapHeld = not talking and (kb.isDown("space") or kb.isDown("w") or kb.isDown("up") or kb.isDown("k"))
end

function game:update(dt, scripted)
  self.t = self.t + dt
  if not scripted then self:readInput() end
  self.stork:update(dt, self.input)
  self.input.flapPressed = false

  local line = self.dialogue[1]
  if line and self.typed < #line.text then
    local before = math.floor(self.typed)
    self.typed = math.min(#line.text, self.typed + dt * 45)
    if math.floor(self.typed) ~= before and math.floor(self.typed) % 6 == 0 then sfx.note(nil, 0.08) end
  end

  for i = 1, 3 do
    self.reveal[i] = self.reveal[i] + (self.revealTarget[i] - self.reveal[i]) * math.min(1, dt * 0.8)
  end
  if self.haiku then
    self.haiku.t = self.haiku.t + dt
    if self.haiku.t > 8 then self.haiku = nil end
  end

  local s = self.stork
  local target = s.x - 640 + s.dir * 140
  self.camX = self.camX + (target - self.camX) * math.min(1, dt * 2.5)
  self.camX = ink.clamp(self.camX, 0, world.W - 1280)

  local r = world.regionAt(s.x)
  if r ~= self.region then self.region, self.regionShow = r, 3.5 end
  self.regionShow = math.max(0, self.regionShow - dt)

  for _, f in ipairs(self.w.fish) do
    if f.caught then
      f.respawn = f.respawn - dt
      if f.respawn <= 0 then f.caught = false end
    else
      f.x = f.x + f.dir * f.speed * dt
      if f.x < f.water.x1 + 30 then f.dir = 1 elseif f.x > f.water.x2 - 30 then f.dir = -1 end
    end
  end
  -- ripples while wading
  self.rippleTimer = self.rippleTimer - dt
  if s:inWater() and math.abs(s.vx) > 20 and self.rippleTimer <= 0 then
    self.rippleTimer = 0.3
    self.ripples[#self.ripples + 1] = { x = s.x, y = world.water(s.x), r = 6, life = 1 }
  end
  for i = #self.ripples, 1, -1 do
    local p = self.ripples[i]
    p.r, p.life = p.r + 40 * dt, p.life - dt * 0.8
    if p.life <= 0 then table.remove(self.ripples, i) end
  end
  for i = #self.drops, 1, -1 do
    local d = self.drops[i]
    d.x, d.y, d.vy, d.life = d.x + d.vx * dt, d.y + d.vy * dt, d.vy + 400 * dt, d.life - dt
    if d.life <= 0 then table.remove(self.drops, i) end
  end
  for i = #self.toasts, 1, -1 do
    local tt = self.toasts[i]
    tt.life, tt.y = tt.life - dt, tt.y - 20 * dt
    if tt.life <= 0 then table.remove(self.toasts, i) end
  end
  for _, l in ipairs(self.leaves) do
    l.y = l.y + 22 * l.s * dt
    l.x = l.x + (math.sin(self.t * 0.8 + l.p) * 20 - 12) * dt
    if l.y > 730 then l.y, l.x = -10, love.math.random(0, 1400) end
  end
  if self.ended then
    self.dusk = math.min(1, self.dusk + dt * 0.15)
    if #self.lanterns < 40 and love.math.random() < dt * 3 then
      local hx = ({ 1850, 2060, 2280, self.w.fisherman.x + 62 })[love.math.random(1, 4)]
      self.lanterns[#self.lanterns + 1] = { x = hx + love.math.random(-30, 30), y = world.ground(hx) - 140, v = 14 + love.math.random() * 10, p = love.math.random() * 6 }
    end
  end
  for _, l in ipairs(self.lanterns) do
    l.y = l.y - l.v * dt
    l.x = l.x + math.sin(self.t * 0.5 + l.p) * 6 * dt
  end
end

-- Drawing ------------------------------------------------------------------------------
function game:hint()
  local s = self.stork
  if self.ended then return text.hints.done end
  for _, seal in ipairs(self.w.seals) do
    if not seal.read and math.abs(s.x - seal.x) < 120 then return text.hints.seal end
  end
  if s.carry.twigs > 0 or s.carry.fish > 0 then return text.hints.carry end
  return text.hints.start
end

function game:drawWorld()
  local a = function(x) return self:inkAt(x) end
  local t, w = self.t, self.w
  scenery.backdrop(self.camX, a, t)
  lg.push()
  lg.translate(-math.floor(self.camX), 0)
  scenery.terrain(self.camX, a)
  scenery.cliff(a, t, self.nest, self.ended or (self.nest.fed >= FISH_NEEDED))
  scenery.reedsDraw(self.camX, a, t)
  for _, h in ipairs(w.houses) do scenery.house(h, a, t, self.ended) end
  scenery.villager(w.villager, a, t)
  scenery.bambooDraw(self.camX, a, t)
  scenery.pond(a, t)
  scenery.frog(w.frog, a, t)
  for _, s in ipairs(w.seals) do scenery.sealStone(s, s.read, a, t) end
  for _, f in ipairs(w.fish) do scenery.fish(f, a, t) end
  for _, tw in ipairs(w.twigs) do scenery.twig(tw, t) end
  scenery.lantern(w.lantern, t)
  self.stork:draw(t)
  scenery.water(self.camX, a, t)
  scenery.boat(w.fisherman, a, t, self.quest.returned)
  for _, p in ipairs(self.ripples) do
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.35 * p.life)
    lg.setLineWidth(1.5)
    lg.ellipse("line", p.x, p.y, p.r, p.r * 0.22)
  end
  for _, d in ipairs(self.drops) do
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.6 * d.life)
    lg.circle("fill", d.x, d.y, 2)
  end
  for _, l in ipairs(self.lanterns) do
    lg.setBlendMode("add")
    lg.setColor(1, 0.55, 0.2, 0.35)
    lg.draw(scenery.blob, l.x, l.y, 0, 0.6, 0.6, 64, 64)
    lg.setBlendMode("alpha")
    lg.setColor(1, 0.75, 0.4)
    lg.rectangle("fill", l.x - 5, l.y - 7, 10, 14, 3)
  end
  for _, tt in ipairs(self.toasts) do
    lg.setFont(self.fonts.small)
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], math.min(1, tt.life))
    lg.printf(tt.msg, tt.x - 150, tt.y, 300, "center")
  end
  lg.pop()

  for _, l in ipairs(self.leaves) do
    local x, y = l.x, l.y
    ink.stroke({ x - 6 * l.s, y, x, y - 3 * l.s, x + 6 * l.s, y + 1 }, 4 * l.s, 0.5, 0.5, nil, false)
  end
end

function game:drawHUD()
  local f = self.fonts
  local s, n = self.stork, self.nest
  -- nest progress: twig and fish slots, painted
  lg.setFont(f.small)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.85)
  lg.print("nest", 24, 20)
  for i = 1, TWIGS_NEEDED do
    local x = 70 + (i - 1) * 30
    ink.stroke({ x, 34, x + 10, 30, x + 22, 32 }, 4, i <= n.twigs and 0.9 or 0.18, 0.5, nil, false)
  end
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.85) -- ink.stroke leaves the colour white
  lg.print("chick", 24, 46)
  for i = 1, FISH_NEEDED do
    local x = 80 + (i - 1) * 34
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], i <= n.fed and 0.85 or 0.18)
    lg.ellipse("fill", x, 56, 11, 4)
    lg.polygon("fill", x - 10, 56, x - 17, 51, x - 17, 61)
  end
  local carry = {}
  if s.carry.twigs > 0 then carry[#carry + 1] = s.carry.twigs .. (s.carry.twigs == 1 and " twig" or " twigs") end
  if s.carry.fish > 0 then carry[#carry + 1] = s.carry.fish .. " fish" end
  if s.carry.lantern then carry[#carry + 1] = "a lantern" end
  if #carry > 0 then
    lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.9)
    lg.print("carrying " .. table.concat(carry, ", "), 24, 72)
  end
  ink.seal(1240, 40, 34, 0.85)
  lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.6)
  lg.printf(("seals %d/3"):format(self.sealsRead), 1100, 66, 160, "right")

  if self.regionShow > 0 then
    lg.setFont(f.region)
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], math.min(1, self.regionShow) * 0.8)
    lg.printf(text.regions[self.region], 0, 34, 1280, "center")
  end

  if self.haiku then
    local h = self.haiku
    local alpha = math.min(1, h.t) * math.min(1, (8 - h.t))
    local hy = (#self.dialogue > 0) and 250 or 120 -- make room under the dialogue scroll
    lg.setFont(f.haiku)
    for i, ln in ipairs(h.lines) do
      lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], alpha * 0.9)
      lg.printf(ln, 0, hy + (i - 1) * 44, 1280, "center")
    end
    ink.seal(640, hy + 150, 26, alpha * 0.9)
  end

  if #self.dialogue == 0 then
    lg.setFont(f.small)
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.65)
    lg.print(self:hint(), 24, 690)
    if self.t < 25 then
      lg.printf("move: arrows / A D    fly: Space (hold to glide)    peck / talk: E", 0, 690, 1256, "right")
    end
  else
    local line = self.dialogue[1]
    local x, y, w, h = 190, 92, 900, 130 -- top of the screen, so the ground stays visible
    lg.setColor(ink.PAPER[1] * 0.98, ink.PAPER[2] * 0.97, ink.PAPER[3] * 0.95, 0.96)
    lg.rectangle("fill", x, y, w, h, 6)
    lg.setColor(0.25, 0.18, 0.12, 0.9)
    lg.rectangle("fill", x - 14, y - 6, 14, h + 12, 4)     -- scroll rollers
    lg.rectangle("fill", x + w, y - 6, 14, h + 12, 4)
    ink.stroke({ x + 20, y + h - 14, x + w / 2, y + h - 18, x + w - 20, y + h - 14 }, 3, 0.25, 0.5, nil, false)
    if line.speaker then
      lg.setFont(f.small)
      lg.setColor(ink.RED[1], ink.RED[2], ink.RED[3], 0.95)
      lg.print(line.speaker, x + 28, y + 14)
    end
    lg.setFont(f.body)
    lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.92)
    lg.printf(line.text:sub(1, math.floor(self.typed)), x + 28, y + 40, w - 56)
    if self.typed >= #line.text then
      lg.setFont(f.small)
      lg.setColor(ink.INK[1], ink.INK[2], ink.INK[3], 0.5 + 0.3 * math.sin(self.t * 5))
      lg.printf("E", x, y + h - 30, w - 24, "right")
    end
  end
end

function game:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.paper)
  self:drawWorld()
  if self.dusk > 0 then
    -- dusk: multiply the painting toward warm grey-violet, then add a little lantern light
    lg.setBlendMode("multiply", "premultiplied")
    local d = self.dusk
    lg.setColor(1 - 0.18 * d, 1 - 0.36 * d, 1 - 0.42 * d, 1)
    lg.rectangle("fill", 0, 0, 1280, 720)
    lg.setBlendMode("alpha")
  end
  self:drawHUD()
end

return game
