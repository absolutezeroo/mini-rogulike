# Dungeon

## Floors

- **Walls** are cliffs drawn from a 16x16 tileset (`DungeonView`): plateau edges, inner corners,
  cliff faces. The generator smooths every floor so only shapes the tiles can draw remain
  (no wall thinner than 3 cells between two floors, `DungeonGenerator.MIN_WALL_THICKNESS`: they
  looked like flimsy fences; no walls touching by a corner).
- **Props** (`data/props/`): crates, vases and barrels break under any attack and may drop loot;
  **powder kegs** blink then explode, hurting everyone (you too) and setting off other kegs.
  Explosions you trigger give you the XP of what they kill. Props block movement, sight and shots.
- **Hazards** (`data/hazards/`): each act has its own list (`ActDef.hazards`), and every hazard
  knows how to lay itself out in a room (`HazardDef.place()`). They hurt monsters too: lure them in.
  - **Traps**: rows of **spikes** firing in a wave, **pressure plates** that strike when stepped on,
    **flame vents** that also set you on fire, **arrow traps** (a plate wired to a slit in a wall:
    arrows fly across the room). They always warn before they strike.
  - **Holes**: anything that walks or is knocked in falls. Monsters are gone (you get the XP if
    you pushed them), the hero climbs out where they last stood safely and loses 15% HP.
    Rolling carries you over; flying monsters (bats, ghosts...) don't care. Walking monsters
    steer around holes, so knock them in.
  - **Crumbling floor**: cracked tiles that hold until someone stands on them, then give way.
  - **Quicksand** (ruins) and **mud** (caves): very slow to cross, and they hurt if you stay.
  - Hazards are never placed where they could cut the stairs off.
- **Sealed stairs** (`StairsSeal`, `DungeonConfig` > Stairs seal): a normal floor's stairs stay
  sealed (dark, under a turning violet seal) until you have slain `seal_share` (70%) of the
  floor's monsters, `seal_max` (50) at most; every kill counts, ambush waves and summons too. The HUD counts them under
  the minimap ("Seal 12 / 18"); stepping on sealed stairs says how many are missing. When only
  `seal_reveal_left` (4) are missing, the minimap shows the monsters left. When the seal breaks,
  the stairs light up, the minimap shows them even unexplored and a golden light (`GuideWisp`)
  runs ahead of you along the way. No more running past everything: a floor takes a couple of
  minutes, a run about half an hour. Floors are 72x72 cells with up to 15 rooms on Pilgrim, and
  bigger the harder the run (see Difficulty); boss floors keep that size.
- **Biomes** (`data/biomes/`, `BiomeDef`): every floor is one world from end to end, picked among
  its act's (`ActDef.biomes`; the boss arena has `boss_biome`): Act I **Weeping Grotto**,
  **Pale Garden**, **Drowned Caverns**; Act II **Catacombs**, **Hushed Archive**; Act III
  **Cinder Ruins**, **Godless Temple**; Act IV **Sandchoked City** (sand streets, an abandoned market,
  oases and palms, a lion fountain) and **Tomb of the Dead Sun** (sarcophagi, burial chambers, gold). Nothing from another biome ever shows up. A biome has:
  - its **look** (`theme`: floor and wall tiles, tint, darkness, music) and its **lights**
    (candles in the crypt and the library, braziers in the ruins);
  - its **grounds** (`GroundLayerDef`: moss, sand, mud, shallow water, cobbles...): patches shaped
    by noise, drifting against the walls or keeping to the middle, drawn by a shader
    (`GroundLayer`) with rounded, ragged edges and a rim, in the art's chunky pixels;
  - its **scenes** (`SceneDef`, `data/biomes/scenes/`): little scenes made by hand, written as
    text plans (one string per row, a symbol per cell, `SceneKey` says what each one is: a prop, a
    piece of decor, a carpet, water; "." = keep free). Each has an anchor (against the top wall, a
    side wall, in a corner, in the middle, anywhere) and is mirrored now and then. A big room
    gets 2-3, a small one 1-2 (`scenes_big_room`, `scenes_small_room`), none where the hero
    arrives. A scene goes only where it fits whole, never at a corridor mouth and never walling
    anything off (`RoomSpace.stays_open`);
  - its **decor** (`DecorRuleDef`): a few small things, each with a reason to be where it is:
    at the foot of the walls (pebbles, ferns, dry scrub), right around a scene's furniture (books
    by the shelves, bones by the graves, gold by the sarcophagi) or on its ground (grass on moss).
    A few per room at most (`max_per_room`); the middle of the rooms and the corridors stay
    clear, so the fight stays readable. The floor tiles carry no decor of their own;
  - its **pots and crates** (`props`: baskets in the desert, mossy jars in the garden...).
  This is how Dead Cells, Enter the Gungeon or Brogue keep generated levels coherent: hand-made
  pieces per biome, laid out by the generator (`FloorDresser`).
