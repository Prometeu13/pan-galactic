-- `love pigeon-story --selftest`: a bot plays the whole story twice, once choosing every
-- tender option and once every hard-boiled one, checking each step.
-- Prints one line per check; exits with code 1 on the first failure.
-- The helpers (goTo, answer, finishChapter...) are also used by --snapshots.

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

local function hotspot(g, id)
  for _, h in ipairs(g.ch.hotspots) do if h.id == id then return h end end
  error("no hotspot " .. id .. " in chapter " .. g.ch.id)
end

-- Put Gus where he can use a hotspot (perched if it needs a perch).
function T.goTo(g, id)
  local h = hotspot(g, id)
  local gus = g.gus
  gus.hop = nil
  if h.perch then
    for _, p in ipairs(g.ch.perches) do
      if p.id == h.perch then
        gus.perch, gus.y = p, p.y
        gus.x = math.max(p.x1 + 10, math.min(p.x2 - 10, h.x))
      end
    end
  else
    gus.perch, gus.y = nil, 600
    gus.x = (h.kind == "exit") and h.x or h.x - 40
  end
  return h
end

-- Click through the open dialogue, answering choices from the list (then 1s).
function T.answer(g, picks)
  local guard = 0
  while g.dlg and guard < 400 do
    guard = guard + 1
    if g.dlg.choosing then
      g:choose(table.remove(picks, 1) or 1)
    else
      g:advance()
    end
  end
end

function T.closeAll(g) T.answer(g, {}) end

local SCRIPT = {
  alley = { "bench", "scarf", "puddle", "vinnie", "exit" },
  diner = { "sign", "window", "pip", "backdoor", "exit" },
  roof = { "coop", "rosa", "tony", "wren", "exit" },
  hospital = { "flowers", "window" },
}

-- Visit every hotspot of the current chapter in order, answering with `picks`.
function T.finishChapter(g, picks)
  local list = SCRIPT[g.ch.id]
  for _, id in ipairs(list) do
    if g.mode == "card" then break end
    T.goTo(g, id)
    g:interact()
    T.answer(g, picks)
  end
end

local function playthrough(game, tone, picks)
  print(("-- playthrough: %s choices"):format(tone))
  local g = game.new()
  check(g.mode == "card" and g.chapterIndex == 1, "starts on the chapter one card")
  g:beginPlay()
  check(g.mode == "talk", "the intro narration plays")
  T.closeAll(g)
  check(g.mode == "play", "then you're free to walk")

  -- chapter one
  T.goTo(g, "exit")
  check(g:interact() == "locked" and g.chapterIndex == 1, "the street stays locked until you learn something")
  T.closeAll(g)
  T.finishChapter(g, picks.alley)
  check(g:hasClue("Sal's scarf") and g:hasClue("the white van"), "chapter one: found the scarf and heard about the van")
  check(g.chapterIndex == 2 and g.mode == "card", "on to chapter two")

  -- chapter two
  g:beginPlay(); T.closeAll(g)
  T.goTo(g, "backdoor")
  g.gus.perch, g.gus.y = nil, 600
  check(g:interact() == "needPerch", "from the ground you can't hear the smoke break")
  T.closeAll(g)
  T.finishChapter(g, picks.diner)
  check(g:hasClue("St. Agnes"), "chapter two: overheard where Sal is")
  check((tone == "tender") == (g.flags.shared == true), "Pip's crust follows your choice")
  check(g.chapterIndex == 3, "on to chapter three")

  -- chapter three
  g:beginPlay(); T.closeAll(g)
  T.goTo(g, "exit")
  check(g:interact() == "locked", "you won't leave the roof without the flock")
  T.closeAll(g)
  T.finishChapter(g, picks.roof)
  check(#g.flock == 3, "Rosa, Tony and Wren joined the flock")
  check(g.chapterIndex == 4, "on to chapter four")

  -- chapter four
  g:beginPlay(); T.closeAll(g)
  for _ = 1, 120 do g:update(1 / 60, true) end
  check(math.abs(g.flock[1].x - g.gus.x) < 200, "the flock follows Gus")
  T.finishChapter(g, {})
  check(g.mode == "ending" and g.salAwake, "tapping on the window starts the finale")
  for _ = 1, 600 do g:update(1 / 60, true) end
  check(g.dawn > 0.95 and g.fx ~= nil, "dawn breaks and the colour comes back")
  check(g.tone == (tone == "tender" and "kind" or "grit"), "the epilogue matches who Gus became")
  for _ = 1, 20 do g:nextEpilogue() end
  check(g.mode == "theend", "THE END")

  -- draw every chapter once
  local c = love.graphics.newCanvas(1280, 720)
  love.graphics.push("all")
  love.graphics.setCanvas({ c, stencil = true })
  g:draw()
  for i = 1, 4 do
    local g2 = game.new()
    if i > 1 then g2:startChapter(i) end
    g2:beginPlay()
    g2:update(1 / 60, true)
    g2:draw()
  end
  love.graphics.pop()
  check(true, "every chapter draws without errors")
end

function T.run(game)
  playthrough(game, "tender", { alley = { 2, 1 }, diner = { 1 }, roof = { 2, 1, 1 } })
  playthrough(game, "hard-boiled", { alley = { 1, 2 }, diner = { 2 }, roof = { 1, 2, 2 } })
  print(("selftest passed: %d checks"):format(passed))
end

return T
