# Balance

## Tools

`tools/balance/` measures the game's balance on the real content and the real engine, so the
balancing work (the `game-balancer` agent, or a person) can measure, change data, and measure
again. Nothing in it is a hand-made list: weapons, perks, relics, families, runes, affixes, shrine
upgrades, elite affixes, monster ranks, monsters, bosses, encounters and difficulties are walked
from `ContentDB` and the `data/` folders (`BalanceContent`), so new content is measured on the
next run. Content found in `data/` but not used by the game is reported (table "Content").

### Running

From the project root (Godot 4.7; import the project first if `.godot/` is missing):

```
godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=all --jobs=2 --out=/tmp/balance
```

| Option | What |
|---|---|
| `--mode=` | `model`, `arena`, `pack`, `marginal`, `economy`, `compound`, `all` (default `model`); `merge --in=a,b` combines earlier runs |
| `--quick` | a small subset of each mode (what the `balance` test suite runs) |
| `--difficulty=` | `easy`, `normal`, `hard`, `nightmare`, `nightmare+N` (Nightmare with its first N ascensions); default all of easy..nightmare+10 (`--quick`: normal) |
| `--build=`, `--boss=`, `--bot=` | restrict the builds (`data/balance/builds/<name>.tres`), bosses, bots (`face_tank`, `kite`) |
| `--acts=2,4` | marginal values: acts measured (default all) |
| `--seed=N` | every measure starts from this seed (default 1): the same command gives the same numbers |
| `--all-pairs` | arena: every build against every boss, not only its act's |
| `--timeout=240` | arena: game seconds before a boss fight is a timeout |
| `--plain`, `--no-weapons` | arena: plain bosses only (no ranked fights); skip the weapon arena (targeted runs) |
| `--jobs=2` | `all`: the arena runs in a second Godot process (2 CPUs: about half the time) |
| `--out=` | where the reports go (default `user://balance`) |

Each mode writes `<out>/<mode>/report.md`, `data.json`, `csv/<table>.csv` and `state.json`
(for `merge`); `--mode=all` also writes `<out>/report.md` and `<out>/data.json` with everything,
and prints a short summary (flags per category, the first ones). Exit code 0: flags are findings.

Run time on 2 CPUs (2026-10-20, all six difficulties, measured): model ~2 s; economy ~3 min
(96 floors); compound ~4 min; pack ~9 min (478 rooms); marginal ~34 min (572 variants, 4 acts);
arena ~45 min (408 boss fights, then 160 weapon-arena fights). `--mode=all --jobs=2` (the arena in
a second process) takes about 45-50 min of real time; one process would take about 1 h 30. `--quick` modes
take 5 s to a minute each; the `balance` test suite about a minute.

### What each mode measures

