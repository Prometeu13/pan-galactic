-- All the "art": everything is drawn from primitives, no image files.
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local lg = love.graphics

local A = {}
local col = D.color
local PI = math.pi

-- THE TRUCK (side view) ------------------------------------------------------------------------
-- (x, y) = bottom centre of the hull. Thruster flames hang below y.
function A.truck(x, y, s, t, opts)
  opts = opts or {}
  lg.push()
  lg.translate(x, y)
  lg.scale(s * (opts.flip and -1 or 1), s)

  -- thrusters
  for _, tx in ipairs({ -95, 75 }) do
    local fl = 16 + math.sin(t * 31 + tx) * 5 + love.math.random() * 5
    if opts.noFlame then fl = 0 end
    if fl > 0 then
      lg.setColor(1, 0.45, 0.1, 0.85)
      lg.polygon("fill", tx - 13, 10, tx + 13, 10, tx, 22 + fl)
      lg.setColor(1, 0.92, 0.45, 0.95)
      lg.polygon("fill", tx - 6, 10, tx + 6, 10, tx, 14 + fl * 0.7)
    end
    lg.setColor(0.36, 0.36, 0.44)
    D.rrect("fill", tx - 20, -8, 40, 18, 6)
    lg.setColor(0.2, 0.2, 0.26)
    D.rrect("fill", tx - 15, 6, 30, 7, 2)
  end

  local body, trim = { 0.96, 0.88, 0.7 }, { 0.2, 0.74, 0.72 }
  -- shadowy underside
  lg.setColor(0, 0, 0, 0.25)
  D.rrect("fill", -152, -126, 300, 126, 18)
  -- main box and cab
  col(body)
  D.rrect("fill", -155, -132, 225, 130, 18)
  D.rrect("fill", 50, -104, 98, 102, 26)
  -- windshield
  lg.setColor(0.5, 0.82, 1, 0.95)
  lg.polygon("fill", 95, -96, 132, -96, 142, -56, 95, -56)
  lg.setColor(1, 1, 1, 0.55)
  lg.setLineWidth(3)
  lg.line(104, -90, 112, -64)
  -- door + handle
  lg.setColor(0, 0, 0, 0.18)
  lg.setLineWidth(2)
  D.rrect("line", 60, -94, 30, 80, 6)
  lg.setColor(0.4, 0.4, 0.45)
  lg.rectangle("fill", 82, -58, 6, 3)
  -- stripes
  col(trim)
  lg.rectangle("fill", -155, -44, 300, 18)
  col(T.c.orange)
  lg.rectangle("fill", -155, -24, 300, 6)
  -- serving window with a chef inside
  lg.setColor(0.12, 0.08, 0.18)
  D.rrect("fill", -135, -108, 160, 58, 6)
  lg.setColor(1, 0.8, 0.6)
  lg.circle("fill", -50, -64, 12)
  lg.setColor(1, 1, 1)
  lg.circle("fill", -56, -82, 8)
  lg.circle("fill", -44, -82, 8)
  lg.circle("fill", -50, -86, 9)
  lg.rectangle("fill", -60, -80, 20, 6)
  lg.setColor(0.1, 0.1, 0.1)
  lg.circle("fill", -46, -64, 2)
  -- a steaming pot on the counter
  lg.setColor(0.6, 0.6, 0.7)
  lg.rectangle("fill", -112, -66, 26, 16)
  lg.setColor(1, 1, 1, 0.5)
  for i = 0, 2 do
    local sy = (t * 20 + i * 8) % 24
    lg.circle("fill", -104 + i * 5 + math.sin(t * 3 + i) * 3, -70 - sy, 3 - sy / 12)
  end
  -- awning
  for i = 0, 5 do
    local ax = -142 + i * 30
    col(i % 2 == 0 and { 0.95, 0.3, 0.32 } or { 0.98, 0.95, 0.9 })
    lg.rectangle("fill", ax, -124, 30, 14)
    lg.arc("fill", ax + 15, -110, 15, 0, PI)
  end
  -- rust and rivets
  lg.setColor(0.6, 0.34, 0.2, 0.55)
  lg.circle("fill", -144, -60, 6)
  lg.circle("fill", 34, -14, 4)
  lg.circle("fill", 128, -32, 3)
  lg.setColor(0.4, 0.36, 0.42)
  for i = 0, 9 do lg.circle("fill", -148 + i * 30, -35, 2) end
  -- roof sign
  lg.setColor(0.4, 0.4, 0.46)
  lg.rectangle("fill", -100, -146, 5, 16)
  lg.rectangle("fill", 18, -146, 5, 16)
  lg.setColor(0.25, 0.2, 0.42)
  D.rrect("fill", -122, -176, 166, 32, 8)
  local blink = (math.floor(t * 2) % 2 == 0)
  col(blink and T.c.gold or T.c.orange)
  lg.setFont(T.font(13))
  lg.printf("GARGLE BLASTER", -122, -168, 166, "center")
  -- giant cocktail on the sign
  lg.setColor(0.75, 0.95, 1, 0.9)
  lg.polygon("fill", 50, -198, 86, -198, 68, -172)
  lg.setColor(0.4, 1, 0.6)
  lg.polygon("fill", 55, -194, 81, -194, 68, -177)
  lg.setColor(0.75, 0.95, 1, 0.9)
  lg.rectangle("fill", 66, -172, 4, 22)
  lg.rectangle("fill", 58, -152, 20, 4)
  lg.setColor(0.4, 0.75, 0.2)
  lg.circle("fill", 78, -200, 5)
  -- dish and antenna on the cab
  lg.setColor(0.7, 0.7, 0.76)
  lg.rectangle("fill", 108, -116, 4, 14)
  lg.arc("fill", 110, -118, 18, PI + 0.2, 2 * PI - 0.2)
  lg.setColor(0.4, 0.4, 0.46)
  lg.setLineWidth(2)
  lg.line(132, -102, 140, -140)
  lg.setColor(1, 0.25, 0.2, (math.sin(t * 5) > 0) and 1 or 0.3)
  lg.circle("fill", 140, -142, 4)

  lg.pop()