- **Chests** (`data/chests/`): walk up to one to open it. Some are trapped: they blow up or let
  monsters out (and keep only one item). A trapped chest rattles now and then...
- **Two ways down** (`FloorRoute`, `dungeon_config.tres` > Routes): a normal floor ends on two
  stairs, and a boss arena opens two once the boss falls. Each leads to a different world of
  the act (`ActDef.biomes`), and may be cursed or hold a floor event: a wooden **sign** over each
  stairs says which ("Flooded Caverns / Ashen Breath - better loot"). The second way gets a twist
  more often (`route_twist_chance`), so the choice is often a calm way or a bold one. Floors
  before a boss have one way: the arena. The offer comes from the run's seed (the same all day in
  a daily run) and the way taken is saved (`RunState.routes`), so a resumed run rebuilds the same
  floor. The second stairs stand in the room farthest from both the start and the first stairs.
- **Curses** (`data/curses/`, `CurseDef`): the Well curses a whole floor. Never the first floor nor
  a boss floor, rarely on Pilgrim, more and more often up to Nightmare (`DifficultyDef.curse_chance`:
  5%, 12%, 20%, 35%). On arrival, the **curse card** (`CurseCard`) shows the Well's sigil forming
  out of souls, the curse's name, its story and its rule. A cursed floor has no floor event, but
  better loot and more gold.
  - **Frostbound**: ice over every room, snow falling, the cold getting into your bones.
    A few **campfires** (one where you arrive, 2-3 more: `CurseDef.spot_count`) warm you back
    up, with logs and stones scattered around them, never twice the same.
  - **Ashen Breath**: the air scorches, embers drift. **Oases** cool you down: a pond of real
    water tiles (`HeatSourceDef.pond`, nobody walks on it: `Layers.WATER`) of a random size, in
    a rough patch of grass with plants and flowers around, each one different.
  - **No camping**: stay too long by a campfire or an oasis (`camp_limit`, 12 s) and the light
    draws monsters in (`CampWatch`): a warning first, then a wave, bigger each time. They give
    nothing.
  - **Lanternless**: the whole floor in the dark but right around you; monsters and traps hide
    in the black. The best loot of the three.
- **Temperature** (`BodyTemperature`, `dungeon_config.tres` > Temperature): the hero has a body
  temperature from -100 (frozen) to 100 (burning up), shown under the XP bar when it is not
  normal, with frost (or a burning haze) creeping in from the screen's edges
  (`temperature_overlay.gdshader`). Cold slows you down; frozen or burning up, you take damage
  every second. Campfires and springs (`HeatSourceDef` with `comfort`) bring it back to normal,
  and away from cold and heat it goes back to normal by itself.
- **Ambushes**: a floor may have a quiet, empty room. Walk in and spikes close the exits,
  monsters pour in, wave after wave, the last one led by an elite. Clear it for a big chest.
- **Elites** (`data/elites/`): any monster can be one, more often deeper and on harder
  difficulties. They glow in their color, show their name, are bigger and tougher, give 3x XP
  and always drop an item. Their affix is a perk, like the hero's: **Swift**, **Vampiric**
  (heals when hitting), **Bursting** (blows up when it dies), **Ironclad**, **Venomous**
  (poisons), **Thorned** (hurts who hits it).

## Secret rooms

Some floors hide a small room behind a **cracked wall** (`SecretRoomPlan`, `SecretRoom`,
`dungeon_config.tres` > Secret rooms): `secret_room_chance` (50%) on a normal floor, one at most
(`secret_rooms_max`), two at most on floors of `secret_big_floor_rooms` (20) rooms or more
(Martyr, Nightmare). Never on a boss floor, the first room or a room with the stairs.

