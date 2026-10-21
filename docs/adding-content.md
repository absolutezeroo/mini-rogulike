# Adding content

Content is data: a `.tres` resource (an instance of a class in `src/definitions/`) under `data/`,
registered where the game looks for it, usually `data/content_db.tres` or an act in
`data/dungeon/acts/`. Most additions need no code. Edit `.tres` files in the Godot inspector when
you can; by hand, keep the `[ext_resource]` paths right.

## Example: a new monster

1. Duplicate a close one in `data/monsters/` (for a slime-like monster, `slime.tres`) and give it a
   unique `id` and a `display_name`.
2. Set its stats, weapon (`data/items/weapons/monster/`), skills, traits, material, loot table and
   `splat_color`; point `frames` to a SpriteFrames in `data/visuals/monsters/` (reuse one or make one
   from a sheet in `assets/characters/monsters/`).
3. Add it to the Monsters of the act(s) it lives in (`data/dungeon/acts/act_N.tres`); `min_depth`
   and `spawn_weight` decide where and how often it shows up.
4. Texts: `python3 tools/i18n/extract.py`, fill its French name and description in
   `locale/strings.csv`, and add its `grammar:gender:<name>` row ([translating.md](translating.md)).
5. Run the tests (`--only=unit` checks the content database and the translations) and spawn it from
   the debug panel to look at it ([testing.md](testing.md)).
6. If it changes the balance of its act, measure it ([balance.md](balance.md)).

## Every kind of content

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
| A pact (a pact door's rule) | New `PactDef` in `data/pacts/` (a rule, waves, elites, relics, max Health cost), add it to `dungeon_config.tres` > Pacts |
| A new kind of pact rule | New script in `src/definitions/pacts/` extending `PactRule`: `describe()`, `status_text()`, listen in `_on_begin()`, call `_break()` |
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
