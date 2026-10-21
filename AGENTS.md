# Agent guide: Le Puits des Âmes

Real-time action roguelike in Godot 4.7, GDScript (statically typed), Compatibility renderer,
for Android and desktop. Humans start at README.md; the reference is in docs/. Read the docs page
for a system before changing it.

## Commands (from the repo root)

- Godot: `godot`, or a downloaded `Godot_v4.7-stable_linux.x86_64` (how to get it: docs/testing.md).
  If `.godot/` is missing, run `godot --headless --import` first.
- Fast tests, after every change to src/, data/ or tests/ (about 30 s):
  `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title`
- Full tests before calling a feature done (a few minutes; suites unit, title, game, tutorial):
  `godot --headless --fixed-fps 60 res://tests/run_tests.tscn`
- Exit code = failed checks; failures print as `FAIL: ...`. Engine `ERROR:` / `SCRIPT ERROR:` lines
  don't fail the run, so read the output: docs/testing.md lists the known ones, anything else is a bug.
- Translations: `python3 tools/i18n/extract.py` after adding texts, then fill the French in
  `locale/strings.csv`; `python3 tools/i18n/extract.py --check` must pass.
- Balance: the `balance` suite is opt-in and slow, and some of its checks fail on purpose
  (`FAIL (KNOWN ...)`). The measuring tools are described in docs/balance.md.

## Code rules (what you would not guess)

- Godot 4 APIs only (`await`, `@export`, `@onready`, typed arrays, `signal.emit()`), never Godot 3.
- Type everything; `class_name` for reusable types; tabs; `##` doc comment on each class and on
  non-obvious members, plain English, explaining why. Match the surrounding code.
- Data-driven: content and tuning numbers live in `data/**/*.tres`, never hard-coded in scripts.
  New content = a resource plus its registration (usually `data/content_db.tres` or an act); see
  docs/adding-content.md. New behaviour = a new `Effect`, `Passive`, `MonsterTrait` or `HazardDef`
  subclass rather than another branch in `Actor`, `Monster` or `World`.
- Ask `FloorRules` for a floor's numbers; never multiply difficulty x depth x event x curse yourself.
- UI listens to `Events` and signals and never drives gameplay. Touch controls only press input
  actions.
- Every player-facing text goes through `tr()`, as a whole sentence with `%d` or `{name}` codes,
  never glued pieces. Data texts stay English and are translated where shown. Say Health, Damage,
  Armor (never HP, ATK, DEF).

## Files

- Resources reference each other by `res://` path (no `uid=`). Don't move or rename files unless asked.
  If you must, update every reference, and move a script's `.gd.uid` with it.
- Edit `.tres` / `.tscn` by hand carefully: keep `[ext_resource]` ids and paths consistent.
- Never edit `.godot/` or `locale/*.translation` (generated). Commit `.uid` and `.import` files.
- Never touch players' saves or settings; tests use empty paths. Don't change
  `config/custom_user_dir_name`.
- Never commit signing keys (`*.keystore`, `*.jks`) or their passwords.

## Done means

- Tests pass and the output has no new engine errors; `extract.py --check` passes.
- A rule fix or new mechanic has a check (`check(condition, "the rule")`) in tests/suites/.
  Never weaken or skip a check.
- The docs/design/ page about the change is updated in the same commit, along with the data texts
  that state a changed number. Balance changes get an entry in docs/balance-log.md.
- Headless tests don't show what the game looks or feels like: say what you could not check.
- Commit messages: what changed for the game on the first line, why in the body.

## Where to look

| Need | Page |
|---|---|
| Layout, how systems fit, autoloads | docs/architecture.md |
| Code rules in full | docs/conventions.md |
| Adding content | docs/adding-content.md |
| Tests, debug panel | docs/testing.md |
| Languages, French glossary | docs/translating.md |
| Balance tools / past passes | docs/balance.md / docs/balance-log.md |
| Android build | docs/android.md |
| What each system does | docs/design/ (dungeon, monsters, builds, loot, progression, interface, presentation) |
