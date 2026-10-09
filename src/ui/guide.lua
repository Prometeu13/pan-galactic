-- The Foodie's Guide to the Galaxy: a little CRT that types out unreliable advice.
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local GUIDE = require("content.guide")
local rng = require("src.core.rng")
local lg = love.graphics

local G = { text = "", shown = 0, t = 0 }

function G.say(text)
  G.text, G.shown = text, 0
end

-- key: an entry in content/guide.lua lines. vars: { name = "..." } fills $name.
function G.sayKey(key, vars)
  local lines = GUIDE.lines[key]
  if not lines then return end
  local s = rng.pick(lines):gsub("%$(%w+)", function(k) return vars and tostring(vars[k] or "") or "" end)
  G.say(s)
end

function G.talking() return G.shown < #G.text end

function G.update(dt)
  G.t = G.t + dt
  G.shown = math.min(#G.text, G.shown + dt * 55)
end

function G.draw(x, y, w, h, alpha)
  alpha = alpha or 1
  lg.setColor(0, 0, 0, 0.35 * alpha)
  D.rrect("fill", x + 3, y + 5, w, h, 12)
  lg.setColor(0.22, 0.2, 0.3, alpha)
  D.rrect("fill", x, y, w, h, 12)
  D.color(T.c.crt, alpha)
  D.rrect("fill", x + 6, y + 6, w - 12, h - 12, 8)

  -- face
  local fx, fy = x + 40, y + h / 2
  D.color(T.c.crtText, alpha)
  lg.setLineWidth(2)
  D.rrect("line", fx - 26, fy - 24, 52, 48, 8)
  local blink = (G.t % 4) < 0.12
  if blink then
    lg.line(fx - 14, fy - 6, fx - 6, fy - 6)
    lg.line(fx + 6, fy - 6, fx + 14, fy - 6)
  else
    lg.circle("fill", fx - 10, fy - 6, 4)
    lg.circle("fill", fx + 10, fy - 6, 4)
  end
  local open = G.talking() and (math.sin(G.t * 22) > 0) and 6 or 1
  lg.ellipse("fill", fx, fy + 10, 9, open)

  D.text("FOODIE'S GUIDE TO THE GALAXY", x + 80, y + 9, 11, { T.c.crtText[1], T.c.crtText[2], T.c.crtText[3], 0.6 * alpha })
  local shown = G.text:sub(1, math.floor(G.shown))
  if G.talking() and (G.t * 3) % 1 < 0.5 then shown = shown .. "_" end
  D.text(shown, x + 80, y + 25, 14, { T.c.crtText[1], T.c.crtText[2], T.c.crtText[3], alpha }, "left", w - 95)
end

return G
