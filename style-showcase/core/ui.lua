-- Gallery screen, per-scene HUD and the info panel that explains each style.

local gfx = require("core.gfx")
local lg = love.graphics

local ui = {
  THUMB_W = 192,
  THUMB_H = 108,
}

local COLS, GAP_X, GAP_Y, TOP = 6, 14, 22, 128
local ROW_H = ui.THUMB_H + 44
local LEFT = (1280 - (COLS * ui.THUMB_W + (COLS - 1) * GAP_X)) / 2

function ui.init()
  ui.fonts = {
    title = lg.newFont(40),
    h2 = lg.newFont(20),
    body = lg.newFont(14),
    small = lg.newFont(12),
    label = lg.newFont(15),
  }
end

local function thumbPos(i)
  local c = (i - 1) % COLS
  local r = math.floor((i - 1) / COLS)
  return LEFT + c * (ui.THUMB_W + GAP_X), TOP + r * (ROW_H + GAP_Y)
end

function ui.galleryHit(x, y, n)
  for i = 1, n do
    local tx, ty = thumbPos(i)
    if x >= tx and x <= tx + ui.THUMB_W and y >= ty and y <= ty + ROW_H then return i end
  end
end

-- Which scene of style i the gallery is showing right now. Thumbnails take turns:
-- each style switches every few seconds (out of step with its neighbours) and
-- cross-fades to the next scene that already has a thumbnail.
local shown = {}
local HOLD, FADE = 5, 0.6

