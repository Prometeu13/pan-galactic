-- Ingredients. `staple` ones live in the truck's pantry forever (infinite).
-- Foraged ones are found on planets. Rule of thumb: an ingredient must never react with itself
-- (see content/reactions.lua), or it becomes impossible to cook "pure".
-- shape: berry, truffle, kelp, crystal, pepper, egg, noodle, leaf, root, mango, gristle, corn, jar
local list = {
  -- Pantry staples
  { id = "salt", name = "Space Salt", tags = { "Smug" }, shape = "jar", color = { 0.92, 0.92, 0.98 }, staple = true,
    blurb = "Harvested from the tears of smug comets." },
  { id = "tea", name = "Leftover Tea", tags = { "Nostalgia" }, shape = "jar", color = { 0.72, 0.5, 0.3 }, staple = true,
    blurb = "It was a good cup of tea once. Like everything." },
  { id = "ice", name = "Mystery Ice", tags = { "Cold" }, shape = "jar", color = { 0.7, 0.88, 1 }, staple = true,
    blurb = "Origin: unknown. Flavour: also unknown." },

  -- Foraged
  { id = "joyberry", name = "Xylopian Joy-Berries", tags = { "Joy", "Red", "Volatile" }, shape = "berry", color = { 1, 0.3, 0.38 },
    blurb = "Giggle when squeezed. Occasionally detonate." },
  { id = "doomtruffle", name = "Doom Truffle", tags = { "Doom", "Crunchy" }, shape = "truffle", color = { 0.32, 0.22, 0.28 },
    blurb = "Pigs refuse to find these. They know." },
  { id = "weepkelp", name = "Weeping Kelp", tags = { "Melancholy", "Slimy", "Blue" }, shape = "kelp", color = { 0.3, 0.55, 0.85 },
    blurb = "Sobs quietly at low tide." },
  { id = "nostalgium", name = "Nostalgium Crystals", tags = { "Nostalgia", "Crunchy", "Cold" }, shape = "crystal", color = { 1, 0.75, 0.45 },
    blurb = "Each facet shows a better version of last year." },
  { id = "panicpepper", name = "Panic Pepper", tags = { "Panic", "Hot" }, shape = "pepper", color = { 1, 0.42, 0.2 },
    blurb = "Screams before you bite it, to save time." },
  { id = "gristle", name = "Committee Gristle", tags = { "Slimy", "Doom", "Green" }, shape = "gristle", color = { 0.5, 0.62, 0.4 },
    blurb = "Formed when a committee sits too long." },
  { id = "fizzwort", name = "Fizzwort", tags = { "Fizzy", "Joy" }, shape = "leaf", color = { 0.4, 0.95, 0.9 },
    blurb = "Hums show tunes when you're not looking." },
  { id = "frostlichen", name = "Frost Lichen", tags = { "Cold", "Blue" }, shape = "leaf", color = { 0.7, 0.85, 1 },
    blurb = "Grows exclusively on disappointing glaciers." },
  { id = "magmango", name = "Magma Mango", tags = { "Hot", "Joy", "Fizzy" }, shape = "mango", color = { 1, 0.6, 0.15 },
    blurb = "Ripe when it starts fizzing. Peel with oven gloves." },
  { id = "egg", name = "Existential Egg", tags = { "Doom", "Nostalgia" }, shape = "egg", color = { 0.95, 0.93, 0.85 },
    blurb = "Which came first? It is still deciding." },
  { id = "noodles", name = "Polyglot Noodles", tags = { "Slimy", "Fizzy", "Panic" }, shape = "noodle", color = { 1, 0.88, 0.45 },
    blurb = "Shriek in forty languages when boiled." },
  { id = "ennui", name = "Ennui Root", tags = { "Melancholy", "Crunchy" }, shape = "root", color = { 0.62, 0.5, 0.7 },
    blurb = "Can't be bothered to grow properly." },
  { id = "swampleaf", name = "Swamp Parsley", tags = { "Green", "Slimy" }, shape = "leaf", color = { 0.35, 0.75, 0.3 },
    blurb = "Garnish of choice for creatures that live in garnish." },
  { id = "voltcorn", name = "Volt-Corn", tags = { "Volatile", "Crunchy", "Panic" }, shape = "corn", color = { 1, 0.92, 0.3 },
    blurb = "Pops. Then the corn around it pops. Then the truck." },
  { id = "smugberry", name = "Smugberries", tags = { "Smug", "Red" }, shape = "berry", color = { 0.85, 0.2, 0.55 },
    blurb = "Ripen faster than other berries and want you to know it." },
}

local byId = {}
for _, ing in ipairs(list) do
  byId[ing.id] = ing
  for _, t in ipairs(ing.tags) do
    if t == "Volatile" then ing.volatile = true end
  end
end

return { list = list, byId = byId }
