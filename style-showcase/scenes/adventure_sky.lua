-- ADVENTURE, scene 3: sky islands and a little mail airship.
--
-- Floating islands are one recipe run several times: a noise-jagged rock underside that
-- tapers to a point, a grassy cap, and whatever sits on top (pines, a windmill, a
-- lighthouse). Distance is faked by scale plus tinting toward the sky colour. Clouds
-- are clumps of circles with a lighter top and a shaded belly, sorted by depth together
-- with the islands and the airship, so the ship really flies behind and in front of
-- things as it follows the mouse.

local gfx = require("core.gfx")
local view = require("core.view")
local deep = require("deep")
local Vector = require("brinevector")

local lg = love.graphics

local S = {
  title = "Adventure",
  subtitle = "The Floating Isles",
  blurb = "Sky islands, waterfalls into the clouds, rope bridges and a mail airship that follows your mouse through depth-sorted clouds.",
  techniques = {
    "One island recipe: jagged tapering rock (noise) + grass cap + props, at any scale",
    "Atmospheric perspective: far islands are smaller and tinted toward the sky",
    "Clouds: circle clumps drawn twice (shaded belly, bright top)",
    "Everything is queued by depth, so the airship passes behind and in front",
    "Airship steering: velocity eases toward the target; tilt follows vertical speed",
    "Rope bridge: a sagging parabola with planks along it",
  },
  libs = {
    "deep: z-ordered draw queue for clouds, islands and the airship",
    "brinevector: airship position / velocity maths",
  },
  genres = { "Open-sky exploration and trading games", "Flight and delivery games", "JRPG world maps", "Cozy adventure" },
  controls = "move the mouse: the airship follows it. Fly low or high to pass in front of or behind the clouds.",
  warmup = 3,
}

local SKY = gfx.rgb("#9fd4f2")

