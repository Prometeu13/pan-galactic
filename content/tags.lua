-- Every flavour tag in the galaxy.
-- `phrases` are how customers describe a tag. The {braced} word gets highlighted in the tag's
-- colour, so players slowly learn the alien menu language. Keep everything ASCII.
-- `word` is used for "and NOTHING <word>" clauses.
-- `emergent` tags never appear on ingredients: they only come out of reactions (content/reactions.lua).

local defs = {
  Joy = { color = { 1.00, 0.84, 0.22 }, word = "joyful",
    phrases = { "pure, uncut {joy}", "a {happy} accident", "finding {joy} in an old coat pocket" } },
  Doom = { color = { 0.86, 0.22, 0.32 }, word = "doomy",
    phrases = { "impending {doom}", "the heat death of the universe, {doom}-wise", "a Monday made of {doom}" } },
  Melancholy = { color = { 0.48, 0.58, 0.92 }, word = "melancholy",
    phrases = { "a hint of {melancholy}", "a rainy Tuesday of {melancholy}", "{sad} jazz in a lift" } },
  Nostalgia = { color = { 0.88, 0.68, 0.46 }, word = "nostalgic",
    phrases = { "a childhood I never had, very {nostalgic}", "the {good old days}", "my grandmother's {nostalgic} gravy" } },
  Smug = { color = { 0.32, 0.84, 0.64 }, word = "smug",
    phrases = { "quiet {smug} superiority", "a being who owns two towels, {smug}ly", "being {right} on the internet" } },
  Panic = { color = { 1.00, 0.38, 0.62 }, word = "panicky",
    phrases = { "mild {panic}", "a deadline {whooshing} past", "{panic} at the self-checkout" } },
  Red = { color = { 1.00, 0.32, 0.26 }, word = "red",
    phrases = { "the colour {red}", "something {red}, but emotionally", "a {red} light you ran anyway" } },
  Blue = { color = { 0.32, 0.58, 1.00 }, word = "blue",
    phrases = { "the colour {blue}", "a {blue} that hums", "the inside of a {blue} whale" } },
  Green = { color = { 0.42, 0.90, 0.32 }, word = "green",
    phrases = { "the colour {green}", "{green}, as a concept", "envy, the {green} kind" } },
  Crunchy = { color = { 0.86, 0.64, 0.34 }, word = "crunchy",
    phrases = { "a satisfying {crunch}", "stepping on autumn leaves, {crunchy}", "gravel, but {crunchy} in a nice way" } },
  Slimy = { color = { 0.60, 0.92, 0.74 }, word = "slimy",
    phrases = { "a {slimy} handshake", "a politician's promise, {slimy}", "something {slimy} under a rock" } },
  Fizzy = { color = { 0.62, 0.95, 1.00 }, word = "fizzy",
    phrases = { "{fizzy} enthusiasm", "a sneeze, but {fizzy}", "{bubbles} with ambition" } },
  Hot = { color = { 1.00, 0.52, 0.16 }, word = "hot",
    phrases = { "the surface of a {hot} star", "a {spicy} rumour", "{hot} gossip" } },
  Cold = { color = { 0.78, 0.92, 1.00 }, word = "cold",
    phrases = { "a {cold} shoulder", "the {chill} of the void", "an ex's {cold} stare" } },
  Volatile = { color = { 0.86, 0.46, 1.00 }, word = "volatile",
    phrases = { "something {volatile}", "a {twitchy} temper", "an {unstable} relationship" } },

  -- Emergent tags (only from reactions)
  Irony = { color = { 0.80, 0.80, 0.86 }, word = "ironic", emergent = true,
    phrases = { "deep {irony}", "a {sarcastic} slow clap", "rain on your wedding day, {ironically}" } },
  Lukewarm = { color = { 0.86, 0.80, 0.62 }, word = "lukewarm", emergent = true,
    phrases = { "{lukewarm} commitment", "bathwater left out, {lukewarm}", "a {meh} handshake" } },
  Wistful = { color = { 0.68, 0.74, 1.00 }, word = "wistful", emergent = true,
    phrases = { "a {wistful} sigh", "staring {wistfully} out of a spaceship", "the one that got away, {wistful}" } },
  Purple = { color = { 0.74, 0.40, 0.96 }, word = "purple", emergent = true,
    phrases = { "the colour {purple}", "royalty, but {purple}", "a bruise, artistically {purple}" } },
  Explosive = { color = { 1.00, 0.28, 0.10 }, word = "explosive", emergent = true,
    phrases = { "an {explosive} finale", "{kaboom}", "fireworks in a {blast} radius" } },
  Bureaucratic = { color = { 0.70, 0.70, 0.48 }, word = "bureaucratic", emergent = true,
    phrases = { "{bureaucracy} in triplicate", "a {form} that needs another form", "waiting in a {queue}" } },
}

-- Stable order for UI and tests.
local order = {
  "Joy", "Doom", "Melancholy", "Nostalgia", "Smug", "Panic", "Red", "Blue", "Green",
  "Crunchy", "Slimy", "Fizzy", "Hot", "Cold", "Volatile",
  "Irony", "Lukewarm", "Wistful", "Purple", "Explosive", "Bureaucratic",
}

return { defs = defs, order = order }
