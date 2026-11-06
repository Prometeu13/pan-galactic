-- COMIC BOOK: a three-panel page printed in halftone dots.
--
-- Colour and ink are separate passes, like real comics:
--   1. colour fills (skies, glows, metal) are drawn into a canvas...
--   2. ...and printed through a halftone shader: the colour is split into cyan,
--      magenta and yellow, and each ink becomes a grid of dots (rotated to its own
--      angle) whose size follows how much of that ink is needed
--   3. black line art, lettering, balloons and sound effects go on top, crisp
-- The impact panel loops: the burst pops in, debris flies and the page shakes.

local gfx = require("core.gfx")
local Draft = require("draft")
local flux = require("flux")
local shack = require("shack")

local lg = love.graphics
local P1 = { 30, 62, 1220, 316 }
local P2 = { 30, 396, 520, 296 }
local P3 = { 570, 396, 680, 296 }

local S = {
  title = "Comic Book",
  subtitle = "Neon City Nights",
  blurb = "A comic page: CMY halftone colour, bold black inks, caption box, speech and shout balloons, speed lines and a sound effect.",
  techniques = {
    "Colour pass printed through a CMY halftone shader (rotated dot screens)",
    "Ink pass on top: thick outlines, silhouettes, lettering",
    "Balloons: ellipse + tail, or a jagged star for shouting (draft)",
    "Speed lines: thin black triangles radiating from the impact point",
    "SFX lettering: stacked offset copies for a 3D extrude, then a pop tween",
  },
  libs = {
    "draft: burst stars and the jagged shout balloon",
    "flux: the SFX pop and debris timing",
    "shack: page shake on impact",
  },
  genres = { "Superhero and action brawlers", "Story cutscenes and motion comics", "Card games and character reveal screens", "Satirical / pop-art puzzle games" },
  warmup = 2.6,
}

local HALFTONE = [[
uniform float cell;
float dots(vec2 sc, float angle, float amount) {
  float c = cos(angle), s = sin(angle);
  vec2 p = mat2(c, -s, s, c) * sc / cell;
  vec2 f = fract(p) - 0.5;
  float r = sqrt(clamp(amount, 0.0, 1.0)) * 0.62;
  return smoothstep(r + 0.07, r - 0.07, length(f));
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 src = Texel(tex, uv);
  if (src.a < 0.01) return vec4(0.0);
  vec3 cmy = 1.0 - src.rgb;
  vec3 paper = vec3(0.98, 0.96, 0.9);
  vec3 col = paper;
  col *= mix(vec3(1.0), vec3(0.0, 0.68, 0.94), dots(sc, 0.26, cmy.r));   // cyan, 15 degrees
  col *= mix(vec3(1.0), vec3(0.93, 0.0, 0.55), dots(sc, 1.31, cmy.g));   // magenta, 75 degrees
  col *= mix(vec3(1.0), vec3(1.0, 0.93, 0.0), dots(sc, 0.0, cmy.b));     // yellow, 0 degrees
  return vec4(col, 1.0);
}
]]

local function inside(p, f)
  lg.setScissor(p[1], p[2], p[3], p[4])
  f(p[1], p[2], p[3], p[4])
  lg.setScissor()
end

