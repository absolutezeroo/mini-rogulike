---
name: add-content
description: Add game content to Le Puits des Âmes - a monster, boss, weapon, armor, consumable, tome, perk, relic, rune, affix, elite affix, biome, scene, prop, hazard, curse, floor event, encounter, achievement, quest or tutorial hint. Use when asked to create or extend content in data/.
---

# Adding content

Content is data. Read docs/adding-content.md first: its table says, for each kind, which
resource to create and where to register it.

1. **Start from a neighbour.** Copy the closest existing `.tres` of the same kind and change it,
   rather than writing one from scratch. Give it a unique `id` (snake_case) and a `display_name` in the game's voice
   (docs/lexicon.md: naming patterns, words to avoid).
2. **Keep the file valid.** Every `[ext_resource]` path must exist, ids must be unique within the
   file, sub-resources referenced by `SubResource("...")` must be declared. Don't add `uid=`.
3. **Register it** where the table says (`data/content_db.tres`, an act in `data/dungeon/acts/`,
   `data/dungeon/dungeon_config.tres`, a biome, a weapon's skills...). Content that isn't
   registered never appears (the balance tools report it as unused).
4. **New behaviour only if the data can't express it**: a subclass of `Effect`, `Passive`,
   `MonsterTrait` or `HazardDef` in `src/definitions/`, typed, with `##` docs, its numbers as
   `@export`s set in the data.
5. **Texts**: run `python3 tools/i18n/extract.py`, then use the `translate` skill to fill the French
   (names also need a `grammar:gender:<name>` row; item prefixes and elite affixes a
   `grammar:feminine:<adjective>` row).
6. **Check**: `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title`
   (the unit suite validates the content database and translations). Add a check if you wrote new
   behaviour.
7. **Docs**: add it to the matching docs/design/ page (tables of monsters, bosses, perks...).
8. **Balance**: if it can change an act's difficulty or a build's power, say so and suggest the
   `game-balancer` subagent; don't guess numbers far from those of its neighbours.

Report what you added, where it is registered, the test results, and what you could not check
(how it looks and feels in the game).
