# Difficulty and progression between runs

## Difficulty

Pressing Descend asks for a difficulty (`data/difficulties/`, `DifficultyDef`). Every value multiplies
the normal game:

| | Pilgrim | Keeper | Martyr | Nightmare |
|---|---|---|---|---|
| Monster HP | x0.7 | x1 | x1.3 | x1.7 |
| Monster damage (attacks, skills, traps, bursts) | x0.6 | x1 | x1.35 | x1.8 |
| Time to dodge (wind-ups, casts) | x1.35 | x1 | x0.85 | x0.7 |
| Monster speed | x0.9 | x1 | x1.05 | x1.15 |
| How far monsters spot you (`detect_range`) | x0.85 | x1 | x1.2 | x1.4 |
| Extra monsters per room | 0 | 0 | +1 | +2 |
| Floor size (`floor_size`) | 72x72 | 84x84 | 96x96 | 104x104 |
| Rooms per floor (`rooms`) | 15 | 19 | 23 | 27 |
| Boss HP | x0.7 | x1 | x1.3 | x1.6 |
| Elite chance | x0.5 | x1 | x1.4 | x1.7 |
| Drop chance | x1.2 | x1 | x1 | x0.9 |
| Drop quality (Magic, Rare, Epic) | x0.7 | x1 | x1 | x1 |
| Heal on each new floor | 25% | - | - | - |
| Light | brighter | - | darker | much darker |
| Souls | x0.5 | x1 | x1.6 | x2.5 |
| Feats count (achievements, the Tree's feats, records) | no | yes | yes | yes |

Pilgrim spares the hero but pays for it, and its card says so in red: half the souls, rarer
Magic, Rare and Epic gear (`loot_quality`), and no feats (`counts_feats`): its runs don't move
achievements, the Tree of Souls' feat nodes (so the oaths), the deepest floor or the victories.
Quests and the bestiary count everywhere. On every card, the souls line is red below x1 and green
above.

Bigger floors get more of everything with their rooms: monsters, chests, hazards, encounters and
items lying around. A floor starts with at most `max_monsters_per_floor` (110) monsters, so the
phone keeps up on Nightmare; the seal never asks for more than `seal_max` (50) kills.

Pilgrim, Keeper and Martyr are open; **Nightmare unlocks after a win on Martyr** (`unlocked_by`).
**Ascension**: a Nightmare win opens **Nightmare +1**, a +1 win opens +2, up to +10
(`data/ascension/`, `AscensionDef`, picked on a strip under the difficulty cards, which lists every
twist up to the chosen level, the next one and the souls multiplier). Each level adds its twist
on top of the ones below: tougher monsters, harder hits, more elites, higher prices, one more
monster per room, faster monsters, tougher bosses, darker floors, less max HP... and 10% more
souls per level.
The last choice is remembered (gold frame), shown in the HUD and on the end-of-run screen.
The difficulty window (`DifficultyPanel`, one `DifficultyCard` each) says what changes in plain
words, compared with Keeper (`DifficultyCard.effects()`: "Monster health +30%", "Time to dodge
-15%", "+1 monster per room", "Monsters spot you sooner", "Bigger floors (+20%)"...; green helps,
red makes it harder), the souls it pays, and for a locked one what unlocks it.

## Between runs

The game opens on the **title screen** (`src/ui/title/`): play, visit the shrine, see your records.
A run left open (the app closed mid-run) shows **Resume the descent** above Descend, as wide as
the other buttons, its floor and level on a second line.
There is no class to pick: everyone starts the same, and becomes who they want during the run.
The bosses of each act are shown with what a run is; the Dawn Knell button (the daily run) opens a card that explains it (same
dungeon for everyone today, the day's start, your score); the records sit on a strip (souls to
spend, runs, victories, deepest floor, difficulty); the Shrine button wears an "Souls to offer"
badge when souls can buy something. The title-side windows (shrine, difficulty, options) use the
game's RPG skin like the bag (`MenuWindow` in `src/ui/common/`: an `RpgWindow` with its Close
button and a header line within reach, big switches, strips and badges).

