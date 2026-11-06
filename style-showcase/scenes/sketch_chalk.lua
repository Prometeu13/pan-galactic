-- HAND-DRAWN, scene 2: a game designer's chalkboard.
--
-- Everything chalky is drawn in plain colours into one canvas, then that canvas is
-- drawn onto the board through a "chalk" shader. The shader throws away pixels where
-- a fine noise is low, so strokes come out grainy and broken like chalk dragged
-- across slate. The board itself is baked once: dark green with mottling and faint
-- eraser swipes from earlier lessons. One curve redraws itself forever, with a puff of
-- chalk dust at the tip.

local gfx = require("core.gfx")
local sketchy = require("core.sketchy")
local Draft = require("draft")

local lg = love.graphics
local BX, BY, BW, BH = 60, 40, 1160, 560

local S = {
  title = "Hand-Drawn",
  subtitle = "Chalkboard",
  blurb = "A boss-fight plan in chalk: grainy strokes from a noise shader, eraser smudges, coloured chalk and a curve that keeps drawing itself.",
  techniques = {
    "All chalk is drawn into a canvas, then shown through a grain shader",
    "Grain = discard pixels where fine noise is low (plus a softer second noise)",
    "Board baked once: mottled slate + faint eraser swipes",
    "Wobbly strokes and handwriting from a shared sketchy helper",
    "A curve drawn progressively, with chalk-dust particles at its tip",
  },
  libs = {
    "draft: the boss's crown (star) and the arena (circle polygon)",
    "(the chalk grain is a small inline GLSL shader)",
  },
  genres = { "Educational and maths games", "Puzzle games with a classroom theme", "Design docs / in-game planning screens", "Strategy briefing screens" },
  warmup = 5,
}

local CHALK = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv);
  float grain = hash(floor(sc * 0.9));
  float clump = vnoise(sc * 0.18);
  float keep = step(0.32, grain * 0.6 + clump * 0.55);
  return c * keep * (0.75 + 0.25 * clump) * color; // canvas is premultiplied: scale rgb and alpha
}
]]

local WHITE = { 0.95, 0.95, 0.9, 0.9 }
local YELLOW = { 1, 0.9, 0.45, 0.9 }
local PINK = { 1, 0.6, 0.7, 0.9 }
local BLUE = { 0.6, 0.85, 1, 0.9 }

