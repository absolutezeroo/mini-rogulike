# Interface

## Controls

Every scrolling list (codex, shrine, bag, shop) scrolls by dragging a finger over it, from
anywhere in it, cards and buttons included, with a bit of momentum (`TouchScroll`, added to each
`ScrollContainer` by the `TouchScrolling` autoload); a drag never presses a button, a tap does.


| Action | Touch | Keyboard and mouse | Gamepad (Xbox names) |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim): tap; hold to charge, let go to unleash | Big red button | Space / J, left click | X |
| Roll (skill 1), weapon skills 2-3, spell 4 | Small round buttons | 1 2 3 4 or K L O P; roll: right click too | A B Y RB |
| Belt (potions, bombs, scrolls) | The 3 small buttons left of the skills | Q / H, 5, 6 | LB, D-pad left, D-pad right |
| Use what you stand by (trade, forge, drink...), or take loot left on the ground | The Interact button (shows only then) | E / F | RT |
| Open the waiting perk choices | The perk button (shows only then) | C | LT |
| Whole floor's map | Tap the minimap | M | D-pad up |
| Bag | Bag button | I / Tab | View (Back) |
| Pause (or close what is open) | II button / phone back button | Escape | Menu (Start) |
| In a menu: move / accept / back | Tap | Arrows or WASD / Enter or Space / Escape | D-pad or left stick / A / B |
| In a menu with tabs: previous / next tab | Tap a tab | Q / E | LB / RB |
| In the bag: equip or use / dismantle / drop the item | The item card's buttons | Enter or Space (right click) / X or Delete / G | A / X / Y |
| In the bag: scroll a long item card | Drag it | Mouse wheel | Right stick |
| Fullscreen or a window | - | F11, Alt+Enter | - |

A keyboard's letters are named as the player's keyboard prints them (`Prompts.key_word()`: the key
in W's place reads Z on a French keyboard); the bindings are the input map's (project.godot), and
what the player is told about them is `data/ui/input_prompts.tres` (see Devices below). B never
pauses in a fight (it is a skill): only Escape, Start and the phone's back button do. The other
way round, the press that closes a menu stays the menu's: B closing the pause menu, the forge or
the bag casts no skill as the fight resumes (the hero reads no new press on the first frame after
a pause, `Player._presses_muted`).

**Attack: tap or hold.** A tap (or a press) is one basic attack at once, aimed at the closest
enemy; a press while the weapon is still swinging waits for it (0.3 s), so quick taps are never
lost. Holding no longer repeats the attack: past 0.22 s it charges the weapon's charged attack
(builds.md, "Charged attacks"), shown at the hero's feet and as twelve steps lighting up around
the attack button's rim (its thumb may hide the hero), in the element the weapon carries; full,
they beat. Letting go full unleashes it; a roll cancels it.

## Devices: touch, keyboard and mouse, gamepad

(A text field, the leaderboards' pseudonym, keeps every key while it has the focus but the up and
down arrows: MenuNav doesn't take Q, E, WASD or left and right from it. On a phone the system's
keyboard opens; with a gamepad alone the name can only be kept.)

The game plays the same with a finger, a keyboard and mouse or a gamepad, and changes what it
shows to the device in hand.

- **Which device** (`InputDevice`, autoload): the last real input decides. A screen touch is touch
  (not the touches the mouse emulates); a key, a mouse button or the mouse moved more than a few
  screen pixels is keyboard and mouse; a gamepad button, or a stick or trigger pushed past the dead
  zone (`InputPromptsDef.stick_deadzone`, 0.5: a drifting stick never takes over) is that gamepad.
  The gamepad's family comes from its name (`PadGlyphsDef.name_hints`: Xbox, PlayStation,
  Nintendo, any other): its buttons' names and colors. Unplugging the gamepad in use goes back to
  the keyboard (touch on a phone). At start: touch on a phone, the keyboard on a computer.
  `InputDevice.changed` tells the HUD, the prompts and the menus.
