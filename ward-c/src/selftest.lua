-- `love ward-c --selftest`: checks the rules, then lets three bots play many shifts.
--   careful  : walks the round, raises the torch when it gets close, backs off in the dark
--   reckless : walks the round and never uses the torch
--   idle     : stands at the station and does nothing
-- A game that is fair but dangerous should let the careful bot win most shifts, and
-- should kill the other two. Prints one line per check; exit code 1 on failure.

local T = {}
local failed = false

local function check(cond, msg)
  if cond then print("ok    " .. msg) else print("FAIL  " .. msg) failed = true end
end

local DT = 1 / 60

-- Play one shift with a policy. Returns "won" / "dead" / "timeout", and the game.
local function play(Game, seed, policy, limit)
  local g = Game.new(seed)
  local t = 0
  while g.mode == "play" and t < (limit or 400) do
    local input = policy(g) or {}
    if input.use then g:use() end
    g:update(DT, input)
    t = t + DT
  end
  while g.mode == "caught" do g:update(DT) end
  return (g.mode == "play") and "timeout" or g.mode, g
end

local function target(g)
  for _, r in ipairs(g.rooms) do
    if not r.checked then return r end
  end
end

local function walkTo(g, z)
  if g.z < z - 0.15 then return { fwd = true } end
  if g.z > z + 0.15 then return { back = true } end
  return {}
end

local function careful(g)
  local gap = g.fig.z - g.z
  local dark = g.blackout > 0 or g.nextBlackout < 0.6
  -- too close: torch on it until it recoils
  if g.fig.state ~= "flee" and g.battery > 0.02 and (gap < 5.5 or (dark and gap < 8)) then
    return { light = true, back = gap < 3 }
  end
  if g.battery <= 0.02 and gap < 6 then return { back = true } end
  local r = target(g)
  if r then
    if g:nearRoom() == r then
      -- don't lean into a room with it right there, or just before the lights go
      -- (a look costs about 3 units of distance, so 5.2 leaves a margin)
      if gap > 5.2 and not dark then return { use = true } end
      return {}
    end
    return walkTo(g, r.z - 1.3)
  end
  if g:atStation() then return { use = true } end
  return { back = true }
end

local function reckless(g)
  local r = target(g)
  if r then
    if g:nearRoom() == r then return { use = true } end
    return walkTo(g, r.z - 1.3)
  end
  if g:atStation() then return { use = true } end
  return { back = true }
end

local function idle() return {} end

