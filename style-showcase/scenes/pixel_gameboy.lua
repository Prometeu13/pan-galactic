-- PIXEL ART, scene 3: a 4-shade handheld LCD platformer at 160x144.
--
-- Restriction is the style: only 4 shades of green, a 160x144 screen, 8x8 tiles.
-- On top of that, the screen itself is simulated:
--   * LCD ghosting: each frame is blended with the previous one, so moving things smear
--   * pixel grid: thin gaps between the big pixels when scaled up
--   * a plastic bezel around the screen, drawn with rounded rectangles
-- Gameplay bits are real: a hero with jump physics, coins that spin by squashing their
-- width, a walking enemy, and a camera that follows the hero through a tile map.

local gfx = require("core.gfx")
local pixelfont = require("core.pixelfont")

local lg = love.graphics
local PW, PH, T = 160, 144, 8
local SCALE = 4.4
local SX, SY = math.floor(640 - PW * SCALE / 2), 46

local S = {
  title = "Pixel Art",
  subtitle = "4-Shade Handheld",
  blurb = "A 160x144, 4-shade LCD platformer inside a drawn handheld, with LCD ghosting and a visible pixel grid.",
  techniques = {
    "Only 4 colours: every sprite string uses the digits 0-3",
    "Level as a list of strings; the camera follows the hero and wraps forever",
    "Jump physics with gravity; coins 'spin' by scaling their width with cos()",
    "LCD ghosting: the previous frame is blended in at 35%",
    "Pixel grid and bezel drawn over the upscaled screen",
  },
  libs = {
    "(none: plain canvases, strings and a little physics)",
  },
  genres = { "Retro handheld-style platformers", "Puzzle and arcade games for jams", "Monster-collecting RPGs", "Demakes and 'lost handheld game' projects" },
  warmup = 3.2,
}

local SHADES = { gfx.rgb("#e0f0c0"), gfx.rgb("#88b070"), gfx.rgb("#3c6848"), gfx.rgb("#102818") }
local P = { ["0"] = SHADES[1], ["1"] = SHADES[2], ["2"] = SHADES[3], ["3"] = SHADES[4] }

local HERO = {
  { "..3333..", ".322223.", ".320203.", ".322223.", "..3333..", ".311113.", "3.3113.3", "..3..3.." },
  { "..3333..", ".322223.", ".320203.", ".322223.", "..3333..", "3311113.", "..3113.3", ".3....3." },
}
local ENEMY = {
  { "..3333..", ".300003.", "30300303", "30000003", ".333333.", ".3.33.3.", "33....33", "........" },
  { "..3333..", ".300003.", "30300303", "30000003", ".333333.", ".3.33.3.", ".33..33.", "........" },
}
local COIN = { "..3333..", ".311113.", "31100113", "31011013", "31011013", "31100113", ".311113.", "..3333.." }
local GROUND = { "11111111", "12121212", "22222222", "23222322", "22222222", "22322232", "22222222", "32222223" }
local BRICK = { "33333333", "31112111", "31112111", "22223222", "11131112", "11131112", "22223222", "33333333" }
local CLOUD = { "....1111....", "..11000011..", ".1000000001.", "100000000001", ".1111111111." }

-- Level: '#' ground, 'B' brick block, 'o' coin, '.' air. 16 rows of 8px = 128px (+16px HUD).
local LEVEL = {
  "........................................",
  "........................................",
  "........................................",
  "..........ooo...............o.o.o.......",
  "........................................",
  ".........BBBBB...........BBBBBBB........",
  "...o.o..............o...................",
  "........................oo..............",
  "..BBB.........BB.......BBBB.....BB......",
  "........................................",
  "######...##########...#############.####",
  "######...##########...#############.####",
  "######...##########...#############.####",
  "######...##########...#############.####",
  "######...##########...#############.####",
  "######...##########...#############.####",
}

function S:load()
  self.t = 0
  self.screen = lg.newCanvas(PW, PH)
  self.screen:setFilter("nearest", "nearest")
  self.ghost = lg.newCanvas(PW, PH)
  self.ghost:setFilter("nearest", "nearest")
  self.font = pixelfont.make()
  local function sp(rows) return gfx.spriteFromStrings(rows, P) end
  self.hero = { sp(HERO[1]), sp(HERO[2]) }
  self.enemy = { sp(ENEMY[1]), sp(ENEMY[2]) }
  self.coin, self.ground, self.brick, self.cloud = sp(COIN), sp(GROUND), sp(BRICK), sp(CLOUD)
  self.W = #LEVEL[1] * T
  self.p = { x = 16, y = 60, vy = 0, onGround = false }
  self.score = 0
  self.taken = {}
  self.e = { x = 120 }
end

local function tile(x, y)
  local row = LEVEL[y + 1]
  if not row then return "." end
  local i = x % #row + 1
  return row:sub(i, i)
end

