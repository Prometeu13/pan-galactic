-- The story engine: chapters, hotspots, dialogue with choices, the flock, the film look.
--
-- Rendering follows the style showcase's Noir scene: every scene is painted in colour,
-- characters and props cast ray-traced shadows (lighter), the light map is multiplied
-- over the frame, glowing things are added on top, and a moonshine chain grades it to
-- black and white with grain and a vignette. In the finale the grade eases off, so the
-- colour comes back with the dawn.

local story = require("src.story")
local scenes = require("src.scenes")
local Pigeon = require("src.pigeon")
local sfx = require("src.sfx")
local moonshine = require("moonshine")
local Lighter = require("lighter")

local lg = love.graphics
local game = {}

local BAR = 62               -- letterbox height
local LOOKS = {
  rosa = { scale = 1, body = { 0.62, 0.58, 0.56 }, neck = { 0.5, 0.35, 0.45 } },
  tony = { scale = 1.25, body = { 0.45, 0.46, 0.5 }, fluffed = true },
  wren = { scale = 0.75, body = { 0.68, 0.68, 0.7 } },
}

function game.new(opts)
  local g = setmetatable({}, { __index = game })
  g.t = 0
  g.flags, g.clues, g.visited = {}, {}, {}
  g.kind, g.grit = 0, 0
  g.flock = {}
  g.dawn, g.salAwake = 0, false
  g.input = {}
  g.fx = moonshine(1280, 720, moonshine.effects.desaturate)
    .chain(moonshine.effects.filmgrain)
    .chain(moonshine.effects.vignette)
  g.fx.desaturate.tint = { 255, 250, 240 }
  g.fx.filmgrain.opacity = 0.3
  g.fx.filmgrain.size = 2
  g.fx.vignette.radius = 0.78
  g.fx.vignette.softness = 0.6
  g.fx.vignette.opacity = 0.65
  g.lightCanvas = lg.newCanvas(1280, 720)
  g.rain = {}
  for i = 1, 340 do
    g.rain[i] = { x = love.math.random(-200, 1300), y = love.math.random(-720, 720), v = love.math.random(900, 1300), l = love.math.random(14, 30) }
  end
  g.top = BAR                -- the top letterbox grows to hold dialogue
  g:startChapter(1, opts and opts.title)
  return g
end

-- Chapters -------------------------------------------------------------------------------
function game:startChapter(i, titleScreen)
  self.chapterIndex = i
  self.ch = story.chapters[i]
  self.sc = scenes[self.ch.id]()
  self.lighter = Lighter({ litPolygons = true })
  for _, p in ipairs(self.sc.occluders) do self.lighter:addPolygon(p) end
  for _, l in ipairs(self.sc.lights) do self.lighter:addLight(l[1], l[2], l[3], l[4], l[5], l[6]) end
  self.dynamic = {}
  self.gus = Pigeon.new(self.ch.start)
  for k, f in ipairs(self.flock) do
    f.x, f.y, f.perchY = self.ch.start - k * 50, Pigeon.GROUND, nil
  end
  self.dlg, self.pendingExit = nil, false
  if titleScreen then
    self.mode = "title"
  else
    self.mode, self.cardT = "card", 0
    sfx.play("card", 1, 0.8)
  end
end

function game:beginPlay()
  self.mode = "play"
  self:playLines(self.ch.intro)
end

-- Clues, flags, requirements -------------------------------------------------------------
function game:hasClue(name)
  for _, c in ipairs(self.clues) do if c == name then return true end end
  return false
end

function game:met(reqs)
  for _, r in ipairs(reqs or {}) do
    if not self.flags[r] and not self:hasClue(r) then return false end
  end
  return true
end

