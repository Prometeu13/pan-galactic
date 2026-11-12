-- `love ward-c --selftest`: checks the rules, then lets bots play many shifts.
--   dutiful  : does the whole round (beds, water, blanket), defends itself with the torch,
--              hides when the battery is gone, and clocks out
--   escaper  : checks two beds, fetches the EXIT key, hides so that the figure walks past
--              to the other end of the ward, then leaves by the EXIT
--   reckless : does the round but never uses the torch and never hides
--   idle     : stands at the station and does nothing
-- A game that is fair but dangerous should let the first two usually win and should
-- kill the other two. Prints one line per check; exit code 1 on failure.

local T = {}
local failed = false

local function check(cond, msg)
  if cond then print("ok    " .. msg) else print("FAIL  " .. msg) failed = true end
end

local DT = 1 / 60
local G

local function sign(x) return x >= 0 and 1 or -1 end

---------------------------------------------------------------------------------------
-- bot building blocks. Each returns an input table: { fwd, back, light, use, turn }
---------------------------------------------------------------------------------------

-- the most pressing figure: out in the corridors and not already running away
local function threat(g)
  local best, bestGap
  for _, f in ipairs(g.figs) do
    if f.active and not f.inside and f.state ~= "flee" and f.state ~= "wander" then
      local gap = g:gap(f)
      if not best or gap < bestGap then best, bestGap = f, gap end
    end
  end
  return best, bestGap or math.huge
end

local function dark(g) return g.blackout > 0 or g.nextBlackout < 0.6 end

-- walk to a position anywhere in the ward; nil when there.
-- Like a person would: for a short way, back off while still facing the thing in front
-- of you; only turn your back on it for a long walk.
local function go(g, seg, p, tol)
  tol = tol or 0.15
  if g.seg ~= seg then
    if g.seg == "annex" then                      -- walk out through the mouth
      if g.dir ~= -1 then
        if g.z < 2.5 then return { back = true } end
        return { turn = true }
      end
      return { fwd = true }
    end
    local a = g:ahead()
    if a and a.kind == "annex" then return { use = true } end
    local want = (g.z <= G.J) and 1 or -1
    if g.dir ~= want then return { turn = true } end
    if want * (G.J - g.z) < 0.6 then return { back = true } end
    return { fwd = true }
  end
  local d = p - g.z
  if math.abs(d) <= tol then return nil end
  if g.dir ~= sign(d) then
    local f, gap = threat(g)
    local watching = f and g:sees(f) and gap < 10
    if math.abs(d) < 1.2 or (watching and math.abs(d) < 6) then return { back = true } end
    return { turn = true }
  end
  return { fwd = true }
end

-- stand so that a door is the thing in front of you, then use it
local function door(g, r, kind)
  if g.seg ~= "main" then return go(g, "main", r.z) end
  local a = g:ahead()
  if a and a.room == r and a.kind == kind then return { use = true } end
  -- from which side? Normally the side you are on; but if you are watching one of
  -- them, keep facing it and back up until the door is in front of you
  local want = (g.z <= r.z) and 1 or -1
  local f, gap = threat(g)
  if f and g:sees(f) and gap < 10 and math.abs(r.z - g.dir * 1.3 - g.z) < 6 then want = g.dir end
  local inp = go(g, "main", r.z - want * 1.3, 0.2)
  if inp then return inp end
  if g.dir ~= want then return { turn = true } end
  return {}
end

-- which way to face to look toward a figure
local function toward(g, f)
  if f.seg == g.seg then return sign(f.p - g.z) end
  if g.seg == "annex" then return -1 end
  if math.abs(G.J - g.z) < 0.3 then return g.dir end
  return sign(G.J - g.z)
end