local function bakeBoard()
  local w, h = BW / 2, BH / 2
  local d = love.image.newImageData(w, h)
  d:mapPixel(function(x, y)
    local n = gfx.fbm(x * 0.02, y * 0.02, 4)
    return 0.12 + n * 0.06, 0.22 + n * 0.07, 0.17 + n * 0.05, 1
  end)
  local c = lg.newCanvas(BW, BH)
  lg.push("all")
  lg.setCanvas(c)
  lg.setColor(1, 1, 1)
  lg.draw(lg.newImage(d), 0, 0, 0, 2, 2)
  -- old eraser swipes: wide faint arcs
  for _ = 1, 14 do
    local x, y = love.math.random(0, BW), love.math.random(0, BH)
    lg.setColor(1, 1, 1, 0.025)
    lg.setLineWidth(love.math.random(30, 70))
    local pts = {}
    for k = 0, 6 do
      pts[#pts + 1] = x + k * 40
      pts[#pts + 1] = y + math.sin(k * 0.9) * 30
    end
    lg.line(pts)
  end
  lg.pop()
  return c
end

function S:load()
  self.t = 0
  love.math.setRandomSeed(1234)
  self.board = bakeBoard()
  self.chalkShader = lg.newShader(CHALK)
  self.layer = lg.newCanvas(1280, 720)
  self.pen = sketchy.new({ wobble = 2.4 })
  self.draft = Draft("fill")
  self.big = lg.newFont(40)
  self.mid = lg.newFont(26)
  self.small = lg.newFont(19)
  self.dust = {}
end

function S:update(dt)
  self.t = self.t + dt
  self.pen:setSeed(math.floor(self.t * 2)) -- chalk lines barely move: a slow 2 Hz boil
  for i = #self.dust, 1, -1 do
    local p = self.dust[i]
    p.life = p.life - dt
    p.x, p.y, p.vy = p.x + p.vx * dt, p.y + p.vy * dt, p.vy + 60 * dt
    if p.life <= 0 then table.remove(self.dust, i) end
  end
  local tip = self.tip
  if tip and love.math.random() < 0.6 then
    self.dust[#self.dust + 1] = { x = tip[1], y = tip[2], vx = love.math.random(-20, 20), vy = love.math.random(-10, 10), life = 0.8 }
  end
end

function S:drawChalk()
  local pen = self.pen
  pen:write("BOSS FIGHT - PHASE 2", 110, 70, self.big, WHITE, 3, 0.6)
  pen:line(110, 122, 560, 118, YELLOW, 3)

  -- arena with the player and the boss
  local ax, ay, ar = 330, 330, 150
  pen:circle(ax, ay, ar, WHITE, 2.5)
  pen:circle(ax, ay, ar * 0.45, { 1, 1, 1, 0.4 }, 1.5)
  -- boss: blob with a crown
  pen:circle(ax + 40, ay - 30, 36, PINK, 3)
  local crown = self.draft:star(ax + 40, ay - 78, 46, 22, 5, -math.pi / 2, false)
  pen:poly(crown, YELLOW, 2.5)
  pen:circle(ax + 28, ay - 36, 4, PINK, 2)
  pen:circle(ax + 52, ay - 36, 4, PINK, 2)
  -- player stick figure
  local px, py = ax - 80, ay + 70
  pen:circle(px, py - 30, 10, BLUE, 2.5)
  pen:line(px, py - 20, px, py + 8, BLUE, 2.5)
  pen:line(px, py + 8, px - 10, py + 26, BLUE, 2.5)
  pen:line(px, py + 8, px + 10, py + 26, BLUE, 2.5)
  pen:line(px - 14, py - 10, px + 14, py - 10, BLUE, 2.5)
  -- attack patterns: dashed arcs + arrows
  for k = 0, 7 do
    local a = k / 8 * math.pi * 2
    pen:line(ax + 40 + math.cos(a) * 50, ay - 30 + math.sin(a) * 50, ax + 40 + math.cos(a) * 90, ay - 30 + math.sin(a) * 90, { 1, 1, 1, 0.55 }, 2)
  end
  pen:line(px + 20, py - 40, px + 70, py - 90, YELLOW, 2.5)
  pen:line(px + 70, py - 90, px + 52, py - 86, YELLOW, 2.5)
  pen:line(px + 70, py - 90, px + 66, py - 72, YELLOW, 2.5)
  pen:write("dodge!", px - 60, py + 40, self.small, YELLOW, 8)

  -- boss HP bar with hatching for the remaining half
  local hx, hy = 620, 170
  pen:poly({ hx, hy, hx + 300, hy, hx + 300, hy + 34, hx, hy + 34 }, WHITE, 2.5)
  pen:hatch(function() lg.rectangle("fill", hx, hy, 150, 34) end, hx, hy, 150, 34, PINK, 7, 2)
  pen:write("HP 1200 -> 600", hx + 320, hy + 2, self.small, WHITE, 4)
  pen:write("dmg = atk x 2 - def", 620, 240, self.mid, WHITE, 5)
  pen:write("enrage at 30%  (!!)", 620, 286, self.mid, PINK, 6)

  -- difficulty curve: axes + a curve that draws itself
  local gx, gy, gw, gh = 640, 360, 420, 200
  pen:line(gx, gy + gh, gx + gw, gy + gh, WHITE, 2.5)
  pen:line(gx, gy + gh, gx, gy, WHITE, 2.5)
  pen:write("time", gx + gw - 50, gy + gh + 8, self.small, WHITE, 9)
  pen:write("fun?", gx - 56, gy - 6, self.small, WHITE, 10)
  local progress = (self.t * 0.18) % 1.25
  local pts, tip = {}, nil
  for i = 0, 40 do
    local f = i / 40
    if f > progress then break end
    local y = gy + gh - (f * 0.75 + math.sin(f * 14) * 0.08) * gh
    pts[#pts + 1] = gx + f * gw
    pts[#pts + 1] = y
    tip = { gx + f * gw, y }
  end
  if #pts >= 4 then pen:path(pts, YELLOW, 3) end
  self.tip = (progress <= 1) and tip or nil
  pen:write("<- the 'flow' zone", gx + 230, gy + 40, self.small, BLUE, 11)
end

function S:draw()
  -- wall and wooden frame
  lg.setColor(gfx.hex("#5a4636"))
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setColor(gfx.hex("#7a5232"))
  lg.rectangle("fill", BX - 22, BY - 22, BW + 44, BH + 44, 6)
  lg.setColor(gfx.hex("#5e3d22"))
  lg.rectangle("line", BX - 22, BY - 22, BW + 44, BH + 44, 6)
  lg.setColor(1, 1, 1)
  lg.draw(self.board, BX, BY)

  -- chalk layer, then through the grain shader
  lg.push("all")
  lg.setCanvas({ self.layer, stencil = true })
  lg.clear(0, 0, 0, 0)
  self:drawChalk()
  lg.pop()
  lg.setShader(self.chalkShader)
  lg.setColor(1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(self.layer)
  lg.setBlendMode("alpha")
  lg.setShader()
  for _, p in ipairs(self.dust) do
    lg.setColor(1, 1, 0.8, p.life * 0.6)
    lg.circle("fill", p.x, p.y, 1.5)
  end

  -- chalk tray with sticks and an eraser
  lg.setColor(gfx.hex("#6b4529"))
  lg.rectangle("fill", BX - 30, BY + BH + 20, BW + 60, 26, 4)
  for i, c in ipairs({ WHITE, YELLOW, PINK, BLUE }) do
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", 300 + i * 70, BY + BH + 12, 52, 11, 5)
  end
  lg.setColor(gfx.hex("#3a3a40"))
  lg.rectangle("fill", 860, BY + BH + 2, 120, 26, 4)
  lg.setColor(gfx.hex("#d8d4c8"))
  lg.rectangle("fill", 860, BY + BH + 20, 120, 10, 3)
end

return S
