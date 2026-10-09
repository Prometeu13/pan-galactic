-- One scene at a time, with a fade between them.
-- A scene is a table with optional methods: enter(params), update(dt), draw(),
-- mousepressed(x, y, button), mousereleased(x, y, button), keypressed(key), wheelmoved(dx, dy).
local S = { current = nil, pending = nil, fade = 0, dir = 0 }

function S.switch(scene, params)
  if not S.current then
    S.current = scene
    scene:enter(params)
    S.fade, S.dir = 1, -1
  else
    S.pending = { scene = scene, params = params }
    S.dir = 1
  end
end

-- No fade: used by snapshots and tests.
function S.instant(scene, params)
  S.current, S.pending, S.fade, S.dir = scene, nil, 0, 0
  scene:enter(params)
end

-- True while fading out: input is ignored so nothing gets clicked twice.
function S.busy() return S.dir > 0 end

function S.update(dt)
  if S.dir ~= 0 then
    S.fade = S.fade + S.dir * dt * 3.5
    if S.dir > 0 and S.fade >= 1 then
      local p = S.pending
      S.pending, S.fade, S.dir = nil, 1, -1
      S.current = p.scene
      p.scene:enter(p.params)
    elseif S.dir < 0 and S.fade <= 0 then
      S.fade, S.dir = 0, 0
    end
  end
  S.call("update", dt)
end

function S.call(name, ...)
  local c = S.current
  if c and c[name] then return c[name](c, ...) end
end

return S
