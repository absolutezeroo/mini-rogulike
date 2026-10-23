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
  inventory, equipment, perks, bosses, the profile, the online leaderboards' queue and filter
  (`LeaderboardTests`, on `FakeBoardBackend`: a server in memory), the privacy rules, the gameplay
  statistics and the credits' data (`PrivacyTests`). No game running: fast.
- **title**: the title screen and its panels (the Leaderboards page with and without a server, the
  statistics' questions, Options > Privacy, the policy and the credits).
  No suite ever reaches the network: the runner gives `Leaderboards` an offline backend first,
  and `Privacy` and `Telemetry` no file (docs/online.md, Tests). The game suite plays its run with
  the statistics accepted on a fake server and checks what its end sends.
- **game**: a bot plays the real game (kills, level ups and perk choices, stairs, death and
  restart, saving and resuming), then on that same game: **combat** (projectiles, perks, skills,
  monsters and their traits, difficulty, weapons), **floor** (props, hazards, chests, ambushes,
  encounters, pact doors, the merchant, loot, curses, biomes, act cards, the belt; on 12 more
  floors, no body put down inside a wall or a prop), **boss** (a full boss fight
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
  panels with keys: move, accept, Back, tabs; their layouts at every size; then a game begun in
  French: every in-run panel with its longest words inside 1280x720, 1540x720, 2340x1080 and
  2548x1296, `_test_french_panels()`), its game part in the
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
  keys: Q / E, Enter, X, Delete, G, Escape, Alt+Enter and F11 switching fullscreen and nothing
  else; and the bag inside a 1280x720 screen in French).
