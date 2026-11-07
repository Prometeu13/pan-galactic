-- BREADCRUMBS: the whole story as data. Edit this file to change what happens.
--
-- Each chapter is one staged scene. Hotspots are things Gus can look at or talk to
-- (press E when near). A hotspot plays a dialogue NODE. Nodes are lists of lines and may
-- end with choices. Node effects:
--   give = "clue"       add a clue to Gus's notebook
--   flag = "name"       set a story flag
--   kind / grit = n     nudge who Gus is becoming (tender vs. hard-boiled)
--   join = "name"       a pigeon joins the flock
--   ending = true       start the finale
-- Hotspot fields: requires = { clues or flags }, perch = "id" (Gus must be perched
-- there), again = node played on later visits, kind = "look" | "talk" | "exit".
-- Speakers: "" is Gus narrating; "(overheard)" marks humans talking: they can't
-- understand pigeons, but pigeons understand them just fine.

local story = {}

story.title = "BREADCRUMBS"
story.subtitle = "a noir story about a pigeon, an old man, and a city that forgets"

story.chapters = {
  ---------------------------------------------------------------------------------------
  {
    id = "alley", number = "CHAPTER ONE", name = "Three Days Without Bread",
    start = 110,
    perches = { { id = "bench", x1 = 180, x2 = 360, y = 545 } },
    intro = {
      "Three days. Three days since the old man last came to his bench with a paper bag of bread.",
      "In this town, three days is long enough to forget a face. I don't forget faces. I'm a pigeon. Faces are all we've got.",
    },
    hotspots = {
      { id = "bench", x = 270, y = 545, r = 110, kind = "look", label = "Sal's bench", node = "bench" },
      { id = "scarf", x = 610, y = 520, r = 80, kind = "look", label = "something on the fence", node = "scarf", again = "scarf2" },
      { id = "puddle", x = 760, y = 600, r = 60, kind = "look", label = "a puddle", node = "puddle" },
      { id = "vinnie", x = 880, y = 545, r = 110, kind = "talk", label = "Vinnie the cat", node = "vinnie", again = "vinnie2" },
      { id = "exit", x = 1230, y = 600, r = 70, kind = "exit", label = "Mercer Street: the Lucky Diner", requires = { "van" }, locked = "exitLocked", node = "exit" },
    },
    nodes = {
      bench = { lines = {
        { "", "Sal's bench. Somebody carved S + M into the armrest a long time ago." },
        { "", "The seat's wet. Nobody's sat on it in days. Nobody's had a reason to." },
      }, flag = "bench" },
      scarf = { lines = {
        { "", "Snagged on the fence: a grey wool scarf. It smells like bread crusts and pipe tobacco." },
        { "", "Sal's. He wore it in July. Said the wind off the river got into his bones." },
      }, give = "Sal's scarf" },
      scarf2 = { lines = { { "", "The scarf. I tugged it free and kept it. Somebody ought to." } } },
      puddle = { lines = {
        { "", "My reflection in the gutter. A grey bird with a grey future." },
        { "", "I've looked worse. I've also looked better, but that was a long time ago and there was more bread." },
      } },
      vinnie = { lines = {
        { "Vinnie", "Well, well. Breakfast walked right up and started talking." },
      }, choices = {
        { "Easy, Vinnie. You haven't caught anything since the Nixon administration.", go = "vinnieGrit", grit = 1 },
        { "I'm not here for trouble. I'm looking for the old man. Sal.", go = "vinnieKind", kind = 1 },
      } },
      vinnieGrit = { lines = { { "Vinnie", "Ha. Fair. My knees aren't what they were. Neither are my teeth." } }, next = "vinnieTells" },
      vinnieKind = { lines = { { "Vinnie", "Polite. Nobody's polite anymore. Fine, bird. I'll tell you." } }, next = "vinnieTells" },
      vinnieTells = { lines = {
        { "Vinnie", "Your bread man? Two nights back he sat down on that bench and didn't get up." },
        { "Vinnie", "A white van came. Red cross on the side. Lights spinning, screaming like a tomcat." },
        { "Vinnie", "Want to know where they took him? Ask the people who knew him. He drank his coffee at the Lucky Diner. Every morning, six sharp." },
      }, give = "the white van", flag = "van", choices = {
        { "Thanks, Vinnie. I owe you one.", kind = 1 },
        { "Don't wait up.", grit = 1 },
      } },
      vinnie2 = { lines = { { "Vinnie", "Still here? The diner, bird. Follow the smell of burnt coffee." } } },
      exitLocked = { lines = { { "", "Not yet. Somebody around here saw something. Somebody always does." } } },
      exit = { lines = { { "", "I left the bench behind. Mercer Street was wet and long, and at the end of it a neon sign was buzzing." } } },
    },
  },
  ---------------------------------------------------------------------------------------
  {
    id = "diner", number = "CHAPTER TWO", name = "The Lucky Diner",
    start = 90,
    perches = { { id = "dumpster", x1 = 840, x2 = 960, y = 520 } },
    intro = {
      "The Lucky Diner never closes. Neither does the grease.",
      "Sal sat in the third booth every morning, and fed us the crusts of his toast on the way out. Regular as rain.",
    },
    hotspots = {
      { id = "sign", x = 330, y = 230, r = 380, kind = "look", label = "the neon sign", node = "sign" },
      { id = "window", x = 300, y = 480, r = 120, kind = "look", label = "the diner window", node = "window" },
      { id = "pip", x = 520, y = 600, r = 90, kind = "talk", label = "a skinny young pigeon", node = "pip", again = "pip2" },
      { id = "backdoor", x = 1040, y = 520, r = 140, kind = "look", label = "the cook and the waitress, on a smoke break", node = "overhear", perch = "dumpster", needPerch = "tooLow" },
      { id = "exit", x = 1230, y = 600, r = 70, kind = "exit", label = "the fire escape: up to Sal's roof", requires = { "St. Agnes" }, locked = "exitLocked", node = "exit" },
    },
    nodes = {
      sign = { lines = {
        { "", "LUCKY DINER. The L has been dark for a year. UCKY DINER." },
        { "", "The city has a sense of humour. It's just not a nice one." },
      } },
      window = { lines = {
        { "", "Through the glass: Dot, the waitress, wiping the same clean spot on the counter, over and over." },
        { "", "The third booth is empty. There's a coffee cup on it, turned upside down. Like a flag at half mast." },
      }, flag = "window" },
      pip = { lines = {
        { "Pip", "Mister? You got anything? I haven't eaten since the bread man stopped coming." },
        { "", "He was all neck and eyes. Last spring's chick. Sal used to save him the soft middle of the roll." },
      }, choices = {
        { "Here, kid. Take my crust.", go = "pipShare", kind = 2 },
        { "Everybody's hungry, kid. Learn to find your own.", go = "pipHard", grit = 1 },
      } },
      pipShare = { lines = {
        { "Pip", "Gee. Thanks, mister. I won't forget it." },
        { "Pip", "Hey... the cook and the lady talk about him. Out back, by the dumpster, when they smoke." },
      }, flag = "shared" },
      pipHard = { lines = {
        { "Pip", "...Yeah. Okay. Sorry, mister." },
        { "Pip", "If you're looking for the bread man, the cook and the lady talk about him. Out back. When they smoke." },
        { "", "He walked off with his head down. I told myself it was a lesson. Lessons are cheap. Bread isn't." },
      } },
      pip2 = { lines = { { "Pip", "Out back, mister. Up on the dumpster, so you can hear 'em." } } },
      tooLow = { lines = { { "", "Too low. Humans talk over pigeons' heads. I needed to get up on that dumpster. (Up arrow to perch.)" } } },
      overhear = { lines = {
        { "(overheard) Marty", "...still can't believe it. Collapsed right there on his bench." },
        { "(overheard) Dot", "St. Agnes, the ambulance fella said. Third floor." },
        { "(overheard) Marty", "Anybody been to see him?" },
        { "(overheard) Dot", "Who? He's got nobody, Marty. Wife passed years ago. Just those birds of his." },
        { "(overheard) Marty", "Huh. Birds don't visit." },
        { "", "Marty was wrong about that. Dead wrong." },
      }, give = "St. Agnes", flag = "agnes" },
      exitLocked = { lines = { { "", "I didn't know enough yet. Somebody in there knew where they took him." } } },
      exit = { lines = {
        { "", "St. Agnes, third floor. I could fly there in ten minutes." },
        { "", "But Sal never fed just me. He fed all of us. If anybody was going, we were all going." },
      } },
    },
  },
  ---------------------------------------------------------------------------------------
  {
    id = "roof", number = "CHAPTER THREE", name = "The Empty Coop",
    start = 90,
    perches = {
      { id = "chimney", x1 = 630, x2 = 710, y = 430 },
      { id = "antenna", x1 = 1100, x2 = 1180, y = 330 },
    },
    intro = {
      "Sal's coop sat on the roof of 14 Mercer like a little wooden church.",
      "The door was open. The seed tray was dry. The flock had scattered like witnesses after a shooting.",
    },
    hotspots = {
      { id = "coop", x = 410, y = 540, r = 130, kind = "look", label = "Sal's coop", node = "coop" },
      { id = "rosa", x = 905, y = 600, r = 100, kind = "talk", label = "Rosa, under the water tower", node = "rosa", again = "joined" },
      { id = "tony", x = 670, y = 430, r = 90, kind = "talk", label = "Big Tony, on the chimney", node = "tony", again = "joined", perch = "chimney", needPerch = "tonyLow" },
      { id = "wren", x = 1140, y = 330, r = 90, kind = "talk", label = "Wren, up the antenna", node = "wren", again = "joined", perch = "antenna", needPerch = "wrenLow" },
      { id = "exit", x = 1230, y = 600, r = 70, kind = "exit", label = "the night sky: St. Agnes", requires = { "rosa", "tony", "wren" }, locked = "exitLocked", node = "exit" },
    },
    nodes = {
      coop = { lines = {
        { "", "Sal built this coop with his own two hands. Every nail a little crooked. Every nail his." },
        { "", "There's a photograph tacked inside the door. A young man and a young woman, laughing, a hundred pigeons at their feet." },
        { "", "On the back, in pencil: S + M, 1961. Same as the bench." },
      }, give = "the photograph" },
      rosa = { lines = {
        { "Rosa", "Sal's gone, Gus. Old men go. That's how it works." },
      }, choices = {
        { "He fed you every day for nine years. You owe him one visit.", go = "rosaYes", grit = 1 },
        { "I'm scared too, Rosa. Come with me anyway.", go = "rosaYes", kind = 1 },
      } },
      rosaYes = { lines = { { "Rosa", "...Alright. For him. Not for you." } }, join = "rosa", flag = "rosa" },
      tonyLow = { lines = { { "", "Big Tony was up on the chimney, sulking. Tony only talks to birds at eye level. (Up arrow to perch.)" } } },
      tony = { lines = {
        { "Tony", "A hospital? Full of humans and nets and that smell? No. No way." },
      }, choices = {
        { "Sal pulled a fishhook out of your foot once, Tony. Remember who held you?", go = "tonyYes", kind = 1 },
        { "Biggest bird on Mercer Street, scared of a building.", go = "tonyYes", grit = 1 },
      } },
      tonyYes = { lines = { { "Tony", "...Fine. But if anybody brings a net, I'm leaving." } }, join = "tony", flag = "tony" },
      wrenLow = { lines = { { "", "Wren had climbed as high as she could go: the top of the antenna. (Up arrow to perch.)" } } },
      wren = { lines = {
        { "Wren", "Gus? Is... is he going to die?" },
      }, choices = {
        { "Not tonight. Not if we get there.", go = "wrenYes", kind = 1 },
        { "Everybody does, kid. But nobody should do it alone.", go = "wrenYes", grit = 1 },
      } },
      wrenYes = { lines = { { "Wren", "Okay. Okay. I'll stay right behind you." } }, join = "wren", flag = "wren" },
      joined = { lines = { { "", "Ready when I was." } } },
      exitLocked = { lines = { { "", "Not alone. Not without the others. Sal fed all of us." } } },
      exit = { lines = { { "", "We took off together, into the rain. Four grey birds over a grey city, flying toward the only light still on." } } },
    },
  },
  ---------------------------------------------------------------------------------------
  {
    id = "hospital", number = "CHAPTER FOUR", name = "St. Agnes, Before Dawn",
    start = 90,
    perches = { { id = "ledge", x1 = 590, x2 = 850, y = 412 } },
    intro = {
      "St. Agnes was all clean windows and hard light. Third floor, Dot had said.",
      "Only one window on the third floor still had a light on.",
    },
    hotspots = {
      { id = "flowers", x = 900, y = 405, r = 80, kind = "look", label = "a flower box", node = "flowers", perch = "ledge" },
      { id = "window", x = 720, y = 330, r = 130, kind = "talk", label = "the lit window", node = "tap", perch = "ledge", needPerch = "windowLow" },
    },
    nodes = {
      flowers = { lines = {
        { "", "Somebody left geraniums in the next window box. Red, probably." },
        { "", "Everything's grey at night. You have to take the colours on trust." },
      } },
      windowLow = { lines = { { "", "The window was three floors up. There's a ledge under it, wide enough for four birds. (Up arrow to perch.)" } } },
      tap = { lines = {
        { "", "Inside: a narrow bed, a beeping machine, an old man who looked smaller than he ever had on his bench." },
        { "", "I tapped on the glass. Once. Twice. The way he used to tap the bag before he opened it." },
        { "", "He turned his head." },
        { "(overheard) Sal", "Well, I'll be. Look who found me." },
        { "(overheard) Sal", "Nurse? Nurse, could you crack this window open? I've got visitors." },
      }, ending = true },
    },
  },
}

-- The epilogue depends on who Gus became.
story.epilogue = {
  kind = {
    "Sal got out of St. Agnes two weeks later. He walks slower now. He brings two bags.",
    "Pip eats first. I make sure of it.",
    "Marty was wrong. Birds visit.",
  },
  grit = {
    "Sal got out of St. Agnes two weeks later. He walks slower now. I walk slower with him.",
    "The city didn't get any softer. But one old man found out the birds come back.",
    "Marty was wrong. Birds visit.",
  },
}

return story
