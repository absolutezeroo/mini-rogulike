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
  encounters, pact doors, the merchant, loot, curses, biomes, act cards, the belt), **boss** (a full boss fight
  with its phases and relic, then winning the run) and **finale** (the bottom of the Well after a
  win: the gate, saves around it, Tôma, the Maw's jaw, the endings, and with Boss stories on
  their meetings, last words and deeds).
- The story (`story_tests.gd`, `StoryTests`): its unit part runs in the unit suite (every
  warden's chronicle, lengths and translations, the reveal rule, conditions, deeds, what a meeting
  tells, fragments, the codex's Chronicle, the option), its game part at the end of the game suite
  (the cinematic in an arena, skipping, no replay on a run picked up again, Short and Off, a deed,
  fragments on the floors and their panel). The runner turns Boss stories off for every other test
  (`Settings.boss_stories`), as it does the tutorial hints; the story tests turn them on.
- Keyboards, mice and gamepads (`pc_tests.gd`, `PcTests`): its unit part in the unit suite (the
  device in use from keys, gamepad buttons and sticks with the dead zone, touches and the mouse;
  the prompts per device and gamepad family; the input map; the settings; the canvas's scale at
  every screen size; MenuNav on a little menu), its title part in the title suite (the title's
  panels with keys: move, accept, Back, tabs; their layouts at every size), its game part in the
  game suite (the HUD per device, the mouse in a fight, pausing, every in-run panel with keys and a
  gamepad, the HUD's layout at every size, on touch and on keys). The runner starts every suite on
  touch (`InputDevice.use(TOUCH)`): the other tests play the phone's game.
- The bag's compartments, tabs and quick actions (`bag_tests.gd`, `BagTests`, on PcTests'
  helpers): its unit part in the unit suite (which compartment every item lands in, each one's
  own places, upgrades, an old save's list coming back past its places, the order in a tab,
  which dismantles ask first, the actions and their keys), its game part in the game suite (loot,
  auto loot and the merchant asking the item's compartment, a full tab, Dismantle the worse per
  tab; the bag on
  touch: tabs tapped, the card's buttons, new marks, the tab remembered, a right click; with a
  gamepad: LB / RB, A, X, Y, B, the confirmation for rare pieces, what is worn never broken; with
  keys: Q / E, Enter, X, Delete, G, Escape; and the bag inside a 1280x720 screen in French).
- The dialogue (`dialogue_tests.gd`, `DialogueTests`, on PcTests' helpers): its unit part in the
  unit suite (every speaker's lines: lengths, translations, codes, the reveal; the tale and the
  advice a staged death gets: a warden, its shockwave, a trap, the Deeps, the cold, the Threshold,
  early deaths again and again, potions left...; once, cooldowns and turns; the keepers' lines
  gated and kept; the save; the codex's Voices; the DialogueBox by touch, keys and gamepad), its
  title part in the title suite (the Vigil-Keeper at the shrine by touch, keys and gamepad, the
  lamps, her box at every size in French), its game part in the game suite (a real death told on
  the end screen, a trap's, the fallback line, the merchant's and the spirit's lines, the end
  screen in French at 1280x720 and the phones' sizes).
- **tutorial**: the hints' data, the first steps played with the real controls, the hints that come
  up once, menus, the options and the profile.

The runner prints `FAIL: <what>` for every failed check, a count per suite, then
`N checks, M failed`. The exit code is the number of failures (a suite that doesn't compile counts as
one).

**Read the output, not only the exit code.** Engine errors printed while a test runs (`ERROR:`,
`SCRIPT ERROR:`) don't fail the run today. Known ones (2026-10-22): `Parse JSON failed` twice (the
damaged-save test, on purpose), plus the leak warnings at exit. Any other is a bug, even if
every check passed (`Lambda capture at index 0 was freed`, seen in the game suite until then, was
one: see docs/conventions.md, "Lambdas that run later").

- **balance** (opt-in: only with `--only=balance`): the balance tools' quick runs against the
  targets of `data/balance/targets.tres`. Some of its checks fail on purpose today (the balance
  work to do): they are printed as `FAIL (KNOWN ...)`.

**The same run twice is not the same run:** floors, loot and fights are random, so a check that
fails once and passes on a rerun is a flaky test, a bug to find (below), never a retry. The game
and tutorial suites were hunted for them on 2026-10-22 (one game run in three failed before).

## Writing a check

Each suite extends `TestSuite` (`tests/support/test_suite.gd`); its `run()` calls `_test_*`
functions. Inside, `check(condition, "what should be true")` counts a check and prints the message
when it fails, so write the message as the rule ("projectiles stop on walls"). Game suites get the
real `Game` scene and wait with `await _frames(n)`; helpers find open cells, clear monsters, count
things on the floor and let a bot play (`_bot_play`). The runner sets English, empty save paths and
no tutorial hints, so a test never touches a player's files.

A rule fix comes with the check that would have caught it. Never weaken or skip a check to get a
green run; a balance target that can't be met yet is listed as known in the balance suite.

### Checks that hold on every floor (no flaky tests)

The game suites play real, random floors: a check passing once proves little. A check that fails
now and then is a bug, in the test's setup or in the game. Make the setup sure, keep the assertion:
- **Where:** never a fixed offset from the hero (a wall, a prop or a hole may be there). Ask the
  helpers: `_open_cell_near()` (open floor all around), `_clear_lane()` (a straight run of solid
  floor that a dash or a shot crosses: `_clear_ray()` tests the world's physics layer, which props
  are on, unlike `has_line_of_sight()`), `_free_points_away()`, `_point_without_props()` (where a
  blast breaks nothing). A body put down by hand must fit there (`_body_fits()`: a wall's or a
  prop's shape can reach into a free cell, and a body put inside one never gets out).
- **Who else:** the floor's monsters wander in, shoot, push, spot the hero in the first frames.
  `_clear_monsters()` (before they move, if what they would cue matters), a dormant target,
  `invincible` on the hero when a stray hit would spoil the test (not when the hit is it). A
  blow's push carries the hero a cell in a frame: `_walk_into_hole()` keeps him out of reach until
  he lands. Traps fire on their own: pick the hero's own shot (`Projectile._shooter`), not the
  newest one.
- **Statuses and looks:** a body watched for its statuses stands at a `_quiet_point()`: in view
  (a monster off screen sleeps), away from fires, ponds, sand and traps.
- **At rest:** `_stand_still()` before comparing where the hero stands (a step of leftover
  knockback, or a deferred freeze one physics step later, moves him).
- **Time:** `_frames(n)` waits n physics steps, one a frame (1/60 s) with `--fixed-fps 60`; a hit
  stop or a slow motion scales what happens in a step, not how many there are. Wait for something
  with a generous timeout (`_until_deeps()`, `_until_trial()`, a loop that breaks when it is so)
  rather than a guess of frames that a slower step would miss.
- **Counting the floor:** `_floor_things()` and `_things_diff()`, not `get_child_count()`: passing
  effects (dust, sparks, a column of light) stand among the floor's entities and come and go, and
  the bodies of monsters slain a moment ago go when their death has played.
- **Hints (tutorial):** another hint of the floor may have its say first: `_until_hint()`.
- **Leftovers:** a test puts back what it changed (holes: `_fill_holes()`; perks, XP, statuses).
  A lambda connected for a test captures nothing that a later test may free (or is disconnected).
- **Diagnose:** a check's message says what it saw (counts, distances, states), so one failure in
  a long run is enough to find the cause.

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
- **The Well's bottom** (Floor row): goes to the final fight at once (FinaleDef), as if Act IV's
  boss had led there.
- **Pact door**: one button per pact: seals a dead-end room of this floor behind its door, shown
  on the map.

Release exports have no button and no panel (`DebugPanel.is_available()`).
