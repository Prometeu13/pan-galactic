-- COMIC, scene 2: an "issue #1" cover.
--
-- A cover is a poster: masthead, corner box, one huge figure, a threat, and blurbs.
-- The hero is a set of polygons in his own coordinate space (flying along +x), drawn
-- twice like every comic in this showcase: flat colours go to the halftone pass, black
-- outlines and spot shadows go on top. Rotating and scaling the whole figure is one
-- transform. Foreshortening (the fist bigger than the head) is what makes him fly out
-- of the page. The masthead is ordinary text drawn many times: an extruded stack, a
-- thick outline, then the fill.

local gfx = require("core.gfx")
local kit = require("core.comickit")
local flux = require("flux")

local lg = love.graphics

local S = {
  title = "Comic Book",
  subtitle = "Issue #1 Cover",
  blurb = "A classic cover layout: extruded masthead, corner box, a foreshortened flying hero, a giant robot hand, sunburst rays and starburst blurbs.",
  techniques = {
    "Figure as polygons in local space: fill in the colour pass, outline in the ink pass",
    "Foreshortening: the leading fist is drawn larger than the head",
    "Masthead: sheared text = extrude stack + thick outline + fill + highlight",
    "Sunburst: alternating wedges, printed through the CMY halftone shader",
    "Starburst blurbs and corner box: the furniture of a real cover",
    "Cape and rays animate, so the cover feels alive without breaking the layout",
  },
  libs = {
    "flux: the starburst's pop and the periodic lightning flash",
  },
  genres = { "Superhero games and brawlers", "Title screens and box art", "Collectible card / gacha reveals", "Motion comics" },
  warmup = 2.2,
}

local BLUE, RED, YELLOW, SKIN = gfx.rgb("#2a55c8"), gfx.rgb("#e0322a"), gfx.rgb("#ffd21f"), gfx.rgb("#f2b890")

-- Hero parts in local space: he flies toward +x. Each: points, colour.
local function heroParts(t)
  local w1, w2 = math.sin(t * 4) * 14, math.sin(t * 4 + 1.2) * 18
  return {
    cape = { pts = { 10, -52, -90, -100 + w1, -220, -120 + w2, -350, -70 + w1, -300, -20, -360, 40 + w2, -280, 70 + w1, -160, 50, -60, 24, 20, -10 }, col = RED },
    legA = { pts = { -110, -18, -200, -30, -300, -8, -330, 8, -300, 22, -200, 14, -110, 16 }, col = BLUE },
    legB = { pts = { -110, 0, -190, 24, -270, 54, -296, 70, -276, 82, -180, 58, -104, 30 }, col = gfx.rgb("#2247aa") },
    bootA = { pts = { -272, -16, -330, -6, -356, 10, -330, 22, -276, 22 }, col = YELLOW },
    bootB = { pts = { -246, 44, -296, 62, -312, 80, -282, 86, -240, 70 }, col = YELLOW },
    armB = { pts = { 0, 10, -40, 50, -96, 78, -108, 58, -60, 30, -30, -6 }, col = gfx.rgb("#2247aa") },
    torso = { pts = { -124, -30, -40, -52, 36, -44, 60, -12, 40, 28, -30, 36, -120, 24 }, col = BLUE },
    belt = { pts = { -124, -30, -102, -34, -98, 26, -120, 24 }, col = YELLOW },
    trunks = { pts = { -146, -26, -122, -30, -118, 24, -144, 20 }, col = RED },
    armA = { pts = { 30, -40, 70, -52, 150, -34, 160, 14, 76, 12, 40, 10 }, col = BLUE },
    glove = { pts = { 140, -40, 168, -46, 172, 24, 146, 20 }, col = YELLOW },
    fist = { pts = { 164, -50, 214, -56, 246, -30, 250, 14, 222, 40, 172, 34, 158, -8 }, col = YELLOW },
    neck = { pts = { 20, -52, 44, -56, 48, -36, 26, -32 }, col = SKIN },
    head = { pts = { 22, -92, 46, -112, 80, -108, 98, -84, 92, -56, 66, -42, 38, -50, 22, -68 }, col = SKIN },
    cowl = { pts = { 18, -90, 44, -118, 84, -114, 104, -88, 98, -74, 60, -82, 40, -66, 24, -62 }, col = BLUE },
    crest = { pts = { 44, -116, 20, -150, 62, -128, 60, -160, 84, -114 }, col = RED },
  }
