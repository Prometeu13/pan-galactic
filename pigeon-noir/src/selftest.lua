-- `love pigeon-noir --selftest`: a bot checks every rule by staging situations and
-- stepping the game. Prints one line per check; exits with code 1 on the first failure.

local city = require("src.city")

local T = {}
local passed = 0

local function check(cond, msg)
  if not cond then
    print("FAIL  " .. msg)
    os.exit(1)
  end
  passed = passed + 1
  print("ok    " .. msg)
end

local function run(g, seconds, input)
  for _ = 1, math.floor(seconds * 60) do
    g.input = {}
    for k, v in pairs(input or {}) do g.input[k] = v end
    g:update(1 / 60, true)
  end
end

local function place(g, x, y, dir)
  local p = g.pigeon
  p.x, p.y, p.vx, p.vy, p.dir, p.hurt = x, y, 0, 0, dir or 1, 0
  p.on = nil
  for _ = 1, 120 do     -- let him land on whatever is below (up to 2 s)
    if p.on then break end
    run(g, 1 / 60)
  end
end

local function calm(g)
  g.cars = {}
  g.carTimer = 999
  for _, cat in ipairs(g.c.cats) do cat.state, cat.x, cat.y = "idle", cat.home, city.SIDEWALK end
end

function T.run(game)
  local g = game.new()
  calm(g)
  check(#g.captions == 4, "intro narration queued")

  -- movement
  place(g, 200, 590)
  check(g.pigeon.on and g.pigeon.on.kind == "sidewalk", "lands on the sidewalk")
  local x0 = g.pigeon.x
  run(g, 1, { right = true })
  check(g.pigeon.x > x0 + 100, "walks right")
  run(g, 0.05, { flapPressed = true })
  check(not g.pigeon.on and g.pigeon.vy < 0, "flaps into the air")
  local st = g.pigeon.stamina
  check(st < 100, "flapping costs wing stamina")
  run(g, 3)
  check(g.pigeon.on ~= nil, "comes back down and perches")

  -- perching on a fire escape landing from above
  place(g, 820, 470)
  check(g.pigeon.on and g.pigeon.on.kind == "escape", "lands on a fire escape")
  run(g, 0.05, { dropPressed = true })
  run(g, 1.5)
  check(g.pigeon.on and g.pigeon.on.y > 500, "Down drops through the landing")

  -- off the curb into the road
  place(g, 300, 590)
  run(g, 0.05, { dropPressed = true })
  run(g, 1)
  check(g.pigeon.on and g.pigeon.on.kind == "road", "Down hops off the curb into the road")

  -- eating
  g.hunger = 40
  local crumb
  for _, cr in ipairs(g.c.crumbs) do if cr.road and cr.alive then crumb = cr break end end
  place(g, crumb.x - 24, city.ROAD - 10, 1)
  check(g:peck() == "eat" and g.hunger > 55, "pecking a road crumb fills the belly")
  check(not crumb.alive, "the crumb is gone")
  run(g, 26)
  calm(g)
  check(crumb.alive, "crumbs come back after a while")

  -- trash can
  local tr = g.c.trash[2]
  place(g, tr.x - 30, 590, 1)
  local before = #g.c.crumbs
  check(g:peck() == "trash" and tr.knocked and #g.c.crumbs == before + 3, "knocking over a trash can spills crumbs")

  -- the diner throws out fries when you're nearby
  place(g, 300, 590)
  g.c.diner.nextThrow = 0.01
  local n = #g.c.crumbs
  run(g, 0.1)
  check(#g.c.crumbs == n + 4, "the cook throws out fries")

  -- warmth
  calm(g)
  g.warmth = 50
  place(g, 3400, 590)      -- the steam vent by the bar
  run(g, 1)
  check(g.warmth > 55, "steam vents warm you up")
  g.warmth = 50
  place(g, 2400, 590)      -- under the hotel awning
  run(g, 1)
  check(g.warmth > 55, "awnings keep the rain off")
  g.warmth = 50
  place(g, 2700, 140)      -- on the hotel roof, in the rain
  run(g, 2)
  check(g.warmth < 50, "the rain chills you in the open")

  -- cats
  calm(g)
  g.feathers = 3
  local cat = g.c.cats[1]
  place(g, cat.x + 120, 590, -1)
  run(g, 0.1)
  check(cat.state == "stalk", "a cat starts stalking when you're on the ground nearby")
  run(g, 1.6)
  check(g.feathers == 2, "the pounce costs a feather")
  calm(g)
  place(g, cat.x + 60, 360, -1)   -- on the wire above the alley
  run(g, 2)
  check(cat.state == "idle" and g.feathers == 2, "cats can't reach you up on the wire")

  -- cars
  calm(g)
  place(g, 1500, 660, 1)
  g.cars = { { x = 1500 - 300, dir = 1, speed = 600, honked = false } }
  run(g, 0.7)
  check(g.feathers == 1, "a taxi on the road costs a feather")
  calm(g)
  place(g, 1700, 590, 1)
  g.pigeon.hurt = 0
  g.cars = { { x = 1700 - 300, dir = 1, speed = 600, honked = false } }
  run(g, 0.8)
  check(g.feathers == 1, "on the sidewalk, taxis pass you by")

  -- checkpoint, death, respawn
  local lamp = g.c.lamps[2]
  place(g, lamp.x, lamp.y - 20)
  check(g.checkpoint.lamp == lamp, "perching on a street lamp saves the spot")
  calm(g)
  g.pigeon.hurt = 0
  g:hit("cat")
  check(g.mode == "dead" and g.deathReason == "cat", "losing the last feather ends the night")
  run(g, 1.2)
  g:keypressed("space")
  check(g.mode == "play" and g.feathers == 3 and math.abs(g.pigeon.x - lamp.x) < 1, "you come back at the last lamp")

  -- starving
  calm(g)
  g.hunger, g.feathers = 0, 1
  place(g, 5000, 190)
  run(g, 6)
  check(g.mode == "dead" and g.deathReason == "hunger", "an empty belly takes feathers too")
  run(g, 1.2)
  g:keypressed("e")

  -- dawn
  calm(g)
  g.clock = game.NIGHT - 0.05
  run(g, 0.1)
  check(g.mode == "dead" and g.deathReason == "dawn", "dawn ends the night if you're not at Sal's")
  run(g, 1.2)
  g:keypressed("e")
  check(g.clock < game.NIGHT, "retrying after dawn gives you a little more night")

  -- winning
  calm(g)
  g.hunger, g.warmth = 80, 80
  place(g, 6050, 250, 1)
  run(g, 1, { right = true })
  check(g.mode == "won", "landing on Sal's roof by the coop wins")

  -- drawing smoke test along the whole street
  local c = love.graphics.newCanvas(1280, 720)
  love.graphics.push("all")
  love.graphics.setCanvas(c)
  local g2 = game.new()
  for x = 100, city.W - 100, 500 do
    g2.pigeon.x, g2.camX = x, math.max(0, math.min(city.W - 1280, x - 640))
    g2:update(1 / 60, true)
    g2:draw()
  end
  g2:die("car")
  g2:draw()
  love.graphics.pop()
  check(true, "drew the whole city (and the death screen) without errors")
  print(("selftest passed: %d checks"):format(passed))
end

return T
