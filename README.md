# Le Puits des Âmes

*Under the village of Kagari lies an old well. One night without a moon, it woke up and took the
villagers' souls. Only the ninja keeping watch at the shrine was spared. Take the lantern, go down,
bring the souls back.*

Real-time action roguelike for Godot 4.7 (GDScript, Compatibility renderer).
Procedural floors lit by torches and lanterns, traps, holes, crumbling floor and quicksand,
ambush rooms, trapped chests, breakable crates and explosive kegs, elite monsters,
monsters with telegraphed attacks, a boss every 3 floors, melee and ranged weapons,
armor you can see on the hero, consumables, loot, XP, a perk to choose at every level up, and
skills that come from what you hold and what you learn: play a mage, a warrior, a paladin, or a mix. Plays with touch controls,
keyboard or gamepad.

## Project layout

```
assets/              Art, audio, fonts and the UI theme (Ninja Adventure pack)
  characters/          Hero and monster sprite sheets (4 directions, frame by frame), bosses/
  weapons/             Weapon icons + attack/ sheets (the weapon in hand, per direction and frame)
  fx/                  Sprite-sheet effects: slashes, claws, explosion, smoke, magic, flames, light.png
  props/               Crates, vases, barrels, powder kegs, lanterns, chests, trap pieces, holes, quicksand
  projectiles/         Arrows, fireballs, magic bolts
  items/               Item icons
  tiles/               Dungeon floors, cliffs and walls
  ui/                  Wood UI, round buttons (sphere/), icons, skill icons (skills/), perk icons (perks/), emotes
  fonts/               Pixel font
  audio/               Sound effects (sfx/), music (one track per floor theme) and jingles
  shaders/             Rig (hit flash + death dissolve), screen look, damage vignette
  theme/               main_theme.tres: pixel UI theme used by every Control
data/                Game content as .tres resources (no code)
  content_db.tres      Index of everything that can spawn
  player/              Starting stats, kit, skills, leveling
  dungeon/             The run (acts/), floor size, difficulty curve, floor themes (themes/)
  visuals/             SpriteFrames: hero.tres, monsters/, weapons/ (the animations themselves)
  audio/               Sounds as AudioStreamRandomizer (variations + pitch) and sound_bank.tres
  monsters/            One file per monster type, bosses in bosses/
  perks/               Level-up perks (common/) and boss relics (relics/)
  upgrades/            Shrine upgrades (bought with souls between runs)
  difficulties/        Easy, Normal, Hard, Nightmare
  story/               story.tres: the game's name, the intro, victory and death texts
  props/               Breakable props and the lantern
  hazards/             Traps, arrow traps, holes, crumbling floor, quicksand and mud
  chests/              Chests (some trapped) and the big chest of ambushes
  elites/              Elite affixes (Swift, Vampiric, Explosive...)
  affixes/             Item affixes for Magic, Rare and Epic equipment (Sharp, of the Bear...)
  shop/                The merchant (stock, prices, look)
  encounters/          Spirit Spring, Blood Altar, Grinning Spirit, Warden's Statue
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  items/tomes/         Skill tomes (teach a spell)
  skills/              Player, monster and boss skills
src/
  autoload/            Events (signal bus), Sfx (sound player), HitStop (impact freeze), Profile (save), Settings (options)
  core/                Small shared helpers (physics layers, weighted random)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    passives/            Building blocks for perks (on hit, on kill, on dash...)
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
    hazards/             HazardDef > TrapDef > ArrowTrapDef, PitDef, QuicksandDef, HeatSourceDef, DarkRoomDef
  dungeon/             Map data, generator, drawing
  world/               World (owns the current floor), FloorPopulator, BossArena, AmbushRoom, RoomGates, PitLayer
  entities/            Actor (shared base), Player, Monster, Projectile, ItemPickup, Stairs, Prop, Trap,
                       hazards/ (Chest, CrumblingFloor, Quicksand, HeatSource, DarkRoom)
  components/          Inventory, Equipment, SkillSet, PerkSet, StatusSet (burn...)
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack, Cast)
  vfx/                 Particles (particles/), sprite-sheet FX, emotes, afterimages, damage numbers; Vfx helpers
  ui/                  Title screen and shrine, story, act cards, HUD and minimap, touch controls, inventory,
                       perk choice, pause menu, options, end of run
  game/                Game: main scene, run and floor flow; RunSave (the run in progress on disk)
tests/               Headless test suite with a bot that plays the game
```

