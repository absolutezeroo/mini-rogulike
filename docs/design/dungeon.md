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

## Pact doors

Some floors hold a sealed side room behind a marked door (`PactRoom`, `data/pacts/`, `PactDef`):
crimson spikes across the doorway, a stele standing in it, a sigil of blood and gold on the floor
before it, candles inside on either side (`DungeonConfig.pact_light`) and a red glow. Seen once,
the room and its door go on the minimap (a red mark, grey once spent). Walking up to the stele
shows the pact (`PactPanel`, in the RPG skin, the game paused): its lore line, then three cards,
**the rule** in plain words (and that the door seals until every foe is slain), **kept** (in
green: a choice of relics, as after a boss) and **broken** (in red: the max Health this hero would
lose, and what would be left). **Swear the pact** sinks the stele and opens the door; **Leave**
changes nothing (it asks again when you come back).

Walking in seals the door and the waves come, as in an ambush (`AmbushRoom`: `PactDef.waves` of
`wave_size` foes, +1 every 3 floors). The rule is watched on a copy of `PactDef.rule` (a
`PactRule` subclass: each listens to the hero for its own thing) until the last foe falls:

- **Kept**: the sigil turns gold, a burst of light, a banner and a toast, and a choice of
  `relic_choices` (3) relics (rare perks) a moment later. It waits in the run's offers, so a save
  keeps it.
- **Broken**: at once, `max_hp_cost` of the hero's max Health is lost for the rest of the run (in
  the hero's save), a banner and a toast say how much. The fight goes on; the door opens once the
  waves are slain, and the relic is lost.

During the fight a line under the map (`PactLine`) names the pact and the rule's state: gold while
it holds, red once broken, green once kept; the minimap outlines the room.

| Pact (FR / EN) | Rule | Fight | Broken costs |
|---|---|---|---|
| Pacte de l'Intouché / Pact of the Untouched | take no damage until the last foe falls (`DamageTakenRule`, 0%) | 2 waves of 2 (+1 / 3 floors), the last led by an elite | 12% max Health |
| Pacte du Glas / Pact of the Knell | slay every foe within 30 s + 2 s per floor below the first, from the door sealing (`TimeLimitRule`); the countdown is on the HUD | 2 waves of 3, the last led by an elite | 12% |
| Pacte du Jeûne / Pact of the Fast | no potion, bomb or scroll (`NoConsumableRule`) | 3 waves of 3, the last led by an elite | 10% |
| Pacte de la Dîme / Pact of the Tithe (from floor 3) | lose no more than half your max Health in all (`DamageTakenRule`, 50%) | 2 waves of 1, every foe an elite | 15% |

Any damage counts for the Untouched and the Tithe (blows, shots, traps, burns, falls); a blow a
ward soaks whole does not.

**Where**: `dungeon_config.tres` > Pacts: `pact_chance` (0.7) per normal floor, never the first
floor nor a boss floor, one at most. It also needs a room that can be sealed without cutting
anything off (`PactRoom.find_room()`): not the first room, no stairs in or by it, a single door on
one side (at most `corridor_width` + 3 cells), and the rest of the floor still joined without it.
About half the floors have one free (the merchant's and the smith's rooms are taken first, the
ambush never takes it), so about **a third of the floors** get a pact door (measured: 55 on 175
floors). Nothing else goes in the room: no monsters, chests, encounters, hazards or items. The
pact and its room come from the floor's seed (`PactRoom.floor_rng()`, its own generator so the rest
of the floor is the same with or without it): a daily run has the same pacts for everyone.

**Saves**: a floor's save (`World.spent_data()`) says whether its pact was sworn. A resumed run
rebuilds the floor with its door open and spent: never offered again. A pact left half-fought by
quitting is lost (no relic); a cost already paid stays paid.

The first pact door seen brings a tutorial hint. Debug panel: "Pact door" spawns one of each in a
dead-end room of the current floor.