function S:load()
  self.t = 0
  self.flux = flux.group()
  self.draft = Draft("fill")
  self.halftone = lg.newShader(HALFTONE)
  self.halftone:send("cell", 6)
  self.colorCanvas = lg.newCanvas(1280, 720)
  self.sky = gfx.vgradient(P1[3], P1[4], { { 0, gfx.rgb("#2a1d6e") }, { 0.7, gfx.rgb("#c4508f") }, { 1, gfx.rgb("#f2a35a") } })
  self.font = lg.newFont(20)
  self.bold = lg.newFont(26)
  self.sfxFont = lg.newFont(78)
  love.math.setRandomSeed(66)
  self.skyline = {}
  local x = P1[1]
  while x < P1[1] + P1[3] do
    local w = love.math.random(50, 110)
    self.skyline[#self.skyline + 1] = { x, w, love.math.random(80, 220) }
    x = x + w + love.math.random(4, 14)
  end
  self.sfx = { scale = 0, rot = -0.15 }
  self.debris = {}
  shack:setDimensions(1280, 720)
  self:impact()
end

function S:impact()
  local s = self.sfx
  s.scale = 0.2
  self.flux:to(s, 0.35, { scale = 1 }):ease("backout")
  shack:setShake(14)
  self.debris = {}
  for k = 1, 14 do
    local a = love.math.random() * math.pi * 2
    self.debris[k] = { x = 910, y = 545, vx = math.cos(a) * love.math.random(150, 380), vy = math.sin(a) * love.math.random(150, 380), r = love.math.random() * 6, s = love.math.random(5, 12) }
  end
  self.nextImpact = 3.2
end

function S:update(dt)
  self.t = self.t + dt
  self.flux:update(dt)
  shack:update(dt)
  for _, d in ipairs(self.debris) do
    d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
    d.vy = d.vy + 300 * dt
    d.r = d.r + dt * 6
  end
  self.nextImpact = self.nextImpact - dt
  if self.nextImpact <= 0 then self:impact() end
end

-- 1) colour fills only
function S:drawColor()
  inside(P1, function(x, y, w, h)
    lg.setColor(1, 1, 1)
    lg.draw(self.sky, x, y)
    lg.setColor(gfx.hex("#fff3a0"))
    lg.circle("fill", 470, 205, 105) -- the moon, right behind the heroine
    for _, b in ipairs(self.skyline) do
      lg.setColor(gfx.hex("#3a2a7a"))
      lg.rectangle("fill", b[1], y + h - b[3], b[2], b[3])
      lg.setColor(gfx.hex("#ffd36e"))
      for wy = y + h - b[3] + 12, y + h - 14, 22 do
        for wx = b[1] + 8, b[1] + b[2] - 14, 18 do
          if gfx.hash(wx * 3 + wy) > 0.5 then lg.rectangle("fill", wx, wy, 8, 10) end
        end
      end
    end
    lg.setColor(gfx.hex("#1d1550"))
    lg.rectangle("fill", 330, y + h - 70, 320, 70)
  end)
  inside(P2, function(x, y, w, h)
    lg.setColor(gfx.hex("#ff6a3d"))
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(gfx.hex("#ffb347"))
    lg.circle("fill", x + w * 0.45, y + h * 0.55, 160)
    lg.push()
    lg.translate(-80, 10) -- robot sits left of centre, leaving room for its shout
    -- robot head metal
    lg.setColor(gfx.hex("#9aa4b8"))
    lg.rectangle("fill", x + 120, y + 60, 230, 210, 30)
    lg.setColor(gfx.hex("#6b7488"))
    lg.rectangle("fill", x + 150, y + 190, 170, 50, 8)
    local pulse = 0.6 + 0.4 * math.sin(self.t * 6)
    lg.setColor(1, 0.25 * pulse, 0.15)
    lg.circle("fill", x + 290, y + 130, 34)
    lg.pop()
  end)
  inside(P3, function(x, y, w, h)
    lg.setColor(gfx.hex("#fff060"))
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(gfx.hex("#ff8a30"))
    lg.circle("fill", 910, 545, 200)
    lg.setColor(gfx.hex("#ff3d3d"))
    lg.circle("fill", 910, 545, 90)
  end)
end

function S:balloon(text, cx, cy, w, h, tx, ty)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", cx - 18, cy + h * 0.3, cx + 18, cy + h * 0.3, tx, ty)
  lg.ellipse("fill", cx, cy, w / 2, h / 2)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.ellipse("line", cx, cy, w / 2, h / 2)
  lg.line(cx - 18, cy + h * 0.42, tx, ty, cx + 18, cy + h * 0.42)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", cx - 16, cy + h * 0.36, cx + 16, cy + h * 0.36, cx, cy + h * 0.5)
  lg.setFont(self.font)
  lg.setColor(0.05, 0.05, 0.05)
  lg.printf(text, cx - w / 2 + 20, cy - 24, w - 40, "center")
end

