-- Truck upgrades, bought between planets.
local list = {
  { id = "pot4", name = "Fourth Ladle Slot", price = 60,
    desc = "The Synthesizer holds 4 ingredients instead of 3. More chaos, more options." },
  { id = "tasteotron", name = "Taste-o-Tron 3000", price = 90,
    desc = "Reveals every tag on every ingredient. Takes the mystery out of mystery meat." },
  { id = "basket", name = "Bigger Basket", price = 40,
    desc = "Carry 12 ingredients while foraging instead of 8." },
  { id = "navcom", name = "Probably-Accurate Nav-Com", price = 50,
    desc = "See where wormholes go, and spot an extra ride." },
  { id = "dice", name = "Fuzzy Dice", price = 30,
    desc = "Customers find them reassuring. +25% patience." },
  { id = "jetboots", name = "Jet Boots", price = 45,
    desc = "Forage 40% faster. Mild risk of becoming a satellite." },
}
local byId = {}
for _, u in ipairs(list) do byId[u.id] = u end
return { list = list, byId = byId }
