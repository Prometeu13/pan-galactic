-- Raw material for the planet generator (src/game/galaxy.lua).
return {
  prefixes = { "Glarb", "Zorp", "Frood", "Krikk", "Bleem", "Squorn", "Vexl", "Mung", "Trill", "Oob",
    "Haggun", "Pleth", "Wub", "Quax", "Drongo", "Fnord" },
  suffixes = { "ulon", "ax", "ia", "ox", "ton", "ee", "nik", "orp", "is", "unda" },
  numerals = { " IV", " Minor", " Prime", " 7", " (the nice one)", " Beta", " Major", "", "", " XII" },
  epithets = {
    "a planet entirely made of customer service",
    "famous for its tax returns",
    "where the weather files complaints",
    "home of the galaxy's second-largest pothole",
    "twinned with a smaller, angrier planet",
    "recently voted Most Adequate Planet",
    "where everyone is slightly too polite",
    "the galaxy's leading exporter of mild inconvenience",
    "mostly harmless, legally speaking",
    "under new management (again)",
  },
  -- Small rule twists. Missing fields mean "no change".
  -- patience/pay are multipliers, forageTime adds seconds, drones adds Form Drones, forageSpeed multiplies.
  quirks = {
    { text = "Gravity here is more of a strongly worded suggestion.", forageSpeed = 1.25 },
    { text = "Local law requires all meals be enjoyed ironically.", pay = 1.1 },
    { text = "Customers have the attention span of a startled gnat.", patience = 0.75, pay = 1.25 },
    { text = "The planet is mostly bureaucracy, with some rock.", drones = 2 },
    { text = "It's always teatime. Nobody knows why. Everyone is relaxed.", patience = 1.3 },
    { text = "Tipping is a religion here. A strict one.", pay = 1.3, patience = 0.9 },
    { text = "The ground is lava, but in a fun way. Forage quickly.", forageTime = -10, pay = 1.15 },
    { text = "Nothing unusual. That's what's unusual.", pay = 1.0 },
  },
  terrains = { "craters", "crystals", "goo", "fungus" },
}
