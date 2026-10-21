# Tests and debug tools

## Tests

From the project root (desktop Godot):

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn
godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title
```

The suites (`tests/suites/`, each a `TestSuite`):
- **unit**: the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
  inventory, equipment, perks, bosses, the profile. No game running: fast.
- **title**: the title screen and its panels.
- **game**: a bot plays the real game (kills, level ups and perk choices, stairs, death and
  restart, saving and resuming), then on that same game: **combat** (projectiles, perks, skills,
  monsters and their traits, difficulty, weapons), **floor** (props, hazards, chests, ambushes,
  encounters, the merchant, loot, curses, biomes, act cards, the belt) and **boss** (a full boss fight
  with its phases and relic, then winning the run).
- **tutorial**: the hints' data, the first steps played with the real controls, the hints that come
  up once, menus, the options and the profile.

The exit code is the number of failures.

- **balance** (opt-in: only with `--only=balance`): the balance tools' quick runs against the
  targets of `data/balance/targets.tres`. Some of its checks fail on purpose today (the balance
  work to do): they are printed as `FAIL (KNOWN ...)`.

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

Release exports have no button and no panel (`DebugPanel.is_available()`).