- **Where**: the generator plans it once the floor is made: a 7x5 room (`secret_room_size`) behind
  a wall of an existing room, joined to it by a passage through the rock 3 cells long
  (`secret_passage_length`) and 1 wide (`secret_passage_width`). Above a room first (the crack
  on a cliff face, where it reads best), else beside or below it. The rock all around it is at
  least `DungeonGenerator.MIN_WALL_THICKNESS` thick, so it never touches another floor and the
  main path never needs it. Its cells stay wall in the map (nothing walks, draws, lights or
  dresses them) until it opens. Planned from its own stream of the floor's seed: the rest of the
  floor is the same with or without it, and a daily run hides the same rooms for everyone.
- **The tells**, subtle but learnable: dark fissures on the stone and chips at its foot
  (`CrackedWall`, a prop in the wall), a faint draft of dust motes drifting into the room, now and
  then a whisper when the hero is close (`secret_whisper`). The first time one is in sight, a
  hint says what it is (`cracked_wall`). Nothing in front of it: the populator keeps its foot free.
- **Breaking in**: any hit of the hero (a blow, a shot, a skill) or a blast breaks it
  (`cracked_wall.tres` > hits: 1); monsters' blows don't, or they would give it away. The rock
  crumbles (sound, dust, debris, a shake), the passage and the room become floor
  (`World.open_cells()`: walls, light, mist, pathfinding and drawing redone), the room shows on the
  minimap, lanterns light it, and the log says "The wall gives way: a hidden room."
- **What it holds**: one of `secret_rewards` (`data/secrets/`, `SecretRewardDef`, by
  `spawn_weight` and `min_depth`, drawn from the floor's seed), its name floating over it:

  | Reward | Weight | What |
  |---|---|---|
  | Hidden Coffer | 30 | a chest better than the ones lying around (2-3 items, quality 3.5), never trapped |
  | Forgotten Shrine | 20 | an altar, a statue or a spring (an encounter) |
  | Buried Rune | 20 | a rune |
  | Hoarder's Cache | 20 | 30-50 gold, +6 a floor (the floor's gold rules apply) |
  | Sealed Draughts | 15 | two rare draughts or scrolls |

  In the acts of the hidden floor, the room may hold its key instead (below).
- **Saved**: a broken wall stays broken and a looted room stays empty after a resume
  (`World.spent_data()` > secrets: each room's state, and whether it held the key).
- **Counted**: secret rooms found go to the profile's stats (the feat "What the Walls Keep":
  find 5) and to the end-of-run screen ("Secret rooms found").

## The hidden floor

**The Nameless Charnel** (`data/secrets/nameless_charnel.tres`, `HiddenFloorDef`,
`dungeon_config.tres` > Hidden Floor): a floor between Act II and Act III that nothing announces.

- **The key**: a secret room of Act II (`key_acts`: [1]) holds the **Bone Key** instead of its
  reward half the time (`key_chance`), while the hero has none and the run hasn't been down yet.
  The key's card says only: "It fits no door on this side of the Warden."
- **The way**: slaying Act II's boss with the key in the bag opens a third way in the arena, a
  sealed fissure of cold light under a ring of runes (`HiddenWay`, opened by `HiddenPassage`), its
  sign naming the floor, beside the two usual stairs. Taking it is a choice: the stairs still lead
  on to Act III. Stepping in spends the key.
- **The floor**: a start room, three rooms of its own monsters (Skeleton, Frost Skull, Lost Soul,
  Hexer, Ghost Lantern, Soul Moth, Cyclops), then an arena (`DungeonGenerator.generate_hidden()`),
  in its own world (a cold catacomb, `nameless_charnel` biome and `charnel` theme), with its
  title card ("Between the Acts"). No curse, no event.
- **Its boss**: The Nameless Effigy (see monsters.md), in a Pillared Nave or a Round Pit. When it
  falls: the usual relic choice, a Big Chest, 60 souls on top of the run's (times the
  difficulty's), the secret feat "Laid to Rest at Last", and the arena's stairs to Act III's first
  floor (the same two ways the Act II boss offered).
- **Depth and the run**: the floor keeps the depth of the boss floor before it
  (`RunState.hidden_floor`): the HUD says Depth 6, its monsters and boss scale like floor 6, the
  run's numbering, records and quests don't move. Its floor seed is its own (the daily run's
  hidden floor is the same for everyone). Splits: the Act II boss floor's split is taken going
  down; the hidden floor takes none, its time goes into the next floor's. Saved like any floor:
  quitting on it comes back to it; quitting once its boss is dead goes on to Act III. Once a run
  (`RunState.hidden_done`): no more keys afterwards, in endless mode too.