end
local ORDER = { "cape", "legB", "bootB", "armB", "legA", "bootA", "torso", "trunks", "belt", "neck", "head", "cowl", "crest", "armA", "glove", "fist" }

function S:load()
  self.t = 0
  self.flux = flux.group()
  self.halftone = kit.halftone(6)
  self.colorCanvas = lg.newCanvas(1280, 720)
  self.mast = lg.newFont(104)
  self.mid = lg.newFont(27)
  self.small = lg.newFont(17)
  self.tiny = lg.newFont(12)
  self.big = lg.newFont(44)
  self.pop = { s = 1 }
  self.flash = { a = 0 }
  self.next = 2.6
  love.math.setRandomSeed(12)
  self.city = {}
  local x = -40
  while x < 1320 do
    local w = love.math.random(60, 130)
    self.city[#self.city + 1] = { x, w, love.math.random(70, 230), love.math.random() }
    x = x + w + 6
  end
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  self.next = self.next - dt
  if self.next <= 0 then
    self.next = 3.4
    self.pop.s = 0.6
    self.flux:to(self.pop, 0.4, { s = 1 }):ease("backout")
    self.flash.a = 1
    self.flux:to(self.flash, 0.5, { a = 0 })
  end
end

local function heroTransform(t)
  lg.translate(790 + math.sin(t * 1.3) * 8, 372 + math.sin(t * 1.9) * 10)
  lg.rotate(-0.42)
  lg.scale(1.22)
end

-- robot fingers rising from the bottom-left: each a chain of thick segments
local FINGERS = {
  { x = 40, y = 770, a = -1.3, lens = { 150, 110, 80 }, bend = 0.46, w = 80 },
  { x = 170, y = 790, a = -1.42, lens = { 180, 126, 90 }, bend = 0.42, w = 86 },
  { x = 310, y = 800, a = -1.52, lens = { 140, 100, 74 }, bend = 0.4, w = 76 },
}

local function fingerSegs(f, t)
  local segs = {}
  local x, y, a = f.x, f.y, f.a
  local curl = 0.12 * math.sin(t * 1.5 + f.x)
  for i, len in ipairs(f.lens) do
    local w = f.w * (1 - (i - 1) * 0.16)
    local x2, y2 = x + math.cos(a) * len, y + math.sin(a) * len
    local nx, ny = -math.sin(a) * w / 2, math.cos(a) * w / 2
    segs[#segs + 1] = { x + nx, y + ny, x2 + nx * 0.86, y2 + ny * 0.86, x2 - nx * 0.86, y2 - ny * 0.86, x - nx, y - ny, jx = x2, jy = y2, w = w, a = a, last = i == #f.lens }
    x, y = x2, y2
    a = a + f.bend + curl
  end
  return segs
end

function S:drawColor()
  local t = self.t
  -- sunburst behind everything
  local cx, cy = 760, 380
  for k = 0, 31 do
    local a1 = k / 32 * math.pi * 2 + t * 0.06
    local a2 = a1 + math.pi * 2 / 32
    lg.setColor(k % 2 == 0 and gfx.rgb("#ffe14a") or gfx.rgb("#ff9a2e"))
    lg.polygon("fill", cx, cy, cx + math.cos(a1) * 1200, cy + math.sin(a1) * 1200, cx + math.cos(a2) * 1200, cy + math.sin(a2) * 1200)
  end
  lg.setColor(gfx.hex("#fff6c0"))
  lg.circle("fill", cx, cy, 150)
  -- skyline tilted, as seen from above
  lg.push()
  lg.translate(640, 720)
  lg.rotate(0.07)
  lg.translate(-640, -720)
  for _, b in ipairs(self.city) do
    lg.setColor(gfx.mix(gfx.rgb("#5a3fa8"), gfx.rgb("#c83f8a"), b[4]))
    lg.rectangle("fill", b[1], 740 - b[3], b[2], b[3] + 40)
    lg.setColor(gfx.hex("#ffe14a"))
    for wy = 740 - b[3] + 12, 730, 22 do
      for wx = b[1] + 10, b[1] + b[2] - 16, 20 do
        if gfx.hash(wx * 0.31 + wy * 0.17) > 0.45 then lg.rectangle("fill", wx, wy, 9, 12) end
      end
    end
  end
  lg.pop()
  -- lightning flash tint
  if self.flash.a > 0.01 then
    lg.setColor(1, 1, 1, self.flash.a * 0.6)
    lg.rectangle("fill", 0, 0, 1280, 720)
  end
end

function S:drawInk()
  local t = self.t
  -- Figures are flat colour + ink, painted back to front so nearer parts cover
  -- farther ones (the halftone stays on the background, as in many real comics).
  for _, f in ipairs(FINGERS) do
    for _, s in ipairs(fingerSegs(f, t)) do
      lg.setColor(gfx.hex("#7f9a98"))
      lg.polygon("fill", s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8])
      lg.setColor(gfx.hex("#b8d2c8"))
      lg.polygon("fill", s[1], s[2], s[3], s[4], (s[3] * 2 + s[5]) / 3, (s[4] * 2 + s[6]) / 3, (s[1] * 2 + s[7]) / 3, (s[2] * 2 + s[8]) / 3)
      -- spot shadow on the underside
      lg.setColor(0.04, 0.04, 0.05)
      lg.polygon("fill", s[7], s[8], s[5], s[6], (s[5] * 4 + s[3]) / 5, (s[6] * 4 + s[4]) / 5, (s[7] * 4 + s[1]) / 5, (s[8] * 4 + s[2]) / 5)
      kit.ink({ s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8] }, 5)
      lg.circle("fill", (s[1] + s[7]) / 2 + 14, (s[2] + s[8]) / 2 - 22, 5)
      lg.setColor(s.last and { gfx.hex("#e0322a") } or { gfx.hex("#566e70") })
      lg.circle("fill", s.jx, s.jy, s.w * 0.44)
      lg.setColor(0.04, 0.04, 0.05)
      lg.setLineWidth(5)
      lg.circle("line", s.jx, s.jy, s.w * 0.44)
      if s.last then
        lg.setColor(1, 1, 1)
        lg.circle("fill", s.jx - s.w * 0.12, s.jy - s.w * 0.12, s.w * 0.1)
      end
    end
  end
  lg.push()
  heroTransform(t)
  local parts = heroParts(t)
  for _, name in ipairs(ORDER) do
    kit.shape(parts[name].pts, parts[name].col)
    kit.ink(parts[name].pts, name == "fist" and 6 or 4)
    if name == "cape" then
      -- deep folds in the cape
      lg.setColor(0.04, 0.04, 0.05)
      lg.polygon("fill", -90, -100 + math.sin(t * 4) * 14, -200, -96, -160, -70, -60, -52)
      lg.polygon("fill", -300, -20, -230, -6, -170, 20, -250, 30)
    elseif name == "torso" then
      lg.setColor(YELLOW)
      lg.ellipse("fill", -30, -8, 30, 24)
      lg.setColor(RED)
      lg.polygon("fill", -22, -26, -40, -6, -30, -6)
      lg.polygon("fill", -30, -6, -22, -6, -38, 14)
      lg.setColor(0.04, 0.04, 0.05)
      lg.setLineWidth(3)
      lg.ellipse("line", -30, -8, 30, 24)
      lg.line(-70, -40, -62, 28)
      lg.line(2, -42, 12, -12, 4, 26)
    elseif name == "armA" then
      lg.setColor(0.04, 0.04, 0.05)
      lg.polygon("fill", 40, 10, 76, 12, 150, 13, 100, 2, 50, 4)
      lg.setLineWidth(3)
      lg.line(80, -34, 124, -26)
    end
  end
  lg.setColor(0.04, 0.04, 0.05)
  -- knuckle lines on the fist
  lg.setLineWidth(4)
  lg.line(196, -50, 204, -16)
  lg.line(222, -42, 226, -10)
  lg.line(172, -6, 244, -4)
  lg.line(176, 30, 190, 4)
  -- face: white eye slit in the cowl, a set jaw
  lg.setColor(1, 1, 1)
  lg.polygon("fill", 62, -86, 88, -92, 92, -82, 66, -78)
  lg.setColor(0.04, 0.04, 0.05)
  lg.setLineWidth(3)
  lg.polygon("line", 62, -86, 88, -92, 92, -82, 66, -78)
  lg.line(74, -58, 90, -62)
  lg.line(92, -72, 100, -70)
  lg.pop()

  -- masthead
  lg.push()
  lg.translate(640, 30)
  lg.shear(-0.16, 0)
  kit.sfx("THUNDERFINCH", -640 + 24, 36, self.mast, YELLOW, RED, 9, 1280, "center")
  lg.setColor(1, 1, 1, 0.55)
  lg.setFont(self.mast)
  lg.setScissor(0, 76, 1280, 26)
  lg.printf("THUNDERFINCH", -640 + 24, 36, 1280, "center")
  lg.setScissor()
  lg.pop()
  lg.setColor(RED)
  lg.rectangle("fill", 250, 18, 260, 32)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.rectangle("line", 250, 18, 260, 32)
  lg.setFont(self.small)
  lg.setColor(1, 1, 1)
  lg.printf("THE UNSTOPPABLE", 250, 24, 260, "center")
  -- corner box: issue number, price, month
  lg.setColor(1, 1, 1)
  lg.rectangle("fill", 34, 28, 130, 178)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(4)
  lg.rectangle("line", 34, 28, 130, 178)
  lg.line(34, 84, 164, 84)
  lg.line(34, 150, 164, 150)
  lg.setFont(self.small)
  lg.printf("LOVE2D\nCOMICS", 34, 34, 130, "center")
  lg.setFont(self.big)
  lg.printf("#1", 34, 90, 130, "center")
  lg.setFont(self.small)
  lg.printf("25c    JUN", 34, 168, 130, "center")
  -- starburst blurb, top right
  lg.push()
  lg.translate(1128, 372)
  lg.rotate(0.14)
  lg.scale(self.pop.s)
  local star = kit.burst(0, 0, 118, 86, 14)
  kit.fillBurst(star, 0, 0, RED)
  kit.ink(star, 4)
  lg.setFont(self.mid)
  lg.setColor(1, 1, 1)
  lg.printf("FIRST\nELECTRIFYING\nISSUE!", -110, -54, 220, "center")
  lg.pop()
  -- bottom banner
  lg.setColor(YELLOW)
  lg.polygon("fill", 470, 640, 1250, 620, 1250, 696, 470, 704)
  kit.ink({ 470, 640, 1250, 620, 1250, 696, 470, 704 }, 4)
  lg.setFont(self.mid)
  lg.setColor(0, 0, 0)
  lg.push()
  lg.translate(860, 664)
  lg.rotate(-0.022)
  lg.printf("\"THE CLOCKWORK COLOSSUS WAKES!\"", -390, -18, 780, "center")
  lg.pop()
  -- barcode box
  lg.setColor(1, 1, 1)
  lg.rectangle("fill", 34, 220, 110, 80)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.rectangle("line", 34, 220, 110, 80)
  for k = 0, 23 do
    local w = 1 + (gfx.hash(k * 2.7) > 0.5 and 2 or 0)
    lg.rectangle("fill", 44 + k * 3.8, 228, w, 52)
  end
  lg.setFont(self.tiny)
  lg.print("0 12345 67890 1", 44, 282)
  -- page border
  lg.setLineWidth(8)
  lg.rectangle("line", 14, 10, 1252, 700)
end

function S:draw()
  kit.page(self.colorCanvas, self.halftone, function() self:drawColor() end, function() self:drawInk() end)
end

return S