**The Dawn Knell** (the daily run: the shrine's bell tolls each dawn, `DailyRun`, `DailyDialog`, the button under Descend): one run a day, the same all day (UTC),
offline. Each floor is generated from the day and its depth, everyone starts with the day's
weapon and relic (shown on the button), on Keeper. The day's first attempt is the official one
(counted when it starts: quitting doesn't give another); its score is kept with the best ever and
the days in a row (`Profile.daily_*`); later attempts that day are practice. Score: 1 per kill,
30 per floor, 150 per boss, 1000 for a victory, 1 per 5 gold picked up. The game over screen
shows it.

Every run ends (death or victory) with **souls** (`DungeonConfig` > Souls, `souls_for_run()`):
a tenth of a soul per kill (the tenths add up over the run, rounded once at the end), 4 per floor
gone down, 10 per boss, 40 for a victory, times the difficulty. Going deeper pays, farming
monsters doesn't: in a run that dies at act III's boss on Keeper (about 80 souls), the kills are 25 of
them. Souls are kept forever (gold only lasts for the run). At the **shrine** (`ShrinePanel`)
they buy the nodes of the **Tree of Souls** (`data/shrine/soul_tree.tres`, `SoulTreeDef`,
`SoulNodeDef`). Four branches, each a fantasy, side by side on one screen (`SoulTreeView`):

| Branch | Nodes, top to bottom ("or": a fork, taking one shuts the other) | Oath at the end |
|---|---|---|
| Flesh | Vitality; Iron Skin or Communion (heal 5% a level when a floor is won); Provisions; Death Denied (a Phoenix Feather from the start: a second life through the trial of the Threshold, see builds.md) or Blood Pact (+20% max Health, heals 30% weaker) | Oath of the Colossus |
| Blade | Might; Keen Eye (+crit) or Quick Hands (+attack speed); Armory (pick the starting weapon, 5 levels); Spoils of the Fallen (elites drop Magic gear) | Oath of the Duelist |
| Arcana | Gift of the Arcane; Pyromancy, Paladin's Oath (new items); Forbidden Library; Satchel of Tomes (start with a tome) or Swift Litany | Oath of the Heretic |
| Greed | Loaded Dice (rerolls); Swiftness, Exile (banishes); Master Smith, Cartographer (stairs, merchant and forge on the minimap); Haggler (-15% prices) or Laden Stalls (+2 items) | Oath of the Vulture |

A node opens once a node above it is bought; some also need a **feat** (an achievement: "?" on the
node, the feat in its card). Tapping a node shows on the right what it does now and next, what
opens it, and Buy. **Reset the tree** gives every soul back, every level of every node
(`SoulTreeDef.reset_cost`, 0: free), but it is earned: once every `reset_runs` (3) finished runs
(`Profile.runs_since_reset`, counted by `Profile.record_run`: a death or a win, daily and Pilgrim
runs included; a run won then lost in the endless floors counts once; a run given up before
floor `reset_min_depth` (2) doesn't count, so quick give-ups don't buy a new tree). Until then the button is
greyed and says "Reset in 2 runs"; a reset starts the count again. Saves from before the rule
start with a reset earned, so nobody is stuck with an old path. Each node's effect is an `UpgradeDef` (`data/upgrades/`):
stats, a head start, perk choices, new items, or run rules (kind `RULES`, read by `RunBoons`:
heals, gold, loot, the merchant, the minimap). The old shrine's levels carry over as they are.

**Oaths** (`data/oaths/`, `OathDef`): the end of each branch opens one. Once one is open (or the
Armory), "At the Well's Edge" (`OathPanel`) comes between the difficulty and the run: swear an
oath or none, and pick the starting weapon (Armory). An oath is an "X, but Y" start (table below).

**The Armory** is bought in 5 levels (`data/upgrades/armory.tres`: `armory_weapons`, an ordered
list, `armory_first` 3 at level 1, `armory_per_level` 2 more each level; costs 90 / 150 / 210 /
270 / 330 souls, 1050 in all). Level 1 opens one weapon per way to fight, the rare ones come last:

| Level | Adds | Weapons |
|---|---|---|
| 1 | Katana (the usual start), Bow, Frost Staff | 3 |
| 2 | Sai, Spark Wand | 5 |
| 3 | Lance, Battle Axe | 7 |
| 4 | Whip, Shuriken | 9 |
| 5 | Greatsword, Templar Sword | 11 |

A weapon in `content_db.tres` > Locked Items (the Templar Sword, opened by Paladin's Oath) is
offered only once unlocked (`ShrineUpgrades.armory_weapons`). The oaths' weapons (War Hammer,
Rapier, Ember Tome) are not in the list: they come with their oath. Ninjaku and Pickaxe are left
to the floors. The node's detail says what the next level adds ("Now: 5 starting weapons >
Next: +2 weapons: Lance, Battle Axe", a weapon still locked marked so); the Well's Edge shows only
the weapons the level opened and "Armory level 3: 7 weapons. More in the Tree of Souls.". A
starting weapon the level no longer offers (an older save, a reset tree) falls back to the usual
Katana. Saves that bought the old one-level Armory keep it as level 1.

| Oath | Rule |
|---|---|
| Oath of the Colossus | the Hammer, +30% max Health, 15% slower |
| Oath of the Duelist | the Rapier, +10% crit chance, crits x2.5 (instead of x1.75), -20% max Health |
| Oath of the Heretic | the Book, +50% skill damage, attacks 20% slower |
| Oath of the Vulture | +35% gold and better loot, merchant 25% dearer |

Each oath card (and its node in the tree) lists the oath line by line (`OathDef.effects()`): the
weapon in plain text, every gain in green, every cost in red, so the price of an oath reads at a
glance. Every oath has at least one of each (a unit check).

Not in the daily run (everyone starts the same). The run keeps its oath in the save (`RunState.oath`).

**The pace of the tree** (measured: `tools/balance` economy mode, table "economy_campaign"): a
full tree (the dearer side of each fork) is a campaign of about 47 runs on Keeper (8765 souls), every source
counted (runs, quests, the bestiary's ranks and challenges, achievements), some 29 hours; the
first node is bought after the first run; the bestiary and the achievements pay about a sixth of
the tree in the first 10 runs (they used to pay more than the whole tree). Martyr and Nightmare
pay more per run (x1.6, x2.5, and more monsters).

Locked items (`content_db.tres` > Locked Items) never appear on the floor until unlocked.
The `Profile` autoload keeps souls, upgrades and records in `user://profile.json` (works on phones).

## Quests

Every day, 3 **daily quests**; every week (from Monday), 3 **weekly quests**
(`data/quests/`, `QuestDef`, drawn by `QuestBoard` from the date: everyone gets the same ones,
UTC). "Slay 60 monsters", "Open 4 chests", "Reach floor 6 in one run", "Go through a cursed
floor", "Defeat 5 bosses", "Win a run"... They count what you do in any run during that day
or week (`Profile.period_stat`), pay their souls as soon as they're done (a toast in the game:
5-18 for a daily quest, 30-70 for a weekly one, more for a harder goal)
and show on the title screen (**Quests**, also a tab of the Codex) with the time left.

## Codex: bestiary, achievements, runs

Five tabs: Quests, Bestiary, Achievements, Runs and **Voices** (what the Vigil-Keeper and the
keepers said, by speaker: presentation.md, "The Vigil-Keeper and the keepers").

**The bestiary** (codex tab, also in the pause menu): every monster and boss, unknown, *seen*
(it spotted you: `Profile.mark_seen`) or slain. Tap one for its page (`MonsterPage`): its look,
what it is, its stats and ways (flies, keeps its distance, traits, a boss' phases), its
**attacks** with an **animated preview** (`AttackPreview`: the same red warning, then the shots,
blast, charge, summons or heal, built from the WeaponDef / SkillDef data), and its challenges.
- **Hunter ranks** (`BestiaryRules`, `data/bestiary.tres`; `Bestiary`): Known (1 kill), Hunted
  (10), Mastered (30) for monsters, 1/3/6 for bosses. Each rank pays souls once
  (2/4/8, bosses 8/12/25); Mastered gives **+10% damage** to that kind for good.
- **Challenges** (`HuntChallenge`, watched by `HuntTracker`): every monster gets those that
  apply (an elite one, pushed into a hole, 3 within 5 s, untouched since it saw you, a crit
  finish; summoned monsters and the Threshold's spectres count for none), every boss its own (with a ranged weapon, with a melee one, under 90 s, without a
  potion, losing less than 25% HP) plus one with a given weapon (`MonsterDef.challenges`: the
  Bloated King with a Bow, the Ember Ronin with a Katana...). Done once, paid in souls, with a toast:
  2-4 for a monster's (3 for an elite one, 4 for a hole, 3 for a streak, 3 untouched, 2 for a crit
  finish), 5-15 for a boss' (melee 5, ranged 8, no potion 8, under 90 s 12, losing little Health 15,
  its weapon 12).

The **Codex** (`CodexPanel`, from the title screen and the pause menu) is built in code in the
game's skin (`RpgWindow`, like the bag and the forge): four tabs in its header, the souls you hold
on the right, and under the tabs a summary line plus one sentence saying what the tab is for
(souls are kept between runs and spent at the Shrine; gold is lost when a run ends). Lists scroll
with a finger (`TouchScroll`); `CodexRows` builds their rows, with a tick box for what is done.
- **Quests**: today's and this week's quests side by side, each with its goal, a progress bar,
  its reward in souls ("Received" once paid) and the time until new ones.
- **Bestiary**: act by act (floors, how many kinds slain), then the hidden floor's boss under a
  "???" heading until it was met (its floor's name after), a card per monster and boss
  (`CodexCard`: picture, rank, kills, a bar toward the next rank, gold frame once Mastered,
  Boss and Celestial badges; unknown ones are dark shapes until met). Its page has three columns:
  look, where it lives and its Celestial form; attacks with the preview, how it behaves and its stats
  (Health, Damage, Armor, Move speed, each with what the number means); hunter ranks (slay N,
  +X souls, done or not) and challenges. A warden's page has two tabs in its middle column,
  **Attacks** and **Chronicle** (`ChronicleRows`, asking `Narrative`): "Chapters 3 of 6, Fragments 1
  of 3", the open chapters in order with their lines, the locked ones as "???" with what opens them
  in plain words ("Slay it 4 times", "Find 2 fragments about it", "Reach floor 7"; a deed as its
  riddle in the Well's voice until the fragment that gives its rule away is found), its waking
  words, and its fragments (found ones are buttons that open their reading panel again, the
  others "???" with where they lie: "Found on the floors of Act II"). Unmet wardens show nothing
  but "Meet it to begin its chronicle".
- **Achievements** (`data/achievements/`, `AchievementDef`): a goal on one of the profile's counters
  (kills, elites, wardens, kinds of creatures, depth, victories on Martyr / Nightmare / ascension,
  monsters pushed into holes, chests, Epic items, encounters, gold or level in one run, secret
  rooms found, hidden bosses slain, trials of the Threshold won: *Not Yet*, the two endings), with a progress bar and its reward; the closest to done
  first. Reaching it pays souls, with a note at the top of the screen. A **secret** one
  (`AchievementDef.secret`) shows as "???" ("A secret feat. Some doors only open from the other
  side.") until reached: "Laid to Rest at Last" (slay the hidden floor's boss, 50 souls) would
  give the hidden floor away. "What the Walls Keep": find 5 secret rooms (25 souls).
- **Runs**: the fastest wins, then the last 20 runs: how each ended (victory, or the floor and
  what slew you), when, the difficulty, how far (floor N of 12), how long, level, weapon, kills
  and the souls earned.

## The two endings

The first win ends on the story's victory text (the first ending: the souls come back, the bell
rings, "the Well goes deeper still"). Afterwards a run is won at the bottom of the Well
(dungeon.md): when the Maw's mask crumbles, the **ending panel** (`EndingPanel`, the game's
skin, the game paused; Back doesn't close it) shows "What Is Left" / « Ce Qui Reste », a line,
and one card per ending (`FinaleDef.endings`, `EndingDef` in `data/story/endings/`):

| Ending (FR / EN) | Its button | What it means | Achievement |
|---|---|---|---|
| Le Dernier Glas / The Last Knell | « Sonner la cloche » / "Ring the bell" | seal the Maw: Tôma dies in peace, Hana rests, Kagari wakes | *Le Dernier Glas / The Last Knell* (100 souls, secret) |
| Le Gardien Sans Nom / The Nameless Keeper | « Prendre sa place » / "Take his place" | the hero stays down there, the nameless keeper of the seal; Tôma climbs back to wake the village | *Celui qui Veille / He Who Keeps Watch* (100 souls, secret) |

The choice is kept in the profile (`Profile.ending`, the last one chosen; "" before any) and
counted (`ending_bell`, `ending_keeper`: `AchievementDef.Stat.ENDING_BELL` and `ENDING_KEEPER`,
after the others), not on Pilgrim (like every feat). Then the victory screen takes the ending's
title and tells it (three short lines), with the run's numbers and souls as usual; Keep going
leads on to endless mode. Both endings lead to the same game today (docs/lore.md, section 9).

## Run timer (speedruns)

Every run is timed (`RunTimer`, `RunState.time`): in-game time, in real seconds (hit stops and
slow motion neither slow it nor make it jump: `HitStop.real_delta()` divides a frame's delta by
the time scale that frame began with, read before its physics where blows land), counting in the bag, the shop and the perk choices (deciding is part
of the run) but not in the pause menu, while a floor loads or during its title cards. It keeps
counting in the trial of the Threshold (a second life is part of the run). It is saved
with the run, so quitting and coming back doesn't reset it.

- **On screen**, under the map (`Hud.show_run_time()`; Options > Run timer hides it). Once the
  last boss falls, the win's time stays there, in gold, through endless mode.
- **Splits**: taking the stairs notes the floor's time (`RunState.splits`) and shows it a few
  seconds: "Floor 3  4:12.3  -0:05.2", green when ahead of the record run, red when behind.
  The hidden floor (dungeon.md) has no split of its own: it keeps the depth of the boss before
  it, and its time goes into the next floor's split. The bottom of the Well has one, after the
  last act's (13), the win's. A win at the bottom is raced under the same record as a first win
  (the same difficulty key), so the first win's record, without the bottom, is the hardest to
  beat.
- **Records** (`Profile.best_times`, `best_splits`): the fastest win per difficulty and ascension
  level (`RunState.record_key()`: "normal", "nightmare/a3"), with its splits to race against.
  Daily runs keep none (their own race).
- **Where it shows**: the end screens (the time, then "New record!" or the record to beat), the
  log, and the Codex > Runs (each run's time, the fastest wins).