**Rule of thumb:** `data/` says *what* exists, `src/definitions/` says *what a thing can have*,
the rest of `src/` says *how it behaves*. Balancing never requires touching code.

## How things fit together

- **Game** creates the Player, asks **World** to build each floor and handles pause and game over.
- **World** generates a `DungeonMap`, builds wall collisions and pathfinding, then lets
  `FloorPopulator` spawn monsters and items picked from `ContentDB` by depth.
- **Actor** (base of Player and Monster) handles stats, HP, attacks, knockback, dashes and hit feedback.
  Final stats = base stats + equipment bonuses + timed buffs.
- **Weapons** are shared: a monster attacks with a `WeaponDef` exactly like the player.
- **Skills and consumables** are both lists of `Effect` resources
  (damage area, projectile, heal, dash, buff). New effect = new class extending `Effect`.
- **Monsters** are driven by a `StateMachine`: Idle (wander) > Chase (path or straight line, use skills)
  > Attack (telegraphed wind-up, strike, recovery). Skills with a `cast_time` go through Cast
  (glow, red circle, cast animation) so the player can dodge them.
- **Game** offers the perk choices (pausing the game) and reacts to boss fights through `Events`.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path.

## Game feel

- **VFX**: hand-drawn sprite-sheet effects (slashes, claws, explosions, smoke, magic circles,
  "!" emote when a monster spots you) plus pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector), dash afterimages, animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **SFX**: the `Sfx` autoload plays world sounds (positional) and UI sounds. Weapons have attack and hit
  sounds, monsters hurt and death sounds, skills and consumables a use sound; everything else comes
  from `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Buses: Master > SFX, UI, Music, Ambience (`default_bus_layout.tres`). Each floor theme has its own music.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: each floor theme has an `ambient` darkness (a `CanvasModulate`); the hero's flickering torch,
  room lanterns, the hero's shots and fireballs, explosions and magic circles light it up (2D lights).
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit and
  dissolves monsters pixel by pixel when they die; lights fall off in flat, dithered steps
  (`assets/fx/light.png`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.
- **Ambience** (`AmbienceDef`, `data/dungeon/ambience/`, set on each floor theme): footsteps that sound
  like the floor (dull in the caves, echoing in the crypt, crunchy in the ruins) and footprints that
  fade, a looping background (wind, storm), random distant sounds around the hero (drops, whispers,
  chains, roars), the SFX bus reverb of the place, floating particles (dust, ghost wisps, embers) and
  drifting pixel fog. Played by `Ambience` (`src/world/ambience.tscn`) on the Ambience bus.
  Big monsters and bosses shake the ground when they walk. Under 30% HP a heartbeat plays and the
  music gets muffled (a low-pass filter on the Music bus). The screen fades to black on the stairs.

## Dungeon

- **Walls** are cliffs drawn from a 16x16 tileset (`DungeonView`): plateau edges, inner corners,
  cliff faces. The generator smooths every floor so only shapes the tiles can draw remain
  (no wall one cell thick, no walls touching by a corner).
- **Props** (`data/props/`): crates, vases and barrels break under any attack and may drop loot;
  **powder kegs** blink then explode, hurting everyone (you too) and setting off other kegs.
  Explosions you trigger give you the XP of what they kill. Props block movement, sight and shots.
- **Hazards** (`data/hazards/`): each act has its own list (`ActDef.hazards`), and every hazard
  knows how to lay itself out in a room (`HazardDef.place()`). They hurt monsters too: lure them in.
  - **Traps**: rows of **spikes** firing in a wave, **pressure plates** that strike when stepped on,
    **flame vents** that also set you on fire, **arrow traps** (a plate wired to a slit in a wall:
    arrows fly across the room). They always warn before they strike.
  - **Holes**: anything that walks or is knocked in falls. Monsters are gone (you get the XP if
    you pushed them), the hero climbs out where they last stood safely and loses 15% HP.
    Rolling carries you over; flying monsters (bats, ghosts...) don't care. Walking monsters
    steer around holes, so knock them in.
  - **Crumbling floor**: cracked tiles that hold until someone stands on them, then give way.
  - **Quicksand** (ruins) and **mud** (caves): very slow to cross, and they hurt if you stay.
  - **Scorching ground** (ruins, `HeatSourceDef`): glowing cracked floor. Standing on it heats
    you up (see Temperature below); step off and you cool down.
  - **Dark rooms** (crypt, ruins, deeper caves, `DarkRoomDef`): a whole room plunged in darkness;
    you only see right around you, and the monsters (and traps) inside hide in the black.
  - Hazards are never placed where they could cut the stairs off.
- **Chests** (`data/chests/`): walk up to one to open it. Some are trapped: they blow up or let
  monsters out (and keep only one item). A trapped chest rattles now and then...
- **Temperature** (`BodyTemperature`, `dungeon_config.tres` > Temperature): the hero has a body
  temperature from -100 (frozen) to 100 (burning up), shown under the XP bar when it is not
  normal, with frost (or a burning haze) creeping in from the screen's edges
  (`temperature_overlay.gdshader`). On **Frozen Depths** floors, a wing of a few rooms next to
  each other is frozen solid (`FloorEventDef.zone`, `frozen_ground.tres`): ice on the ground
  (`frozen_ground.gdshader`), snow falling, and the cold creeping in while you are there. The
  **campfires** in it bring you back to normal. Cold slows you down; frozen or burning up, you
  take damage every second. Away from cold and heat, it goes back to normal by itself.
- **Ambushes**: a floor may have a quiet, empty room. Walk in and spikes close the exits,
  monsters pour in, wave after wave, the last one led by an elite. Clear it for a big chest.
- **Elites** (`data/elites/`): any monster can be one, more often deeper and on harder
  difficulties. They glow in their color, show their name, are bigger and tougher, give 3x XP
  and always drop an item. Their affix is a perk, like the hero's: **Swift**, **Vampiric**
  (heals when hitting), **Explosive** (blows up when it dies), **Armored**, **Venomous**
  (poisons), **Spiked** (hurts who hits it).

## On a phone

- **The run is saved** (`RunSave`, `user://run.json`) when a floor begins and whenever the app goes
  to the background (a call, switching apps...). The title screen then offers **Continue**: same
  depth (a fresh floor), the hero exactly as saved (level, stats, gear, bag, perks, spell, perk
  choices left open). Dying erases it. "Save and quit" in the pause menu does the same on purpose.
