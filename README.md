# Mini Roguelike

Real-time action roguelike for Godot 4 (GDScript, Compatibility renderer).
Procedural floors, monsters with telegraphed attacks, melee and ranged weapons,
armor, consumables, skills, loot, XP and levels. Plays with touch controls,
keyboard or gamepad.

## Project layout

```
assets/              Art, audio, fonts and the UI theme
  sprites/             Kenney Tiny Dungeon tileset + custom item sprites (items/)
  ui/                  Kenney UI Pack Pixel Adventure (upscaled 2x)
  fonts/               Kenney Mini pixel font
  theme/               main_theme.tres: pixel UI theme used by every Control
data/                Game content as .tres resources (no code)
  content_db.tres      Index of everything that can spawn
  player/              Starting stats, kit, skills, leveling
  dungeon/             Floor size, room count, difficulty curve, floor themes (themes/)
  monsters/            One file per monster type
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  skills/              Player and monster skills
src/
  autoload/            Events: global signal bus
  core/                Small shared helpers (physics layers, weighted random)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
  dungeon/             Map data, generator, drawing
  world/               World (owns the current floor) and FloorPopulator
  entities/            Actor (shared base), Player, Monster, Projectile, ItemPickup, Stairs
  components/          Inventory, Equipment, SkillSet
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack)
  vfx/                 Slashes, rings, floating damage numbers
  ui/                  HUD, touch controls, inventory, game over
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
  > Attack (telegraphed wind-up, strike, recovery).
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path.

## Adding content

| To add... | Do this |
|---|---|
| A monster | Duplicate a file in `data/monsters/`, edit it, add it to `content_db.tres` > Monsters |
| A weapon / armor / consumable | Duplicate a file in `data/items/...`, edit, add it to `content_db.tres` > Items |
| A loot drop | Edit the monster's Loot table (items don't need to be in the DB to drop) |
| A player skill | Create a `SkillDef` in `data/skills/player/`, add it to `player_def.tres` > Skills (max 3) |
| A new kind of effect | New script in `src/definitions/effects/` extending `Effect`, override `apply()` |
| A new monster behaviour | New state script in `src/ai/states/`, add a node for it in `monster.tscn` |

Each piece of content has an **icon** (any `Texture2D`, usually an `AtlasTexture` pointing into
`tilemap_packed.png`) and an **icon tint** to recolor it. To change a sprite, edit the icon's region
in the inspector or drop in your own 16x16 PNG.

`min_depth` and `spawn_weight` control where and how often something appears.
A `spawn_weight` of 0 means it never spawns on its own (starting gear, loot-only items, monster weapons).

## Controls

| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim, hold) | Big red button | J / Space | X |
| Skills 1-3 | Small round buttons | K L O or 1 2 3 | A B Y |
| Quick potion | Potion button | Q / H | LB |
| Inventory | Bag button | I / Tab | Back |

## Tests

From the project root (desktop Godot):

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn
```

Checks the rules, the content database, 100 generated maps, inventory and equipment,
then a bot plays the real game (kills, level ups, stairs, death and restart).
The exit code is the number of failures.

## Art and credits

All third-party assets are CC0 (public domain) by [Kenney](https://kenney.nl):
Tiny Dungeon, UI Pack - Pixel Adventure and Kenney Fonts. Licenses are next to each asset folder.
The armor, bomb and scroll sprites in `assets/sprites/items/` were drawn for this project in the same palette.

Pixel art is 16x16, drawn at 2x in the world, with nearest filtering
(Project Settings > Rendering > Textures > Default Texture Filter).

## Conventions

- Static typing everywhere, `class_name` for reusable types.
- `snake_case` files and functions, `PascalCase` classes, `_private` members.
- One scene per entity, its script next to it.
- Entities draw their sprite in `_draw()` (flip, walk bob, weapon swing, hit flash) so a single
  scene works for every monster type: the look comes from the data.