-- Build one island: returns a table with polygons relative to (0,0) = centre of the top.
local function makeIsland(w, depth, seed)
  local I = { w = w, depth = depth, seed = seed, rock = {}, grass = {} }
  local n = 26
  -- underside: a ragged profile whose depth peaks near the middle
  local top, bottom = {}, {}
  for i = 0, n do
    local u = i / n
    local x = (u - 0.5) * w
    local shape = math.sin(u * math.pi) ^ 0.75
    local jag = 0.55 + gfx.fbm(u * 5 + seed, seed, 3) * 0.9
    top[#top + 1] = { x, 0 }
    bottom[#bottom + 1] = { x + (gfx.hash(i + seed) - 0.5) * 8, shape * depth * jag }
  end
  I.top, I.bottom = top, bottom
  return I
end

local function drawIsland(I, tintAmount, t)
  local function c(hex) return gfx.mix(gfx.rgb(hex), SKY, tintAmount) end
  local n = #I.top
  -- rock in vertical slices, alternating two tones so it reads as faceted stone
  for i = 1, n - 1 do
    local a, b, c1, d = I.top[i], I.top[i + 1], I.bottom[i + 1], I.bottom[i]
    local shade = gfx.hash(i * 3 + I.seed)
    lg.setColor(gfx.mix(c("#8a6f5a"), c("#5f4a44"), shade * 0.7 + (i / n) * 0.3))
    lg.polygon("fill", a[1], a[2], b[1], b[2], c1[1], c1[2], d[1], d[2])
  end
  -- strata bands
  lg.setColor(c("#a88868"))
  for i = 1, n - 1 do
    local a, b = I.bottom[i], I.bottom[i + 1]
    local y1, y2 = a[2] * 0.36, b[2] * 0.36
    lg.polygon("fill", I.top[i][1], y1, I.top[i + 1][1], y2, I.top[i + 1][1], y2 + 5, I.top[i][1], y1 + 5)
  end
  -- hanging roots / drips under the edge
  lg.setColor(c("#4f8a3f"))
  for i = 2, n - 1, 3 do
    local x = I.top[i][1]
    lg.setLineWidth(2)
    lg.line(x, 4, x + math.sin(t + i) * 2, 14 + gfx.hash(i + I.seed) * 22)
  end
  -- grass cap: a slab with a scalloped lower edge and a lighter top
  lg.setColor(c("#4f9a48"))
  lg.rectangle("fill", -I.w / 2 - 4, -8, I.w + 8, 16, 8)
  for i = 1, n - 1, 1 do
    lg.circle("fill", I.top[i][1] + 6, 8, 7 + gfx.hash(i + I.seed * 2) * 5)
  end
  lg.setColor(c("#7fc85a"))
  lg.rectangle("fill", -I.w / 2 - 2, -10, I.w + 4, 9, 5)
end

local function pine(x, y, h, tintAmount, sway)
  local function c(hex) return gfx.mix(gfx.rgb(hex), SKY, tintAmount) end
  lg.setColor(c("#5a3f2a"))
  lg.rectangle("fill", x - 3, y - h * 0.25, 6, h * 0.25)
  for k = 0, 2 do
    local yy = y - h * 0.2 - k * h * 0.26
    local hw = h * (0.3 - k * 0.07)
    lg.setColor(c(k == 2 and "#3f8f52" or "#2f7a46"))
    lg.polygon("fill", x - hw, yy, x + hw, yy, x + sway * (k + 1), yy - h * 0.36)
  end
end

local function cloud(x, y, s, seed, alpha)
  local n = 7
  -- shaded belly first, then the bright tops slightly higher
  for pass = 1, 2 do
    for i = 0, n do
      local u = i / n
      local r = (18 + math.sin(u * math.pi) * 34 * (0.7 + gfx.hash(i + seed) * 0.6)) * s
      local cx = x + (u - 0.5) * 190 * s
      if pass == 1 then
        lg.setColor(0.78, 0.86, 0.95, alpha)
        lg.circle("fill", cx, y + 6 * s, r)
      else
        lg.setColor(1, 1, 1, alpha)
        lg.circle("fill", cx - 3 * s, y - 5 * s, r * 0.9)
      end
    end
  end
  lg.setColor(0.78, 0.86, 0.95, alpha)
  lg.rectangle("fill", x - 100 * s, y + 12 * s, 200 * s, 18 * s, 9 * s)
end

function S:load()
  self.t = 0
  self.q = deep:new()
  self.glow = gfx.radialTexture(128, 2)
  self.font = lg.newFont(16)
  self.small = lg.newFont(13)
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#3f8fd8") }, { 0.5, gfx.rgb("#8fcbf0") }, { 0.85, gfx.rgb("#d8f0f8") }, { 1, gfx.rgb("#fff4d8") },
  })
  self.ray = lg.newMesh({
    { 0, 0, 0, 0, 1, 1, 0.85, 0.3 }, { 1, -0.08, 0, 0, 1, 1, 0.85, 0 }, { 1, 0.08, 0, 0, 1, 1, 0.85, 0 },
  }, "fan", "static")
  -- islands: x, y, scale, tint, depth z (bigger z = nearer)
  self.islands = {
    { I = makeIsland(150, 110, 7), x = 180, y = 250, s = 0.5, tint = 0.6, z = 2, kind = "pines" },
    { I = makeIsland(170, 130, 23), x = 1090, y = 210, s = 0.55, tint = 0.55, z = 2, kind = "tower" },
    { I = makeIsland(130, 100, 41), x = 640, y = 180, s = 0.36, tint = 0.72, z = 1, kind = "pines" },
    { I = makeIsland(380, 230, 3), x = 330, y = 440, s = 1, tint = 0, z = 6, kind = "village" },
    { I = makeIsland(260, 190, 15), x = 930, y = 400, s = 0.9, tint = 0.12, z = 5, kind = "windmill" },
  }
  love.math.setRandomSeed(4)
  self.clouds = {}
  for i = 1, 13 do
    local z = (i % 4 == 0) and 8 or ((i % 3 == 0) and 4 or 3)
    self.clouds[i] = {
      x = love.math.random(-200, 1400), y = (z == 8) and love.math.random(560, 700) or love.math.random(90, 600),
      s = (z == 8) and 1.7 + love.math.random() or 0.5 + love.math.random() * 0.7,
      v = (z == 8) and 26 or 6 + love.math.random() * 10, seed = i * 13, z = z,
    }
  end
  self.ship = { pos = Vector(470, 280), vel = Vector(0, 0), face = 1 }
  self.gulls = {}
  for i = 1, 5 do self.gulls[i] = { x = 400 + i * 40, y = 120 + (i % 2) * 18 + i * 6, p = i } end
