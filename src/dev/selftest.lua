-- Headless tests: `love . --selftest` (exit code 0 = pass). No window, no audio.
local TAGS = require("content.tags")
local REACTIONS = require("content.reactions")
local ING = require("content.ingredients")
local SPECIES = require("content.species")
local UP = require("content.upgrades")
local rngLib = require("src.core.rng")
local Flavor = require("src.game.flavor")
local Run = require("src.game.run")
local Orders = require("src.game.orders")
local Galaxy = require("src.game.galaxy")

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function check(cond, msg) if not cond then error(msg or "check failed", 2) end end

test("content: every tag used is defined", function()
  for _, ing in ipairs(ING.list) do
    for _, t in ipairs(ing.tags) do check(TAGS.defs[t], ing.id .. " uses unknown tag " .. t) end
  end
  for _, sp in ipairs(SPECIES.list) do
    for _, t in ipairs(sp.likes) do check(TAGS.defs[t], sp.id .. " likes unknown tag " .. t) end
    for _, t in ipairs(sp.hates) do check(TAGS.defs[t], sp.id .. " hates unknown tag " .. t) end
  end
  for _, r in ipairs(REACTIONS) do
    check(TAGS.defs[r.a] and TAGS.defs[r.b] and TAGS.defs[r.result], "bad reaction")
  end
  for name, def in pairs(TAGS.defs) do
    check(#def.phrases > 0, name .. " has no phrases")
    for _, p in ipairs(def.phrases) do check(p:find("{"), name .. " phrase without {highlight}: " .. p) end
  end
  for _, t in ipairs(TAGS.order) do check(TAGS.defs[t], "order lists unknown tag " .. t) end
end)

test("content: no ingredient reacts with itself", function()
  for _, ing in ipairs(ING.list) do
    local dish = Flavor.combine({ ing.id })
    check(#dish.fired == 0, ing.id .. " reacts on its own")
  end
end)

test("content: ingredients have ASCII blurbs", function()
  for _, ing in ipairs(ING.list) do
    check(ing.blurb and #ing.blurb > 0, ing.id .. " needs a blurb")
    check(not ing.blurb:find("[\128-\255]"), ing.id .. " blurb must be ASCII")
  end
end)

test("flavor: reactions fire", function()
  local d = Flavor.combine({ "joyberry", "doomtruffle" })
  check(d.counts.Irony == 1 and d.counts.Joy == nil and d.counts.Doom == nil, "Joy + Doom should make Irony")
  d = Flavor.combine({ "joyberry", "panicpepper" })
  check(d.counts.Explosive == 1, "Volatile + Hot should explode")
  d = Flavor.combine({ "joyberry", "voltcorn" })
  check(d.counts.Explosive == 1, "two Volatiles should explode")
  d = Flavor.combine({ "smugberry", "weepkelp" })
  check(d.counts.Purple == 1 and d.counts.Bureaucratic == 1, "Red+Blue=Purple, Smug+Slimy=Bureaucratic")
  d = Flavor.combine({ "tea", "ennui" })
  check(d.counts.Wistful == 1 and d.counts.Crunchy == 1, "Melancholy + Nostalgia = Wistful")
end)

test("flavor: scoring", function()
  local order = { wants = { { tag = "Irony", n = 1 }, { tag = "Crunchy", n = 1 } }, price = 30 }
  local r = Flavor.score(Flavor.combine({ "fizzwort", "doomtruffle" }), order)
  -- fizzwort+doomtruffle = Fizzy, Irony, Crunchy: correct but one extra
  check(r.rating.id == "delighted", "one extra tag should be delighted, got " .. r.rating.id)
  local perfect = { wants = { { tag = "Doom", n = 1 }, { tag = "Crunchy", n = 1 } }, price = 30 }
  r = Flavor.score(Flavor.combine({ "doomtruffle" }), perfect)
  check(r.rating.id == "transcendent" and r.pay == 45, "exact match is transcendent with tip")
  local hate = { wants = { { tag = "Doom", n = 1 } }, hate = "Crunchy", price = 30 }
  r = Flavor.score(Flavor.combine({ "doomtruffle" }), hate)
  check(r.hated and r.rating.id == "complaint", "hated tag means complaint")
  r = Flavor.score(Flavor.combine({ "joyberry", "panicpepper" }), perfect)
  check(r.catastrophe and r.pay == 0, "unwanted explosion is a catastrophe")
  local double = { wants = { { tag = "Crunchy", n = 2 } }, price = 30 }
  r = Flavor.score(Flavor.combine({ "doomtruffle" }), double)
  check(#r.missing == 1, "double helping needs two")
end)

test("orders: always solvable with a perfect dish", function()
  local rng = rngLib.new(1234)
  for trial = 1, 400 do
    local run = Run.new()
    if trial % 2 == 0 then run.upgrades.pot4 = true end
    for _ = 1, rng.random(0, 10) do
      local ing = rng.pick(ING.list)
      if not ing.staple then Run.add(run, ing.id) end
    end
    local sp = rng.pick(SPECIES.list)
    local o = Orders.generate(run, sp, rng, {})
    check(#o.wants >= 1 and #o.wants <= 3, "1-3 wants")
    check(o.price > 0, "price")
    check(#o.solution <= Run.potSize(run), "solution fits the pot")
    local counts = {}
    for _, id in ipairs(o.solution) do counts[id] = (counts[id] or 0) + 1 end
    for id, n in pairs(counts) do check(Run.count(run, id) >= n, "solution uses ingredients you have") end
    local res = Flavor.score(Flavor.combine(o.solution), o)
    check(res.rating.id == "transcendent", "solution should be perfect, got " .. res.rating.id .. " for " .. o.text)
    check(o.text:find("{"), "order text highlights tags")
  end
end)

test("run: pantry, learning, upgrades, debt", function()
  local run = Run.new()
  check(Run.count(run, "salt") == math.huge, "staples are infinite")
  local first = Run.add(run, "weepkelp")
  check(first == "Melancholy", "first find reveals first tag")
  check(Run.isKnown(run, "weepkelp", "Melancholy") and not Run.isKnown(run, "weepkelp", "Blue"), "others hidden")
  check(Run.take(run, "weepkelp") and not Run.take(run, "weepkelp"), "take consumes")
  check(Run.learn(run, "weepkelp") == 2, "cooking teaches the rest")
  run.flurbos = 100
  check(Run.buy(run, "pot4") and Run.potSize(run) == 4, "buy pot4")
  check(not Run.buy(run, "pot4"), "can't buy twice")
  check(Run.payDebt(run, 1000) == 100 - UP.byId.pot4.price, "pay what you have")
  run.upgrades.tasteotron = true
  check(Run.isKnown(run, "egg", "Doom"), "taste-o-tron reveals everything")
end)

test("galaxy: planets and rides", function()
  local rng = rngLib.new(99)
  local run = Run.new()
  local rides = Galaxy.rides(run, rng)
  check(#rides == 3, "three rides")
  for _, r in ipairs(rides) do
    check(#r.planet.pool == 6 and #r.planet.residents >= 2, "planet has a pool and residents")
    check(r.planet.name and #r.planet.name > 0, "planet named")
  end
  run.upgrades.navcom = true
  rides = Galaxy.rides(run, rng)
  check(#rides == 4, "nav-com adds a ride")
  for _, r in ipairs(rides) do check(r.revealed, "nav-com reveals all") end
end)

test("sim: a lazy bot that cooks each order's solution earns money", function()
  local rng = rngLib.new(7)
  local run = Run.new()
  local earned = 0
  for _ = 1, 3 do
    local p = Galaxy.planet(rng)
    for _ = 1, 6 do Run.add(run, rng.pick(p.pool)) end
    for _ = 1, 6 do
      local o = Orders.generate(run, SPECIES.byId[rng.pick(p.residents)], rng, p.quirk)
      for _, id in ipairs(o.solution) do Run.take(run, id) end
      earned = earned + Flavor.score(Flavor.combine(o.solution), o).pay
    end
  end
  check(earned > 300, "perfect play should earn > 300 over 3 shifts, got " .. earned)
  print(string.format("  (perfect play earns %d Flurbos over 3 shifts)", earned))
end)

test("scenes: a bot plays three full days (hitchhike, forage, shop, outfitter)", function()
  local scenes = require("src.core.scenes")
  local H = require("src.scenes.hitchhike")
  local Fo = require("src.scenes.forage")
  local S = require("src.scenes.shop")
  local O = require("src.scenes.outfitter")
  local function step(n, until_)
    for _ = 1, n do
      scenes.update(1 / 30)
      if until_ and until_() then return true end
    end
    return false
  end
  Run.new()
  scenes.instant(H)
  for day = 1, 3 do
    check(scenes.current == H, "day " .. day .. ": should be hitchhiking")
    H:choose(H.rides[2]) -- the free wormhole
    check(step(600, function() return scenes.current == Fo end), "warp should land on a planet")
    -- grab the nearest ingredients by teleporting the chef onto them
    step(30)
    for _ = 1, 5 do
      local it = Fo.items[1]
      if it then Fo.chef.x, Fo.chef.y = it.x, it.y; step(2) end
    end
    check(#Fo.basket > 0, "picked something up")
    Fo:finish()
    check(step(120, function() return scenes.current == S end), "forage leads to the shop")
    -- serve every customer their order's solution (when still affordable)
    check(step(30 * 300, function()
      local c = S.queue[1]
      if not S.cooking and not S.result and c and c.order and c.state == "wait" and #S.pot == 0 then
        for _, id in ipairs(c.order.solution) do S:addToPot(id) end
        if #S.pot == 0 then S:addToPot("salt") end
        S:serve()
      end
      return S.over
    end), "shift should end")
    check(S.shift.count == 6, "six customers handled, got " .. S.shift.count)
    check(S.shift.served >= 4, "bot should serve most customers, served " .. S.shift.served)
    S:mousepressed(S.btnClose.x + 5, S.btnClose.y + 5, 1)
    check(step(120, function() return scenes.current == O end), "shop leads to the outfitter")
    O:pay(50)
    O:mousepressed(O.btnGo.x + 5, O.btnGo.y + 5, 1)
    check(step(120, function() return scenes.current == H end), "outfitter leads to hitchhiking")
  end
  local run = Run.current
  check(run.day == 3 and run.stats.served >= 12, "three days played")
  print(string.format("  (bot after 3 days: %d Flurbos, debt %d, %d served, %d transcendent)",
    run.flurbos, run.debt, run.stats.served, run.stats.transcendent))
end)

local M = {}
function M.run()
  local pass, fail = 0, 0
  for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
      pass = pass + 1
      print("PASS  " .. t.name)
    else
      fail = fail + 1
      print("FAIL  " .. t.name .. "\n      " .. tostring(err))
    end
  end
  print(string.format("%d passed, %d failed", pass, fail))
  return fail == 0
end
return M
