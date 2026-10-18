# Mini Roguelike

Real-time action roguelike for Godot 4.7 (GDScript, Compatibility renderer).
Procedural floors lit by torches and lanterns, traps, breakable crates and explosive kegs,
monsters with telegraphed attacks, a boss every 3 floors, melee and ranged weapons,
armor you can see on the hero, consumables, loot, XP, a perk to choose at every level up, and
skills that come from what you hold and what you learn: play a mage, a warrior, a paladin, or a mix. Plays with touch controls,
keyboard or gamepad.

## Project layout

```
assets/              Art, audio, fonts and the UI theme (Ninja Adventure pack)
  characters/          Hero and monster sprite sheets (4 directions, frame by frame), bosses/
  weapons/             Weapon icons + attack/ sheets (the weapon in hand, per direction and frame)
  fx/                  Sprite-sheet effects: slashes, claws, explosion, smoke, magic, flames, light.png
  props/               Crates, vases, barrels, powder kegs, lanterns, trap pieces
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
  dungeon/             The run (acts/), floor size, difficulty curve, floor themes (themes/)
  visuals/             SpriteFrames: hero.tres, monsters/, weapons/ (the animations themselves)
  audio/               Sounds as AudioStreamRandomizer (variations + pitch) and sound_bank.tres
  monsters/            One file per monster type, bosses in bosses/
  perks/               Level-up perks (common/) and boss relics (relics/)
  props/               Breakable props and the lantern
  traps/               Spike traps, pressure plates, flame vents
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  items/tomes/         Skill tomes (teach a spell)
  skills/              Player, monster and boss skills
src/
  autoload/            Events (signal bus), Sfx (sound player), HitStop (impact freeze)
  core/                Small shared helpers (physics layers, weighted random)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    passives/            Building blocks for perks (on hit, on kill, on dash...)
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
  dungeon/             Map data, generator, drawing
  world/               World (owns the current floor), FloorPopulator, BossArena
  entities/            Actor (shared base), Player, Monster, Projectile, ItemPickup, Stairs, Prop, Trap
  components/          Inventory, Equipment, SkillSet, PerkSet, StatusSet (burn...)
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack, Cast)
  vfx/                 Particles (particles/), sprite-sheet FX, emotes, afterimages, damage numbers; Vfx helpers
  ui/                  HUD, touch controls, inventory, perk choice, game over
  game/                Game: main scene, run and floor flow
tests/               Headless test suite with a bot that plays the game
```

**Rule of thumb:** `data/` says *what* exists, `src/definitions/` says *what a thing can have*,
the rest of `src/` says *how it behaves*. Balancing never requires touching code.

## How things fit together

- **Game** creates the Player, asks **World** to build each floor and handles pause and game over.
- **World** generates a `DungeonMap`, builds wall collisions and pathfinding, then lets
  `FloorPopulator` spawn monsters and items picked from `ContentDB` by depth.
- **Actor** (base of Player and Monster) handles stats, HP, attacks, knockback, dashes and hit feedback.
  Final stats = base stats + equipment bonuses + timed buffs.
- **Weapons** are shared: a monster attacks with a `WeaponDef` exactly like the player.
- **Skills and consumables** are both lists of `Effect` resources
  (damage area, projectile, heal, dash, buff). New effect = new class extending `Effect`.
- **Monsters** are driven by a `StateMachine`: Idle (wander) > Chase (path or straight line, use skills)
  > Attack (telegraphed wind-up, strike, recovery). Skills with a `cast_time` go through Cast
  (glow, red circle, cast animation) so the player can dodge them.
- **Game** offers the perk choices (pausing the game) and reacts to boss fights through `Events`.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path.

## Game feel