end

function S:update(dt)
  self.t = self.t + dt
  for _, c in ipairs(self.clouds) do
    c.x = c.x + c.v * dt
    if c.x > 1500 then c.x = -300 end
  end
  -- airship: accelerate toward the mouse (or wander when the mouse is idle/away)
  local mx, my = view.mouse()
  local target
  if mx and mx > 0 and mx < 1280 and my > 0 and my < 720 and (mx ~= self.lastMx or self.mouseSeen) then
    if self.lastMx and mx ~= self.lastMx then self.mouseSeen = true end
    target = self.mouseSeen and Vector(mx, my) or nil
  end
  self.lastMx = mx
  if not target then
    target = Vector(560 + math.sin(self.t * 0.35 + 2.5) * 260, 300 + math.sin(self.t * 0.6 + 2) * 60)
  end
  local s = self.ship
  local desired = (target - s.pos) * 1.4
  s.vel = s.vel + (desired - s.vel) * math.min(1, dt * 1.6)
  s.pos = s.pos + s.vel * dt
  if math.abs(s.vel.x) > 12 then s.face = s.vel.x > 0 and 1 or -1 end
  for _, g in ipairs(self.gulls) do
    g.x = g.x + 34 * dt
    if g.x > 1340 then g.x = -60 end
  end
end