end

-- ALIENS (front view) -------------------------------------------------------------------------
-- (x, y) = feet. mood: neutral | happy | angry | confused
local function eyes(n, cx, cy, spread, r, mood, t, glow)
  for i = 1, n do
    local ex = cx + (n == 1 and 0 or (-spread / 2 + (i - 1) * spread / (n - 1)))
    if mood == "happy" then
      lg.setLineWidth(3)
      lg.setColor(0.1, 0.08, 0.12)
      lg.arc("line", "open", ex, cy + 2, r * 0.8, PI + 0.3, 2 * PI - 0.3)
    else
      if glow then col(T.c.crtText) else lg.setColor(1, 1, 1) end
      lg.circle("fill", ex, cy, r)
      lg.setColor(0.1, 0.08, 0.12)
      local blink = ((t + i * 0.3) % 3.7) < 0.12
      if blink then
        lg.setLineWidth(2)
        lg.line(ex - r, cy, ex + r, cy)
      else
        lg.circle("fill", ex + r * 0.3, cy, r * 0.45)
      end
      if mood == "angry" then
        lg.setLineWidth(3)
        local dir = (ex < cx) and 1 or -1
        lg.line(ex - r * dir, cy - r * 1.5, ex + r * dir, cy - r * 0.9)
      end
    end
  end
end

local function mouth(cx, cy, w, mood)
  lg.setColor(0.1, 0.08, 0.12)
  lg.setLineWidth(3)
  if mood == "happy" then
    lg.arc("fill", cx, cy - 2, w * 0.6, 0, PI)
  elseif mood == "angry" then
    lg.arc("line", "open", cx, cy + w * 0.4, w * 0.5, PI + 0.4, 2 * PI - 0.4)
  elseif mood == "confused" then
    lg.line(cx - w * 0.5, cy, cx - w * 0.2, cy - 3, cx + w * 0.1, cy + 3, cx + w * 0.5, cy - 2)
  else
    lg.line(cx - w * 0.4, cy, cx + w * 0.4, cy)
  end
end