function S:update(dt)
  self.t = self.t + dt
  local p = self.p
  p.x = p.x + 38 * dt
  -- jump before gaps and blocks (a tiny "AI" so it plays itself)
  local ahead = tile(math.floor((p.x + 14) / T), 10)
  local wall = tile(math.floor((p.x + 12) / T), math.floor((p.y + 4) / T))
  if p.onGround and (ahead == "." or wall == "B" or love.math.random() < 0.006) then
    p.vy = -175
    p.onGround = false
  end
  p.vy = p.vy + 420 * dt
  p.y = p.y + p.vy * dt
  -- land on ground or brick tops
  local footY = math.floor((p.y + 8) / T)
  local under = tile(math.floor((p.x + 4) / T), footY)
  if p.vy > 0 and (under == "#" or under == "B") then
    p.y = footY * T - 8
    p.vy = 0
    p.onGround = true
  end
  -- fell into a gap: drop back in from the top a few tiles further on
  if p.y > 10 * T then p.y = -10; p.vy = 0; p.x = p.x + 3 * T end
  -- collect coins
  local cx, cy = math.floor((p.x + 4) / T), math.floor((p.y + 4) / T)
  if tile(cx, cy) == "o" then
    local key = (cx % #LEVEL[1]) .. ":" .. cy .. ":" .. math.floor(cx / #LEVEL[1])
    if not self.taken[key] then self.taken[key] = true; self.score = self.score + 10 end
  end
  self.e.x = 120 + math.sin(self.t * 0.8) * 30
end

function S:drawWorld()
  local camX = math.floor(self.p.x - 50)
  lg.clear(SHADES[1])
  -- parallax clouds and hills (slower than the camera)
  lg.setColor(1, 1, 1)
  for i = -1, 4 do
    local x = math.floor(i * 70 - (camX * 0.25) % 70)
    lg.draw(self.cloud, x, 12 + (i % 2) * 10)
  end
  lg.setColor(SHADES[2])
  for x = 0, PW do
    local wx = x + camX * 0.5
    local h = 70 + math.sin(wx * 0.04) * 8 + math.sin(wx * 0.013) * 6
    lg.rectangle("fill", x, math.floor(h), 1, 120)
  end
  lg.setColor(1, 1, 1)
  local first = math.floor(camX / T)
  for ty = 0, #LEVEL - 1 do
    for tx = first, first + PW / T + 1 do
      local ch = tile(tx, ty)
      local x, y = tx * T - camX, ty * T + 16
      if ch == "#" then lg.draw(self.ground, x, y)
      elseif ch == "B" then lg.draw(self.brick, x, y)
      elseif ch == "o" then
        local key = (tx % #LEVEL[1]) .. ":" .. ty .. ":" .. math.floor(tx / #LEVEL[1])
        if not self.taken[key] then
          local spin = math.abs(math.cos(self.t * 4 + tx))
          lg.draw(self.coin, x + 4, y, 0, math.max(0.15, spin), 1, 4, 0)
        end
      end
    end
  end
  -- enemy and hero
  local ex = math.floor((self.e.x - camX) % self.W)
  if ex < PW then lg.draw(self.enemy[math.floor(self.t * 4) % 2 + 1], ex, 9 * T + 16) end
  local p = self.p
  lg.draw(self.hero[p.onGround and (math.floor(self.t * 8) % 2 + 1) or 2], math.floor(p.x - camX), math.floor(p.y) + 16)
  -- HUD strip
  lg.setColor(SHADES[4])
  lg.rectangle("fill", 0, 0, PW, 11)
  lg.setFont(self.font)
  lg.setColor(SHADES[1])
  lg.print(("SCORE %05d"):format(self.score), 3, 3)
  lg.print("WORLD 1-2", PW - 38, 3)
end

local function bezel()
  -- body
  lg.setColor(gfx.hex("#c9c6bf"))
  lg.rectangle("fill", SX - 70, 8, PW * SCALE + 140, 760, 34)
  lg.setColor(gfx.hex("#b5b2aa"))
  lg.rectangle("fill", SX - 70, 8, PW * SCALE + 140, 6, 3)
  -- dark screen surround
  lg.setColor(gfx.hex("#4a4d5e"))
  lg.rectangle("fill", SX - 44, SY - 30, PW * SCALE + 88, PH * SCALE + 46, 16)
  lg.setColor(gfx.hex("#8a2a48"))
  lg.rectangle("fill", SX - 30, SY - 18, 60, 3)
  lg.setColor(gfx.hex("#2a2c48"))
  lg.rectangle("fill", SX + 36, SY - 18, 60, 3)
  -- power LED
  lg.setColor(1, 0.2, 0.2)
  lg.circle("fill", SX - 26, SY + 120, 4)
  lg.setColor(0.8, 0.8, 0.85)
  lg.print("POWER", SX - 40, SY + 130)
end

function S:draw()
  local view = require("core.view")
  -- 1) draw the game at 160x144
  lg.push("all")
  local prev = self.ghost
  self.ghost, self.screen = self.screen, prev
  lg.setCanvas(self.screen)
  self:drawWorld()
  -- 2) LCD ghosting: blend in the previous frame
  lg.setColor(1, 1, 1, 0.35)
  lg.draw(self.ghost)
  lg.pop()

  -- 3) the console around it
  lg.setColor(gfx.hex("#2d2b3a"))
  lg.rectangle("fill", 0, 0, 1280, 720)
  bezel()
  lg.setColor(1, 1, 1)
  lg.draw(self.screen, SX, SY, 0, SCALE, SCALE)
  -- 4) pixel grid: thin lines between the big pixels
  lg.setColor(SHADES[4][1], SHADES[4][2], SHADES[4][3], 0.12)
  lg.setLineWidth(1)
  for x = 0, PW do lg.line(SX + x * SCALE, SY, SX + x * SCALE, SY + PH * SCALE) end
  for y = 0, PH do lg.line(SX, SY + y * SCALE, SX + PW * SCALE, SY + y * SCALE) end
  -- glass reflection
  lg.setColor(1, 1, 1, 0.05)
  lg.polygon("fill", SX, SY, SX + 260, SY, SX, SY + 200)
  lg.setCanvas({ view.canvas, stencil = true })
end

return S