- **VFX**: hand-drawn sprite-sheet effects (slashes, claws, explosions, smoke, magic circles,
  "!" emote when a monster spots you) plus pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector), dash afterimages, animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **SFX**: the `Sfx` autoload plays world sounds (positional) and UI sounds. Weapons have attack and hit
  sounds, monsters hurt and death sounds, skills and consumables a use sound; everything else comes
  from `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Buses: Master > SFX, UI, Music (`default_bus_layout.tres`). Each floor theme has its own music.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: each floor theme has an `ambient` darkness (a `CanvasModulate`); the hero's flickering torch,
  room lanterns, the hero's shots and fireballs, explosions and magic circles light it up (2D lights).
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit and
  dissolves monsters pixel by pixel when they die; lights fall off in flat, dithered steps
  (`assets/fx/light.png`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.

## Dungeon

- **Walls** are cliffs drawn from a 16x16 tileset (`DungeonView`): plateau edges, inner corners,
  cliff faces. The generator smooths every floor so only shapes the tiles can draw remain
  (no wall one cell thick, no walls touching by a corner).
- **Props** (`data/props/`): crates, vases and barrels break under any attack and may drop loot;
  **powder kegs** blink then explode, hurting everyone (you too) and setting off other kegs.
  Explosions you trigger give you the XP of what they kill. Props block movement, sight and shots.
- **Traps** (`data/traps/`) hurt everyone standing on them, monsters included:
  rows of **spikes** firing in a wave, **pressure plates** that strike when stepped on,
  **flame vents** that also set you on fire. They always warn before they strike.

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
| Warrior | Katana, Sai, Lance, Battle Axe, War Hammer, Pickaxe | Whirlwind, Iaido Dash, Flurry, Shadow Step, Piercing Thrust, Spear Throw, Cleave, Ground Slam, Fissure, Rock Spike |
| Mage | Spark Wand, Frost Staff, Ember Tome | Spark Nova, Arcane Bolt, Frost Nova (slow), Ice Shards (slow), Fireball, Fire Wave (burn) |
| Paladin | Templar Sword | Smite (damage + heal), Holy Shield (DEF + heal) |

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

A `PerkDef` (in `data/perks/`) is stat bonuses + a list of `Passive`s, both multiplied by its level:

| Passive | Hook | Used by |
|---|---|---|
| `HealOnKillPassive` | on kill | Vampirism |
| `ThornsPassive` | on damaged | Thorns |
| `BurnOnHitPassive` | on hit | Ignite (burn status) |
| `CritShockwavePassive` | on hit (crits) | Thunderclap |
| `DashShockwavePassive` | on dash | Shock Roll |
| `LootOnKillPassive` | on kill | Fortune |
| `ExecutePassive` | before a hit | Executioner |
| `ExtraProjectilesPassive` | every volley | Multishot |
| `CheatDeathPassive` | before dying | Phoenix Feather |

Damage caused by a passive (burn, thorns, shockwaves) is a *secondary* hit: it never triggers
other on-hit perks, so effects can't chain forever. Perks are stored per actor in a `PerkSet`,
so monsters could use them too (elites, later).

## The run

A run is **3 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its look, its own monsters and a boss on its last floor. Beating the last boss **wins the run**;
you can then keep going in endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. Mossy Caves | 1-3 | Cave Mouse, Blue Bat, Slime, Red Spider, Spore Cap, Viper, Acid Larva, Burrower, Giant Slime | King Slime |
| II. Haunted Crypt | 4-6 | Skeleton, Dark Sorcerer, Spirit, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull | Demon Cyclops |
| III. Burning Ruins | 7-9 | Fire Shaman, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus | Crimson Tengu |

Monsters are data (`MonsterDef`): stats, a weapon (its `on_hit` status poisons, burns or slows),
skills (telegraphed casts: spore clouds, dives, charges, ink rings...), and what happens when they
die: a **death burst** (a flame spirit explodes, a frost skull freezes everything around, after a
short warning) or **death spawns** (a giant slime splits in two).

## Bosses

The last floor of each act is a start room and one big arena. The boss sleeps
in the middle; walking in closes the exits with spikes and wakes it up (boss music, health bar
with its portrait). A `BossDef` is a `MonsterDef` plus:

- **phases**: at a given HP ratio the boss gets stat bonuses, new skills, a shorter wind-up and a tint;
- **cast skills**: rings of projectiles, ground quakes (red circle), summons (`SummonEffect`), dashes;
- **relic_choices**: when it dies the spikes go down, the stairs appear and you pick a relic.

| Floor | Boss | Style |
|---|---|---|
| 3 | King Slime | 360° slams, slime rain, splits into slimes at half HP |
| 6 | Demon Cyclops | heavy club, fire eye beam, quake, calls skeletons, berserk at 20% |
| 9 | Crimson Tengu | fast blade, dashes, feather storms, calls spirits |

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
| An act | New `ActDef` in `data/dungeon/acts/` (theme, monsters, boss), add it to `dungeon_config.tres` > Acts |
| A weapon / armor / consumable | Duplicate a file in `data/items/...`, edit, add it to `content_db.tres` > Items |
| A loot drop | Edit the monster's Loot table (items don't need to be in the DB to drop) |
| A player skill | Create a `SkillDef` in `data/skills/player/`, put it in a weapon's Skills (max 2) or in a tome |
| A skill tome | New `SkillTomeDef` in `data/items/tomes/` pointing to a skill, add it to `content_db.tres` > Items |
| A new kind of effect | New script in `src/definitions/effects/` extending `Effect`, override `apply()` |
| A new monster behaviour | New state script in `src/ai/states/`, add a node for it in `monster.tscn` |
| A perk | New `PerkDef` in `data/perks/`, add it to `content_db.tres` > Perks |
| A new kind of perk | New script in `src/definitions/passives/` extending `Passive`, override the hooks you need |
| A boss | New `BossDef` in `data/monsters/bosses/`, add it to `dungeon_config.tres` > Bosses |
| A prop | New `PropDef` in `data/props/` (sprite, hits, loot, explosion, light), add it to `content_db.tres` > Props |
| A trap | New `TrapDef` in `data/traps/` (trigger, art, timing, damage), add it to `content_db.tres` > Traps |

Each piece of content has an **icon** (any `Texture2D`) and an **icon tint** to recolor it.
Monsters and the player also have `frames` (their SpriteFrames in `data/visuals/`): a new monster
can reuse an existing one, or you can make a new SpriteFrames from a sheet in `assets/characters/`.
Floor looks (tiles, decor, tint, darkness, music) are `DungeonTheme` files in `data/dungeon/themes/`.
How many lanterns, prop clusters and trap groups a floor gets is in `dungeon_config.tres`.

`min_depth` and `spawn_weight` control where and how often something appears.
A `spawn_weight` of 0 means it never spawns on its own (starting gear, loot-only items, monster weapons).

## Controls

| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim, hold) | Big red button | J / Space | X |
| Skills 1-4 | Small round buttons | K L O P or 1 2 3 4 | A B Y RB |
| Quick potion | Potion button | Q / H | LB |
| Choose a perk | Tap a card | Arrows + Enter | D-pad + A |
| Inventory | Bag button | I / Tab | Back |

## Tests

From the project root (desktop Godot):

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn
```

Checks the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
inventory, equipment, weapon skills and tomes, every kind of perk, props, explosive chains, traps and lights, then a bot plays the real game (kills, level ups and perk choices, stairs,
a full boss fight with its phases and relic, death and restart).
The exit code is the number of failures.

## Art and credits

Art, sound effects and music: **[Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack)**
by Pixel-boy and AAA, CC0 (public domain). License in `assets/LICENSE_NinjaAdventure.txt`.
Footstep sounds: Kenney Impact Sounds, CC0 ([kenney.nl](https://kenney.nl)).
The weapon attack sheets were composed from the pack's weapon sprites to match the hero's attack frames.

Pixel art is drawn at 2x in the world, with nearest filtering
(Project Settings > Rendering > Textures > Default Texture Filter).

## Conventions

- Static typing everywhere, `class_name` for reusable types.
- `snake_case` files and functions, `PascalCase` classes, `_private` members.
- One scene per entity, its script next to it.
- One monster scene for every monster type: the sprite, weapon and sounds come from the data,
  the rig animates whatever it is given.