function A.alien(x, y, s, look, mood, t, phase)
  mood = mood or "neutral"
  lg.push()
  local bounce = mood == "happy" and math.abs(math.sin(t * 9)) * 10 or math.sin(t * 3 + (phase or 0)) * 3
  lg.translate(x, y - bounce * s)
  lg.scale(s)
  local c = look.color
  if mood == "angry" then c = D.mix(c, { 1, 0.15, 0.1 }, 0.35 + 0.1 * math.sin(t * 10)) end
  local dark = D.mix(c, { 0, 0, 0 }, 0.3)
  local hx, hy, spread, er, mx, my, mw = 0, -80, 34, 9, 0, -50, 26
  local glow = false

  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 2, 50, 10)

  if look.shape == "blob" then
    col(dark)
    for i = -2, 2 do lg.ellipse("fill", i * 17, -6, 10, 12) end
    col(c)
    lg.ellipse("fill", 0, -62, 50, 58)
    if look.suit then
      lg.setColor(0.25, 0.25, 0.35)
      lg.polygon("fill", -38, -40, 38, -40, 30, -10, -30, -10)
      lg.setColor(1, 1, 1)
      lg.polygon("fill", -8, -40, 8, -40, 0, -24)
      lg.setColor(0.9, 0.2, 0.2)
      lg.polygon("fill", -3, -34, 3, -34, 0, -16)
    end
    hy, spread, er, my = -82, 30, 14, -58
  elseif look.shape == "tall" then
    col(dark)
    lg.rectangle("fill", -18, -40, 10, 40)
    lg.rectangle("fill", 8, -40, 10, 40)
    col(c)
    D.rrect("fill", -30, -118, 60, 82, 14)
    lg.rectangle("fill", -6, -132, 12, 16)
    lg.ellipse("fill", 0, -152, 34, 26)
    if look.tie then
      lg.setColor(0.25, 0.22, 0.4)
      lg.polygon("fill", -6, -116, 6, -116, 9, -70, 0, -60, -9, -70)
      lg.setColor(0.95, 0.95, 0.85)
      D.rrect("fill", 12, -100, 22, 28, 3)
      lg.setColor(0.4, 0.4, 0.5)
      for i = 0, 3 do lg.line(15, -94 + i * 6, 30, -94 + i * 6) end
    end
    hx, hy, spread, er, my, mw = 0, -156, 30, 8, -140, 22
  elseif look.shape == "box" then
    col(dark)
    lg.rectangle("fill", -22, -30, 12, 30)
    lg.rectangle("fill", 10, -30, 12, 30)
    col(c)
    D.rrect("fill", -38, -104, 76, 76, 6)
    D.rrect("fill", -32, -158, 64, 50, 8)
    lg.setColor(0.4, 0.4, 0.46)
    lg.setLineWidth(2)
    lg.line(0, -158, 0, -176)
    lg.setColor(1, 0.3, 0.3, (math.sin(t * 2) > 0) and 1 or 0.3)
    lg.circle("fill", 0, -178, 4)
    col(T.c.crt)
    D.rrect("fill", -26, -152, 52, 38, 4)
    lg.setColor(0.3, 0.3, 0.36)
    for i = 0, 2 do lg.circle("fill", -14 + i * 14, -70, 5) end
    hy, spread, er, my, mw = -138, 24, 6, -122, 18
    glow = true
  elseif look.shape == "mouse" then
    lg.setLineWidth(4)
    col(D.mix(c, { 1, 0.6, 0.7 }, 0.4))
    lg.line(36, -20, 60, -30, 70, -60)
    col(c)
    lg.ellipse("fill", 0, -46, 40, 46)
    for _, sx in ipairs({ -32, 32 }) do
      col(c)
      lg.circle("fill", sx, -124, 24)
      lg.setColor(1, 0.7, 0.75)
      lg.circle("fill", sx, -124, 14)
    end
    col(c)
    lg.circle("fill", 0, -98, 36)
    lg.setColor(1, 0.55, 0.65)
    lg.circle("fill", 0, -86, 6)
    lg.setColor(0.4, 0.35, 0.35)
    lg.setLineWidth(1.5)
    for i = -1, 1 do
      lg.line(10, -86 + i * 4, 40, -90 + i * 7)
      lg.line(-10, -86 + i * 4, -40, -90 + i * 7)
    end
    -- tiny spectacles: it's a philosopher
    lg.setColor(0.2, 0.2, 0.25)
    lg.setLineWidth(2)
    lg.circle("line", -13, -104, 11)
    lg.circle("line", 13, -104, 11)
    lg.line(-2, -104, 2, -104)
    hy, spread, er, my, mw = -104, 26, 7, -74, 16
  elseif look.shape == "cone" then
    col(c)
    lg.polygon("fill", -46, 0, 46, 0, 26, -100, -26, -100)
    lg.ellipse("fill", 0, -100, 26, 14)
    col(dark)
    for i = 0, 6 do
      lg.polygon("fill", -46 + i * 13, 0, -40 + i * 13, -14, -33 + i * 13, 0)
    end
    if look.hat then
      lg.setColor(0.3, 0.6, 1)
      lg.polygon("fill", -18, -108, 18, -108, 0, -160)
      lg.setColor(1, 0.9, 0.3)
      lg.circle("fill", 0, -162, 6)
      for i = 0, 2 do
        lg.setColor(1, 0.4, 0.4)
        lg.circle("fill", -10 + i * 10, -120 - i * 12, 3)
      end
    end
    hy, spread, er, my, mw = -70, 40, 9, -40, 28
  elseif look.shape == "puddle" then
    col(c)
    lg.ellipse("fill", 0, -22, 64, 24)
    lg.ellipse("fill", -40, -6, 20, 8)
    lg.ellipse("fill", 44, -4, 16, 6)
    lg.setColor(1, 1, 1, 0.35)
    lg.ellipse("fill", -20, -32, 18, 6)
    col(c)
    lg.setLineWidth(5)
    local sway = math.sin(t * 2) * 6
    lg.line(-14, -30, -22 + sway, -80)
    lg.line(14, -30, 24 + sway, -88)
    hx, hy, spread, er, my, mw = 1 + sway, -84, 46, 11, -18, 30
  end

  eyes(look.eyes or 2, hx, hy, spread, er, mood, t, glow)
  if look.shape == "box" then
    col(T.c.crtText)
    lg.setLineWidth(2)
    if mood == "happy" then
      lg.line(-9, my, 0, my + 3, 9, my)
    else
      lg.line(-9, my + 2, 9, my + 2)
    end
  else
    mouth(mx, my, mw, mood)
  end

  if mood == "confused" then
    col(T.c.gold)
    lg.setFont(T.font(30))
    lg.print("?", 30, hy - 70 + math.sin(t * 4) * 4)
  elseif mood == "angry" then
    lg.setColor(1, 1, 1, 0.6)
    for i = 0, 2 do
      local sy = (t * 40 + i * 14) % 40
      lg.circle("fill", -30 + i * 30, hy - 40 - sy, 6 - sy / 10)
    end
  end
  lg.pop()
