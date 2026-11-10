-- Comic-book toolkit shared by the extra Comic scenes. (The first scene keeps its own
-- inline copy so it reads as one self-contained recipe.)
--
--   kit.halftone(cell)              -- CMY halftone shader: draw a colour canvas with it
--   kit.page(colorCanvas, colorFn, inkFn, shader)  -- the two-pass print: colour, then ink
--   kit.shape(pts, fill)            -- helpers to fill in the colour pass ...
--   kit.ink(pts, width)             -- ... and outline in the ink pass
--   kit.balloon / kit.caption / kit.burst / kit.sfx / kit.speedLines
--   kit.clip(poly, fn)              -- draw inside a (convex) panel shape

local gfx = require("core.gfx")
local lg = love.graphics
local kit = {}

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

function kit.halftone(cell)
  local sh = lg.newShader(HALFTONE)
  sh:send("cell", cell or 6)
  return sh
end

-- Colour pass into `canvas`, printed through the halftone shader; then crisp inks.
function kit.page(canvas, shader, colorFn, inkFn)
  lg.push("all")
  lg.setCanvas({ canvas, stencil = true })
  lg.clear(0, 0, 0, 0)
  colorFn()
  lg.pop()
  lg.setColor(gfx.hex("#fbf7ec"))
  lg.rectangle("fill", -40, -40, 1360, 800)
  lg.setShader(shader)
  lg.setColor(1, 1, 1)
  lg.draw(canvas)
  lg.setShader()
  inkFn()
end

function kit.clip(poly, fn)
  lg.stencil(function() lg.polygon("fill", poly) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  fn()
  lg.setStencilTest()
end

-- a (possibly concave) filled shape
function kit.shape(pts, color)
  lg.setColor(color)
  if not pcall(function()
    for _, t in ipairs(love.math.triangulate(pts)) do lg.polygon("fill", t) end
  end) then lg.polygon("fill", pts) end
end

function kit.ink(pts, width, open)
  lg.setColor(0.04, 0.04, 0.05)
  lg.setLineWidth(width or 4)
  lg.setLineJoin("bevel")
  if open then lg.line(pts) else lg.polygon("line", pts) end
  lg.setLineJoin("miter")
end

function kit.balloon(text, cx, cy, w, h, tx, ty, font)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", cx - 18, cy + h * 0.3, cx + 18, cy + h * 0.3, tx, ty)
  lg.ellipse("fill", cx, cy, w / 2, h / 2)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.ellipse("line", cx, cy, w / 2, h / 2)
  lg.line(cx - 18, cy + h * 0.42, tx, ty, cx + 18, cy + h * 0.42)
  lg.setColor(1, 1, 1)
  lg.polygon("fill", cx - 16, cy + h * 0.36, cx + 16, cy + h * 0.36, cx, cy + h * 0.5)
  lg.setFont(font)
  lg.setColor(0.05, 0.05, 0.05)
  local _, lines = font:getWrap(text, w - 40)
  lg.printf(text, cx - w / 2 + 20, cy - #lines * font:getHeight() / 2, w - 40, "center")
end

function kit.caption(text, x, y, w, font, color)
  local _, lines = font:getWrap(text, w - 20)
  local h = #lines * font:getHeight() + 14
  lg.setColor(color or { gfx.hex("#ffe36e") })
  lg.rectangle("fill", x, y, w, h)
  lg.setColor(0, 0, 0)
  lg.setLineWidth(3)
  lg.rectangle("line", x, y, w, h)
  lg.setFont(font)
  lg.printf(text, x + 10, y + 7, w - 20, "left")
  return h
end

-- jagged star outline (points list)
function kit.burst(cx, cy, r1, r2, n, squash, rot)
  local pts = {}
  for i = 0, n * 2 - 1 do
    local a = i / (n * 2) * math.pi * 2 + (rot or 0)
    local r = (i % 2 == 0) and r1 or r2
    pts[#pts + 1] = cx + math.cos(a) * r
    pts[#pts + 1] = cy + math.sin(a) * r * (squash or 1)
  end
  return pts
end

function kit.fillBurst(pts, cx, cy, color)
  lg.setColor(color)
  for i = 1, #pts, 2 do
    local j = (i + 2 > #pts) and 1 or i + 2
    lg.polygon("fill", cx, cy, pts[i], pts[i + 1], pts[j], pts[j + 1])
  end
end

-- bold lettering with a 3D extrude and an outline
function kit.sfx(text, x, y, font, fill, extrude, depth, limit, align)
  lg.setFont(font)
  local function put(ox, oy)
    if limit then lg.printf(text, x + ox, y + oy, limit, align or "center") else lg.print(text, x + ox, y + oy) end
  end
  for k = depth or 8, 1, -1 do
    lg.setColor(extrude[1] * (1 - k * 0.03), extrude[2] * (1 - k * 0.03), extrude[3] * (1 - k * 0.03))
    put(k * 1.5, k * 1.5)
  end
  lg.setColor(0, 0, 0)
  for dx = -1, 1 do for dy = -1, 1 do if dx ~= 0 or dy ~= 0 then
    put(dx * 3, dy * 3)
    put(dx * 1.5, dy * 1.5)
  end end end
  lg.setColor(fill)
  put(0, 0)
  put(1, 0)       -- a second pass, one pixel over, fakes a bolder weight
end

function kit.speedLines(cx, cy, n, r1, r2, wob)
  lg.setColor(0.04, 0.04, 0.05)
  for k = 0, n - 1 do
    local a = k / n * math.pi * 2 + (wob or 0) * math.sin(k * 12.9)
    local rr = r1 + (k % 3) * r1 * 0.14
    lg.polygon("fill", cx + math.cos(a) * rr, cy + math.sin(a) * rr,
      cx + math.cos(a + 0.02) * r2, cy + math.sin(a + 0.02) * r2,
      cx + math.cos(a - 0.02) * r2, cy + math.sin(a - 0.02) * r2)
  end
end

return kit
