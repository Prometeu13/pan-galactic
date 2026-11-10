-- "Any silhouette -> low-poly": fill an outline with flat-coloured triangles.
--
--   1. take the outline's own corners, plus extra points along its edges
--   2. scatter random points inside it
--   3. Delaunay-triangulate all of them
--   4. throw away triangles whose centre falls outside the outline (the triangulation
--      always fills the convex hull, so concave bays need trimming)
--   5. ask a colour function for each surviving triangle's colour
--
-- Returns a plain list of triangles, so scenes can animate or re-colour them, and a
-- helper turns the list into a Mesh.

local Delaunay = require("delaunay")
local facets = {}
local lg = love.graphics

-- even-odd ray cast: is (x, y) inside the polygon {x1,y1,x2,y2,...}?
function facets.inside(poly, x, y)
  local inside = false
  local n = #poly / 2
  local j = n
  for i = 1, n do
    local xi, yi = poly[i * 2 - 1], poly[i * 2]
    local xj, yj = poly[j * 2 - 1], poly[j * 2]
    if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside = not inside end
    j = i
  end
  return inside
end

-- outline: flat list of points. spacing: rough size of a facet in pixels.
-- colorFn(cx, cy, rnd) -> r, g, b   (rnd is a stable random 0..1 for this facet)
function facets.fromOutline(outline, spacing, colorFn, seed)
  local rng = love.math.newRandomGenerator(seed or 1)
  local pts = {}
  local function add(x, y)
    -- Delaunay dislikes duplicate or perfectly aligned points: nudge everything a hair
    pts[#pts + 1] = Delaunay.Point(x + (rng:random() - 0.5) * 0.01, y + (rng:random() - 0.5) * 0.01)
  end
  local n = #outline / 2
  local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, n do
    local x1, y1 = outline[i * 2 - 1], outline[i * 2]
    local j = i % n + 1
    local x2, y2 = outline[j * 2 - 1], outline[j * 2]
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local steps = math.max(1, math.floor(len / spacing + 0.5))
    for s = 0, steps - 1 do
      add(x1 + (x2 - x1) * s / steps, y1 + (y2 - y1) * s / steps)
    end
    minx, miny = math.min(minx, x1), math.min(miny, y1)
    maxx, maxy = math.max(maxx, x1), math.max(maxy, y1)
  end
  -- interior points: jittered grid, kept only if inside (and not hugging the edge)
  for gx = minx + spacing * 0.5, maxx, spacing do
    for gy = miny + spacing * 0.5, maxy, spacing do
      local x = gx + (rng:random() - 0.5) * spacing * 0.8
      local y = gy + (rng:random() - 0.5) * spacing * 0.8
      if facets.inside(outline, x, y) then add(x, y) end
    end
  end
  local out = {}
  if #pts < 3 then return out end
  local ok, tris = pcall(Delaunay.triangulate, unpack(pts))
  if not ok then return out end
  for _, t in ipairs(tris) do
    local cx = (t.p1.x + t.p2.x + t.p3.x) / 3
    local cy = (t.p1.y + t.p2.y + t.p3.y) / 3
    if facets.inside(outline, cx, cy) then
      local r, g, b = colorFn(cx, cy, rng:random())
      out[#out + 1] = { t.p1.x, t.p1.y, t.p2.x, t.p2.y, t.p3.x, t.p3.y, r, g, b, cx = cx, cy = cy }
    end
  end
  return out
end

-- A full rectangle of facets (for skies, water, backdrops).
function facets.grid(x, y, w, h, cell, colorFn, seed)
  return facets.fromOutline({ x, y, x + w, y, x + w, y + h, x, y + h }, cell, colorFn, seed)
end

-- Append triangles to a vertex list / build a Mesh from one or more triangle lists.
function facets.mesh(...)
  local verts = {}
  for _, tris in ipairs({ ... }) do
    for _, t in ipairs(tris) do
      verts[#verts + 1] = { t[1], t[2], 0, 0, t[7], t[8], t[9], 1 }
      verts[#verts + 1] = { t[3], t[4], 0, 0, t[7], t[8], t[9], 1 }
      verts[#verts + 1] = { t[5], t[6], 0, 0, t[7], t[8], t[9], 1 }
    end
  end
  if #verts == 0 then return nil end
  return lg.newMesh(verts, "triangles", "static")
end

return facets
