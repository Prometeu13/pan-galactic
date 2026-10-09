-- Customers. likes: tags they tend to order (they bias which ingredients an order is built from).
-- hates: tags that ruin a dish for them. look: how src/ui/art.lua draws them.
local list = {
  { id = "grumbleon", name = "Grumbleon Clerk", plural = "Grumbleon Clerks",
    look = { shape = "tall", color = { 0.55, 0.72, 0.45 }, eyes = 2, tie = true },
    likes = { "Doom", "Slimy", "Bureaucratic", "Lukewarm", "Green" }, hates = { "Joy", "Fizzy" },
    patience = 1.35, wealth = 1.2,
    openers = { "Per form 27-B/6, I require", "Having queued for the statutory period, I request",
      "Kindly process my application for" },
    good = { "Acceptable. I shall file a positive report in triplicate.", "This meal has been approved. Stamp. Stamp." },
    bad = { "This will be referred to a sub-committee.", "I am filing a complaint. And a complaint about the complaint." } },

  { id = "android", name = "Glum Android", plural = "Glum Androids",
    look = { shape = "box", color = { 0.62, 0.66, 0.74 }, eyes = 2 },
    likes = { "Melancholy", "Doom", "Cold", "Irony", "Wistful" }, hates = { "Joy", "Fizzy" },
    patience = 1.0, wealth = 1.1,
    openers = { "I suppose I'll have", "Not that it matters, but give me", "Brain the size of a moon and I'm ordering" },
    good = { "I've been more miserable. Not recently, but I have.", "That was almost tolerable. Don't tell anyone." },
    bad = { "Just as I expected. Which is somehow worse.", "I'll add this to my list of disappointments. It's a long list." } },

  { id = "blagulon", name = "Blagulon Partygoer", plural = "Blagulon Partygoers",
    look = { shape = "cone", color = { 1, 0.45, 0.7 }, eyes = 3, hat = true },
    likes = { "Joy", "Fizzy", "Explosive", "Hot", "Panic" }, hates = { "Melancholy", "Cold" },
    patience = 0.7, wealth = 1.0,
    openers = { "WOOO! GIMME", "Party's in my mouth and you're invited! I want", "No time! Party! Quick! Make me" },
    good = { "BEST. FOOD. EVER. (Until the next one.)", "I'm telling all 400 of my siblings!" },
    bad = { "This is a party foul. A big one.", "Booooo. Boo. Boo, I say." } },

  { id = "philomouse", name = "Philosophical Mouse", plural = "Philosophical Mice",
    look = { shape = "mouse", color = { 0.94, 0.92, 0.9 }, eyes = 2 },
    likes = { "Irony", "Wistful", "Smug", "Nostalgia", "Crunchy" }, hates = { "Panic" },
    patience = 1.1, wealth = 1.4,
    openers = { "Hypothetically speaking, I would order", "If a dish falls in a forest... anyway, I'd like",
      "Consider, if you will," },
    good = { "Ah. This dish asks the right questions.", "Delicious. And yet, what IS delicious?" },
    bad = { "I asked for meaning and received lunch.", "This dish has no answer. Nor a question." } },

  { id = "snottling", name = "Snottling", plural = "Snottlings",
    look = { shape = "puddle", color = { 0.45, 0.82, 0.4 }, eyes = 2 },
    likes = { "Slimy", "Green", "Fizzy", "Purple", "Blue" }, hates = { "Crunchy", "Hot" },
    patience = 1.0, wealth = 0.9,
    openers = { "*squelch* Wants", "Hhhhhhh (translation: I'd like)", "*bubbles hopefully at*" },
    good = { "*happy squelching*", "*vibrates in a way that probably means thank you*" },
    bad = { "*sad drip*", "*leaves a damp, disappointed puddle*" } },

  { id = "salesbeing", name = "Time-Share Salesbeing", plural = "Time-Share Salesbeings",
    look = { shape = "blob", color = { 1, 0.66, 0.3 }, eyes = 1, suit = true },
    likes = { "Smug", "Purple", "Red", "Hot", "Nostalgia" }, hates = { "Doom", "Irony" },
    patience = 0.9, wealth = 1.5,
    openers = { "Have I got a deal for YOU! Also, I'll take", "Let's circle back and synergise on",
      "Quick question, no pressure, how about" },
    good = { "Five stars! Have you considered a holiday moon?", "Love it. Let's do lunch. This was lunch. Let's do it again." },
    bad = { "I'm going to have to escalate this to my manager. Who is also me.", "Not a win-win. A lose-lose. My least favourite." } },
}

local byId = {}
for _, s in ipairs(list) do byId[s.id] = s end
return { list = list, byId = byId }
