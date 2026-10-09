-- Virtual resolution. The whole game is laid out on a 1280x720 canvas and scaled to fit
-- any window (letterboxed, centred inside the safe area so phone notches don't cover UI).
local vp = { w = 1280, h = 720, scale = 1, ox = 0, oy = 0, sw = 1280, sh = 720 }

function vp.resize(sw, sh)
  vp.sw, vp.sh = sw, sh
  local x, y, w, h = 0, 0, sw, sh
  if love.window and love.window.getSafeArea then
    local ok, sx, sy, swid, shei = pcall(love.window.getSafeArea)
    if ok and swid and shei and swid > 0 and shei > 0 then x, y, w, h = sx, sy, swid, shei end
  end
  vp.scale = math.min(w / vp.w, h / vp.h)
  vp.ox = x + (w - vp.w * vp.scale) / 2
  vp.oy = y + (h - vp.h * vp.scale) / 2
end

function vp.toVirtual(x, y)
  return (x - vp.ox) / vp.scale, (y - vp.oy) / vp.scale
end

function vp.mouse()
  return vp.toVirtual(love.mouse.getPosition())
end

function vp.apply()
  love.graphics.translate(vp.ox, vp.oy)
  love.graphics.scale(vp.scale)
end

return vp
