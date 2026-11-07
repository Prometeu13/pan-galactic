-- All the writing lives here: dialogue, haiku, hints. Edit freely.

return {
  title = "INKWING",
  subtitle = "a black stork, a small nest, the first cold wind",

  intro = {
    "The first cold wind came down the valley this morning.",
    "Your chick is hungry, and the nest is thin.",
    "Bring twigs to mend it. Bring fish to fill a small belly.",
  },

  -- shown on the HUD until the goal changes
  hints = {
    start = "Gather twigs and fish, then bring them home to the nest (top of the cliff).",
    carry = "Fly home and press E at the nest to give what you carry.",
    seal = "A red seal stone. Press E beside it to look at the view.",
    done = "The nest is warm. Wander as long as you like.",
  },

  -- region names appear when you enter a region
  regions = { "Reed Marsh", "Bamboo Village", "Mountain Pond" },

  -- one haiku per seal stone; reading it paints the region in
  haiku = {
    { "reeds bow to the wind", "a heron's old footprints fill", "with the morning sky" },
    { "rice smoke in the lanes", "someone's lantern left unlit", "bamboo hums along" },
    { "the pond holds the moon", "all day, and gives it back", "to the frog at dusk" },
  },

  chick = {
    hungry = { "Peep! Peep!", "(the chick opens its beak very, very wide)" },
    fed = { "(a satisfied little burp)" },
    twig = { "(the chick tucks the twig in, very seriously)" },
    full = { "(the chick is warm and fed, and already asleep)" },
  },

  fisherman = {
    ask = {
      "Ah, a stork. Good fishing weather, if you can see the water.",
      "I lost my lantern in the bamboo grove, east of the village.",
      "Without it I can't fish past dusk. If you find it...",
    },
    waiting = { "The bamboo grove is east of the village. My lantern has a red paper shade." },
    thanks = {
      "My lantern! You have a kind beak, friend.",
      "Here, the best of today's catch. For your little one.",
    },
    after = { "The river's quiet tonight. Good for thinking." },
  },

  frog = {
    "Ribbit. You walk like a poem with long legs.",
    "Ribbit. The fish here are slow in the cold. Peck when their shadow passes.",
    "Ribbit. Have you read the seal stones? The valley looks better after.",
  },

  villager = {
    "The storks come back every year. It means good rice.",
    "My grandmother said a stork's nest on a cliff keeps the wind off the village.",
  },

  ending = {
    "The nest is woven tight. The chick sleeps, round as a dumpling.",
    "Down in the village, the lanterns go up one by one.",
    "Winter can come now.",
  },
}
