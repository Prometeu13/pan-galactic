-- WATERCOLOR, scene 2: a birch grove in October.
--
-- The lesson here is "paint around the white". Birch trunks are just bare paper: the
-- autumn foliage is flooded in behind them wet-in-wet (dozens of overlapping blooms of
-- yellow, orange and rust), and the trunks are then defined by what's added on top: a
-- cool grey shadow down one side, and the dark horizontal scars. Splatter (flicked
-- dots of paint) and long violet cast shadows finish it. Leaves fall as tiny live
-- washes, each with a fixed seed so its ragged edge doesn't boil.

local gfx = require("core.gfx")
local washkit = require("core.washkit")

local lg = love.graphics
local GROUND = 520

local S = {
  title = "Watercolor",
  subtitle = "Birch Grove, October",
  blurb = "Autumn foliage flooded in wet-in-wet, birch trunks left as bare paper with grey shadow and dark scars, violet cast shadows and falling leaves.",
  techniques = {
    "Wet-in-wet foliage: ~90 overlapping low-alpha blooms in a limited palette",
    "Negative painting: trunks are unpainted paper, defined by shadow and scars",
    "Complementary shadows: violet-blue stripes across an ochre ground",
    "Splatter: flicked dots clustered around the canopy",
    "Three depth planes: pale blue far trunks, mid grove, big foreground trunks",
    "Falling leaves and a fox are live washes with fixed seeds",
  },
  libs = {
    "vivid: darker pooled edges on every wash (through core/washkit.lua)",
  },
  genres = { "Storybook and seasonal games", "Walking sims and photo-taking games", "Narrative games with painted backdrops", "Cosy collecting / foraging games" },
  warmup = 2,
}

local function c(h) return { gfx.hex(h) } end
local function rect(x, y, w, h) return { x, y, x + w, y, x + w, y + h, x, y + h } end

local FOLIAGE = { "#f2c230", "#f0a52a", "#e8842a", "#d9602a", "#c8452a", "#f4d85a", "#b8a030" }

