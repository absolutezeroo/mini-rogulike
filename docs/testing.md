# Tests and debug tools

## Getting Godot

The tests and tools need the Godot **4.7** editor binary (desktop, not an export template). On a
machine without it, the Linux build from the official release works headless:

```
curl -sSLO https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip Godot_v4.7-stable_linux.x86_64.zip   # then call it instead of `godot` below
```

On a fresh clone (no `.godot/` folder), import the project once first, or the first run fails on
missing resources: `godot --headless --import`. Errors printed by the import itself are normal on
the first run.

## Running the tests

From the project root:

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn                       # everything, a few minutes
godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title  # fast, about 30 s
```

The suites (`tests/suites/`, each a `TestSuite`):
- **unit**: the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
  inventory, equipment, perks, bosses, the profile. No game running: fast.
- **title**: the title screen and its panels.
- **game**: a bot plays the real game (kills, level ups and perk choices, stairs, death and
  restart, saving and resuming), then on that same game: **combat** (projectiles, perks, skills,
  monsters and their traits, difficulty, weapons), **floor** (props, hazards, chests, ambushes,
  encounters, pact doors, the merchant, loot, curses, biomes, act cards, the belt) and **boss** (a full boss fight
  with its phases and relic, then winning the run).
- The story (`story_tests.gd`, `StoryTests`): its unit part runs in the unit suite (every
  warden's chronicle, lengths and translations, the reveal rule, conditions, deeds, what a meeting
  tells, fragments, the codex's Chronicle, the option), its game part at the end of the game suite
  (the cinematic in an arena, skipping, no replay on a run picked up again, Short and Off, a deed,
  fragments on the floors and their panel). The runner turns Boss stories off for every other test
  (`Settings.boss_stories`), as it does the tutorial hints; the story tests turn them on.
- **tutorial**: the hints' data, the first steps played with the real controls, the hints that come
  up once, menus, the options and the profile.

The runner prints `FAIL: <what>` for every failed check, a count per suite, then
`N checks, M failed`. The exit code is the number of failures (a suite that doesn't compile counts as
one).

**Read the output, not only the exit code.** Engine errors printed while a test runs (`ERROR:`,
`SCRIPT ERROR:`) don't fail the run today. Known ones (2026-10-22): `Parse JSON failed` twice (the
damaged-save test, on purpose), plus the leak warnings at exit. Any other is a bug, even if
every check passed.

- **balance** (opt-in: only with `--only=balance`): the balance tools' quick runs against the
  targets of `data/balance/targets.tres`. Some of its checks fail on purpose today (the balance
  work to do): they are printed as `FAIL (KNOWN ...)`.

## Writing a check

Each suite extends `TestSuite` (`tests/support/test_suite.gd`); its `run()` calls `_test_*`
functions. Inside, `check(condition, "what should be true")` counts a check and prints the message
when it fails, so write the message as the rule ("projectiles stop on walls"). Game suites get the
real `Game` scene and wait with `await _frames(n)`; helpers find open cells, clear monsters, count
things on the floor and let a bot play (`_bot_play`). The runner sets English, empty save paths and
no tutorial hints, so a test never touches a player's files.

A rule fix comes with the check that would have caught it. Never weaken or skip a check to get a
green run; a balance target that can't be met yet is listed as known in the balance suite.

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
- **Pact door**: one button per pact: seals a dead-end room of this floor behind its door, shown
  on the map.

Release exports have no button and no panel (`DebugPanel.is_available()`).