function S:drawProps(isl)
  local t = self.t
  local w = isl.I.w
  local tintA = isl.tint
  local function c(hex) return gfx.mix(gfx.rgb(hex), SKY, tintA) end
  local sway = math.sin(t * 1.2 + isl.x) * 1.5
  if isl.kind == "pines" then
    pine(-w * 0.25, -8, 70, tintA, sway)
    pine(w * 0.05, -8, 96, tintA, sway)
    pine(w * 0.3, -8, 60, tintA, sway)
  elseif isl.kind == "tower" then
    lg.setColor(c("#d8d0c0"))
    lg.polygon("fill", -16, -8, 16, -8, 11, -110, -11, -110)
    lg.setColor(c("#c8463a"))
    lg.polygon("fill", -18, -110, 18, -110, 0, -146)
    lg.rectangle("fill", -13, -70, 26, 10)
    lg.setColor(c("#fff2a8"))
    lg.rectangle("fill", -5, -104, 10, 14)
    pine(-w * 0.32, -8, 60, tintA, sway)
    pine(w * 0.3, -8, 74, tintA, sway)
  elseif isl.kind == "windmill" then
    pine(-w * 0.36, -8, 84, tintA, sway)
    pine(-w * 0.22, -8, 64, tintA, sway)
    -- mill body, cap and door
    lg.setColor(c("#efe6d2"))
    lg.polygon("fill", 20, -8, 76, -8, 66, -104, 30, -104)
    lg.setColor(c("#d8ccb2"))
    lg.polygon("fill", 56, -8, 76, -8, 66, -104, 56, -104)
    lg.setColor(c("#a8463a"))
    lg.polygon("fill", 24, -104, 72, -104, 48, -134)
    lg.setColor(c("#6a4a2a"))
    lg.rectangle("fill", 41, -32, 14, 24, 6)
    lg.setColor(c("#7fb8d8"))
    lg.rectangle("fill", 42, -74, 12, 14)
    -- sails
    lg.push()
    lg.translate(48, -108)
    lg.rotate(t * 0.9)
    for k = 0, 3 do
      lg.rotate(math.pi / 2)
      lg.setColor(c("#6a4a2a"))
      lg.rectangle("fill", -2, 0, 4, 78)
      lg.setColor(c("#f8f0dc"))
      lg.polygon("fill", 3, 16, 22, 20, 22, 74, 3, 76)
      lg.setColor(c("#c8b890"))
      for j = 0, 3 do lg.rectangle("fill", 3, 28 + j * 13, 19, 1.5) end
    end
    lg.pop()
    lg.setColor(c("#4a3424"))
    lg.circle("fill", 48, -108, 5)
    -- a signpost and a fence
    lg.setColor(c("#8a6a44"))
    for k = 0, 4 do lg.rectangle("fill", 86 + k * 9, -24, 3, 16) end
    lg.rectangle("fill", 84, -20, 42, 3)
  elseif isl.kind == "village" then
    pine(-w * 0.42, -8, 92, tintA, sway)
    pine(-w * 0.33, -8, 66, tintA, sway)
    pine(w * 0.4, -8, 78, tintA, sway)
    -- three cottages with steep roofs and lit windows
    local houses = { { -78, 54, 48, "#c8563a" }, { -14, 66, 62, "#3f7fa8" }, { 60, 50, 44, "#d89a3a" } }
    for _, h in ipairs(houses) do
      local x, hw, hh = h[1], h[2], h[3]
      lg.setColor(c("#f2e8d2"))
      lg.rectangle("fill", x, -8 - hh, hw, hh)
      lg.setColor(c("#d8ccb2"))
      lg.rectangle("fill", x + hw * 0.7, -8 - hh, hw * 0.3, hh)
      lg.setColor(c(h[4]))
      lg.polygon("fill", x - 7, -8 - hh, x + hw + 7, -8 - hh, x + hw / 2, -8 - hh - hw * 0.62)
      lg.setColor(c("#6a4a2a"))
      lg.rectangle("fill", x + hw * 0.4, -30, 12, 22, 5)
      lg.setColor(c("#ffe89a"))
      lg.rectangle("fill", x + 7, -8 - hh + 10, 10, 10)
      lg.setColor(c("#8a6a55"))
      lg.rectangle("fill", x + hw * 0.7, -8 - hh - hw * 0.5, 8, 20)
    end
    -- chimney smoke
    for k = 0, 4 do
      local u = ((t * 0.3 + k / 5) % 1)
      lg.setColor(1, 1, 1, 0.5 * (1 - u))
      lg.circle("fill", 36 + math.sin(t + k) * 4 + u * 20, -110 - u * 60, 5 + u * 10)
    end
    -- a waterfall spilling off the right edge, turning to mist
    lg.setColor(c("#8fd8f0"))
    lg.polygon("fill", 150, -8, 176, -8, 196, 12, 188, 12)
    for k = 0, 9 do
      local y = 12 + ((t * 180 + k * 31) % 300)
      lg.setColor(0.8, 0.95, 1, 0.75 * (1 - (y - 12) / 300))
      lg.rectangle("fill", 186 + (k % 4) * 3, y, 3, 26)
    end
    lg.setColor(0.8, 0.95, 1, 0.5)
    lg.polygon("fill", 186, 12, 198, 12, 204, 300, 180, 300)
    -- dock for the airship: a little pier with a mooring mast
    lg.setColor(c("#8a6a44"))
    lg.rectangle("fill", -220, -12, 46, 6)
    lg.rectangle("fill", -214, -64, 4, 54)
    lg.setColor(c("#e2442f"))
    lg.polygon("fill", -210, -64, -188, -57 + math.sin(t * 4) * 2, -210, -50)
  end
end

