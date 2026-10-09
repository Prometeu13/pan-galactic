-- Between planets: buy truck upgrades, pay down the debt, then hitch the next ride.
local scenes = require("src.core.scenes")
local vp = require("src.core.viewport")
local sfx = require("src.core.sfx")
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local A = require("src.ui.art")
local fx = require("src.ui.fx")
local Guide = require("src.ui.guide")
local Run = require("src.game.run")
local UP = require("content.upgrades")
local GUIDE = require("content.guide")
local lg = love.graphics

local O = {}

function O:enter()
  self.run = Run.current
  self.t = 0
  self.stars = self.stars or D.makeStars(160)
  self.rows = {}
  for i, u in ipairs(UP.list) do
    local y = 150 + (i - 1) * 62
    self.rows[i] = { u = u, y = y, btn = { x = 1110, y = y + 8, w = 140, h = 40, label = "", size = 15 } }
  end
  self.btnPay = { x = 30, y = 600, w = 150, h = 44, label = "Pay 50", size = 16, color = T.c.pink }
  self.btnPayAll = { x = 196, y = 600, w = 180, h = 44, label = "Pay all I can", size = 16, color = T.c.pink }
  self.btnGo = { x = 960, y = 616, w = 300, h = 64, label = "Stick out thumb  >", size = 20, color = T.c.teal }
  self.victory = false
  fx.clear()
  Guide.sayKey("outfitter")
end

function O:update(dt) self.t = self.t + dt end

function O:draw()
  local t = self.t
  local mx, my = vp.mouse()
  local run = self.run
  D.fill(T.c.bg)
  D.drawStars(self.stars, t, 6)
  A.truck(250, 475 + math.sin(t * 1.2) * 6, 0.85, t)

  -- shift report
  D.panel(30, 30, 470, 240)
  D.text("REPORT, DAY " .. run.day, 50, 44, 22, T.c.gold)
  local s = run.lastShift
  if s then
    D.text("Served " .. s.served .. "   Walk-outs " .. s.walkouts .. "   Explosions " .. s.explosions, 50, 82, 16, T.c.ink)
    D.text("Earned " .. s.earned .. " Flurbos   Transcendent " .. s.transcendent, 50, 108, 16, T.c.ink)
  end
  D.text("Galactic rating", 50, 146, 16, T.c.dim)
  D.stars(200, 156, Run.rating(run), 11)
  D.text("Rumours of the Restaurant at the End of the Universe: " .. run.rumors .. "/" .. #GUIDE.rumors, 50, 182, 14, T.c.teal, "left", 430)
  if run.rumors > 0 then
    D.text(GUIDE.rumors[run.rumors], 50, 220, 12, T.c.dim, "left", 430)
  end

  -- upgrades
  D.panel(530, 30, 730, 540)
  D.text("TRUCK UPGRADES", 550, 44, 22, T.c.orange)
  D.coin(1110, 57, 12)
  D.text(tostring(run.flurbos) .. " Flurbos", 1130, 46, 20, T.c.gold)
  D.text("Spend now, or pay the bank. The galaxy will not judge you. The bank will.", 550, 100, 14, T.c.dim)
  for _, r in ipairs(self.rows) do
    local u = r.u
    local owned = Run.has(run, u.id)
    D.color(T.c.panel2)
    D.rrect("fill", 550, r.y, 700, 56, 8)
    D.text(u.name, 566, r.y + 6, 17, owned and T.c.good or T.c.ink)
    D.text(u.desc, 566, r.y + 30, 12, T.c.dim, "left", 520)
    r.btn.label = owned and "Installed" or (u.price .. " F")
    r.btn.enabled = Run.canBuy(run, u.id)
    r.btn.color = owned and T.c.good or T.c.orange
    D.button(r.btn, mx, my)
  end

  -- debt
  D.text("Debt to the First Bank of Fringe Bureaucracy: " .. run.debt, 30, 560, 17, run.debt > 0 and T.c.bad or T.c.good)
  local can = run.flurbos > 0 and run.debt > 0
  self.btnPay.enabled = can
  self.btnPayAll.enabled = can
  D.button(self.btnPay, mx, my)
  D.button(self.btnPayAll, mx, my)
  D.button(self.btnGo, mx, my)

  Guide.draw(530, 596, 410, 112)

  if self.victory then
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, 1280, 720)
    D.panel(290, 200, 700, 260)
    D.shadowText("DEBT CLEARED!", 290, 230, 44, T.c.gold, "center", 700)
    D.text("A gold-edged invitation drifts through the window:\n\"The Restaurant at the End of the Universe requests the pleasure of your cooking.\"\n\n(End of the vertical slice. Keep hitchhiking if you like.)", 330, 300, 17, T.c.ink, "center", 620)
  end
end

function O:pay(amount)
  local paid = Run.payDebt(self.run, amount)
  if paid > 0 then
    sfx.play("coin")
    fx.pop("-" .. paid .. " debt", 300, 540, T.c.good, 20)
    if self.run.debt <= 0 then
      self.victory = true
      Guide.sayKey("debt_paid")
    end
  end
end

function O:mousepressed(x, y)
  if self.victory then self.victory = false return end
  for _, r in ipairs(self.rows) do
    if D.inside(r.btn, x, y) and Run.buy(self.run, r.u.id) then
      sfx.play("coin")
      fx.burst(r.btn.x + 70, r.btn.y + 20, 20, T.c.gold, 200, { life = 0.6 })
      return
    end
  end
  if D.inside(self.btnPay, x, y) then self:pay(50) return end
  if D.inside(self.btnPayAll, x, y) then self:pay(self.run.flurbos) return end
  if D.inside(self.btnGo, x, y) then
    sfx.play("click")
    scenes.switch(require("src.scenes.hitchhike"))
  end
end

function O:keypressed(k)
  if self.victory then self.victory = false return end
  if k == "return" or k == "space" then scenes.switch(require("src.scenes.hitchhike")) end
end

return O