- **The HUD** (`Hud._apply_device()`): on touch, the joystick and the round buttons as always. On
  keys or a gamepad they are put away for the **action bar** (`ActionBar`), low in the middle: one
  slot per round button (attack, the four skills, the three belt slots), each with its key or
  button under it, its cooldown (shade falling a pixel row at a time), its charge (twelve steps on
  its lower edge) and its count; it mirrors the touch buttons (the HUD keeps those up to date shown
  or not), so both always say the same. Beside it, while something is in reach, Interact's prompt:
  its key, the thing's picture and what it does ("[E] Trade"); Interact also takes loot left on the
  ground. The bag, pause, map and perk buttons show their key on their top edge. The first touch
  brings the touch controls back. The tutorial's ring points at the bar's slot instead of the round
  button (`Hud.hint_target()`), at nothing for the joystick.
- **The mouse in a fight** (`MouseControls`): a click the HUD doesn't take (not on a button, the map,
  a hint) holds its action down: the left button attacks (auto-aim as always: the closest enemy),
  the right one rolls (`ActionPromptDef.mouse`). Never from a touch screen's own mouse events.
- **Prompts** (`Prompts`, `PromptGlyph`): a key or button is shown as a little cap in pixel art on
  the 2-unit grid of a BODY letter's pixels, its word at `Fonts.BODY`: a key (its face over a darker
  lower edge), a round face button rimmed in its color (the font has PlayStation's ✕ ○ □ △ and the
  arrows, `tools/i18n/add_glyphs.py`), a shoulder or trigger, a stick, a little mouse with its
  button lit. In a sentence it is "[E]". Every instruction that says "tap" or names a control has
  two versions, each a whole sentence translated as such: one for touch, one for keys and
  gamepads with `{action}` codes (`HintDef.button_text`, `DeviceText` in the loading tips, and in
  code `Prompts.pick("Tap to skip", "Press {ui_accept} to skip")`); the codes are filled with the
  device's key ("Press [Enter] to skip", "Press [✕] to skip"). Others are worded for every device
  ("Choose a slot to see what it does."). A hint on screen changes its words when the device does.
- **Keyboard layouts**: keys picked for their place (moving, attack, skills, belt) are bound by
  `physical_keycode`, so WASD is Z Q S D on a French keyboard and the caps say so; keys named after
  what they do (M the map, I the bag, E or F interact, C the perks) are bound by their letter
  (`keycode`), wherever the layout puts it. A cap shows a sign as itself ("," not "Comma":
  `InputPromptsDef.key_words`).