function S:drawShip()
  local s = self.ship
  local t = self.t
  local tilt = gfx.clamp(s.vel.y * 0.0012, -0.2, 0.2) * s.face
  lg.push()
  lg.translate(s.pos.x, s.pos.y + math.sin(t * 1.6) * 4)
  lg.scale(s.face, 1)
  lg.rotate(tilt)
  -- tail fins
  lg.setColor(gfx.hex("#c8463a"))
  lg.polygon("fill", -70, -52, -104, -84, -100, -44)
  lg.polygon("fill", -70, -36, -104, -6, -100, -44)
  -- envelope: an ellipse built from gores (stripes), darker underneath
  local stripes = { "#f2e3c0", "#e2553f", "#f2e3c0", "#e2553f", "#f2e3c0", "#e2553f", "#f2e3c0" }
  lg.setColor(gfx.hex("#b84232"))
  lg.ellipse("fill", 0, -44, 92, 38)
  for i, col in ipairs(stripes) do
    local u1, u2 = (i - 1) / #stripes, i / #stripes
    local pts = {}
    for k = 0, 12 do
      local a = math.pi + k / 12 * math.pi
      local w = gfx.lerp(u1, u2, 0) * 2 - 1
      pts[#pts + 1] = math.cos(a) * 92 * 1
      pts[#pts + 1] = -44 + math.sin(a) * 38
    end
    local x1, x2 = -92 + u1 * 184, -92 + u2 * 184
    lg.setColor(gfx.hex(col))
    -- clip each gore to the ellipse by sampling its top and bottom edge
    local poly = {}
    for k = 0, 6 do
      local x = gfx.lerp(x1, x2, k / 6)
      poly[#poly + 1] = x
      poly[#poly + 1] = -44 - 38 * math.sqrt(math.max(0, 1 - (x / 92) ^ 2))
    end
    for k = 6, 0, -1 do
      local x = gfx.lerp(x1, x2, k / 6)
      poly[#poly + 1] = x
      poly[#poly + 1] = -44 + 20 * math.sqrt(math.max(0, 1 - (x / 92) ^ 2))
    end
    if #poly >= 6 then pcall(lg.polygon, "fill", poly) end
  end
  lg.setColor(1, 1, 1, 0.35)
  lg.ellipse("fill", 8, -64, 58, 9)
  -- nose cone and ropes
  lg.setColor(gfx.hex("#8a6a44"))
  lg.circle("fill", 92, -44, 6)
  lg.setColor(gfx.hex("#5a4632"))
  lg.setLineWidth(1.6)
  for _, x in ipairs({ -50, -18, 18, 50 }) do
    lg.line(x, -44 + 30 * math.sqrt(1 - (x / 92) ^ 2), x * 0.62, 10)
  end
  -- gondola: a little wooden boat hull with windows and a mail flag
  lg.setColor(gfx.hex("#8a5a34"))
  lg.polygon("fill", -40, 8, 44, 8, 34, 32, -30, 32)
  lg.setColor(gfx.hex("#a8703f"))
  lg.rectangle("fill", -42, 6, 88, 7, 3)
  lg.setColor(gfx.hex("#ffe89a"))
  for k = 0, 2 do lg.circle("fill", -18 + k * 20, 20, 5) end
  lg.setColor(gfx.hex("#5a3a22"))
  for k = 0, 2 do lg.circle("line", -18 + k * 20, 20, 5) end
  -- the pilot's head and scarf
  lg.setColor(gfx.hex("#e0b08a"))
  lg.circle("fill", 26, 0, 7)
  lg.setColor(gfx.hex("#5a4632"))
  lg.arc("fill", 26, -1, 8, math.pi, math.pi * 2)
  lg.setColor(gfx.hex("#3f7fd0"))
  lg.polygon("fill", 22, 5, 2 - math.sin(t * 6) * 3, 2 + math.sin(t * 7) * 3, 4, 9)
  -- propeller at the stern: a blurred disc and two blades
  lg.setColor(gfx.hex("#5a4632"))
  lg.rectangle("fill", -52, 16, 14, 5)
  lg.setColor(1, 1, 1, 0.3)
  lg.ellipse("fill", -54, 18, 4, 20)
  lg.setColor(gfx.hex("#3a2a1e"))
  local ph = math.sin(t * 30)
  lg.ellipse("fill", -54, 18, 3, 20 * math.abs(ph) + 2)
  -- mail sack hanging below
  lg.setColor(gfx.hex("#c9b27a"))
  lg.setLineWidth(1.5)
  lg.line(0, 32, math.sin(t * 2) * 3, 46)
  lg.ellipse("fill", math.sin(t * 2) * 3, 54, 9, 10)
  lg.pop()
end

function S:drawBridge(x1, y1, x2, y2)
  local n = 22
  local pts = {}
  for i = 0, n do
    local u = i / n
    local sag = math.sin(u * math.pi) * 40 + math.sin(self.t * 1.3 + u * 6) * 1.5
    pts[#pts + 1] = gfx.lerp(x1, x2, u)
    pts[#pts + 1] = gfx.lerp(y1, y2, u) + sag
  end
  lg.setColor(gfx.hex("#6a4a2a"))
  for i = 1, #pts - 2, 2 do
    lg.setLineWidth(5)
    lg.line(pts[i] + 2, pts[i + 1], pts[i + 2] - 2, pts[i + 3])
    lg.setLineWidth(1.5)
    lg.line(pts[i], pts[i + 1], pts[i], pts[i + 1] - 20)
  end
  local rail = {}
  for i = 1, #pts, 2 do rail[#rail + 1] = pts[i] rail[#rail + 1] = pts[i + 1] - 20 end
  lg.setLineWidth(2)
  lg.line(rail)
end

function S:draw()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  -- sun with slowly turning rays
  lg.setBlendMode("add")
  for k = 0, 11 do
    lg.push()
    lg.translate(1040, 110)
    lg.rotate(k / 12 * math.pi * 2 + t * 0.05)
    lg.scale(520, 520)
    lg.setColor(1, 1, 1, 0.5)
    lg.draw(self.ray)
    lg.pop()
  end
  lg.setColor(1, 0.98, 0.8, 0.9)
  lg.draw(self.glow, 1040, 110, 0, 3.4, 3.4, 64, 64)
  lg.setBlendMode("alpha")
  lg.setColor(1, 1, 0.92)
  lg.circle("fill", 1040, 110, 40)

  local q = self.q
  for _, c in ipairs(self.clouds) do
    q:queue(c.z * 2, function() cloud(c.x, c.y, c.s, c.seed, c.z == 8 and 0.92 or 0.95) end)
  end
  for _, isl in ipairs(self.islands) do
    q:queue(isl.z * 2, function()
      lg.push()
      lg.translate(isl.x, isl.y + math.sin(t * 0.6 + isl.x) * 5)
      lg.scale(isl.s)
      self:drawProps(isl)
      drawIsland(isl.I, isl.tint, t)
      lg.pop()
    end)
  end
  -- rope bridge between the two near islands (queued just in front of them)
  q:queue(12, function()
    local a, b = self.islands[4], self.islands[5]
    self:drawBridge(a.x + 196, a.y - 6 + math.sin(t * 0.6 + a.x) * 5, b.x - 120, b.y - 6 + math.sin(t * 0.6 + b.x) * 5)
  end)
  -- the airship's depth depends on how low it flies: low = near, high = far
  local s = self.ship
  local z = (s.pos.y > 430) and 14 or ((s.pos.y > 260) and 9 or 5)   -- deep wants whole numbers
  q:queue(z, function() self:drawShip() end)
  q:queue(3, function()
    for _, g in ipairs(self.gulls) do
      local flap = math.sin(t * 6 + g.p) * 7
      lg.setColor(1, 1, 1, 0.9)
      lg.setLineWidth(2.5)
      lg.line(g.x - 10, g.y - flap, g.x, g.y, g.x + 10, g.y - flap)
    end
  end)
  q:draw()

  -- quest card
  lg.setColor(0.1, 0.2, 0.32, 0.72)
  lg.rectangle("fill", 24, 620, 330, 62, 10)
  lg.setColor(gfx.hex("#ffe89a"))
  lg.setFont(self.small)
  lg.print("MAIL RUN", 44, 630)
  lg.setColor(1, 1, 1)
  lg.setFont(self.font)
  lg.print("Deliver 3 letters to Windrest Mill", 44, 650)
  -- altitude gauge on the right
  lg.setColor(0.1, 0.2, 0.32, 0.72)
  lg.rectangle("fill", 1216, 260, 36, 220, 10)
  lg.setColor(1, 1, 1, 0.5)
  for k = 0, 8 do lg.rectangle("fill", 1226, 276 + k * 23.5, (k % 2 == 0) and 16 or 9, 2) end
  local ay = gfx.clamp(276 + (s.pos.y / 720) * 188, 270, 470)
  lg.setColor(gfx.hex("#ffe89a"))
  lg.polygon("fill", 1212, ay, 1226, ay - 7, 1226, ay + 7)
end

return S
