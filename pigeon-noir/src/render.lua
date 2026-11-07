-- Drawing the city, and the two-tone comic noir look.
--
-- Everything is drawn in GREYS, plus two spot colours: red and yellow. Then the whole
-- frame goes through a shader that:
--   * keeps strongly saturated pixels (the spot colours) as flat colour
--   * crushes everything else to pure black or pure white around 50% brightness,
--     with a little noise in the threshold so edges come out gritty, like ink on cheap
--     paper
-- So "grey 0.7" means "this will be white" and "grey 0.2" means "this will be black".
-- Light cones are just pale polygons: after the threshold they become hard white
-- shapes, and anything dark in front of them turns into a silhouette.

local city = require("src.city")

local lg = love.graphics
local R = {}

local TWO_TONE = [[
uniform float time;
uniform float invert;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 c = Texel(tex, uv).rgb;
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  vec3 outc;
  if (mx - mn > 0.32) {
    outc = c;                                   // spot colour survives
  } else {
    float l = dot(c, vec3(0.3, 0.59, 0.11));
    float grit = (hash(floor(sc / 2.0) + floor(time * 12.0)) - 0.5) * 0.14;
    outc = vec3(smoothstep(0.47, 0.53, l + grit));
  }
  outc = mix(outc, 1.0 - outc, invert);
  return vec4(outc, 1.0);
}
]]

