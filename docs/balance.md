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
| `--jobs=2` | `all`: the arena runs in a second Godot process (2 CPUs: about half the time) |
| `--out=` | where the reports go (default `user://balance`) |

Each mode writes `<out>/<mode>/report.md`, `data.json`, `csv/<table>.csv` and `state.json`
(for `merge`); `--mode=all` also writes `<out>/report.md` and `<out>/data.json` with everything,
and prints a short summary (flags per category, the first ones). Exit code 0: flags are findings.

Run time on 2 CPUs (2026-10-20, all six difficulties): model ~5 s; economy ~3 min; compound
~5 min; pack ~15 min; marginal ~30 min; arena (boss fights and the weapon arena) ~40 min. With
`--jobs=2` a full `--mode=all` takes about 55 min of real time. `--quick` modes take seconds to a
minute each.

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
  keeps its weapon's range and rolls away from wind-ups, casts, shots and the boss' shockwave.
  Every boss x the builds of its act (expected on every difficulty; degenerate, family and baseline
  builds on Normal and Hard) x both bots; every boss rank (Epic, Legendary, Shiny, with the affixes
  the game rolls) with the expected build on Normal and Hard. Result, time, phase reached, boss
  health left (and the time to kill projected from it), damage dealt and taken, hits, healing by
  source (perk, rune, affix, family, skill, item, revive), lowest health. Then the **weapon arena**:
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

### Hooks in the game code (behaviour-neutral)

`Actor.healed(amount, source)` and `Actor.heal_source` tag every heal with what caused it (set for
the length of a call by `PerkSet`, `SkillSet.try_use` and `ConsumableDef.use`); nothing in the game
listens. `PerkSet.Entry.source_tag()` names a perk, family, rune or affix for it. That's all: the
tools drive the game through its input actions, its data and its public nodes.

## Balance log

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