- The dialogue (`dialogue_tests.gd`, `DialogueTests`, on PcTests' helpers): its unit part in the
  unit suite (every speaker's lines: lengths, translations, codes, the reveal; the tale and the
  advice a staged death gets: a warden, its shockwave, a trap, the Deeps, the cold, the Threshold,
  early deaths again and again, potions left...; once, cooldowns and turns; the keepers' lines
  gated and kept; the save; the codex's Voices; the DialogueBox by touch, keys and gamepad), its
  title part in the title suite (the Vigil-Keeper at the shrine by touch, keys and gamepad, the
  lamps, her box at every size in French), its game part in the game suite (a real death told on
  the end screen, a trap's, the fallback line, the merchant's and the spirit's lines, the end
  screen in French at 1280x720 and the phones' sizes).
- The floors' identity (`level_tests.gd`, `LevelTests`): its unit part in the unit suite (the
  room shapes' geometry; 20 floors a biome at every difficulty's size: one piece, solid walls,
  start, stairs, hearts and cracks on open ground, every listed shape used, a signature room now
  and then and never two; the Deeps' maze), its game part in the game suite after the biomes
  (built floors: nothing in rock, a chasm or a pool, chasms are holes, pools water, pillars
  standing, every open cell reachable, the minimap's round rooms; every biome's ceiling on the
  grid, its layers, its fade over the hero and a monster, none over an arena; every signature
  room forced on a floor, dressed, named once on a banner).
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

### No GDScript warnings

The editor's warnings (a local shadowing a property, an integer division, a static function
called on an instance, an unused signal, a needless `await`...) never show in a headless test.
The project is kept at zero; check it before calling a change done:

```
python3 tools/lint/gd_warnings.py      # prints them, exit 1 if there is any (about 1 min)
```

It starts a headless editor with its GDScript language server (`--lsp-port`), opens every script
of `src/`, `tests/` and `tools/` in it, prints what the server reports for each (warnings and
parse errors, with the project's own warning settings) and stops the editor. Godot is found as
`--godot PATH`, `$GODOT`, `godot` on the PATH, or a downloaded `Godot_v4.7-stable_linux.x86_64`
(the root, `_tool/`, `/tmp`); the project must have been imported once. The editor re-saves
`default_bus_layout.tres` when it starts: the tool puts it (and the project settings and the
roadmap) back as they were. Android's build template (`android/build/`, which carries its own
`.gdignore`, so the editor never scans it) is not ours and is left out. How to fix each kind:
docs/conventions.md, "No GDScript warnings".

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
**DBG** button next to pause (or F1) opens the `DebugPanel` (the game pauses). It has five tabs,
switched by a tap or a click, or with Q / E and a gamepad's LB / RB like the bag's; keys and a
gamepad move between its buttons (MenuNav). A toggle says its state ("Invisible: ON") and a
step its value ("Damage x5"), and both stay pressed while on.

- **World**: pick a depth and go there, next floor, rebuild the floor (plain unless you choose a
  **Curse** or a **floor Event** row: the floor is rebuilt with it, its card included,
  `World.forced_curse` / `forced_event`). **Places**: the next boss floor, the hidden floor, the
  Deeps (as if the hero fell into a hole), the bottom of the Well (the final fight, FinaleDef).
  **Move**: to the stairs, to the boss room's doorway, to the next room, break the stairs' seal,
  **Reveal maps** (this floor's map and every next one's, seen as they begin). **Encounter**:
  pick any encounter and place it beside the hero; **Boss story** has the floor's warden tell its
  story again (its cinematic, `Game.debug_boss_story()`; nothing with Boss stories off).
  **Fragment**: pick any fragment of the past (with its warden) and place it beside the hero.
  **Pact door**: one button per pact: seals a dead-end room of this floor behind its door.
- **Hero**: the cheats, kept across floors until the run ends (`DebugCheats`): god mode (nothing
  hurts), **Invisible** (monsters never notice him, and forget him if they had), **No
  cooldowns** (skills and the roll ready again at once), and three steps: **Damage** dealt
  x1 / x2 / x5 / x10 / one-shot, damage **Taken** x1 / x0.5 / x0.25 / x0.1 (at least 1 a blow),
  move **Speed** x1 / x1.5 / x2 / x3. Then full heal, +500 gold, level up, **Kill hero** (a blow
  nothing turns away: the end of the run, or the Threshold with a second life), freezing /
  burning / normal temperature, an Epic weapon, every consumable, every rune, the smith here, and
  **Give**: any weapon, armor, consumable, tome, rune, key, perk or relic, picked from its list.
- **Monsters**: **No AI** (every monster, bosses and new ones too, stands still: no step, no
  blow, no spell, no shockwave; a knockback still moves it), kill all, put all asleep, spawn any
  monster or boss of the game (plain, elite, or at a rare rank), make the next boss of a rank.
- **Gallery** (`DebugGallery`): pick a **Biome** (the nine of the acts, the bosses', the Deeps', the
  hidden floor's, the bottom of the Well's), its **Rooms** (as usual, every room but the first in
  one of its room shapes, or its signature room, marked with a star, for sure) and a **Ceiling**
  (its own, none, or any biome's), then **Build this floor**: a plain floor of its act, its map
  revealed. **Monsters of** an act (with its bosses), the hidden floor, the Deeps, the bottom of
  the Well or everything, then **Monster gallery**: a hall in the chosen biome's look, every one
  of them standing in rows, its name under its feet (none with the camera zoomed far out),
  bosses last; it turns No AI, Invisible and Full light on, to walk among them.
- **Tools**: the game's **speed** (x1 / x0.25 / x0.5 / x2, under the hit stops: `HitStop`), the
  camera's **zoom** (x1 / x0.75 / x0.5 / x0.35), **Full light** (every floor at its brightest,
  `World.relight()`), **Bodies & reach** (`DebugShapes`: each body's circle, the hero's weapon
  reach, each monster's attack range in red and how far it notices the hero, a line to its
  target), **Frame rate** (`DebugOverlay`: frames per second, monsters awake / on the floor,
  shots in the air, nodes, draw calls), **Save & reload** (saves the run and picks it up again,
  as the title's Continue would; not in a debug run).

A line at the top of the screen names the cheats on, and says when the run is a **debug run**:
anything the panel does to the run (all but the Tools tab's views and the game's speed) makes it
one, and nothing of a debug run is kept: the run is never saved (the save stays as it was
before the first cheat), and the profile is saved once, then held (`Profile.held`) and read back
from its file when the run ends, dropping the souls, kills, records and achievements it gave.
Every cheat ends with the run (`Game._begin_run()`, leaving the game). Checks: `DebugTests`
(tests/suites/debug_tests.gd), from the unit and game suites.

Release exports have no button and no panel (`DebugPanel.is_available()`), and every
`DebugCheats` setter refuses outside a debug build: the hooks in `Actor`, `Monster`, `Player`,
`SkillSet`, `HitStop`, `GameCamera` and `World` stay inert.
