-- NOIR, scene 2: the private eye's office, a quarter past midnight.
--
-- The signature image of film noir is light through venetian blinds. It is painted
-- straight into a light map: a fan of bright stripes that start at the window, spread
-- and fade as they rake across the wall, and fall over everything in their way (the
-- detective's hat and face included). A neon sign outside blinks, so the stripes pulse.
-- The desk lamp adds a warm pool, and throws the detective's shadow up the wall: that
-- shadow is simply his own outline, scaled away from the bulb.

local gfx = require("core.gfx")
local kit = require("core.noirkit")

local lg = love.graphics
local FLOOR = 600

local S = {
  title = "Noir",
  subtitle = "The Private Eye's Office",
  blurb = "Blinds, a desk lamp, a ceiling fan and somebody waiting behind the frosted glass. Striped light rakes across the room.",
  techniques = {
    "Light map: ambient darkness + additive light shapes, multiplied over the room",
    "Venetian blinds = a fan of gradient stripes (one Mesh) that spread and fade",
    "Neon outside blinks: the striped light pulses with it",
    "Wall shadow = the character's own polygons scaled away from the lamp bulb",
    "Frosted glass door: a bright panel, a blurred silhouette, mirrored lettering",
    "Colour-authored, then desaturated with grain, vignette and letterbox",
  },
  libs = {
    "moonshine: desaturate, filmgrain, vignette",
  },
  genres = { "Detective adventures and visual novels", "Interrogation / dialogue games", "Point-and-click mysteries", "Menu hubs between cases" },
  controls = "press C to see the colour version.",
  warmup = 3,
}

local function rect(x, y, w, h) return { x, y, x + w, y, x + w, y + h, x, y + h } end

function S:load()
  self.t = 0
  self.bw = true
  self.fx = kit.grade()
  self.lightCanvas = lg.newCanvas(1280, 720)
  self.glow = gfx.radialTexture(128, 2)
  self.font = lg.newFont(20)
  self.doorFont = lg.newFont(15)
  self.rain = kit.newRain(140, 8)

  -- wallpaper baked once: stripes and a little grime
  self.wall = lg.newCanvas(1280, FLOOR)
  lg.push("all")
  lg.setCanvas(self.wall)
  lg.clear(gfx.hex("#5a6a5c"))
  for x = 0, 1280, 44 do
    lg.setColor(gfx.hex("#526053"))
    lg.rectangle("fill", x, 0, 22, FLOOR)
    lg.setColor(gfx.hex("#6a7a66"))
    lg.rectangle("fill", x + 32, 0, 2, FLOOR)
  end
  lg.setColor(gfx.hex("#4a3628"))
  lg.rectangle("fill", 0, 470, 1280, 130)            -- wainscot
  lg.setColor(gfx.hex("#3a2a1e"))
  for x = 0, 1280, 120 do lg.rectangle("line", x + 10, 484, 100, 104) end
  lg.rectangle("fill", 0, 466, 1280, 8)
  lg.pop()

  self.slats = {}
  for y = 150, 470, 20 do self.slats[#self.slats + 1] = rect(1186, y, 80, 6) end
  self.deskTop = rect(410, 470, 500, 16)
  self.deskBody = rect(430, 486, 460, 114)
  -- the detective, seated behind the desk
  self.man = {
    { 586, 470, 596, 372, 630, 352, 668, 352, 704, 372, 712, 470 },   -- shoulders and chest
    { 628, 300, 668, 300, 672, 340, 650, 356, 628, 342 },             -- head
    { 594, 296, 706, 296, 700, 306, 600, 306 },                       -- hat brim
    { 622, 296, 628, 262, 672, 262, 678, 296 },                       -- hat crown
  }
  -- ...and the same shapes pushed away from the lamp bulb: his shadow on the wall
  local LX, LY, K = 500, 452, 1.3
  self.manShadow = {}
  for i, p in ipairs(self.man) do
    local q = {}
    for k = 1, #p, 2 do
      q[k], q[k + 1] = LX + (p[k] - LX) * K, LY + (p[k + 1] - LY) * K
    end
    self.manShadow[i] = q
  end
  self.shade = { 474, 398, 526, 398, 546, 428, 454, 428 }
  self.cabinet = rect(318, 372, 88, 228)
  self.coat = { 986, 250, 1040, 250, 1060, 470, 970, 470 }

  -- the blinds' light: stripes that start at the window (right), spread out and fade
  local verts = {}
  local function v(x, y, a) verts[#verts + 1] = { x, y, 0, 0, 1, 0.96, 0.88, a } end
  for k = 0, 15 do
    local y = 150 + k * 20 + 7
    local function far(yy) return 330 + (yy - 310) * 1.7 + 70 end
    local x0, x1, x2 = 1190, 760, 300
    local function mid(yy) return gfx.lerp(yy, far(yy), 0.45) end
    v(x0, y, 0.95) v(x0, y + 12, 0.95) v(x1, mid(y + 12), 0.7)
    v(x0, y, 0.95) v(x1, mid(y + 12), 0.7) v(x1, mid(y), 0.7)
    v(x1, mid(y), 0.7) v(x1, mid(y + 12), 0.7) v(x2, far(y + 12), 0)
    v(x1, mid(y), 0.7) v(x2, far(y + 12), 0) v(x2, far(y), 0)
  end
  self.stripes = lg.newMesh(verts, "triangles", "static")
  self.neon = 1
  self.smoke = {}
end

function S:keypressed(k)
  if k == "c" then
    self.bw = not self.bw
    if self.bw then self.fx.enable("desaturate") else self.fx.disable("desaturate") end
  end
end

function S:update(dt)
  self.t = self.t + dt
  kit.updateRain(self.rain, dt)
  -- the neon sign across the street: on, on, off...
  local phase = self.t % 2.6
  self.neon = (phase < 1.7 or (phase > 1.9 and phase < 2.0)) and 1 or 0.25
  if love.math.random() < dt * 7 then self.smoke[#self.smoke + 1] = { x = 726, y = 458, life = 0 } end
  for i = #self.smoke, 1, -1 do
    local s = self.smoke[i]
    s.life = s.life + dt
    s.y = s.y - 26 * dt
    s.x = s.x + math.sin(s.life * 1.7 + i) * 10 * dt
    if s.life > 4 then table.remove(self.smoke, i) end
  end
end

function S:drawRoom()
  local t = self.t
  lg.setColor(1, 1, 1)
  lg.draw(self.wall)
  -- a crooked framed licence on the wall
  lg.push()
  lg.translate(800, 250)
  lg.rotate(0.05)
  lg.setColor(gfx.hex("#2a1e14"))
  lg.rectangle("fill", -44, -32, 88, 64)
  lg.setColor(gfx.hex("#e8dcc0"))
  lg.rectangle("fill", -36, -24, 72, 48)
  lg.setColor(gfx.hex("#6a5a48"))
  for k = 0, 3 do lg.rectangle("fill", -26, -14 + k * 9, 52 - k * 8, 3) end
  lg.pop()
  -- the detective's shadow, thrown up the wall by the desk lamp
  lg.setColor(gfx.hex("#232a25"))
  for _, p in ipairs(self.manShadow) do lg.polygon("fill", p) end
  -- floorboards
  lg.setColor(gfx.hex("#4a3424"))
  lg.rectangle("fill", 0, FLOOR, 1280, 120)
  lg.setColor(gfx.hex("#33241a"))
  for x = -40, 1280, 110 do lg.line(x, FLOOR, x - 40, 720) end
  lg.rectangle("fill", 0, FLOOR, 1280, 4)

  -- door with a frosted glass panel
  lg.setColor(gfx.hex("#3a2618"))
  lg.rectangle("fill", 110, 150, 190, 450)
  lg.setColor(gfx.hex("#2a1a10"))
  lg.rectangle("fill", 96, 150, 14, 450)
  lg.setColor(gfx.hex("#c9a23a"))
  lg.circle("fill", 280, 430, 8)
  -- filing cabinet
  lg.setColor(gfx.hex("#5a6258"))
  lg.polygon("fill", self.cabinet)
  for k = 0, 3 do
    lg.setColor(gfx.hex("#3e453e"))
    lg.rectangle("line", 324, 378 + k * 56, 76, 50)
    lg.setColor(gfx.hex("#8a8f84"))
    lg.rectangle("fill", 350, 398 + k * 56, 24, 6)
  end
  -- coat rack with the trench coat and a hat
  lg.setColor(gfx.hex("#2a1e14"))
  lg.rectangle("fill", 1010, 200, 8, 400)
  lg.rectangle("fill", 980, 590, 68, 10)
  lg.setColor(gfx.hex("#8a7250"))
  lg.polygon("fill", self.coat)
  lg.setColor(gfx.hex("#6e5a3e"))
  lg.polygon("fill", 1014, 250, 1040, 250, 1050, 470, 1014, 470)
  lg.setColor(gfx.hex("#2a2622"))
  lg.ellipse("fill", 1014, 204, 40, 8)
  lg.polygon("fill", 992, 204, 998, 176, 1030, 176, 1036, 204)

  -- the detective behind his desk
  lg.setColor(gfx.hex("#4a4a52"))
  lg.polygon("fill", self.man[1])
  lg.setColor(gfx.hex("#e8e4dc"))
  lg.polygon("fill", 636, 356, 662, 356, 656, 420, 642, 420)      -- shirt
  lg.setColor(gfx.hex("#7a2a2a"))
  lg.polygon("fill", 645, 360, 653, 360, 656, 410, 649, 420, 642, 410) -- tie
  lg.setColor(gfx.hex("#c99a7a"))
  lg.polygon("fill", self.man[2])
  lg.setColor(gfx.hex("#2a2622"))
  lg.polygon("fill", self.man[3])
  lg.polygon("fill", self.man[4])
  lg.setColor(gfx.hex("#4a3a2a"))
  lg.rectangle("fill", 624, 288, 52, 8)
  -- his arm resting on the desk, cigarette between two fingers
  lg.setColor(gfx.hex("#4a4a52"))
  lg.polygon("fill", 690, 400, 716, 392, 742, 452, 716, 470, 696, 470)
  lg.setColor(gfx.hex("#c99a7a"))
  lg.ellipse("fill", 728, 462, 14, 9)
  lg.setColor(gfx.hex("#f2efe8"))
  lg.rectangle("fill", 716, 456, 18, 3)

  -- desk and what's on it
  lg.setColor(gfx.hex("#5a3a22"))
  lg.polygon("fill", self.deskBody)
  lg.setColor(gfx.hex("#6e4a2c"))
  lg.polygon("fill", self.deskTop)
  lg.setColor(gfx.hex("#3e2816"))
  for k = 0, 1 do
    lg.rectangle("line", 446 + k * 300, 500, 130, 40)
    lg.rectangle("line", 446 + k * 300, 548, 130, 40)
  end
  -- banker's lamp
  lg.setColor(gfx.hex("#8a6a2a"))
  lg.rectangle("fill", 496, 428, 8, 34)
  lg.ellipse("fill", 500, 466, 26, 6)
  lg.setColor(gfx.hex("#2f6a48"))
  lg.polygon("fill", self.shade)
  -- telephone
  lg.setColor(gfx.hex("#1a1a1c"))
  lg.rectangle("fill", 548, 448, 54, 22, 6)
  lg.rectangle("fill", 540, 436, 70, 10, 5)
  lg.setColor(gfx.hex("#5a5a60"))
  lg.circle("fill", 575, 459, 7)
  -- typewriter with a sheet of paper in it
  lg.setColor(gfx.hex("#f0ece0"))
  lg.rectangle("fill", 792, 396, 56, 50)
  lg.setColor(gfx.hex("#26282c"))
  lg.rectangle("fill", 776, 436, 90, 34, 5)
  lg.rectangle("fill", 770, 428, 102, 10, 4)
  lg.setColor(gfx.hex("#8a8f94"))
  for r = 0, 1 do for k = 0, 8 do lg.circle("fill", 786 + k * 9 + r * 4, 450 + r * 9, 3) end end
  -- bottle and glass
  lg.setColor(gfx.hex("#5a3a1a"))
  lg.rectangle("fill", 882, 416, 20, 54, 4)
  lg.rectangle("fill", 888, 398, 8, 20)
  lg.setColor(gfx.hex("#e8dcc0"))
  lg.rectangle("fill", 884, 436, 16, 16)
  lg.setColor(0.8, 0.85, 0.9, 0.5)
  lg.rectangle("fill", 846, 448, 18, 22, 3)
  lg.setColor(gfx.hex("#b87a2a"))
  lg.rectangle("fill", 848, 460, 14, 9)
  -- ashtray
  lg.setColor(gfx.hex("#8a8f94"))
  lg.ellipse("fill", 708, 468, 20, 5)

  -- ceiling fan: three blades squashed into ellipses, spinning slowly
  lg.setColor(gfx.hex("#2a1e14"))
  lg.rectangle("fill", 636, 62, 8, 40)
  for k = 0, 2 do
    local a = t * 1.8 + k * math.pi * 2 / 3
    local bx, by = 640 + math.cos(a) * 80, 106 + math.sin(a) * 12
    lg.push()
    lg.translate((640 + bx) / 2, (106 + by) / 2)
    lg.rotate(math.atan2(by - 106, bx - 640))
    lg.ellipse("fill", 0, 0, 46, 8 + math.abs(math.sin(a)) * 3)
    lg.pop()
  end
  lg.circle("fill", 640, 106, 12)
end

function S:drawGlows()
  local t = self.t
  -- the window strip: neon-lit rain behind the slats
  local n = self.neon
  lg.setColor(0.95 * n, 0.9 * n, 0.85 * n)
  lg.rectangle("fill", 1190, 142, 90, 336)
  lg.setScissor(1190, 142, 90, 336)
  kit.drawRain(self.rain, 0.5)
  lg.setScissor()
  lg.setColor(gfx.hex("#141210"))
  for _, s in ipairs(self.slats) do lg.polygon("fill", s) end
  lg.rectangle("fill", 1180, 134, 100, 10)
  lg.rectangle("fill", 1180, 474, 100, 10)
  lg.rectangle("fill", 1180, 134, 10, 350)
  -- frosted glass: bright panel, a soft figure behind it, lettering in reverse
  lg.setColor(gfx.hex("#d8d4c4"))
  lg.rectangle("fill", 132, 190, 146, 220)
  local sway = math.sin(t * 0.6) * 3
  for k = 3, 0, -1 do
    lg.setColor(0.12, 0.11, 0.1, 0.22)
    lg.ellipse("fill", 205 + sway, 270, 22 + k * 3, 26 + k * 3)                      -- head
    lg.ellipse("fill", 205 + sway, 250, 46 + k * 3, 8 + k * 2)                       -- wide hat brim
    lg.polygon("fill", 168 - k * 3 + sway, 410, 180 - k * 2 + sway, 300, 230 + k * 2 + sway, 300, 242 + k * 3 + sway, 410)
  end
  lg.setFont(self.doorFont)
  lg.setColor(0.1, 0.09, 0.08, 0.85)
  lg.push()
  lg.translate(205, 200)
  lg.scale(-1, 1)                                   -- we're inside: the sign reads backwards
  lg.printf("J. HOLLIS", -70, 0, 140, "center")
  lg.printf("INVESTIGATIONS", -70, 20, 140, "center")
  lg.pop()
  lg.setColor(gfx.hex("#2a1a10"))
  lg.setLineWidth(8)
  lg.rectangle("line", 132, 190, 146, 220)
  -- lamp glow, cigarette ember and smoke
  lg.setBlendMode("add")
  lg.setColor(1, 0.85, 0.5, 0.75)
  lg.draw(self.glow, 500, 436, 0, 1.3, 0.9, 64, 64)
  lg.setColor(0.8, 1, 0.8, 0.25)
  lg.draw(self.glow, 500, 410, 0, 1.1, 0.6, 64, 64)
  lg.setBlendMode("alpha")
  lg.setColor(1, 0.5, 0.15, 0.7 + 0.3 * math.sin(t * 3))
  lg.circle("fill", 735, 457, 2.5)
  for _, s in ipairs(self.smoke) do
    lg.setColor(0.9, 0.9, 0.9, 0.16 * (1 - s.life / 4))
    lg.circle("fill", s.x, s.y, 5 + s.life * 9)
  end
end

function S:drawLight()
  local n = self.neon
  lg.setColor(n, n, n)
  lg.draw(self.stripes)
  -- a soft spill around the window itself
  lg.setColor(0.5 * n, 0.5 * n, 0.5 * n)
  lg.draw(self.glow, 1230, 310, 0, 5, 6, 64, 64)
  -- desk lamp: a warm pool, strongest below the shade
  lg.setColor(1, 0.85, 0.55)
  lg.setScissor(0, 426, 1280, 300)
  lg.draw(self.glow, 500, 452, 0, 9, 5, 64, 64)
  lg.draw(self.glow, 500, 452, 0, 6, 3.4, 64, 64)
  lg.draw(self.glow, 500, 452, 0, 3, 2, 64, 64)
  lg.setScissor()
  lg.setColor(0.42, 0.36, 0.24)
  lg.draw(self.glow, 520, 420, 0, 8, 6, 64, 64)
  -- corridor light through the frosted glass, falling on the floor
  lg.setColor(0.5, 0.5, 0.46)
  lg.polygon("fill", 132, 600, 278, 600, 400, 720, 150, 720)
  lg.setColor(0.3, 0.3, 0.28)
  lg.draw(self.glow, 205, 330, 0, 4, 5, 64, 64)
end

function S:draw()
  self.fx(function()
    local target = lg.getCanvas()
    self:drawRoom()
    kit.beginLight(self.lightCanvas, 0.2)
    self:drawLight()
    kit.endLight(self.lightCanvas, target)
    self:drawGlows()
    kit.letterbox("\"She came in out of the rain at a quarter past midnight. Trouble usually waits until one.\"", self.font)
  end)
end

return S
