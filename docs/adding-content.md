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
| A demon of the Deeps | A `MonsterDef` in `data/monsters/abyss/`, add it to `data/abyss/abyss.tres` > Monsters (in no act) |
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
| A boss | New `BossDef` in `data/monsters/bosses/`, set it as an act's Boss, and give it a chronicle (below, "The story") |
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
| A boss of several forms | Its next form in `BossDef.next_boss` (it rises in the same arena; `arena_anchor`, `body_stays`, `rise_time`) |
| A body that can only be hurt sometimes | A `WeakPointTrait` in the monster's Traits (closed and open times by phase, its pull and bite) |
| A skill striking marked spots on the ground | A `GroundStrikeEffect` (count, radius, fuse, spread, element, a strike sheet) |
| The bottom of the Well, its endings | `data/story/finale.tres` (`FinaleDef`: the gate, its floor, its boss, its endings), `data/story/endings/` (`EndingDef`: button, line, title, text, the stat of its achievement) |
| An encounter | New `EncounterDef` in `data/encounters/` (choices, costs, outcomes, the `verb` on the Interact button by it), add it to `content_db.tres` > Encounters |
| A pact (a pact door's rule) | New `PactDef` in `data/pacts/` (a rule, waves, elites, relics, max Health cost), add it to `dungeon_config.tres` > Pacts |
| A new kind of pact rule | New script in `src/definitions/pacts/` extending `PactRule`: `describe()`, `status_text()`, listen in `_on_begin()`, call `_break()` |
| An item affix | New `ItemAffixDef` in `data/affixes/` (prefix or suffix, slots, stats, on-hit or passives + description), add it to `content_db.tres` > Item Affixes |
| Story texts | Edit `data/story/story.tres` (intro pages, death lines...); an act's line is its `ActDef` > Lore |
| A boss's story, a fragment, a condition, a deed, a cinematic step | See "The story" below |
| A speaker, a line of dialogue, an advice of the Vigil-Keeper, a condition on the run | See "Dialogue" below |
| A secret room's reward | New `SecretRewardDef` in `data/secrets/` (a chest, an encounter, items or runes, gold: `SecretChestReward`, `SecretEncounterReward`, `SecretItemReward`, `SecretGoldReward`; `spawn_weight`, `min_depth`), add it to `dungeon_config.tres` > Secret Rewards |
| A new kind of secret reward | New script in `src/definitions/secrets/` extending `SecretRewardDef`, override `place()` (and `is_claimed()`, `place_spent()`) |
| The hidden floor | `data/secrets/nameless_charnel.tres` (`HiddenFloorDef`: its key, the acts that hide it, its world, monsters, boss, rewards), set in `dungeon_config.tres` > Hidden Floor |
| A tutorial hint | Add a `HintDef` to `data/tutorial/tutorial.tres` > Hints (a cue from `Tutorial.CUES`, a text, a HUD control to point at). A hint that names a control ("tap...") also gets a `button_text` for keys and gamepads, with `{action}` codes ("Press {interact} to trade") |
| A loading tip about a control | A `DeviceText` (`touch_text`, `button_text` with `{action}` codes) in `data/ui/loading_tips.tres` > Control Tips (plain tips: Tips) |
| A new input action, or a control shown to the player | Bind it in project.godot > Input Map (keys, gamepad), then add an `ActionPromptDef` to `data/ui/input_prompts.tres` > Actions: its name on the Options' Controls page, the key its prompts show (`key`), a mouse button that also does it in a fight (`mouse`), how it is done by touch (`touch_text`) |
| A compartment of the bag (and its tab), or where a kind of item goes | `data/items/bag_categories.tres` (`BagCategorySet` of `BagCategoryDef`: name, icon, its places (`capacity`), what it says when full (`full_text`), the item classes it holds (`kinds`: a class counts as the nearest one listed, a `WeaponDef` before its parent `EquipmentDef`), items named by id (`item_ids`, winning over `kinds`), `catch_all`, `hidden_when_empty`). A new item class lands in its parent's compartment, or the catch-all one. More places for the hero: `PlayerDef.bag_bonus` (every compartment); an upgrade: `Inventory.extra_places` / `extra_by_category` |
| A new thing to do with an item in the bag | A `BagAction` subclass in `src/ui/inventory/actions/` (`available()`, `label()`, `run()`, an `input` action for keys and gamepads, `needs_confirm()` for a second press), added to `InventoryPanel._actions` |
| A gamepad family's button names | A `PadGlyphsDef` in `data/ui/input_prompts.tres` > Pads (the pieces of a pad's name that say it is of this family, its buttons' and axes' words, its face buttons' colors); the last one is for every other pad |

Each piece of content has an **icon** (any `Texture2D`) and an **icon tint** to recolor it.
Monsters and the player also have `frames` (their SpriteFrames in `data/visuals/`): a new monster
can reuse an existing one, or you can make a new SpriteFrames from a sheet in `assets/characters/`.
Floor looks (tiles, decor, tint, darkness, music) are `DungeonTheme` files in `data/dungeon/themes/`, one per biome.
How many lanterns, prop clusters, hazard groups and chests a floor gets, how often ambushes and
elites happen, is in `dungeon_config.tres`.

`min_depth` and `spawn_weight` control where and how often something appears.
A `spawn_weight` of 0 means it never spawns on its own (starting gear, loot-only items, monster weapons).

## The story: chronicles, fragments, conditions, deeds, cinematics

How a warden's story is told is in [design/presentation.md](design/presentation.md#boss-stories);
what is true in it is [lore.md](lore.md) (write with the `lore` skill). The pieces:

| Piece | Class (`src/definitions/story/`) | Data | What it is |
|---|---|---|---|
| A warden's story | `BossChronicleDef` | `data/story/chronicles/<boss id>.tres`, set on the `BossDef` > Chronicle | its chapters, its waking lines, its last words, its fragments |
| A chapter | `ChronicleChapter` (sub-resource) | in the chronicle | `id` (saved, never rename), `title`, 2-4 `lines`, `slain` (times the warden was slain), `conditions` |
| Its waking words | `WakingLine` (sub-resource) | in the chronicle | one line the warden says in quotes as it wakes, once its `conditions` are met (the last open one is said) |
| Its last words | `WakingLine` (sub-resource) | in the chronicle's Last Words | one line it says as it falls, on its banner (the last open one; most wardens have none: Tôma and the Maw do) |
| A fragment | `FragmentDef` | `data/story/fragments/<id>.tres`, listed in the chronicle's Fragments | `id` (saved), `title`, `author`, `place`, 2-5 `lines`, a `look`, `conditions` before it may lie on a floor |
| A fragment's look | `FragmentLookDef` | `data/story/fragment_looks/` | its 16x16 picture (`assets/items/fragments/`), the element of its glow, the word on the Interact button |
| A condition | `ProgressCondition` and its subclasses (`conditions/`) | a sub-resource, or shared in `data/story/conditions/` | `SlainCondition`, `MetCondition`, `StatCondition` (a profile counter: deepest floor, runs won...), `FragmentsCondition`, `AllCondition`, `AnyCondition` (one of several ways: the reveal); deeds (`deeds/`) |
| A deed | `DeedCondition` subclasses (`deeds/`) | a sub-resource of the chronicle | something precise done as the warden fell: `ChallengeDeed` (a `HuntChallenge` way of killing: a weapon, untouched, fast, without a potion...), `ElementDeed`, `MarkDeed` (the run bought nothing, drank at the spring, swore an oath...), `PurseDeed`, `HardshipDeed`, `UnhealedDeed`, `StandingDeed` (not a single roll in the fight); its `hint` (a riddle) and `rule` (plain), and the fragment that gives the rule away |
| A cinematic | `CinematicDef` (`cinematic/`) | `data/story/cinematics/` | its steps and the tuning they share (bars' height, letters a second, reading time, skip rules) |
| A cinematic step | `CinematicStep` subclasses (`cinematic/steps/`) | sub-resources of a cinematic | `LetterboxStep`, `CameraStep`, `AnimationStep`, `NameStep`, `NarrateStep` (a chapter, the warden's words, or the line it remembers), `ClearTextStep`, `WaitStep` |
| The whole | `NarrativeDef` | `data/story/narrative.tres` (`content_db.tres` > Narrative) | the full and short cinematics, the fragments' chance and when they start, the reveal gate (`keeper_reveal`) and its words |

The code that uses them: `Narrative` (`src/game/story/narrative.gd`, the only one writing the
story's part of the Profile, and answering what is open, told, found, done, and what a meeting
tells: `plan()`), `BossMeeting` (plays a meeting's cinematic when the hero walks into an arena),
`CinematicDirector` (runs a cinematic's steps) and `CinematicView` (draws it), `FragmentPlacer` (lays
fragments on the floors), `Fragment` (one on the floor) and `FragmentPanel` (reading it), and the
codex's `ChronicleRows`. None knows a warden by name: everything comes from the data.

**A new boss's chronicle.** Write it first (the `lore` skill: French first, English its equal;
docs/lore.md section 5 for who it was and what it knows; section 7 for what may be said when).
Copy a chronicle of `data/story/chronicles/`, then:
1. Chapters in the order they are told: the first one `slain = 0` and no conditions (the first
   meeting), then its life, how it fell, the keeper who bound it, its own truth; `slain` grows
   (1, 2, 4, 6 in ours). Each 2-4 lines, at most two sentences and 150 letters each.
2. One or two chapters or waking lines earned by a deed that means something for it (a sub-resource
   `DeedCondition` subclass in the chapter's Conditions, with an `id`, a `hint` in the Well's voice
   and a plain `rule`). A chapter can wait for its fragments (`FragmentsCondition`).
3. Two waking lines: one when a fragment of it was found, one naming the keeper with
   `data/story/conditions/keeper_named.tres` in its Conditions. **Any text naming Tôma must ask for
   that condition** (the tests scan every text in both languages for `NarrativeDef.reveal_words`).
4. Two or three fragments in `data/story/fragments/` (a real author, a place, 2-5 lines ending on
   an image), one of them giving the deed's rule away (`revealed_by`); a page of Tôma's journal
   waits for `keeper_named`. A hidden warden's fragments wait for a `MetCondition`. They lie on the
   floors of its act (or of the acts that hide its way, for the hidden floor's warden; of the last
   act for the bottom of the Well's forms, once it is open).
5. Set the chronicle on the `BossDef` (> Chronicle). Beware loops of resources: a condition inside
   a warden's own chronicle names that warden by `monster_id`, not by its `BossDef` (`SlainCondition`
   and `MetCondition` take one). What a boss says when it falls goes in its Last Words, never in the
   `BossDef`: a boss of several forms gets a chronicle for each, the risen one is met in its turn.
6. `python3 tools/i18n/extract.py`, the French (the `translate` skill: « », a plain space before
   `: ; ! ?` and inside the quotes), `--check`. The unit suite checks every warden of the acts, the
   hidden floor and the bottom of the Well has a chronicle with 4 chapters or more, every line is
   translated and fits, and the reveal.
7. Add what is new about it to docs/lore.md (section 5b).

**A new kind of condition**: a script in `src/definitions/story/conditions/` extending
`ProgressCondition`: `is_met(subject)` (read the Profile through Narrative or the Profile's
counters, never the UI) and `describe(subject)` (plain words for the codex's lock). A new counter:
a key in `Profile.stat_value()`, read by a `StatCondition`. Dialogue and NPCs can use the same
conditions (`ProgressCondition.all_met(conditions, subject)`).

**A new kind of deed**: a script in `src/definitions/story/deeds/` extending `DeedCondition`:
`achieved(kill)`, reading the warden's death as `HuntTracker.kill_context()` describes it (add a
key there if it needs one, from the run or the fight: `RunState.marks` for what the run did, set
by `RunRecords` from the `Events`). Recorded for good by `Narrative.record_deeds()`.

**A new kind of cinematic step**: a script in `src/definitions/story/cinematic/steps/` extending
`CinematicStep`: `play(director)` uses the director's stage (`camera`, `subject`, `hero`, `view`,
`story`, `def`'s tuning) and waits with `await director.wait(seconds)` so a tap can hurry or end it;
`always_run` for a step that must run even when skipped (putting things back). Then add it to a
cinematic's Steps. A scene for an NPC or the final fight is another `CinematicDef` played by a
`CinematicDirector` with its own subject and `StoryBeat`.

## Dialogue: speakers, lines, advice

What it is for the player: [design/presentation.md](design/presentation.md#the-vigil-keeper-and-the-keepers-dialogue);
what may be said and when: [lore.md](lore.md) (sections 6 and 7; write with the `lore` skill,
French first). The pieces:

| Piece | Class | Data | What it is |
|---|---|---|---|
| A speaker | `SpeakerDef` (`src/definitions/dialogue/`) | `data/story/dialogue/speakers/<id>.tres` | name, title, `portrait` (a faceset, drawn at a whole scale), `figure` (a 16x16 sheet: the shrine draws its first column), `color`, `voice` (`assets/audio/sfx/voice/`), `letters_per_second` |
| What it says at one moment | `DialogueDef` | `data/story/dialogue/<id>.tres` | `id` (saved, never rename), `speaker`, `lines` |
| A line | `DialogueLineDef` (sub-resource) | in the dialogue | `id` (saved), 1-3 `lines` (pages, at most two sentences and 150 letters each), `conditions`, `priority`, `once`, `cooldown_runs`, `remembered` (false for a line holding the run's {codes}: the tests ask for it) |
| A condition on the run | `RunCondition` subclasses (`src/definitions/story/conditions/run/`) | sub-resources of the line | `KillerCondition`, `CauseCondition`, `PlaceCondition`, `RunMarkCondition`, `LevelCondition`, `GearCondition`, `OutcomeCondition`, `DeathStreakCondition`, `DeathCountCondition`; any story condition works too (`StatCondition` on `talk:<dialogue id>` for meetings, `keeper_named.tres`, `NotCondition`, `EndingCondition`) |

- **A line for a speaker**: add a `DialogueLineDef` to its dialogue (the inspector, or by hand:
  copy a sub-resource), a new `id`, its pages in English (the key), its conditions and priority;
  `python3 tools/i18n/extract.py`, the French in `locale/strings.csv`, `--check`. A line naming
  Tôma asks for `data/story/conditions/keeper_named.tres` (the tests scan both languages).
- **An advice of the Vigil-Keeper**: a line in `data/story/dialogue/vigil_advice.tres`: an
  `OutcomeCondition` (a death), what the death or the run must be (a `KillerCondition` with the
  monster's id, a `CauseCondition`...), a priority among the others (a warden's own moves 80, a
  cause 66-75, the run's habits 40-64, the master's lessons 4-5), a `cooldown_runs` so it is not
  said every death. **Say only what the game does**: read the monster's data and docs/design
  first (its skills, their telegraphs), never invent a mechanic or a number.
- **A tale of a death**: the same in `vigil_tale.tres` (`{killer}` at a sentence's start or after a
  colon only; `remembered` false).
- **A new speaker**: a `SpeakerDef`, its dialogues, listed in `NarrativeDef.dialogues` (the codex's
  Voices and the tests), and hung where it speaks: a `dialogue` export on its data (as
  `ShopDef`, `ForgeDef`, `EncounterDef`), its panel showing `Dialogues.say(dialogue)` (a line on
  the panel) or a `DialogueBox` / `DialogueScreen` (a conversation). Nothing in the code knows a
  speaker by name.
- **A new kind of condition on the run**: a script extending `RunCondition`: `met(facts)` reads
  the `RunFacts`. A fact the run does not know yet: a field in `RunFacts`, read in `of_death()` /
  `of_victory()` (a cause of death: set `HitInfo.cause` where the hit is made; something the run
  did: a mark set by `RunRecords`, `Events.run_marked`).
- **A new code** (`{something}` in a line): a key in `RunFacts.codes()`, and in the tests' `CODES`.

