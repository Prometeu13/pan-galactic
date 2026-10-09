-- Drawing helpers: panels, buttons, text, tag chips, stars.
local T = require("src.ui.theme")
local TAGS = require("content.tags")
local lg = love.graphics

local D = {}

function D.color(c, a) lg.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1)) end

-- Fills the whole virtual screen, plus the letterbox bleed.
function D.fill(c)
  D.color(c)
  lg.rectangle("fill", -400, -400, 2080, 1520)
end

function D.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

function D.rrect(mode, x, y, w, h, r)
  r = r or 8
  lg.rectangle(mode, x, y, w, h, r, r)
end

function D.panel(x, y, w, h, fill, edge, r)
  r = r or 12
  lg.setColor(0, 0, 0, 0.35)
  D.rrect("fill", x + 3, y + 5, w, h, r)
  D.color(fill or T.c.panel)
  D.rrect("fill", x, y, w, h, r)
  lg.setLineWidth(2)
  D.color(edge or T.c.edge)
  D.rrect("line", x, y, w, h, r)
end

function D.text(s, x, y, size, color, align, w)
  lg.setFont(T.font(size or 16))
  D.color(color or T.c.ink)
  if align then lg.printf(s, x, y, w, align) else lg.print(s, x, y) end
end

function D.shadowText(s, x, y, size, color, align, w, off)
  off = off or 3
  D.text(s, x + off, y + off, size, { 0, 0, 0, 0.55 }, align, w)
  D.text(s, x, y, size, color, align, w)
end

function D.inside(b, x, y)
  return x and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

-- b = { x, y, w, h, label, enabled, color, size }. Returns true if hovered.
function D.button(b, mx, my)
  local enabled = b.enabled ~= false
  local hot = enabled and D.inside(b, mx, my)
  local base = enabled and (b.color or T.c.orange) or T.c.faint
  local yo = hot and -2 or 0
  lg.setColor(0, 0, 0, 0.4)
  D.rrect("fill", b.x, b.y + 4, b.w, b.h, 10)
  D.color(hot and D.mix(base, { 1, 1, 1 }, 0.25) or base)
  D.rrect("fill", b.x, b.y + yo, b.w, b.h, 10)
  lg.setColor(1, 1, 1, 0.16)
  D.rrect("fill", b.x + 4, b.y + yo + 3, b.w - 8, b.h * 0.4, 8)
  local size = b.size or 18
  D.text(b.label, b.x, b.y + yo + (b.h - T.font(size):getHeight()) / 2, size,
    enabled and T.c.dark or T.c.dim, "center", b.w)
  return hot
end

-- A coloured pill for a tag. opts: { n, outline, dim, size }. Returns width, height.
function D.chip(tag, x, y, opts)
  opts = opts or {}
  local size = opts.size or 13
  local f = T.font(size)
  local label, col
  if tag == "?" then
    label, col = opts.label or "?", T.c.faint
  else
    label, col = tag, TAGS.defs[tag].color
    if opts.n and opts.n > 1 then label = label .. " x" .. opts.n end
  end
  local w, h = f:getWidth(label) + 14, f:getHeight() + 4
  D.color(col, opts.dim and 0.3 or 1)
  D.rrect("fill", x, y, w, h, h / 2)
  if opts.outline then
    lg.setLineWidth(2)
    D.color(opts.outline)
    D.rrect("line", x - 2, y - 2, w + 4, h + 4, h / 2 + 2)
  end
  lg.setFont(f)
  lg.setColor(0.08, 0.06, 0.12, opts.dim and 0.6 or 1)
  lg.print(label, x + 7, y + 2)
  return w, h
end

-- items: { {tag=, n=, outline=, dim=, label=}, ... } wrapped into maxW. Returns total height.
function D.chipRow(items, x, y, maxW, size)
  local cx, cy, rowH = x, y, 0
  for _, it in ipairs(items) do
    local f = T.font(size or 13)
    local label = it.tag == "?" and (it.label or "?") or (it.tag .. ((it.n and it.n > 1) and (" x" .. it.n) or ""))
    local w = f:getWidth(label) + 14
    if cx + w > x + maxW and cx > x then
      cx, cy = x, cy + rowH + 6
    end
    local _, h = D.chip(it.tag, cx, cy, { n = it.n, outline = it.outline, dim = it.dim, size = size, label = it.label })
    rowH = math.max(rowH, h)
    cx = cx + w + 6
  end
  return cy - y + rowH
end

