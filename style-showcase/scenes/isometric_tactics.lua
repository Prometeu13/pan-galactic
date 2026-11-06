-- ISOMETRIC, scene 3: a tactics RPG battle that plays itself.
--
-- The look is classic strategy-RPG: a raised height-map of tile columns, units standing
-- on top, and the board doing the explaining: blue tiles for where a unit can move,
-- an arrow path, red tiles for where it can strike, floating damage numbers.
--
-- Under the hood:
--   * move range = breadth-first search, max 4 steps, climbing at most 1 level per step
--   * the battle is a hump.timer *script*: plain sequential code with wait() calls
--     ("select, wait, show range, wait, walk, attack...") instead of a state machine
--   * walking uses tween.lua per tile; lunges, HP drains and pop-ups use flux
--   * everything is depth-sorted through a deep queue

local gfx = require("core.gfx")
local deep = require("deep")
local Object = require("classic")
local tween = require("tween")
local flux = require("flux")
local Timer = require("hump.timer")

local lg = love.graphics
local N = 10
local TW, TH, LH = 76, 38, 16
local OX, OY = 640, 120

local S = {
  title = "Isometric",
  subtitle = "Tactics Battle",
  blurb = "A strategy-RPG board: height-mapped tiles, move and attack ranges, path arrows, HP bars, turn order and damage pop-ups. It plays itself.",
  techniques = {
    "Height map written as digit strings; each tile is a column",
    "Move range: BFS up to 4 steps, max 1 level of climb per step",
    "Battle choreography as a sequential script with wait() (coroutines)",
    "Walking tile by tile, lunges, HP drains and damage numbers are tweens",
    "Units, tiles and overlays share one depth-sorted draw queue",
  },
  libs = {
    "hump.timer: the battle script (timer:script with wait)",
    "tween.lua: tile-to-tile walking",
    "flux: lunges, HP bars and damage pop-ups",
    "deep: depth sorting; classic: the Unit class",
  },
  genres = { "Tactics RPGs and strategy games", "Turn-based roguelites", "Board-game adaptations", "Squad-based puzzle combat" },
  warmup = 3.5, -- the moment the move range and path arrow are both on screen
}

local HEIGHTS = {
  "0001122100",
  "0011222110",
  "0012332211",
  "0012332210",
  "0011222110",
  "0001221100",
  "0000111000",
  "0000010000",
  "0000000000",
  "0000000000",
}
local BLOCKED = { ["2,6"] = "tree", ["7,2"] = "tree", ["8,7"] = "rock", ["1,4"] = "rock" }

local function height(i, j)
  local row = HEIGHTS[j + 1]
  if not row or i < 0 or i >= N then return nil end
  return tonumber(row:sub(i + 1, i + 1))
end

local function project(i, j, h)
  return OX + (i - j) * TW / 2, OY + (i + j) * TH / 2 - h * LH
end

-- Unit ------------------------------------------------------------------------------
local Unit = Object:extend()
function Unit:new(name, kind, team, i, j, hp)
  self.name, self.kind, self.team = name, kind, team
  self.i, self.j, self.pi, self.pj = i, j, i, j
  self.hp, self.maxHp, self.shown = hp, hp, hp
  self.flash, self.lunge = 0, 0
  self.home = { i, j }
end

function Unit:reset()
  self.i, self.j = self.home[1], self.home[2]
  self.pi, self.pj = self.i, self.j
  self.hp, self.shown = self.maxHp, self.maxHp
end

local COLORS = {
  knight = { 0.25, 0.45, 0.9 }, archer = { 0.25, 0.65, 0.35 }, mage = { 0.55, 0.3, 0.85 },
  goblin = { 0.75, 0.25, 0.2 }, orc = { 0.6, 0.2, 0.15 },
}