-- Dialogue ---------------------------------------------------------------------------------
function game:playLines(lines)
  local node = { lines = {} }
  for _, l in ipairs(lines) do node.lines[#node.lines + 1] = { "", l } end
  self:openNode(node)
end

function game:playNode(id)
  local node = self.ch.nodes[id]
  assert(node, "missing story node: " .. tostring(id))
  self:openNode(node)
end

function game:openNode(node)
  if node.give and not self:hasClue(node.give) then
    self.clues[#self.clues + 1] = node.give
    self.newClue = { name = node.give, t = 0 }
  end
  if node.flag then self.flags[node.flag] = true end
  if node.join and not self.flags["joined_" .. node.join] then
    self.flags["joined_" .. node.join] = true
    self.flock[#self.flock + 1] = { id = node.join, look = LOOKS[node.join], x = self.gus.x - 60, y = Pigeon.GROUND, dir = 1 }
    sfx.play("coo", 0.9 + #self.flock * 0.1, 0.7)
  end
  if node.ending then self.pendingEnding = true end
  self.dlg = { node = node, line = 1, typed = 0, choosing = false, sel = 1 }
  if self.mode == "play" then self.mode = "talk" end
end

function game:currentLine()
  local d = self.dlg
  return d and d.node.lines[d.line]
end

function game:advance()
  local d = self.dlg
  if not d then return end
  local line = self:currentLine()
  if d.choosing then return self:choose(d.sel) end
  if line and d.typed < #line[2] then
    d.typed = #line[2]
  elseif d.line < #d.node.lines then
    d.line, d.typed = d.line + 1, 0
  elseif d.node.choices then
    d.choosing, d.sel = true, 1
  elseif d.node.next then
    self:playNode(d.node.next)
  else
    self:closeDialogue()
  end
end

function game:choose(i)
  local d = self.dlg
  local c = d and d.choosing and d.node.choices[i]
  if not c then return end
  self.kind = self.kind + (c.kind or 0)
  self.grit = self.grit + (c.grit or 0)
  sfx.play("type", 0.6, 0.6)
  if c.go then self:playNode(c.go) else self:closeDialogue() end
end

function game:closeDialogue()
  self.dlg = nil
  if self.mode == "talk" then self.mode = "play" end
  if self.pendingEnding then
    self.pendingEnding = false
    self:startEnding()
  elseif self.pendingExit then
    self.pendingExit = false
    if self.chapterIndex < #story.chapters then self:startChapter(self.chapterIndex + 1) end
  end
end

-- Hotspots ---------------------------------------------------------------------------------
function game:nearHotspot()
  local gus = self.gus
  if gus.hop then return nil end
  local best, bestD
  for _, h in ipairs(self.ch.hotspots) do
    local d
    if h.perch then
      d = math.abs(gus.x - h.x)
      if gus.perch and gus.perch.id == h.perch then d = math.sqrt((gus.x - h.x) ^ 2 + ((gus.y - 20) - h.y) ^ 2) end
    else
      d = math.sqrt((gus.x - h.x) ^ 2 + ((gus.y - 20) - h.y) ^ 2)
      if h.kind == "exit" then d = math.abs(gus.x - h.x) end
    end
    if d < h.r and (not bestD or d < bestD) then best, bestD = h, d end
  end
  return best
end

function game:interact()
  if self.mode == "card" then if self.cardT > 0.8 then self:beginPlay() end return "card" end
  if self.mode == "talk" then self:advance() return "advance" end
  if self.mode ~= "play" then return nil end
  local h = self:nearHotspot()
  if not h then return nil end
  if h.perch and not (self.gus.perch and self.gus.perch.id == h.perch) then
    if h.needPerch then self:playNode(h.needPerch) end
    return "needPerch"
  end
  if h.kind == "exit" then
    if self:met(h.requires) then
      self.pendingExit = true
      self:playNode(h.node)
      return "exit"
    end
    self:playNode(h.locked)
    return "locked"
  end
  local id = (self.visited[h.id] and h.again) or h.node
  self.visited[h.id] = true
  if h.kind == "talk" and h.id == "vinnie" then sfx.play("purr", 1, 0.5) end
  if h.id == "window" and self.ch.id == "hospital" then sfx.play("tap", 1, 0.8) end
  self:playNode(id)
  return h.id
end

-- The finale --------------------------------------------------------------------------------
function game:startEnding()
  self.mode = "ending"
  self.salAwake = true
  self.endT = 0
  local tone = (self.kind >= self.grit) and "kind" or "grit"
  self.tone = tone
  self.epilogue = story.epilogue[tone]
  self.epi, self.epiT = 1, 0
  sfx.play("dawn", 1, 0.9)
  for k, f in ipairs(self.flock) do
    f.perchY = 412
    f.x = 620 + k * 50
  end
end

-- Input -------------------------------------------------------------------------------------
function game:keypressed(k)
  if self.mode == "theend" then return end
  if self.mode == "talk" and self.dlg and self.dlg.choosing then
    local n = #self.dlg.node.choices
    if k == "up" or k == "w" then self.dlg.sel = (self.dlg.sel - 2) % n + 1 return end
    if k == "down" or k == "s" then self.dlg.sel = self.dlg.sel % n + 1 return end
    local num = tonumber(k)
    if num and num >= 1 and num <= n then self:choose(num) return end
  end
  if k == "e" or k == "space" or k == "return" or k == "j" then
    if self.mode == "ending" then
      self:nextEpilogue()
    else
      self:interact()
    end
  elseif self.mode == "play" then
    if k == "up" or k == "w" then self.gus:flyUp(self.ch.perches)
    elseif k == "down" or k == "s" then self.gus:hopDown() end
  end
end

function game:nextEpilogue()
  if not self.epilogue then return end
  local line = self.epilogue[self.epi]
  if self.epiT * 45 < #line then
    self.epiT = #line / 45
  elseif self.epi < #self.epilogue then
    self.epi, self.epiT = self.epi + 1, 0
  else
    self.mode, self.theEndT = "theend", 0
  end
end

-- Update ------------------------------------------------------------------------------------
function game:update(dt, scripted)
  self.t = self.t + dt
  sfx.loop("rain", 0.45 * (1 - self.dawn))
  for _, r in ipairs(self.rain) do
    r.y = r.y + r.v * dt
    r.x = r.x + r.v * 0.15 * dt
    if r.y > 720 then r.y, r.x = r.y - 780 - love.math.random(0, 200), love.math.random(-200, 1300) end
  end
  if self.sc.update then self.sc.update(self, dt) end
  if self.newClue then
    self.newClue.t = self.newClue.t + dt
    if self.newClue.t > 3 then self.newClue = nil end
  end
  if self.mode == "card" then
    self.cardT = self.cardT + dt
    if self.cardT > 4.5 then self:beginPlay() end
    return
  end
  if self.mode == "theend" then self.theEndT = self.theEndT + dt return end

  if not scripted then
    local kb = love.keyboard
    self.input.left = self.mode == "play" and (kb.isDown("left") or kb.isDown("a"))
    self.input.right = self.mode == "play" and (kb.isDown("right") or kb.isDown("d"))
  end
  self.gus:update(dt, self.input)

  -- the flock follows a few steps behind, and perches where Gus perches
  for k, f in ipairs(self.flock) do
    local tx, ty
    if f.perchY then
      tx, ty = f.x, f.perchY
    elseif self.gus.perch then
      local p = self.gus.perch
      tx = math.max(p.x1 + 10, math.min(p.x2 - 10, self.gus.x - self.gus.dir * 46 * k))
      ty = p.y
    else
      tx, ty = math.max(30, math.min(1250, self.gus.x - self.gus.dir * 50 * k)), Pigeon.GROUND
    end
    local dx = tx - f.x
    if math.abs(dx) > 2 then f.dir = dx > 0 and 1 or -1 end
    f.walking = math.abs(dx) > 4
    f.x = f.x + dx * math.min(1, dt * 2.5)
    f.y = f.y + (ty - f.y) * math.min(1, dt * 4)
    f.flying = math.abs(ty - f.y) > 4
    f.walk = (f.walk or 0) + (f.walking and dt * 8 or 0)
  end

  -- dialogue typing
  local line = self:currentLine()
  if line and self.dlg.typed < #line[2] then
    local before = math.floor(self.dlg.typed)
    self.dlg.typed = math.min(#line[2], self.dlg.typed + dt * 50)
    if math.floor(self.dlg.typed) ~= before and before % 3 == 0 then sfx.play("type", 0.9 + love.math.random() * 0.2, 0.25) end
  end
  if self.mode == "ending" then
    self.endT = self.endT + dt
    self.dawn = math.min(1, self.endT / 9)
    self.epiT = self.epiT + dt
    local l = self.epilogue[self.epi]
    if self.endT > 3 and self.epiT * 45 > #l + 150 then self:nextEpilogue() end
  end
  self.top = self.top + (((self.mode == "talk") and 176 or BAR) - self.top) * math.min(1, dt * 10)

  -- birds cast shadows: refresh their occluders
  for _, p in ipairs(self.dynamic) do self.lighter:removePolygon(p) end
  self.dynamic = { Pigeon.occluder(self.gus.x, self.gus.y, self.gus.dir, 1) }
  for _, f in ipairs(self.flock) do self.dynamic[#self.dynamic + 1] = Pigeon.occluder(f.x, f.y, f.dir, f.look.scale or 1) end
  for _, p in ipairs(self.dynamic) do self.lighter:addPolygon(p) end
end

-- Drawing -----------------------------------------------------------------------------------
function game:drawLightMap(target)
  lg.setCanvas({ self.lightCanvas, stencil = true })
  local a = self.sc.ambient
  lg.clear(a, a, a * 1.1, 1)
  lg.setBlendMode("add")
  self.lighter:drawLights()
  lg.setBlendMode("alpha")
  lg.setCanvas(target)
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(1, 1, 1)
  lg.draw(self.lightCanvas)
  lg.setBlendMode("alpha")
end

function game:drawScene()
  self.fx.desaturate.strength = 1 - 0.78 * self.dawn
  self.fx.vignette.opacity = 0.65 - 0.3 * self.dawn
  self.fx(function()
    local target = lg.getCanvas()
    self.sc.back(self, self.t)
    for _, f in ipairs(self.flock) do
      Pigeon.paint(f.x, f.y, f.dir, self.t, f.look, f.walk or 0, f.flying, 0)
    end
    self.gus:draw(self.t)
    self:drawLightMap(target)
    self.sc.emissive(self, self.t)
    lg.setLineWidth(1.5)
    local ra = 0.28 * (1 - self.dawn)
    for _, r in ipairs(self.rain) do
      lg.setColor(0.85, 0.88, 0.95, ra)
      lg.line(r.x, r.y, r.x - r.l * 0.15, r.y - r.l)
    end
  end)
end

function game:drawUI()
  local f = self.fonts
  -- letterbox bars (dialogue opens in the top one, so nobody on the ground is covered)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", 0, 0, 1280, self.top)
  lg.rectangle("fill", 0, 720 - BAR, 1280, BAR)
  lg.setFont(f.small)
  local talking = self.mode == "talk"
  local infoY = talking and (720 - BAR + 22) or 22
  lg.setColor(0.6, 0.6, 0.6)
  lg.print(self.ch.number .. "  ·  " .. self.ch.name, 24, infoY)
  if #self.clues > 0 then
    lg.printf("NOTEBOOK:  " .. table.concat(self.clues, "  ·  "), 400, infoY, 856, "right")
  end
  if self.newClue and not talking then
    local a = math.min(1, self.newClue.t * 3) * math.min(1, 3 - self.newClue.t)
    lg.setColor(1, 1, 1, a)
    lg.printf("+ noted: " .. self.newClue.name, 400, 40, 856, "right")
  elseif self.newClue then
    lg.setColor(1, 1, 1)
    lg.printf("+ noted: " .. self.newClue.name, 400, infoY - 18, 856, "right")
  end

  if self.mode == "play" then
    -- hotspot markers and the prompt for the nearest one
    local near = self:nearHotspot()
    for _, h in ipairs(self.ch.hotspots) do
      local a = (h == near) and 0.9 or 0.25
      local bob = math.sin(self.t * 3 + h.x) * 3
      lg.setColor(1, 1, 1, a)
      lg.push()
      lg.translate(h.x, (h.kind == "exit" and 560 or h.y - 70) + bob)
      lg.rotate(math.pi / 4)
      lg.rectangle("line", -5, -5, 10, 10)
      lg.pop()
    end
    lg.setFont(f.body)
    if near then
      local verb = (near.kind == "talk" and "talk to ") or (near.kind == "exit" and "go: ") or "look at "
      lg.setColor(1, 1, 1)
      lg.printf("E   " .. verb .. near.label, 0, 720 - BAR + 18, 1280, "center")
    elseif self.chapterIndex == 1 then
      lg.setColor(0.6, 0.6, 0.6)
      lg.setFont(f.small)
      lg.printf("arrows: walk    Up: flutter onto a perch    Down: hop down    E: look / talk / continue", 0, 720 - BAR + 22, 1280, "center")
    end
  elseif self.mode == "talk" and self.dlg then
    local d = self.dlg
    local line = self:currentLine()
    local y0 = self.top - 160
    if line then
      local who = line[1]
      local overheard = who:find("%(overheard%)") ~= nil
      lg.setFont(f.small)
      lg.setColor(overheard and { 0.6, 0.6, 0.6 } or { 0.85, 0.85, 0.85 })
      lg.print(who == "" and "GUS" or who:upper(), 120, y0)
      lg.setFont(f.body)
      lg.setColor(1, 1, 1)
      local text = line[2]
      local shown = text:sub(1, math.floor(d.typed))
      lg.printf(who == "" and shown or ("\"" .. shown .. (d.typed >= #text and "\"" or "")), 120, y0 + 24, 1040)
    end
    if d.choosing then
      lg.setColor(0, 0, 0)
      lg.rectangle("fill", 0, 0, 1280, self.top)
      lg.setFont(f.small)
      lg.setColor(0.6, 0.6, 0.6)
      lg.print("WHAT DO YOU SAY?", 120, y0)
      lg.setFont(f.body)
      for i, c in ipairs(d.node.choices) do
        local sel = i == d.sel
        lg.setColor(sel and { 1, 1, 1 } or { 0.55, 0.55, 0.55 })
        lg.printf((sel and ">  " or "   ") .. i .. ".  " .. c[1], 120, y0 + 30 + (i - 1) * 40, 1060)
      end
    elseif line and d.typed >= #line[2] then
      lg.setColor(1, 1, 1, 0.4 + 0.3 * math.sin(self.t * 5))
      lg.setFont(f.small)
      lg.printf("E", 0, self.top - 30, 1200, "right")
    end
  elseif self.mode == "ending" then
    local line = self.epilogue[self.epi]
    lg.setFont(f.body)
    lg.setColor(1, 1, 1)
    lg.printf(line:sub(1, math.floor(self.epiT * 45)), 120, 720 - BAR + 18, 1040, "center")
  end
end

function game:drawCard()
  local a = math.min(1, self.cardT * 1.5) * math.min(1, (4.5 - self.cardT) * 2)
  lg.setColor(0, 0, 0)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setFont(self.fonts.small)
  lg.setColor(0.6, 0.6, 0.6, a)
  lg.printf(self.ch.number, 0, 300, 1280, "center")
  lg.setFont(self.fonts.card)
  lg.setColor(1, 1, 1, a)
  local name = self.ch.name
  lg.printf(name:sub(1, math.floor(self.cardT * 22)), 0, 330, 1280, "center")
end

function game:drawTheEnd()
  local a = math.min(1, self.theEndT * 0.7)
  lg.setColor(0, 0, 0, a)
  lg.rectangle("fill", 0, 0, 1280, 720)
  lg.setFont(self.fonts.card)
  lg.setColor(1, 1, 1, a)
  lg.printf("THE END", 0, 260, 1280, "center")
  lg.setFont(self.fonts.body)
  lg.setColor(0.75, 0.75, 0.75, a)
  local who = self.tone == "kind" and "a soft-hearted bird in a hard town" or "a hard-boiled bird with a soft spot"
  lg.printf("Gus turned out to be " .. who .. ".", 0, 340, 1280, "center")
  lg.printf(("%d clues in the notebook.  %s"):format(#self.clues, self.flags.shared and "Pip got the crust." or "Pip went hungry that night."), 0, 380, 1280, "center")
  lg.setFont(self.fonts.small)
  lg.setColor(0.6, 0.6, 0.6, a * (0.6 + 0.3 * math.sin(self.t * 3)))
  lg.printf("press Esc for the title", 0, 470, 1280, "center")
end

function game:draw()
  if self.mode == "card" then self:drawCard() return end
  self:drawScene()
  if self.mode == "title" then return end
  self:drawUI()
  if self.mode == "theend" then self:drawTheEnd() end
end

return game