- **Menus with keys and a gamepad** (`MenuNav`, autoload): every window built on `RpgWindow` or
  `RpgDialog`, and the title screen, is a menu (the group "menu"). The one on top holds the focus:
  opening, its first button outside its header gets it (or the one it names: the codex its tab, the
  perk choice its first card, even while the cards wait out their first moments); when what covered
  it closes, or its focused button goes away (a list rebuilt), the focus comes back to the one it
  was on. Directions (arrows, WASD, D-pad, left stick: one move a push) go to the nearest button
  that way in that menu only, wrapping at its edges; a slider takes left and right; a list follows
  the focus (`ScrollContainer.follow_focus`), and a box with nothing to focus scrolls. Q / E and LB /
  RB switch tabs (buttons in the group "menu_tabs": the codex, the options, the bag). Enter, Space or A press;
  Escape or B go back (the screens' own Back: `GameMenus.back()`, `TitleScreen.back()`); Escape on
  the bare title quits nothing. The buttons Back stands for show its key: a window's Close beside
  it, a dialog's Resume, Later, Leave and Close inside on the left (`PromptGlyph.badge()`; on touch
  nothing, the phone's layout unchanged). A gold pixel frame (corner brackets, breathing by a pixel) shows
  around the focused button while keys or a gamepad drive (`InputDevice.navigating`), never on
  touch or after the mouse moved; the mouse hovers and clicks as always. The frame stays inside
  the boxes that clip its button (a list's scroll, a column), give or take its own width: a
  button scrolled out of its column has none (`MenuNav.frame_area()`). A codex page opened with
  keys starts at the top of its columns (`MonsterPage.scroll_to_top()`: its first button was
  focused before the columns were laid out, and the column used to scroll it just out of sight). Buttons are focusable
  again everywhere but the HUD, where nothing keeps the focus (Space attacks). The debug panel too
  (an `RpgWindow`, its tabs on Q / E and LB / RB).
- **Someone speaking** (`DialogueBox`, `src/ui/dialogue/`; presentation.md, "The Vigil-Keeper
  and the keepers"): a face, a name, words typed letter by letter. A tap or a click on it, Enter,
  Space or a gamepad's A write the page out, then go on; a touch and the click the screen makes of
  it count once (`TAP_GAP_FRAMES`). Paged (the shrine's `DialogueScreen`, a menu of its own: the
  box holds the focus, a tap anywhere goes on, Back closes it, the focus comes back to her), the
  "more" sign is a bobbing gold arrow on touch, the accept key's cap on keys and pads. Stacked (the
  end screen) it types everything by itself and never holds the buttons: accept is its own only
  while it writes. The Vigil-Keeper on the title screen is a button like the others (the arrows
  reach her; Enter or A on her opens her words).
- **The Controls page** (Options > Controls): what does what on the device in use, read-only: each
  control of `input_prompts.tres` with every key and mouse button (caps), the gamepad's buttons in
  its family's names, or how it is done by touch. Picking up another device turns the page.
  Remapping is not there yet.

## Screens: windows, sizes, scale

- **Windows** (computers): resizable; **Fullscreen** in Options (Screen), or F11 / Alt+Enter
  anywhere (`Settings.fullscreen`, saved). The keys do only that, in any menu: `Settings`'
  WindowKeys node stays the root's last child, so it reads them before any menu's `_input` (Godot
  goes from the last node up) and the bag never takes Alt+Enter for Enter, nor a card F11 for a skip.
- **Scale** (`PixelGrid`): the UI is laid out at 1280x720 and the canvas grows with the screen's
  shape (`canvas_items`, expand). Its scale is rounded down to a step of 0.5 (x1 from 720 to 1079
  lines, x1.5 at 1080, x2 at 1440, x3 at 2160), where BODY letters keep whole pixels, and the canvas
  takes the rest (1366x768 lays out at 1366x768, 21:9 at 1720x720, 16:10 at 1280x800). A screen too
  small for x1 (1024x768) keeps its own scale (x0.8: letters a little uneven). The camera zooms in
  by what the rounding took off, so a floor is framed as before on every screen
  (`PixelGrid.world_zoom()`, `GameCamera`).
- **Interface size** (Options > Screen): Big (the largest step that fits), Medium, Small: one or two
  steps smaller, never under x1, for more room on a big monitor; the floor's framing stays
  (`Settings.ui_size`, saved).
- The layouts are checked at 1280x720, 1366x768, 1920x1080, 2560x1440, 1280x800, 3440x1440,
  1024x768 and the phones' 2340x1080 and 1540x720: nothing out of the screen, no HUD control over
  another, on touch and on keys (`PcTests`). French runs 20-30% longer: in French, at 1280x720,
  1540x720, 2340x1080 and 2548x1296, every in-run panel is checked with its longest words
  (`PcTests._test_french_panels()`: the bag, the merchant saying why it can't sell, the forge
  taking out the longest rune's name or with no room for it, the four encounters, the pause, the
  options, the codex's tabs and every monster's page, the longest fragment, the ending's choice,
  the longest perks). Long words wrap; letters never go under `Fonts.SMALL`.

## Nothing opens by itself

Walking up to someone or something never opens a window, and a level up never does either: the
player decides when the fight stops.

- **Interact** (input action `interact`): standing by the merchant, the forge, an encounter or a
  pact door's stele, a round button pops in above the skills (left of the third one, where the
  thumb on the attack button reaches it; `InteractButton`), with the thing's picture and what
  tapping does on a plaque under it: **Trade** (the merchant), **Forge** (the smith), the
  encounter's own word (`EncounterDef.verb`: **Drink** at the spring, **Offer** at the blood
  altar, **Talk** to the grinning spirit, **Kneel** before the statue), **Read the pact** (a pact
  door, until it is sworn), **Read** (a fragment of the past lying on the floor: it opens in a
  panel over the paused game, a tap closes it; presentation.md, Boss stories). A soft gold ring lies at the thing's feet while the button is its.
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
- **Pause menu** (the II button, Escape, a gamepad's Start, or the phone's back button): resume, options, save and quit,
  give up the run (two taps). Coming back to the app, the game waits paused.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  five volumes (**General**, **Music**, **Interface**, **Combat**, **Ambience**: which sounds
  each one sets is in presentation.md, SFX; letting go of a slider plays a sound of what it sets: a
  click, a hit, coins; settings files from before, with one sound volume, give it to Interface,
  Combat and Ambience), screen shake, size of the touch controls, **vibrations** (big shakes,
  hits you land, crits; `Settings.vibrate()`; exported Android builds need the Vibrate permission),
  **fixed joystick** (it stays in its corner and starts only when touched there, instead of
  appearing under the thumb), **battery saver** (30 FPS cap, `Engine.max_fps`), **fewer effects**
  (half the particles in `Vfx.burst`; no heat, cold or pull distortion, no bloom, halos' inner
  band only), **screen flashes** (lightning lights the screen for one frame, at most 3 a second;
  off for players sensitive to flashes), **run timer** (on/off), **auto loot** (All / Better only /
  By hand, three buttons, the picked one's rule spelled out under them; see design/loot.md),
  **boss stories** (Full / Short / Off, three buttons the same way: the cinematic before a
  warden's fight, presentation.md "Boss stories"),
  **tutorial hints** (on/off) and **Replay tutorial**, on a computer **fullscreen**, the
**interface size** (Big / Medium / Small), and the **language** (English / Français,
  see Languages). The window (`OptionsPanel`, built in code on `MenuWindow`) groups them
  (Sound, Touch controls, Screen and battery, Loot, Story, Tutorial), each with a one-line "what it does",
on a Settings tab beside a Controls tab (the keys and buttons of the device in use, above);
  on/off options are big switches, and tapping an option's name flips it too.
- **Loot left on the ground** (auto loot, or no room in the bag): while the hero stands on it, a
  small board low in the middle of the screen, above the belt and skill buttons (`LootPrompt`,
  built by the HUD from `Events.loot_offered` / `loot_left`), shows its slot, its name in its
  rarity, its type and the first changes against what is worn (green / red), with **Take**; with
  no room, the button reads "Open the bag". Only the button catches touches (the joystick's thumb
  may slide under the board). A full bag also says so in a toast.
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
over a menu or a big banner. A tap or a click (or OK) closes it. A hint about a control says it
in the device's words ("Tap the big button" / "Press [Space]", `HintDef.button_text`).

- **First steps**: move (it stays until you have walked a few tiles), then the sealed stairs; when
  a monster first sees you, attack (tap; until you swing), then roll, then the weapon's two
  skills, then the charged attack (pointing at the attack button until one is unleashed).
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

## Text

The font (`assets/fonts/normal_font.ttf`) is pixel art on a 9-pixel em (2048 units, 227.5 a
pixel): capitals 6 pixels high, strokes 1 pixel wide. It is drawn sharp (no antialiasing, hinting
or subpixel positioning), so a letter stays whole only when one of its pixels covers a whole
number of screen pixels; otherwise some rows and columns double and others vanish, and letters
look cut. The UI is laid out at 1280x720 and stretched (`canvas_items`): x1 on a 720-line window,
x1.5 on most phones (1080 lines), x2 on 1440.

- **Sizes** (`Fonts`, `src/core/fonts.gd`), multiples of 18 (2, 4, 6 UI pixels a font pixel: whole
  at x1, x1.5 and x2): **`Fonts.BODY` 18** for everything read (sentences, notes, buttons, names,
  headings in a panel), **`Fonts.TITLE` 36** (the story, a difficulty's or a monster's name, big
  numbers, the Descend and Resume buttons), **`Fonts.HUGE` 54** (the game's name, act and curse
  cards, the Threshold's countdown).
  **`Fonts.SMALL` 12** only for fine print BODY cannot fit (a slot's item level and empty-slot
  words, the difficulty cards' lists, the oath cards, a perk card's level and family bonus and
  the perk choice's two rules under and over the cards, the Daily button's second line, the Tree
  of Souls' branch lines): whole on phones (2 screen pixels a font
  pixel), a little uneven on a 720-line screen. No size in between: hierarchy comes from color
  (gold headings, dim notes), ribbons and boards. The unit, title and game suites hold every
  scene, the theme and the panels built in code to `Fonts.SIZES`.
- **Outline**: one font pixel (`Fonts.outline_size()`: 8 at BODY, 16 at TITLE, 24 at HUGE), set by
  `UiSkin.label()`, `UiSkin.set_text_style()` and the theme's Label. It is drawn under the letters
  and never eats a stroke. Dark words on the orange buttons have none.
- **Drawn by hand** (`Fonts.draw()`: damage numbers, signs and names over the world, the HUD's
  round buttons, slots, the Tree of Souls): the size is counted in UI units whatever the camera's
  zoom, and the text is put on a whole screen pixel, with the same outline. Damage numbers pop in
  at TITLE for an instant, then settle at BODY (no in-between scale).
- **Half pixels**: at x1.5 an odd UI position falls between two screen pixels, where every pixel
  samples a letter's texture right on an edge and picks a side by rounding luck. `PixelGrid`
  (autoload) shifts the whole screen a quarter of a pixel, which takes whole and half positions
  off those edges.
- A wrapped line never splits a stat from its number (the HUD's info line uses unbreakable
  spaces).

## Bag, forge and the other in-run screens

The bag, the forge, the shop, encounters, perk choices, the pause menu and the end of a run are drawn in the game's RPG skin (`UiSkin`, `src/ui/common/`): a wooden
board with a gold ornate border (`RpgWindow`), the title on a red ribbon, dark recesses for each
column, scroll bars and sliders in the same pixel art (`assets/theme/main_theme.tres`, pieces in
`assets/ui/scroll/`: a dark groove, a riveted gold bar, a gold fill and a gold knob), and items in square slots (`ItemSlot`): the icon at a whole-pixel scale, a frame in the
item's rarity color (a rune's in its family's), how many, and a weapon's rune sockets as little
stones lit in their runes' colors. The selected slot pulses gold.

- **Bag** (`InventoryPanel`, built in code): the hero, the weapon / head / body slots, the belt and
  the stats on the left (the hero is his own rig, `HeroPortrait`: dressed as his body in the
  world, his weapon slung on his back with its elements, his armor with its rarity's trim and its
  affixes' marks, idling at 4 screen pixels per art pixel, 20x22 art pixels); the bag in the middle, one compartment at a time (its tab), and under it
  **Dismantle the worse (n)** (the tab's worse gear); the picked item's card on the right (name in its rarity,
  type, every line of its details, its rune sockets, for gear in the bag "Dismantle value: 12
  gold") with its actions' buttons. Dismantle the worse opens a confirmation (`RpgDialog`): how
  many and the gold, their slots, "what you wear, potions, runes, tomes and keys are never
  touched", Dismantle: +n gold / Keep them. Gold won flies as coins to the counter (`GoldBurst`)
  with the coin sound.
  - **Compartments and their tabs** (`Inventory`, `BagCategorySet`,
    `data/items/bag_categories.tres`; `BagTab`): the bag is six compartments, each with its own
    places (loot.md, "Room in the bag"): **Weapons** (Armes), **Armors** (Armures), **Runes**,
    **Tomes & Scrolls** (Grimoires & Parchemins: the tomes and the Scroll of Fire),
    **Consumables** (Consommables) and **Other** (Divers: keys, and whatever no compartment
    claims; its tab hidden while empty). A row of wooden tabs over the grid, each with its icon,
    how many items it holds (a stack counts all of its own; red when the compartment is full) and
    a small gold gem while something new waits in it; under them the open tab's name and its own
    places ("Runes  3 / 16", red when full), between its keys on keys and gamepads ([Q] Weapons
    16 / 16 [E], [LB] ... [RB]). A compartment holding more than its places (a run saved before,
    a compartment made smaller) keeps it all and says so under it ("More than it has room for:
    make room before anything new goes in."). Tap a tab, or Q / E, LB / RB (`MenuNav`,
    "menu_tabs"). The tab picked stays picked until the run ends (the bag opens on it); a new
    run, Restart included, opens it on the first tab with nothing seen yet.
  - **In a tab**: a 4-column grid, one slot per stack with its count ("x3"), the rarest first,
    then weapons, helms, body armors (a rune's family, a consumable's kind), the higher item
    level, then by name; after them the compartment's free places (empty slots). A slot new since the bag
    was last closed (or the item last picked) has the gold gem in its corner; what is worn or on
    the belt is never new.
  - **Actions** (`BagAction`, `src/ui/inventory/actions/`): Equip / Unequip / Learn / Use (not
    for runes and keys), To belt / To bag (consumables), Drop (the bag's items), Dismantle (gear
    in the bag, never what is worn). Each is a button on the card (touch, mouse, the focus), and
    the first, third and fourth also a key on the item itself, no menu in between: Enter or
    Space / a gamepad's A uses it (only on an item's slot: on a button, Enter presses the
    button), X or Delete / X dismantles, G / Y drops; each button shows its key or button over
    its top edge (`PromptGlyph.badge`, nothing on touch). A right click on a slot uses it too. A
    Rare or Epic piece, or one with a rune set, asks a second press before it breaks
    (`DismantleRules.needs_confirm`): the button says "Sure?" and the card "Press [X] again to
    break it: +40 gold" ("Tap again..." on touch); Back (Escape, B) takes the question back
    first, picking another item does too. Commons and Magic pieces go at once, one of a stack
    per press. After one of a stack is used, dropped or dismantled, the rest stays picked; with
    keys, the focus goes on to the slot that took the gone stack's place, so X X X goes through
    a tab of junk. The buttons flow to a second row when they don't fit (French on a 1280-wide
    canvas), and the card's details scroll with the right stick (its cap shows while there is
    more), the mouse wheel or a finger.
  - **Keys and gamepads**: the focus is the pick (moving onto a slot shows its card; on touch and
    with the mouse a tap or click picks). The bag opens on the open tab's first slot; switching
    tabs puts the focus on the new tab's first slot. The empty places can take the focus too
    (nothing to do there), so the arrows never jump out of the grid.
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
  the souls earned and what they buy. After a death, the Vigil-Keeper's tale and advice sit under
  the title in her `DialogueBox` (presentation.md); with nothing for her to say, the story's line.
- **Keepers' words**: the shop and the forge open on a line of the merchant's or the smith's
  (their dialogue's, else a greeting) in quotes beside their face; the grinning spirit's line
  shows in place of its encounter's description, in its color (the panel keeps its height on a
  720-line screen), and the outcome takes its place when a choice is made.
- **Codex, Voices** (*Paroles*): what each speaker said and is kept, by speaker, and how many
  lines are still to hear.