-- Text with {Tag:words} spans coloured by tag, wrapped to width w. Returns height used.
function D.rich(str, x, y, w, size, base)
  local f = T.font(size)
  lg.setFont(f)
  local segs, pos = {}, 1
  while true do
    local s, e, tag, txt = str:find("{(%w+):([^}]*)}", pos)
    if not s then
      segs[#segs + 1] = { str:sub(pos) }
      break
    end
    if s > pos then segs[#segs + 1] = { str:sub(pos, s - 1) } end
    segs[#segs + 1] = { txt, tag }
    pos = e + 1
  end
  local lh = f:getHeight() * 1.2
  local cx, cy = x, y
  for _, sg in ipairs(segs) do
    local col = sg[2] and TAGS.defs[sg[2]] and TAGS.defs[sg[2]].color or (base or T.c.ink)
    if not sg[1]:find("%S") then
      cx = cx + f:getWidth(sg[1])
    end
    for lead, word, trail in sg[1]:gmatch("(%s*)(%S+)(%s*)") do
      if cx > x then cx = cx + f:getWidth(lead) end
      local ww = f:getWidth(word)
      if cx + ww > x + w and cx > x then cx, cy = x, cy + lh end
      if sg[2] then
        D.color(col)
        D.rrect("fill", cx - 3, cy, ww + 6, f:getHeight() + 1, 5)
        lg.setColor(0.08, 0.06, 0.12)
      else
        D.color(col)
      end
      lg.print(word, cx, cy)
      cx = cx + ww + f:getWidth(trail)
    end
  end
  return cy - y + lh
end

function D.star(x, y, r, fill)
  local pts = {}
  for i = 0, 9 do
    local a = -math.pi / 2 + i * math.pi / 5
    local rr = (i % 2 == 0) and r or r * 0.45
    pts[#pts + 1] = x + math.cos(a) * rr
    pts[#pts + 1] = y + math.sin(a) * rr
  end
  if fill > 0 then
    D.color(T.c.gold, fill)
    lg.polygon("fill", pts)
  end
  D.color(T.c.gold)
  lg.setLineWidth(1.5)
  lg.polygon("line", pts)
end

function D.stars(x, y, value, r)
  for i = 1, 5 do
    local fill = math.max(0, math.min(1, value - (i - 1)))
    D.star(x + (i - 1) * r * 2.3, y, r, fill)
  end
end

function D.coin(x, y, r)
  D.color(T.c.gold)
  lg.circle("fill", x, y, r)
  lg.setColor(0.75, 0.5, 0.1)
  lg.setLineWidth(2)
  lg.circle("line", x, y, r * 0.72)
  lg.setFont(T.font(math.floor(r * 1.2)))
  lg.printf("F", x - r, y - r * 0.7, r * 2, "center")
end

-- Starfield ---------------------------------------------------------------------------------
function D.makeStars(n)
  local s = {}
  for i = 1, n do
    s[i] = { x = love.math.random() * 1280, y = love.math.random() * 720,
      z = 0.2 + love.math.random() * 0.8, tw = love.math.random() * 6.28 }
  end
  return s
end

function D.drawStars(stars, t, speed)
  speed = speed or 20
  for _, s in ipairs(stars) do
    local x = (s.x - t * speed * s.z) % 1280
    local a = 0.4 + 0.6 * s.z * (0.7 + 0.3 * math.sin(t * 2 + s.tw))
    lg.setColor(0.85, 0.9, 1, a)
    lg.circle("fill", x, s.y, 0.6 + s.z * 1.4)
  end
end

-- k in 0..1: how far into hyperspace we are.
function D.drawWarp(stars, t, k)
  lg.setLineWidth(2)
  for _, s in ipairs(stars) do
    local dx, dy = s.x - 640, s.y - 360
    local d = math.sqrt(dx * dx + dy * dy) + 1
    local grow = 1 + ((t * 0.8 * s.z) % 1) * 2.5
    local x1, y1 = 640 + dx * grow, 360 + dy * grow
    local len = 10 + k * 260 * s.z
    lg.setColor(0.7 + 0.3 * s.z, 0.85, 1, 0.3 + 0.7 * s.z)
    lg.line(x1, y1, x1 + dx / d * len, y1 + dy / d * len)
  end
end

-- Sky gradient as a vertical mesh-free stack of bands.
function D.gradient(x, y, w, h, top, bottom, steps)
  steps = steps or 24
  local bh = h / steps
  for i = 0, steps - 1 do
    D.color(D.mix(top, bottom, i / (steps - 1)))
    lg.rectangle("fill", x, y + i * bh, w, bh + 1)
  end
end

return D
