# Le Puits des Âmes

*Under the village of Kagari lies an old well. One night without a moon, it woke up and took the
villagers' souls. Only the ninja keeping watch at the shrine was spared. Take the lantern, go down,
bring the souls back.*

Real-time action roguelike for Godot 4.7 (GDScript, Compatibility renderer).
Procedural floors lit by torches and lanterns, traps, holes, crumbling floor and quicksand,
ambush rooms, trapped chests, breakable crates and explosive kegs, elite monsters,
monsters with telegraphed attacks, a boss every 3 floors, melee and ranged weapons,
armor you can see on the hero, consumables, loot, XP, a perk to choose at every level up, and
skills that come from what you hold and what you learn: play a mage, a warrior, a paladin, or a mix. Plays with touch controls,
keyboard or gamepad.

## Project layout

```
assets/              Art, audio, fonts and the UI theme (Ninja Adventure pack)
  characters/          Hero and monster sprite sheets (4 directions, frame by frame), bosses/
  weapons/             Weapon icons + attack/ sheets (the weapon in hand, per direction and frame)
  fx/                  Sprite-sheet effects: slashes, claws, explosion, smoke, magic, flames
  props/               Crates, vases, barrels, powder kegs, lanterns, chests, trap pieces, holes, quicksand
  projectiles/         Arrows, fireballs, magic bolts
  items/               Item icons
  tiles/               Dungeon floors, cliffs and walls
  ui/                  Wood UI, round buttons (sphere/), icons, skill icons (skills/), perk icons (perks/), emotes
  fonts/               Pixel font
  audio/               Sound effects (sfx/), music (one track per floor theme) and jingles
  shaders/             Rig (hit flash + death dissolve), screen look, damage vignette
  theme/               main_theme.tres: pixel UI theme used by every Control
data/                Game content as .tres resources (no code)
  content_db.tres      Index of everything that can spawn
  player/              Starting stats, kit, skills, leveling
  dungeon/             The run (acts/), floor size, difficulty curve, floor looks (themes/)
  biomes/              The worlds a floor can be (one per file) and their hand-made scenes (scenes/)
  visuals/             SpriteFrames: hero.tres, monsters/, weapons/ (the animations themselves)
  audio/               Sounds as AudioStreamRandomizer (variations + pitch) and sound_bank.tres
  monsters/            One file per monster type, bosses in bosses/
  perks/               Level-up perks (common/) and boss relics (relics/)
  upgrades/            Shrine upgrades (bought with souls between runs)
  difficulties/        Easy, Normal, Hard, Nightmare
  story/               story.tres: the game's name, the intro, victory and death texts
  props/               Breakable props and the lantern
  hazards/             Traps, arrow traps, holes, crumbling floor, quicksand and mud
  chests/              Chests (some trapped) and the big chest of ambushes
  elites/              Elite affixes (Swift, Vampiric, Explosive...)
  affixes/             Item affixes for Magic, Rare and Epic equipment (Sharp, of the Bear...)
  shop/                The merchant (stock, prices, look)
  encounters/          Spirit Spring, Blood Altar, Grinning Spirit, Warden's Statue
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  items/tomes/         Skill tomes (teach a spell)
  skills/              Player, monster and boss skills
src/
  autoload/            Events (signal bus), Sfx (sound player), HitStop (impact freeze), Profile (save), Settings (options)
  core/                Small shared helpers (physics layers, weighted random, SafeFile)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    passives/            Building blocks for perks (on hit, on kill, on dash...)
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
    hazards/             HazardDef > TrapDef > ArrowTrapDef, PitDef, QuicksandDef, HeatSourceDef, DarkRoomDef
    monster_traits/      MonsterTrait > GuardTrait, ThiefTrait, DeathBurstTrait, DeathSpawnTrait
    biomes/              BiomeDef, GroundLayerDef, DecorRuleDef, SceneDef (hand-made scenes), SceneKey
  dungeon/             Map data, generator, drawing
  world/               World (owns the current floor), FloorRules (how hard and rewarding it is),
                       NavGrid (pathfinding), FogOfWar (what the hero has seen), WallBuilder,
                       FloorPopulator, BossArena, AmbushRoom, RoomGates, PitLayer;
                       dressing/ (FloorDresser: a floor in its biome, RoomSpace)
  entities/            Actor (shared base), Player, Monster, Projectile, ItemPickup, Stairs, Prop, Trap,
                       hazards/ (Chest, CrumblingFloor, Quicksand, HeatSource, DarkRoom, FloorPatch),
                       ground/ (GroundLayer: a biome's ground, drawn by a shader)
  components/          Inventory, Equipment, SkillSet, PerkSet, StatusSet (burn...)
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack, Cast)
  vfx/                 Particles (particles/), sprite-sheet FX, emotes, afterimages, damage numbers; Vfx helpers
  ui/                  Title screen and shrine, story, act cards, HUD and minimap, touch controls, inventory,
                       perk choice, pause menu, options, end of run
  game/                Game: main scene, floor flow, pauses; RunState (the run: depth, kills, bosses,
                       difficulty), RunRecords (stats, bestiary, achievements, history), OfferQueue
                       (perk choices waiting), GameMenus (the panels), ShrineUpgrades, RunSave (on disk)
tests/               Headless tests: run_tests (the runner), suites/ (unit, title, game, combat, floor, boss,
                     balance: opt-in), support/ (TestSuite: checks, scene helpers, the bot)
tools/balance/       Balance tools (not exported): model, arena, packs, marginal values, economy, compound
                     checks; builds and targets in data/balance/ (see docs/balance.md)
```

**Rule of thumb:** `data/` says *what* exists, `src/definitions/` says *what a thing can have*,
the rest of `src/` says *how it behaves*. Balancing never requires touching code.

## How things fit together

- **Game** creates the Player, asks **World** to build each floor and handles pause and game over.
- **World** generates a `DungeonMap`, rolls the floor's curse or event, builds its `FloorRules`
  (difficulty x event x curse x depth: ask it, never multiply by hand), the walls (`WallBuilder`)
  and pathfinding (`NavGrid`), then lets `FloorPopulator` spawn monsters and items picked from
  `ContentDB` by depth. Anything can shake the screen with `Events.screen_shake`.
- **Actor** (base of Player and Monster) handles stats, HP, attacks, knockback, dashes and hit feedback.
  Final stats = base stats + equipment bonuses + timed buffs.
- **Weapons** are shared: a monster attacks with a `WeaponDef` exactly like the player.
- **Skills and consumables** are both lists of `Effect` resources
  (damage area, projectile, heal, dash, buff). New effect = new class extending `Effect`.
- **Monsters** are driven by a `StateMachine`: Idle (wander) > Chase (path or straight line, use skills)
  > Attack (telegraphed wind-up, strike, recovery). Skills with a `cast_time` go through Cast
  (glow, red circle, cast animation) so the player can dodge them.
  - **Moving**: Chase walks straight at the target only when its body can (`Monster.has_clear_walk()`:
    a shape cast of its width against walls and corners, plus no water, hole or prop on the line);
    otherwise it follows the A* path, its corners cut where the body fits. Walking but getting
    nowhere for 0.3 s (`is_stuck()`), it takes the path, then steps aside and looks again. Monsters
    keep a little space between them (no pile-up in doorways); wandering ones never pick a way
    into a wall.
  - **Sight**: `detect_radius()` is the kind's reach times the difficulty's `detect_range`
    (Easy x0.85, Normal x1, Hard x1.2, Nightmare x1.4); chasing, they see 1.6x further.
  - **Sleep**: what isn't seen isn't run. A few times a second the World lets monsters off screen
    (beyond a 256 px margin) and out of reach of the hero sleep: no AI, no movement, no animation
    (`Monster.set_awake()`, `World.awake_monsters`). Hunting monsters and bosses stay awake; a hit
    wakes a sleeper. On a crowded Nightmare floor, monsters cost about a quarter of what they did.
- **Drawing the floor**: `DungeonView` draws the map in 8x8-cell chunks, each its own canvas item,
  so the renderer skips the ones off screen; inside a chunk, tiles go texture by texture to batch.
  About 90 draw calls whatever the floor's size (it was ~1500 on a big floor).
- **Mist over the walls** (`PlateauMist`, `plateau_mist.gdshader`): a volumetric mist over the
  plateau above the cliffs (and all around the map). Every frame a ray goes down through its
  height in 6 slices (3 with Fewer effects) for each pixel of a small viewport over the view,
  one pixel per art pixel: a 3D noise drifting with the wind and slowly rising, thick at the
  bottom and wispy on top, densities adding up (Beer-Lambert), in dithered steps. Seen from the
  south like the art, it rises up the screen a little over the room behind a wall, and its
  layers lean with the camera. It is lit by the floor's light (`LightField.light_texture()`):
  lamps by a wall and the hero's torch glow in it, scattered softly; away from them it stays
  dark. Thin at the rim so the cliff's edge stays readable. Colors and thickness per theme
  (`DungeonTheme` > Mist).
  The light goes with it: a lamp by a wall reaches into the mist over the rim, losing two levels
  a tile instead of one, and light that went into the mist never comes out the other side (no
  light through the walls). Moving lights (the torch, shots) do the same in the light shader.
