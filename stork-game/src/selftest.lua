-- `love stork-game --selftest`: a bot plays the whole game by teleporting the stork next
-- to each objective and pressing "peck". Every step checks the game state.
-- Prints a line per check; exits with code 1 on the first failure.

local world = require("src.world")

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
  g.input = input or { left = false, right = false, flapHeld = false, flapPressed = false }
  for _ = 1, math.floor(seconds * 60) do
    g:update(1 / 60, true)
    g.input.flapPressed = false
  end
end

local function closeDialogue(g)
  local guard = 0
  while #g.dialogue > 0 and guard < 200 do g:advance(); guard = guard + 1 end
end

-- Put the stork so its beak reaches (x, y).
local function reachFor(g, x, y, air)
  local s = g.stork
  s.dir = 1
  s.air = air or false
  s.vx, s.vy = 0, 0
  if air then
    s.x, s.y = x - 62, y + 40
  else
    s.x = x - 52
    s.y = world.ground(s.x)
  end
end

function T.run(game)
  local g = game.new()
  check(#g.dialogue == 3, "intro dialogue queued")
  closeDialogue(g)
  check(#g.dialogue == 0, "intro dialogue dismissed")

  -- movement
  local x0 = g.stork.x
  run(g, 1, { right = true })
  check(g.stork.x > x0 + 100, "walking right moves the stork")
  run(g, 0.05, { flapPressed = true, flapHeld = true })
  check(g.stork.air, "flapping lifts off")
  run(g, 4, {})
  check(not g.stork.air, "the stork lands again")

  -- twigs (two need flight: the roof and the ledge)
  for i, tw in ipairs(g.w.twigs) do
    local high = tw.y < world.ground(tw.x) - 30
    reachFor(g, tw.x, tw.y, high)
    check(g:interact() == "twig", ("twig %d picked up%s"):format(i, high and " (in flight)" or ""))
  end
  check(g.stork.carry.twigs == 5, "carrying 5 twigs")

  -- deliver to the nest
  local n = g.nest
  g.stork.x, g.stork.y, g.stork.air = n.x - 20, n.y + 50, true
  check(g:interact() == "nest", "deliver at the nest")
  closeDialogue(g)
  check(n.twigs == 5 and g.stork.carry.twigs == 0, "nest has 5 twigs")

  -- fishing: stand in each water zone where a fish is, peck
  local caught = 0
  for _, f in ipairs(g.w.fish) do
    if caught < 2 then
      local s = g.stork
      s.dir, s.air, s.vx, s.vy = 1, false, 0, 0
      s.x = f.x - 52
      s.y = world.ground(s.x)
      if g:interact() == "fish" then caught = caught + 1 end
    end
  end
  check(caught == 2, "caught 2 fish by pecking at their shadows")

  -- the lantern quest
  local fm = g.w.fisherman
  g.stork.x, g.stork.y, g.stork.air = fm.x - 60, world.ground(fm.x - 60), false
  check(g:interact() == "fisherman" and g.quest.asked, "the fisherman asks about his lantern")
  closeDialogue(g)
  local l = g.w.lantern
  reachFor(g, l.x, l.y)
  check(g:interact() == "lantern" and g.stork.carry.lantern, "found the lantern in the bamboo")
  g.stork.x, g.stork.y = fm.x - 60, world.ground(fm.x - 60)
  g:interact()
  closeDialogue(g)
  check(g.quest.returned and g.stork.carry.fish == 3, "lantern returned; the fisherman gives a fish")

  -- a seal stone paints its region in
  local seal = g.w.seals[2]
  check(g:inkAt(seal.x) < 0.3, "the village starts as a faint sketch")
  g.stork.x, g.stork.y, g.stork.air = seal.x - 20, world.ground(seal.x - 20), false
  check(g:interact() == "seal" and g.haiku, "reading a seal stone shows a haiku")
  run(g, 6, {})
  check(g:inkAt(seal.x) > 0.95 and g:inkAt(seal.x + 600) > 0.9, "the village is painted in")

  -- feed the chick and finish
  g.stork.x, g.stork.y, g.stork.air = n.x - 20, n.y + 50, true
  g:interact()
  check(n.fed == 3 and g.ended, "chick fed: the ending begins")
  closeDialogue(g)
  run(g, 10, {})
  check(g.dusk > 0.9 and #g.lanterns > 0, "dusk falls and lanterns rise")

  -- drawing smoke test, all along the valley
  local c = love.graphics.newCanvas(1280, 720)
  love.graphics.push("all")
  love.graphics.setCanvas({ c, stencil = true })
  for x = 100, world.W - 100, 400 do
    g.stork.x, g.camX = x, math.max(0, math.min(world.W - 1280, x - 640))
    g:draw()
  end
  love.graphics.pop()
  check(true, "drew the whole valley without errors")
  print(("selftest passed: %d checks"):format(passed))
end

return T
