# Interface

## Controls

Every scrolling list (codex, shrine, bag, shop) scrolls by dragging a finger over it, from
anywhere in it, cards and buttons included, with a bit of momentum (`TouchScroll`, added to each
`ScrollContainer` by the `TouchScrolling` autoload); a drag never presses a button, a tap does.


| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim, hold) | Big red button | J / Space | X |
| Skills 1-4 | Small round buttons | K L O P or 1 2 3 4 | A B Y RB |
| Belt (potions, bombs, scrolls) | The 3 small buttons left of the skills | Q / H, 5, 6 | LB (slot 1) |
| Pause | II button / phone back button | Escape | - |
| Choose a perk | Tap a card | Arrows + Enter | D-pad + A |
| Inventory | Bag button | I / Tab | Back |

## On a phone

- **The run is saved** (`RunSave`, `user://run.json`) when a floor begins and whenever the app goes
  to the background (a call, switching apps...). The title screen then offers **Continue**: same
  depth (a fresh floor), the hero exactly as saved (level, stats, gear, bag, perks, spell, perk
  choices left open). Dying erases it. "Save and quit" in the pause menu does the same on purpose.
  Never during the trial of the Threshold: quit in there, and the run picks up as it was before
  the killing blow.
- **Pause menu** (the II button, Escape, or the phone's back button): resume, options, save and quit,
  give up the run (two taps). Coming back to the app, the game waits paused.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  five volumes (**General**, **Music**, **Interface**, **Combat**, **Ambience**: which sounds
  each one sets is in presentation.md, SFX; letting go of a slider plays a sound of what it sets: a
  click, a hit, coins; settings files from before, with one sound volume, give it to Interface,
  Combat and Ambience), screen shake, size of the touch controls, **vibrations** (big shakes,
  hits you land, crits; `Settings.vibrate()`; exported Android builds need the Vibrate permission),
  **fixed joystick** (it stays in its corner and starts only when touched there, instead of
  appearing under the thumb), **battery saver** (30 FPS cap, `Engine.max_fps`), **fewer effects**
  (half the particles in `Vfx.burst`), **run timer** (on/off), **tutorial hints** (on/off) and
  **Replay tutorial**, and the **language** (English / Français, see Languages). The window (`OptionsPanel`, built in code on `MenuWindow`) groups them
  (Sound, Touch controls, Screen and battery, Tutorial), each with a one-line "what it does";
  on/off options are big switches, and tapping an option's name flips it too.
- **The trial of the Threshold** (`ThresholdHud`, built by the HUD from the `Threshold`'s signals):
  its name and rule across the screen for three seconds ("The Threshold" / "Slay 8 spectres before
  the knell"), then a panel at the top center with the spectres slain ("Slain 3 / 8") and a big
  countdown in seconds, red and beating in the last ten. The minimap, the seal, the boss bar and
  the bag button are put away until the hero is back; a toast says he came back ("You come back
  from the Threshold."), a red banner that the knell has tolled.
- **Minimap** (`Minimap`): rooms are revealed when you walk in, corridors around you; it shows holes,
  the stairs (violet while sealed), unopened chests, a running ambush, a pact door once seen (its
  room outlined during the fight), the boss and, near the end of a seal, the last monsters. Tap it
  for the whole floor. During a pact's fight a line under it (`PactLine`) names the pact and how its
  rule holds ("Untouched", "18 s left").

## Tutorial

No separate tutorial level: the first run teaches as it goes. A small wooden board comes up at the
top of the screen (`HintBox`), says what to do, and, when it is about a control, a gold ring pulses
around it with an arrow. Each hint shows **once ever** (`Profile.hints_seen`), one at a time, never
over a menu or a big banner. A tap (or OK) closes it.

- **First steps**: move (it stays until you have walked a few tiles), then the sealed stairs; when
  a monster first sees you, attack (until you swing), then roll, then the weapon's two skills.
- **The first time something happens**: low health (drink a potion from the belt), gear in the bag
  (open the Bag), your first soul, perks and families, a family bonus, a spell, an elite, a rune, the
  forge, the merchant, a chest, an ambush, a pact door, a boss, the stairs opening, a cursed or
  strange floor, cold and heat, the first trial of the Threshold (pointing at its countdown, once its
  name is gone).
- **Data**: `data/tutorial/tutorial.tres` (`TutorialDef`): the hints (`HintDef`: its cue, the hint
  it comes after, a condition, the title and text, the HUD control it points at, the action that
  ends it or how long it stays, its priority) and the distances and thresholds. The cues, actions
  and conditions are listed in `Tutorial` (`src/game/tutorial.gd`); the controls are the HUD's
  unique names (`Hud.hint_target()`).
- **Options**: "Tutorial hints" turns them off; "Replay tutorial" shows them all again.

## Bag, forge and the other in-run screens

The bag, the forge, the shop, encounters, perk choices, the pause menu and the end of a run are drawn in the game's RPG skin (`UiSkin`, `src/ui/common/`): a wooden
board with a gold ornate border (`RpgWindow`), the title on a red ribbon, dark recesses for each
column, and items in square slots (`ItemSlot`): the icon at a whole-pixel scale, a frame in the
item's rarity color (a rune's in its family's), how many, and a weapon's rune sockets as little
stones lit in their runes' colors. The selected slot pulses gold.

- **Bag** (`InventoryPanel`, built in code): the hero, the weapon / head / body slots, the belt and
  the stats on the left; the bag as a 4-column grid of slots (empty places shown); the picked
  item's card on the right (name in its rarity, type, every line of its details, its rune sockets)
  with Equip / Use / Learn, To belt and Drop.
- **Forge** (`ForgePanel`): the smith and what he says; the weapons you can work on as slots, the
  picked one big with its sockets; your runes as a grid. Pick a rune, then "Set it in"; pick a
  set rune, then "Take out (gold)".
- **Shop** (`ShopPanel`, built in code): the merchant and your gold on top; what he sells as slots
  with their price (a padlock on locked ones) and Reroll ("new items for sale, locked ones stay");
  what you carry with what he pays; the picked item's card: its stats in words, how it compares
  with what you wear (`ItemCompare`: "+3 damage", "-12 move speed", in green / red), its price,
  Buy (greyed with the reason: not enough gold, bag full), Lock (what it does, spelled out) or Sell.
- **Encounters** (`EncounterPanel`): one card per choice with its cost and every outcome in plain
  words with its odds ("55%  Heals you fully", `EncounterChoice.chances()`,
  `EncounterOutcome.summary()`), risks in red; Leave ("nothing happens, you can come back").
- **Perk choice**, **pause menu** and **end of a run** use `RpgDialog` (a centred board, no Close):
  the cards on dark wood with Reroll / Banish explained; each pause button says what it does, with
  what gold and souls are for; the end screen shows the run's numbers (`RunState.summary_rows()`),
  the souls earned and what they buy.