function Unit:draw(scene)
  local hgt = scene:heightAt(self.pi, self.pj)
  local x, y = project(self.pi + 0.5, self.pj + 0.5, hgt)
  local dir = self.team == "ally" and 1 or -1
  x = x + self.lunge * 14 * dir
  y = y - self.lunge * 4
  local c = COLORS[self.kind]
  local big = self.kind == "orc" and 1.25 or 1
  lg.setColor(0, 0, 0, 0.3)
  lg.ellipse("fill", x, y, 16 * big, 7 * big)
  lg.setColor(self.team == "ally" and { 0.4, 0.7, 1, 0.8 } or { 1, 0.35, 0.3, 0.8 })
  lg.setLineWidth(2)
  lg.ellipse("line", x, y, 17 * big, 8 * big)
  lg.push()
  lg.translate(x, y)
  lg.scale(big)
  local skin = (self.team == "enemy") and { 0.45, 0.65, 0.3 } or { 0.95, 0.78, 0.62 }
  lg.setColor(c)
  lg.polygon("fill", -11, -6, 11, -6, 8, -34, -8, -34)
  lg.setColor(skin)
  lg.circle("fill", 0, -42, 9)
  if self.kind == "knight" then
    lg.setColor(0.75, 0.78, 0.85)
    lg.arc("fill", 0, -44, 10, math.pi, math.pi * 2)
    lg.setLineWidth(3)
    lg.line(12, -14, 12 + 6 * dir, -44)
  elseif self.kind == "archer" then
    lg.setColor(0.2, 0.45, 0.25)
    lg.arc("fill", 0, -43, 11, math.pi * 0.9, math.pi * 2.1)
    lg.setColor(0.55, 0.38, 0.2)
    lg.setLineWidth(2)
    lg.arc("line", "open", 12, -24, 16, -math.pi / 2, math.pi / 2)
  elseif self.kind == "mage" then
    lg.setColor(0.4, 0.2, 0.7)
    lg.polygon("fill", -12, -46, 12, -46, 2, -72)
    lg.setColor(0.55, 0.38, 0.2)
    lg.setLineWidth(2)
    lg.line(-14, -4, -14, -52)
    lg.setColor(0.6, 0.9, 1)
    lg.circle("fill", -14, -55, 4 + math.sin(scene.t * 5) * 0.8)
  else
    lg.setColor(1, 0.2, 0.1)
    lg.circle("fill", -3 * dir, -43, 1.8)
    lg.circle("fill", 4 * dir, -43, 1.8)
    lg.setColor(0.7, 0.7, 0.75)
    lg.setLineWidth(3)
    lg.line(-12 * dir, -14, -16 * dir, -30)
  end
  if self.flash > 0 then
    lg.setColor(1, 1, 1, self.flash)
    lg.polygon("fill", -11, -6, 11, -6, 8, -34, -8, -34)
    lg.circle("fill", 0, -42, 9)
  end
  lg.pop()
  -- HP bar
  local w = 40
  local bx, by = x - w / 2, y - 70 * big - 8
  lg.setColor(0, 0, 0, 0.7)
  lg.rectangle("fill", bx - 1, by - 1, w + 2, 7)
  local f = math.max(0, self.shown / self.maxHp)
  lg.setColor(f > 0.5 and { 0.3, 0.9, 0.4 } or (f > 0.25 and { 1, 0.8, 0.2 } or { 1, 0.3, 0.25 }))
  lg.rectangle("fill", bx, by, w * f, 5)
end

-- Scene -----------------------------------------------------------------------------
function S:heightAt(i, j)
  local h1 = height(math.floor(i + 0.5), math.floor(j + 0.5)) or 0
  return h1
end

function S:occupied(i, j, except)
  for _, u in ipairs(self.units) do
    if u ~= except and u.i == i and u.j == j and u.hp > 0 then return true end
  end
  return BLOCKED[i .. "," .. j] ~= nil
end

