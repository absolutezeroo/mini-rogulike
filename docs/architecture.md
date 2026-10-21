# Architecture

How the code is laid out and how the pieces talk to each other. Code rules are in
[conventions.md](conventions.md); what each system does for the player is in [design/](design/).

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
locale/              strings.csv: every player text, English (the key) and French (see Languages)
tools/i18n/          extract.py (keeps the CSV up to date), add_glyphs.py (French glyphs for the font)
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
- **Game** offers the perk choices (pausing the game) and reacts to boss fights through `Events`.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path.

## Autoloads

Few, each with one job (`project.godot` > Autoload):

| Autoload | Script | Job |
|---|---|---|
| `Events` | `src/autoload/events.gd` | Signal bus for notifications (screen shake, camera kick, boss fight...). Emit and listen; never use it to give orders |
| `Sfx` | `src/autoload/sfx.gd` | Plays world (positional) and UI sounds from `data/audio/sound_bank.tres` |
| `HitStop` | `src/autoload/hit_stop.gd` | Impact freeze and slow motion |
| `Profile` | `src/autoload/profile.gd` | What lasts between runs: souls, Tree of Souls, records, bestiary, quests (`user://profile.json`) |
| `Settings` | `src/autoload/settings.gd` | Options and language (`user://settings.cfg`) |
| `TouchScrolling` | `src/autoload/touch_scrolling.gd` | Adds finger scrolling to every `ScrollContainer` |
| `Loader` | `src/autoload/scene_loader.gd` | Loading screen between the title and the game |

Tests empty `Profile.save_path` and `Settings.path`, so they never touch a player's files.

## Rendering

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
