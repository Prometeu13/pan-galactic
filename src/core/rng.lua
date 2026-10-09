-- Seeded randomness. `rng` itself is the run's generator; rng.new(seed) makes an independent
-- one (used so a planet always looks the same however often it is drawn).
local function wrap(gen)
  local r = { gen = gen }
  function r.seed(s) gen:setSeed(s) end
  function r.random(a, b)
    if a == nil then return gen:random() end
    if b == nil then return gen:random(a) end
    return gen:random(a, b)
  end
  function r.float(a, b) return a + (b - a) * gen:random() end
  function r.chance(p) return gen:random() < p end
  function r.pick(t) return t[gen:random(#t)] end
  function r.shuffle(t)
    for i = #t, 2, -1 do
      local j = gen:random(i)
      t[i], t[j] = t[j], t[i]
    end
    return t
  end
  -- items: list; weight(item) -> number >= 0
  function r.weighted(items, weight)
    local total = 0
    for _, it in ipairs(items) do total = total + weight(it) end
    if total <= 0 then return items[gen:random(#items)] end
    local x = gen:random() * total
    for _, it in ipairs(items) do
      x = x - weight(it)
      if x <= 0 then return it end
    end
    return items[#items]
  end
  return r
end

local M = wrap(love.math.newRandomGenerator(os.time()))
function M.new(seed) return wrap(love.math.newRandomGenerator(seed)) end
return M