function R.load()
  R.shader = lg.newShader(TWO_TONE)
  R.scene = lg.newCanvas(1280, 720)
  local d = love.image.newImageData(64, 64)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / 32 - 1, (y + 0.5) / 32 - 1
    local r = math.min(1, math.sqrt(dx * dx + dy * dy))
    return 1, 1, 1, (1 - r) ^ 2
  end)
  R.blob = lg.newImage(d)
  R.font = lg.newFont(34)
  love.math.setRandomSeed(1947)
  R.far, R.mid = {}, {}
  local x = -200
  while x < 3200 do
    local w = love.math.random(60, 140)
    R.far[#R.far + 1] = { x = x, w = w, top = love.math.random(200, 380) }
    x = x + w + love.math.random(0, 10)
  end
  x = -200
  while x < 4800 do
    local w = love.math.random(90, 200)
    R.mid[#R.mid + 1] = { x = x, w = w, top = love.math.random(260, 430), tower = love.math.random() < 0.3 }
    x = x + w + love.math.random(10, 40)
  end
  R.rain = {}
  for i = 1, 420 do
    R.rain[i] = { x = love.math.random(-100, 1380), y = love.math.random(-720, 720), v = love.math.random(1100, 1600), l = love.math.random(18, 40) }
  end
  R.splashes = {}
end

function R.updateRain(dt)
  for _, r in ipairs(R.rain) do
    r.y = r.y + r.v * dt
    r.x = r.x - r.v * 0.15 * dt
    if r.y > 720 then
      if love.math.random() < 0.25 then
        R.splashes[#R.splashes + 1] = { x = r.x, y = love.math.random(605, 715), t = 0 }
      end
      r.y, r.x = r.y - 780 - love.math.random(0, 200), love.math.random(-100, 1500)
    end
  end
  for i = #R.splashes, 1, -1 do
    local s = R.splashes[i]
    s.t = s.t + dt
    if s.t > 0.2 then table.remove(R.splashes, i) end
  end
end

local function grey(v, a) lg.setColor(v, v, v, a or 1) end
local RED = { 0.9, 0.08, 0.08 }
local YELLOW = { 1, 0.85, 0.1 }

-- Sky, moon and the two skyline layers (screen space, parallax).
function R.backdrop(camX, flash, t, moonX, moonY)
  grey(flash > 0 and 0.95 or 0.07)
  lg.rectangle("fill", 0, 0, 1280, 720)
  if flash <= 0 then
    local mx, my = (moonX or 860) - camX * 0.04, moonY or 150
    grey(0.95)
    lg.circle("fill", mx, my, 70)
    grey(0.07)
    lg.circle("fill", mx + 25, my - 12, 62)  -- a thin crescent
  end
  for _, b in ipairs(R.far) do
    local x = b.x - camX * 0.25
    if x > -150 and x < 1300 then
      grey(0.08)
      lg.rectangle("fill", x, b.top, b.w, 720)
      if flash <= 0 then
        grey(0.7)
        lg.setLineWidth(1)
        lg.line(x, 720, x, b.top, x + b.w, b.top)
        for wy = b.top + 14, 560, 22 do
          for wx = x + 8, x + b.w - 10, 16 do
            if (math.floor(wx + b.top) * 7 + wy) % 11 == 0 then lg.rectangle("fill", wx, wy, 5, 7) end
          end
        end
      end
    end
  end
  for _, b in ipairs(R.mid) do
    local x = b.x - camX * 0.5
    if x > -220 and x < 1300 then
      grey(0.05)
      lg.rectangle("fill", x, b.top, b.w, 720)
      if b.tower then
        lg.rectangle("fill", x + b.w * 0.6, b.top - 46, 30, 30)
        lg.rectangle("fill", x + b.w * 0.6 + 4, b.top - 16, 3, 16)
        lg.rectangle("fill", x + b.w * 0.6 + 23, b.top - 16, 3, 16)
      end
      if flash <= 0 then
        grey(0.8)
        lg.setLineWidth(2)
        lg.line(x + b.w, 720, x + b.w, b.top)
        for wy = b.top + 18, 560, 30 do
          for wx = x + 10, x + b.w - 14, 22 do
            if (math.floor(wx * 3 + b.top) + wy) % 7 == 0 then lg.rectangle("fill", wx, wy, 8, 12) end
          end
        end
      end
    end
  end
end

local function neon(text, x, y, t, vertical, seed)
  local on = math.sin(t * 7 + seed) > -0.85 and not (math.sin(t * 1.3 + seed) > 0.97)
  if not on then return end
  lg.setColor(RED[1], RED[2], RED[3], 0.35)
  lg.draw(R.blob, x, y, 0, vertical and 2.2 or 4, vertical and 5 or 1.8, 32, 32)
  lg.setColor(RED)
  lg.setFont(R.font)
  if vertical then
    for i = 1, #text do lg.printf(text:sub(i, i), x - 30, y - #text * 19 + (i - 1) * 38, 60, "center") end
  else
    lg.printf(text, x - 150, y - 20, 300, "center")
  end
end

function R.building(b, t, signs, flash)
  local x1, x2, top = b.x1, b.x2, b.top
  grey(0.1)
  lg.rectangle("fill", x1, top, x2 - x1, city.SIDEWALK - top)
  if flash > 0 then return end
  -- moonlit rim on the left edge and along the roof
  grey(0.9)
  lg.setLineWidth(3)
  lg.line(x1, city.SIDEWALK, x1, top, x2, top)
  -- windows: some lit, some with somebody standing in them
  local cols = math.floor((x2 - x1 - 40) / 60)
  for wy = top + 40, city.SIDEWALK - 110, 90 do
    for c = 0, cols - 1 do
      local wx = x1 + 30 + c * 60
      local h = (math.floor(wx) * 31 + wy * 7) % 17
      if h < 6 then
        grey(0.88)
        lg.rectangle("fill", wx, wy, 30, 44)
        if h == 0 then -- a silhouette in the window
          grey(0.05)
          lg.circle("fill", wx + 15, wy + 16, 6)
          lg.rectangle("fill", wx + 7, wy + 24, 16, 20)
        elseif h == 1 then -- venetian blinds
          grey(0.05)
          for k = 0, 4 do lg.rectangle("fill", wx, wy + 4 + k * 9, 30, 4) end
        end
      else
        grey(0.85)
        lg.setLineWidth(1)
        lg.rectangle("line", wx, wy, 30, 44)
      end
    end
  end
  if b.sign then
    local text = signs[b.sign]
    if b.kind == "hotel" then neon(text, x1 + 60, top + 220, t, true, x1)
    elseif b.kind == "diner" then neon(text, (x1 + x2) / 2 - 60, top + 40, t, false, x1)
    else neon(text, (x1 + x2) / 2, top + 50, t, false, x1) end
  end
  -- a door
  grey(0.85)
  lg.setLineWidth(2)
  lg.rectangle("line", x2 - 90, city.SIDEWALK - 70, 40, 70)
end

function R.escape(e)
  grey(0.8)
  lg.setLineWidth(2)
  for i, y in ipairs(e.levels) do
    lg.line(e.x1, y, e.x2, y)
    lg.line(e.x1, y - 22, e.x2, y - 22)
    for x = e.x1, e.x2, 12 do lg.line(x, y, x, y - 22) end
    local below = e.levels[i - 1] or city.SIDEWALK - 60
    lg.line(e.x2 - 10, y, e.x1 + 10, below) -- zig-zag ladder down
  end
end

local cones = {}
function R.lamp(l, t)
  -- The cone is a pale gradient: bright at the bulb, fading toward 50% grey at the
  -- ground. After the threshold (with its grit) that becomes hard white light whose
  -- lower edge crumbles like dry-brushed ink.
  local h = city.ROAD + 20 - l.y
  if not cones[h] then
    cones[h] = lg.newMesh({
      { -10, 8, 0, 0, 0.85, 0.85, 0.85, 1 }, { 10, 8, 0, 0, 0.85, 0.85, 0.85, 1 },
      { 100, h, 0, 0, 0.47, 0.47, 0.47, 1 }, { -100, h, 0, 0, 0.47, 0.47, 0.47, 1 },
    }, "fan", "static")
  end
  lg.setColor(1, 1, 1)
  lg.draw(cones[h], l.x, l.y)
  grey(0.04)
  lg.rectangle("fill", l.x - 3, l.y, 6, city.SIDEWALK - l.y)
  lg.rectangle("fill", l.x - 18, l.y - 6, 36, 10)
  grey(0.95)
  lg.rectangle("fill", l.x - 10, l.y + 4, 20, 5)
end

function R.awning(s)
  for k = 0, math.floor((s.x2 - s.x1) / 20) - 1 do
    grey(k % 2 == 0 and 0.9 or 0.08)
    lg.polygon("fill", s.x1 + k * 20, s.y, s.x1 + k * 20 + 20, s.y, s.x1 + k * 20 + 24, s.y + 22, s.x1 + k * 20 + 4, s.y + 22)
  end
  grey(0.9)
  lg.setLineWidth(2)
  if s.bus then
    lg.line(s.x1 + 6, s.y, s.x1 + 6, city.SIDEWALK)
    lg.line(s.x2 - 6, s.y, s.x2 - 6, city.SIDEWALK)
    lg.rectangle("line", s.x1 + 20, s.y + 40, s.x2 - s.x1 - 40, 50)
  end
end

function R.street(camX, signsGlow)
  grey(0.12)
  lg.rectangle("fill", camX - 10, city.SIDEWALK, 1300, city.ROAD - city.SIDEWALK - 20)
  grey(0.9)
  lg.rectangle("fill", camX - 10, city.SIDEWALK, 1300, 3)
  grey(0.05)
  lg.rectangle("fill", camX - 10, city.ROAD - 20, 1300, 100)
  grey(0.85)
  lg.rectangle("fill", camX - 10, city.ROAD - 22, 1300, 3)       -- curb edge
  local x0 = math.floor(camX / 120) * 120
  for x = x0, camX + 1300, 120 do lg.rectangle("fill", x, 700, 60, 4) end
end

-- Wet asphalt: lights smear into vertical streaks on the road.
function R.reflections(c, camX, t)
  for _, l in ipairs(c.lamps) do
    for k = 0, 5 do
      grey(0.7, 0.8)
      lg.rectangle("fill", l.x - 40 + k * 16 + math.sin(t * 3 + k) * 2, city.ROAD + 4, 4, 30 + (k % 3) * 10)
    end
  end
  for _, b in ipairs(c.buildings) do
    if b.sign then
      local x = (b.x1 + b.x2) / 2
      for k = 0, 6 do
        lg.setColor(RED[1], RED[2], RED[3], 0.7)
        lg.rectangle("fill", x - 50 + k * 15 + math.sin(t * 2 + k) * 3, city.ROAD + 6, 3, 18 + (k % 4) * 8)
      end
    end
  end
end

function R.vent(v, t)
  grey(0.85)
  lg.setLineWidth(2)
  lg.ellipse("line", v.x, city.SIDEWALK + 6, 30, 5)
  for k = 0, 7 do
    local p = (t * 0.5 + k / 8) % 1
    grey(0.75, 0.9 * (1 - p))
    lg.circle("fill", v.x + math.sin(p * 7 + k) * 14, city.SIDEWALK - p * 160, 8 + p * 26)
  end
end

function R.trash(tr)
  local x, y = tr.x, city.SIDEWALK
  if tr.knocked then
    grey(0.06)
    lg.rectangle("fill", x - 30, y - 28, 56, 28, 4)
    grey(0.9)
    lg.setLineWidth(2)
    lg.rectangle("line", x - 30, y - 28, 56, 28, 4)
    lg.ellipse("line", x + 30, y - 14, 6, 14)
  else
    grey(0.06)
    lg.rectangle("fill", x - 20, y - 52, 40, 52)
    grey(0.9)
    lg.setLineWidth(2)
    lg.rectangle("line", x - 20, y - 52, 40, 52)
    lg.line(x - 24, y - 54, x + 24, y - 54)
    for k = -1, 1 do lg.line(x + k * 10, y - 46, x + k * 10, y - 6) end
  end
end

function R.crumb(cr, t)
  if not cr.alive then return end
  lg.setColor(YELLOW)
  local bob = math.sin(t * 4 + cr.x) * 1
  lg.ellipse("fill", cr.x, cr.y - 3 + bob, cr.food > 15 and 6 or 4, 3)
  lg.ellipse("fill", cr.x + 7, cr.y - 2 + bob, 3, 2)
end

function R.cat(cat, t)
  local x, y, d = cat.x, cat.y, cat.dir
  local crouch = (cat.state == "stalk") and 8 or 0
  local function shape()
    lg.ellipse("fill", x, y - 20 + crouch / 2, 26, 14 - crouch / 3)
    lg.circle("fill", x + d * 24, y - 34 + crouch, 12)
    lg.polygon("fill", x + d * 16, y - 42 + crouch, x + d * 20, y - 56 + crouch, x + d * 26, y - 44 + crouch)
    lg.polygon("fill", x + d * 26, y - 44 + crouch, x + d * 34, y - 56 + crouch, x + d * 34, y - 40 + crouch)
    local sw = math.sin(t * 3 + cat.home) * 10
    lg.setLineWidth(6)
    lg.line(x - d * 24, y - 22, x - d * 40, y - 40 + sw, x - d * 36, y - 60 + sw)
    lg.rectangle("fill", x - 18, y - 12, 7, 12)
    lg.rectangle("fill", x + 12, y - 12, 7, 12)
  end
  -- white rim, then the black cat: silhouettes need an edge on a black street
  lg.push()
  grey(0.9)
  for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
    lg.push()
    lg.translate(o[1], o[2])
    shape()
    lg.pop()
  end
  grey(0.03)
  shape()
  lg.pop()
  lg.setColor(YELLOW)
  local open = (cat.state == "idle" and math.sin(t * 0.7 + cat.home) > 0.9) and 0.3 or 2.5
  lg.ellipse("fill", x + d * 20, y - 36 + crouch, 3, open)
  lg.ellipse("fill", x + d * 29, y - 36 + crouch, 3, open)
end

function R.car(car, t)
  local x, y, d = car.x, city.ROAD, car.dir
  -- headlight beam reaches far ahead: the warning you get before the car arrives
  grey(0.66)
  lg.polygon("fill", x + d * 70, y - 26, x + d * 520, y - 70, x + d * 520, y + 30)
  lg.setColor(YELLOW)
  lg.polygon("fill", x - 80, y - 4, x + 80, y - 4, x + 70, y - 30, x + 40, y - 34, x + 20, y - 58, x - 34, y - 58, x - 54, y - 34, x - 76, y - 30)
  grey(0.05)
  lg.polygon("fill", x - 26, y - 52, x + 14, y - 52, x + 30, y - 34, x - 44, y - 34)
  lg.rectangle("fill", x - 80, y - 18, 160, 5)
  lg.circle("fill", x - 48, y, 13)
  lg.circle("fill", x + 48, y, 13)
  grey(0.9)
  lg.circle("fill", x - 48, y, 5)
  lg.circle("fill", x + 48, y, 5)
  lg.rectangle("fill", x - 12, y - 66, 24, 8) -- roof sign
  lg.setColor(RED)
  lg.rectangle("fill", x - d * 80 - 3, y - 26, 6, 8)
end

function R.coop(c, t, sal)
  local x, y = c.x, c.y
  grey(0.9)
  lg.setLineWidth(2)
  lg.rectangle("line", x - 70, y - 60, 140, 60)
  for k = -60, 60, 14 do lg.line(x + k, y - 60, x + k, y) end
  lg.polygon("line", x - 80, y - 60, x, y - 92, x + 80, y - 60)
  -- Sal's lit window on the floor below: the only warm colour in the whole city
  lg.setColor(YELLOW)
  lg.rectangle("fill", x + 90, y + 40, 60, 80)
  grey(0.05)
  lg.circle("fill", x + 120, y + 70, 10)
  lg.rectangle("fill", x + 104, y + 82, 32, 38)
  if sal then
    grey(0.9)
    lg.circle("fill", x - 30, y - 22, 7)
    lg.circle("fill", x + 20, y - 22, 7)
  end
end

-- Draw the scene canvas through the two-tone shader.
function R.present(t, invert)
  R.shader:send("time", t)
  R.shader:send("invert", invert or 0)
  lg.setShader(R.shader)
  lg.setColor(1, 1, 1)
  lg.draw(R.scene)
  lg.setShader()
end

-- Rain on top of everything, crisp white.
function R.rainDraw(sheltered)
  lg.setLineWidth(1.5)
  for _, r in ipairs(R.rain) do
    lg.setColor(1, 1, 1, 0.55)
    lg.line(r.x, r.y, r.x + r.l * 0.15, r.y - r.l)
  end
  for _, s in ipairs(R.splashes) do
    lg.setColor(1, 1, 1, 0.8 * (1 - s.t / 0.2))
    lg.ellipse("line", s.x, s.y, 3 + s.t * 30, 1 + s.t * 5)
  end
end

return R
