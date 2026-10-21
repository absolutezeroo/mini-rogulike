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
| Use what you stand by (trade, forge, drink...) | The Interact button (shows only then) | E / F | RT |
| Open the waiting perk choices | The perk button (shows only then) | C | LT |
| Pause | II button / phone back button | Escape | - |
| Choose a perk | Tap a card | Arrows + Enter | D-pad + A |
| Inventory | Bag button | I / Tab | Back |

## Nothing opens by itself

Walking up to someone or something never opens a window, and a level up never does either: the
player decides when the fight stops.

- **Interact** (input action `interact`): standing by the merchant, the forge, an encounter or a
  pact door's stele, a round button pops in above the skills (left of the third one, where the
  thumb on the attack button reaches it; `InteractButton`), with the thing's picture and what
  tapping does on a plaque under it: **Trade** (the merchant), **Forge** (the smith), the
  encounter's own word (`EncounterDef.verb`: **Drink** at the spring, **Offer** at the blood
  altar, **Talk** to the grinning spirit, **Kneel** before the statue), **Read the pact** (a pact
  door, until it is sworn). A soft gold ring lies at the thing's feet while the button is its.
  Tapping (or E / F, the right trigger) opens its window; walking out of reach hides the button.
  Closing the window leaves the button there: tap again to come back. Spent things (a used
  encounter, a sworn pact) offer nothing.
  How it works: a thing adds an `Interactable` child (`src/entities/interactable.gd`: its verb,
  icon, color, reach, `enabled`, signal `used`); the Game's `Interactor` gives the button to the
  nearest usable one in reach each physics frame (`focus_changed`, read by the HUD) and uses it
  when the action goes down (`Game.interact()` does the same). Anything can join without other
  code changing (an item on the ground could, later). Chests and stairs keep working by walking
  on them: they open no window.
- **The perk button** (input action `offers`): see [builds.md](builds.md#perks-and-relics). Left
  of the minimap, under the pause button: a glowing golden star, "Perks" under it and how many
  choices wait on a red badge; it swells when one more comes. Hidden while none waits.
- Both are put away during the trial of the Threshold.

## On a phone

- **The run is saved** (`RunSave`, `user://run.json`) when a floor begins and whenever the app goes
  to the background (a call, switching apps...). The title screen then offers **Continue**: same
  depth (a fresh floor), the hero exactly as saved (level, stats, gear, bag, perks, spell, the
  perk choices still waiting, the one on screen with its cards). Dying erases it. "Save and quit" in the pause menu does the same on purpose.
  Never during the trial of the Threshold: quit in there, and the run picks up as it was before
  the killing blow.
- **Pause menu** (the II button, Escape, or the phone's back button): resume, options, save and quit,
  give up the run (two taps). Coming back to the app, the game waits paused.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  music and sound volumes, screen shake, size of the touch controls, **vibrations** (big shakes,
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
  (open the Bag), your first soul, a perk waiting (pointing at the perk button until it is
  tapped), a family bonus, a spell, an elite, a rune, the forge, the merchant, an encounter, a pact
  door (these four say to walk up and tap Interact, and point at its button as soon as it shows:
  a hint's ring follows its control), a chest, an ambush, a boss, the stairs opening, a cursed or
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
  the cards on dark wood with Reroll / Banish explained and **Later** (the choice waits behind the
  perk button; Back does the same), coming in softly (the world dims, the board rises, 0.2 s)
  instead of cutting over the fight; each pause button says what it does, with
  what gold and souls are for; the end screen shows the run's numbers (`RunState.summary_rows()`),
  the souls earned and what they buy.