- **Pause menu** (the II button, Escape, or the phone's back button): resume, options, save and quit,
  give up the run (two taps). Coming back to the app, the game waits paused.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  music and sound volumes, screen shake, size of the touch controls, **vibrations** (big shakes,
  hits you land, crits; `Settings.vibrate()`; exported Android builds need the Vibrate permission).
- **Minimap** (`Minimap`): rooms are revealed when you walk in, corridors around you; it shows holes,
  the stairs, unopened chests, a running ambush and the boss. Tap it for the whole floor.

## Codex: bestiary, achievements, runs

The title screen's **Codex** (`CodexPanel`) has three tabs:
- **Bestiary**: every monster and boss; unknown ones are black silhouettes until you slay one.
  The profile counts kills per monster (`Profile.kills_by_monster`).
- **Achievements** (`data/achievements/`, `AchievementDef`): a goal on one of the profile's counters
  (kills, elites, wardens, kinds of creatures, depth, victories on Hard / Nightmare / ascension,
  monsters pushed into holes, chests, Epic items, encounters, gold or level in one run), with its
  progress. Reaching it pays souls, with a note at the top of the screen.
- **Runs**: the last 20 runs (difficulty, depth, level, kills, weapon, what ended it, souls).

## Story and identity

Everything is tied to one idea: **souls**. The Well stole the souls of the hero's village; the
monsters down there feed on them; the three bosses are its wardens.

- **The story** (`data/story/story.tres`, `StoryDef`) is told page by page before the first run
  (`StoryScreen`: typed out, tap to go on, Skip), and again from the title screen's Story button.
- **Every act opens with a title card** on black (`ActCard`, `ActDef.lore`): its name and a line of story.
- **Every kill frees a soul**: a little light rises from the body and flies into the hero's lantern
  (`SoulWisp`); bosses free a dozen. The HUD counts the souls of the run, which go to the
  **shrine** at the end: it turns them into permanent upgrades.
- Death and victory screens tell how it ended (`StoryDef.death_lines`, `victory_text`).

The game's texts are in English; the name stays French. The project's internal name is still
"Mini Roguelike" (`project.godot`), on purpose: the save file's folder depends on it.

## The belt

Potions, bombs and scrolls don't take room in the bag: they go on the **belt** (`Belt`),
3 slots of one kind each, stacking up to 9. Each slot has its own button on screen, so you choose
what to drink or throw. When the belt is full, the rest goes to the bag; the bag screen moves
consumables between the two ("To belt" / "To bag"). The merchant buys from the belt too.

## Loot, gold and the merchant

- **Rarity**: found equipment can come out **Magic** (blue, 1 affix), **Rare** (yellow, 2) or
  **Epic** (purple, 3), with more damage and bonuses (`ItemRarity`). Affixes (`data/affixes/`,
  `ItemAffixDef`) add stats ("Sharp", "of the Bear"...) or set enemies on fire, poison or slow
  them ("Burning", "Venomous", "Frozen"). Rare and Epic items on the floor shine with a beam.
  `LootRoller` makes rolled copies; the plain .tres is the Common version. Chances grow with depth
  (`dungeon_config.tres` > Loot) and with the source: elites, chests and bosses drop better.
- **Gold** drops from monsters (always from elites and bosses), chests and sometimes crates, and
  flies to you. It lasts one run. Potions and other consumables you already carry plenty of
  (4 of the same, `consumable_carry_cap`) drop as gold instead: no bag full of potions.
- **The merchant** (`data/shop/merchant.tres`, `Merchant`, `ShopPanel`) waits in a quiet room on
  some floors: walk up to him to buy equipment (better than average), potions and sometimes a
  tome, or to sell what you carry. Every item has a `value`; the price grows with rarity and depth.

## Special floors and bosses

Bosses have a lot of HP and stand their ground: they ignore 95% of the knockback, so no weapon can
keep one away from you (`MonsterDef.knockback_resistance`). Big monsters resist half of it, and
elites at least half.

- **Special floors** (`data/floor_events/`, `FloorEventDef`): 30% of the normal floors after the first
  (`dungeon_config.tres` > Floor events) are announced when you arrive: **Haunted** (elites, dim),
  **Treasure Vault** (chests and gold, more traps), **The Swarm** (hordes of weak monsters),
  **Pitch Dark** (very dark, better loot), **Quiet Halls** (few monsters, the merchant, encounters),
  **Blood Moon** (monsters hit harder, double gold), **Frozen Depths** (a frozen wing:
  find the campfires; better loot and gold). They multiply monsters, HP, damage, elites,
  light, chests, hazards, encounters, gold and loot quality.
- **Two bosses per act** (`ActDef.boss` + `other_bosses`): each run draws one per act (saved with
  the run; the title screen shows both). King Slime or the **Giant Frog** (leaps, poison spit, calls
  its brood); Demon Cyclops or the **Weeping Spirit** (a freezing wail, blinks, calls lost souls);
  Crimson Tengu or the **Red Samurai** (arcs of fire, dashes, a ring of fire).

## Encounters

Some rooms hold something strange (`data/encounters/`, `EncounterDef`): walk up to it and choose.
Each choice has a cost (gold, a part of your max HP) and outcomes drawn by weight
(`EncounterChoice`, `EncounterOutcome`: heal, hurt, gold, an item of some quality, a choice of
perks or relics, monsters or elites, any `Effect`). Each can be used once.

| Encounter | Choice | What may happen |
|---|---|---|
| Spirit Spring | Drink | healed (55%), a strong buff for a minute (25%), cursed water hurts (20%) |
| Blood Altar | Offer your blood (-15% max HP) | a choice of relics |
| Grinning Spirit | Pay 30 / 80 gold (more each floor) | an item, sometimes a great one... or it laughs and runs |
| Warden's Statue | Pray | a choice of perks (50%), or two elites (50%) |

## Skills and builds

There are no classes: what you hold and what you learn decides how you play.
The hero has **4 skill buttons**:

| Button | Skill | Comes from |
|---|---|---|
| 1 | Roll | always (`PlayerDef.innate_skills`) |
| 2, 3 | two weapon skills | the equipped weapon (`WeaponDef.skills`) |
| 4 | a learned spell | the last **skill tome** you read (`SkillTomeDef`) |

| Style | Weapons | Their skills |
|---|---|---|
| Warrior | Katana, Sai, Lance, Battle Axe, War Hammer, Pickaxe, Greatsword, Whip | Whirlwind, Iaido Dash, Flurry, Shadow Step, Piercing Thrust, Spear Throw, Cleave, Ground Slam, Fissure, Rock Spike, Sundering Blow, Lash, Battle Cry |
| Ninja | Ninjaku, Shuriken (3 stars a throw) | Kunai Fan, Shuriken Storm (a ring of 16), Shadow Step |
| Duelist | Rapier (fast, crits) | Riposte (leap back, then crits and speed), Piercing Thrust |
| Archer | Bow (arrows pierce one enemy) | Volley (5 arrows), Arrow Rain (4 hits on an area ahead) |
| Mage | Spark Wand, Frost Staff, Ember Tome | Spark Nova, Arcane Bolt, Frost Nova (slow), Ice Shards (slow), Fireball, Fire Wave (burn) |
| Paladin | Templar Sword | Smite (damage + heal), Holy Shield (DEF + heal) |

The weapon in the hero's hand is animated frame by frame with the attack. For weapons without a
hand-drawn sheet, the sheet is baked from the item sprite rotated around its handle (a swing,
a heavy swing, a thrust, a lash or an aim; 4 directions x 4 frames, `assets/weapons/attack/`).

Tomes (found on the floor, dropped by casters and bosses) teach Holy Light, Battle Cry, Frost Nova,
Fireball, Blink or Thunder, whatever weapon you hold: a warrior can heal, a mage can blink.
Swapping weapons swaps buttons 2 and 3 (new skills start on a short cooldown, so swapping can't skip
cooldowns); the roll and the learned spell stay.

Skill damage uses **skill power** (`power x (1 + skill_power)`), and cooldowns shrink with
**cooldown reduction** (60% max): the Arcane Focus, Arcane Power, Devotion perks and the Sage's Codex
relic push a caster build; the Shadow Cloak gives some cooldown reduction.

A skill is a list of `Effect`s, each with an optional **delay** (combos: Flurry is three stabs,
Fissure three bursts running forward). Effects: damage area (with a sheet effect, a status, an offset),
projectiles (fans, rings, pierce, explosions, status), dash, dash strike (cuts everything along the
path), heal, buff, summon. Statuses (`OnHitStatus`): burn and slow.

## Perks and relics

Every level up pauses the game and offers **1 perk out of 3**. Taking a perk again levels it up
(up to its `max_stacks`). Bosses drop a choice of **relics** (rare perks).

A `PerkDef` (in `data/perks/`) is stat bonuses + a list of `Passive`s, both multiplied by its level:

| Passive | Hook | Used by |
|---|---|---|
| `HealOnKillPassive` | on kill | Vampirism |
| `ThornsPassive` | on damaged | Thorns |
| `BurnOnHitPassive` | on hit | Ignite (burn status) |
| `CritShockwavePassive` | on hit (crits) | Thunderclap |
| `DashShockwavePassive` | on dash | Shock Roll |
| `LootOnKillPassive` | on kill | Fortune |
| `ExecutePassive` | before a hit | Executioner |
| `ExtraProjectilesPassive` | every volley | Multishot |
| `CheatDeathPassive` | before dying | Phoenix Feather |

Damage caused by a passive (burn, thorns, shockwaves) is a *secondary* hit: it never triggers
other on-hit perks, so effects can't chain forever. Perks are stored per actor in a `PerkSet`,
so monsters could use them too (elites, later).

## The run

A run is **3 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its look, its own monsters and a boss on its last floor. Beating the last boss **wins the run**;
you can then keep going in endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. Mossy Caves | 1-3 | Cave Mouse, Blue Bat, Slime, Red Spider, Spore Cap, Viper, Acid Larva, Burrower, Giant Slime, Shell Guard, Thief Racoon | King Slime |
| II. Haunted Crypt | 4-6 | Skeleton, Dark Sorcerer, Spirit, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull, Thief Racoon, Brood Mother | Demon Cyclops |
| III. Burning Ruins | 7-9 | Fire Shaman, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus, Bomber, Brood Mother, Shell Guard | Crimson Tengu |

Monsters are data (`MonsterDef`): stats, a weapon (its `on_hit` status poisons, burns or slows),
skills (telegraphed casts: spore clouds, dives, charges, ink rings...), and what happens when they
die: a **death burst** (a flame spirit explodes, a frost skull freezes everything around, after a
short warning) or **death spawns** (a giant slime splits in two).

Some fight differently:
- **Shell Guard**: its shell (`MonsterDef.front_guard`, `guard_arc`, the silver arc in front of it)
  blocks most of the damage and push of blows from the front. It turns slowly: roll behind it.
  Burns, poison and blasts go around the shell.
- **Thief Racoon** (`steals_gold`, `flee_time`): each hit takes some of your gold, then it runs
  away. Slay it to get the gold back, with interest.
- **Brood Mother**: keeps her distance and lays red spiders (a `SummonEffect` skill). Kill her first.
- **Bomber**: keeps away and lobs bombs that blow up where they land (a projectile skill with an
  `explosion_radius`).
- The **Fire Shaman** heals the monsters around it.

## Difficulty

Pressing Play asks for a difficulty (`data/difficulties/`, `DifficultyDef`). Every value multiplies
the normal game:

| | Easy | Normal | Hard | Nightmare |
|---|---|---|---|---|
| Monster HP | x0.7 | x1 | x1.3 | x1.7 |
| Monster damage (attacks, skills, traps, bursts) | x0.6 | x1 | x1.35 | x1.8 |
| Time to dodge (wind-ups, casts) | x1.35 | x1 | x0.85 | x0.7 |
| Monster speed | x0.9 | x1 | x1.05 | x1.15 |
| Extra monsters per room | 0 | 0 | +1 | +2 |
| Boss HP | x0.7 | x1 | x1.3 | x1.6 |
| Elite chance | x0.5 | x1 | x1.6 | x2.5 |
| Drop chance | x1.4 | x1 | x1 | x0.9 |
| Heal on each new floor | 25% | - | - | - |
| Light | brighter | - | darker | much darker |
| Souls | x0.5 | x1 | x1.6 | x2.5 |

Easy, Normal and Hard are open; **Nightmare unlocks after a win on Hard** (`unlocked_by`).
**Ascension**: a Nightmare win opens **Nightmare +1**, a +1 win opens +2, up to +10
(`data/ascension/`, `AscensionDef`, picked under the difficulty cards). Each level adds its twist
on top of the ones below: tougher monsters, harder hits, more elites, higher prices, one more
monster per room, faster monsters, tougher bosses, darker floors, less max HP... and 10% more
souls per level.
The last choice is remembered, shown in the HUD and on the end-of-run screen.

## Between runs

The game opens on the **title screen** (`src/ui/title/`): play, visit the shrine, see your records.
There is no class to pick: everyone starts the same, and becomes who they want during the run.

Every run ends (death or victory) with **souls**: 1 per kill, 5 per floor, 20 per boss, 100 for a
victory. At the **shrine** they buy permanent upgrades (`data/upgrades/`, `UpgradeDef`):

| Kind | Upgrades |
|---|---|
| Stats | Vitality (+HP), Might (+ATK), Toughness (+DEF), Swiftness (+SPD), Arcane Talent (+skill power) |
| Starting items / perk | Provisions (extra potions), Second Chance (start with a Phoenix Feather) |
| Unlocks | Paladin's Oath (Templar Sword), Pyromancy (Ember Tome), Forbidden Library (Thunder and Wind tomes), Master Smith (Plate Armor, Shadow Cloak) |

Locked items (`content_db.tres` > Locked Items) never appear on the floor until unlocked.
The `Profile` autoload keeps souls, upgrades and records in `user://profile.json` (works on phones).

## Bosses

The last floor of each act is a start room and one big arena. The boss sleeps
in the middle; walking in closes the exits with spikes and wakes it up (boss music, health bar
with its portrait). A `BossDef` is a `MonsterDef` plus:

- **phases**: at a given HP ratio the boss gets stat bonuses, new skills, a shorter wind-up and a tint;
- **cast skills**: rings of projectiles, ground quakes (red circle), summons (`SummonEffect`), dashes;
- **relic_choices**: when it dies the spikes go down, the stairs appear and you pick a relic.

| Floor | Boss | Style |
|---|---|---|
| 3 | King Slime | 360° slams, slime rain, splits into slimes at half HP |
| 6 | Demon Cyclops | heavy club, fire eye beam, quake, calls skeletons, berserk at 20% |
| 9 | Crimson Tengu | fast blade, dashes, feather storms, calls spirits |

## Animations

Animations are **frame by frame**, like in Zelda-style RPGs: every character has a drawing for each
direction (down, up, left, right) and each pose, and the weapon is drawn *in the hand* for each
attack frame. Nothing is rotated or moved by code, so the weapon never floats or goes through the body.

Every actor (player and monsters) has a **rig**: `src/entities/rig/actor_rig.tscn`.

```
Rig                  at the actor's feet
└── Visual           flash shader, scaled 2x (units = art pixels)
    └── Squash       squash & stretch on hits
        ├── Body       AnimatedSprite2D: the character (SpriteFrames from the data)
        ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
        ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
        └── Weapon     AnimatedSprite2D: the weapon in hand, same animation and frame as Body
```

The animations live in `SpriteFrames` resources in `data/visuals/`, named `<pose>_<direction>`:

| Animation | When |
|---|---|
| `idle_*`, `walk_*` | standing, moving |
| `attack_*` | attacking (sped up to fit the weapon's attack speed) |
| `dash_*` | rolling |
| `hit_*` | taking a hit |
| `dead` | dying |
| `cast`, `intro` | bosses: telegraphed skill, waking up |

A missing animation falls back to a simpler one (`attack_left` > `attack`), and creatures with no
attack pose lunge instead. Monsters freeze in their attack pose and shake during their wind-up,
so you can see the strike coming.

**Weapons**: each `WeaponDef` has `attack_frames` (a SpriteFrames with `attack_down/up/left/right`).
The sheets in `assets/weapons/attack/` are 64x64 cells, one column per direction, one row per frame,
drawn so the handle sits in the hero's hand on that frame. The weapon is drawn behind the body when
facing up. `attack_fx` is the slash effect played in front of the actor.

**Armor (paper doll)**: what you wear shows on the hero. Each `ArmorDef` has `wear_frames`, a layer
with the same animations as the hero, and a `wear_color`. The layers copy the body's animation and
frame every frame, so they can't drift. The layer sheets (`assets/characters/hero/wear/`) are grayscale
and were made from the hero's own frames (hood and outfit pixels), so one style serves many armors:

| Style (`data/visuals/wear/`) | Slot | Used by |
|---|---|---|
| hood | head | Leather Cap |
| helm | head | Iron Helm |
| tunic | body | Leather Armor, Shadow Cloak |
| mail | body | Chain Mail |
| plate | body | Plate Armor |

A new armor = pick a style and a color in the inspector.

To tweak an animation, open a file in `data/visuals/` and use the SpriteFrames panel
(add frames, change the speed, toggle loop). The actor scripts never touch animations directly:
they call `rig.play_attack()`, `rig.play_hurt()`, etc.

## Adding content

| To add... | Do this |
|---|---|
| A monster | Duplicate a file in `data/monsters/`, edit it, add it to an act's Monsters (`data/dungeon/acts/`) |
| An act | New `ActDef` in `data/dungeon/acts/` (theme, monsters, boss), add it to `dungeon_config.tres` > Acts |
| A weapon / armor / consumable | Duplicate a file in `data/items/...`, edit, add it to `content_db.tres` > Items |
| A loot drop | Edit the monster's Loot table (items don't need to be in the DB to drop) |
| A player skill | Create a `SkillDef` in `data/skills/player/`, put it in a weapon's Skills (max 2) or in a tome |
| A skill tome | New `SkillTomeDef` in `data/items/tomes/` pointing to a skill, add it to `content_db.tres` > Items |
| A new kind of effect | New script in `src/definitions/effects/` extending `Effect`, override `apply()` |
| A new monster behaviour | New state script in `src/ai/states/`, add a node for it in `monster.tscn` |
| A perk | New `PerkDef` in `data/perks/`, add it to `content_db.tres` > Perks |
| A new kind of perk | New script in `src/definitions/passives/` extending `Passive`, override the hooks you need |
| A boss | New `BossDef` in `data/monsters/bosses/`, set it as an act's Boss |
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
| Another boss for an act | New `BossDef`, add it to the act's Other Bosses |
| An encounter | New `EncounterDef` in `data/encounters/` (choices, costs, outcomes), add it to `content_db.tres` > Encounters |
| An item affix | New `ItemAffixDef` in `data/affixes/` (prefix or suffix, slots, stats or on-hit), add it to `content_db.tres` > Item Affixes |
| Story texts | Edit `data/story/story.tres` (intro pages, death lines...); an act's line is its `ActDef` > Lore |

Each piece of content has an **icon** (any `Texture2D`) and an **icon tint** to recolor it.
Monsters and the player also have `frames` (their SpriteFrames in `data/visuals/`): a new monster
can reuse an existing one, or you can make a new SpriteFrames from a sheet in `assets/characters/`.
Floor looks (tiles, decor, tint, darkness, music) are `DungeonTheme` files in `data/dungeon/themes/`.
How many lanterns, prop clusters, hazard groups and chests a floor gets, how often ambushes and
elites happen, is in `dungeon_config.tres`.

`min_depth` and `spawn_weight` control where and how often something appears.
A `spawn_weight` of 0 means it never spawns on its own (starting gear, loot-only items, monster weapons).

## Controls

| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim, hold) | Big red button | J / Space | X |
| Skills 1-4 | Small round buttons | K L O P or 1 2 3 4 | A B Y RB |
| Belt (potions, bombs, scrolls) | The 3 small buttons left of the skills | Q / H, 5, 6 | LB (slot 1) |
| Pause | II button / phone back button | Escape | - |
| Choose a perk | Tap a card | Arrows + Enter | D-pad + A |
| Inventory | Bag button | I / Tab | Back |

