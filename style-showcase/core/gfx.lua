-- Small drawing helpers shared by the scenes. No external libraries here: this file
-- shows what plain love.graphics can do (meshes, generated textures, noise, curves).

local gfx = {}
local lg = love.graphics

-- "#ff8800" or "ff8800" -> r, g, b (0..1). Optional alpha.
function gfx.hex(s, a)
  s = s:gsub("#", "")
  return tonumber(s:sub(1, 2), 16) / 255,
         tonumber(s:sub(3, 4), 16) / 255,
         tonumber(s:sub(5, 6), 16) / 255,
         a or 1
end

-- Same as gfx.hex but returns a table, handy for palettes.
function gfx.rgb(s, a)
  return { gfx.hex(s, a) }
end

function gfx.lerp(a, b, t) return a + (b - a) * t end

function gfx.mix(c1, c2, t)
  return {
    c1[1] + (c2[1] - c1[1]) * t,
    c1[2] + (c2[2] - c1[2]) * t,
    c1[3] + (c2[3] - c1[3]) * t,
    (c1[4] or 1) + ((c2[4] or 1) - (c1[4] or 1)) * t,
  }
end

function gfx.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Vertical gradient as a Mesh. stops = { {t, {r,g,b,a}}, ... } with t from 0 (top) to 1.
-- A mesh with per-vertex colours is how LÖVE does smooth gradients without images.
function gfx.vgradient(w, h, stops)
  local verts = {}
  for _, s in ipairs(stops) do
    local t, c = s[1], s[2]
    local y = t * h
    verts[#verts + 1] = { 0, y, 0, 0, c[1], c[2], c[3], c[4] or 1 }
    verts[#verts + 1] = { w, y, 1, 0, c[1], c[2], c[3], c[4] or 1 }
  end
  local mesh = lg.newMesh(verts, "strip", "static")
  return mesh
end

-- Horizontal-band gradient for a polygon-ish strip: top edge points with one colour,
-- bottom edge with another. pts = {x1,y1,x2,y2,...} along the top, bottomY is flat.
function gfx.ridgeMesh(pts, bottomY, topColor, bottomColor)
  local verts = {}
  for i = 1, #pts, 2 do
    local x, y = pts[i], pts[i + 1]
    verts[#verts + 1] = { x, y, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 }
    verts[#verts + 1] = { x, bottomY, 0, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 }
  end
  return lg.newMesh(verts, "strip", "static")
end

-- A soft round "blob" texture generated in code. Used for glows, particles, light.
function gfx.radialTexture(size, power, color)
  power = power or 2
  local d = love.image.newImageData(size, size)
  local r, g, b = 1, 1, 1
  if color then r, g, b = color[1], color[2], color[3] end
  d:mapPixel(function(x, y)
    local dx = (x + 0.5) / size * 2 - 1
    local dy = (y + 0.5) / size * 2 - 1
    local dist = math.min(1, math.sqrt(dx * dx + dy * dy))
    local a = (1 - dist) ^ power
    return r, g, b, a
  end)
  local img = lg.newImage(d)
  img:setFilter("linear", "linear")
  return img
end

-- Fractal Brownian motion: several octaves of love.math.noise stacked together.
-- This one function is the basis of clouds, mountains, terrain, wood grain, fog...
function gfx.fbm(x, y, octaves, lacunarity, gain)
  octaves = octaves or 5
  lacunarity = lacunarity or 2
  gain = gain or 0.5
  local sum, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves do
    sum = sum + amp * love.math.noise(x * freq, y * freq)
    norm = norm + amp
    amp = amp * gain
    freq = freq * lacunarity
  end
  return sum / norm
end

-- Heart outline from the classic parametric curve. Returns a flat vertex list.
function gfx.heart(cx, cy, size, segments)
  segments = segments or 40
  local pts = {}
  for i = 0, segments - 1 do
    local t = i / segments * math.pi * 2
    local x = 16 * math.sin(t) ^ 3
    local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    pts[#pts + 1] = cx + x * size / 32
    pts[#pts + 1] = cy - y * size / 32
  end
  return pts
end

-- Filled shape that may be concave (a heart, a mountain ridge): triangulate first,
-- because love.graphics.polygon("fill") only handles convex shapes correctly.
function gfx.fillConcave(pts)
  local ok, tris = pcall(love.math.triangulate, pts)
  if not ok then return end
  for _, t in ipairs(tris) do lg.polygon("fill", t) end
end

-- Mountain ridge from noise: returns a flat list of points across the width.
function gfx.ridge(width, baseY, amplitude, freq, seed, step, octaves)
  step = step or 8
  local pts = {}
  for x = -step, width + step, step do
    local n = gfx.fbm(x * freq + seed, seed * 0.37, octaves or 5)
    pts[#pts + 1] = x
    pts[#pts + 1] = baseY - n * amplitude
  end
  return pts
end

-- Close a ridge into a polygon reaching down to bottomY.
function gfx.closeRidge(pts, bottomY)
  local poly = {}
  for i = 1, #pts do poly[i] = pts[i] end
  poly[#poly + 1] = pts[#pts - 1]
  poly[#poly + 1] = bottomY
  poly[#poly + 1] = pts[1]
  poly[#poly + 1] = bottomY
  return poly
end

-- Draw a ridge as vertical slices: robust for any jagged shape (no triangulation).
function gfx.fillRidge(pts, bottomY)
  for i = 1, #pts - 2, 2 do
    local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
    lg.polygon("fill", x1, y1, x2, y2, x2, bottomY, x1, bottomY)
  end
end

-- Deterministic pseudo-random number for an integer key. Lets infinite scrolling
-- worlds place the same tree at the same spot every time, without storing it.
function gfx.hash(n)
  local s = math.sin(n * 127.1 + 311.7) * 43758.5453
  return s - math.floor(s)
end

-- Text with a dark outline (8 offset copies, then the text itself).
function gfx.outlinedText(text, x, y, color, outline, width, limit, align)
  outline = outline or { 0, 0, 0, 1 }
  width = width or 2
  lg.setColor(outline)
  for dx = -1, 1 do
    for dy = -1, 1 do
      if dx ~= 0 or dy ~= 0 then
        if limit then
          lg.printf(text, x + dx * width, y + dy * width, limit, align or "left")
        else
          lg.print(text, x + dx * width, y + dy * width)
        end
      end
    end
  end
  lg.setColor(color)
  if limit then lg.printf(text, x, y, limit, align or "left") else lg.print(text, x, y) end
end

-- Make an Image from a list of strings, one character per pixel.
-- palette maps characters to colours; "." (or any unmapped char) is transparent.
-- This is how you can keep pixel-art sprites inside source code.
function gfx.spriteFromStrings(rows, palette)
  local h, w = #rows, #rows[1]
  local d = love.image.newImageData(w, h)
  for y = 1, h do
    local row = rows[y]
    for x = 1, w do
      local c = palette[row:sub(x, x)]
      if c then d:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4] or 1) end
    end
  end
  local img = lg.newImage(d)
  img:setFilter("nearest", "nearest")
  return img
end

return gfx
