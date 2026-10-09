-- Palette and fonts.
local T = {}

T.c = {
  bg = { 0.04, 0.03, 0.10 }, ink = { 0.97, 0.94, 0.86 }, dim = { 0.66, 0.63, 0.76 }, faint = { 0.36, 0.33, 0.5 },
  panel = { 0.11, 0.09, 0.20 }, panel2 = { 0.17, 0.14, 0.29 }, edge = { 0.34, 0.28, 0.52 },
  orange = { 1, 0.56, 0.18 }, teal = { 0.22, 0.82, 0.78 }, pink = { 1, 0.36, 0.6 }, gold = { 1, 0.82, 0.25 },
  good = { 0.45, 0.92, 0.45 }, bad = { 1, 0.36, 0.3 }, cream = { 0.97, 0.9, 0.72 },
  crt = { 0.04, 0.14, 0.09 }, crtText = { 0.48, 1, 0.62 }, dark = { 0.12, 0.08, 0.18 },
}

local cache = {}
function T.font(size)
  local f = cache[size]
  if not f then
    f = love.graphics.newFont(size)
    cache[size] = f
  end
  return f
end

return T
