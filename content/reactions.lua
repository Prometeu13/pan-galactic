-- When two tags meet in the Flavor Synthesizer they may react: one of each is consumed
-- and the result tag is produced. Reactions fire in this order, as many times as possible.
-- a == b means "two of the same".
return {
  { a = "Volatile", b = "Volatile", result = "Explosive" },
  { a = "Volatile", b = "Hot",      result = "Explosive" },
  { a = "Joy",      b = "Doom",     result = "Irony" },
  { a = "Hot",      b = "Cold",     result = "Lukewarm" },
  { a = "Melancholy", b = "Nostalgia", result = "Wistful" },
  { a = "Red",      b = "Blue",     result = "Purple" },
  { a = "Smug",     b = "Slimy",    result = "Bureaucratic" },
}
