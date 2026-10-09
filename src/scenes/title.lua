-- Title screen.
local scenes = require("src.core.scenes")
local T = require("src.ui.theme")
local D = require("src.ui.draw")
local A = require("src.ui.art")
local Guide = require("src.ui.guide")
local Run = require("src.game.run")
local sfx = require("src.core.sfx")
local lg = love.graphics

local Title = {}
local planet = { ground = { 0.45, 0.3, 0.6 }, sky = { 0.9, 0.5, 0.4 }, accent = { 0.3, 0.9, 0.8 }, ringed = true }

function Title:enter()
  self.t = 0
  self.stars = self.stars or D.makeStars(220)
  self.btn = { x = 540, y = 470, w = 200, h = 54, label = "Stick out thumb", size = 20 }
  Guide.sayKey("title")
end

function Title:update(dt) self.t = self.t + dt end

function Title:draw()
  local t = self.t
  D.fill(T.c.bg)
  D.drawStars(self.stars, t, 15)
  A.planet(1080, 640, 190, planet, t)

  local tx = 290 + math.sin(t * 0.5) * 30
  local ty = 470 + math.sin(t * 1.3) * 10
  lg.push()
  lg.translate(tx, ty)
  lg.rotate(math.sin(t * 0.7) * 0.05)
  A.truck(0, 0, 1.0, t)
  lg.pop()

  D.shadowText("THE PAN-GALACTIC", 0, 70, 56, T.c.orange, "center", 1280, 4)
  D.shadowText("GARGLE BLASTER", 0, 132, 72, T.c.gold, "center", 1280, 5)
  D.text("a cosmic food truck  -  vertical slice prototype", 0, 222, 18, T.c.dim, "center", 1280)

  local mx, my = require("src.core.viewport").mouse()
  D.button(self.btn, mx, my)
  D.text("Click / Space to start   -   Esc quits   -   F11 fullscreen", 0, 538, 14, T.c.faint, "center", 1280)
  Guide.draw(340, 610, 600, 90)
end

local function start()
  sfx.play("click")
  Run.new()
  scenes.switch(require("src.scenes.hitchhike"))
end

function Title:mousepressed(x, y)
  if D.inside(self.btn, x, y) then start() end
end

function Title:keypressed(k)
  if k == "space" or k == "return" then start() end
end

return Title