function S:moveRange(u, steps)
  local dist, prev, q, head = {}, {}, { { u.i, u.j } }, 1
  local key = function(i, j) return j * 100 + i end
  dist[key(u.i, u.j)] = 0
  while head <= #q do
    local c = q[head]; head = head + 1
    local d = dist[key(c[1], c[2])]
    if d < steps then
      for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local ni, nj = c[1] + o[1], c[2] + o[2]
        local h0, h1 = height(c[1], c[2]), height(ni, nj)
        if h1 and dist[key(ni, nj)] == nil and math.abs(h1 - h0) <= 1 and not self:occupied(ni, nj, u) then
          dist[key(ni, nj)] = d + 1
          prev[key(ni, nj)] = c
          q[#q + 1] = { ni, nj }
        end
      end
    end
  end
  return dist, prev
end

function S:load()
  self.t = 0
  self.layer = deep:new()
  self.timer = Timer.new()
  self.flux = flux.group()
  self.tweens = {}
  self.popups = {}
  self.font = lg.newFont(16)
  self.big = lg.newFont(34)
  self.dmgFont = lg.newFont(26)
  self.units = {
    Unit("Aria", "knight", "ally", 2, 7, 60), Unit("Bram", "archer", "ally", 4, 8, 42),
    Unit("Cleo", "mage", "ally", 6, 8, 36),
    Unit("Grub", "goblin", "enemy", 4, 2, 40), Unit("Skrag", "orc", "enemy", 5, 3, 70),
    Unit("Nix", "goblin", "enemy", 6, 1, 40),
  }
  self.banner = { text = "", alpha = 0, x = 0 }
  self.timer:script(function(wait) self:battle(wait) end)
end

function S:showBanner(text)
  local b = self.banner
  b.text, b.alpha, b.x = text, 0, -200
  self.flux:to(b, 0.4, { alpha = 1, x = 0 }):ease("backout")
    :after(b, 0.4, { alpha = 0, x = 200 }):delay(0.9):ease("quadin")
end

function S:attack(u, target)
  self.attackTiles = nil
  self.flux:to(u, 0.12, { lunge = 1 }):ease("quadout"):after(u, 0.25, { lunge = 0 }):ease("quadin")
  local dmg = love.math.random(12, 24)
  target.hp = math.max(1, target.hp - dmg)
  target.flash = 1
  self.flux:to(target, 0.4, { flash = 0 }):delay(0.1)
  self.flux:to(target, 0.8, { shown = target.hp }):delay(0.15)
  local hx, hy = project(target.pi + 0.5, target.pj + 0.5, height(target.i, target.j))
  local p = { x = hx, y = hy - 80, text = tostring(dmg), alpha = 1, scale = 0.4 }
  self.popups[#self.popups + 1] = p
  self.flux:to(p, 0.25, { scale = 1.2 }):ease("backout")
  self.flux:to(p, 1.1, { y = hy - 130, alpha = 0 }):delay(0.4)
end

-- The whole battle, written top to bottom. wait(seconds) pauses the coroutine.
function S:battle(wait)
  while true do
    self:showBanner("PLAYER PHASE")
    wait(1.6)
    for _, u in ipairs(self.units) do
      if u.team == "ally" then
        self.selected = u
        wait(0.5)
        local dist, prev = self:moveRange(u, 4)
        self.range = dist
        wait(1.0)
        -- pick the reachable tile closest to any enemy
        local best, bestD, target = nil, 1e9, nil
        for k in pairs(dist) do
          local i, j = k % 100, math.floor(k / 100)
          for _, e in ipairs(self.units) do
            if e.team == "enemy" then
              local d = math.abs(e.i - i) + math.abs(e.j - j)
              if d >= 1 and d < bestD then best, bestD, target = { i, j }, d, e end
            end
          end
        end
        local path, c = {}, best
        while c do
          table.insert(path, 1, c)
          c = prev[c[2] * 100 + c[1]]
        end
        self.path = path
        wait(0.7)
        self.range = nil
        for s = 2, #path do
          local step = path[s]
          self.tweens[#self.tweens + 1] = tween.new(0.24, u, { pi = step[1], pj = step[2] }, "inOutQuad")
          wait(0.26)
          u.i, u.j = step[1], step[2]
        end
        self.path = nil
        self.attackTiles = { { u.i + 1, u.j }, { u.i - 1, u.j }, { u.i, u.j + 1 }, { u.i, u.j - 1 } }
        wait(0.5)
        if bestD == 1 then self:attack(u, target) else self.attackTiles = nil end
        wait(1.2)
      end
    end
    self.selected = nil
    self:showBanner("ENEMY PHASE")
    wait(2.2)
    for _, u in ipairs(self.units) do u:reset() end
  end
end

function S:update(dt)
  self.t = self.t + dt
  self.timer:update(dt)
  self.flux:update(dt)
  for k = #self.tweens, 1, -1 do
    if self.tweens[k]:update(dt) then table.remove(self.tweens, k) end
  end
  for k = #self.popups, 1, -1 do
    if self.popups[k].alpha <= 0.01 and self.popups[k].scale > 1 then table.remove(self.popups, k) end
  end
end

function S:drawTile(i, j)
  local h = height(i, j)
  local x, y = project(i, j, h)
  local top = h >= 3 and { 0.62, 0.6, 0.55 } or (h == 2 and { 0.58, 0.68, 0.38 } or { 0.45, 0.68, 0.35 })
  if (i + j) % 2 == 0 then top = { top[1] * 0.94, top[2] * 0.94, top[3] * 0.94 } end
  local base = h * LH + 24
  lg.setColor(0.42, 0.3, 0.2)
  lg.polygon("fill", x - TW / 2, y + TH / 2, x, y + TH, x, y + TH + base, x - TW / 2, y + TH / 2 + base)
  lg.setColor(0.32, 0.22, 0.15)
  lg.polygon("fill", x, y + TH, x + TW / 2, y + TH / 2, x + TW / 2, y + TH / 2 + base, x, y + TH + base)
  lg.setColor(top)
  lg.polygon("fill", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  lg.setColor(0, 0, 0, 0.12)
  lg.setLineWidth(1)
  lg.polygon("line", x, y, x + TW / 2, y + TH / 2, x, y + TH, x - TW / 2, y + TH / 2)
  -- overlays: move range (blue), attack range (red)
  local pulse = 0.25 + 0.1 * math.sin(self.t * 5)
  if self.range and self.range[j * 100 + i] then
    lg.setColor(0.2, 0.5, 1, pulse + 0.3)
    lg.polygon("fill", x, y + 3, x + TW / 2 - 5, y + TH / 2, x, y + TH - 3, x - TW / 2 + 5, y + TH / 2)
    lg.setColor(0.8, 0.9, 1, 0.8)
    lg.setLineWidth(2)
    lg.polygon("line", x, y + 3, x + TW / 2 - 5, y + TH / 2, x, y + TH - 3, x - TW / 2 + 5, y + TH / 2)
  end
  if self.attackTiles then
    for _, a in ipairs(self.attackTiles) do
      if a[1] == i and a[2] == j then
        lg.setColor(1, 0.3, 0.25, pulse + 0.2)
        lg.polygon("fill", x, y + 3, x + TW / 2 - 5, y + TH / 2, x, y + TH - 3, x - TW / 2 + 5, y + TH / 2)
      end
    end
  end
  local b = BLOCKED[i .. "," .. j]
  if b == "tree" then
    lg.setColor(0.35, 0.22, 0.12)
    lg.rectangle("fill", x - 4, y + TH / 2 - 30, 8, 30)
    lg.setColor(0.2, 0.5, 0.25)
    lg.circle("fill", x, y + TH / 2 - 44, 22)
    lg.setColor(0.3, 0.62, 0.32)
    lg.circle("fill", x - 7, y + TH / 2 - 50, 11)
  elseif b == "rock" then
    lg.setColor(0.55, 0.55, 0.58)
    lg.ellipse("fill", x, y + TH / 2 - 8, 20, 14)
    lg.setColor(0.7, 0.7, 0.72)
    lg.ellipse("fill", x - 5, y + TH / 2 - 13, 9, 6)
  end
end

function S:drawPath()
  if not self.path or #self.path < 2 then return end
  local pts = {}
  for _, p in ipairs(self.path) do
    local x, y = project(p[1] + 0.5, p[2] + 0.5, height(p[1], p[2]))
    pts[#pts + 1] = x; pts[#pts + 1] = y
  end
  lg.setColor(1, 1, 1, 0.9)
  lg.setLineWidth(5)
  lg.line(pts)
  local n = #pts
  local ax, ay, bx, by = pts[n - 3], pts[n - 2], pts[n - 1], pts[n]
  local a = math.atan2(by - ay, bx - ax)
  lg.polygon("fill", bx + math.cos(a) * 10, by + math.sin(a) * 10,
    bx + math.cos(a + 2.4) * 12, by + math.sin(a + 2.4) * 12, bx + math.cos(a - 2.4) * 12, by + math.sin(a - 2.4) * 12)
end

function S:drawUI()
  -- turn order strip
  lg.setFont(self.font)
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", 14, 646, 500, 60, 10)
  lg.setColor(1, 1, 1, 0.8)
  lg.print("TURN ORDER", 26, 652)
  local k = 0
  for _, u in ipairs(self.units) do
    local x = 40 + k * 80
    local c = COLORS[u.kind]
    lg.setColor(c)
    lg.circle("fill", x, 688, 14)
    if u == self.selected then
      lg.setColor(1, 0.85, 0.3)
      lg.setLineWidth(3)
      lg.circle("line", x, 688, 17)
    end
    lg.setColor(1, 1, 1, 0.85)
    lg.print(u.name, x + 18, 680)
    k = k + 1
  end
  -- selected unit card + action menu
  local u = self.selected
  if u then
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 1280 - 300, 520, 286, 186, 10)
    lg.setColor(1, 0.85, 0.3)
    lg.setFont(self.dmgFont)
    lg.print(u.name, 1280 - 284, 530)
    lg.setFont(self.font)
    lg.setColor(1, 1, 1, 0.8)
    lg.print(("%s   HP %d/%d   MOV 4"):format(u.kind:upper(), math.floor(u.shown + 0.5), u.maxHp), 1280 - 284, 566)
    local items = { "Move", "Attack", "Skill", "Wait" }
    local active = self.range and 1 or (self.attackTiles and 2 or 1)
    for i, it in ipairs(items) do
      local y = 596 + (i - 1) * 26
      if i == active then
        lg.setColor(1, 0.85, 0.3, 0.25)
        lg.rectangle("fill", 1280 - 290, y - 2, 266, 24, 4)
        lg.setColor(1, 0.85, 0.3)
        lg.print("> " .. it, 1280 - 280, y)
      else
        lg.setColor(1, 1, 1, 0.7)
        lg.print("  " .. it, 1280 - 280, y)
      end
    end
  end
  -- phase banner
  local b = self.banner
  if b.alpha > 0.01 then
    lg.setColor(0, 0, 0, 0.6 * b.alpha)
    lg.rectangle("fill", 0, 300, 1280, 70)
    lg.setFont(self.big)
    lg.setColor(1, 0.9, 0.5, b.alpha)
    lg.printf(b.text, b.x, 314, 1280, "center")
  end
end

function S:draw()
  lg.setColor(1, 1, 1)
  self.bg = self.bg or gfx.vgradient(1280, 720, { { 0, gfx.rgb("#7fb7d8") }, { 1, gfx.rgb("#e8d9b0") } })
  lg.draw(self.bg)
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      self.layer:queue((i + j) * 10, function() self:drawTile(i, j) end)
    end
  end
  for _, u in ipairs(self.units) do
    local z = math.floor((u.pi + u.pj) * 10 + 0.5) + 6
    self.layer:queue(z, function() u:draw(self) end)
  end
  self.layer:draw()
  self:drawPath()
  -- bouncing cursor over the selected unit
  local u = self.selected
  if u then
    local x, y = project(u.pi + 0.5, u.pj + 0.5, self:heightAt(u.pi, u.pj))
    local bob = math.sin(self.t * 6) * 5
    lg.setColor(1, 0.85, 0.3)
    lg.polygon("fill", x - 9, y - 104 + bob, x + 9, y - 104 + bob, x, y - 90 + bob)
  end
  for _, p in ipairs(self.popups) do
    lg.setFont(self.dmgFont)
    lg.push()
    lg.translate(p.x, p.y)
    lg.scale(p.scale)
    gfx.outlinedText(p.text, -16, -14, { 1, 0.95, 0.4, p.alpha }, { 0.4, 0, 0, p.alpha }, 2)
    lg.pop()
  end
  self:drawUI()
end

return S
