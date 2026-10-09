-- The shop: aliens queue at the serving window and describe a feeling. You pick ingredients from
-- the pantry, the Flavor Synthesizer combines their tags (with reactions), and the customer judges.
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
local Flavor = require("src.game.flavor")
local Orders = require("src.game.orders")
local ING = require("content.ingredients")
local SPECIES = require("content.species")
local lg = love.graphics

local Shop = {}

local WIN_Y0, WIN_Y1 = 56, 340
local SLOTS = { { x = 230, s = 1.0 }, { x = 110, s = 0.72 }, { x = 30, s = 0.58 } }
local SHELF = { x = 16, y = 372, w = 756, h = 242 }
local SYNTH = { x = 788, y = 372, w = 476, h = 340 }
local CARD_W, CARD_H, COLS, ROWS = 180, 98, 4, 2
local SHIFT_SIZE = 6
local RESULT_TIME = 2.8

function Shop:enter()
  local run = Run.current
  self.run, self.planet = run, run.planet
  self.quirk = self.planet.quirk
  self.t = 0
  self.queue, self.leaving = {}, {}
  self.spawned, self.spawnT = 0, 1.2
  self.pot = {}
  self.page = 1
  self.cooking, self.result = nil, nil
  self.soot = 0
  self.over = false
  self.horizon = Terrain.horizonProps(self.planet)
  self.shift = { served = 0, earned = 0, walkouts = 0, explosions = 0, transcendent = 0, stars = 0, count = 0 }
  self.btnServe = { x = 1018, y = 652, w = 234, h = 50, label = "SYNTHESIZE & SERVE", size = 17 }
  self.btnDump = { x = 800, y = 664, w = 190, h = 38, label = "Dump pot", size = 15, color = T.c.pink }
  self.btnPrev = { x = 668, y = 376, w = 40, h = 22, label = "<", size = 14, color = T.c.teal }
  self.btnNext = { x = 716, y = 376, w = 40, h = 22, label = ">", size = 14, color = T.c.teal }
  self.btnClose = { x = 540, y = 500, w = 200, h = 50, label = "Close up shop", size = 18 }
  fx.clear()
  Guide.sayKey("shop_open", { planet = self.planet.name })
end

-- Customers --------------------------------------------------------------------------------------
function Shop:patienceFor(sp)
  local p = 50 * sp.patience * (self.quirk.patience or 1)
  if Run.has(self.run, "dice") then p = p * 1.25 end
  return p
end

function Shop:spawn()
  local sp = SPECIES.byId[rng.pick(self.planet.residents)]
  local pat = self:patienceFor(sp)
  self.queue[#self.queue + 1] = { sp = sp, x = -90, state = "walk", mood = "neutral",
    patience = pat, max = pat, phase = rng.float(0, 6), y = WIN_Y1 - 8, vy = 0, rot = 0 }
  self.spawned = self.spawned + 1
end

function Shop:giveOrder(c)
  c.order = Orders.generate(self.run, c.sp, rng, self.quirk)
  if rng.chance(0.45) then
    local truthful = rng.chance(0.7)
    local id
    if truthful then
      id = rng.pick(c.order.solution)
    else
      id = rng.pick(Run.available(self.run))
    end
    if id then Guide.sayKey(truthful and "hint_true" or "hint_false", { name = ING.byId[id].name }) end
  end
end