-- a checked room whose lock still works, not past the figure and not right under its nose
local function usableRoom(g, f)
  local best, bestD
  for _, r in ipairs(g.rooms) do
    if r.checked and not r.lockUsed and r.request ~= "carried" then
      local d = g:pathDist(g.seg, g.z, "main", r.z)
      local ok = true
      if f then
        local fd = g:pathDist(f.seg, f.p, "main", r.z)
        if fd < G.SEE_YOU + 2.5 then ok = false end                 -- it would see you go in
        if f.seg == "main" and g.seg == "main" and (f.p - g.z) * (r.z - g.z) > 0 and math.abs(r.z - g.z) > 1.0 then ok = false end
      end
      if ok and (not best or d < bestD) then best, bestD = r, d end
    end
  end
  return best
end

-- behind a door: stay still and dark until they have gone
local function hidden(g, mem)
  local a = g.figs[1]
  if mem.flipFrom and a.home.p == mem.flipFrom then return {} end      -- it hasn't come past yet
  for _, f in ipairs(g.figs) do
    if f.active and not f.inside then
      local gap = g:gap(f)
      if f.state == "linger" then return {} end
      if f.state == "wander" and gap < 4 then return {} end
      if f.state == "still" and gap < 2.2 then return {} end
    end
  end
  mem.flipFrom = nil
  return { use = true }
end

-- Go and hide (so that figure A walks past and settles at the other end).
local function hideNow(g, mem)
  local a = g.figs[1]
  local f = threat(g)
  local r = usableRoom(g, f)
  if not r then return nil end
  mem.flipFrom = a.home.p
  return door(g, r, "hide")
end

-- Torch, turn, back off or hide as needed. Returns nil if nothing is pressing.
local function defend(g, mem, room, style)
  local f, gap = threat(g)
  if not f then return nil end
  -- battery nearly gone: get behind a door while there is still distance
  if style.hide and g.battery < 0.15 and gap < 11 then
    local h = hideNow(g, mem)
    if h then return h end
  end
  local limit = math.max(dark(g) and 8 or 5.5, (room or 0) + 0.3)
  if gap >= limit then return nil end
  -- it is already back where it lives: the torch can't push it any further
  local atHome = f.seg == f.home.seg and math.abs(f.p - f.home.p) < 0.3
  if atHome and gap >= 3 and not dark(g) then return nil end
  local need = toward(g, f)
  if g.dir ~= need then return { turn = true } end
  if g.battery <= 0.02 or not style.torch then return { back = true } end
  return { light = g:sees(f), back = gap < 3 }
end