-- The same policy, but acting on what it saw a moment ago: a stand-in for human
-- reaction time.
local function slow(policy, frames)
  local queue = {}
  return function(g)
    if g.t < 0.05 then queue = {} end           -- a new shift
    queue[#queue + 1] = policy(g) or {}
    if #queue > frames then return table.remove(queue, 1) end
    return {}
  end
end

function T.run(Game, R, render)
  -- rules -------------------------------------------------------------------------
  local g = Game.new(1)
  check(g.mode == "play" and g.checked == 0 and #g.rooms == 6, "a new shift starts with six unchecked beds")
  g.nextBlackout = 99
  local z0 = g.fig.z
  for _ = 1, 240 do g:update(DT, {}) end
  check(math.abs(g.fig.z - z0) < 0.01, "with the lights on and you watching, it does not move")
  g.blackout = 1.0
  for _ = 1, 60 do g:update(DT, {}) end
  check(g.fig.z < z0 - 1.5, ("in a one-second blackout it comes %.1f units closer"):format(z0 - g.fig.z))
  g.blackout, g.nextBlackout = 2.0, 99
  g.z = g.fig.z - 8
  local z1 = g.fig.z
  for _ = 1, 30 do g:update(DT, { light = true }) end
  check(math.abs(g.fig.z - z1) < 0.01 and g.battery < 1, "the torch freezes it, even in a blackout, and drains the battery")
  for _ = 1, 60 do g:update(DT, { light = true }) end
  check(g.stats.repels == 1 and g.fig.z > z1, "a second of torch makes it recoil")
  for _ = 1, 120 do g:update(DT, {}) end
  g = Game.new(2)
  g.nextBlackout = 99
  g.z = 2.7
  check(g:nearRoom() and g:nearRoom().bed == 1 and g:prompt() == "E   check Bed 1", "standing by a door offers to check that bed")
  local zf = g.fig.z
  g:use()
  check(g.peek ~= nil, "E leans into the room")
  for _ = 1, 150 do g:update(DT, {}) end
  check(g.peek == nil and g.rooms[1].checked and g.checked == 1, "after the look, the bed is ticked off")
  check(g.fig.z < zf - 2.5, ("while you were not looking it came %.1f units closer"):format(zf - g.fig.z))
  local dead = 0
  for _, l in ipairs(g.lamps) do if l.dead then dead = dead + 1 end end
  check(dead == 1, "each checked bed costs the ward one lamp")
  g = Game.new(3)
  g.nextBlackout = 99
  g.battery = 0.2
  g.z = 10.7
  g:use()
  for _ = 1, 150 do g:update(DT, {}) end
  check(math.abs(g.battery - 0.7) < 0.01, "Bed 3 has batteries (+50%)")
  g = Game.new(4)
  g.fig.z = g.z + 1.2
  g:update(DT, {})
  check(g.mode == "caught", "if it reaches you, you are caught")
  for _ = 1, 200 do g:update(DT, {}) end
  check(g.mode == "dead", "...and the shift ends")
  g = Game.new(5)
  for _, r in ipairs(g.rooms) do r.checked = true end
  g.checked = 6
  g.z = 5
  g:use()
  check(g.mode == "play", "you can't clock out from the middle of the corridor")
  g.z = 1
  g:use()
  check(g.mode == "won", "all beds checked + back at the station + E = shift over")

  -- every screen draws ----------------------------------------------------------------
  local ok, err = pcall(function()
    local gg = Game.new(6)
    gg.nextBlackout = 99
    render()
    R.draw(gg)
    gg.z = 2.7
    gg:use()
    gg:update(DT)
    R.draw(gg)
    for _ = 1, 150 do gg:update(DT) end
    for z = 1, 27, 0.7 do
      gg.z = z
      gg.fig.z = math.min(29, z + 2 + (z % 3))
      gg.light = (math.floor(z) % 2 == 0)
      R.draw(gg)
    end
    gg.fig.z = gg.z + 1
    gg:update(DT)
    R.draw(gg)
    for _ = 1, 200 do gg:update(DT) end
    R.draw(gg)
    gg.mode = "won"
    R.draw(gg)
  end)
  check(ok, "title, corridor at every depth, room, caught, game over and win screens all draw" .. (ok and "" or (": " .. tostring(err))))

  -- bots -----------------------------------------------------------------------------
  local N = 40
  local function tally(policy, limit)
    local won, dead, timeout, time, batt = 0, 0, 0, 0, 0
    for seed = 1, N do
      local res, gg = play(Game, seed * 31, policy, limit)
      if res == "won" then
        won = won + 1
        time = time + gg.time
        batt = batt + gg.battery
      elseif res == "dead" then dead = dead + 1 else timeout = timeout + 1 end
      if os.getenv("WARD_DEBUG") and seed <= 10 then
        print(("        seed %2d: %-7s t=%5.1f beds=%d battery=%3.0f%% repels=%d blackouts=%d z=%.1f"):format(
          seed, res, gg.t, gg.checked, gg.battery * 100, gg.stats.repels, gg.stats.blackouts, gg.z))
      end
    end
    return won, dead, timeout, won > 0 and time / won or 0, won > 0 and batt / won or 0
  end
  local w, d, to, avg, batt = tally(careful)
  print(("      careful bot : %d won, %d caught, %d timed out of %d  (avg %.0f s, %.0f%% battery left)"):format(w, d, to, N, avg, batt * 100))
  check(w >= N * 0.8, "a careful player with perfect reflexes finishes the round")
  check(batt < 0.6, "...but it costs most of the battery")
  local ws, ds, tos, avgs, batts = tally(slow(careful, 24))
  print(("      careful, 0.4 s reactions: %d won, %d caught, %d timed out of %d  (avg %.0f s, %.0f%% battery left)"):format(ws, ds, tos, N, avgs, batts * 100))
  check(ws >= N * 0.4 and ds >= 1, "with human reaction time it is winnable, and it can go wrong")
  local w2, d2 = tally(reckless)
  print(("      reckless bot: %d won, %d caught of %d"):format(w2, d2, N))
  check(w2 <= N * 0.25, "walking the round without the torch gets you caught")
  local w3, d3, to3 = tally(idle, 600)
  print(("      idle bot    : %d won, %d caught, %d still standing after 10 minutes"):format(w3, d3, to3))
  check(w3 == 0, "standing still never wins")

  print(failed and "SELFTEST FAILED" or "selftest passed")
  return not failed
end

return T