-- one birch: white trunk (paper), grey shadow side, scars, a few dark branches
function S:birch(x, top, bottom, w, lean, rng, strength)
  local paint = self.paint
  local x2 = x + lean
  -- re-open the white of the paper where the trunk goes
  lg.setColor(washkit.PAPER[1], washkit.PAPER[2], washkit.PAPER[3], 0.92 * strength)
  lg.polygon("fill", x - w / 2, bottom, x + w / 2, bottom, x2 + w * 0.36, top, x2 - w * 0.36, top)
  -- shadow down the right side, with a cool reflected-light tint
  paint:wash({ x + w * 0.08, bottom, x + w / 2, bottom, x2 + w * 0.36, top, x2 + w * 0.06, top }, c("#8a93a8"), { alpha = 0.13 * strength, jitter = 2.5, step = 16, layers = 4 })
  paint:wash({ x + w * 0.3, bottom, x + w / 2, bottom, x2 + w * 0.36, top, x2 + w * 0.26, top }, c("#5f6a8a"), { alpha = 0.1 * strength, jitter = 2, step = 16, layers = 3 })
  -- a warm glaze on the lit side
  paint:wash({ x - w / 2, bottom, x - w * 0.2, bottom, x2 - w * 0.16, top, x2 - w * 0.36, top }, c("#f6e2a8"), { alpha = 0.08 * strength, jitter = 2, step = 16, layers = 3 })
  -- scars: short dark horizontal dashes, some with a "eye" shaped knot
  local y = top + rng:random() * 30
  while y < bottom - 10 do
    local u = (y - top) / (bottom - top)
    local cx = gfx.lerp(x2, x, u)
    local cw = gfx.lerp(w * 0.72, w, u)
    local len = cw * (0.2 + rng:random() * 0.5)
    local sx = cx - cw / 2 + rng:random() * (cw - len)
    lg.setColor(0.16, 0.14, 0.15, (0.5 + rng:random() * 0.4) * strength)
    lg.setLineWidth(1 + rng:random() * 2.5)
    lg.line(sx, y, sx + len, y + (rng:random() - 0.5) * 3)
    if rng:random() < 0.16 then
      lg.setColor(0.14, 0.12, 0.13, 0.8 * strength)
      lg.polygon("fill", cx - cw * 0.26, y + 8, cx, y + 2, cx + cw * 0.26, y + 8, cx, y + 16)
    end
    y = y + 8 + rng:random() * 30
  end
  -- dark base where the trunk meets the ground
  paint:blob(x, bottom + 2, w * 0.95, 9, c("#6a4a1e"), { alpha = 0.1 * strength, jitter = 3, layers = 4, noEdge = true })
  paint:blob(x + w * 0.2, bottom - 8, w * 0.4, 14, c("#3a3230"), { alpha = 0.08 * strength, jitter = 2, layers = 3, noEdge = true })
  -- thin branches reaching up and out
  for k = 1, 4 do
    local by = top + (bottom - top) * (0.06 + rng:random() * 0.4)
    local u = (by - top) / (bottom - top)
    local bx = gfx.lerp(x2, x, u)
    local dir = (k % 2 == 0) and 1 or -1
    local len = 50 + rng:random() * 90
    local pts = {}
    for i = 0, 6 do
      local v = i / 6
      pts[#pts + 1] = bx + dir * v * len
      pts[#pts + 1] = by - v * len * (0.5 + rng:random() * 0.1) - math.sin(v * 3) * 8
    end
    lg.setColor(0.2, 0.17, 0.17, 0.55 * strength)
    lg.setLineWidth(math.max(1, w * 0.07))
    lg.line(pts)
  end
end

function S:paintStatic()
  local paint = self.paint
  local rng = love.math.newRandomGenerator(77)
  -- sky peeking through: pale cerulean at the top
  paint:wash(rect(40, 40, 1200, 300), c("#a9cbe6"), { alpha = 0.1, jitter = 16, step = 30 })
  -- far grove: cool, pale, soft
  for i = 1, 16 do
    local x = 70 + i * 72 + rng:random(-20, 20)
    paint:wash({ x - 5, GROUND - 20, x + 5, GROUND - 20, x + 4, 120, x - 3, 120 }, c("#9fb0c8"), { alpha = 0.1, jitter = 3, layers = 3 })
  end
  -- foliage flooded in: big pale blooms first, then smaller, hotter ones
  for i = 1, 34 do
    local x, y = rng:random(60, 1220), rng:random(50, 330)
    paint:blob(x, y, 90 + rng:random() * 90, 60 + rng:random() * 60, c(FOLIAGE[rng:random(1, 2)]), { alpha = 0.055, jitter = 16, layers = 4, noEdge = true })
  end
  for i = 1, 60 do
    local x, y = rng:random(50, 1230), rng:random(40, 400)
    local col = FOLIAGE[rng:random(1, #FOLIAGE)]
    paint:blob(x, y, 30 + rng:random() * 60, 22 + rng:random() * 40, c(col), { alpha = 0.075, jitter = 10, layers = 4 })
  end
  -- undergrowth: a soft band of olive and gold bushes behind the trunks
  for i = 1, 40 do
    local x, y = rng:random(50, 1230), rng:random(380, 500)
    local col = ({ "#c8a030", "#a89a3a", "#d98a2a", "#8a8a3a", "#e0b040" })[rng:random(1, 5)]
    paint:blob(x, y, 50 + rng:random() * 70, 24 + rng:random() * 30, c(col), { alpha = 0.07, jitter = 10, layers = 4, noEdge = i % 2 == 0 })
  end
  -- deep accents where the canopy is densest
  for i = 1, 22 do
    local x, y = rng:random(60, 1220), rng:random(60, 300)
    paint:blob(x, y, 16 + rng:random() * 26, 12 + rng:random() * 18, c(rng:random() < 0.5 and "#a8341f" or "#7a5a1a"), { alpha = 0.09, jitter = 6, layers = 3 })
  end
  -- splatter: flicked paint around the canopy
  for i = 1, 12 do
    paint:splatter(rng:random(80, 1200), rng:random(60, 380), 16, 90, c(FOLIAGE[rng:random(1, 5)]), rng)
  end
  -- ground: ochre and sienna washes, a path of lighter paper winding back
  paint:wash(rect(40, GROUND - 30, 1200, 220), c("#e0a640"), { alpha = 0.12, jitter = 12, step = 30 })
  paint:wash(rect(40, GROUND + 40, 1200, 150), c("#c8742a"), { alpha = 0.09, jitter = 14, step = 30 })
  paint:wash({ 560, 690, 760, 690, 700, 600, 660, GROUND + 10, 630, GROUND - 16, 610, GROUND - 16, 610, GROUND + 20, 600, 610 }, c("#f7ecd0"), { alpha = 0.09, jitter = 14, step = 20, noEdge = true })
  -- leaf litter: lots of small dabs
  for i = 1, 150 do
    local x, y = rng:random(50, 1230), GROUND - 10 + rng:random() ^ 0.8 * 190
    local s = 3 + (y - GROUND) / 190 * 8
    local col = c(FOLIAGE[rng:random(1, #FOLIAGE)])
    lg.setColor(col[1], col[2], col[3], 0.4)
    lg.ellipse("fill", x, y, s * (1 + rng:random()), s * 0.5)
  end
  -- middle grove
  for i = 1, 9 do
    local x = 90 + i * 124 + rng:random(-30, 30)
    if math.abs(x - 660) > 70 then
      self:birch(x, 60, GROUND + rng:random(0, 26), 18 + rng:random() * 8, rng:random(-14, 14), rng, 0.8)
    end
  end
  -- long violet shadows cast toward us and to the right (complement of the ochre)
  local trunks = { { 190, 54 }, { 450, 46 }, { 880, 60 }, { 1090, 50 } }
  for _, tr in ipairs(trunks) do
    local x, w = tr[1], tr[2]
    paint:wash({ x - w / 2, GROUND + 70, x + w / 2, GROUND + 70, x + w / 2 + 330, 700, x - w / 2 + 250, 700 }, c("#6a5a9a"), { alpha = 0.085, jitter = 7, step = 24, layers = 4 })
  end
  -- foreground birches: big, sharp, full strength
  self:birch(190, 20, GROUND + 78, 54, 10, rng, 1)
  self:birch(450, 20, GROUND + 70, 46, -8, rng, 1)
  self:birch(880, 20, GROUND + 82, 60, -14, rng, 1)
  self:birch(1090, 20, GROUND + 74, 50, 12, rng, 1)
  -- a few leaves still on the near branches
  for i = 1, 60 do
    local x, y = rng:random(60, 1220), rng:random(40, 300)
    local col = c(FOLIAGE[rng:random(1, 5)])
    lg.setColor(col[1], col[2], col[3], 0.6)
    lg.push()
    lg.translate(x, y)
    lg.rotate(rng:random() * 6)
    lg.ellipse("fill", 0, 0, 8, 4)
    lg.pop()
  end
  -- grass tufts in a dry-brush flick
  for i = 1, 70 do
    local x, y = rng:random(50, 1230), GROUND + rng:random(20, 180)
    lg.setColor(0.45, 0.36, 0.14, 0.4)
    lg.setLineWidth(1.5)
    for k = -1, 1 do lg.line(x, y, x + k * 5 + rng:random(-2, 2), y - 12 - rng:random() * 10) end
  end
end

function S:load()
  self.t = 0
  self.paint = washkit.new()
  self.grain = washkit.grain()
  self.border = washkit.border()
  self.sig = lg.newFont(16)
  self.painting = lg.newCanvas(1280, 720)
  lg.push("all")
  lg.setCanvas(self.painting)
  lg.clear(0, 0, 0, 0)
  self:paintStatic()
  lg.pop()
  love.math.setRandomSeed(9)
  self.leaves = {}
  for i = 1, 34 do
    self.leaves[i] = {
      x = love.math.random(60, 1220), y = love.math.random(40, 680), v = 24 + love.math.random() * 30,
      p = love.math.random() * 6, col = c(FOLIAGE[love.math.random(1, 5)]), s = 5 + love.math.random() * 5,
    }
  end
  self.fox = { x = 300 }
end

function S:update(dt)
  self.t = self.t + dt
  for _, l in ipairs(self.leaves) do
    l.y = l.y + l.v * dt
    l.x = l.x + math.sin(self.t * 1.2 + l.p) * 30 * dt
    if l.y > 690 then l.y = 40 l.x = love.math.random(60, 1220) end
  end
  self.fox.x = self.fox.x + 22 * dt
  if self.fox.x > 1300 then self.fox.x = -80 end
end

function S:drawFox()
  local paint = self.paint
  local t = self.t
  local x, y = self.fox.x, GROUND + 36 + math.sin(t * 5) * 1.5
  local rust, cream, dark = c("#c8582a"), c("#f4e8d4"), c("#3a2a24")
  paint:fixed(900, function()
    -- tail, body, head
    paint:wash({ x - 34, y - 14, x - 78, y - 30 + math.sin(t * 2) * 5, x - 96, y - 16 + math.sin(t * 2) * 6, x - 74, y - 4, x - 36, y - 4 }, rust, { alpha = 0.3, jitter = 2.5, step = 10, layers = 4 })
    paint:wash({ x - 96, y - 16 + math.sin(t * 2) * 6, x - 82, y - 24 + math.sin(t * 2) * 5, x - 78, y - 8 }, cream, { alpha = 0.5, jitter = 1.5, step = 8, layers = 3 })
    paint:wash({ x - 40, y - 26, x + 22, y - 28, x + 30, y - 12, x + 20, y, x - 36, y }, rust, { alpha = 0.32, jitter = 2.5, step = 10, layers = 4 })
    paint:wash({ x + 16, y - 30, x + 30, y - 46, x + 52, y - 34, x + 62, y - 26, x + 44, y - 20, x + 24, y - 16 }, rust, { alpha = 0.34, jitter = 2, step = 8, layers = 4 })
    paint:wash({ x + 28, y - 44, x + 30, y - 60, x + 40, y - 46 }, rust, { alpha = 0.4, jitter = 1, step = 8, layers = 3 })
    paint:wash({ x + 40, y - 26, x + 62, y - 26, x + 46, y - 20, x + 30, y - 14 }, cream, { alpha = 0.5, jitter = 1.5, step = 8, layers = 3 })
  end)
  -- legs trotting: four dark strokes
  local step = math.sin(t * 5)
  lg.setColor(dark[1], dark[2], dark[3], 0.7)
  lg.setLineWidth(4)
  lg.line(x + 16, y - 4, x + 18 + step * 9, y + 16)
  lg.line(x + 8, y - 4, x + 8 - step * 9, y + 16)
  lg.line(x - 28, y - 4, x - 28 - step * 9, y + 16)
  lg.line(x - 20, y - 4, x - 20 + step * 9, y + 16)
  lg.circle("fill", x + 62, y - 26, 2.2)
  lg.circle("fill", x + 46, y - 33, 1.6)
end

function S:draw()
  local paint = self.paint
  local t = self.t
  lg.setColor(washkit.PAPER)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.painting)
  lg.setBlendMode("alpha")
  -- dappled light that slowly breathes on the path
  for k = 0, 9 do
    local a = 0.5 + 0.5 * math.sin(t * 0.7 + k * 1.9)
    lg.setColor(1, 0.97, 0.8, 0.16 * a)
    lg.ellipse("fill", 520 + (k * 83) % 320, GROUND + 30 + (k * 47) % 150, 40 + (k % 3) * 14, 10 + (k % 2) * 5)
  end
  self:drawFox()
  -- falling leaves
  for i, l in ipairs(self.leaves) do
    local a = t * 1.6 + l.p
    local dx, dy = math.cos(a) * l.s, math.sin(a) * l.s * 0.6
    paint:fixed(2000 + i, function()
      paint:wash({ l.x - dx, l.y - dy, l.x - dy * 0.7, l.y + dx * 0.5, l.x + dx, l.y + dy, l.x + dy * 0.7, l.y - dx * 0.5 }, l.col, { alpha = 0.3, jitter = 1.2, step = 6, layers = 3, convex = true })
    end)
  end
  washkit.finish(self.grain, self.border, "birch grove, october  -  love2d", self.sig)
end

return S