## Tests

From the project root (desktop Godot):

```
godot --headless --fixed-fps 60 res://tests/run_tests.tscn
```

Checks the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
inventory, equipment, weapon skills and tomes, every kind of perk, props, explosive chains, traps and lights, then a bot plays the real game (kills, level ups and perk choices, stairs,
a full boss fight with its phases and relic, death and restart).
The exit code is the number of failures.

## Art and credits

Art, sound effects and music: **[Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack)**
by Pixel-boy and AAA, CC0 (public domain). License in `assets/LICENSE_NinjaAdventure.txt`.
Footstep sounds: Kenney Impact Sounds, CC0 ([kenney.nl](https://kenney.nl)).
Ambience sounds (`assets/audio/ambience/`) are filtered versions of those sounds; the heartbeat is synthesized.
The weapon attack sheets were composed from the pack's weapon sprites to match the hero's attack frames.

Pixel art is drawn at 2x in the world, with nearest filtering
(Project Settings > Rendering > Textures > Default Texture Filter).

## Conventions

- Static typing everywhere, `class_name` for reusable types.
- `snake_case` files and functions, `PascalCase` classes, `_private` members.
- One scene per entity, its script next to it.
- One monster scene for every monster type: the sprite, weapon and sounds come from the data,
  the rig animates whatever it is given.
