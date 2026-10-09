-- The Foodie's Guide to the Galaxy: your onboard AI. Cryptic, unhelpful, occasionally right.
-- $name style variables are filled in by the caller. ASCII only (the typewriter counts bytes).
return {
  lines = {
    title = {
      "Welcome, chef. I am the Foodie's Guide to the Galaxy. My advice is 40% accurate, 100% confident.",
      "Your debt is large. Your truck is small. Your prospects are, statistically, soup.",
    },
    hitchhike = {
      "Stick out your thumb. The galaxy is full of rides, most of them only slightly fatal.",
      "Pick a ride. Freighters cost money, wormholes cost certainty, and the poetry barge costs your soul.",
      "Rule one of hitchhiking: always know where your ladle is.",
    },
    broke = {
      "You can't afford that. I'd lend you money, but I am a voice in a box.",
    },
    poem = {
      "Cover your ears. Actually, don't. The captain notices.",
    },
    forage_start = {
      "Grab ingredients, avoid the Form Drones, and get back to the truck before the timer ends.",
      "Fresh ingredients! Some of them are 'volatile'. That's a culinary term for 'run'.",
      "Forage time. Remember: if it glows, it's either delicious or plutonium. Usually both.",
    },
    discover = {
      "$name! I know exactly one thing about these: they taste $tag. The rest is a surprise.",
      "Ooh, $name. My database says '$tag'. My database also says I'm a toaster, so.",
    },
    volatile_pop = {
      "That ingredient exploded. I'd call that 'over-ripe'.",
      "Kaboom. Nature's way of saying 'pick faster'.",
    },
    fined = {
      "You've been fined for loitering without a loitering permit. Classic.",
      "A Form Drone! Never make eye contact. They have a form for that.",
    },
    basket_full = {
      "Your basket is full. Head back to the truck, chef.",
    },
    shop_open = {
      "We're open on $planet! Click ingredients to add them to the Synthesizer, then Serve.",
      "Customers will describe a feeling. The coloured words are flavour tags. Match them. Easy. Ha.",
    },
    hint_true = {
      "Psst. The $name might help with that. Or I'm guessing. I'm not saying which.",
      "My sensors suggest $name. My sensors are a magic 8-ball, but still.",
    },
    hint_false = {
      "Psst. The $name might help with that. Or I'm guessing. I'm not saying which.",
      "Trust me: $name. I have literally never been wrong, except all those times.",
    },
    serve_great = {
      "Transcendent! Somewhere, a culinary critic just felt a disturbance in the gravy.",
      "Perfect match. I'll pretend I predicted that.",
    },
    serve_ok = {
      "They liked it. They didn't LOVE it, but liking is legally binding.",
      "Close enough. 'Close enough' is the galaxy's official motto.",
    },
    serve_bad = {
      "That was a flavour crime. Not a big one. A misdemeanour.",
      "Note to self: they did not want that. Note to you: same.",
    },
    serve_hated = {
      "You served them something they hate. Bold. Wrong, but bold.",
    },
    explosion = {
      "The dish exploded. Hot and volatile together: who could have predicted it? Me. I could.",
      "KABOOM. On the bright side, the customer is now in orbit and no longer complaining.",
    },
    walkout = {
      "A customer left. They said the wait was 'longer than the universe'. Which is untrue. Mostly.",
    },
    learned = {
      "Your tongue has learned new tags. Your tongue is very proud.",
    },
    shift_over = {
      "Shift over. Count your Flurbos, then pick an upgrade or pay down that debt.",
    },
    outfitter = {
      "Upgrades or debt? The bank recommends debt. The bank always recommends debt.",
      "Treat yourself. The First Bank of Fringe Bureaucracy will treat you too. With interest.",
    },
    debt_paid = {
      "You paid off your debt! A gold-edged invitation drifts in... The Restaurant at the End of the Universe would like a word.",
    },
  },

  -- Unlocked one at a time when you serve a Transcendent dish: breadcrumbs toward the legend.
  rumors = {
    "A Grumbleon whispers: 'They say the Restaurant has no reservations. You simply arrive when you were always going to.'",
    "A mouse taps its nose: 'The head chef there cooked a dish so perfect it got a job and moved out.'",
    "An android sighs: 'The Restaurant serves the end of everything. I hear the dessert is optional.'",
    "A Blagulon shouts: 'The Restaurant's after-party is LITERALLY the Big Bang!'",
    "A salesbeing winks: 'Get there and they'll make you an offer you can't refuse. I tried. They refused.'",
  },
}
