# Conventions

The rules the code follows. Most come from the
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html);
the ones below are those worth spelling out, or where this project chose something specific.

## GDScript

- **Godot 4 only.** `await`, `@export`, `@onready`, typed arrays, `signal.emit()`. No Godot 3 idioms
  (`yield`, `export var`, `connect("signal", obj, "method")`).
- **Static typing everywhere**: every variable, parameter and return type, `:=` when the type is
  obvious from the right side. Typed arrays and dictionaries (`Array[PerkDef]`).
- **`class_name`** for every reusable type; a script used once by its scene can do without.
- **Names**: `snake_case` files, folders, functions and variables; `PascalCase` classes and nodes;
  `CONSTANT_CASE` constants; `_private` members and methods, which nothing outside the script
  touches (tests included, where possible).
- **Doc comments**: `##` on every class (what it is for) and on every member whose purpose is not
  obvious from its name. They show in the editor's help. Plain `#` comments say *why*, not *what*.
  Write in plain English, as the existing code does.
- **Indentation**: tabs (`.editorconfig`), LF line endings (`.gitattributes`).
- **Scenes**: one scene per entity, its script next to it. One monster scene serves every monster
  type: the sprite, weapon and sounds come from the data, the rig animates whatever it is given.

## How the code is organised

- **Data-driven.** Content and tuning live in `data/**/*.tres` (instances of the classes in
  `src/definitions/`). Never hard-code a tuning number in a script: add an `@export` to the Def and
  set it in the data. New content usually needs no code; see [adding-content.md](adding-content.md).
- **Call down, signal up.** A node calls methods on its children and emits signals to whoever owns
  it. Gameplay code emits on `Events` for notifications; UI listens and never drives gameplay.
- **One input path.** Touch controls only press input actions, so keyboard, gamepad and touch share
  the same code.
- **Ask, don't recompute.** A floor's difficulty (difficulty x depth x event x curse) comes from its
  `FloorRules`; healing from hits and kills goes through `Actor.sustain_heal()` and its budget.
- **Small pieces.** Prefer a new `Effect`, `Passive`, `MonsterTrait` or `HazardDef` subclass to a new
  branch in `Actor`, `Monster` or `World`. Those three are already the biggest scripts.

## Texts

- Every text the player reads goes through `tr()` (in static functions:
  `TranslationServer.tr()`). Translate whole sentences, then fill them:
  `tr("Level %d / %d") % [a, b]`, or named codes where French needs another order
  (`tr("{rarity} {kind_lower}").format(...)`). Never glue translated pieces together.
- Data texts stay English in `data/` and are translated where they are shown: `tr(def.display_name)`.
- Player-facing words: **Health, Damage, Armor, Move speed** (never HP, ATK, DEF). The French
  glossary is in [translating.md](translating.md).
- Names, lore and flavor speak in the Well's dark-fantasy voice: [lexicon.md](lexicon.md). Rules
  and numbers stay plain.
- **Ids are not names.** A resource's `id` is for code, data, saves and tool options and never
  changes; its `display_name` is what the player reads and can be renamed freely. Several ids kept
  the game's first names (difficulty `easy` is Pilgrim, rank `shiny` is Celestial...): the
  list is in [balance.md](balance.md).
- After adding texts: `python3 tools/i18n/extract.py`, then fill the French. Details in
  [translating.md](translating.md).
- **Font sizes come from `Fonts`**: `Fonts.BODY` (18) for anything read, `Fonts.TITLE` (36),
  `Fonts.HUGE` (54), `Fonts.SMALL` (12) only for fine print that cannot fit; never a literal size.
  Labels get their one-font-pixel outline from `UiSkin.label()` / `UiSkin.set_text_style()`; text
  drawn in `_draw()` goes through `Fonts.draw()`. Any other size cuts the pixel font's letters on
  phones ([design/interface.md](design/interface.md#text)); the tests check it.

## Files and paths

- **Resources reference each other by path.** The `.tres` and `.tscn` files carry no `uid=`, so a
  moved or renamed file breaks every `res://` path to it (the content database alone holds ~220).
  Move files only in the Godot editor's FileSystem dock, which rewrites the references; if you must
  move them by hand, search for every `res://` path to them, and move a script's `.gd.uid` with it.
  Big reorganisations aren't worth that risk.
- Commit the `.uid` and `.import` files next to their source. Never commit `.godot/` (the import
  cache) or `locale/*.translation` (built from `locale/strings.csv`).
- Never change `config/custom_user_dir_name` ("Mini Roguelike"): it is where players' saves live.
- Signing keys (`*.keystore`, `*.jks`) and their passwords never go in git (see
  [android.md](android.md)).

## Tests and docs go with the change

- A rule fix comes with a check that fails without it ([testing.md](testing.md)).
- When what a player sees or a number changes, update the page of [design/](design/) that
  describes it, and the texts in the data that state it (perk, rune and affix descriptions).
- A balance change gets a dated entry in [balance-log.md](balance-log.md).