local function pick(st, i, time)
  local ready = {}
  for vi, s in ipairs(st.scenes) do
    if s._thumb then ready[#ready + 1] = vi end
  end
  if #ready == 0 then return nil end
  local clock = time + i * 1.7
  local k = math.floor(clock / HOLD) % #ready + 1
  local into = clock % HOLD
  local nextV, mix = nil, 0
  if #ready > 1 and into > HOLD - FADE then
    nextV = ready[k % #ready + 1]
    mix = (into - (HOLD - FADE)) / FADE
  end
  return ready[k], nextV, mix
end

function ui.shownVariant(i) return shown[i] or 1 end

function ui.drawGallery(styles, hover, time)
  lg.push("all")
  ui.bg = ui.bg or gfx.vgradient(1280, 720, {
    { 0, gfx.rgb("#1b1530") }, { 1, gfx.rgb("#0b0a12") },
  })
  lg.setColor(1, 1, 1)
  lg.draw(ui.bg)

  lg.setFont(ui.fonts.title)
  lg.setColor(gfx.hex("#ffe9b0"))
  lg.printf("LÖVE Style Showcase", 0, 26, 1280, "center")
  lg.setFont(ui.fonts.body)
  lg.setColor(gfx.hex("#b9b0d6"))
  local total = 0
  for _, st in ipairs(styles) do total = total + #st.scenes end
  lg.printf(("%d art styles  ·  %d scenes  ·  zero image files  ·  every pixel is drawn by Lua code at runtime"):format(#styles, total),
    0, 80, 1280, "center")

  for i, st in ipairs(styles) do
    local x, y = thumbPos(i)
    local lift = (hover == i) and -4 or 0
    local vi, nextV, mix = pick(st, i, time)
    -- a hovered style holds still, so what you click is what you saw
    if hover == i and shown[i] and st.scenes[shown[i]]._thumb then vi, nextV, mix = shown[i], nil, 0 end
    shown[i] = vi or 1
    local s = st.scenes[shown[i]]
    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", x + 4, y + 6, ui.THUMB_W, ui.THUMB_H, 8)
    if vi then
      lg.stencil(function() lg.rectangle("fill", x, y + lift, ui.THUMB_W, ui.THUMB_H, 8) end, "replace", 1)
      lg.setStencilTest("greater", 0)
      lg.setBlendMode("alpha", "premultiplied")
      lg.setColor(1, 1, 1)
      lg.draw(s._thumb, x, y + lift)
      if nextV then
        lg.setColor(mix, mix, mix, mix)
        lg.draw(st.scenes[nextV]._thumb, x, y + lift)
      end
      lg.setBlendMode("alpha")
      lg.setStencilTest()
    end
    lg.setLineWidth(hover == i and 3 or 1)
    lg.setColor(hover == i and { gfx.hex("#ffd36e") } or { 1, 1, 1, 0.18 })
    lg.rectangle("line", x, y + lift, ui.THUMB_W, ui.THUMB_H, 8)
    if #st.scenes > 1 then
      -- one dot per scene; the lit one is the scene on show
      local n = #st.scenes
      local bw = n * 12 + 10
      lg.setColor(0, 0, 0, 0.6)
      lg.rectangle("fill", x + ui.THUMB_W - bw - 6, y + lift + 6, bw, 16, 8)
      for k = 1, n do
        local on = (k == shown[i])
        lg.setColor(on and { gfx.hex("#ffd36e") } or { 1, 1, 1, st.scenes[k]._thumb and 0.45 or 0.15 })
        lg.circle("fill", x + ui.THUMB_W - bw + 5 + (k - 1) * 12, y + lift + 14, on and 4 or 3)
      end
    end
    lg.setFont(ui.fonts.label)
    lg.setColor(gfx.hex("#ffe9b0"))
    lg.print(("%02d  %s"):format(i, s.title), x + 2, y + ui.THUMB_H + 6)
    lg.setFont(ui.fonts.small)
    lg.setColor(gfx.hex("#8e86ad"))
    lg.print(s.subtitle or "", x + 2, y + ui.THUMB_H + 25)
  end

  lg.setFont(ui.fonts.small)
  lg.setColor(gfx.hex("#8e86ad"))
  lg.printf("Click a thumbnail to open the scene it shows  ·  Left/Right: next style  ·  Up/Down: other scenes of a style  ·  I: info panel  ·  Esc: back / quit  ·  F12: screenshot",
    0, 700, 1280, "center")
  lg.pop()
end

local INFO_BTN = { x = 1280 - 14 - 176, y = 14, w = 176, h = 34 }
local variantBtn = nil -- set while drawing the HUD

local function inside(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function ui.hudHit(x, y)
  if inside(INFO_BTN, x, y) then return "info" end
  if inside(variantBtn, x, y) then return "variant" end
end

local function section(title, items, x, y, w, color)
  lg.setFont(ui.fonts.label)
  lg.setColor(color)
  lg.print(title, x, y)
  y = y + 22
  lg.setFont(ui.fonts.body)
  for _, it in ipairs(items) do
    lg.setColor(1, 1, 1, 0.88)
    local _, lines = ui.fonts.body:getWrap(it, w - 14)
    lg.print("•", x, y)
    lg.printf(it, x + 14, y, w - 14)
    y = y + #lines * ui.fonts.body:getHeight() + 4
  end
  return y + 10
end

-- info = { index, count, variant, variants }
function ui.drawHud(s, info, showInfo)
  lg.setShader()
  lg.setBlendMode("alpha")
  -- Title pill (top-left)
  lg.setFont(ui.fonts.h2)
  local label = ("%02d / %02d   %s"):format(info.index, info.count, s.title)
  local w = ui.fonts.h2:getWidth(label) + 28
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", 14, 14, w, 34, 17)
  lg.setColor(1, 1, 1, 0.95)
  lg.print(label, 28, 19)

  -- Scene pill: which scene of this style, click (or Up/Down) for the next one
  variantBtn = nil
  if info.variants > 1 then
    lg.setFont(ui.fonts.label)
    local vl = ("Scene %d/%d: %s   (Up/Down)"):format(info.variant, info.variants, s.subtitle or "")
    local vw = ui.fonts.label:getWidth(vl) + 26
    variantBtn = { x = 14 + w + 8, y = 14, w = vw, h = 34 }
    lg.setColor(0.25, 0.18, 0.02, 0.75)
    lg.rectangle("fill", variantBtn.x, 14, vw, 34, 17)
    lg.setColor(gfx.hex("#ffd36e"))
    lg.print(vl, variantBtn.x + 13, 22)
    w = w + vw + 8
  end

  -- "How it's made" toggle (top-right)
  local b = INFO_BTN
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", b.x, b.y, b.w, b.h, 17)
  lg.setColor(showInfo and { gfx.hex("#ffd36e") } or { 1, 1, 1, 0.95 })
  lg.setFont(ui.fonts.label)
  lg.printf(showInfo and "Hide info  (I)" or "How it's made  (I)", b.x, b.y + 8, b.w, "center")

  -- Controls hint, next to the title
  lg.setFont(ui.fonts.small)
  local hint = "Left/Right: style   Esc: gallery"
  local hw = ui.fonts.small:getWidth(hint) + 24
  lg.setColor(0, 0, 0, 0.45)
  lg.rectangle("fill", 14 + w + 8, 20, hw, 22, 11)
  lg.setColor(1, 1, 1, 0.75)
  lg.print(hint, 14 + w + 20, 24)

  if showInfo then
    local pw, px, py = 390, 1280 - 390 - 14, 58
    local ph = 720 - py - 14
    lg.setColor(0.04, 0.03, 0.08, 0.82)
    lg.rectangle("fill", px, py, pw, ph, 12)
    lg.setColor(1, 1, 1, 0.12)
    lg.rectangle("line", px, py, pw, ph, 12)

    local x, y, iw = px + 18, py + 14, pw - 36
    lg.setFont(ui.fonts.h2)
    lg.setColor(gfx.hex("#ffe9b0"))
    lg.printf(s.title .. ": " .. (s.subtitle or ""), x, y, iw)
    local _, tl = ui.fonts.h2:getWrap(s.title .. ": " .. (s.subtitle or ""), iw)
    y = y + #tl * ui.fonts.h2:getHeight() + 6
    if s.blurb then
      lg.setFont(ui.fonts.body)
      lg.setColor(1, 1, 1, 0.7)
      lg.printf(s.blurb, x, y, iw)
      local _, bl = ui.fonts.body:getWrap(s.blurb, iw)
      y = y + #bl * ui.fonts.body:getHeight() + 14
    end
    y = section("How it's drawn", s.techniques or {}, x, y, iw, { gfx.hex("#9fd8ff") })
    y = section("Libraries used", s.libs or {}, x, y, iw, { gfx.hex("#b6f5a8") })
    y = section("Games that fit this look", s.genres or {}, x, y, iw, { gfx.hex("#ffb3c7") })
    if s.controls then
      lg.setFont(ui.fonts.small)
      lg.setColor(gfx.hex("#ffd36e"))
      lg.printf("Try it: " .. s.controls, x, py + ph - 40, iw)
    end
  end

end

return ui