end

-- INGREDIENTS ----------------------------------------------------------------------------------
function A.ingredient(x, y, r, def, t)
  local c = def.color
  local jx = def.volatile and math.sin(t * 43) * r * 0.05 or 0
  lg.push()
  lg.translate(x + jx, y)
  local hl = D.mix(c, { 1, 1, 1 }, 0.5)
  local dk = D.mix(c, { 0, 0, 0 }, 0.35)
  local sh = def.shape

  if sh == "berry" then
    for _, p in ipairs({ { -0.32, 0.18 }, { 0.32, 0.18 }, { 0, -0.22 }, { 0, 0.45 } }) do
      col(c); lg.circle("fill", p[1] * r, p[2] * r, r * 0.4)
      col(hl); lg.circle("fill", p[1] * r - r * 0.12, p[2] * r - r * 0.12, r * 0.1)
    end
    lg.setColor(0.3, 0.75, 0.3)
    lg.ellipse("fill", r * 0.15, -r * 0.62, r * 0.3, r * 0.12)
  elseif sh == "truffle" then
    col(c)
    lg.circle("fill", 0, 0, r * 0.72)
    for i = 0, 6 do
      local a = i / 7 * PI * 2
      lg.circle("fill", math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, r * 0.25)
    end
    lg.setColor(0.8, 0.2, 0.3, 0.8)
    for i = 0, 4 do lg.circle("fill", math.cos(i * 1.9) * r * 0.4, math.sin(i * 2.3) * r * 0.4, r * 0.06) end
  elseif sh == "kelp" then
    lg.setLineWidth(r * 0.22)
    for k = -1, 1 do
      local pts = {}
      for i = 0, 8 do
        local yy = r * 0.85 - i * r * 0.21
        pts[#pts + 1] = k * r * 0.35 + math.sin(i * 0.9 + t * 2 + k) * r * 0.15
        pts[#pts + 1] = yy
      end
      col(k == 0 and c or dk)
      lg.line(pts)
    end
    lg.setColor(0.7, 0.85, 1, 0.8)
    lg.circle("fill", r * 0.45, -r * 0.1 + (t * 10 % 10), r * 0.08)
  elseif sh == "crystal" then
    local shards = { { 0, 1, 0.3, 0 }, { -0.42, 0.75, 0.22, -0.4 }, { 0.42, 0.7, 0.22, 0.4 } }
    for _, s in ipairs(shards) do
      local bx, h, w, lean = s[1] * r, s[2] * r, s[3] * r, s[4] * r
      col(c)
      lg.polygon("fill", bx - w, r * 0.6, bx + w, r * 0.6, bx + w * 0.7 + lean * 0.3, r * 0.6 - h, bx + lean * 0.3, r * 0.6 - h * 1.25, bx - w * 0.7 + lean * 0.3, r * 0.6 - h)
      col(hl, 0.7)
      lg.polygon("fill", bx - w * 0.2, r * 0.6, bx + w * 0.2, r * 0.6, bx + lean * 0.3, r * 0.6 - h * 1.2)
    end
  elseif sh == "pepper" then
    col(c)
    local pts = {}
    for i = 0, 10 do
      local a = i / 10
      pts[#pts + 1] = -r * 0.7 + a * r * 1.3
      pts[#pts + 1] = -r * 0.3 + math.sin(a * PI) * r * 0.55 - a * r * 0.2
    end
    lg.setLineWidth(r * 0.45)
    lg.line(pts)
    lg.circle("fill", pts[1], pts[2], r * 0.22)
    lg.setColor(0.3, 0.7, 0.25)
    lg.setLineWidth(r * 0.12)
    lg.line(-r * 0.75, -r * 0.3, -r * 0.85, -r * 0.65)
    col(hl, 0.6)
    lg.setLineWidth(r * 0.08)
    lg.line(-r * 0.4, -r * 0.05, 0, r * 0.12)
  elseif sh == "egg" then
    col(c)
    lg.ellipse("fill", 0, 0, r * 0.62, r * 0.82)
    lg.setColor(0.5, 0.4, 0.55)
    for i = 0, 4 do lg.circle("fill", math.cos(i * 2.1) * r * 0.32, math.sin(i * 1.7) * r * 0.45, r * 0.07) end
    lg.setColor(0.2, 0.15, 0.2)
    lg.setLineWidth(2)
    lg.line(-r * 0.5, -r * 0.1, -r * 0.2, r * 0.05, 0, -r * 0.15, r * 0.25, r * 0.05, r * 0.5, -r * 0.1)
  elseif sh == "noodle" then
    lg.setLineWidth(r * 0.12)
    for k = 0, 4 do
      local pts = {}
      for i = 0, 12 do
        pts[#pts + 1] = -r * 0.8 + i * r * 0.133
        pts[#pts + 1] = -r * 0.45 + k * r * 0.22 + math.sin(i * 1.3 + k + t * 4) * r * 0.1
      end
      col(k % 2 == 0 and c or dk)
      lg.line(pts)
    end
  elseif sh == "leaf" then
    lg.push()
    lg.rotate(-0.6)
    col(c)
    lg.ellipse("fill", 0, 0, r * 0.4, r * 0.85)
    col(dk)
    lg.setLineWidth(2)
    lg.line(0, -r * 0.8, 0, r * 0.85)
    for i = -2, 2 do lg.line(0, i * r * 0.25, r * 0.3, i * r * 0.25 - r * 0.15) end
    lg.pop()
  elseif sh == "root" then
    col(c)
    lg.polygon("fill", -r * 0.38, -r * 0.45, r * 0.38, -r * 0.45, r * 0.05, r * 0.9)
    lg.circle("fill", 0, -r * 0.45, r * 0.38)
    col(dk)
    lg.setLineWidth(2)
    for i = 0, 3 do lg.line(-r * 0.25 + i * 0.03 * r, -r * 0.1 + i * r * 0.2, r * 0.15, -r * 0.05 + i * r * 0.2) end
    lg.setColor(0.4, 0.6, 0.35)
    lg.setLineWidth(r * 0.1)
    lg.line(0, -r * 0.8, -r * 0.2, -r * 1.05)
    lg.line(0, -r * 0.8, r * 0.2, -r * 1.05)
  elseif sh == "mango" then
    col(c)
    lg.ellipse("fill", 0, r * 0.05, r * 0.78, r * 0.62)
    col(D.mix(c, { 1, 0.2, 0.1 }, 0.4))
    lg.ellipse("fill", r * 0.25, r * 0.15, r * 0.4, r * 0.35)
    col(hl, 0.7)
    lg.ellipse("fill", -r * 0.3, -r * 0.2, r * 0.2, r * 0.1)
    lg.setColor(0.3, 0.7, 0.3)
    lg.ellipse("fill", r * 0.2, -r * 0.62, r * 0.3, r * 0.1)
  elseif sh == "gristle" then
    col(c)
    D.rrect("fill", -r * 0.75, -r * 0.5, r * 1.5, r, r * 0.4)
    lg.circle("fill", -r * 0.4, -r * 0.5, r * 0.3)
    lg.circle("fill", r * 0.3, r * 0.45, r * 0.32)
    col(hl, 0.5)
    lg.ellipse("fill", -r * 0.2, -r * 0.2, r * 0.4, r * 0.1)
    lg.setColor(0.2, 0.2, 0.15)
    lg.setLineWidth(1)
    lg.rectangle("line", r * 0.1, -r * 0.3, r * 0.35, r * 0.4)
  elseif sh == "corn" then
    lg.setColor(0.45, 0.75, 0.3)
    lg.polygon("fill", -r * 0.5, r * 0.9, -r * 0.1, -r * 0.3, 0, r * 0.9)
    lg.polygon("fill", r * 0.5, r * 0.9, r * 0.1, -r * 0.3, 0, r * 0.9)
    col(c)
    lg.ellipse("fill", 0, -r * 0.1, r * 0.35, r * 0.85)
    col(dk)
    for i = -3, 3 do
      for j = -1, 1 do lg.circle("fill", j * r * 0.16, -r * 0.1 + i * r * 0.2, r * 0.05) end
    end
  elseif sh == "jar" then
    col(c, 0.85)
    D.rrect("fill", -r * 0.55, -r * 0.55, r * 1.1, r * 1.35, r * 0.2)
    lg.setColor(0.5, 0.45, 0.6)
    D.rrect("fill", -r * 0.62, -r * 0.8, r * 1.24, r * 0.3, 4)
    lg.setColor(0.97, 0.94, 0.85)
    lg.rectangle("fill", -r * 0.45, -r * 0.15, r * 0.9, r * 0.45)
    lg.setColor(1, 1, 1, 0.4)
    lg.rectangle("fill", -r * 0.42, -r * 0.5, r * 0.12, r * 1.1)
  end

  if def.volatile then
    lg.setColor(1, 0.95, 0.5, 0.9)
    lg.setLineWidth(2)
    for i = 0, 3 do
      local a = t * 6 + i * PI / 2
      local r1, r2 = r * 0.95, r * (1.15 + 0.1 * math.sin(t * 20 + i))
      lg.line(math.cos(a) * r1, math.sin(a) * r1, math.cos(a) * r2, math.sin(a) * r2)
    end
  end
  lg.pop()
end

-- THE FLAVOR SYNTHESIZER -----------------------------------------------------------------------
-- (x, y) = bottom centre. liquid: colour. heat: 0..1 how hard it's working.
function A.synth(x, y, t, liquid, heat)
  heat = heat or 0
  local shake = heat > 0.5 and (love.math.random() - 0.5) * 6 * heat or 0
  lg.push()
  lg.translate(x + shake, y)
  -- pipes
  lg.setColor(0.45, 0.42, 0.55)
  lg.setLineWidth(10)
  lg.line(-90, -50, -110, -50, -110, -180, -60, -180)
  lg.line(90, -40, 110, -40, 110, -200)
  -- chimney steam
  for i = 0, 3 do
    local sy = (t * (30 + 80 * heat) + i * 18) % 70
    lg.setColor(1, 1, 1, (0.35 + heat * 0.3) * (1 - sy / 70))
    lg.circle("fill", 110 + math.sin(t * 2 + i) * 6, -206 - sy, 6 + sy / 6)
  end
  -- base
  lg.setColor(0.3, 0.27, 0.42)
  D.rrect("fill", -95, -72, 190, 72, 10)
  lg.setColor(0.22, 0.2, 0.32)
  lg.rectangle("fill", -95, -18, 190, 8)
  -- dials
  for i = 0, 2 do
    local dx = -55 + i * 55
    lg.setColor(0.95, 0.92, 0.85)
    lg.circle("fill", dx, -45, 15)
    lg.setColor(0.8, 0.2, 0.2)
    lg.setLineWidth(3)
    local a = -PI * 0.8 + (0.3 + 0.5 * heat + 0.15 * math.sin(t * (2 + i) + i)) * PI * 1.6
    lg.line(dx, -45, dx + math.cos(a) * 11, -45 + math.sin(a) * 11)
  end
  for i = 0, 4 do
    local on = math.sin(t * (3 + i) + i * 2) > 0
    if on then col(i % 2 == 0 and T.c.good or T.c.pink) else lg.setColor(0.2, 0.2, 0.25) end
    lg.circle("fill", -70 + i * 35, -10 + 4, 4)
  end
  -- dome
  local cy, R = -140, 72
  lg.setColor(0.6, 0.8, 1, 0.12)
  lg.circle("fill", 0, cy, R)
  lg.stencil(function() lg.circle("fill", 0, cy, R - 4) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  local level = cy + R * 0.05 + math.sin(t * 3) * 3 * (1 + heat * 2)
  col(liquid, 0.9)
  lg.rectangle("fill", -R, level, R * 2, R * 2)
  col(D.mix(liquid, { 1, 1, 1 }, 0.4), 0.8)
  lg.ellipse("fill", 0, level, R, 6)
  local nb = 6 + math.floor(heat * 14)
  for i = 1, nb do
    local bx = math.sin(i * 12.9898) * R * 0.7
    local sp = 20 + (i % 5) * 8 + heat * 60
    local by = cy + R - ((t * sp + i * 17) % (R * 1.1))
    if by > level then
      col(D.mix(liquid, { 1, 1, 1 }, 0.6), 0.8)
      lg.circle("fill", bx + math.sin(t * 3 + i) * 4, by, 3 + (i % 3) * 2)
    end
  end
  lg.setStencilTest()
  lg.setColor(1, 1, 1, 0.35)
  lg.setLineWidth(4)
  lg.arc("line", "open", 0, cy, R - 12, PI * 1.15, PI * 1.45)
  lg.setColor(0.55, 0.52, 0.66)
  lg.setLineWidth(6)
  lg.circle("line", 0, cy, R)
  lg.setColor(0.4, 0.38, 0.52)
  D.rrect("fill", -R - 6, cy - R - 10, (R + 6) * 2, 16, 6)
  D.rrect("fill", -40, -78, 80, 16, 4)
  lg.pop()
end

-- CHEF (top-down, for foraging) ----------------------------------------------------------------
function A.chef(x, y, t, moving, dir, stunned)
  lg.push()
  lg.translate(x, y)
  local wob = moving and math.sin(t * 18) * 3 or 0
  lg.setColor(0, 0, 0, 0.3)
  lg.ellipse("fill", 0, 22, 20, 7)
  if stunned then lg.rotate(math.sin(t * 30) * 0.3) end
  -- feet
  lg.setColor(0.25, 0.2, 0.3)
  lg.ellipse("fill", -8, 18 + wob * 0.5, 6, 4)
  lg.ellipse("fill", 8, 18 - wob * 0.5, 6, 4)
  -- body
  col(T.c.orange)
  lg.ellipse("fill", 0, 4, 17, 16)
  lg.setColor(1, 1, 1)
  lg.ellipse("fill", 0, 8, 10, 10)
  -- arms
  lg.setColor(1, 0.8, 0.62)
  lg.circle("fill", -17, 4 + wob, 5)
  lg.circle("fill", 17, 4 - wob, 5)
  -- head
  lg.circle("fill", 0, -14, 11)
  lg.setColor(0.1, 0.1, 0.1)
  lg.circle("fill", -4 + dir * 2, -14, 2)
  lg.circle("fill", 4 + dir * 2, -14, 2)
  -- hat
  lg.setColor(1, 1, 1)
  lg.rectangle("fill", -9, -26, 18, 6)
  lg.circle("fill", -6, -31, 7)
  lg.circle("fill", 6, -31, 7)
  lg.circle("fill", 0, -35, 8)
  if stunned then
    col(T.c.gold)
    for i = 0, 2 do
      local a = t * 6 + i * 2.1
      D.star(math.cos(a) * 20, -44 + math.sin(a) * 6, 5, 1)
    end
  end
  lg.pop()
end

-- FORM DRONE (bureaucratic hazard) -------------------------------------------------------------
function A.drone(x, y, t)
  lg.push()
  lg.translate(x, y + math.sin(t * 4) * 4)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 36, 18, 5)
  lg.setColor(0.5, 0.5, 0.55)
  lg.rectangle("fill", -2, -36, 4, 10)
  local pw = math.abs(math.sin(t * 40)) * 22
  lg.setColor(0.8, 0.8, 0.85, 0.8)
  lg.ellipse("fill", 0, -36, pw + 4, 3)
  lg.setColor(0.55, 0.38, 0.22)
  D.rrect("fill", -18, -26, 36, 46, 4)
  lg.setColor(0.97, 0.95, 0.88)
  lg.rectangle("fill", -14, -18, 28, 34)
  lg.setColor(0.6, 0.6, 0.7)
  lg.rectangle("fill", -8, -29, 16, 6)
  lg.setColor(0.5, 0.5, 0.6)
  for i = 0, 3 do lg.line(-10, -4 + i * 5, 10, -4 + i * 5) end
  lg.setColor(1, 1, 1)
  lg.circle("fill", 0, -10, 6)
  lg.setColor(0.8, 0.1, 0.1)
  lg.circle("fill", 1, -10, 3)
  lg.setColor(0.8, 0.15, 0.15)
  lg.setFont(T.font(9))
  lg.printf("FORM", -14, 14, 28, "center")
  lg.pop()
end

-- PLANET (space view) --------------------------------------------------------------------------
function A.planet(x, y, r, p, t)
  local function ring(a1, a2, alpha)
    lg.push()
    lg.translate(x, y)
    lg.rotate(-0.25)
    lg.scale(1, 0.28)
    lg.setColor(p.accent[1], p.accent[2], p.accent[3], alpha)
    lg.setLineWidth(r * 0.14)
    lg.arc("line", "open", 0, 0, r * 1.6, a1, a2)
    lg.pop()
  end
  if p.ringed then ring(PI, 2 * PI, 0.45) end
  col(p.ground)
  lg.circle("fill", x, y, r)
  lg.stencil(function() lg.circle("fill", x, y, r) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  col(p.sky, 0.6)
  for i = -2, 2 do
    lg.ellipse("fill", x + math.sin(t * 0.3 + i) * r * 0.1, y + i * r * 0.38, r * 1.2, r * 0.1)
  end
  lg.setColor(0, 0, 0, 0.45)
  lg.circle("fill", x + r * 0.45, y + r * 0.3, r * 0.95)
  lg.setStencilTest()
  if p.ringed then ring(0, PI, 0.8) end
end

-- RIDES ----------------------------------------------------------------------------------------
function A.freighter(x, y, s, t)
  lg.push()
  lg.translate(x, y)
  lg.scale(s)
  -- engines at the back (right, since it flies left)
  for i = -1, 1 do
    local fl = 30 + love.math.random() * 15
    lg.setColor(0.4, 0.8, 1, 0.8)
    lg.polygon("fill", 110, i * 18 - 6, 110, i * 18 + 6, 110 + fl, i * 18)
  end
  local pts = { -110, 0, -80, -36, -20, -50, 40, -44, 100, -30, 116, 10, 80, 40, 0, 48, -70, 36 }
  lg.setColor(0.45, 0.4, 0.38)
  lg.polygon("fill", pts)
  lg.setColor(0.35, 0.3, 0.3)
  lg.circle("fill", -40, 10, 14)
  lg.circle("fill", 30, 20, 10)
  lg.circle("fill", 60, -20, 8)
  local cc = { { 0.9, 0.3, 0.3 }, { 0.3, 0.6, 0.9 }, { 0.9, 0.75, 0.2 }, { 0.3, 0.8, 0.5 } }
  for i = 1, 4 do
    col(cc[i])
    lg.rectangle("fill", -70 + i * 30, -70, 26, 22)
  end
  lg.setColor(0.8, 0.85, 0.9)
  D.rrect("fill", -100, -30, 30, 18, 6)
  lg.setColor(1, 1, 0.6, (math.sin(t * 4) > 0) and 1 or 0.3)
  lg.circle("fill", -108, 0, 4)
  lg.pop()
end

function A.wormhole(x, y, s, t)
  lg.push()
  lg.translate(x, y)
  lg.scale(s)
  for i = 8, 1, -1 do
    local k = i / 8
    local hue = (t * 0.2 + k) % 1
    local c = { 0.5 + 0.5 * math.sin(hue * 6.28), 0.5 + 0.5 * math.sin(hue * 6.28 + 2), 0.5 + 0.5 * math.sin(hue * 6.28 + 4) }
    col(c, 0.25 + 0.5 * (1 - k))
    lg.push()
    lg.rotate(t * (0.5 + k))
    lg.ellipse("fill", 0, 0, 90 * k, 60 * k)
    lg.pop()
  end
  lg.setColor(0, 0, 0)
  lg.ellipse("fill", 0, 0, 14, 10)
  lg.pop()
end

function A.barge(x, y, s, t)
  lg.push()
  lg.translate(x, y)
  lg.scale(s)
  lg.setColor(0.45, 0.6, 0.3, 0.8)
  for i = -1, 1, 2 do lg.polygon("fill", 100, i * 20 - 6, 100, i * 20 + 6, 130 + love.math.random() * 10, i * 20) end
  lg.setColor(0.62, 0.66, 0.38)
  lg.rectangle("fill", -100, -30, 200, 60)
  lg.rectangle("fill", -60, -60, 110, 32)
  lg.rectangle("fill", -20, -84, 40, 26)
  lg.setColor(0.5, 0.52, 0.3)
  lg.rectangle("fill", -100, 20, 200, 10)
  lg.setColor(1, 0.95, 0.6)
  for i = 0, 5 do lg.rectangle("fill", -86 + i * 30, -14, 14, 10) end
  -- loudspeakers for the poetry
  lg.setColor(0.4, 0.4, 0.45)
  lg.polygon("fill", -100, -20, -130, -40, -130, 10, -100, -6)
  lg.setColor(1, 1, 1, 0.5 + 0.5 * math.sin(t * 8))
  lg.setLineWidth(2)
  for i = 1, 3 do lg.arc("line", "open", -132, -15, 8 * i, PI * 0.7, PI * 1.3) end
  lg.pop()
end

return A
