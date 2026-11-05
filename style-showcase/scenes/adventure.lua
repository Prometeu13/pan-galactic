-- ADVENTURE: a storybook vista that scrolls forever, with RPG-style dialogue.
--
-- Depth comes from parallax: each layer moves at a different fraction of the camera's
-- speed, and farther layers are tinted toward the sky colour (atmospheric perspective).
-- The world is infinite but costs no memory: trees, rocks and castles are placed by
-- hashing their grid position, so the same spot always produces the same thing.

local gfx = require("core.gfx")
local Camera = require("hump.camera")
local Timer = require("hump.timer")
local parallax = require("parallax")
local Text = require("slog-text")

local lg = love.graphics

local S = {
  title = "Adventure",
  subtitle = "The Road to Highspire",
  blurb = "A side-scrolling storybook world with 5 parallax layers, a walking hero and animated RPG dialogue.",
  techniques = {
    "5 parallax layers (0.08x to 1.35x camera speed) tinted toward the sky with distance",
    "Infinite world: objects placed with a hash of their grid cell, nothing stored",
    "Procedural walk cycle: limbs swing on sine waves, the cape trails behind",
    "Typewriter dialogue with inline effects: [bounce], [shake], [color]",
    "Quest tracker and dialogue frame are plain rectangles, lines and text",
  },
  libs = {
    "hump.camera: the camera the whole world follows",
    "love-parallax: draws each layer at its own depth relative to the camera",
    "SYSL-Text: typewriter text with bounce/shake/colour tags",
    "hump.timer: cycles the dialogue lines and spawns bird flocks",
  },
  genres = { "Action-adventure and Zelda-likes", "Side-scrolling RPGs and metroidvanias", "Story-driven exploration games", "Auto-runners with a narrative" },
  warmup = 7,
}

local SKY_LOW = { gfx.hex("#ffd9a8") }
local GROUND_Y = 560

local LINES = {
  "[dropshadow=2][color=#ffd36e]Ranger Maelis:[/color][/dropshadow] The road to [color=#ffcc33][bounce]Highspire[/bounce][/color] winds past the [shake]Whispering Pass[/shake]. Keep your torch lit, traveller.",
  "[dropshadow=2][color=#ffd36e]Ranger Maelis:[/color][/dropshadow] They say the castle bells ring on their own at dusk... [pause=0.4][color=#9fd8ff][swing]probably just the wind[/swing][/color].",
  "[dropshadow=2][color=#ffd36e]Ranger Maelis:[/color][/dropshadow] Take this map. If you reach the gate, tell them [rainbow]Maelis[/rainbow] sent you!",
}

local function tint(c, amount) return gfx.mix(c, SKY_LOW, amount) end