## Boss arenas

A boss floor is a start room and an arena picked among `DungeonConfig.arenas` (or the boss' own,
`BossDef.arenas`: the Wyrms want room). An `ArenaDef` (`data/arenas/`) has a size, a shape (rect,
**oval**, **cross**), pillars (props: cover from shots) and **changes** (`ArenaShiftDef`), one at
each of the boss' next phases (`Monster.phase_entered`): the cells blink red (`CellWarning`), then
become cracked floor, pits or spikes, in a pattern (the **edge** crumbling in, a **cross** of
spikes through the middle, **corners** falling away, **scattered** holes). Never under the hero,
the boss or the middle (where the stairs appear).

| Arena | Size, shape | Changes |
|---|---|---|
| Great Hall | 27x19, 4 pillars | the edge crumbles, then the ground caves in |
| Round Pit | 27x21 oval | a cross of spikes, then the pit closes in |
| Cross Court | 29x23 cross, 4 pillars | spikes here and there, then holes |
| Pillared Nave | 31x17, two rows of pillars | the corners fall away, then a cross of spikes |
| Old Chamber | 21x15 | the floor cracks, then caves in |

## Special floors and bosses

Bosses have a lot of HP and stand their ground: they ignore 95% of the knockback, so no weapon can
keep one away from you (`MonsterDef.knockback_resistance`). Big monsters resist half of it, and
elites at least half.

- **Special floors** (`data/floor_events/`, `FloorEventDef`): 30% of the normal floors after the first
  (`dungeon_config.tres` > Floor events) are announced when you arrive: **The Wandering Dead** (elites, dim),
  **Hoard of the Dead** (chests and gold, more traps), **The Swarm** (hordes of weak monsters),
  **Utter Dark** (very dark, better loot), **Hushed Halls** (few monsters, the merchant, encounters),
  **Blood Moon** (monsters hit harder, double gold). They multiply monsters, HP, damage, elites,
  light, chests, hazards, encounters, gold and loot quality.
- **Two bosses per act** (`ActDef.boss` + `other_bosses`): each run draws one per act (saved with
  the run; the title screen shows both). Bloated King or the **Mire Matron** (leaps, poison spit, calls
  its brood); Gorr the One-Eyed or the **Mother of Tears** (a freezing wail, blinks, calls lost souls);
  Crimson Tengu or the **Ember Ronin** (arcs of fire, dashes, a ring of fire). Gilded Hoarder or the
  **Dead Sun** (a burning sun buried with the kingdom: solar flares, blinks, calls its embers).

## Blood Moon

A floor event (`data/floor_events/blood_moon.tres`): frenzied monsters, double gold, and its own
look over the biome (`FloorEventDef.atmosphere`, the biome's sounds stay; `ambient_tint` reddens
the light): a crimson grade, a great red glow breathing over the top of the screen
(`AmbienceDef.moon_color`), edges darkening to blood and beating like a heart
(`vignette_color`, `vignette_pulse`, in `screen.gdshader`), red moonlight shafts and mist, falling
red ash (`src/vfx/ambient/blood_ash.tscn`).

## Encounters

Some rooms hold something strange (`data/encounters/`, `EncounterDef`): walk up to it and choose.
Each choice has a cost (gold, a part of your max health) and outcomes drawn by weight
(`EncounterChoice`, `EncounterOutcome`: heal, hurt, gold, an item of some quality, a choice of
perks or relics, monsters or elites, any `Effect`). Each can be used once. The panel shows every
outcome in words with its odds before you choose; the words come from the outcome's fields
(`EncounterOutcome.summary()`), so new encounters explain themselves.

| Encounter | Choice | What may happen |
|---|---|---|
| Spring of the Drowned | Drink | healed (55%), a strong buff for a minute (25%), cursed water hurts (20%) |
| Blood Altar | Offer your blood (-15% max health) | a choice of relics |
| Grinning Spirit | Wager 30 / 80 gold (more each floor) | an item, sometimes a great one... or it laughs and runs |
| Warden's Statue | Kneel | a choice of perks (50%), or two elites (50%) |
