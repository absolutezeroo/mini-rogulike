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
  audio/               Sound effects (sfx/), music (a track per place: docs/design/presentation.md "Music"), ambience beds and jingles
  shaders/             Rig (hit flash + death dissolve), screen look, damage vignette
  theme/               main_theme.tres: pixel UI theme used by every Control
data/                Game content as .tres resources (no code)
  content_db.tres      Index of everything that can spawn
  player/              Starting stats, kit, skills, leveling
  dungeon/             The run (acts/), floor size, difficulty curve, floor looks (themes/)
  biomes/              The worlds a floor can be (one per file) and their hand-made scenes (scenes/), room
                       shapes (shapes/), signature rooms (set_pieces/), ceilings (ceilings/), pools (pools/)
  visuals/             SpriteFrames: hero.tres, monsters/, weapons/ (the animations themselves)
  audio/               Sounds as AudioStreamRandomizer (variations + pitch), sound_bank.tres, sound_mix.tres
  monsters/            One file per monster type, bosses in bosses/
  perks/               Level-up perks (common/) and boss relics (relics/)
  upgrades/            Shrine upgrades (bought with souls between runs)
  difficulties/        Pilgrim, Keeper, Martyr, Nightmare
  story/               story.tres: the game's name, the intro, victory and death texts; narrative.tres (how the
                       story is told), chronicles/ (each warden's), fragments/, fragment_looks/, conditions/
                       (shared reveal gates), cinematics/ (the boss meetings' steps); finale.tres (the bottom
                       of the Well) and its endings (endings/); dialogue/ (who speaks and what: the
                       Vigil-Keeper's tales, advice and shrine words, the keepers' lines; speakers/)
  props/               Breakable props and the lantern
  hazards/             Traps, arrow traps, holes, crumbling floor, quicksand and mud
  chests/              Chests (some trapped) and the big chest of ambushes
  elites/              Elite affixes (Swift, Vampiric, Bursting...)
  affixes/             Item affixes for Magic, Rare and Epic equipment (Sharp, of the Bear...)
  shop/                The merchant (stock, prices, look)
  encounters/          Spring of the Drowned, Blood Altar, Grinning Spirit, Keeper's Statue
  secrets/             What secret rooms hold (SecretRewardDef), the hidden floor (HiddenFloorDef)
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  items/bag_categories.tres  The bag's compartments (tabs): which items go in each, their places
  items/tomes/         Skill tomes (teach a spell)
  skills/              Player, monster and boss skills
  leaderboards/        The online leaderboards (leaderboards.tres: LeaderboardsConfig) and their boards
                       (boards/: LeaderboardDef), see docs/online.md
  online/              privacy.tres (PrivacyDef: the contact placeholders, the consent rules, the short
                       policy), telemetry.tres (TelemetryDef: the statistics' events and fields),
                       world_stats.tres (WorldStatsDef: the world counters, the Well's Toll),
                       remote_config.tres (RemoteConfigDef: the remote settings' allow-list, RemoteKeyDef)
                       feedback.tres (FeedbackDef: the feedback form's categories and limits)
  credits/             credits.tres (CreditsDef: who made what, licenses and their files)
  ui/                  Loading tips, input_prompts.tres (the controls as the player is told about them: the
                       Controls page, the keys prompts show, the gamepad families' button names)
src/
  autoload/            Events (signal bus), Sfx (sound player), HitStop (impact freeze), Profile (save), Settings (options),
                       InputDevice (the device in use), MenuNav (menus with keys and gamepads), PixelGrid (the canvas's scale), SoftKeyboard (typing on a phone),
                       Leaderboards (the online leaderboards), Privacy (the player's privacy choices),
                       Telemetry (the gameplay statistics, with consent), WorldStats (the world counters),
                       RemoteConfig (the remote settings: Talo's game config, checked against the allow-list),
                       Feedback (the player's feedback messages and their queue)
  online/              The online pieces: RunSummary (a run that ended), PlayerName (the pseudonym's
                       filter), BoardBackend (offline) > TaloBackend (Talo's REST API), RunTelemetry (what
                       the statistics learn of a run), RemoteTuning (what the remote settings change in a run, saved with it),
                       FeedbackInfo (the game's details a feedback message can carry)
  core/                Small shared helpers (physics layers, weighted random, SafeFile, NumberText)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    passives/            Building blocks for perks (on hit, on kill, on dash...)
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
    hazards/             HazardDef > TrapDef > ArrowTrapDef, PitDef, QuicksandDef, HeatSourceDef, DarkRoomDef
    monster_traits/      MonsterTrait > GuardTrait, ThiefTrait, DeathBurstTrait, DeathSpawnTrait, PerkTrait
    biomes/              BiomeDef, GroundLayerDef, DecorRuleDef, SceneDef (hand-made scenes), SceneKey
    input/               InputPromptsDef, ActionPromptDef, PadGlyphsDef (what a control is called on each device),
                         DeviceText (a sentence for touch and one for keys and gamepads)
    story/               The story: ProgressCondition (conditions/; conditions on the run that ended:
                         conditions/run/, RunCondition), DeedCondition (deeds/), chronicles, chapters, waking
                         lines, fragments, NarrativeDef, CinematicDef and CinematicStep (cinematic/)
    dialogue/            SpeakerDef, DialogueDef, DialogueLineDef (who speaks, what may be said, when)
  dungeon/             Map data, generator (its rooms' shapes: RoomPlan; its secret rooms: SecretRoomPlan), drawing
  world/               World (owns the current floor), FloorRules (how hard and rewarding it is),
                       NavGrid (pathfinding), FogOfWar (what the hero has seen), WallBuilder,
                       FloorPopulator, FloorLedger (what the hero used up of what the seed laid, for the
                       save), FragmentPlacer, BossArena (and its Storyteller), AmbushRoom, RoomGates, PitLayer, SecretRoom; PocketWorld
                       (a World built beside the floor for a while) > ThresholdWorld (the limbo of a second
                       life's trial), AbyssWorld (the Deeps a fall takes the hero to);
                       dressing/ (FloorDresser: a floor in its biome, RoomSpace); RoomFeatures (the shaped
                       rooms' chasms, pools and pillars); ceiling/ (CeilingLayer: what hangs over the rooms)
  entities/            Actor (shared base), Player, Monster, Projectile, ItemPickup, Stairs, Prop, Trap, Fragment,
                       hazards/ (Chest, CrumblingFloor, Quicksand, HeatSource, DarkRoom, FloorPatch),
                       ground/ (GroundLayer: a biome's ground, drawn by a shader)
  components/          Inventory, Equipment, SkillSet, PerkSet, StatusSet (burn...)
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack, Cast)
  vfx/                 Particles (particles/), sprite-sheet FX, emotes, afterimages, damage numbers; Vfx helpers
  ui/                  Title screen and shrine, story, act cards, HUD and minimap, touch controls, the action
                       bar and mouse controls, prompts (Prompts, PromptGlyph), inventory (its tabs, BagTab, and
                       actions/: BagAction), perk choice, pause
                       menu, options (and its Controls page), end of run
  game/                Game: main scene, floor flow, pauses; RunState (the run: depth, kills, bosses,
                       difficulty), RunRecords (stats, bestiary, achievements, history), OfferQueue
                       (perk choices waiting), GameMenus (the panels), ShrineUpgrades, RunSave (on disk),
                       Threshold (a second life's trial: the floor out of the tree, the hero in a limbo),
                       Abyss (the Deeps under a floor's holes), SubWorld (the hero's stay in a pocket world:
                       his world out of the tree as it is, back as it was; stays nest),
                       HiddenPassage (the way to the hidden floor); story/: Narrative (the story's progress
                       and answers), BossMeeting (a warden met: its cinematic), CinematicDirector (plays a
                       CinematicDef's steps), StoryBeat (what one telling holds), Dialogues (what a speaker
                       says now), RunFacts (what is known of a run as it ends)
tests/               Headless tests: run_tests (the runner), suites/ (unit, title, game, combat, floor, boss,
                     balance: opt-in), support/ (TestSuite: checks, scene helpers, the bot; FakeBoardBackend:
                     a leaderboard server in memory)
online/              talo.cfg.example: the form of talo.cfg, the leaderboards' access key (never committed:
                     docs/online.md)
locale/              strings.csv: every player text, English (the key) and French (see Languages)
tools/i18n/          extract.py (keeps the CSV up to date), add_glyphs.py (French glyphs for the font)
tools/levels/        level_art.py (the deep water, paper boats and the ceilings' atlases, drawn in the pack's
                     palette), level_shots (screenshots of shapes, signature rooms, ceilings, the big map)
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
    (Pilgrim x0.85, Keeper x1, Martyr x1.2, Nightmare x1.4); chasing, they see 1.6x further.
  - **Sleep**: what isn't seen isn't run. A few times a second the World lets monsters off screen
    (beyond a 256 px margin) and out of reach of the hero sleep: no AI, no movement, no animation
    (`Monster.set_awake()`, `World.awake_monsters`). Hunting monsters and bosses stay awake; a hit
    wakes a sleeper. On a crowded Nightmare floor, monsters cost about a quarter of what they did.
- **Game** offers the perk choices (pausing the game; a level up's only when the player taps the
  perk button, `open_offers()`) and reacts to boss fights through `Events`. Its `Interactor` gives
  the HUD's Interact button to the nearest `Interactable` (merchant, forge, encounter, pact): nothing
  opens by walking up to it.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path;
  the mouse's clicks in a fight do the same (`MouseControls`).
- **Devices** (design/interface.md "Devices"): `InputDevice` says which device is in use; the HUD
  swaps its touch controls for the `ActionBar` (which mirrors them) on keys and gamepads; `Prompts`
  turns an action into the key or button to show (`PromptGlyph` draws it as a cap) from the input
  map and `data/ui/input_prompts.tres` (`InputPromptsDef`: the controls told about, the gamepad
  families' names, the dead zone), and picks a sentence's version for the device (`DeviceText`,
  `HintDef.button_text`, `Prompts.pick()`); `MenuNav` lets keys and gamepads use every window.

- **The story** (design/presentation.md "Boss stories"): the content is data (`data/story/`, a
  `BossChronicleDef` on each `BossDef`), gated by `ProgressCondition`s. `Narrative` (static, like
  `Bestiary`) is the only code writing the story's part of the Profile and answers what is open,
  told, found and done, and what a meeting tells (`plan()`). When the hero walks into an arena,
  `BossArena.start()` asks the World's `Storyteller` (the Game's `BossMeeting`) and waits for it:
  the Game pauses, a `CinematicDirector` runs the `CinematicDef`'s steps on a `CinematicView`
  (its own CanvasLayer, 7), then the boss wakes. `FragmentPlacer` lays fragments while a floor is
  populated; reading one goes through the Interactor and `Events.fragment_requested`. Deeds are
  checked by the `HuntTracker` at a warden's death; what the run did is `RunState.marks` (set by
  `RunRecords` from the Events).
- **The dialogue** (design/presentation.md "The Vigil-Keeper and the keepers"): `DialogueDef`s of
  `DialogueLineDef`s, gated by the same conditions; `Dialogues` picks a line and keeps it said
  through `Narrative` (`Profile.lines_told`). When the hero falls, the Game reads `RunFacts` at once
  (`Game.end_facts`: the killer and the cause come from `Player.killer_def` and
  `Actor.death_cause`, itself from the killing `HitInfo.cause`); the end screen asks
  `NarrativeDef.tell_end()` and shows it in a `DialogueBox` (`src/ui/dialogue/`). The title screen
  puts the shrine's speaker by the Well (`ShrineKeeper`) and opens a `DialogueScreen`; the shop,
  forge and encounter panels show their def's `dialogue` line where their greeting was.

## Autoloads

Few, each with one job (`project.godot` > Autoload):

| Autoload | Script | Job |
|---|---|---|
| `Events` | `src/autoload/events.gd` | Signal bus for notifications (screen shake, camera kick, boss fight...). Emit and listen; never use it to give orders |
| `Sfx` | `src/autoload/sfx.gd` | Plays combat, world (positional) and UI sounds from `data/audio/sound_bank.tres`, each on its bus, mixed by `data/audio/sound_mix.tres`; the music, crossfaded (which track plays where: `Soundtrack`) |
| `HitStop` | `src/autoload/hit_stop.gd` | Impact freeze and slow motion |
| `Profile` | `src/autoload/profile.gd` | What lasts between runs: souls, Tree of Souls, records, bestiary, quests (`user://profile.json`) |
| `Settings` | `src/autoload/settings.gd` | Options and language (`user://settings.cfg`) |
| `TouchScrolling` | `src/autoload/touch_scrolling.gd` | Adds finger scrolling to every `ScrollContainer` |
| `Loader` | `src/autoload/scene_loader.gd` | Loading screen between the title and the game |
| `SoftKeyboard` | `src/autoload/soft_keyboard.gd` | While a phone's keyboard is up over a text field, shows the field in a readable bar in the strip the keyboard leaves; tells `PixelGrid` a keyboard's resize so the UI keeps its scale (design/interface.md, Screens) |
| `PixelGrid` | `src/autoload/pixel_grid.gd` | Picks the canvas's scale (whole steps of 0.5, the interface size option; the camera keeps the framing: `world_zoom()`) and shifts the screen a quarter of a pixel so text and pixel art at half-pixel spots draw whole (design/interface.md, Text and Screens) |
| `InputDevice` | `src/autoload/input_device.gd` | The device in use (touch, keyboard and mouse, gamepad and its family) from the last real input; `changed` for the HUD, prompts and menus |
| `Leaderboards` | `src/autoload/leaderboards.gd` | The online leaderboards (docs/online.md): queues the scores of runs that end (`Events.run_ended`), sends them through its backend (Talo, or offline without a key), reads the boards for the page. Its own file, `user://leaderboards.json` |
| `MenuNav` | `src/autoload/menu_nav.gd` | Menus with keys and gamepads: the menu on top (group "menu") holds the focus, directions with wrap, tabs, the focus frame |

Tests empty `Profile.save_path` and `Settings.path`, so they never touch a player's files, and give
`Leaderboards` an offline backend and no file (`use_for_tests()`): never the network.

## Rendering

- **Drawing the floor**: `DungeonView` draws the map in 8x8-cell chunks, each its own canvas item,
  so the renderer skips the ones off screen; inside a chunk, tiles go texture by texture to batch.
  About 90 draw calls whatever the floor's size (it was ~1500 on a big floor).
- **The ceiling** (`CeilingLayer`, design/dungeon.md "Ceilings") is drawn the same way: chunks of
  12 cells, each one canvas item over its biome's one atlas, plus its shadows' chunks; per frame
  only the bodies' places go to its shader. Measured on Nightmare floors (104 x 104, 56-127
  pieces): 1-3 more draw calls, render time within llvmpipe's noise.
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