-- how much clear distance an action needs (they walk at V_UNSEEN while you aren't looking)
local function roomFor(seconds) return seconds * G.V_UNSEEN + G.CATCH + 0.4 end

local function nextBed(g, beds)
  for _, bed in ipairs(beds) do
    if not g.rooms[bed].checked then return g.rooms[bed] end
  end
end

local function shelf(g)
  local inp = go(g, "annex", G.ANNEX - 1.6, 0.2)
  if inp then return inp end
  if g.dir ~= 1 then return { turn = true } end
  local a = g:ahead()
  if a and a.kind == "shelf" then
    local _, gap = threat(g)
    if gap > roomFor(G.RUMMAGE_TIME) and not dark(g) then return { use = true } end
  end
  return {}
end

local function careful(g, r, kind, seconds)
  local inp = door(g, r, kind)
  if inp.use then
    local _, gap = threat(g)
    if gap <= roomFor(seconds) or dark(g) then return {} end
  end
  return inp
end

---------------------------------------------------------------------------------------
-- the players
---------------------------------------------------------------------------------------
-- the round, in a sensible order: beds 1-4, supplies, deliveries, beds 5-6
local function roundStep(g)
  local r = nextBed(g, { 1, 2, 3, 4 })
  if r then return careful(g, r, "check", G.PEEK_TIME), roomFor(G.PEEK_TIME) end
  for _, rr in ipairs(g.rooms) do
    if rr.request == "asked" then return shelf(g), roomFor(G.RUMMAGE_TIME) end
  end
  local best
  for _, rr in ipairs(g.rooms) do
    if rr.request == "carried" and (not best or g:pathDist(g.seg, g.z, "main", rr.z) < g:pathDist(g.seg, g.z, "main", best.z)) then best = rr end
  end
  if best then return careful(g, best, "deliver", G.DELIVER_TIME), roomFor(G.DELIVER_TIME) end
  r = nextBed(g, { 5, 6 })
  if r then return careful(g, r, "check", G.PEEK_TIME), roomFor(G.PEEK_TIME) end
  return nil
end

local CAREFUL = { torch = true, hide = true }

local function dutiful(g, mem)
  if g.hide then return hidden(g, mem) end
  local step, room = roundStep(g)
  local d = defend(g, mem, room, CAREFUL)
  if d then return d end
  if step then return step end
  -- round done. If it has settled at the station, either lure it past a hiding place
  -- or, with no locks left, take the other way out.
  local a = g.figs[1]
  if a.home.p < 5 and a.state ~= "wander" then
    local h = hideNow(g, mem)
    if h then return h end
    return mem.leave(g, mem)
  end
  local inp = go(g, "main", 1.2)
  if inp then return inp end
  local ah = g:ahead()
  if ah and ah.kind == "clock" then return { use = true } end
  return {}
end

-- walk to the EXIT and unlock it (fetching the key first if need be)
function T.leave(g, mem)
  if not g.items.key then return shelf(g) end
  local inp = go(g, "main", G.LEN - 1.8, 0.25)
  if inp then return inp end
  if g.dir ~= 1 then return { turn = true } end
  local ah = g:ahead()
  if ah and ah.kind == "exit" then
    local _, gap = threat(g)
    if gap > roomFor(G.UNLOCK_TIME) and not dark(g) then return { use = true } end
  end
  return {}
end

local function escaper(g, mem)
  if g.hide then return hidden(g, mem) end
  local r = nextBed(g, { 1, 2 })
  local step, room
  if r then
    step, room = careful(g, r, "check", G.PEEK_TIME), roomFor(G.PEEK_TIME)
  elseif not g.items.key then
    step, room = shelf(g), roomFor(G.RUMMAGE_TIME)
  end
  local a = g.figs[1]
  if not step and a.home.p > 20 and a.state ~= "wander" then
    -- get behind a door and let it come and walk past
    return defend(g, mem, nil, CAREFUL) or hideNow(g, mem) or {}
  end
  local d = defend(g, mem, room or roomFor(G.UNLOCK_TIME), CAREFUL)
  if d then return d end
  if step then return step end
  return mem.leave(g, mem)
end

-- does the round, but never uses the torch, never hides, never waits
local function reckless(g, mem)
  local step = roundStep(g)
  if step then
    local a = g:ahead()
    if a and (a.kind == "check" or a.kind == "deliver" or a.kind == "shelf") then return { use = true } end
    return step
  end
  local inp = go(g, "main", 1.2)
  if inp then return inp end
  return { use = true }
end

local function idle() return {} end

-- The same policy with human reactions: the torch comes on `frames` late, and a key
-- press (E, Q) only happens after the bot has wanted it for a quarter of a second.
local function slow(policy, frames)
  local lights, want = {}, { use = 0, turn = 0 }
  return function(g, mem)
    if g.t < 0.05 then lights, want = {}, { use = 0, turn = 0 } end      -- a new shift
    local now = policy(g, mem) or {}
    local out = { fwd = now.fwd, back = now.back }
    lights[#lights + 1] = now.light or false
    if #lights > frames then out.light = table.remove(lights, 1) end
    for _, k in ipairs({ "use", "turn" }) do
      want[k] = now[k] and want[k] + 1 or 0
      if want[k] > 15 then
        out[k] = true
        want[k] = 0
      end
    end
    return out
  end
end

-- Play one shift with a policy. Returns "won" / "dead" / "timeout", and the game.
local function play(seed, policy, limit)
  local g = G.new(seed)
  local mem = { leave = T.leave }
  local t = 0
  local nextPrint = 0
  while g.mode == "play" and t < (limit or 600) do
    local input = policy(g, mem) or {}
    if T.trace and t >= nextPrint then
      nextPrint = t + 0.5
      local A, B = g.figs[1], g.figs[2]
      local keys = {}
      for k, v in pairs(input) do if v then keys[#keys + 1] = k end end
      table.sort(keys)
      print(("  t=%5.1f you %-5s %5.1f dir %+d batt %3.0f%% %-8s| A %-5s %5.1f %-6s seen=%s | B %s | bl=%.1f/%.1f | %s"):format(
        t, g.seg, g.z, g.dir, g.battery * 100, g.hide and "HIDDEN" or (g.busy and g.busy.kind or ""), A.seg, A.p, A.state, tostring(g:sees(A)),
        B.active and (B.inside and "in" or ("%s %.1f %s"):format(B.seg, B.p, B.state)) or "-", g.blackout, g.nextBlackout, table.concat(keys, "+")))
    end
    if input.turn then g:turnAround() end
    if input.use then g:use() end
    g:update(DT, input)
    t = t + DT
  end
  while g.mode == "caught" do g:update(DT) end
  return (g.mode == "play") and "timeout" or g.mode, g
end

local function run(g, seconds, input)
  for _ = 1, math.floor(seconds * 60 + 0.5) do g:update(DT, input) end
end

function T.run(Game, R, render)
  G = Game
  -- rules: light and dark -------------------------------------------------------------
  local g = G.new(1)
  local a, b = g.figs[1], g.figs[2]
  check(g.mode == "play" and g.checked == 0 and #g.rooms == 6 and not b.active, "a new shift: six unchecked beds, one figure at the far end")
  g.nextBlackout = 99
  local z0 = a.p
  run(g, 4)
  check(math.abs(a.p - z0) < 0.01, "lights on and you watching: it does not move")
  g.blackout = 1.0
  run(g, 1)
  check(a.p < z0 - 1.5, ("in a one-second blackout it comes %.1f units closer"):format(z0 - a.p))
  g.blackout, g.nextBlackout = 2.0, 99
  g.z = a.p - 8
  local z1 = a.p
  run(g, 0.5, { light = true })
  check(math.abs(a.p - z1) < 0.01 and g.battery < 1, "the torch freezes it, even in a blackout, and drains the battery")
  run(g, 1, { light = true })
  check(g.stats.repels == 1 and a.p > z1, "a second of torch makes it recoil")

  -- rules: beds -------------------------------------------------------------------------
  g = G.new(2)
  a = g.figs[1]
  g.nextBlackout = 99
  g.z = 2.7
  check(g:ahead() and g:ahead().kind == "check" and g:prompt() == "E   check Bed 1", "standing by a door offers to check that bed")
  local zf = a.p
  g:use()
  check(g.busy ~= nil and g.peek ~= nil, "E leans into the room")
  run(g, 2.5)
  check(g.busy == nil and g.rooms[1].checked and g.checked == 1, "after the look, the bed is ticked off")
  check(a.p < zf - 2.5, ("while you were not looking it came %.1f units closer"):format(zf - a.p))
  local dead = 0
  for _, l in ipairs(g.lamps.main) do if l.dead then dead = dead + 1 end end
  check(dead == 1, "each checked bed costs the ward one lamp")

  -- rules: turning around -----------------------------------------------------------------
  g = G.new(3)
  a = g.figs[1]
  g.nextBlackout = 99
  g.z = 12
  zf = a.p
  g:turnAround()
  run(g, 0.5)
  check(g.dir == -1, "Q turns you around")
  run(g, 2, { fwd = true })
  check(g.z < 12 - 4, ("walking away from it you cover %.1f units in 2 s (backing away: %.1f)"):format(12 - g.z, G.BACK * 2))
  check(a.p < zf - 3, ("...but with your back turned it follows: %.1f units closer"):format(zf - a.p))
  check(not g:sees(a), "you can't see what is behind you")
  g:turnAround()
  run(g, 0.5)
  local held = a.p
  run(g, 1)
  check(g:sees(a) and math.abs(a.p - held) < 0.01, "turn back and it stops")

  -- rules: the side corridor, requests, the key ---------------------------------------------
  g = G.new(4)
  a = g.figs[1]
  g.nextBlackout = 99
  for _, bed in ipairs({ 2, 4 }) do
    g.z = g.rooms[bed].z - 1.3
    a.p = G.FAR_HOME
    g:use()
    run(g, 2.5)
  end
  check(g.rooms[2].request == "asked" and g.rooms[4].request == "asked", "Bed 2 asks for water, Bed 4 needs a blanket")
  check(not g:roundDone(), "the round is not done while a patient is waiting")
  a.p = G.FAR_HOME
  g.z = 12.8
  check(g:ahead() and g:ahead().kind == "annex", "the side corridor opens off the main one")
  g:use()
  check(g.seg == "annex" and g.dir == 1, "E turns into it")
  check(math.abs(g:pathDist("annex", 5, "main", 20) - 11) < 0.01, "distances run through the junction (5 in + 6 along = 11)")
  g.z = G.ANNEX - 1.6
  local batt = g.battery
  g.battery = 0.3
  g:use()
  run(g, 1.5)
  check(g.items.water and g.items.blanket and g.items.key, "the shelves have water, a blanket and the EXIT key")
  check(math.abs(g.battery - 0.8) < 0.01, "...and batteries, once")
  check(a.seg == "main" and a.p < G.FAR_HOME - 1, "it kept coming while you rummaged")
  g:turnAround()
  run(g, 0.5)
  g.z = 0.6
  run(g, 0.5, { fwd = true })
  check(g.seg == "main" and math.abs(g.z - G.J) < 1.5, "walking out of the side corridor puts you back at the junction")
  a.p, a.state = G.FAR_HOME, "still"
  if g.dir ~= 1 then g:turnAround() run(g, 0.5) end
  g.z = g.rooms[4].z - 1.3
  check(g:ahead() and g:ahead().kind == "deliver", "back at Bed 4 with the blanket")
  g:use()
  run(g, 2)
  check(g.rooms[4].request == "done" and not g.items.blanket, "the blanket is delivered")

  -- rules: hiding -----------------------------------------------------------------------------
  g = G.new(5)
  a = g.figs[1]
  g.nextBlackout = 99
  g.rooms[3].checked = true
  g.z = g.rooms[3].z - 1.3
  a.p = g.z + 2
  g:use()
  check(g.hide == nil, "you can't hide with it right there: it would see you")
  a.p = 22
  g:use()
  check(g.hide ~= nil and g.rooms[3].lockUsed, "E on a checked room hides you in it")
  run(g, 7)
  check(a.state == "linger" and math.abs(a.p - g.rooms[3].z) < 0.7, "it comes to the door and waits outside")
  check(g.mode == "play", "...but it does not come in")
  run(g, 4)
  check(a.home.p == G.NEAR_HOME and (a.state == "wander" or a.p < 5), "then it searches on past, and settles at the other end of the ward")
  run(g, 12)
  check(a.state == "still" and math.abs(a.p - G.NEAR_HOME) < 0.1, "it does not come back to the door while you stay behind it")
  g:use()
  check(g.hide == nil and g.mode == "play", "step out once it has gone")
  if g.dir ~= -1 then g:turnAround() end
  run(g, 0.5)
  local was = a.p
  g:turnAround()
  run(g, 2)
  check(a.p > was + 1, "once you are out in the corridor again, it hunts again")
  g:turnAround()
  run(g, 0.5)
  a.p, a.state = G.NEAR_HOME, "still"
  if g.dir ~= 1 then g:turnAround() run(g, 0.5) end
  a.p = G.NEAR_HOME
  g.z = g.rooms[3].z - 1.3
  check(not (g:ahead() and g:ahead().kind == "hide" and g:ahead().room == g.rooms[3]), "each room hides you only once")
  g = G.new(6)
  a = g.figs[1]
  g.nextBlackout = 99
  g.rooms[3].checked = true
  g.z = g.rooms[3].z - 1.3
  a.p = 20
  g:use()
  run(g, 6)
  check(a.state == "linger", "(hiding again, with it outside the door)")
  run(g, 0.1, { light = true })
  check(g.mode == "caught", "a light under the door while it stands there: found")

  -- rules: the second figure ------------------------------------------------------------------
  g = G.new(7)
  a, b = g.figs[1], g.figs[2]
  g.nextBlackout = 99
  g.z = g.rooms[5].z - 1.3
  a.p = G.FAR_HOME
  g:use()
  run(g, 2.5)
  check(b.active and b.inside, "checking the empty bed wakes what is under it")
  g.z, a.p, a.state = 8, G.FAR_HOME, "still"
  local out = false
  for _ = 1, 12 do
    g.blackout, g.nextBlackout = 0, 0.01
    b.rest = 0
    run(g, 0.05)
    if not b.inside then out = true break end
    g.blackout = 0
  end
  check(out and b.seg == "main" and math.abs(b.p - 20) < 1.5, "it comes out of Bed 5's room when the lights go")
  g.blackout, g.nextBlackout = 0, 99
  g.z = 24
  a.p, b.p, b.state = G.FAR_HOME, 19, "still"
  local bz = b.p
  run(g, 1.5)
  check(not g:sees(b) and b.p > bz + 1.5, "now there is one behind you too, and that one moves")

  -- rules: endings ---------------------------------------------------------------------------
  g = G.new(8)
  g.figs[1].p = g.z + 1.2
  g:update(DT, {})
  check(g.mode == "caught", "if one reaches you, you are caught")
  run(g, 3.4)
  check(g.mode == "dead", "...and the shift ends")
  g = G.new(9)
  for _, r in ipairs(g.rooms) do r.checked = true if r.request then r.request = "done" end end
  g.checked = 6
  g.z = 5
  g:use()
  check(g.mode == "play", "you can't clock out from the middle of the corridor")
  g.z = 1
  g:use()
  check(g.mode == "won" and g.ending == "clock", "round done + back at the station + E = shift over")
  g = G.new(10)
  a = g.figs[1]
  g.nextBlackout = 99
  a.p, a.home.p = G.NEAR_HOME, G.NEAR_HOME
  g.z = G.LEN - 1.8
  g:use()
  check(g.mode == "play" and g.busy == nil, "the EXIT is chained without the key")
  g.items.key = true
  g:use()
  run(g, 3)
  check(g.mode == "won" and g.ending == "exit", "with the key (and nothing standing in front of it) the EXIT lets you out")

  -- every screen draws ----------------------------------------------------------------
  if R then
    local ok, err = pcall(function()
      local gg = G.new(11)
      gg.nextBlackout = 99
      render()
      R.draw(gg)
      gg.z = 2.7
      gg:use()
      gg:update(DT)
      R.draw(gg)
      run(gg, 2.5)
      for _, facing in ipairs({ 1, -1 }) do
        gg.dir = facing
        for z = 1, 28, 0.7 do
          gg.z = z
          gg.figs[1].p = math.max(1, math.min(G.FAR_HOME, z + facing * (2 + (z % 3))))
          gg.light = (math.floor(z) % 2 == 0)
          R.draw(gg)
        end
      end
      gg.figs[2].active, gg.figs[2].inside, gg.figs[2].p = true, false, 12
      gg.seg, gg.dir = "annex", 1
      for z = 0.3, 8.6, 0.6 do gg.z = z R.draw(gg) end
      gg.dir = -1
      gg.figs[2].seg, gg.figs[2].p = "annex", 1
      for z = 8.6, 0.3, -0.6 do gg.z = z R.draw(gg) end
      gg.z = G.ANNEX - 1.6
      gg.dir = 1
      gg.figs[1].p, gg.figs[2].seg, gg.figs[2].p = G.FAR_HOME, "main", 20
      gg:use()
      gg:update(DT)
      R.draw(gg)
      run(gg, 1.5)
      gg.seg, gg.z, gg.dir = "main", gg.rooms[1].z - 1.3, 1
      gg.figs[2].inside = true
      gg:use()
      for _ = 1, 20 do run(gg, 0.6) R.draw(gg) end
      gg:use()
      gg:turnAround()
      for _ = 1, 20 do gg:update(DT) R.draw(gg) end
      gg.figs[1].seg, gg.figs[1].p = gg.seg, gg.z + gg.dir
      gg:update(DT)
      R.draw(gg)
      run(gg, 1)
      R.draw(gg)
      run(gg, 3)
      R.draw(gg)
      for _, e in ipairs({ "clock", "exit" }) do
        gg.mode, gg.ending, gg.time = "won", e, 100
        R.draw(gg)
      end
    end)
    check(ok, "title, both corridors facing both ways, room, hiding, shelves, turn, caught, game over and both endings draw" .. (ok and "" or (": " .. tostring(err))))
  end

  -- bots -----------------------------------------------------------------------------
  local tr = os.getenv("WARD_TRACE")          -- e.g. WARD_TRACE=escaper:31 prints one shift
  if tr then
    local name, seed = tr:match("(%a+):(%d+)")
    T.trace = true
    local res = play(tonumber(seed), ({ dutiful = dutiful, escaper = escaper, reckless = reckless, slow = slow(dutiful, 24) })[name])
    print("  -> " .. res)
    return true
  end
  local N = 40
  local function tally(name, policy, limit)
    local s = { won = 0, dead = 0, timeout = 0, time = 0, batt = 0, hides = 0, repels = 0, clock = 0, exit = 0 }
    for seed = 1, N do
      local res, gg = play(seed * 31, policy, limit)
      s[res] = s[res] + 1
      if res == "won" then
        s.time = s.time + gg.time
        s.batt = s.batt + gg.battery
        s.hides = s.hides + gg.stats.hides
        s.repels = s.repels + gg.stats.repels
        s[gg.ending] = s[gg.ending] + 1
      end
      if os.getenv("WARD_DEBUG") and seed <= 12 then
        print(("        seed %2d: %-7s t=%5.1f beds=%d battery=%3.0f%% repels=%d hides=%d blackouts=%d at %s %.1f  A@%.1f(home %.1f) B %s"):format(
          seed, res, gg.t, gg.checked, gg.battery * 100, gg.stats.repels, gg.stats.hides, gg.stats.blackouts, gg.seg, gg.z,
          gg.figs[1].p, gg.figs[1].home.p, gg.figs[2].active and (gg.figs[2].inside and "in" or ("out@" .. math.floor(gg.figs[2].p))) or "asleep"))
      end
    end
    local w = math.max(1, s.won)
    print(("      %-22s: %2d won, %2d caught, %2d timed out of %d   (avg %3.0f s, %2.0f%% battery left, %.1f torch recoils, %.1f hides)"):format(
      name, s.won, s.dead, s.timeout, N, s.time / w, s.batt / w * 100, s.repels / w, s.hides / w))
    return s
  end
  local d1 = tally("dutiful", dutiful)
  check(d1.won >= N * 0.8 and d1.clock >= d1.won * 0.6, ("a careful nurse with perfect reflexes finishes the round (%d clocked out, %d had to use the EXIT)"):format(d1.clock, d1.exit))
  local d2 = tally("dutiful, 0.4 s slower", slow(dutiful, 24))
  check(d2.won >= N * 0.4, "with human reaction time the round is still winnable")
  check(d1.dead + d2.dead >= 1 or (d2.batt / math.max(1, d2.won)) < 0.6, "...but not for free (shifts are lost, or the battery runs low)")
  local e1 = tally("escaper", escaper)
  check(e1.won >= N * 0.7 and e1.exit == e1.won, "the EXIT is a real second way out (key + one hide)")
  local r1 = tally("reckless", reckless)
  check(r1.won <= N * 0.25, "doing the round without torch or hiding gets you caught")
  local i1 = tally("idle", idle, 600)
  check(i1.won == 0 and i1.dead == N, "standing still never wins")

  print(failed and "SELFTEST FAILED" or "selftest passed")
  return not failed
end

return T