function Shop:walkout(c, i)
  table.remove(self.queue, i)
  c.state, c.mood = "leave", "angry"
  self.leaving[#self.leaving + 1] = c
  self.shift.walkouts = self.shift.walkouts + 1
  self.run.stats.walkouts = self.run.stats.walkouts + 1
  self:rate(1)
  sfx.play("bad")
  Guide.sayKey("walkout")
end

function Shop:rate(stars)
  Run.addRating(self.run, stars)
  self.shift.stars = self.shift.stars + stars
  self.shift.count = self.shift.count + 1
end

-- Pot ---------------------------------------------------------------------------------------------
function Shop:addToPot(id)
  if self.cooking or self.over then return end
  if #self.pot >= Run.potSize(self.run) then
    fx.pop("Synthesizer full!", 1135, 400, T.c.bad, 16)
    return
  end
  if Run.take(self.run, id) then
    table.insert(self.pot, id)
    sfx.play("pick", 0.8 + #self.pot * 0.1)
  end
end

function Shop:removeFromPot(i)
  if self.cooking then return end
  local id = table.remove(self.pot, i)
  if id then Run.giveBack(self.run, id); sfx.play("click") end
end

function Shop:dump()
  for i = #self.pot, 1, -1 do self:removeFromPot(i) end
end

function Shop:canServe()
  local c = self.queue[1]
  return c and c.order and c.state == "wait" and #self.pot > 0 and not self.cooking and not self.result
end

function Shop:serve()
  if not self:canServe() then return end
  self.cooking = { t = 0, dur = 1.3, cust = self.queue[1], nextBubble = 0 }
  self.queue[1].state = "served"
end

function Shop:resolve()
  local c = self.cooking.cust
  self.cooking = nil
  local run = self.run
  local dish = Flavor.combine(self.pot)
  local res = Flavor.score(dish, c.order)
  local learned, seen = 0, {}
  for _, id in ipairs(self.pot) do
    if not seen[id] then
      seen[id] = true
      learned = learned + Run.learn(run, id)
    end
  end
  self.pot = {}

  run.flurbos = run.flurbos + res.pay
  run.stats.earned = run.stats.earned + res.pay
  run.stats.served = run.stats.served + 1
  self.shift.earned = self.shift.earned + res.pay
  self.shift.served = self.shift.served + 1
  self:rate(res.rating.stars)

  local good = res.score >= 0.7 and not res.hated
  c.comment = rng.pick(good and c.sp.good or c.sp.bad)
  self.result = { t = 0, dish = dish, res = res, cust = c, learned = learned }

  if res.catastrophe then
    c.mood = "angry"
    self.shift.explosions = self.shift.explosions + 1
    run.stats.explosions = run.stats.explosions + 1
    fx.burst(895, 500, 60, { 1, 0.55, 0.15 }, 520, { life = 1.0, size = 9, grav = 200 })
    fx.burst(895, 500, 40, { 0.3, 0.3, 0.3 }, 300, { life = 1.4, size = 12, grav = -40 })
    fx.shake(16, 0.6)
    self.soot = 1
    sfx.play("boom")
    Guide.sayKey("explosion")
    c.state, c.vy = "blast", -900
    table.remove(self.queue, 1)
    self.leaving[#self.leaving + 1] = c
  else
    local mood = "happy"
    if res.hated or res.rating.id == "complaint" then mood = "angry"
    elseif res.rating.id == "bemused" then mood = "confused" end
    c.mood = mood
    if res.rating.id == "transcendent" then
      self.shift.transcendent = self.shift.transcendent + 1
      run.stats.transcendent = run.stats.transcendent + 1
      fx.burst(SLOTS[1].x, 200, 30, T.c.gold, 320, { up = 200, life = 1.2 })
      sfx.play("coin")
      local rumor = Run.nextRumor(run)
      if rumor then Guide.say("RUMOUR! " .. rumor) else Guide.sayKey("serve_great") end
    elseif res.hated then
      sfx.play("bad")
      Guide.sayKey("serve_hated")
    elseif mood == "happy" then
      sfx.play("coin")
      Guide.sayKey("serve_ok")
    else
      sfx.play("bad")
      Guide.sayKey("serve_bad")
    end
    if learned > 0 then fx.pop("New tags learned!", 895, 420, T.c.teal, 18) end
  end
  if res.pay > 0 then fx.pop("+" .. res.pay .. " Flurbos", SLOTS[1].x, 120, T.c.gold, 24) end
end

-- Update ------------------------------------------------------------------------------------------
function Shop:update(dt)
  self.t = self.t + dt
  self.soot = math.max(0, self.soot - dt * 0.25)
  if self.over then return end

  -- arrivals
  self.spawnT = self.spawnT - dt
  if self.spawned < SHIFT_SIZE and #self.queue < 3 and self.spawnT <= 0 then
    self:spawn()
    self.spawnT = rng.float(4, 8)
  end

  -- queue movement and patience
  for i = #self.queue, 1, -1 do
    local c = self.queue[i]
    local slot = SLOTS[math.min(i, #SLOTS)]
    if c.x < slot.x then
      c.x = math.min(slot.x, c.x + 170 * dt)
      if c.state ~= "served" then c.state = "walk" end
    elseif c.state == "walk" then
      c.state = "wait"
    end
    c.s = c.s and (c.s + (slot.s - c.s) * math.min(1, dt * 4)) or slot.s
    if i == 1 and c.state == "wait" and not c.order then self:giveOrder(c) end
    if c.state == "wait" then
      c.patience = c.patience - dt * (i == 1 and 1 or 0.4)
      if c.patience <= 0 then self:walkout(c, i) end
    end
  end

  for i = #self.leaving, 1, -1 do
    local c = self.leaving[i]
    if c.state == "blast" then
      c.vy = c.vy + 600 * dt
      c.y = c.y + c.vy * dt
      c.x = c.x + 120 * dt
      c.rot = c.rot + dt * 8
      if c.y < -300 or c.y > 900 then table.remove(self.leaving, i) end
    else
      c.x = c.x + 220 * dt
      if c.x > 1400 then table.remove(self.leaving, i) end
    end
  end

  -- cooking
  if self.cooking then
    local ck = self.cooking
    ck.t = ck.t + dt
    ck.nextBubble = ck.nextBubble - dt
    if ck.nextBubble <= 0 then
      sfx.play("bubble", 0.8 + love.math.random() * 0.6)
      ck.nextBubble = 0.18
    end
    if ck.t >= ck.dur then self:resolve() end
  end

  -- result display, then the customer leaves
  if self.result then
    local r = self.result
    r.t = r.t + dt
    if r.t >= RESULT_TIME then
      local c = r.cust
      if c.state ~= "blast" then
        for i, q in ipairs(self.queue) do
          if q == c then table.remove(self.queue, i) break end
        end
        c.state = "leave"
        self.leaving[#self.leaving + 1] = c
      end
      self.result = nil
    end
  end

  if self.spawned >= SHIFT_SIZE and #self.queue == 0 and not self.cooking and not self.result then
    self.over = true
    self.run.lastShift = self.shift
    Guide.sayKey("shift_over")
  end
end

-- Drawing -----------------------------------------------------------------------------------------
function Shop:liquidColor()
  if #self.pot == 0 then return { 0.35, 0.8, 0.75 } end
  local r, g, b = 0, 0, 0
  for _, id in ipairs(self.pot) do
    local c = ING.byId[id].color
    r, g, b = r + c[1], g + c[2], b + c[3]
  end
  local n = #self.pot
  return { r / n, g / n, b / n }
end

function Shop:drawWindow()
  local t = self.t
  Terrain.drawHorizon(self.planet, self.horizon, WIN_Y0, WIN_Y1, t)

  local function drawCust(c)
    lg.push()
    if c.state == "blast" then
      lg.translate(c.x, c.y - 80)
      lg.rotate(c.rot)
      lg.translate(-c.x, -(c.y - 80))
    end
    A.alien(c.x, c.y, c.s or 1, c.sp.look, c.mood, t, c.phase)
    lg.pop()
  end
  for i = #self.queue, 1, -1 do drawCust(self.queue[i]) end
  for _, c in ipairs(self.leaving) do drawCust(c) end

  -- queue patience pips for people waiting behind
  for i = 2, #self.queue do
    local c = self.queue[i]
    local k = c.patience / c.max
    lg.setColor(0, 0, 0, 0.5)
    D.rrect("fill", c.x - 26, WIN_Y1 - 26, 52, 8, 4)
    D.color(k > 0.35 and T.c.good or T.c.bad)
    D.rrect("fill", c.x - 26, WIN_Y1 - 26, 52 * k, 8, 4)
  end

  if self.soot > 0 then
    lg.setColor(0.1, 0.08, 0.08, 0.55 * self.soot)
    for i = 0, 11 do
      lg.circle("fill", 100 + (i * 197) % 1100, WIN_Y0 + 40 + (i * 89) % 220, 40 + (i * 37) % 50)
    end
  end

  -- window frame + awning
  D.color(T.c.cream)
  lg.rectangle("fill", -200, WIN_Y1, 1680, 22)
  lg.setColor(0.75, 0.62, 0.45)
  lg.rectangle("fill", -200, WIN_Y1 + 18, 1680, 6)
  for i = 0, 22 do
    D.color(i % 2 == 0 and { 0.95, 0.3, 0.32 } or { 0.98, 0.95, 0.9 })
    local ax = -20 + i * 60
    lg.rectangle("fill", ax, WIN_Y0, 60, 10)
    lg.arc("fill", ax + 30, WIN_Y0 + 10, 30, 0, math.pi)
  end
end

function Shop:drawBubble()
  local c = self.queue[1]
  local r = self.result
  if r then c = r.cust end
  if not c or (not c.order and not r) or c.x < SLOTS[1].x - 5 then return end
  local x, y, w, h = 400, 84, 860, 200
  D.color(T.c.cream)
  D.rrect("fill", x, y, w, h, 18)
  lg.polygon("fill", x + 2, y + 110, x - 70, y + 150, x + 2, y + 140)
  D.text(c.sp.name, x + 18, y + 10, 13, { 0.45, 0.38, 0.5 })

  if r then
    local res = r.res
    D.text("\"" .. c.comment .. "\"", x + 18, y + 34, 20, T.c.dark, "left", w - 36)
    local rc = (res.rating.stars >= 4) and { 0.2, 0.6, 0.25 } or (res.rating.stars >= 3 and { 0.75, 0.55, 0.1 } or { 0.8, 0.2, 0.15 })
    D.text(res.rating.label, x + 18, y + 120, 32, rc)
    D.stars(x + 380, y + 140, res.rating.stars, 13)
    D.text("+" .. res.pay .. " Flurbos", x + 560, y + 126, 22, { 0.6, 0.45, 0.05 })
    if res.catastrophe then
      D.text("(it exploded: Volatile + Hot, or two Volatiles, make Explosive)", x + 18, y + 162, 14, { 0.8, 0.2, 0.15 })
    elseif res.hated then
      D.text("(contained something they HATE)", x + 18, y + 162, 14, { 0.8, 0.2, 0.15 })
    elseif #res.missing > 0 then
      D.text("Missing: " .. table.concat(res.missing, ", "), x + 18, y + 162, 14, { 0.5, 0.4, 0.5 })
    elseif res.extras > 0 then
      D.text("Correct, but " .. res.extras .. " unwanted tag(s) muddied it.", x + 18, y + 162, 14, { 0.5, 0.4, 0.5 })
    end
    return
  end

  local o = c.order
  lg.setFont(T.font(20))
  D.rich(o.text, x + 18, y + 32, w - 36, 20, T.c.dark)
  D.text("Pays about " .. o.price .. " Flurbos", x + 18, y + h - 30, 13, { 0.45, 0.38, 0.5 })
  -- patience
  local k = c.patience / c.max
  D.text("Patience", x + w - 330, y + h - 30, 13, { 0.45, 0.38, 0.5 })
  lg.setColor(0.85, 0.8, 0.7)
  D.rrect("fill", x + w - 260, y + h - 27, 240, 12, 6)
  D.color(k > 0.35 and { 0.3, 0.75, 0.35 } or { 0.9, 0.3, 0.25 })
  D.rrect("fill", x + w - 260, y + h - 27, 240 * k, 12, 6)
end

function Shop:pantry()
  return Run.pantry(self.run)
end

function Shop:cardRect(slot)
  local col = (slot - 1) % COLS
  local row = math.floor((slot - 1) / COLS)
  return SHELF.x + 10 + col * (CARD_W + 6), SHELF.y + 30 + row * (CARD_H + 6)
end

function Shop:pageItems()
  local all = self:pantry()
  local per = COLS * ROWS
  local pages = math.max(1, math.ceil(#all / per))
  self.page = math.max(1, math.min(self.page, pages))
  local out = {}
  for i = (self.page - 1) * per + 1, math.min(#all, self.page * per) do out[#out + 1] = all[i] end
  return out, pages
end

function Shop:drawShelf(mx, my)
  D.panel(SHELF.x, SHELF.y, SHELF.w, SHELF.h)
  D.text("PANTRY  (click to add to the Synthesizer)", SHELF.x + 12, SHELF.y + 6, 14, T.c.dim)
  local items, pages = self:pageItems()
  if pages > 1 then
    D.text(self.page .. "/" .. pages, 610, 378, 14, T.c.dim)
    D.button(self.btnPrev, mx, my)
    D.button(self.btnNext, mx, my)
  end
  local hover
  for i, id in ipairs(items) do
    local def = ING.byId[id]
    local x, y = self:cardRect(i)
    local n = Run.count(self.run, id)
    local hot = mx >= x and mx <= x + CARD_W and my >= y and my <= y + CARD_H
    if hot then hover = { id = id, x = x, y = y } end
    D.color(hot and T.c.edge or T.c.panel2, n > 0 and 1 or 0.5)
    D.rrect("fill", x, y, CARD_W, CARD_H, 10)
    A.ingredient(x + 32, y + 36, 22, def, self.t)
    D.text(def.name, x + 62, y + 8, 13, n > 0 and T.c.ink or T.c.faint, "left", CARD_W - 68)
    D.text(def.staple and "inf" or ("x" .. n), x + 8, y + 4, 12, def.staple and T.c.teal or T.c.gold)
    local chips = {}
    for _, tag in ipairs(def.tags) do
      if Run.isKnown(self.run, id, tag) then chips[#chips + 1] = { tag = tag, dim = n == 0 }
      else chips[#chips + 1] = { tag = "?", dim = n == 0 } end
    end
    D.chipRow(chips, x + 8, y + 62, CARD_W - 12, 11)
    if i <= 9 then D.text(tostring(i), x + CARD_W - 16, y + CARD_H - 18, 11, T.c.faint) end
  end
  return hover
end

function Shop:drawSynth(mx, my)
  D.panel(SYNTH.x, SYNTH.y, SYNTH.w, SYNTH.h)
  D.text("FLAVOR SYNTHESIZER  Mk. II (ish)", SYNTH.x + 12, SYNTH.y + 6, 14, T.c.dim)
  local heat = self.cooking and math.min(1, self.cooking.t / self.cooking.dur + 0.3) or (#self.pot > 0 and 0.15 or 0)
  A.synth(895, 645, self.t, self:liquidColor(), heat)

  local size = Run.potSize(self.run)
  for i = 1, size do
    local x, y = 1018, 400 + (i - 1) * 42
    local id = self.pot[i]
    local hot = id and mx >= x and mx <= x + 234 and my >= y and my <= y + 36
    D.color(hot and T.c.edge or T.c.panel2)
    D.rrect("fill", x, y, 234, 36, 8)
    if id then
      local def = ING.byId[id]
      A.ingredient(x + 20, y + 18, 13, def, self.t)
      D.text(def.name, x + 40, y + 9, 13, T.c.ink, "left", 170)
      if hot then D.text("x", x + 216, y + 8, 15, T.c.bad) end
    else
      D.text("empty slot", x + 40, y + 9, 13, T.c.faint)
    end
  end

  local y0 = 400 + size * 42 + 4
  if self.result then
    D.text("Result:", 1018, y0, 13, T.c.dim)
    local items = {}
    local res = self.result.res
    for _, e in ipairs(Flavor.list(self.result.dish.counts)) do
      local outline = res.matched[e.tag] and T.c.good or nil
      if e.tag == self.result.cust.order.hate or e.tag == "Explosive" then outline = T.c.bad end
      items[#items + 1] = { tag = e.tag, n = e.n, outline = outline }
    end
    D.chipRow(items, 1018, y0 + 20, 234, 12)
  elseif #self.pot > 0 then
    local pred = Flavor.predict(self.pot, function(id, tag) return Run.isKnown(self.run, id, tag) end)
    D.text("Predicted:", 1018, y0, 13, T.c.dim)
    local items = {}
    for _, e in ipairs(Flavor.list(pred.counts)) do items[#items + 1] = { tag = e.tag, n = e.n } end
    if pred.unknown > 0 then items[#items + 1] = { tag = "?", label = pred.unknown .. " unknown" } end
    local h = D.chipRow(items, 1018, y0 + 20, 234, 12)
    if pred.counts.Explosive then D.text("WARNING: likely to explode", 1018, y0 + 26 + h, 12, T.c.bad) end
  end

  self.btnServe.enabled = self:canServe() and true or false
  D.button(self.btnServe, mx, my)
  self.btnDump.enabled = #self.pot > 0 and not self.cooking
  D.button(self.btnDump, mx, my)
end

function Shop:drawHud()
  D.panel(-10, -10, 1300, 66, T.c.panel, T.c.edge, 0)
  D.text("DAY " .. self.run.day .. "  -  " .. self.planet.name, 16, 6, 18, T.c.ink)
  D.text(self.quirk.text, 16, 30, 12, T.c.teal, "left", 520)
  local done = self.shift.count
  D.text("Customers " .. done .. "/" .. SHIFT_SIZE, 560, 16, 18, T.c.ink)
  D.coin(770, 27, 12)
  D.text(tostring(self.run.flurbos), 790, 16, 20, T.c.gold)
  D.text("Debt " .. self.run.debt, 880, 16, 18, T.c.bad)
  D.stars(1090, 27, Run.rating(self.run), 10)
end

function Shop:draw()
  local mx, my = vp.mouse()
  D.fill(T.c.bg)
  self:drawWindow()
  self:drawBubble()
  local hover = self:drawShelf(mx, my)
  self:drawSynth(mx, my)
  Guide.draw(16, 622, 756, 90)
  self:drawHud()

  if hover then
    local def = ING.byId[hover.id]
    local tx = math.min(hover.x, 772 - 300)
    local ty = hover.y - 52
    D.panel(tx, ty, 300, 46, T.c.dark, T.c.edge, 8)
    D.text(def.blurb, tx + 10, ty + 6, 13, T.c.ink, "left", 280)
  end

  if self.over then
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 0, 0, 1280, 720)
    local s = self.shift
    D.panel(390, 170, 500, 400)
    D.shadowText("SHIFT OVER", 390, 190, 40, T.c.gold, "center", 500)
    local lines = {
      "Dishes served: " .. s.served,
      "Transcendent dishes: " .. s.transcendent,
      "Walk-outs: " .. s.walkouts,
      "Explosions: " .. s.explosions,
      "Flurbos earned: " .. s.earned,
    }
    for i, l in ipairs(lines) do D.text(l, 430, 250 + (i - 1) * 30, 20, T.c.ink) end
    D.text("Shift rating:", 430, 410, 20, T.c.ink)
    D.stars(590, 422, s.count > 0 and s.stars / s.count or 0, 12)
    self.btnClose.y = 490
    D.button(self.btnClose, mx, my)
  end
end

-- Input -------------------------------------------------------------------------------------------
function Shop:mousepressed(x, y, b)
  if self.over then
    if D.inside(self.btnClose, x, y) then scenes.switch(require("src.scenes.outfitter")) end
    return
  end
  if D.inside(self.btnServe, x, y) then self:serve() return end
  if D.inside(self.btnDump, x, y) then self:dump() return end
  local _, pages = self:pageItems()
  if pages > 1 then
    if D.inside(self.btnPrev, x, y) then self.page = self.page - 1 return end
    if D.inside(self.btnNext, x, y) then self.page = self.page + 1 return end
  end
  -- pot slots
  for i = 1, Run.potSize(self.run) do
    local sx, sy = 1018, 400 + (i - 1) * 42
    if x >= sx and x <= sx + 234 and y >= sy and y <= sy + 36 then self:removeFromPot(i) return end
  end
  -- pantry cards
  local items = self:pageItems()
  for i, id in ipairs(items) do
    local cx, cy = self:cardRect(i)
    if x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
      if b == 2 then
        for j = #self.pot, 1, -1 do
          if self.pot[j] == id then self:removeFromPot(j) break end
        end
      else
        self:addToPot(id)
      end
      return
    end
  end
end

function Shop:wheelmoved(_, dy)
  self.page = self.page + (dy < 0 and 1 or -1)
end

function Shop:keypressed(k)
  if self.over then
    if k == "return" or k == "space" then scenes.switch(require("src.scenes.outfitter")) end
    return
  end
  local n = tonumber(k)
  if n and n >= 1 then
    local items = self:pageItems()
    if items[n] then self:addToPot(items[n]) end
  elseif k == "backspace" then
    self:removeFromPot(#self.pot)
  elseif k == "return" or k == "space" then
    self:serve()
  end
end

return Shop
