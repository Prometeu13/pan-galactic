-- Hitchhiking: pick a passing ride to the next planet.
local scenes = require("src.core.scenes")
local rng = require("src.core.rng")
local vp = require("src.core.viewport")
local sfx = require("src.core.sfx")
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local A = require("src.ui.art")
local Guide = require("src.ui.guide")
local Run = require("src.game.run")
local Galaxy = require("src.game.galaxy")
local SPECIES = require("content.species")
local lg = love.graphics

local H = {}

function H:enter()
  self.run = Run.current
  self.t = 0
  self.stars = self.stars or D.makeStars(240)
  self.rides = Galaxy.rides(self.run, rng)
  self.state = "choose"
  self.warpT = 0
  self.chosen = nil
  local n = #self.rides
  local top, h = 70, 540 / n
  for i, r in ipairs(self.rides) do
    r.y = top + (i - 1) * h + h / 2
    r.h = h - 12
    r.btn = { x = 1080, y = r.y - 24, w = 170, h = 48, label = r.def.fare > 0 and ("Thumb it (" .. r.def.fare .. "F)") or "Thumb it (free)", size = 16 }
  end
  Guide.sayKey("hitchhike")
end

function H:update(dt)
  self.t = self.t + dt
  if self.state == "warp" then
    self.warpT = self.warpT + dt
    if self.warpT >= self.warpDur then
      self.state = "done"
      self.run.day = self.run.day + 1
      self.run.planet = self.chosen.planet
      scenes.switch(require("src.scenes.forage"))
    end
  end
end

function H:choose(r)
  if self.run.flurbos < r.def.fare then
    Guide.sayKey("broke")
    sfx.play("bad")
    return
  end
  self.run.flurbos = self.run.flurbos - r.def.fare
  self.chosen = r
  self.state = "warp"
  self.warpT = 0
  self.warpDur = r.poem and 5.5 or 2.2
  if r.poem then Guide.sayKey("poem") end
  sfx.play("warp")
end

local function residentsText(p)
  local names = {}
  for _, id in ipairs(p.residents) do names[#names + 1] = SPECIES.byId[id].plural end
  return table.concat(names, ", ")
end

function H:drawHud()
  D.panel(-10, -10, 1300, 64, T.c.panel, T.c.edge, 0)
  D.text("DAY " .. (self.run.day + 1) .. "  -  HITCHHIKING", 20, 16, 20, T.c.ink)
  D.coin(900, 27, 12)
  D.text(tostring(self.run.flurbos), 920, 16, 20, T.c.gold)
  D.text("Debt: " .. self.run.debt, 1040, 16, 20, T.c.bad)
end

function H:draw()
  local t = self.t
  D.fill(T.c.bg)
  local mx, my = vp.mouse()

  if self.state == "choose" then
    D.drawStars(self.stars, t, 30)
    -- you, floating with a thumb out
    local ty = 360 + math.sin(t * 1.5) * 8
    A.truck(140, ty + 60, 0.55, t)
    D.text("you", 110, ty + 90, 14, T.c.dim, "center", 60)

    for i, r in ipairs(self.rides) do
      local x0, y0, h = 260, r.y - r.h / 2, r.h
      D.panel(x0, y0, 1000, h, T.c.panel, T.c.edge, 12)
      local ax = 380 + math.sin(t * 0.6 + i) * 20
      local s = math.min(0.75, h / 200)
      if r.def.id == "freighter" then A.freighter(ax, r.y, s, t)
      elseif r.def.id == "wormhole" then A.wormhole(ax, r.y, s, t)
      else A.barge(ax, r.y, s, t) end

      D.text(r.def.name, 500, y0 + 10, 20, T.c.orange)
      D.text(r.def.desc, 500, y0 + 36, 13, T.c.dim, "left", 300)

      local p = r.planet
      if r.revealed then
        A.planet(850, r.y, math.min(32, h * 0.22), p, t)
        D.text(p.name, 895, y0 + 10, 16, T.c.ink, "left", 180)
        D.text(p.quirk.text, 895, y0 + 32, 11, T.c.teal, "left", 180)
        if h > 120 then D.text("Locals: " .. residentsText(p), 895, y0 + 72, 11, T.c.dim, "left", 180) end
      else
        lg.setColor(0.2, 0.18, 0.3)
        lg.circle("fill", 850, r.y, 30)
        D.text("?", 835, r.y - 20, 34, T.c.faint, "center", 30)
        D.text("Destination unknown", 895, r.y - 10, 14, T.c.faint, "left", 180)
      end
      r.btn.enabled = self.run.flurbos >= r.def.fare
      D.button(r.btn, mx, my)
    end
    self:drawHud()
  else
    local k = math.min(1, self.warpT / 0.8)
    D.drawWarp(self.stars, t, k)
    lg.push()
    lg.translate(640 + (love.math.random() - 0.5) * 6 * k, 380)
    A.truck(0, 0, 0.7, t)
    lg.pop()
    if self.chosen.poem then
      D.panel(300, 80, 680, 220, { 0.2, 0.24, 0.14 }, { 0.6, 0.66, 0.38 })
      D.text("THE CAPTAIN RECITES:", 320, 92, 14, { 0.8, 0.85, 0.5 })
      D.text(self.chosen.poem, 320, 116, 16, T.c.ink, "left", 640)
    else
      D.shadowText(self.chosen.revealed and ("Next stop: " .. self.chosen.planet.name) or "Next stop: ???", 0, 140, 34, T.c.gold, "center", 1280)
    end
  end
  Guide.draw(260, 620, 1000, 86)
end

function H:mousepressed(x, y)
  if self.state ~= "choose" then return end
  for _, r in ipairs(self.rides) do
    if D.inside(r.btn, x, y) then self:choose(r) return end
  end
end

function H:keypressed(k)
  local n = tonumber(k)
  if self.state == "choose" and n and self.rides[n] then self:choose(self.rides[n]) end
end

return H