- **model** (static, seconds): the content's numbers put through the game's own code (a real
  `Player` gets each build; `FloorRules` scales monsters; `Combat`'s variance, crit and armor),
  fights as arithmetic. Every monster kind x every rank (plain, Elite with each affix, Epic and
  Legendary with spreads of affixes, Shiny) x every depth it appears at x every difficulty:
  health, armor, hit and damage per second on the act's expected build (after its armor), time to
  kill, hits to kill the hero, damage taken while killing it; rank chances per depth. Every boss
  (alternates too) x every phase x every boss rank x every difficulty: health, armor, hit and
  damage per second per phase, time to kill, a face-tank estimate, the threat (share of the
  hero's health a face-tank fight costs) and the curve (act over act, difficulty over Normal);
  each elite affix on each boss. Every weapon x every rarity x every armor value monsters have:
  DPS on each act's expected hero, weapon skills' damage and cooldowns. Builds, degenerate and
  family DPS ratios, a static perk estimate. Assumptions: 100% uptime; fans land 1 + 0.6 per
  extra projectile on a boss; status uptime 1 - exp(-rate x duration); DoTs of a kind don't stack;
  sustain capped by `SustainRules`; procs it can't place (chains, bursts, rolls, thorns) left out.
- **arena** (engine): real fights in the Game scene with a bot at the controls (`BalanceBot`):
  `face_tank` stands in reach and hits, uses skills when ready, never rolls or drinks; `kite`
  keeps its weapon's range and hits whenever in reach, steps out of swings, skill circles, leap
  lines, shots, blinking arena cells and live traps, rolls only as a blow lands (within the
  roll's invulnerability) and only where the whole roll is solid ground, and holds the hit that
  would set off a boss' shockwave when its roll isn't ready.
  Every boss x the builds of its act (expected on every difficulty; degenerate, family and baseline
  builds on Normal and Hard) x both bots; every boss rank (Epic, Legendary, Shiny, with the affixes
  the game rolls) with the expected build on Normal and Hard. Result, time, phase reached, boss
  health left (and the time to kill projected from it), damage dealt and taken, hits, healing by
  source (perk, rune, affix, family, skill, item, revive), damage taken by kind (melee, skill,
  shockwave, adds, ticks, traps, falls; printed per fight), lowest health. Then the **weapon arena**:
  every weapon (Common, on the act's expected build otherwise) against every boss, kite, Normal.
- **pack** (engine): on each act's last normal floor, Normal and Hard: three of each monster kind
  (time from first hurt to death, damage taken), mixed rooms of the act's list by spawn weight
  (room size of that depth and difficulty, 3 rooms) for every build of the act and both bots, and
  rooms with one ranked monster (Elite with each affix, Epic, Legendary, Shiny) + 2 commons.
- **marginal** (engine): every perk at each level, every relic, every family's bonus alone, every
  rune, every item affix, every shrine level (stats and starting perks), every encounter outcome,
  added alone to each act's expected build (Normal). Each variant: DPS and boss time to kill on
  the act's boss as a dummy (no AI, health scaled to ~15 s for the base build; the hero
  untouchable, held at 45% health for the second half so low-health bonuses and heals show);
  pack clear time on a room of the act's monsters that don't fight back (cleaves, chains, kill
  effects); boss time to die = (health + ward) x revives / (the boss' DPS on that hero - sustain);
  effective health vs the act's monsters; damage taken in one live room at max level
  (informative). **Value = sqrt(boss TTK ratio x pack clear ratio) x boss time-to-die ratio - 1**.
  Ranked per act and category at max level; flagged beyond 2x / under 0.5x the category's median.
  A perk the build already has is measured from the build without it (its families kept awake);
  a family the build has awake is measured by putting it to sleep. Encounter outcomes that are
  not stats (a perk or relic gift, a heal, gold, items) are valued from the measured ones.
  Every measure starts on a fresh run of the same seed: a repeat gives +0% (table "marginal_base"),
  another seed shows how much is luck.
- **economy** (engine): every normal depth x difficulty, 2 floors each, generated by the game
  (its events, curses, merchants...) and harvested by its code: every monster slain, crate broken,
  chest opened; gold, XP, items by rarity, runes counted; a merchant's stock priced on each floor;
  ambushes and encounters valued from their data. Gold per floor (full clear and typical) vs stock
  prices, rerolls and rune removal; XP before each boss -> level (the expected builds' reasoning);
  rarity per depth and source; souls per run by result and difficulty vs the shrine's total.
- **compound** (engine): attack speed x crit x damage (Frenzy, Precision, Strength, War Banner
  alone and together vs the product of the parts); Multishot and Prism on every ranged weapon at
  64, 128, 256 px; echo (Echo perk, Echo runes, of Echoes, Arcane Focus); burn stacking (Ignite,
  Ember, Burning, Kindling, Inferno); armor vs many weak hits (share of each act's monsters hitting
  each build for 1); healing vs the sustain cap (lifesteal stacks with and without `SustainRules`,
  in a room and on a boss dummy, and what a real boss fight's budget would pay).

### Reading the report

`report.md` starts with the run (command, seed, time per part) and a table of contents; then
**FLAGS**: a count per category, then every flag numbered (F1, F2...; errors first): severity,
category (`model:` estimates, `arena:`/`pack:` real fights, `marginal:`, `economy:`, `compound:`),
subject, measured value, target, and why. Then the tables, numbered by section: 1 Builds,
2 Monsters, 3 Bosses, 4 Weapons, 5 Marginal values, 6 Economy, 7 Compound checks, 8 Content (in a
single mode's report the numbers start where its sections start). Long tables show their first
rows; the CSV (`csv/`) and `data.json` have every row. `data.json` holds every table (as rows of
named columns) and the raw measures (every fight, room, floor and variant) for scripts.

Errors are pillar breaks measured on the engine (a face-tank win, too much healing in a boss
fight); warnings are targets missed. Model flags are estimates: confirm them with the arena or the
lab before changing data.

### Targets (data/balance/targets.tres, a first proposal)

| Target | Value | Why |
|---|---|---|
| Boss time to kill, expected build, Normal | 40-100 s (rare-rank boss <= 150 s) | under it the boss is not a fight; over it the fight drags on a phone |
| Face-tank (never dodges) with expected and degenerate builds | must lose to every boss from Normal | skill beats stats: standing and trading blows must never win (pillar 1) |
| Kite (keeps range, rolls) with the expected build | wins on Easy and Normal | the fight must be beatable by playing it |
| Healing in a boss fight / damage taken | <= 25% expected, <= 50% degenerate and family | healing forgives mistakes, it doesn't out-heal a boss |
| Boss hits to kill the expected build (Normal) | 6-12 | one mistake isn't the end; ignoring the patterns kills |
| Common monster time to kill (expected build, Normal) | 0.5-2.5 s | paper below, a slog above |
| Elite / Epic / Legendary / Shiny time to kill | 3-10 / 5-16 / 8-25 / 2-10 s | a short duel, a longer one, a mini-boss, a treasure |
| Common monster hits to kill the expected build | >= 6 | never a two-shot |
| Room damage (kite, expected build) / clear time | <= 35% of max health / <= 25 s | a room shouldn't cost half your life when you play well |
| Act curve (boss threat, act over act) | x0.9-x1.6 | a steady curve, no wall (pillar 5) |
| Difficulty vs Normal (boss threat) | Easy x0.2-0.7, Hard x1.3-2.6, Nightmare x2-5, +5 x2.5-8, +10 x3-12 | Easy forgiving, Nightmare demanding, ascensions add twists not walls |
| Any pick at max vs its category's median (marginal value) | 0.5x-2x | every pick a real choice (pillar 2) |
| Degenerate build DPS / expected build's | <= 2.5x | stacking pays, it doesn't trivialise (pillar 3) |
| Weapon DPS vs the median weapon (same rarity, same hero) | 0.6x-1.6x | no trap, no only choice |
| Weapon arena: bosses beaten (Common, kite, Normal) | >= 50% | a weapon that loses to most bosses is a trap |
| A stack of multiplying bonuses (compound) | <= 2.5x the expected build's DPS | check the products, not the parts |
| Most armored build: monsters hitting it for 1 | <= 50% of the act's | armor makes weak monsters weaker, not harmless |
| One sustain source alone, cut by the budget in rooms | <= 10% | a single Leech or Vampirism is never capped on packs |
| Gold between merchants / an average stock item | 0.8-3 items | buy something most visits, never everything |
| A reroll / rune removal vs a floor's gold | <= 35% / <= 60% | cheap enough to use |
| Runs to buy the whole shrine (dying in act II-III, Normal) | 15-60 | a long goal, not a grind |
| First run (dies at the act I boss) | buys a shrine level | something to show for it |

### Builds (data/balance/builds/)

- `baseline`: a fresh hero (level 1, the Katana).
- `expected_a1`..`expected_a4`: what an average player has at each act's boss. Level from the XP
  curve and the XP measured on Normal floors (economy table "XP gathered before each act's boss",
  kills 80/75/65/60% of the act's monsters), one perk per level up leaning to families, a relic
  per boss slain, gear rarity from the loot weights at that depth, runes from bosses and elites,
  a few shrine levels. Each file's `description` says why.
- `degenerate_*`: one thing stacked as hard as the game allows at that act: lifesteal (each act),
  crit, attack speed, burn, thorns/armor, skills/cooldowns, max health.
- `family_<id>_a3`: each family built on purpose at act III (expected_a3's level and gear, 10
  perks leaning on the family, its runes).

To add a build: copy a `.tres` in `data/balance/builds/`, give it a unique `name`, `tags`
(`expected` - one per act -, `degenerate`, `family` + the family id, `baseline`), its act, level,
weapon (rarity, affix ids, rune ids), armors, perk ids -> stacks, shrine upgrade ids -> levels,
and say why in `description`. Unknown ids and impossible stacks are flagged ("build data").
To add a target: add an `@export` to `tools/balance/balance_targets.gd` with its reason, its value
and the same reason in `targets.tres`, and check it where it is measured (`flag()` in the mode);
add it to docs/balance.md's table. To change a target, say why in the balance log.

### Limits (read before trusting a number)

- **Repeatable, not luck-free.** The same command gives the same numbers (`--seed`); the lab
  replays each measure on a fresh run of the same seed, so two builds are compared on the same
  luck (table "marginal_base": a repeat gives +0%). Another seed moves a value by 2-40% (shown
  there too); a fight that ends with the boss at 2% may flip from one run of the tools to another
  (the arena runs each fight once). Read flags across several bosses or acts, not one fight.
- **The bots are decent, not good.** `kite` doesn't use the terrain, doesn't drink, and rolls
  only on what it sees coming (it still eats some shockwaves and falls when thrown off); a lost kite fight means "hard for a careful player", not
  "impossible". `face_tank` is the pillar-1 test as written: it never dodges.
- **Dummies don't fight back.** The marginal values' boss and rooms don't move or attack: slows,
  freezes, knockback, thorns and retaliation, roll effects and other crowd control show no value
  there (they are in the live rooms' "Taken" column and in the arena). A pick at +0% is either a
  trap or a defensive/control pick: read its description before calling it weak.
- **Saturation.** When a build already out-heals its act's boss (sustain >= the boss' damage per
  second), every defensive pick scores 0 (time to die is capped at 200 s): that is a finding
  about the build's sustain, not about the picks.
- **Quantised damage.** The dummy dies after a whole number of hits: picks worth under ~3% of
  damage can read +0%, and two levels can read the same.
- **The model is arithmetic.** It ignores movement, positioning and most procs; it is for
  coverage (every rank, depth, difficulty) and trends. The engine modes are the measures.

### Hooks in the game code (behaviour-neutral)

`Actor.healed(amount, source)` and `Actor.heal_source` tag every heal with what caused it (set for
the length of a call by `PerkSet`, `SkillSet.try_use` and `ConsumableDef.use`); nothing in the game
listens. `PerkSet.Entry.source_tag()` names a perk, family, rune or affix for it. That's all: the
tools drive the game through its input actions, its data and its public nodes.

## Balance log

### 2026-10-20 - Phase 2A: bosses, sustain, armor, the kite bot

Measured with the arena (`--mode=arena --plain --no-weapons`, seed 1, Normal and Hard, every
boss x the builds of its act x both bots) and the model, against the phase 2 baseline above.
The other two phase 2 passes (B: monsters, ranks, elites, difficulties; C: perks, runes,
affixes, weapons, shrine, economy) ran in parallel: their data is not in these numbers.

#### What was wrong (root causes)

- **The kite bot played badly**, so "the kite loses" meant little. It backed off at the *start* of
  every wind-up or cast within 220 px (a melee hero stopped hitting for most of the fight: a
  third to a quarter of the face-tank's damage per second), rolled *early* (at 55% of a wind-up:
  the 0.23 s of invulnerability ended before the blow), rolled straight into pits (falls cost 15%
  of max Health each: up to 163 of 216 damage taken against the Weeping Spirit) and never saw the
  arena's warnings or traps.
- **Sustain in boss fights**: the budget refilled 2% of max Health a second and started full (20%):
  from act III one Leech rune paid back 66-100% of the damage taken.
- **Flat armor** (`Combat.mitigate`: damage minus armor, at least 1): every act IV monster hit a
  36-armor build for 1, act IV bosses' blows did 7 to the expected build (13 armor), and a boss's
  shockwave (a trap-sized blast, `dungeon_damage(4, 0.6)`) did 1-2 to anyone with armor: the
  boss' answer to face-tanking cost nothing.

#### What changed and why

| Change | Before | After | Where |
|---|---|---|---|
| Kite bot | see above | hits whenever in reach (attacks don't root the hero); steps out of swings, skill circles (`telegraph_radius`, damage areas), off leap/rush lines, sideways from shots heading its way, off blinking arena cells and live traps; rolls only when the blow lands within the roll's invulnerability (swings and circles at 75%, casts of shots at 85% when close, shots under 0.15 s away, shockwave rings 0.25 s after they appear) and only where the whole roll (40-160 px) is solid ground; holds the hit that would set off a shockwave when its roll isn't ready | tools/balance/balance_bot.gd |
| Armor rule | `max(1, A - D)` | `max(1, round(A x A / (A + D)))` (`Combat.ARMOR_WEIGHT` = 1): about D points off a big hit (35 vs 5: 31), half of a hit the armor's size (20 vs 20: 10), never harmless (20 vs 36: 7) | src/combat/combat.gd; the tools' model, lab and compound checks call it; the bestiary's Armor line now says "a 10-damage hit does X, a 30-damage hit Y" |
| Boss-fight sustain | refill x0.5 (2% of max Health/s), budget 20% | refill x0.1 (**0.4%/s**), budget x0.25 (**5%**) while `World.is_boss_fight()` (`SustainRules.boss_fight_rate`, new `boss_fight_burst`) | data/dungeon/sustain.tres, sustain_rules.gd, sustain_meter.gd |
| Boss shockwave | `dungeon_damage(4, 0.6)` (6-14 before armor) | new `BossDef.shockwave_power` (share of the boss' power), **1.0** on every boss (11-29 on Normal): the face-tank takes it every few seconds, the kite rolls through or holds | boss_def.gd, monster.gd, data/monsters/bosses/* |
| Act IV bosses | Gilded Hoarder, Sun Wraith | +2 attack (base stats): act IV boss threat x0.93 -> x0.97 of act III (model) | gilded_hoarder.tres, sun_wraith.tres |
| Red Samurai | Flame Arc x1.6 skill power (37 DPS in its last phase, the highest of act III) | x1.3 (both versions) | data/skills/boss/flame_arc*.tres |
| Giant Frog | spit x0.6 every 3 s, leap x1.2, 800 Health | spit x0.5 (cooldown 3.5 s, fierce 3 s), leap x1.0 (both versions), 700 Health (act I's alternate was harder than act II bosses for the kite) | giant_frog.tres, poison_spit*.tres, frog_leap*.tres |
| Azure Wyrm | 1100 Health, Frost Breath and Hailstorm x0.5 (the kite lost it in every run, 12-26% left) | 1000 Health, x0.42 (all four skill files) | azure_wyrm.tres, frost_breath*.tres, hailstorm*.tres |

Tools: `--plain` and `--no-weapons` for targeted arena runs; each fight now logs the damage taken
by kind (melee, skill, shockwave, adds, ticks, traps, falls).

#### Results

Model, boss threat act over act (expected builds, target x0.9-1.6): Normal x0.79 / x0.99 / x0.62
-> **x1.06 / x1.05 / x0.97**; Hard x0.90 / x1.10 / x0.70 -> x1.08 / x1.12 / x0.97 (the model doesn't
count shockwaves). "model: face-tank wins", "model: heal share" and "model: act curve" pass.

Summary, expected builds, plain bosses: the face-tank wins **0 of 10 on Normal (was 5) and 0 of
10 on Hard (was 3)**; heal share in boss fights 6-40% (was up to 100%; a single Leech rune heals
0.4% of max Health a second against a boss). The kite wins 6 of 10 on Normal (as before, but
without the Leech carry: before, its act III-IV wins healed 66-97% of the damage taken), 3 of 10
on Hard; its damage per second roughly doubled (act II: 14-24 -> 30-33). Its Normal losses are
close: Giant Frog 8-27% left, Azure Wyrm 5% (after its change), Red Samurai 0% (died with it),
Gilded Hoarder 3% (165 of its 365 damage from falls: a bot weakness; the earlier run won at 37%).

Expected builds vs every boss (engine; F face-tank, K kite; W win with the hero's lowest health,
L loss with the boss' health left; heal = healed / damage taken). Before = the baseline run; after
= the final rules and bot, before the last Giant Frog and Azure Wyrm changes (measured
separately below):

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| king_slime | expected_a1 | hard | F | L 17s (boss 65%) | L 15s (boss 66%) |
| king_slime | expected_a1 | hard | K | L 72s (boss 15%) | W 68s (min 4%) |
| king_slime | expected_a1 | normal | F | L 23s (boss 27%) | L 19s (boss 33%) |
| king_slime | expected_a1 | normal | K | W 84s (min 45%) | W 60s (min 62%) |
| giant_frog | expected_a1 | hard | F | L 15s (boss 65%) | L 12s (boss 68%) |
| giant_frog | expected_a1 | hard | K | L 39s (boss 54%) | L 28s (boss 60%) |
| giant_frog | expected_a1 | normal | F | L 19s (boss 43%) | L 18s (boss 41%) |
| giant_frog | expected_a1 | normal | K | L 34s (boss 47%) | L 43s (boss 27%) |
| demon_cyclops | expected_a2 | hard | F | L 21s (boss 58%) | L 16s (boss 65%) |
| demon_cyclops | expected_a2 | hard | K | L 91s (boss 34%) | L 84s (boss 15%) |
| demon_cyclops | expected_a2 | normal | F | L 36s (boss 3%) | L 24s (boss 34%) |
| demon_cyclops | expected_a2 | normal | K | L 99s (boss 23%) | W 87s (min 10%) heal 6% |
| weeping_spirit | expected_a2 | hard | F | L 29s (boss 33%) | L 22s (boss 45%) |
| weeping_spirit | expected_a2 | hard | K | L 140s (boss 15%) | W 82s (min 19%) heal 6% |
| weeping_spirit | expected_a2 | normal | F | W 38s (min 32%) heal 7% | L 27s (boss 17%) |
| weeping_spirit | expected_a2 | normal | K | L 118s (boss 25%) | W 75s (min 57%) heal 12% |
| azure_wyrm | expected_a2 | hard | F | L 19s (boss 62%) | L 15s (boss 68%) |
| azure_wyrm | expected_a2 | hard | K | L 49s (boss 55%) | L 63s (boss 31%) |
| azure_wyrm | expected_a2 | normal | F | L 29s (boss 21%) | L 26s (boss 21%) |
| azure_wyrm | expected_a2 | normal | K | L 72s (boss 24%) | L 57s (boss 26%) |
| crimson_tengu | expected_a3 | hard | F | L 41s (boss 3%) heal 48% | L 17s (boss 64%) heal 10% |
| crimson_tengu | expected_a3 | hard | K | W 103s (min 59%) heal 83% | L 45s (boss 23%) heal 11% |
| crimson_tengu | expected_a3 | normal | F | W 40s (min 78%) heal 81% | L 28s (boss 19%) heal 13% |
| crimson_tengu | expected_a3 | normal | K | W 90s (min 62%) heal 73% | W 67s (min 36%) heal 28% |
| red_samurai | expected_a3 | hard | F | L 21s (boss 49%) heal 34% | L 14s (boss 65%) heal 8% |
| red_samurai | expected_a3 | hard | K | L 80s (boss 4%) heal 58% | L 34s (boss 49%) heal 13% |
| red_samurai | expected_a3 | normal | F | L 27s (boss 24%) heal 38% | L 19s (boss 39%) heal 9% |
| red_samurai | expected_a3 | normal | K | W 77s (min 24%) heal 66% | L 56s (boss 0%) heal 15% |
| jade_wyrm | expected_a3 | hard | F | W 40s (min 25%) heal 57% | L 19s (boss 51%) heal 10% |
| jade_wyrm | expected_a3 | hard | K | L 90s (boss 10%) heal 58% | L 49s (boss 30%) heal 13% |
| jade_wyrm | expected_a3 | normal | F | W 38s (min 80%) heal 82% | L 26s (boss 16%) heal 12% |
| jade_wyrm | expected_a3 | normal | K | W 81s (min 33%) heal 67% | W 57s (min 2%) heal 20% |
| gilded_hoarder | expected_a4 | hard | F | W 71s (min 7%) heal 62% | L 24s (boss 67%) heal 11% |
| gilded_hoarder | expected_a4 | hard | K | W 99s (min 4%) heal 66% | L 78s (boss 17%) heal 24% |
| gilded_hoarder | expected_a4 | normal | F | W 52s (min 83%) heal 100% | L 38s (boss 25%) heal 15% |
| gilded_hoarder | expected_a4 | normal | K | W 97s (min 81%) heal 97% | L 59s (boss 3%) heal 17% |
| sun_wraith | expected_a4 | hard | F | W 51s (min 37%) heal 64% | L 22s (boss 62%) heal 10% |
| sun_wraith | expected_a4 | hard | K | W 79s (min 85%) heal 100% | W 60s (min 24%) heal 18% |
| sun_wraith | expected_a4 | normal | F | W 44s (min 89%) heal 96% | L 26s (boss 42%) heal 11% |
| sun_wraith | expected_a4 | normal | K | W 62s (min 76%) heal 96% | W 62s (min 63%) heal 40% |

After the last Giant Frog and Azure Wyrm changes (Frog: leap x1.0 too, 700 Health, spit every 3.5 s; Wyrm: 1000 Health instead of 1100, Frost Breath and Hailstorm x0.42 instead of x0.5), same seed:

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| giant_frog | expected_a1 | hard | F | L 15s (boss 65%) | L 12s (boss 65%) |
| giant_frog | expected_a1 | hard | K | L 39s (boss 54%) | L 43s (boss 26%) |
| giant_frog | expected_a1 | normal | F | L 19s (boss 43%) | L 16s (boss 37%) |
| giant_frog | expected_a1 | normal | K | L 34s (boss 47%) | L 36s (boss 22%) |
| azure_wyrm | expected_a2 | hard | F | L 19s (boss 62%) | L 17s (boss 58%) |
| azure_wyrm | expected_a2 | hard | K | L 49s (boss 55%) | L 69s (boss 13%) |
| azure_wyrm | expected_a2 | normal | F | L 29s (boss 21%) | L 29s (boss 12%) |
| azure_wyrm | expected_a2 | normal | K | L 72s (boss 24%) | L 67s (boss 5%) |

Degenerate builds (engine, measured before the Red Samurai / Giant Frog changes and the bot's
hold-the-last-hit refinement):

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| king_slime | degenerate_attack_speed_a1 | hard | F | L 14s (boss 49%) | L 14s (boss 54%) |
| king_slime | degenerate_attack_speed_a1 | hard | K | L 66s (boss 21%) | L 67s (boss 8%) |
| king_slime | degenerate_attack_speed_a1 | normal | F | L 17s (boss 33%) | L 14s (boss 32%) |
| king_slime | degenerate_attack_speed_a1 | normal | K | L 62s (boss 10%) | W 56s (min 33%) |
| king_slime | degenerate_lifesteal_a1 | hard | F | L 25s (boss 47%) heal 38% | L 15s (boss 65%) heal 9% |
| king_slime | degenerate_lifesteal_a1 | hard | K | L 97s (boss 5%) heal 59% | W 66s (min 22%) heal 26% |
| king_slime | degenerate_lifesteal_a1 | normal | F | L 35s (boss 2%) heal 44% | L 23s (boss 33%) heal 11% |
| king_slime | degenerate_lifesteal_a1 | normal | K | W 66s (min 73%) heal 89% | W 49s (min 2%) heal 16% |
| giant_frog | degenerate_attack_speed_a1 | hard | F | L 12s (boss 49%) | L 9s (boss 63%) |
| giant_frog | degenerate_attack_speed_a1 | hard | K | L 23s (boss 66%) | L 31s (boss 33%) |
| giant_frog | degenerate_attack_speed_a1 | normal | F | L 13s (boss 36%) | L 12s (boss 32%) |
| giant_frog | degenerate_attack_speed_a1 | normal | K | L 30s (boss 51%) | L 30s (boss 28%) |
| giant_frog | degenerate_lifesteal_a1 | hard | F | L 22s (boss 42%) heal 37% | L 13s (boss 66%) heal 9% |
| giant_frog | degenerate_lifesteal_a1 | hard | K | L 51s (boss 34%) heal 50% | L 45s (boss 31%) heal 16% |
| giant_frog | degenerate_lifesteal_a1 | normal | F | L 24s (boss 30%) heal 37% | L 17s (boss 45%) heal 10% |
| giant_frog | degenerate_lifesteal_a1 | normal | K | L 60s (boss 25%) heal 50% | W 64s (min 25%) heal 27% |
| demon_cyclops | degenerate_crit_a2 | hard | F | W 9s (min 25%) | W 8s (min 19%) |
| demon_cyclops | degenerate_crit_a2 | hard | K | W 18s (min 54%) | W 26s (min 6%) |
| demon_cyclops | degenerate_crit_a2 | normal | F | W 8s (min 39%) | W 8s (min 12%) |
| demon_cyclops | degenerate_crit_a2 | normal | K | L 27s (boss 25%) | L 25s (boss 0%) |
| demon_cyclops | degenerate_lifesteal_a2 | hard | F | L 22s (boss 52%) heal 37% | L 13s (boss 72%) heal 8% |
| demon_cyclops | degenerate_lifesteal_a2 | hard | K | W 124s (min 5%) heal 66% | L 76s (boss 21%) heal 23% |
| demon_cyclops | degenerate_lifesteal_a2 | normal | F | L 24s (boss 38%) heal 38% | L 16s (boss 54%) heal 9% |
| demon_cyclops | degenerate_lifesteal_a2 | normal | K | W 98s (min 10%) heal 55% | L 62s (boss 10%) heal 17% |
| weeping_spirit | degenerate_crit_a2 | hard | F | W 8s (min 36%) | W 7s (min 3%) |
| weeping_spirit | degenerate_crit_a2 | hard | K | W 19s (min 75%) | W 18s (min 75%) |
| weeping_spirit | degenerate_crit_a2 | normal | F | W 7s (min 43%) | W 8s (min 39%) |
| weeping_spirit | degenerate_crit_a2 | normal | K | W 16s (min 73%) | W 20s (min 78%) |
| weeping_spirit | degenerate_lifesteal_a2 | hard | F | L 28s (boss 32%) heal 40% | L 17s (boss 57%) heal 9% |
| weeping_spirit | degenerate_lifesteal_a2 | hard | K | W 95s (min 30%) heal 70% | W 66s (min 44%) heal 34% |
| weeping_spirit | degenerate_lifesteal_a2 | normal | F | W 31s (min 31%) heal 53% | L 18s (boss 41%) heal 10% |
| weeping_spirit | degenerate_lifesteal_a2 | normal | K | W 88s (min 87%) heal 100% | W 52s (min 51%) heal 27% |
| azure_wyrm | degenerate_crit_a2 | hard | F | W 10s (min 32%) | L 10s (boss 0%) |
| azure_wyrm | degenerate_crit_a2 | hard | K | L 22s (boss 32%) | L 20s (boss 24%) |
| azure_wyrm | degenerate_crit_a2 | normal | F | W 7s (min 47%) | W 7s (min 30%) |
| azure_wyrm | degenerate_crit_a2 | normal | K | L 25s (boss 6%) | W 15s (min 46%) |
| azure_wyrm | degenerate_lifesteal_a2 | hard | F | L 19s (boss 65%) heal 34% | L 13s (boss 69%) heal 8% |
| azure_wyrm | degenerate_lifesteal_a2 | hard | K | L 61s (boss 42%) heal 54% | L 47s (boss 45%) heal 15% |
| azure_wyrm | degenerate_lifesteal_a2 | normal | F | L 31s (boss 15%) heal 43% | L 18s (boss 51%) heal 10% |
| azure_wyrm | degenerate_lifesteal_a2 | normal | K | L 107s (boss 20%) heal 64% | L 52s (boss 30%) heal 19% |
| crimson_tengu | degenerate_burn_a3 | hard | F | L 22s (boss 38%) heal 32% | L 19s (boss 51%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | hard | K | L 65s (boss 25%) heal 32% | L 54s (boss 8%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | normal | F | W 27s (min 5%) heal 41% | L 23s (boss 15%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | normal | K | L 66s (boss 11%) heal 31% | W 62s (min 6%) heal 46% |
| crimson_tengu | degenerate_lifesteal_a3 | hard | F | L 25s (boss 59%) heal 39% | L 13s (boss 78%) heal 8% |
| crimson_tengu | degenerate_lifesteal_a3 | hard | K | L 113s (boss 16%) heal 64% | L 82s (boss 23%) heal 23% |
| crimson_tengu | degenerate_lifesteal_a3 | normal | F | L 40s (boss 7%) heal 48% | L 19s (boss 62%) heal 10% |
| crimson_tengu | degenerate_lifesteal_a3 | normal | K | L 101s (boss 26%) heal 50% | W 76s (min 42%) heal 33% |
| crimson_tengu | degenerate_skills_a3 | hard | F | L 20s (boss 22%) heal 34% | L 11s (boss 60%) heal 7% |
| crimson_tengu | degenerate_skills_a3 | hard | K | W 28s (min 96%) heal 100% | W 34s (min 78%) heal 45% |
| crimson_tengu | degenerate_skills_a3 | normal | F | W 18s (min 72%) heal 68% | W 15s (min 6%) heal 9% |
| crimson_tengu | degenerate_skills_a3 | normal | K | L 19s (boss 29%) heal 13% | W 15s (min 87%) heal 32% |
| red_samurai | degenerate_burn_a3 | hard | F | L 15s (boss 66%) heal 28% | L 13s (boss 70%) heal 31% |
| red_samurai | degenerate_burn_a3 | hard | K | L 36s (boss 70%) heal 25% | L 25s (boss 60%) heal 26% |
| red_samurai | degenerate_burn_a3 | normal | F | L 22s (boss 33%) heal 32% | L 18s (boss 39%) heal 30% |
| red_samurai | degenerate_burn_a3 | normal | K | L 38s (boss 32%) heal 29% | L 40s (boss 26%) heal 30% |
| red_samurai | degenerate_lifesteal_a3 | hard | F | L 17s (boss 68%) heal 33% | L 12s (boss 79%) heal 6% |
| red_samurai | degenerate_lifesteal_a3 | hard | K | L 37s (boss 84%) heal 43% | L 37s (boss 72%) heal 8% |
| red_samurai | degenerate_lifesteal_a3 | normal | F | L 26s (boss 52%) heal 40% | L 12s (boss 75%) heal 8% |
| red_samurai | degenerate_lifesteal_a3 | normal | K | L 66s (boss 41%) heal 55% | L 62s (boss 40%) heal 17% |
| red_samurai | degenerate_skills_a3 | hard | F | L 8s (boss 44%) heal 17% | L 7s (boss 43%) heal 5% |
| red_samurai | degenerate_skills_a3 | hard | K | W 24s (min 49%) heal 45% | W 18s (min 23%) heal 10% |
| red_samurai | degenerate_skills_a3 | normal | F | W 11s (min 40%) heal 39% | L 7s (boss 33%) heal 6% |
| red_samurai | degenerate_skills_a3 | normal | K | W 14s (min 84%) heal 94% | W 13s (min 11%) heal 8% |
| jade_wyrm | degenerate_burn_a3 | hard | F | L 22s (boss 43%) heal 29% | L 17s (boss 56%) heal 32% |
| jade_wyrm | degenerate_burn_a3 | hard | K | L 48s (boss 54%) heal 30% | L 47s (boss 31%) heal 31% |
| jade_wyrm | degenerate_burn_a3 | normal | F | L 31s (boss 2%) heal 31% | L 23s (boss 23%) heal 33% |
| jade_wyrm | degenerate_burn_a3 | normal | K | L 64s (boss 31%) heal 30% | L 50s (boss 5%) heal 31% |
| jade_wyrm | degenerate_lifesteal_a3 | hard | F | L 25s (boss 62%) heal 39% | L 17s (boss 68%) heal 9% |
| jade_wyrm | degenerate_lifesteal_a3 | hard | K | L 90s (boss 39%) heal 64% | L 59s (boss 40%) heal 17% |
| jade_wyrm | degenerate_lifesteal_a3 | normal | F | L 33s (boss 30%) heal 42% | L 19s (boss 63%) heal 10% |
| jade_wyrm | degenerate_lifesteal_a3 | normal | K | L 45s (boss 63%) heal 48% | L 50s (boss 38%) heal 15% |
| jade_wyrm | degenerate_skills_a3 | hard | F | W 18s (min 15%) heal 38% | L 14s (boss 48%) heal 8% |
| jade_wyrm | degenerate_skills_a3 | hard | K | W 28s (min 22%) heal 49% | W 19s (min 39%) heal 14% |
| jade_wyrm | degenerate_skills_a3 | normal | F | W 12s (min 55%) heal 49% | W 10s (min 32%) heal 11% |
| jade_wyrm | degenerate_skills_a3 | normal | K | W 20s (min 80%) heal 81% | W 11s (min 71%) heal 17% |
| gilded_hoarder | degenerate_lifesteal_a4 | hard | F | L 32s (boss 49%) heal 44% | L 17s (boss 66%) heal 9% |
| gilded_hoarder | degenerate_lifesteal_a4 | hard | K | L 129s (boss 33%) heal 69% | L 68s (boss 21%) heal 21% |
| gilded_hoarder | degenerate_lifesteal_a4 | normal | F | W 43s (min 3%) heal 51% | L 21s (boss 57%) heal 11% |
| gilded_hoarder | degenerate_lifesteal_a4 | normal | K | W 117s (min 5%) heal 72% | W 94s (min 30%) heal 36% |
| gilded_hoarder | degenerate_max_health_a4 | hard | F | W 117s (min 93%) heal 98% | L 76s (boss 33%) heal 55% |
| gilded_hoarder | degenerate_max_health_a4 | hard | K | W 235s (min 2%) heal 82% | W 161s (min 4%) heal 69% |
| gilded_hoarder | degenerate_max_health_a4 | normal | F | W 88s (min 99%) heal 98% | W 81s (min 4%) heal 57% |
| gilded_hoarder | degenerate_max_health_a4 | normal | K | W 189s (min 77%) heal 100% | W 128s (min 34%) heal 35% |
| gilded_hoarder | degenerate_thorns_a4 | hard | F | W 143s (min 77%) heal 63% | L 112s (boss 16%) heal 67% |
| gilded_hoarder | degenerate_thorns_a4 | hard | K | T 240s (boss 33%) heal 96% | T 240s (boss 14%) heal 73% |
| gilded_hoarder | degenerate_thorns_a4 | normal | F | W 116s (min 98%) heal 97% | W 103s (min 1%) heal 75% |
| gilded_hoarder | degenerate_thorns_a4 | normal | K | T 240s (boss 26%) heal 96% | W 233s (min 15%) heal 64% |
| sun_wraith | degenerate_lifesteal_a4 | hard | F | L 30s (boss 50%) heal 42% | L 18s (boss 63%) heal 10% |
| sun_wraith | degenerate_lifesteal_a4 | hard | K | L 99s (boss 3%) heal 59% | W 58s (min 22%) heal 22% |
| sun_wraith | degenerate_lifesteal_a4 | normal | F | L 39s (boss 0%) heal 45% | L 22s (boss 43%) heal 11% |
| sun_wraith | degenerate_lifesteal_a4 | normal | K | W 89s (min 86%) heal 100% | W 59s (min 43%) heal 29% |
| sun_wraith | degenerate_max_health_a4 | hard | F | W 82s (min 97%) heal 100% | W 79s (min 0%) heal 56% |
| sun_wraith | degenerate_max_health_a4 | hard | K | W 142s (min 73%) heal 79% | W 110s (min 18%) heal 29% |
| sun_wraith | degenerate_max_health_a4 | normal | F | W 69s (min 99%) heal 100% | W 65s (min 2%) heal 60% |
| sun_wraith | degenerate_max_health_a4 | normal | K | W 128s (min 10%) heal 69% | W 83s (min 72%) heal 46% |
| sun_wraith | degenerate_thorns_a4 | hard | F | W 98s (min 95%) heal 100% | L 92s (boss 1%) heal 63% |
| sun_wraith | degenerate_thorns_a4 | hard | K | T 240s (boss 6%) heal 92% | W 141s (min 56%) heal 71% |
| sun_wraith | degenerate_thorns_a4 | normal | F | W 75s (min 96%) heal 96% | W 80s (min 1%) heal 71% |
| sun_wraith | degenerate_thorns_a4 | normal | K | W 220s (min 90%) heal 98% | W 142s (min 6%) heal 76% |

Family builds (act III, Normal): the face-tank won 7 of 15 fights before, **0 of 15** after; their
heal share is 7-33% (was up to 65%). The kite wins 7 of 15 (was 7), Red Samurai being the wall
(all five lost at 11-15%: measured before the Flame Arc change).

#### For the other passes

- **B (monsters, elites, difficulties): the armor rule makes monsters hit armored heroes 2-3x
  harder.** Model, every act monster at its depths on Normal vs the act's expected build:

  | Act | Expected build's armor | Average monster hit (before -> after) | Average damage per second | Average hits to kill the hero |
  |---|---|---|---|---|
  | I | 2 | 3.7 -> 4.4 | 2.5 -> 2.9 | 38 -> 30 |
  | II | 7 | 2.2 -> 5.3 | 1.6 -> 3.8 | 116 -> 40 |
  | III | 10 | 3.6 -> 8.0 | 2.0 -> 4.5 | 88 -> 30 |
  | IV | 13 | 3.2 -> 9.2 | 1.9 -> 5.6 | 119 -> 32 |

  Hits to kill the hero are still far above the target (>= 6), and rooms cost more (the
  baseline's "monsters are harmless" finding). Measure before also buffing monster damage: the two
  compound. The rule also helps the hero's small hits against armored monsters (5 vs 4 armor:
  3 instead of 1) and burns against armor (6 vs 5: 3 instead of 1).
- **C (perks, runes, relics, weapons, shrine):** the remaining face-tank wins on Normal are the
  builds' own power, not the bosses': `degenerate_crit_a2` kills act II bosses in 7-8 s (82%
  crit, 3 Shatter runes), `degenerate_skills_a3` kills Crimson Tengu and Jade Wyrm in 10-15 s;
  `degenerate_max_health_a4` and `degenerate_thorns_a4` beat both act IV bosses at 1-4% of their
  health, carried by two revives (Phoenix Feather / cheat death: 187-386 Health) and the Templar
  Sword's Holy Shield and Smite (unlimited healing spells: 75-300 Health a fight). Frost Armor
  and the Fortified affix lose much of their value with diminishing armor (re-measure them).
  Kill-heal picks lose their boss-fight credit in the lab: "marginal: too weak" now flags
  Vampirism x3 in act II (0.15x the median) because its value came from sustain the boss-fight
  budget no longer pays.

#### Open

- Ranked bosses (Epic, Legendary, Shiny) were not re-measured (the kite's damage per second
  roughly doubled, so their projected 100-191 s should drop: measure).
- The heal-share target (<= 25% of the damage taken) reads high for good kite fights: a kite that
  takes 50 damage and heals 20 is at 40% while healing 0.4% of its Health a second. Proposal:
  check it on face-tank fights (where it means "out-healing the boss") and judge kite fights by
  healing per second vs the boss' damage per second on that build.
- The kite still loses some Hard fights and a few Normal ones by a little; it still eats some
  shockwaves (side hits from chains, shards and thorns can finish the streak) and falls when
  thrown off. A lost kite fight is "hard for a careful player", not "impossible".
- Guard checks (balance suite, `_boss_guards`): a 36-armor build is hit for more than 1 by most
  act IV monsters; a minute of boss-fight sustain heals <= 35% of the act IV build's Health; the
  expected build face-tanking each act's boss on Normal loses with <= 25% healed. Unit tests: the
  armor formula (monotonic, never harmless, the examples above) and the boss-fight budget.

### 2026-10-20 - Phase 2 baseline measured (tools only, no game data changed)

`--mode=all --jobs=2`, seed 1, all six difficulties (39 min; the marginal values were run again
after a fix to their dummy rooms and merged with `--mode=merge`). 136 errors, 541 warnings.
Headline numbers (report.md and data.json of that run are the "before" of phase 2):

- **Face-tank beats bosses.** Expected builds on Normal: the face-tank bot wins 5 of 10 boss
  fights (Weeping Spirit, Crimson Tengu, Jade Wyrm, Gilded Hoarder, Sun Wraith); on Hard 3. From
  act III, one Leech rune heals 66-100% of the damage taken in a boss fight (Gilded Hoarder:
  236 of 236; target <= 25%): the boss-fight budget (2% of max Health a second = 5.7/s at act IV)
  is as large as the act IV boss' damage per second on that build (5.65/s).
- **Flat armor.** Builds with 32-36 armor face-tank act IV bosses at 93-99% health; every act IV
  monster hits them for 1. Frost Armor x4 (+252%) and the Fortified affix (+301%) are the top
  picks of act III.
- **Degenerate stacks.** Crit (Rapier, 82% crit, 3 Shatter runes) kills act II bosses in 7-10 s
  standing still; skills/cooldowns (3 Echo runes, Echo, Devotion) in 11-18 s with Devotion's heals.
- **Monsters are harmless to the expected builds.** Rooms cost 0-2% of max health on Normal;
  commons die in 0.2-0.9 s, elites in 0.5-1.5 s (target 3-10 s); act II commons hit for 1-3.
- **The curve.** Boss threat act II vs act I x0.79, act IV vs act III x0.62 (act IV easier than
  act III). The kite bot loses all three act II bosses on Normal (boss at 23-25%).
- **Economy.** A merchant visit's gold buys 4-23 average items on Normal (target 0.8-3); the whole
  shrine (3150 souls) takes ~13 average runs on Normal, ~3 on Nightmare.

Open: see FLAGS of that report; method in .claude/agents/game-balancer.md.

### 2026-10-20 - Phase 1: rules and themes (no simulator yet)

Everything here was done by reading the code and the data; nothing was measured on the arena yet
(tools/balance is being built). Phase 2 measures and tunes the numbers below.

#### Sustain rules changed (code, unit and game tests)

The owner could beat a boss by standing still with Vampirism or a life-drain rune. Causes found:
lifesteal rounded every hit up (`roundi`: 8% of a 7-damage hit healed 1, i.e. 14%; every bolt of
the Arcane ring healed 1), on-kill heals fed on a boss's summoned adds, and nothing limited
stacking (three Leech runes, Vampirism, the Blood family and the Fury rune all added up).

| Rule | Before | After | Where |
|---|---|---|---|
| Ticks and secondary hits | lifesteal only skipped them because `Actor.take_hit` drops the attacker of secondary hits; Ice Shards' shards and the Arcane ring of bolts were direct hits (lifesteal, chain counters, Kindling...) | `LifestealPassive` ignores `is_tick` / `is_secondary` itself; shots fired by passives are secondary (`ProjectileSpec.secondary`, `ProjectileEffect.secondary`, set on the Arcane ring and on kill-burst shards) and get no extra projectiles from Multishot / Prism | lifesteal_passive.gd, projectile.gd, kill_burst_passive.gd, world.gd |
| Rounding | `roundi` per hit (and `maxi(1, ...)` per kill for the Blood family) | fractions add up per actor (`SustainMeter.pending`), paid in whole points; nothing banked at full health | src/combat/sustain_meter.gd |
| Shared limit | none | one budget for every heal from hits, kills and skills (Leech, Vampirism, Devotion, the Blood family, Fury, Vampiric gear): holds **20%** of max Health, refills **4% of max Health per second** | data/dungeon/sustain.tres (`SustainRules`, `DungeonConfig.sustain`) |
| Boss fights | same as anywhere | the budget refills at **x0.5** (2% of max Health per second) while `World.is_boss_fight()` | `SustainRules.boss_fight_rate` |
| Summons and adds | on-kill heals counted every kill | summoned monsters (`Monster.summoned`) and, during a boss fight, every non-boss kill feed no on-kill heal (`Actor.can_heal_killer()`); Fortune drops nothing from summons either (their own loot was already off) | monster.gd, heal_on_kill / bloodlust / loot_on_kill passives |

Monsters keep whole-point accumulation but no budget (a Vampiric elite heals as before).
Potions, springs, healing spells (Smite, Holy Light, Holy Shield), the Easy difficulty's heal on a
new floor and the level-up full heal are not limited: they are deliberate, scarce or between
fights.

What it means for a 100-Health hero: up to 20 Health at once (a pack of 3 slain together with
Vampirism 3 still heals fully), then 4 per second; 2 per second against a boss. One Leech rune on
a katana (9 damage, 2.6 hits a second = 2.3 Health a second) is never cut against packs; against
a boss with 5 Armor (about 5 damage a hit, 1.3 a second) it is under the boss-fight limit too.
Three Leech runes, or Leech + Vampirism + Blood, hit the limit and stop there.

Leech: 8% -> **10%** (exact now instead of rounded up: at act I damage the old 8% healed 12-14%
per hit, so 10% keeps the pack fantasy). Description: "Your hits heal 10% of the damage they deal
(burns and side effects don't)."

Guard tests: unit `_test_sustain` (fractions, full health, the burst, the rate, the boss-fight
rate, a minute of stacked sustain stays under the limit, a single Leech rune is never cut);
game `_test_sustain_in_game` (a burn tick and a secondary hit heal nothing, 6 small hits heal
floor(total x 10%), a shard fired by a perk heals nothing, three Leech runes on 40-damage hits
every frame for a second heal no more than the budget, a summoned rat's death heals nothing, an
ordinary one does); boss `_test_boss_fight` (adds, summoned or not, heal nothing; the boss does).

#### Families: what moved and why

Fantasies (pillar 4): Inferno = fire, burning; Frost = cold, slows, freezing; Blood = health, life
drain, low-health power; Storm = lightning, chains, speed of the strike; Arcane = skills, spells,
cooldowns. Plain-number perks belong to no family.

Before (common perks | relics):

| Family | Perks | Misfits |
|---|---|---|
| Inferno | Ignite, Frenzy, Kindling, Blazing Roll \| War Banner, Phoenix Feather | Frenzy (pure attack speed), War Banner (damage, crit, attack speed) |
| Frost | Frostbite, Cold Snap, Ice Shards \| Guardian Ring | only 3 common perks; Guardian Ring a plain ward |
| Blood | Vampirism, Strength, Vitality, Thorns \| Executioner | Strength (pure damage), Thorns (nothing about blood) |
| Storm | Precision, Thunderclap, Shock Roll, Swiftness \| Multishot | Precision (crits, nothing electric), Multishot (extra projectiles) |
| Arcane | Arcane Focus, Arcane Power, Devotion, Echo \| Sage's Codex, Multishot | - |
| none | Fortune, Iron Skin | |

After:

| Family | Common perks | Relics | Members |
|---|---|---|---|
| Inferno | Ignite, Kindling, Blazing Roll, **Burning Thorns** | Phoenix Feather | 5 |
| Frost | Frostbite, Cold Snap, Ice Shards, **Frost Armor** | Guardian Ring | 5 |
| Blood | Vampirism, Vitality, **Bloodrage** (new), **Devotion** | Executioner | 5 |
| Storm | **Frenzy**, Thunderclap, Shock Roll, Swiftness | - | 4 |
| Arcane | Arcane Focus, Arcane Power, Devotion, Echo | Sage's Codex, Multishot | 6 |
| none | **Strength**, **Precision**, Fortune | **War Banner** | |

- **Frenzy** Inferno -> Storm: attack speed is the speed of the strike; its icon (flying kunai)
  already said so. Color changed to Storm's.
- **War Banner** Inferno -> none: damage, crit and attack speed are plain numbers.
- **Multishot** Storm + Arcane -> Arcane: more projectiles (fireballs included) is a spell thing,
  nothing electric about it.
- **Precision** Storm -> none: crit chance and an opening crit are plain numbers.
- **Strength** Blood -> none: +damage is not blood.
- **Thorns** Blood -> Inferno, light rework **Burning Thorns**: enemies that hit you up close take
  4 damage per level *and catch fire* (2 every 0.5 s for 3 s). `ThornsPassive.status` (optional).
  Same id, same icon (orange spikes), Inferno's color. The "of Thorns" affix and Spiked elites
  are unchanged.
- **Iron Skin** none -> Frost, light rework **Frost Armor**: +1 Armor per level, and getting hit
  releases a wave of cold that throws enemies back *and slows them 40%* (once every 3 s).
  `RetaliatePassive.status` (optional). Same id, same icon (an icy shield), Frost's color.
- **Devotion** Arcane -> Arcane + Blood: healing with every skill is both.
- **Bloodrage** (new Blood common, icon recolored from Strength's): below half Health, +15% damage
  per level (max 3). `BloodlustPassive` bonus is now per level (the family and the Fury rune have
  1 level: unchanged).
- **Guardian Ring** stays Frost: "Every floor starts with a shell of frost that soaks up 20
  damage" (the ward already breaks in icy sparkles).

Every family has 4 common perks; sizes 4-6 with relics. Guard test: unit `_test_family_themes`
(4+ common perks each, sizes within 2, the moves above, plain-number perks familyless, no
HP/ATK/DEF in perk, family or rune texts).

Runes (all kept in their family):

| Rune | Family | Effect | Note |
|---|---|---|---|
| Ember | Inferno | hits 35% chance to burn | fits |
| Pyre | Inferno | burning deaths burst into flames | fits |
| Rime | Frost | hits slow 20% | fits |
| Shatter | Frost | crits release a shockwave | **was a plain shockwave**: now it also slows 40% for 1.5 s (`CritShockwavePassive.status`) |
| Leech | Blood | hits heal 10% of their damage | was 8% rounded up per hit |
| Fury | Blood | below half +30% damage, kills heal 2% | fits |
| Spark | Storm | every 4th hit chains to 2 | fits |
| Gale | Storm | the roll throws a gust | wind of a storm: fits |
| Echo | Arcane | skills 12% ready again | fits |
| Prism | Arcane | +1 projectile | fits; strength to measure (below) |

Plain words: "HP" replaced by "Health" in Vampirism, Devotion, Executioner, Phoenix Feather, the
Blood family, the Fury rune and the Vampiric affix.

#### Static sanity pass

Fixed (clear-cut):
- **Strength** max level 5 -> 3 (+10 -> +6 damage). It was the only damage perk with 5 levels,
  and flat damage is worth double against flat Armor (`Combat.mitigate`): at max, a katana at
  level 6 (10 power) against a boss with 5 Armor went from 5 to 15 damage a hit (x3), against
  +48% for Frenzy or +60% for Arcane Power at max. Now x2.2 there, +60% raw.

Listed for phase 2 (need measuring, not clear-cut from reading):
- **Multishot** (max 2: three shots) and **Prism** (stackable, 3 sockets on an Epic) on
  single-shot weapons (Bow, Spark Wand, Fireball): up to x3-x4 damage if the fan hits; depends on
  range and spread (12 degrees per projectile).
- **Ignite** max 3: a flat 6 every 0.5 s (12 a second per target, AoE weapons spread it) is huge
  in act I (a slime has 26 Health) and fades later (Armor eats ticks, no depth scaling).
- **Vitality** max 5: +75 Health when the hero starts at 60.
- **Executioner** +120% at max under 35% Health.
- **Echo** perk 45% at max + Echo runes (each rolls on its own) + of Echoes: cooldown loops.
- **Frost Armor** max 4: +4 Armor makes many weak hits deal 1 (`Combat.mitigate` minimum).
- **Swiftness** +75% for 1.5 s after a roll at max, with roll-on-cooldown builds.

#### Open questions for phase 2 (to measure with the arena)

1. Face-tank vs kite for each boss with: no sustain, one Leech rune, three Leech runes,
   Vampirism 3 + Blood awake + Fury. Must the face-tank lose with every one? Is
   `boss_fight_rate` 0.5 needed, enough, or too harsh (try 1.0 / 0.5 / 0.25)?
2. Packs: healing by source per minute with the same builds: does `burst` 20% / `rate` 4% leave
   Leech and Vampirism feeling good (most kills fully paid)? Target: a single sustain source is
   never capped on packs.
3. Family strength side by side (time to clear a pack room, boss time) for the five awake
   families: the Arcane ring is now secondary (no Frost/Kindling bonus, no lifesteal, no extra
   projectiles from Multishot/Prism) - check Arcane didn't fall behind; Storm has no relic.
4. Strength (now 3 levels) against Frenzy, Arcane Power, Kindling at max, on fast (Rapier, Sai)
   and slow (War Hammer) weapons, against Armor 0 and 5.
5. Multishot / Prism on Bow, Spark Wand, Fireball: damage per second at 64, 128, 256 px.
6. Ignite and Ember at act I vs act IV (flat burns against depth scaling and Armor).
7. Bloodrage + Blood + Fury below half Health (+115%): with sustain limited, is staying low a
   real risk/reward or a trap?
8. Vampiric elites and Vampiric bosses (60% lifesteal, monsters have no budget): fight length.
9. Burning Thorns and Frost Armor against swarms (Swarm floors) and act IV damage.
10. The level-up full heal: can a fight be turned by XP mid-boss? (summons give none; adds that
   are not summoned do: check BossDef summons all set `summoned`.)