- **Game** offers the perk choices (pausing the game) and reacts to boss fights through `Events`.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path.

## Game feel

- **Weight of a blow**: every hit you land pushes the camera a few pixels along the blow, a shot
  recoils it back, a hit taken knocks it away (`GameCamera.kick`, `Events.camera_kick`, springing
  back in real time, apart from the shake; both follow the Screen shake option). A killing blow
  stops the world a moment longer; killing an elite or better slows it down for a beat
  (`HitStop.slow`).
- **What monsters are made of** (`ImpactMaterialDef`, `data/materials/`: flesh, bone, slime,
  armor, spirit, plant; `MonsterDef.material`): a hit sounds like it (a punch in flesh, a dry knock
  on bone, a squelch, a clang on armor, a chime on spirits, played over the monster's cry), its
  sparks take its color, and when it dies it flings **chips** of itself that land and stay for the
  whole floor (`SplatLayer.add_debris`): bone shards, slime drops, bits of armor. Broken crates and
  barrels leave their splinters too. Sounds: Kenney "Impact Sounds" (CC0).
- **VFX**: hand-drawn sprite-sheet effects (slashes, claws, explosions, smoke, magic circles,
  "!" emote when a monster spots you) plus pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector), dash afterimages, animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
- **Atmosphere** (`AmbienceDef` > Atmosphere, one per biome and curse): the whole picture takes
  the biome's colors (`screen.gdshader`: shadows and highlights graded toward two tints,
  saturation, contrast), bright things **bloom** (fire, gold, lights), the air **trembles** with
  heat in the ruins and the desert (rows of pixels sliding by whole pixels). Over the floor, in
  world space (`AtmosphereLayer`, `atmosphere.gdshader`, dithered on the art's grid): **shafts of
  light** falling from cracks above (garden, temple, library, cave, desert), **leaf shadows**
  drifting in the garden, **mist** creeping over the crypt and the flooded caverns, **water light**
  dancing on the floor of the flooded caverns.
- **Attack effects** (shaders, all on the art's pixel grid): a melee swing draws a crescent at the
  weapon's reach and arc (`SwingVfx`, `swing.gdshader`: white cutting edge, the weapon's
  `trail_color` behind, thinning out in dithered pixels), a thrust a streak; claws and bites keep
  their sheets. Hits pop a sharp star (`ImpactVfx`, bigger on crits). Blasts ripple the picture
  (`ShockwaveVfx`, `shockwave.gdshader`). Monster warnings (`TelegraphView`, `telegraph.gdshader`):
  zone, cone or line with crawling hazard stripes and a solid rim, filling up from the monster as
  the attack comes, flashing just before it lands. Shots leave a glowing streak.
- **Shots and blasts**: magic shots (fireballs, bolts, spells) glow in their color (a pulsing
  halo, `ProjectileHalo`, and a light in the dark), leave a glowing streak and burst on impact
  (`Vfx.pop`); plain things (shurikens, arrows, feathers, coins: `projectile_glow` /
  `ProjectileEffect.glow` 0) just fly. Explosions are a ball of fire drawn by a shader
  (`BlastVfx`, `blast.gdshader`: white-hot heart, flame bands, licking edges, smoke) with a
  ripple, fire and smoke particles and a scorch mark left on the floor.
- **Little details**: fights leave **splats** on the floor (`SplatLayer`, `World.add_splat`): blood,
  green slime, purple ink, bone dust, in each monster's `splat_color` (spirits and flames leave
  none), fading after a while. **Plants sway** in a breeze and **bend** away from whoever walks
  through them (`DecorRuleDef.sway`, `SceneKey.sway`). Shallow water **glints** (`GroundLayerDef.shimmer`).
  Braziers and candles **burn** (`PropDef.flame`). The HP bars keep a pale **trail** of what a hit
  cost, then drain it; they glow when healed. Each biome has its **air**: fireflies in the garden,
  sand gusts in the desert, mist over the flooded caverns, dust in the library and the tomb.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **SFX**: the `Sfx` autoload plays world sounds (positional) and UI sounds. Weapons have attack and hit
  sounds, monsters hurt and death sounds, skills and consumables a use sound; everything else comes
  from `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Buses: Master > SFX, UI, Music, Ambience (`default_bus_layout.tres`). Each floor theme has its own music.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: in steps, tile by tile (see [Lights](#lights)): the hero's torch, room lanterns, braziers,
  campfires, glowing shots and explosions light up each floor's own darkness.
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit and
  dissolves monsters pixel by pixel when they die; light falls off in flat steps, tile by tile
  (`LightField`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.
- **Ambience** (`AmbienceDef`, `data/dungeon/ambience/`, set on each floor theme): footsteps that sound
  like the floor (dull in the caves, echoing in the crypt, crunchy in the ruins) and footprints that
  fade, a looping background (wind, storm), random distant sounds around the hero (drops, whispers,
  chains, roars), the SFX bus reverb of the place, floating particles (dust, ghost wisps, embers) and
  drifting pixel fog. Played by `Ambience` (`src/world/ambience.tscn`) on the Ambience bus.
  Big monsters and bosses shake the ground when they walk. Under 30% HP a heartbeat plays and the
  music gets muffled (a low-pass filter on the Music bus). The screen fades to black on the stairs.

## Dungeon

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
  minutes, a run about half an hour. Floors are 72x72 cells with up to 15 rooms on Easy, and
  bigger the harder the run (see Difficulty); boss floors keep that size.
- **Biomes** (`data/biomes/`, `BiomeDef`): every floor is one world from end to end, picked among
  its act's (`ActDef.biomes`; the boss arena has `boss_biome`): Act I **Mossy Cave**,
  **Underground Garden**, **Flooded Caverns**; Act II **Crypt**, **Abandoned Library**; Act III
  **Burning Ruins**, **Ruined Temple**; Act IV **Buried City** (sand streets, an abandoned market,
  oases and palms, a lion fountain) and **Sun Tomb** (sarcophagi, burial chambers, gold). Nothing from another biome ever shows up. A biome has:
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
  a boss floor, rarely on Easy, more and more often up to Nightmare (`DifficultyDef.curse_chance`:
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
  (heals when hitting), **Explosive** (blows up when it dies), **Armored**, **Venomous**
  (poisons), **Spiked** (hurts who hits it).

## On a phone

- **The run is saved** (`RunSave`, `user://run.json`) when a floor begins and whenever the app goes
  to the background (a call, switching apps...). The title screen then offers **Continue**: same
  depth (a fresh floor), the hero exactly as saved (level, stats, gear, bag, perks, spell, perk
  choices left open). Dying erases it. "Save and quit" in the pause menu does the same on purpose.
