-- Ways to hitchhike to the next planet. `reveals`: whether you see where it goes.
return {
  { id = "freighter", name = "Asteroid Freighter", fare = 15, reveals = true,
    desc = "Smells of ore. The driver will tell you about his divorce. Twice." },
  { id = "wormhole", name = "Unlicensed Wormhole", fare = 0, reveals = false,
    desc = "Free! Destination: pending. Side effects: also pending." },
  { id = "barge", name = "Bureaucratic Poetry Barge", fare = 0, reveals = true, poem = true,
    desc = "Free passage, on condition that you listen to the captain's poetry." },
  poems = {
    "O stapled form of grimbly woe,\nthy margins wide, thy ink so slow,\nI fill thee in, I fill thee out,\nI do not know what you're about.\n\n(The captain weeps. You lose all dignity, but no Flurbos.)",
    "Ode to Form 12-C:\nThou art filled in, thou art filed,\nthou art lost in a cabinet.\nI miss thee, 12-C.\n\n(The captain bows. Nobody claps. He notes this down.)",
    "Haiku of Mandatory Compliance:\nqueue, queue, queue, queue, queue\nqueue, queue, queue, queue, queue, queue, queue\nyour number is called\n\n(It wasn't your number.)",
  },
}