function S:load()
  self.t = 0
  self.timer = Timer.new()
  self.cam = Camera(640, 360)
  -- love-parallax expects a camera-like table with these fields.
  self.target = { x = 640, y = 360, w2 = 640, h2 = 360, angle = 0, scale = 1 }
  self.layers = {
    far = parallax.new(self.target, 1, 0.08),
    castle = parallax.new(self.target, 1, 0.22),
    hills = parallax.new(self.target, 1, 0.45),
    ground = parallax.new(self.target, 1, 1.0),
    front = parallax.new(self.target, 1, 1.35),
  }
  -- love-parallax scrolls Y too. Our camera never moves vertically, so cancel that out:
  -- with this offset, a layer's world y equals its screen y.
  for _, layer in pairs(self.layers) do
    layer.offsetY = -self.target.h2 + self.target.y * layer.speed
  end
  self.sky = gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#5aa7e0") }, { 0.45, gfx.rgb("#a9d4ef") }, { 0.75, SKY_LOW }, { 1, SKY_LOW },
  })
  self.glow = gfx.radialTexture(128, 2)

  self.font = lg.newFont(19)
  self.small = lg.newFont(14)
  self.textbox = Text.new("left", { color = { 0.96, 0.92, 0.82, 1 }, shadow_color = { 0, 0, 0, 0.6 }, font = self.font, print_speed = 0.03, adjust_line_height = 4 })
  self.line = 1
  self.textbox:send(LINES[1], 640, false)
  self.timer:every(8, function()
    self.line = self.line % #LINES + 1
    self.textbox:send(LINES[self.line], 640, false)
  end)

  self.birds = {}
  local function flock()
    local n = love.math.random(4, 7)
    local y = love.math.random(90, 220)
    for i = 1, n do
      self.birds[#self.birds + 1] = { x = -40 - i * 26, y = y + math.abs(i - n / 2) * 14, p = love.math.random() * 6, v = 70 }
    end
  end
  flock()
  for _, b in ipairs(self.birds) do b.x = b.x + 600 end
  self.timer:every(9, flock)
end

function S:update(dt)
  self.t = self.t + dt
  self.timer:update(dt)
  self.textbox:update(dt)
  self.cam:move(70 * dt, 0)
  self.target.x, self.target.y = self.cam.x, self.cam.y
  for i = #self.birds, 1, -1 do
    local b = self.birds[i]
    b.x = b.x + b.v * dt
    if b.x > 1400 then table.remove(self.birds, i) end
  end
end

-- Helpers that draw "whatever is in view" for a layer moving at `speed`.
local function visibleRange(self, speed)
  local cx = self.target.x * speed
  return cx - 700, cx + 700
end

function S:drawFar()
  local x0, x1 = visibleRange(self, 0.08)
  local c1 = tint({ gfx.hex("#6f7fb8") }, 0.35)
  local snow = tint({ 1, 1, 1 }, 0.25)
  local pts = {}
  for x = math.floor(x0 / 10) * 10, x1, 10 do
    pts[#pts + 1] = x
    pts[#pts + 1] = 560 - gfx.fbm(x * 0.0025, 0.5, 5) * 440
  end
  lg.setColor(c1)
  gfx.fillRidge(pts, 720)
  lg.setColor(snow)
  for i = 1, #pts - 2, 2 do
    local y = pts[i + 1]
    if y < 300 then
      local depth = (300 - y) * 0.5
      lg.polygon("fill", pts[i], y, pts[i + 2], pts[i + 3], pts[i + 2], pts[i + 3] + depth, pts[i], y + depth)
    end
  end
end

local function drawCastle(x, base, c)
  lg.setColor(c)
  -- cliff
  lg.polygon("fill", x - 190, 900, x - 120, base + 20, x - 60, base, x + 140, base - 10, x + 210, base + 40, x + 260, 900)
  -- walls and towers
  lg.rectangle("fill", x - 80, base - 90, 200, 90)
  for _, tx in ipairs({ -95, 20, 120 }) do
    local h = (tx == 20) and 190 or 130
    lg.rectangle("fill", x + tx, base - h, 36, h)
    lg.polygon("fill", x + tx - 8, base - h, x + tx + 18, base - h - 50, x + tx + 44, base - h)
  end
  for bx = x - 80, x + 110, 16 do lg.rectangle("fill", bx, base - 100, 9, 10) end
end

function S:drawCastleLayer()
  local x0, x1 = visibleRange(self, 0.22)
  local c = tint({ gfx.hex("#4a5a8a") }, 0.25)
  local spacing = 2400
  for i = math.floor(x0 / spacing) - 1, math.floor(x1 / spacing) + 1 do
    local x = i * spacing + 420
    -- the castle is far away: draw it at 55% size around its base point
    lg.push()
    lg.translate(x, 360)
    lg.scale(0.55)
    lg.translate(-x, -330)
    drawCastle(x, 330, c)
    -- banners on the towers flutter
    for k, tx in ipairs({ -77, 38, 138 }) do
      local h = (tx == 38) and 240 or 180
      local wave = math.sin(self.t * 4 + k) * 4
      lg.setColor(gfx.hex("#d94f4f"))
      lg.polygon("fill", x + tx, 330 - h - 26, x + tx + 28, 330 - h - 20 + wave, x + tx, 330 - h - 12)
      lg.setColor(c)
      lg.rectangle("fill", x + tx - 2, 330 - h - 30, 3, 34)
    end
    -- warm windows
    lg.setColor(1, 0.85, 0.5, 0.9)
    for _, w in ipairs({ { 30, -160 }, { 30, -120 }, { -85, -100 }, { 130, -95 } }) do
      lg.rectangle("fill", x + w[1], 330 + w[2], 8, 12, 3)
    end
    lg.pop()
  end
end

local function pine(x, y, h, c, dark)
  lg.setColor(dark)
  lg.rectangle("fill", x - 3, y - h * 0.2, 6, h * 0.25)
  lg.setColor(c)
  for i = 0, 2 do
    local w = h * (0.42 - i * 0.1)
    local top = y - h * (0.35 + i * 0.25) - h * 0.25
    lg.polygon("fill", x - w, y - h * 0.15 - i * h * 0.25, x, top, x + w, y - h * 0.15 - i * h * 0.25)
  end
end

function S:drawHills()
  local x0, x1 = visibleRange(self, 0.45)
  local c = tint({ gfx.hex("#3f7a5a") }, 0.18)
  local pts = {}
  for x = math.floor(x0 / 10) * 10, x1, 10 do
    pts[#pts + 1] = x
    pts[#pts + 1] = 500 - gfx.fbm(x * 0.003, 4.2, 3) * 120
  end
  lg.setColor(c)
  gfx.fillRidge(pts, 720)
  local cell = 34
  for i = math.floor(x0 / cell), math.floor(x1 / cell) do
    if gfx.hash(i) > 0.35 then
      local x = i * cell + gfx.hash(i + 99) * 20
      local y = 500 - gfx.fbm(x * 0.003, 4.2, 3) * 120 + 18
      pine(x, y, 60 + gfx.hash(i + 7) * 50, tint({ gfx.hex("#2f6248") }, 0.1), tint({ gfx.hex("#3b2f2a") }, 0.2))
    end
  end
end

function S:drawGround()
  local x0, x1 = visibleRange(self, 1)
  lg.setColor(gfx.hex("#6fae4f"))
  lg.rectangle("fill", x0, GROUND_Y - 30, x1 - x0, 300)
  lg.setColor(gfx.hex("#8cc463"))
  lg.rectangle("fill", x0, GROUND_Y - 30, x1 - x0, 8)
  -- dirt path
  lg.setColor(gfx.hex("#c9a46c"))
  lg.rectangle("fill", x0, GROUND_Y + 2, x1 - x0, 46)
  lg.setColor(gfx.hex("#b08a55"))
  lg.rectangle("fill", x0, GROUND_Y + 40, x1 - x0, 8)
  lg.setColor(gfx.hex("#5a9a40"))
  lg.rectangle("fill", x0, GROUND_Y + 48, x1 - x0, 200)
  local cell = 60
  for i = math.floor(x0 / cell), math.floor(x1 / cell) do
    local x = i * cell
    local h = gfx.hash(i)
    -- pebbles on the path
    lg.setColor(gfx.hex("#9c7c4e"))
    lg.ellipse("fill", x + h * 40, GROUND_Y + 14 + gfx.hash(i + 3) * 24, 5 + h * 4, 3)
    -- grass tufts and flowers
    lg.setColor(gfx.hex("#4f8a38"))
    local gx = x + gfx.hash(i + 11) * 50
    lg.polygon("fill", gx - 6, GROUND_Y - 22, gx, GROUND_Y - 42, gx + 6, GROUND_Y - 22)
    lg.polygon("fill", gx + 2, GROUND_Y - 22, gx + 12, GROUND_Y - 36, gx + 12, GROUND_Y - 22)
    if h > 0.6 then
      lg.setColor(h > 0.8 and { gfx.hex("#ffe066") } or { gfx.hex("#f28fb8") })
      lg.circle("fill", gx + 20, GROUND_Y + 80 + gfx.hash(i + 5) * 60, 4)
    end
    -- a signpost every so often
    if i % 23 == 0 then
      lg.setColor(gfx.hex("#7a5232"))
      lg.rectangle("fill", x - 4, GROUND_Y - 90, 8, 70)
      lg.polygon("fill", x - 6, GROUND_Y - 92, x + 66, GROUND_Y - 92, x + 80, GROUND_Y - 78, x + 66, GROUND_Y - 64, x - 6, GROUND_Y - 64)
      lg.setFont(self.small)
      lg.setColor(gfx.hex("#f5e6c8"))
      lg.print("Highspire", x, GROUND_Y - 87)
    end
  end
end

function S:drawHero()
  -- The hero stays at screen centre while the world scrolls past.
  local x, y = 600, GROUND_Y + 22
  local t = self.t * 7
  local bob = math.abs(math.sin(t)) * 3
  lg.push()
  lg.translate(x, y - bob)
  -- cape trails and ripples
  local w = math.sin(t * 0.8) * 6
  lg.setColor(gfx.hex("#b8322f"))
  lg.polygon("fill", -6, -62, -40 + w, -14, -30 - w, -8, 4, -58)
  -- back leg, back arm
  local swing = math.sin(t) * 0.6
  local function limb(ax, ay, angle, len, width, color)
    lg.setColor(color)
    lg.setLineWidth(width)
    lg.line(ax, ay, ax + math.sin(angle) * len, ay + math.cos(angle) * len)
  end
  limb(-2, -26, -swing, 26, 9, { gfx.hex("#4b3a2a") })
  limb(0, -56, swing * 0.8, 22, 7, { gfx.hex("#c79a72") })
  -- body
  lg.setColor(gfx.hex("#3e6fb0"))
  lg.rectangle("fill", -11, -62, 22, 38, 6)
  lg.setColor(gfx.hex("#6b4a2a"))
  lg.rectangle("fill", -12, -32, 24, 5)
  -- sword on the back
  lg.setColor(gfx.hex("#cfd8e3"))
  lg.setLineWidth(4)
  lg.line(-8, -40, 10, -78)
  lg.setColor(gfx.hex("#7a5232"))
  lg.line(6, -70, 14, -66)
  -- head with a little helm
  lg.setColor(gfx.hex("#e8b796"))
  lg.circle("fill", 2, -74, 11)
  lg.setColor(gfx.hex("#9aa6b2"))
  lg.arc("fill", 2, -76, 12, math.pi, math.pi * 2)
  lg.setColor(gfx.hex("#2a1f3d"))
  lg.circle("fill", 7, -74, 1.8)
  -- front leg, front arm
  limb(2, -26, swing, 26, 9, { gfx.hex("#5c4632") })
  limb(2, -56, -swing * 0.8, 22, 7, { gfx.hex("#e0b48a") })
  lg.pop()
  -- shadow
  lg.setColor(0, 0, 0, 0.18)
  lg.ellipse("fill", x, y + 2, 22, 5)
end

function S:drawFront()
  local x0, x1 = visibleRange(self, 1.35)
  local cell = 320
  for i = math.floor(x0 / cell), math.floor(x1 / cell) do
    if gfx.hash(i * 3.3) > 0.45 then
      -- a dark, slightly out-of-focus bush passing close to the "lens"
      local x = i * cell + gfx.hash(i) * 120
      lg.setColor(gfx.hex("#2c5a30"))
      for k = 0, 4 do
        lg.circle("fill", x + k * 34 - 70, 720 - math.sin(k / 4 * math.pi) * 40, 46 + gfx.hash(i + k) * 14)
      end
      lg.setColor(gfx.hex("#3d7a3d"))
      lg.circle("fill", x - 10, 700, 22)
    end
  end
end

function S:drawDialogue()
  local x, y, w, h = 230, 586, 820, 112
  lg.setColor(0.12, 0.08, 0.06, 0.88)
  lg.rectangle("fill", x, y, w, h, 10)
  lg.setLineWidth(3)
  lg.setColor(gfx.hex("#d9b46a"))
  lg.rectangle("line", x + 4, y + 4, w - 8, h - 8, 8)
  -- portrait: a hooded ranger, drawn with arcs and circles
  local px, py = x + 62, y + 58
  lg.setColor(gfx.hex("#2f4a35"))
  lg.circle("fill", px, py + 6, 40)
  lg.setColor(gfx.hex("#e8b796"))
  lg.circle("fill", px, py + 4, 22)
  lg.setColor(gfx.hex("#3d5e44"))
  lg.arc("fill", px, py + 2, 32, math.pi * 1.02, math.pi * 1.98)
  lg.setColor(gfx.hex("#2a1f3d"))
  lg.circle("fill", px - 8, py + 4, 2.5)
  lg.circle("fill", px + 8, py + 4, 2.5)
  lg.setColor(gfx.hex("#8a5a3a"))
  lg.arc("line", "open", px, py + 12, 7, 0.3, math.pi - 0.3)
  self.textbox:draw(x + 122, y + 16)
  -- "next" arrow bobs when the line is finished
  if self.textbox:is_finished() then
    lg.setColor(gfx.hex("#d9b46a"))
    local by = y + h - 18 + math.sin(self.t * 5) * 3
    lg.polygon("fill", x + w - 30, by - 5, x + w - 18, by - 5, x + w - 24, by + 3)
  end
end

function S:drawQuest()
  local x, y = 1280 - 290, 64
  lg.setColor(0.12, 0.08, 0.06, 0.75)
  lg.rectangle("fill", x, y, 270, 84, 8)
  lg.setFont(self.small)
  lg.setColor(gfx.hex("#d9b46a"))
  lg.print("QUEST", x + 14, y + 10)
  lg.setColor(0.96, 0.92, 0.82)
  lg.print("Reach the gates of Highspire", x + 14, y + 30)
  local dist = math.max(0, 9999 - math.floor(self.cam.x / 10))
  lg.setColor(0.8, 0.75, 0.65)
  lg.print(("%d paces remain"):format(dist), x + 14, y + 52)
  lg.setColor(gfx.hex("#d9b46a"))
  lg.rectangle("line", x + 236, y + 30, 16, 16, 3)
end

function S:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.sky)
  lg.setBlendMode("add")
  lg.setColor(1, 0.85, 0.6, 0.5)
  lg.draw(self.glow, 980, 300, 0, 4, 4, 64, 64)
  lg.setBlendMode("alpha")
  lg.setColor(1, 0.97, 0.85)
  lg.circle("fill", 980, 300, 46)

  for _, b in ipairs(self.birds) do
    local f = math.sin(self.t * 10 + b.p) * 6
    lg.setColor(0.2, 0.2, 0.3, 0.8)
    lg.setLineWidth(2)
    lg.line(b.x - 9, b.y - f, b.x, b.y, b.x + 9, b.y - f)
  end

  self.layers.far:draw(function() self:drawFar() end)
  self.layers.castle:draw(function() self:drawCastleLayer() end)
  self.layers.hills:draw(function() self:drawHills() end)
  -- hump.camera and love-parallax agree on the main layer: attach the camera directly.
  self.cam:attach(0, 0, 1280, 720)
  self:drawGround()
  self.cam:detach()
  self:drawHero()
  self.layers.front:draw(function() self:drawFront() end)
  self:drawQuest()
  self:drawDialogue()
end

return S