- **Pause menu** (the II button, Escape, or the phone's back button): resume, options, save and quit,
  give up the run (two taps). Coming back to the app, the game waits paused.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  music and sound volumes, screen shake, size of the touch controls, **vibrations** (big shakes,
  hits you land, crits; `Settings.vibrate()`; exported Android builds need the Vibrate permission),
  **fixed joystick** (it stays in its corner and starts only when touched there, instead of
  appearing under the thumb), **battery saver** (30 FPS cap, `Engine.max_fps`), **fewer effects**
  (half the particles in `Vfx.burst`), **run timer** (on/off), **tutorial hints** (on/off) and
  **Replay tutorial**. The window (`OptionsPanel`, built in code on `MenuWindow`) groups them
  (Sound, Touch controls, Screen and battery, Tutorial), each with a one-line "what it does";
  on/off options are big switches, and tapping an option's name flips it too.
- **Minimap** (`Minimap`): rooms are revealed when you walk in, corridors around you; it shows holes,
  the stairs (violet while sealed), unopened chests, a running ambush, the boss and, near the
  end of a seal, the last monsters. Tap it for the whole floor.

## Tutorial

No separate tutorial level: the first run teaches as it goes. A small wooden board comes up at the
top of the screen (`HintBox`), says what to do, and, when it is about a control, a gold ring pulses
around it with an arrow. Each hint shows **once ever** (`Profile.hints_seen`), one at a time, never
over a menu or a big banner. A tap (or OK) closes it.

- **First steps**: move (it stays until you have walked a few tiles), then the sealed stairs; when
  a monster first sees you, attack (until you swing), then roll, then the weapon's two skills.
- **The first time something happens**: low health (drink a potion from the belt), gear in the bag
  (open the Bag), your first soul, perks and families, a family bonus, a spell, an elite, a rune, the
  forge, the merchant, a chest, an ambush, a boss, the stairs opening, a cursed or strange floor,
  cold and heat.
- **Data**: `data/tutorial/tutorial.tres` (`TutorialDef`): the hints (`HintDef`: its cue, the hint
  it comes after, a condition, the title and text, the HUD control it points at, the action that
  ends it or how long it stays, its priority) and the distances and thresholds. The cues, actions
  and conditions are listed in `Tutorial` (`src/game/tutorial.gd`); the controls are the HUD's
  unique names (`Hud.hint_target()`).
- **Options**: "Tutorial hints" turns them off; "Replay tutorial" shows them all again.

## Run timer (speedruns)

Every run is timed (`RunTimer`, `RunState.time`): in-game time, in real seconds (hit stops and
slow motion don't slow it), counting in the bag, the shop and the perk choices (deciding is part
of the run) but not in the pause menu, while a floor loads or during its title cards. It is saved
with the run, so quitting and coming back doesn't reset it.

- **On screen**, under the map (`Hud.show_run_time()`; Options > Run timer hides it). Once the
  last boss falls, the win's time stays there, in gold, through endless mode.
- **Splits**: taking the stairs notes the floor's time (`RunState.splits`) and shows it a few
  seconds: "Floor 3  4:12.3  -0:05.2", green when ahead of the record run, red when behind.
- **Records** (`Profile.best_times`, `best_splits`): the fastest win per difficulty and ascension
  level (`RunState.record_key()`: "normal", "nightmare/a3"), with its splits to race against.
  Daily runs keep none (their own race).
- **Where it shows**: the end screens (the time, then "New record!" or the record to beat), the
  log, and the Codex > Runs (each run's time, the fastest wins).

## Android build

Everything is ready in `export_presets.cfg` (preset **Android**): the app is called "Le Puits des
Âmes", package `com.absolutezeroo.puitsdesames`, version 0.1.0 (code 1), arm64-v8a, landscape,
immersive, the Vibrate permission, no Gradle build needed. Tests and tools are left out
(`exclude_filter`). The icon is adaptive (`assets/icon/`: the hero over the well's glow and its
souls, plus a monochrome version for themed icons); the splash shows it on the night color.
The project keeps its name "Mini Roguelike" so saves stay where they are (`user://`).

- **From the phone** (Godot's Android editor): Project > Export > Android > Export Project. The
  editor signs debug builds with its own key. Debug builds show the DBG button; a release build
  hides it.
- **From a computer**: install the Android export templates (Editor > Manage Export Templates)
  and set the Java and Android SDK paths in Editor Settings > Export > Android (only the SDK's
  build-tools are needed: `apksigner`); then
  `godot --headless --export-debug "Android" build/le-puits-des-ames.apk` (or `--export-release`).
- **Release**: make your own key once and keep it safe (every update must be signed with it):
  `keytool -genkeypair -v -keystore puits-release.keystore -alias puits -keyalg RSA -keysize 2048
  -validity 10000`. Never put it, or its password, in git: give it to Godot through the
  environment (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`) or the preset's
  fields on your own machine only.
- **Play Store** (preset **Android Play Store**): the same app as an AAB, built with Gradle. Install
  the Android build template once (Project > Install Android Build Template; the `android/` folder
  it makes is not in git), then `godot --headless --export-release "Android Play Store"
  build/le-puits-des-ames.aab`. Raise `version/code` (and `version/name`) for each upload.
- **Privacy policy**: `docs/privacy.html` (the game sends nothing anywhere; saves stay on the
  phone). With GitHub Pages on (Settings > Pages > branch `main`, folder `/docs`) it is at
  `https://absolutezeroo.github.io/mini-rogulike/privacy.html`, the link the Play Console asks for.

## Lights

Light comes in levels, from 0 (pitch dark) to 15 (full light), like in block games: a lantern of
level 13 lights its tile 13, the next tiles 12, then 11... (`LightField`, `src/world/lighting/`).
It spreads around corners but walls stop it; cliff faces catch it, and the mist on the plateau
above glows near the lamps, fading twice as fast (see Mist over the walls). Each level is one flat band of color, and the color changes as the light fades
(warm by the flame, dusky further out, cold in the dark).

- **Lights** are `LightSource` nodes (`color`, `level`): lanterns and furniture (`PropDef.light_level`),
  campfires and oases (`HeatSourceDef.light_level`), the hero's torch (level 12), glowing shots and
  flashes (`relative`: counted above the floor's own light, so they show even in daylight).
- **Each theme** has its `LightingDef` (`data/dungeon/lighting/`): `ambient_level` (the light away
  from any lamp: 5 in the crypt, 9 in the desert) and `ramp`, the color of each level. Difficulty,
  curses and events (darkness, the Blood Moon) lower the floor's light and tint it, less and less
  near the lamps.
- **How**: lights that stay put are spread once per floor on the CPU, half a tile per cell, all at
  once, brightest first. Moving ones (up to 24 near the hero) are added every frame by a shader
  (`light_cells.gdshader`, walls checked along the way) into a small viewport, one pixel per cell,
  stretched over the floor and multiplied with it: no light ever gets brighter than the art, so
  bright floors (the desert) never burn white. Sparks, slashes, floating text and the ambient
  particles are drawn above it (z 4 and up) and shine on their own.

## Blood Moon

A floor event (`data/floor_events/blood_moon.tres`): frenzied monsters, double gold, and its own
look over the biome (`FloorEventDef.atmosphere`, the biome's sounds stay; `ambient_tint` reddens
the light): a crimson grade, a great red glow breathing over the top of the screen
(`AmbienceDef.moon_color`), edges darkening to blood and beating like a heart
(`vignette_color`, `vignette_pulse`, in `screen.gdshader`), red moonlight shafts and mist, falling
red ash (`src/vfx/ambient/blood_ash.tscn`).

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

## Monster ranks: Elite, Epic, Legendary, Shiny

Any monster can come at a rank (`MonsterRankDef`, `data/monster_ranks/`; `DungeonConfig.elite_rank`
and `rare_ranks`, rarest first, each with its own chance from its depth, times the difficulty):

| Rank | Affixes | Health (depth 1 / 5 / 11) | Damage | Look | Rewards |
|---|---|---|---|---|---|
| **Elite** | 1 ("Vampiric Skeleton") | x2.5 / x3.7 / x5.5 | x1.15 | a ring of the affix's color | x3 XP, better loot, 1 extra drop |
| **Epic** (from depth 3) | 2, listed over its name | - / x6.3 / x9 | x1.2 | two purple rings | x6 XP, 2 extra drops, x8 gold |
| **Legendary** (from depth 5) | 3 | - / x8.5 / x11.5 | x1.3 | golden rings and a crown of rays | x10 XP, 3 extra drops of high quality, x15 gold |
| **Shiny** (1 in 400, any depth) | none | x3.3 / x3.9 / x4.8 | x1 | other colors (hue shift), a gleam sweeping its body, sparkles | x8 XP, 3 extra drops, x25 gold; joins the bestiary's Shiny collection |

A rank's Health grows with depth (`hp_multiplier` + `hp_multiplier_per_depth` per floor): the
hero's power grows faster than the monsters' own depth scaling, so a deeper Elite needs more
Health to stay a short duel. Its affixes' Health on top (Armored x1.3, Explosive x0.85...).
Ranked bosses use `boss_hp_multiplier` and keep their own damage.

Bosses roll the rare ranks too (`boss_chance`): a **Legendary King Slime (Swift, Vampiric,
Armored)** has its affixes' perks, more HP, better loot and one more relic to choose; a Shiny boss
other colors and one more relic. The boss bar shows the rank's color and the affixes. The debug
panel spawns any rank and can make the next boss one.

## Dragons

- **Sand Drake** (Act IV): breathes slowing sand, whips up a sandstorm ring.
- **The Wyrms** (`WyrmTrait`, `WyrmBody`): long dragons. The boss is the head; a body of
  segments follows the path the head took, wings flap on its sides, a pointed tail ends it.
  The body burns at a touch (and throws you back); only the head can be hurt. They fly.
  **Azure Wyrm** (Act II, frost: Frost Breath, Glacial Dive, Hailstorm) and **Jade Wyrm**
  (Act III, venom: Venom Spit, Coil Rush, Toxic Bloom), with their three phases and fiercer
  forms, and their own bestiary challenge (a Hammer, an Axe).

## Codex: bestiary, achievements, runs

**The bestiary** (codex tab, also in the pause menu): every monster and boss, unknown, *seen*
(it spotted you: `Profile.mark_seen`) or slain. Tap one for its page (`MonsterPage`): its look,
what it is, its stats and ways (flies, keeps its distance, traits, a boss' phases), its
**attacks** with an **animated preview** (`AttackPreview`: the same red warning, then the shots,
blast, charge, summons or heal, built from the WeaponDef / SkillDef data), and its challenges.
- **Hunter ranks** (`BestiaryRules`, `data/bestiary.tres`; `Bestiary`): Known (1 kill), Hunted
  (10), Mastered (30) for monsters, 1/3/6 for bosses. Each rank pays souls once
  (5/15/40, bosses 30/60/120); Mastered gives **+10% damage** to that kind for good.
- **Challenges** (`HuntChallenge`, watched by `HuntTracker`): every monster gets those that
  apply (an elite one, pushed into a hole, 3 within 5 s, untouched since it saw you, a crit
  finish), every boss its own (with a ranged weapon, with a melee one, under 90 s, without a
  potion, losing less than 25% HP) plus one with a given weapon (`MonsterDef.challenges`: the
  King Slime with a Bow, the Red Samurai with a Katana...). Done once, paid in souls, with a toast.

The **Codex** (`CodexPanel`, from the title screen and the pause menu) is built in code in the
game's skin (`RpgWindow`, like the bag and the forge): four tabs in its header, the souls you hold
on the right, and under the tabs a summary line plus one sentence saying what the tab is for
(souls are kept between runs and spent at the Shrine; gold is lost when a run ends). Lists scroll
with a finger (`TouchScroll`); `CodexRows` builds their rows, with a tick box for what is done.
- **Quests**: today's and this week's quests side by side, each with its goal, a progress bar,
  its reward in souls ("Received" once paid) and the time until new ones.
- **Bestiary**: act by act (floors, how many kinds slain), a card per monster and boss
  (`CodexCard`: picture, rank, kills, a bar toward the next rank, gold frame once Mastered,
  Boss and Shiny badges; unknown ones are dark shapes until met). Its page has three columns:
  look, where it lives and its Shiny; attacks with the preview, how it behaves and its stats
  (Health, Damage, Armor, Move speed, each with what the number means); hunter ranks (slay N,
  +X souls, done or not) and challenges.
- **Achievements** (`data/achievements/`, `AchievementDef`): a goal on one of the profile's counters
  (kills, elites, wardens, kinds of creatures, depth, victories on Hard / Nightmare / ascension,
  monsters pushed into holes, chests, Epic items, encounters, gold or level in one run), with a
  progress bar and its reward; the closest to done first. Reaching it pays souls, with a note at
  the top of the screen.
- **Runs**: the fastest wins, then the last 20 runs: how each ended (victory, or the floor and
  what slew you), when, the difficulty, how far (floor N of 12), how long, level, weapon, kills
  and the souls earned.

## Story and identity

Everything is tied to one idea: **souls**. The Well stole the souls of the hero's village; the
monsters down there feed on them; the bosses are its wardens, and the Gilded Hoarder, deep in the
Buried Kingdom, is the Keeper who hoards them.

- **The story** (`data/story/story.tres`, `StoryDef`) is told page by page before the first run
  (`StoryScreen`: typed out, tap to go on, Skip), and again from the title screen's Story button.
- **Every act opens with a title card** on black (`ActCard`, `ActDef.lore`): its name and a line of story.
- **Every kill frees a soul**: a little light rises from the body and flies into the hero's lantern
  (`SoulWisp`); bosses free a dozen. The HUD counts the souls of the run, which go to the
  **shrine** at the end: it turns them into permanent upgrades.
- Death and victory screens tell how it ended (`StoryDef.death_lines`, `victory_text`).

The game's texts are in English; the name stays French. The project's internal name is still
"Mini Roguelike" (`project.godot`), on purpose: the save file's folder depends on it.

## The belt

Potions, bombs and scrolls don't take room in the bag: they go on the **belt** (`Belt`),
3 slots of one kind each, stacking up to 9. Each slot has its own button on screen, so you choose
what to drink or throw. When the belt is full, the rest goes to the bag; the bag screen moves
consumables between the two ("To belt" / "To bag"). The merchant buys from the belt too.

## Loot, gold and the merchant

- **Item level**: every weapon and armor is as strong as the floor it was found or bought on
  (`ItemLevelRules`, `data/items/item_levels.tres`), and it never grows after that. A floor-2
  katana is better than a floor-1 one; to get stronger you have to loot. Each level above 1 adds
  2 damage per second to a weapon (the same for a quick rapier and a slow hammer: the slow one
  gets more per hit), 1.5 Health to a body armor and 1 to a helm. Monsters and bosses grow at the
  same pace (+32% / +33% Health per floor, `dungeon_config.tres` > Difficulty), so a hero who
  keeps his first sword falls behind. Rarity and affixes come on top. The level shows on the slot
  ("Lv 7"), first on the item card, and first in the comparison with what you wear ("+3 item
  levels, +5 damage"). The merchant sells at the floor's level; a forge keeps the weapon's level.
- **Rarity**: found equipment can come out **Magic** (blue, 1 affix), **Rare** (yellow, 2) or
  **Epic** (purple, 3), with more damage and bonuses (`ItemRarity`). Affixes (`data/affixes/`,
  `ItemAffixDef`) add stats ("Sharp", "of the Bear"...) or set enemies on fire, poison or slow
  them ("Burning", "Venomous", "Frozen"). Some act like a perk while worn (`ItemAffixDef.passives`,
  joined to the hero's `PerkSet` by `set_gear()`; their `description` shows on the item):
  **Vampiric** (heal on kill), **Shocking** (every 4th hit chains lightning), **of Embers**
  (burning enemies explode), **Shattering** (+25% on slowed enemies), **of Echoes** (skills may be
  ready again at once), **of Thorns**. Rare and Epic items on the floor shine with a beam.
  `LootRoller` makes rolled copies; the plain .tres is the Common version. Chances grow with depth
  (`dungeon_config.tres` > Loot) and with the source: elites, chests and bosses drop better.
- **Gold** drops from monsters (always from elites and bosses), chests and sometimes crates, and
  flies to you. It lasts one run. Potions and other consumables you already carry plenty of
  (4 of the same, `consumable_carry_cap`) drop as gold instead: no bag full of potions.
- **The merchant** (`data/shop/merchant.tres`, `Merchant`, `ShopPanel`) waits in a quiet room on
  some floors: walk up to him to buy equipment (better than average), potions and sometimes a
  tome, or to sell what you carry. Every item has a `value`; the price grows with rarity and depth.
  **Reroll** buys a new stock (`ShopDef.reroll_cost`, +`reroll_cost_growth` each time at the same
  merchant). **Lock** keeps an entry through rerolls; if you don't buy it, it waits at the next
  merchant at the same price (`World.kept_stock`, kept in saved runs).

## Bag, forge and the other in-run screens

The bag, the forge, the shop, encounters, perk choices, the pause menu and the end of a run are drawn in the game's RPG skin (`UiSkin`, `src/ui/common/`): a wooden
board with a gold ornate border (`RpgWindow`), the title on a red ribbon, dark recesses for each
column, and items in square slots (`ItemSlot`): the icon at a whole-pixel scale, a frame in the
item's rarity color (a rune's in its family's), how many, and a weapon's rune sockets as little
stones lit in their runes' colors. The selected slot pulses gold.

- **Bag** (`InventoryPanel`, built in code): the hero, the weapon / head / body slots, the belt and
  the stats on the left; the bag as a 4-column grid of slots (empty places shown); the picked
  item's card on the right (name in its rarity, type, every line of its details, its rune sockets)
  with Equip / Use / Learn, To belt and Drop.
- **Forge** (`ForgePanel`): the smith and what he says; the weapons you can work on as slots, the
  picked one big with its sockets; your runes as a grid. Pick a rune, then "Set it in"; pick a
  set rune, then "Take out (gold)".
- **Shop** (`ShopPanel`, built in code): the merchant and your gold on top; what he sells as slots
  with their price (a padlock on locked ones) and Reroll ("new items for sale, locked ones stay");
  what you carry with what he pays; the picked item's card: its stats in words, how it compares
  with what you wear (`ItemCompare`: "+3 damage", "-12 move speed", in green / red), its price,
  Buy (greyed with the reason: not enough gold, bag full), Lock (what it does, spelled out) or Sell.
- **Encounters** (`EncounterPanel`): one card per choice with its cost and every outcome in plain
  words with its odds ("55%  Heals you fully", `EncounterChoice.chances()`,
  `EncounterOutcome.summary()`), risks in red; Leave ("nothing happens, you can come back").
- **Perk choice**, **pause menu** and **end of a run** use `RpgDialog` (a centred board, no Close):
  the cards on dark wood with Reroll / Banish explained; each pause button says what it does, with
  what gold and souls are for; the end screen shows the run's numbers (`RunState.summary_rows()`),
  the souls earned and what they buy.

## Runes and the forge

- **Runes** (`RuneDef`, `data/runes/`, content_db > Runes): stones carved with a glyph of one of
  the five families. Bosses always drop one (`boss_runes`), elites and up often
  (`ranked_rune_chance`, 30%), chests sometimes (`chest_rune_chance`, 20%), plain monsters rarely
  (`rune_chance`, 1%). They are not among the random items: no merchant sells them.
  - Inferno: **Ember** (hits may set enemies on fire), **Pyre** (enemies dying burning explode).
  - Frost: **Rime** (hits chill), **Shatter** (critical hits release a frost shockwave that slows).
  - Blood: **Leech** (your hits heal 10% of their damage), **Fury** (wounded you hit harder, kills heal).
  - Storm: **Spark** (every 3rd hit chains lightning), **Gale** (your roll throws a gust).
  - Arcane: **Echo** (skills may be ready again at once), **Prism** (one more projectile; with Multishot, 2 more at most, the volley sharing its damage).
- **Sockets**: every weapon has 1 to 3, by rarity (`ItemRarity.SOCKETS`: Common and Magic 1,
  Rare 2, Epic 3). A rune works like a perk while its weapon is worn (`RuneDef.passives`, through
  `PerkSet.set_gear`); two identical runes count twice. Set runes show on the weapon's details,
  with its empty sockets, and are saved with it.
- **The forge** (`data/forge/smith.tres`, `ForgeDef`, `Forge`, `ForgePanel`): Brann the Smith,
  his anvil and glowing coals, in a quiet room of some floors (`forge_chance` 30%, +15% for each
  floor without one, never on boss floors). Walk up to him: pick a weapon (the worn one or one
  in the bag), set runes from the bag into its free sockets for free, or pick a socket and take
  its rune back out, intact, for gold (`removal_price` + `removal_price_per_depth`). A plain
  weapon becomes its own copy the first time a rune goes in. Debug panel: "Forge here", "Every rune".

## Special floors and bosses

Bosses have a lot of HP and stand their ground: they ignore 95% of the knockback, so no weapon can
keep one away from you (`MonsterDef.knockback_resistance`). Big monsters resist half of it, and
elites at least half.

- **Special floors** (`data/floor_events/`, `FloorEventDef`): 30% of the normal floors after the first
  (`dungeon_config.tres` > Floor events) are announced when you arrive: **Haunted** (elites, dim),
  **Treasure Vault** (chests and gold, more traps), **The Swarm** (hordes of weak monsters),
  **Pitch Dark** (very dark, better loot), **Quiet Halls** (few monsters, the merchant, encounters),
  **Blood Moon** (monsters hit harder, double gold). They multiply monsters, HP, damage, elites,
  light, chests, hazards, encounters, gold and loot quality.
- **Two bosses per act** (`ActDef.boss` + `other_bosses`): each run draws one per act (saved with
  the run; the title screen shows both). King Slime or the **Giant Frog** (leaps, poison spit, calls
  its brood); Demon Cyclops or the **Weeping Spirit** (a freezing wail, blinks, calls lost souls);
  Crimson Tengu or the **Red Samurai** (arcs of fire, dashes, a ring of fire). Gilded Hoarder or the
  **Sun Wraith** (a burning sun buried with the kingdom: solar flares, blinks, calls its embers).

## Quests

Every day, 3 **daily quests**; every week (from Monday), 3 **weekly quests**
(`data/quests/`, `QuestDef`, drawn by `QuestBoard` from the date: everyone gets the same ones,
UTC). "Slay 60 monsters", "Open 4 chests", "Reach floor 6 in one run", "Go through a cursed
floor", "Defeat 5 bosses", "Win a run"... They count what you do in any run during that day
or week (`Profile.period_stat`), pay their souls as soon as they're done (a toast in the game)
and show on the title screen (**Quests**, also a tab of the Codex) with the time left.

## Encounters

Some rooms hold something strange (`data/encounters/`, `EncounterDef`): walk up to it and choose.
Each choice has a cost (gold, a part of your max health) and outcomes drawn by weight
(`EncounterChoice`, `EncounterOutcome`: heal, hurt, gold, an item of some quality, a choice of
perks or relics, monsters or elites, any `Effect`). Each can be used once. The panel shows every
outcome in words with its odds before you choose; the words come from the outcome's fields
(`EncounterOutcome.summary()`), so new encounters explain themselves.

| Encounter | Choice | What may happen |
|---|---|---|
| Spirit Spring | Drink | healed (55%), a strong buff for a minute (25%), cursed water hurts (20%) |
| Blood Altar | Offer your blood (-15% max health) | a choice of relics |
| Grinning Spirit | Pay 30 / 80 gold (more each floor) | an item, sometimes a great one... or it laughs and runs |
| Warden's Statue | Pray | a choice of perks (50%), or two elites (50%) |

## Skills and builds

There are no classes: what you hold and what you learn decides how you play.
The hero has **4 skill buttons**:

| Button | Skill | Comes from |
|---|---|---|
| 1 | Roll | always (`PlayerDef.innate_skills`) |
| 2, 3 | two weapon skills | the equipped weapon (`WeaponDef.skills`) |
| 4 | a learned spell | the last **skill tome** you read (`SkillTomeDef`) |

| Style | Weapons | Their skills |
|---|---|---|
| Warrior | Katana, Sai, Lance, Battle Axe, War Hammer, Pickaxe, Greatsword, Whip | Whirlwind, Iaido Dash, Flurry, Shadow Step, Piercing Thrust, Spear Throw, Cleave, Ground Slam, Fissure, Rock Spike, Sundering Blow, Lash, Battle Cry |
| Ninja | Ninjaku, Shuriken (3 stars a throw) | Kunai Fan, Shuriken Storm (a ring of 16), Shadow Step |
| Duelist | Rapier (fast, crits) | Riposte (leap back, then crits and speed), Piercing Thrust |
| Archer | Bow (arrows pierce one enemy) | Volley (5 arrows), Arrow Rain (4 hits on an area ahead) |
| Mage | Spark Wand, Frost Staff, Ember Tome | Spark Nova, Arcane Bolt, Frost Nova (slow), Ice Shards (slow), Fireball, Fire Wave (burn) |
| Paladin | Templar Sword | Smite (damage + heal), Holy Shield (Armor + heal; both heal half during a boss fight) |

The weapon in the hero's hand is animated frame by frame with the attack. For weapons without a
hand-drawn sheet, the sheet is baked from the item sprite rotated around its handle (a swing,
a heavy swing, a thrust, a lash or an aim; 4 directions x 4 frames, `assets/weapons/attack/`).

Tomes (found on the floor, dropped by casters and bosses) teach Holy Light, Battle Cry, Frost Nova,
Fireball, Blink or Thunder, whatever weapon you hold: a warrior can heal, a mage can blink.
Swapping weapons swaps buttons 2 and 3 (new skills start on a short cooldown, so swapping can't skip
cooldowns); the roll and the learned spell stay.

Skill damage uses **skill power** (`power x (1 + skill_power)`), and cooldowns shrink with
**cooldown reduction** (60% max): the Arcane Focus, Arcane Power, Devotion perks and the Sage's Codex
relic push a caster build; the Shadow Cloak gives some cooldown reduction.

A skill is a list of `Effect`s, each with an optional **delay** (combos: Flurry is three stabs,
Fissure three bursts running forward). Effects: damage area (with a sheet effect, a status, an offset),
projectiles (fans, rings, pierce, explosions, status), dash, dash strike (cuts everything along the
path), heal, buff, summon. Statuses (`OnHitStatus`): burn and slow.

## Perks and relics

Every level up pauses the game and offers **1 perk out of 3**. Taking a perk again levels it up
(up to its `max_stacks`). Bosses drop a choice of **relics** (rare perks).

Everything on a card is spelled out for someone who never played a roguelike: "New perk (up to
level 3)" or "Level 1 > 2 (max 3)", what it does, and a box per **family** with its name, little
squares for the perks of it you hold (this one included), how many more it takes and what its
bonus does; the card that would complete a family glows and says "AWAKENS!". One line under the
title says what families are. In the bag, **Perks** opens "Your perks" (`BuildWindow`): every
family with its progress and bonus, and every perk taken with its level and effect.

A `PerkDef` (in `data/perks/`) is stat bonuses + a list of `Passive`s, both multiplied by its level:

| Passive | Hook | Used by |
|---|---|---|
| `HealOnKillPassive` | on kill (not summons) | Vampirism |
| `LifestealPassive` | on hit (direct hits only) | the Leech rune, Vampiric elites |
| `HealOnSkillPassive` | on skill | Devotion |
| `ThornsPassive` | on damaged (can leave a status) | Burning Thorns |
| `RetaliatePassive` | on damaged (cooldown, can leave a status) | Frost Armor: getting hit throws enemies back and chills them |
| `MomentumPassive` | on dash, before a hit | Swiftness: hits right after a roll deal more |
| `OpenerPassive` | before a hit | Precision: the first blow on an unhurt enemy is a crit |
| `FloorWardPassive` | on a new floor | Guardian Ring: every floor starts with a ward |
| `BurnOnHitPassive` | on hit | Ignite (burn status) |
| `CritShockwavePassive` | on hit (crits, can leave a status) | Thunderclap, the Shatter rune |
| `DashShockwavePassive` | on dash (can leave a status) | Shock Roll, Cold Snap, Blazing Roll |
| `SlowOnHitPassive` | on hit | Frostbite |
| `StatusDamagePassive` | before a hit (burning/poisoned/slowed target) | Kindling, the Frost family |
| `KillBurstPassive` | on kill (shards out of the body, a blast) | Ice Shards, the Inferno family |
| `SkillEchoPassive` | on skill (cooldown back to 0) | Echo |
| `EffectsOnSkillPassive` | on skill (any `Effect`) | the Arcane family |
| `ChainLightningPassive` | every few hits | the Storm family |
| `BloodlustPassive` | before a hit (wounded), on kill | Bloodrage, the Blood family, the Fury rune |
| `LootOnKillPassive` | on kill | Fortune |
| `ExecutePassive` | before a hit | Executioner |
| `ExtraProjectilesPassive` | every volley | Multishot |
| `CheatDeathPassive` | before dying | Phoenix Feather |

Damage caused by a passive (burn, thorns, shockwaves, chains, Ice Shards' shards, the Arcane
ring of bolts: `ProjectileSpec.secondary`) is a *secondary* hit: it never triggers other on-hit
perks (no lifesteal, no chain counter), and passive shots get no extra projectiles, so effects
can't chain forever.

**Healing from hits, kills and skills** (`SustainRules`, `data/dungeon/sustain.tres`, set in
`DungeonConfig` > Sustain; `SustainMeter`, `Actor.sustain_heal()`): Leech, Vampirism, Devotion,
the Blood family, the Fury rune and Vampiric gear all draw from one budget. It holds 20% of the
hero's max health (a pack slain at once still heals well) and refills 4% of it per second. While a
boss fight is on it holds a quarter of that (5%) and refills a tenth as fast (0.4% a second,
`boss_fight_burst`, `boss_fight_rate`): healing there forgives a mistake, it can't out-heal a boss. Healing is paid in whole
points, the fractions adding up (10% of a 7-damage hit is 0.7, not 1). Burn and poison ticks and
secondary hits heal nothing, and summoned monsters and a boss's adds feed no "on kill" heal (nor
Fortune's loot). Potions, springs, healing spells and level ups are not limited. Perks are stored per actor in a `PerkSet`,
so monsters could use them too (elites, later).

### Families (synergies)

Most perks and relics belong to a **family** (`SynergyDef`, `data/perks/synergies/`, listed in
`content_db.tres` > Synergies; a perk names its own in `PerkDef.synergies`). Holding **3 different
perks** of a family wakes its bonus for the rest of the run: a change in how you play, not a number.

| Family | Perks and relics | Awake |
|---|---|---|
| **Inferno** | Ignite, Kindling, Blazing Roll, Burning Thorns, Phoenix Feather | enemies that die burning explode and set everything around on fire |
| **Frost** | Frostbite, Cold Snap, Ice Shards, Frost Armor, Guardian Ring | slowed enemies take +50%, crits freeze them |
| **Blood** | Vampirism, Vitality, Bloodrage, Devotion, Executioner | below half Health +40% damage, every kill heals 4% max Health |
| **Storm** | Frenzy, Thunderclap, Shock Roll, Swiftness | attacks 15% faster; every 3rd hit, lightning jumps to 3 enemies |
| **Arcane** | Arcane Focus, Arcane Power, Devotion, Echo, Sage's Codex, Multishot | every skill also fires a ring of 8 bolts |

A perk sits in a family only if its effect plainly belongs to it (Inferno: fire and burning;
Frost: cold, slows, freezing; Blood: health, life drain, low-health power; Storm: lightning,
chains, speed of the strike; Arcane: skills, spells, cooldowns). Plain-number perks (Strength,
Precision, Fortune, War Banner) belong to none. See docs/balance.md.

### Choosing: reroll, banish, families first

Under the cards, **Reroll** deals three other cards and **Banish** (then tap a card) removes that
perk for the rest of the run, another card taking its place. A run starts with
`base_rerolls` / `base_banishes` (1 each, `DungeonConfig` > Perk choices), plus the shrine's Loaded
Dice and Exile; every boss slain gives `rerolls_per_boss` more. Offers lean toward the families you
have started: a perk weighs `1 + family_bias` times more for each started, not yet awake family
it belongs to (`ContentDB.pick_perks`).

The perk cards show each family's count ("Frost 1/3") and shine "Wakes Inferno!" on the card that
would complete one. An awake family gets a banner and a framed icon at the head of the HUD's perk row.

## The run

A run is **4 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its biomes, its own monsters and a boss on its last floor. Beating the last boss **wins the run**;
you can then keep going in endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. Mossy Caves | 1-3 | Cave Mouse, Blue Bat, Slime, Red Spider, Spore Cap, Viper, Acid Larva, Burrower, Giant Slime, Shell Guard, Thief Racoon | King Slime |
| II. Haunted Crypt | 4-6 | Skeleton, Dark Sorcerer, Spirit, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull, Thief Racoon, Brood Mother | Demon Cyclops |
| III. Burning Ruins | 7-9 | Fire Shaman, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus, Bomber, Brood Mother, Shell Guard | Crimson Tengu |
| IV. Buried Kingdom | 10-12 | Dune Rex, Gold Racoon, Red Viper, Ash Lizard, Bone Lizard, Stone Mole, Bomber | Gilded Hoarder |

**Supports** fight from behind, kill them first: the **Moss Heart** (act I) and the **Ember
Heart** (act III) mend their hurt allies, the **Soul Moth** (act II) and the **Gilded Moth**
(act IV) wrap them in wards that soak up your blows, the **Sand Drummer** (act IV) beats a war
drum (allies hit harder, run faster); the **Fire Shaman** now mends its allies too
(`AllyEffect`: heal, buff or ward the allies around; `SkillDef.ai_ally_need`: only when an ally
needs it). A beam of light shows who is helped.

Monsters are data (`MonsterDef`): stats, a weapon (its `on_hit` status poisons, burns or slows),
skills (telegraphed casts: spore clouds, dives, charges, ink rings...), and **traits**
(`MonsterDef.traits`, `src/definitions/monster_traits/`): small resources that hook into the
monster (on spawn, every frame, steering, attacking, taking a hit, hurting the hero, dying, drawing).
Every monster of a kind shares the trait; per-monster values live in `Monster.trait_state()`.
What a monster draws besides its body (warnings, elite aura and name, health bar, trait drawings)
is `MonsterOverlay`.

- **DeathBurstTrait**: bursts after a short warning (a flame spirit explodes, a frost skull
  freezes everything around).
- **DeathSpawnTrait**: monsters come out when it dies (a giant slime splits in two).
- **GuardTrait** (Shell Guard): the shell, the silver arc in front of it, blocks most of the damage
  and push of blows from the front. It turns slowly: roll behind it. Burns, poison and blasts
  go around the shell.
- **ThiefTrait** (Thief Racoon): each hit takes some of your gold, then it runs away. Slay it to
  get the gold back, with interest.
- **Brood Mother**: keeps her distance and lays red spiders (a `SummonEffect` skill). Kill her first.
- **Bomber**: keeps away and lobs bombs that blow up where they land (a projectile skill with an
  `explosion_radius`).
- The **Fire Shaman** heals the monsters around it.

## Difficulty

Pressing Play asks for a difficulty (`data/difficulties/`, `DifficultyDef`). Every value multiplies
the normal game:

| | Easy | Normal | Hard | Nightmare |
|---|---|---|---|---|
| Monster HP | x0.7 | x1 | x1.3 | x1.7 |
| Monster damage (attacks, skills, traps, bursts) | x0.6 | x1 | x1.35 | x1.8 |
| Time to dodge (wind-ups, casts) | x1.35 | x1 | x0.85 | x0.7 |
| Monster speed | x0.9 | x1 | x1.05 | x1.15 |
| How far monsters spot you (`detect_range`) | x0.85 | x1 | x1.2 | x1.4 |
| Extra monsters per room | 0 | 0 | +1 | +2 |
| Floor size (`floor_size`) | 72x72 | 84x84 | 96x96 | 104x104 |
| Rooms per floor (`rooms`) | 15 | 19 | 23 | 27 |
| Boss HP | x0.7 | x1 | x1.3 | x1.6 |
| Elite chance | x0.5 | x1 | x1.4 | x1.7 |
| Drop chance | x1.4 | x1 | x1 | x0.9 |
| Heal on each new floor | 25% | - | - | - |
| Light | brighter | - | darker | much darker |
| Souls | x0.5 | x1 | x1.6 | x2.5 |

Bigger floors get more of everything with their rooms: monsters, chests, hazards, encounters and
items lying around. A floor starts with at most `max_monsters_per_floor` (110) monsters, so the
phone keeps up on Nightmare; the seal never asks for more than `seal_max` (50) kills.

Easy, Normal and Hard are open; **Nightmare unlocks after a win on Hard** (`unlocked_by`).
**Ascension**: a Nightmare win opens **Nightmare +1**, a +1 win opens +2, up to +10
(`data/ascension/`, `AscensionDef`, picked on a strip under the difficulty cards, which lists every
twist up to the chosen level, the next one and the souls multiplier). Each level adds its twist
on top of the ones below: tougher monsters, harder hits, more elites, higher prices, one more
monster per room, faster monsters, tougher bosses, darker floors, less max HP... and 10% more
souls per level.
The last choice is remembered (gold frame), shown in the HUD and on the end-of-run screen.
The difficulty window (`DifficultyPanel`, one `DifficultyCard` each) says what changes in plain
words, compared with Normal (`DifficultyCard.effects()`: "Monster health +30%", "Time to dodge
-15%", "+1 monster per room", "Monsters spot you sooner", "Bigger floors (+20%)"...; green helps,
red makes it harder), the souls it pays, and for a locked one what unlocks it.

## Between runs

The game opens on the **title screen** (`src/ui/title/`): play, visit the shrine, see your records.
There is no class to pick: everyone starts the same, and becomes who they want during the run.
The bosses of each act are shown with what a run is; the Daily run button says what it is (same
dungeon for everyone today, the day's start, your score); the records sit on a strip (souls to
spend, runs, victories, deepest floor, difficulty); the Shrine button wears an "Upgrade ready"
badge when souls can buy something. The title-side windows (shrine, difficulty, options) use the
game's RPG skin like the bag (`MenuWindow` in `src/ui/common/`: an `RpgWindow` with its Close
button and a header line within reach, big switches, strips and badges).

**Daily run** (`DailyRun`, the button next to Play): one run a day, the same all day (UTC),
offline. Each floor is generated from the day and its depth, everyone starts with the day's
weapon and relic (shown on the button), on Normal. The day's first attempt is the official one
(counted when it starts: quitting doesn't give another); its score is kept with the best ever and
the days in a row (`Profile.daily_*`); later attempts that day are practice. Score: 1 per kill,
30 per floor, 150 per boss, 1000 for a victory, 1 per 5 gold picked up. The game over screen
shows it.

Every run ends (death or victory) with **souls**: 1 per kill, 5 per floor, 20 per boss, 100 for a
victory. Souls are kept forever (gold only lasts for the run). At the **shrine** (`ShrinePanel`)
they buy the nodes of the **Tree of Souls** (`data/shrine/soul_tree.tres`, `SoulTreeDef`,
`SoulNodeDef`). Four branches, each a fantasy, side by side on one screen (`SoulTreeView`):

| Branch | Nodes, top to bottom ("or": a fork, taking one shuts the other) | Oath at the end |
|---|---|---|
| Body | Vitality; Toughness or Regeneration (heal 5% a level when a floor is won); Provisions; Second Chance or Blood Pact (+20% max Health, heals 30% weaker) | The Colossus |
| Blade | Might; Keen Eye (+crit) or Quick Hands (+attack speed); Armory (pick the starting weapon); Trophy Hunter (elites drop Magic gear) | The Duelist |
| Arcana | Arcane Talent; Pyromancy, Paladin's Oath (new items); Forbidden Library; Satchel of Tomes (start with a tome) or Quick Recharge | The Scholar |
| Fortune | Loaded Dice (rerolls); Swiftness, Exile (banishes); Master Smith, Cartographer (stairs, merchant and forge on the minimap); Haggler (-15% prices) or Full Stalls (+2 items) | The Plunderer |

A node opens once a node above it is bought; some also need a **feat** (an achievement: "?" on the
node, the feat in its card). Tapping a node shows on the right what it does now and next, what
opens it, and Buy. **Reset the tree** gives every soul back (`SoulTreeDef.reset_cost`, 0: free),
so trying another path costs nothing. Each node's effect is an `UpgradeDef` (`data/upgrades/`):
stats, a head start, perk choices, new items, or run rules (kind `RULES`, read by `RunBoons`:
heals, gold, loot, the merchant, the minimap). The old shrine's levels carry over as they are.

**Oaths** (`data/oaths/`, `OathDef`): the end of each branch opens one. Once one is open (or the
Armory), "Before the descent" (`OathPanel`) comes between the difficulty and the run: swear an
oath or none, and pick the starting weapon (Armory). An oath is an "X, but Y" start:

| Oath | Rule |
|---|---|
| The Colossus | the Hammer, +30% max Health, 15% slower |
| The Duelist | the Rapier, +10% crit chance, crits x2.5 (instead of x1.75), -20% max Health |
| The Scholar | the Book, +50% skill damage, attacks 20% slower |
| The Plunderer | +35% gold and better loot, merchant 25% dearer |

Not in the daily run (everyone starts the same). The run keeps its oath in the save (`RunState.oath`).

Locked items (`content_db.tres` > Locked Items) never appear on the floor until unlocked.
The `Profile` autoload keeps souls, upgrades and records in `user://profile.json` (works on phones).

## Bosses

The last floor of each act is a start room and one big arena. The boss sleeps
in the middle; walking in closes the exits with spikes and wakes it up (boss music, health bar
with its portrait). A `BossDef` is a `MonsterDef` plus:

- **phases**: three per boss, full life, two thirds (`hp_ratio` 0.66) and one third (0.33). Each
  phase adds stats, swaps in new attack patterns, shortens the wind-up and the cooldowns
  (`cooldown_multiplier`) and tints the boss; the last one uses fierce versions of its skills
  (`<skill>_fierce`: a second wave, rings shifted into the gaps of the first, more summons).
  Entering a phase, the boss **roars**: untouchable for a moment (`phase_roar_time`) and a
  shockwave throws the hero off. Notches on the boss bar show where the next phases start;
- **no face-tanking**: hit it too many times in a row (`shockwave_after_hits`, fewer in later
  phases) and it answers with the same shockwave (`Combat.shockwave`), which hits as hard as its
  blows (`shockwave_power`, a share of its power): roll through the red ring or stop hitting;
- **cast skills**: rings of projectiles, ground quakes (red circle), summons (`SummonEffect`), dashes;
- **relic_choices**: when it dies the spikes go down, the stairs appear and you pick a relic.

| Floor | Boss | Style |
|---|---|---|
| 3 | King Slime | 360° slams, slime rain, splits into slimes at half HP |
| 6 | Demon Cyclops | heavy club, fire eye beam, quake, calls skeletons, berserk at 20% |
| 9 | Crimson Tengu | fast blade, dashes, feather storms, calls spirits |
| 12 | Gilded Hoarder | crushing leaps, storms of gold coins, calls its thieves (Gold Racoons) when half dead |

## Animations

Animations are **frame by frame**, like in Zelda-style RPGs: every character has a drawing for each
direction (down, up, left, right) and each pose, and the weapon is drawn *in the hand* for each
attack frame. Nothing is rotated or moved by code, so the weapon never floats or goes through the body.

Every actor (player and monsters) has a **rig**: `src/entities/rig/actor_rig.tscn`.

```
Rig                  at the actor's feet
└── Visual           flash shader, scaled 2x (units = art pixels)
    └── Squash       squash & stretch on hits
        ├── Body       AnimatedSprite2D: the character (SpriteFrames from the data)
        ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
        ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
        └── Weapon     AnimatedSprite2D: the weapon in hand, same animation and frame as Body
```

The animations live in `SpriteFrames` resources in `data/visuals/`, named `<pose>_<direction>`:

| Animation | When |
|---|---|
| `idle_*`, `walk_*` | standing, moving |
| `attack_*` | attacking (sped up to fit the weapon's attack speed) |
| `dash_*` | rolling |
| `hit_*` | taking a hit |
| `dead` | dying |
| `cast`, `intro` | bosses: telegraphed skill, waking up |

A missing animation falls back to a simpler one (`attack_left` > `attack`), and creatures with no
attack pose lunge instead. Monsters freeze in their attack pose and shake during their wind-up,
so you can see the strike coming.

**Weapons**: each `WeaponDef` has `attack_frames` (a SpriteFrames with `attack_down/up/left/right`).
The sheets in `assets/weapons/attack/` are 64x64 cells, one column per direction, one row per frame,
drawn so the handle sits in the hero's hand on that frame. The weapon is drawn behind the body when
facing up. `attack_fx` is the slash effect played in front of the actor.

**Armor (paper doll)**: what you wear shows on the hero. Each `ArmorDef` has `wear_frames`, a layer
with the same animations as the hero, and a `wear_color`. The layers copy the body's animation and
frame every frame, so they can't drift. The layer sheets (`assets/characters/hero/wear/`) are grayscale
and were made from the hero's own frames (hood and outfit pixels), so one style serves many armors:

| Style (`data/visuals/wear/`) | Slot | Used by |
|---|---|---|
| hood | head | Leather Cap |
| helm | head | Iron Helm |
| tunic | body | Leather Armor, Shadow Cloak |
| mail | body | Chain Mail |
| plate | body | Plate Armor |

A new armor = pick a style and a color in the inspector.

To tweak an animation, open a file in `data/visuals/` and use the SpriteFrames panel
(add frames, change the speed, toggle loop). The actor scripts never touch animations directly:
they call `rig.play_attack()`, `rig.play_hurt()`, etc.

## Adding content

| To add... | Do this |
|---|---|
| A monster | Duplicate a file in `data/monsters/`, edit it, add it to an act's Monsters (`data/dungeon/acts/`) |
| An act | New `ActDef` in `data/dungeon/acts/` (biomes, monsters, boss), add it to `dungeon_config.tres` > Acts |
| A weapon / armor / consumable | Duplicate a file in `data/items/...`, edit, add it to `content_db.tres` > Items |
| A loot drop | Edit the monster's Loot table (items don't need to be in the DB to drop) |
| A player skill | Create a `SkillDef` in `data/skills/player/`, put it in a weapon's Skills (max 2) or in a tome |
| A skill tome | New `SkillTomeDef` in `data/items/tomes/` pointing to a skill, add it to `content_db.tres` > Items |
| A new kind of effect | New script in `src/definitions/effects/` extending `Effect`, override `apply()` |
| A new monster ability | A `MonsterTrait` subclass in `src/definitions/monster_traits/`, add it to a monster's Traits |
| A new monster AI state | New state script in `src/ai/states/`, add a node for it in `monster.tscn` |
| A perk | New `PerkDef` in `data/perks/`, add it to `content_db.tres` > Perks |
| A new kind of perk | New script in `src/definitions/passives/` extending `Passive`, override the hooks you need |
| A boss | New `BossDef` in `data/monsters/bosses/`, set it as an act's Boss |
| A shrine upgrade | New `UpgradeDef` in `data/upgrades/`, add it to `content_db.tres` > Upgrades |
| An achievement | New `AchievementDef` in `data/achievements/` (stat, target, souls), add it to `content_db.tres` > Achievements |
| An ascension level | New `AscensionDef` in `data/ascension/`, add it at the end of `content_db.tres` > Ascensions |
| A difficulty | New `DifficultyDef` in `data/difficulties/`, add it to `content_db.tres` > Difficulties |
| A prop | New `PropDef` in `data/props/` (sprite, hits, loot, explosion, light), add it to `content_db.tres` > Props |
| A trap or hazard | New `TrapDef` / `ArrowTrapDef` / `PitDef` / `QuicksandDef` / `HeatSourceDef` / `DarkRoomDef` in `data/hazards/`, add it to an act's Hazards |
| A new kind of hazard | New script in `src/definitions/hazards/` extending `HazardDef`, override `place()` |
| An elite affix | New `EliteAffixDef` in `data/elites/` (name, color, a perk), add it to `content_db.tres` > Elite Affixes |
| A chest | New `ChestDef` in `data/chests/`, set it in `dungeon_config.tres` > Chests |
| A special floor | New `FloorEventDef` in `data/floor_events/`, add it to `content_db.tres` > Floor Events |
| A biome | New `BiomeDef` in `data/biomes/` (a theme, grounds, scenes, decor, lights), add it to an act's Biomes |
| A scene | New `SceneDef` in `data/biomes/scenes/`: write its plan (rows of symbols), its keys (what each symbol is), its anchor; add it to a biome's Scenes |
| Furniture | New `PropDef` in `data/props/furniture/` (an atlas region of a tileset in `assets/tiles/`, a footprint), used in scenes |
| A curse | New `CurseDef` in `data/curses/` (temperature, campfires or springs, darkness, look, lore), add it to `content_db.tres` > Curses |
| Another boss for an act | New `BossDef`, add it to the act's Other Bosses |
| An encounter | New `EncounterDef` in `data/encounters/` (choices, costs, outcomes), add it to `content_db.tres` > Encounters |
| An item affix | New `ItemAffixDef` in `data/affixes/` (prefix or suffix, slots, stats, on-hit or passives + description), add it to `content_db.tres` > Item Affixes |
| Story texts | Edit `data/story/story.tres` (intro pages, death lines...); an act's line is its `ActDef` > Lore |
| A tutorial hint | Add a `HintDef` to `data/tutorial/tutorial.tres` > Hints (a cue from `Tutorial.CUES`, a text, a HUD control to point at) |

Each piece of content has an **icon** (any `Texture2D`) and an **icon tint** to recolor it.
Monsters and the player also have `frames` (their SpriteFrames in `data/visuals/`): a new monster
can reuse an existing one, or you can make a new SpriteFrames from a sheet in `assets/characters/`.
Floor looks (tiles, decor, tint, darkness, music) are `DungeonTheme` files in `data/dungeon/themes/`, one per biome.
How many lanterns, prop clusters, hazard groups and chests a floor gets, how often ambushes and
elites happen, is in `dungeon_config.tres`.

`min_depth` and `spawn_weight` control where and how often something appears.
A `spawn_weight` of 0 means it never spawns on its own (starting gear, loot-only items, monster weapons).

## Controls

Every scrolling list (codex, shrine, bag, shop) scrolls by dragging a finger over it, from
anywhere in it, cards and buttons included, with a bit of momentum (`TouchScroll`, added to each
`ScrollContainer` by the `TouchScrolling` autoload); a drag never presses a button, a tap does.


| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim, hold) | Big red button | J / Space | X |
| Skills 1-4 | Small round buttons | K L O P or 1 2 3 4 | A B Y RB |
| Belt (potions, bombs, scrolls) | The 3 small buttons left of the skills | Q / H, 5, 6 | LB (slot 1) |
| Pause | II button / phone back button | Escape | - |
| Choose a perk | Tap a card | Arrows + Enter | D-pad + A |
| Inventory | Bag button | I / Tab | Back |

## Debug tools

In debug builds only (running from the Godot editor, on the phone too, or a debug export), a
**DBG** button next to pause (or F1) opens the `DebugPanel` (the game pauses):
- **Floor**: pick a depth and go there, next floor, rebuild the floor, next boss floor, teleport
  next to the stairs, break the stairs' seal, reveal the map. Jumped-to floors are plain unless you choose:
- **Curse** (Frostbound, Ashen Breath, Lanternless) or **floor event**: rebuilds the floor with it
  (`World.forced_curse` / `forced_event`), its card included.
- **Biome**: goes to its act and builds a floor of it (`World.forced_biome`).
- **Hero**: god mode (nothing hurts), full heal, +500 gold, level up, an Epic weapon, every
  consumable, freezing / burning / normal temperature.
- **Monsters**: pick any monster or boss and spawn it (or an elite one), kill all, put all asleep.

Release exports have no button and no panel (`DebugPanel.is_available()`).

## Tests

From the project root (desktop Godot):

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn
godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title
```

The suites (`tests/suites/`, each a `TestSuite`):
- **unit**: the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
  inventory, equipment, perks, bosses, the profile. No game running: fast.
- **title**: the title screen and its panels.
- **game**: a bot plays the real game (kills, level ups and perk choices, stairs, death and
  restart, saving and resuming), then on that same game: **combat** (projectiles, perks, skills,
  monsters and their traits, difficulty, weapons), **floor** (props, hazards, chests, ambushes,
  encounters, the merchant, loot, curses, biomes, act cards, the belt) and **boss** (a full boss fight
  with its phases and relic, then winning the run).
- **tutorial**: the hints' data, the first steps played with the real controls, the hints that come
  up once, menus, the options and the profile.

The exit code is the number of failures.

- **balance** (opt-in: only with `--only=balance`): the balance tools' quick runs against the
  targets of `data/balance/targets.tres`. Some of its checks fail on purpose today (the balance
  work to do): they are printed as `FAIL (KNOWN ...)`.

## Balance tools

`tools/balance/` measures the whole game's balance with numbers: every monster and rank at every
depth and difficulty, every boss (and boss rank), every weapon, the marginal value of every perk,
relic, family, rune, affix, shrine level and encounter, the economy, and stacks that multiply. The
fights are real (the Game scene, headless, a bot at the controls); the content is walked, never
listed by hand.

```
godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=all --jobs=2 --out=<dir>
godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=model   # seconds
```

Modes: `model`, `arena`, `pack`, `marginal`, `economy`, `compound`, `all` (`--quick` for a small
subset, `--difficulty=normal,hard,nightmare+5`, `--build=`, `--boss=`, `--bot=`, `--seed=`). Each
run writes `report.md` (numbered FLAGS first, then numbered tables) and `data.json`. Builds live in
`data/balance/builds/`, goals in `data/balance/targets.tres`. How to read and extend it, and the
balance log: [docs/balance.md](docs/balance.md).

## Art and credits

Art, sound effects and music: **[Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack)**
by Pixel-boy and AAA, CC0 (public domain). License in `assets/LICENSE_NinjaAdventure.txt`.
Footstep sounds: Kenney Impact Sounds, CC0 ([kenney.nl](https://kenney.nl)).
Bag and forge skin (`assets/ui/rpg/`): Kenney **Pixel UI Pack** and **Fantasy UI Borders**, CC0
(licenses next to them); the dark insets and slots are redrawn in the same palette.
Ambience sounds (`assets/audio/ambience/`) are filtered versions of those sounds; the heartbeat is synthesized.
The weapon attack sheets were composed from the pack's weapon sprites to match the hero's attack frames.

Pixel art is drawn at 2x in the world, with nearest filtering
(Project Settings > Rendering > Textures > Default Texture Filter).

## Conventions

- Static typing everywhere, `class_name` for reusable types.
- `snake_case` files and functions, `PascalCase` classes, `_private` members.
- One scene per entity, its script next to it.
- One monster scene for every monster type: the sprite, weapon and sounds come from the data,
  the rig animates whatever it is given.