-- 3) black inks, balloons and lettering
function S:drawInk()
  lg.setColor(0, 0, 0)
  -- panel 1: skyline outlines, the heroine on the roof
  inside(P1, function(x, y, w, h)
    lg.setLineWidth(3)
    for _, b in ipairs(self.skyline) do lg.rectangle("line", b[1], y + h - b[3], b[2], b[3]) end
    lg.circle("line", 470, 205, 105)
    local hx, hy = 470, y + h - 70
    local flutter = math.sin(self.t * 5) * 14
    lg.polygon("fill", hx - 6, hy - 92, hx - 70 + flutter, hy - 20, hx - 40 + flutter, hy - 6, hx + 4, hy - 80)
    lg.polygon("fill", hx - 14, hy - 100, hx + 14, hy - 100, hx + 18, hy - 46, hx - 18, hy - 46)
    lg.polygon("fill", hx - 18, hy - 46, hx - 4, hy - 46, hx - 10, hy, hx - 22, hy)
    lg.polygon("fill", hx + 4, hy - 46, hx + 18, hy - 46, hx + 22, hy, hx + 10, hy)
    lg.circle("fill", hx, hy - 112, 13)
    lg.polygon("fill", hx - 8, hy - 122, hx - 14, hy - 138, hx - 2, hy - 124)
    lg.polygon("fill", hx + 8, hy - 122, hx + 14, hy - 138, hx + 2, hy - 124)
    -- caption box
    lg.setColor(gfx.hex("#ffe36e"))
    lg.rectangle("fill", x + 16, y + 14, 420, 44)
    lg.setColor(0, 0, 0)
    lg.rectangle("line", x + 16, y + 14, 420, 44)
    lg.setFont(self.font)
    lg.print("MEANWHILE, HIGH ABOVE NEON CITY...", x + 28, y + 24)
  end)
  self:balloon("Something's not right tonight...", 760, 140, 300, 100, 500, 210)

  -- panel 2: robot linework and a shout balloon
  inside(P2, function(x, y, w, h)
    lg.push()
    lg.translate(-80, 10)
    lg.setLineWidth(5)
    lg.rectangle("line", x + 120, y + 60, 230, 210, 30)
    lg.setLineWidth(3)
    lg.rectangle("line", x + 150, y + 190, 170, 50, 8)
    for k = 0, 5 do lg.line(x + 170 + k * 26, y + 190, x + 170 + k * 26, y + 240) end
    lg.circle("line", x + 290, y + 130, 34)
    lg.circle("fill", x + 290, y + 130, 12)
    lg.rectangle("fill", x + 150, y + 110, 70, 18)
    for _, r in ipairs({ { 140, 80 }, { 330, 80 }, { 140, 250 }, { 330, 250 } }) do lg.circle("fill", x + r[1], y + r[2], 5) end
    lg.line(x + 235, y + 60, x + 235, y + 20)
    lg.circle("fill", x + 235, y + 18, 7)
    lg.pop()
  end)
  local shout = self.draft:star(420, 470, 230, 180, 16, 0, false)
  for i = 2, #shout, 2 do shout[i] = 470 + (shout[i] - 470) * 0.6 end
  lg.setColor(1, 1, 1)
  self.draft:polygon(shout, "fill")
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.polygon("line", shout)
  lg.setFont(self.bold)
  lg.printf("SURRENDER, HUMAN!", 330, 440, 180, "center")

  -- panel 3: speed lines, burst, SFX, debris
  inside(P3, function(x, y, w, h)
    for k = 0, 47 do
      local a = k / 48 * math.pi * 2 + 0.02 * math.sin(self.t * 20 + k)
      local r1, r2 = 140 + (k % 3) * 20, 520
      lg.polygon("fill", 910 + math.cos(a) * r1, 545 + math.sin(a) * r1,
        910 + math.cos(a + 0.025) * r2, 545 + math.sin(a + 0.025) * r2,
        910 + math.cos(a - 0.025) * r2, 545 + math.sin(a - 0.025) * r2)
    end
    for _, d in ipairs(self.debris) do
      lg.push()
      lg.translate(d.x, d.y)
      lg.rotate(d.r)
      lg.polygon("fill", -d.s, -d.s * 0.4, d.s, -d.s * 0.6, d.s * 0.4, d.s * 0.7)
      lg.pop()
    end
    local s = self.sfx
    lg.push()
    lg.translate(910, 545)
    lg.rotate(s.rot)
    lg.scale(s.scale)
    local burst = self.draft:star(0, 0, 420, 250, 14, 0, false)
    lg.setColor(1, 1, 1)
    self.draft:polygon(burst, "fill")
    lg.setColor(0, 0, 0)
    lg.setLineWidth(5)
    lg.polygon("line", burst)
    lg.setFont(self.sfxFont)
    local text = "KRAKOOM!"
    local tw = self.sfxFont:getWidth(text)
    for k = 8, 1, -1 do -- 3D extrude: offset copies, darkest at the back
      lg.setColor(0.45 - k * 0.03, 0.05, 0.05)
      lg.print(text, -tw / 2 + k * 1.5, -46 + k * 1.5)
    end
    gfx.outlinedText(text, -tw / 2, -46, { 1, 0.85, 0.1 }, { 0, 0, 0 }, 3)
    lg.pop()
  end)

  -- panel borders
  lg.setColor(0, 0, 0)
  lg.setLineWidth(6)
  for _, p in ipairs({ P1, P2, P3 }) do lg.rectangle("line", p[1], p[2], p[3], p[4]) end
end

function S:draw()
  lg.push("all")
  lg.setCanvas(self.colorCanvas)
  lg.clear(0, 0, 0, 0)
  self:drawColor()
  lg.pop()

  lg.push()
  shack:apply()
  lg.setColor(gfx.hex("#fbf7ec"))
  lg.rectangle("fill", -40, -40, 1360, 800)
  lg.setShader(self.halftone)
  lg.setColor(1, 1, 1)
  lg.draw(self.colorCanvas)
  lg.setShader()
  self:drawInk()
  lg.pop()
end

return S
