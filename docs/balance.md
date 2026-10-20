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
  kill, hits to kill the hero, damage taken while killing it; rank chances per depth; the
  commons' curve and the ranks' ladder (medians per act on Normal, table "monster_ladder"). Every boss
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
| Rank ladder (medians per act, Normal) | each rank >= x1.2 the time to kill of the one below, and costs more health | a rank is a clearly tougher fight, not a recolor |
| Commons' curve (median health lost killing one, act over act) | x0.9-x1.6 (the act curve's step) | each act's monsters a little harder than the last |
| Common monster hits to kill the expected build | >= 6 | never a two-shot |
| Room damage (kite, expected build) / clear time | <= 35% of max health / <= 25 s | a room shouldn't cost half your life when you play well |
| Act curve (boss threat, act over act) | x0.9-x1.6 | a steady curve, no wall (pillar 5) |
| Difficulty vs Normal (boss threat) | Easy x0.2-0.7, Hard x1.3-2.6, Nightmare x2-5, +5 x2.5-8, +10 x3-12 | Easy forgiving, Nightmare demanding, ascensions add twists not walls |
| Any pick at max vs its category's median (marginal value) | 0.5x-2x | every pick a real choice (pillar 2) |
| Degenerate build DPS / expected build's | <= 2.5x | stacking pays, it doesn't trivialise (pillar 3) |
| Weapon DPS vs the median weapon (same rarity, same hero) | 0.75x-1.4x (phase 2C; was 0.6-1.6) | no trap, no only choice |
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

### 2026-10-20 - Phase 2B: common monsters, ranks, elite affixes, difficulties, depth scaling

Measured with `--mode=model` (every monster x rank x depth x difficulty, seed 1) before and after
each change, and `--mode=pack` (engine, Normal and Hard) after. Bosses, sustain, the armor rule,
perks, runes, gear and the economy were left to the other phase 2 passes (A and C): bosses keep
exactly their numbers (their depth scaling now has its own fields, set to the old values; the
model's boss tables and curve are unchanged by this pass).

**Read the last part first ("After merging phase 2A"):** the tables in between were measured
with the old flat armor; 2A's percentage armor made two of the damage changes compound, and
they were reverted.

**What was wrong.** Commons died in 0.2-0.9 s and cost the expected builds 0.3-0.8% of their
Health each (face to face); act II-IV commons needed 100-123 hits to kill the hero on Normal and
the cost *fell* act after act (0.8%, 0.3%, 0.3%, 0.4%: hero Armor grew 2 -> 13 while monster attack
grew +1 per floor). A rank was only more Health (Elite x2.5, Epic x3.5, Legendary x5) and no more
damage, so an Elite died in 1-1.8 s and a Legendary in 2.4-3.9 s for 2.5-3.6% of the hero's Health.

**Changes (data, plus two small rules):**

| What | Before | After | Why |
|---|---|---|---|
| Common monsters' base Health (`data/monsters/*.tres`) | - | x0.8-x2.6 each (act I x1.08-1.6, act II x1.6-2.6, act III x1.3-2.2, act IV x0.8-1.9); the spread compressed (fodder up more than tanks; Dune Rex, the slowest to kill, 85 -> 70) | time to kill to 0.6 / 0.8 / 0.9 / 1.2 s (medians, acts I-IV); act I capped at x1.6 so a level-1 hero on floor 1 still kills a rat in 3-4 hits |
| ~~Act II commons' attack (skeleton, sorcerer, skull, lantern, frost skull, soul moth, brood mother +2; eye, owl +1)~~ | 0 | ~~+1/+2~~ **reverted after 2A** | act II hit the hero for 1-3 after its Armor (7): the cheapest act. Not needed with 2A's armor (below) |
| Act III commons' attack (shaman, flam, reptile, dragon, kappa, octopus, ember heart) | 0 | +1 | keeps act III a little harder than act II |
| `monster_attack_per_depth` (now a float, rounded) | 1 | ~~1.5~~ **1.0 after 2A** (monsters only) | was: monster damage kept up with the hero's flat Armor. With 2A's armor it compounded (below) |
| `boss_hp_scale_per_depth`, `boss_attack_per_depth` (new) | (shared) | 0.22, 1.0 = the old values | bosses are tuned one by one (phase 2A): the monsters' scaling no longer moves them |
| `MonsterRankDef.hp_multiplier_per_depth` (new rule) | - | Elite 2.5 **+0.3**/floor, Epic **4.5 +0.45**, Legendary **6.5 +0.5**, Shiny **3.3 +0.15** | the hero's damage grows ~x10 over act I and ~x3 after: one flat multiplier makes either a floor-1 slog or a deep pushover. Depth 1/5/11: Elite x2.5/x3.7/x5.5, Epic -/x6.3/x9, Legendary -/x8.5/x11.5 |
| `MonsterRankDef.damage_multiplier` (new rule, not bosses) | x1 | Elite **x1.15**, Epic **x1.2**, Legendary **x1.3**, Shiny x1 | a rank is a threat, not only a sponge (kept small: flat Armor turns x1.3 raw into x1.5-x2 after Armor) |
| `elite_chance_per_depth` | 0.015 | **0.012** | tougher elites, a little rarer: act IV Normal 15% (was 18%) |
| Hard / Nightmare `elite_chance` | x1.6 / x2.5 | **x1.4 / x1.7** | with ranks 2-4x tougher, 56% of Nightmare act IV monsters came ranked; now 35% (Nightmare +5: 78% -> 45%; Normal 25% -> 22%). Also bosses' rare-rank chance on those difficulties |
| Ascension 3 "Elite Guard" | elites +50% | **+30%** | same reason; description updated |

`Monster.make_ranked` applies the rank's depth Health and damage (`Monster._depth`, set in
`setup`); `FloorRules.scale_monster` picks the boss or monster depth values; the model
(`foe_numbers`) does the same. README: rank table (Health, Damage per depth) and Elite chance
row updated.

**Before -> after (model, every difficulty, the act's last normal floor, the act's expected build, medians over
the act's monsters).** Time to kill · share of the hero's Health lost killing one face to face
(no dodging) · commons: average hits to kill the hero:

| Act | Difficulty | Common | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|
| 1 | easy | 0.2→**0.4** s · 0.3→**0.3**% · 64→**64** hits | 0.7→**1.1** s · 0.8→**1.8**% | - | - | 0.7→**1.4** s · 0.8→**1.2**% |
| 1 | normal | 0.4→**0.6** s · 0.8→**1.3**% · 32→**26** hits | 0.9→**1.6** s · 2.5→**5.2**% | - | - | 1.1→**1.9** s · 2.5→**4.3**% |
| 1 | hard | 0.5→**0.7** s · 1.7→**2.4**% · 21→**18** hits | 1.2→**2.1** s · 4.8→**10.2**% | - | - | 1.4→**2.5** s · 5.1→**8.4**% |
| 1 | nightmare | 0.6→**1.0** s · 3.5→**5.2**% · 14→**12** hits | 1.6→**2.8** s · 10.1→**18.4**% | - | - | 1.8→**3.3** s · 10.5→**18.0**% |
| 1 | nightmare+5 | 0.7→**1.1** s · 4.5→**6.7**% · 13→**11** hits | 1.9→**3.2** s · 12.8→**25.0**% | - | - | 2.0→**3.8** s · 13.6→**22.9**% |
| 1 | nightmare+10 | 0.8→**1.3** s · 5.8→**8.4**% · 12→**10** hits | 2.1→**3.7** s · 16.2→**33.6**% | - | - | 2.3→**4.4** s · 17.5→**29.3**% |
| 2 | easy | 0.2→**0.6** s · 0.1→**0.2**% · 200→**150** hits | 0.7→**2.3** s · 0.3→**1.4**% | 1.0→**4.1** s · 0.5→**3.3**% | 1.7→**6.3** s · 1.1→**7.4**% | 0.8→**2.3** s · 0.3→**0.9**% |
| 2 | normal | 0.4→**0.8** s · 0.3→**1.5**% · 100→**33** hits | 1.0→**3.3** s · 0.9→**9.2**% | 1.5→**5.9** s · 1.5→**19.0**% | 2.4→**9.1** s · 2.5→**35.2**% | 1.1→**3.3** s · 0.9→**5.9**% |
| 2 | hard | 0.5→**1.1** s · 1.0→**3.8**% · 40→**18** hits | 1.3→**4.4** s · 2.8→**19.8**% | 1.9→**7.8** s · 4.5→**42.5**% | 3.1→**11.8** s · 7.8→**75.2**% | 1.4→**4.2** s · 3.1→**14.7**% |
| 2 | nightmare | 0.6→**1.4** s · 2.4→**8.0**% · 22→**12** hits | 1.7→**5.7** s · 6.5→**42.8**% | 2.5→**10.6** s · 10.4→**89.8**% | 4.0→**15.8** s · 17.9→**150.8**% | 1.8→**5.5** s · 7.2→**31.0**% |
| 2 | nightmare+5 | 0.7→**1.6** s · 3.3→**10.8**% · 18→**10** hits | 1.9→**6.6** s · 8.9→**55.8**% | 2.9→**12.3** s · 14.2→**118.8**% | 4.7→**18.2** s · 24.2→**195.8**% | 2.1→**6.4** s · 9.9→**42.0**% |
| 2 | nightmare+10 | 0.8→**1.9** s · 4.6→**13.8**% · 15→**10** hits | 2.2→**7.7** s · 12.4→**74.5**% | 3.4→**14.1** s · 19.8→**155.5**% | 5.4→**20.9** s · 33.5→**264.8**% | 2.5→**7.3** s · 13.7→**54.0**% |
| 3 | easy | 0.4→**0.6** s · 0.1→**0.2**% · 229→**229** hits | 0.9→**3.0** s · 0.3→**1.8**% | 1.4→**5.3** s · 0.6→**4.7**% | 2.1→**7.3** s · 1.2→**9.3**% | 1.1→**2.8** s · 0.3→**0.7**% |
| 3 | normal | 0.5→**0.9** s · 0.3→**1.5**% · 108→**33** hits | 1.4→**4.3** s · 0.9→**11.9**% | 1.9→**7.7** s · 1.8→**23.4**% | 3.0→**10.8** s · 3.3→**40.8**% | 1.5→**3.9** s · 0.9→**6.7**% |
| 3 | hard | 0.7→**1.2** s · 1.1→**4.1**% · 38→**18** hits | 1.8→**5.7** s · 3.2→**27.1**% | 2.6→**10.1** s · 5.4→**56.6**% | 4.0→**14.2** s · 8.7→**91.3**% | 2.0→**5.1** s · 3.4→**17.9**% |
| 3 | nightmare | 0.9→**1.5** s · 3.1→**9.3**% · 19→**11** hits | 2.3→**7.5** s · 8.6→**57.9**% | 3.4→**13.4** s · 13.5→**116.2**% | 5.2→**19.1** s · 22.0→**191.0**% | 2.6→**6.7** s · 9.3→**40.3**% |
| 3 | nightmare+5 | 1.0→**1.8** s · 4.1→**12.1**% · 16→**10** hits | 2.6→**8.7** s · 11.5→**75.3**% | 3.8→**15.4** s · 18.4→**149.8**% | 6.0→**22.0** s · 29.3→**248.7**% | 3.0→**7.7** s · 12.4→**52.4**% |
| 3 | nightmare+10 | 1.1→**2.0** s · 5.5→**16.2**% · 14→**8** hits | 3.0→**10.0** s · 15.7→**103.1**% | 4.4→**17.8** s · 24.9→**198.9**% | 6.9→**25.3** s · 39.8→**333.8**% | 3.4→**8.9** s · 16.6→**70.3**% |
| 4 | easy | 0.5→**0.8** s · 0.1→**0.2**% · 285→**270** hits | 1.3→**4.9** s · 0.4→**2.0**% | 1.9→**8.4** s · 0.8→**5.5**% | 2.7→**10.9** s · 1.7→**10.8**% | 1.4→**3.9** s · 0.3→**1.0**% |
| 4 | normal | 0.7→**1.1** s · 0.4→**2.0**% · 123→**41** hits | 1.8→**7.0** s · 1.3→**18.4**% | 2.7→**12.1** s · 2.3→**36.7**% | 3.9→**16.1** s · 3.6→**64.2**% | 2.0→**5.5** s · 1.3→**9.5**% |
| 4 | hard | 0.9→**1.5** s · 1.7→**5.7**% · 41→**20** hits | 2.4→**9.1** s · 4.8→**44.7**% | 3.6→**15.7** s · 7.5→**88.1**% | 5.2→**21.5** s · 12.4→**147.4**% | 2.6→**7.2** s · 5.0→**27.2**% |
| 4 | nightmare | 1.1→**2.0** s · 4.8→**12.8**% · 20→**12** hits | 3.1→**11.9** s · 12.8→**97.9**% | 4.6→**20.7** s · 20.8→**192.3**% | 6.8→**29.6** s · 33.6→**315.1**% | 3.4→**9.4** s · 14.4→**61.6**% |
| 4 | nightmare+5 | 1.3→**2.3** s · 6.6→**17.5**% · 17→**10** hits | 3.6→**13.9** s · 17.8→**130.0**% | 5.3→**24.2** s · 29.2→**254.2**% | 8.0→**34.8** s · 46.5→**409.8**% | 3.9→**10.8** s · 19.8→**83.7**% |
| 4 | nightmare+10 | 1.5→**2.6** s · 9.1→**23.6**% · 14→**9** hits | 4.1→**16.2** s · 25.0→**174.2**% | 6.1→**28.8** s · 41.1→**340.4**% | 9.2→**41.0** s · 64.4→**566.5**% | 4.5→**12.4** s · 27.2→**113.3**% |

Commons' curve and ranks' ladder (new model table `monster_ladder`, Normal, medians):

| Act | Common TTK | Common Health lost | Step | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|---|
| I | 0.4 -> **0.6 s** | 0.8% -> **1.3%** | - | 0.9 -> **1.6 s** / 2.5% -> **5.2%** | - | - | 1.1 -> **1.9 s** |
| II | 0.4 -> **0.8 s** | 0.3% -> **1.5%** | x0.38 -> **x1.19** | 1.0 -> **3.3 s** / 0.9% -> **9.2%** | 1.5 -> **5.9 s** / **19%** | 2.4 -> **9.1 s** / **35%** | 1.1 -> **3.3 s** |
| III | 0.5 -> **0.9 s** | 0.3% -> **1.5%** | x1.0 -> **x1.02** | 1.4 -> **4.3 s** / 0.9% -> **11.9%** | 1.9 -> **7.7 s** / **23%** | 3.0 -> **10.8 s** / **41%** | 1.5 -> **3.9 s** |
| IV | 0.7 -> **1.2 s** | 0.4% -> **2.0%** | x1.33 -> **x1.29** | 1.8 -> **7.0 s** / 1.3% -> **18.4%** | 2.7 -> **12.1 s** / **37%** | 3.9 -> **16.0 s** / **64%** | 2.0 -> **5.5 s** |

Model flags (seed 1, all difficulties; per monster, Normal): monster TTK 24 -> **6**, Elite TTK
43 -> **16**, Epic 34 -> **7**, Legendary 34 -> **6**, Shiny 35 -> **8** (170 -> 43). New checks
"model: monster curve" and "model: rank ladder": 0 flags. Boss tables, the boss curve and the
difficulty curve: unchanged (bosses untouched).

What is left, and why it is left:
- **Act I ranks (all 10 act I Elites at 0.8-2.3 s, 7 Shinies).** The model measures them against
  the level-6 build that reaches the act I boss; the same monsters meet a level-1 hero with a tenth
  of that damage on floor 1. Raising them to 3 s would make a floor-1 Elite slime a 30-s slog for
  a fresh hero. The per-depth rank Health is the compromise (an Elite is x2.5 on floor 1, x3.7 on
  floor 5). Same for the swarm fodder (rat, bat, larva, snake at 0.3-0.4 s: one or two hits by
  design, "comes in numbers").
- **Act II-III fodder ranks** (Elite bat, skull, frost skull, thief racoon, flam: 1.2-2.7 s) and
  the **Dune Rex** ranks (Elite 11.3 s, Epic 19 s, Legendary 26 s: act IV's tank, plain 1.9 s after
  its Health 85 -> 70): edge cases of one multiplier on a spread of kinds.
- **Boss adds are commons (finding for phase 2A).** King Slime and Giant Frog call slimes, the act
  II/III/IV bosses skeletons, spirits, flams, gold racoons: they got this pass's Health and
  attack. The balance suite's duel "expected_a1 kite wins" vs King Slime now **fails**: baseline a
  win (hero min 45%, 70 taken in 8 hits); now a loss with the boss at 1-4% (128 taken in 14-15
  hits), with the slime's Health brought back to 28 (x1.08) for it; the rest is the +1 attack
  per hit at depth 3. A coin-flip fight, but a regression: phase 2A should decide (fewer or
  weaker adds in `data/skills/boss/call_*`, or a rule scaling boss-summoned adds with the boss
  depth values). Giant Frog's kite fight was already a loss in the baseline.
- **High difficulties.** Nightmare and its ascensions multiply Health x1.7-2.25 on top: an act IV
  Legendary takes 30 s on Nightmare and 41 s on Nightmare +10 (face to face it would cost 3-5x the
  hero's Health: it must be dodged, like a boss). The expected builds are the Normal ones (on
  Nightmare a player is 2-3 levels higher: economy table "XP before each act's boss"); the
  ranked share was cut instead of their Health (above). Watch it in real Nightmare runs.
- **Difficulty curve (boss threat): Easy act IV x0.12, Nightmare act IV x5.19.** Both come from the
  flat armor rule (`Combat.mitigate`): x0.6 damage against 13 Armor leaves 1-point hits on Easy;
  x1.8 against it more than triples them on Nightmare. Not fixed with difficulty numbers: phase
  2A's armor rule decides it.

**Depends on armor (phase 2A changes `Combat.mitigate`).** Every damage number above is after
today's flat armor (hero Armor 2 / 7 / 10 / 13 at acts I-IV). The new monster damage (+0.5 attack
per floor, act II +1/+2, act III +1, rank x1.15-x1.3) was kept small on purpose: under a
diminishing-returns armor the same raw numbers hit harder at act III-IV (where flat Armor now
eats 10-13 points of each hit) and softer in act I. After 2A lands, re-run `--mode=model` and
check: commons' hits to kill the hero >= 6 on Nightmare +10 (today 8-10), the "monster curve"
step (x0.9-1.6 per act), Elite/Legendary Health lost on Normal (today 5-18% / 35-64%), and the
difficulty curve (Easy act IV should rise toward x0.4, Nightmare act IV fall toward x3). If act
III-IV commons get too sharp, lower `monster_attack_per_depth` back toward 1.0 first.

**Rewards and economy (phase 2C).** XP, gold and drops per rank are unchanged, but ranked monsters
are rarer (Normal act IV 25% -> 22% of monsters, Hard and Nightmare more so) and take longer: the
souls, XP and gold per floor measured by `--mode=economy` move a little; re-measure there.

Engine (pack mode, Normal and Hard, expected builds): measured before the last touch-ups (act II
commons +20% Health, act III +1 attack, slime 34 -> 28, Dune Rex 85 -> 70), seed 1; medians:

| Act | Ranked + 2 commons, face-tank: Elite / Epic / Legendary / Shiny TTK (before -> after) | Rooms, expected build, kite: Health lost / clear | Face-tank |
|---|---|---|---|
| I Normal | 0.8 -> **1.5** / 1.8 -> **4.3** / 3.6 -> **6.0** / 0.8 -> **1.8** s | 0% -> 0% / 2.1 -> 3.6 s | 2% -> 2% |
| II Normal | 0.6 -> **2.2** / 0.1 -> **3.1** / 1.2 -> **4.2** / 0.9 -> **2.1** s | 0% -> 0% / 4.6 -> 6.8 s | 0% -> 0% |
| III Normal | 1.5 -> **5.1** / 1.8 -> **6.7** / 3.0 -> **9.7** / 2.2 -> **4.2** s | 0% -> 0% / 14.9 -> 14.7 s | 0% -> 0% |
| IV Normal | 1.8 -> **6.5** / 1.8 -> **6.0** / 3.0 -> **12.0** / 1.2 -> **5.4** s | 0% -> 0% / 9.3 -> 12.6 s | 1% -> 5% |
| III Hard | 0.2 -> **6.2** / 4.1 -> **13.4** / 4.1 -> **18.1** / 0.4 -> **6.0** s | 0% -> **10%** / 24.7 -> 23.2 s | 1% -> 14% |
| IV Hard | 0.3 -> **5.9** / 3.1 -> **10.6** / 3.6 -> **13.8** / 0.9 -> **5.9** s | 0% -> **2%** / 17.4 -> 19.3 s | 8% -> **25%** |

Ranked monsters now last a real duel on the engine too (the before column has engine noise:
0.1 s = slain in the hit that hurt it first). Mixed rooms still cost the kite bot almost nothing on
Normal (room damage is a ceiling target, <= 35%: met everywhere) and face-tanking them 0-5%: the
commons' extra damage shows on Hard (10-25%) and against ranked monsters (Normal face-tank: Epic
and Legendary rooms 2-27%). Act IV with the kite bot and the slow Greatsword: the Epic, Legendary
and Shiny rooms ran 30-49 s or to the timeout (the bot keeps range and swings rarely); face-tank
6-12 s. Watch that in play: if act IV ranks drag, lower `hp_multiplier_per_depth` first.

Guard tests: unit `_test_monster_ranks` (Elite < Epic < Legendary in Health at every depth, a
Shiny below an Epic, no rank weaker deeper, damage x1 < Elite <= Epic <= Legendary <= x1.5, a
Shiny hits like its kind; bosses scale with the boss depth values, monsters with theirs); floor
test (an Elite has the rank's Health at its depth and hits harder); balance suite: "model: monster
curve" and "model: rank ladder" (target `rank_ladder_step_min` = 1.2 in targets.tres).
Regular suites: unit,title 4734 checks, game 900, tutorial 273: 0 failed. Balance suite: the
known failures (fewer flags each), "duel: degenerate_lifesteal_a1 face-tank loses" now passes
(left in KNOWN for phase 2A to confirm), "duel: expected_a1 kite wins" newly failed before the 2A merge (it passes after it: below).

#### After merging phase 2A (percentage armor): re-measured, two damage changes reverted

2A's `Combat.mitigate` (damage x damage / (damage + armor), at least 1) already makes the
commons hit for real: on top of it, this pass's extra monster damage compounded. Model on the
merged branch with every 2B change kept (Normal, medians): a common cost 1.4 / 2.3 / 2.7 / 4.0% of
the hero's Health (acts I-IV), act II stepped x1.71 over act I (flag), an act IV Elite 28% and
Legendary 90% face to face. Measured three variants (same seed):

| Variant | Commons' Health lost (I-IV) | Steps | Act IV Elite / Legendary | Flags |
|---|---|---|---|---|
| all 2B changes | 1.4 / 2.3 / 2.7 / 4.0% | x1.71, x1.17, x1.46 | 28% / 90% | monster curve |
| without act II/III attack | 1.4 / 2.2 / 2.6 / 4.0% | x1.64, x1.15, x1.55 | 28% / 90% | monster curve |
| also `monster_attack_per_depth` 1.0 | 1.2 / 1.7 / 1.7 / 2.7% | x1.40, x0.99, x1.64 | 19% / 62% | monster curve |
| **kept:** that + act III +1 attack | **1.2 / 1.7 / 1.7 / 2.7%** | **x1.40, x1.01, x1.59** | **19% / 62%** | none |

So the final state: **`monster_attack_per_depth` back to 1.0** (still its own field, a float),
**the act II attack bumps removed**, the act III +1 kept; Health, ranks, rank damage and elite
chances as above. Final model, Normal: commons need 27 / 40 / 31 / 34 hits to kill the expected
build (Nightmare +10: 12 / 13 / 11 / 12; target >= 6), Easy stays at 0.5-0.8% a common. The
difficulty curve (boss threat) is now inside its targets everywhere (Easy x0.38-0.47, Hard
x1.76-1.92, Nightmare x2.83-3.37, +5 x3.12-3.84, +10 x4.26-5.43): 2A's armor fixed what flat armor
broke, as expected. Model flags (per monster, Normal): monster TTK 6, Elite 17, Epic 7, Legendary
6, Shiny 8 (baseline 24 / 43 / 34 / 34 / 35); "monster curve" and "rank ladder": 0.

Phase 2 baseline -> final (merged, model, every difficulty, the act's last normal floor; time to
kill · share of the hero's Health lost killing one face to face · commons: hits to kill the hero):

| Act | Difficulty | Common | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|
| 1 | easy | 0.2→**0.4** s · 0.3→**0.5**% · 64→**43** hits | 0.7→**1.1** s · 0.8→**1.7**% | - | - | 0.7→**1.4** s · 0.8→**1.7**% |
| 1 | normal | 0.4→**0.6** s · 0.8→**1.2**% · 32→**27** hits | 0.9→**1.6** s · 2.5→**4.7**% | - | - | 1.1→**1.9** s · 2.5→**4.1**% |
| 1 | hard | 0.5→**0.7** s · 1.7→**2.1**% · 21→**21** hits | 1.2→**2.1** s · 4.8→**8.4**% | - | - | 1.4→**2.5** s · 5.1→**7.3**% |
| 1 | nightmare | 0.6→**1.0** s · 3.5→**4.3**% · 14→**14** hits | 1.6→**2.8** s · 10.1→**15.8**% | - | - | 1.8→**3.3** s · 10.5→**14.9**% |
| 1 | nightmare+5 | 0.7→**1.1** s · 4.5→**5.6**% · 13→**13** hits | 1.9→**3.2** s · 12.8→**22.0**% | - | - | 2.0→**3.8** s · 13.6→**19.4**% |
| 1 | nightmare+10 | 0.8→**1.3** s · 5.8→**7.2**% · 12→**12** hits | 2.1→**3.7** s · 16.2→**27.8**% | - | - | 2.3→**4.4** s · 17.5→**24.8**% |
| 2 | easy | 0.2→**0.6** s · 0.1→**0.5**% · 200→**95** hits | 0.7→**2.3** s · 0.3→**2.7**% | 1.0→**4.1** s · 0.5→**5.8**% | 1.7→**6.3** s · 1.1→**9.5**% | 0.8→**2.3** s · 0.3→**1.8**% |
| 2 | normal | 0.4→**0.8** s · 0.3→**1.7**% · 100→**40** hits | 1.0→**3.3** s · 0.9→**7.7**% | 1.5→**5.8** s · 1.5→**18.1**% | 2.4→**9.1** s · 2.5→**28.6**% | 1.1→**3.3** s · 0.9→**6.6**% |
| 2 | hard | 0.5→**1.1** s · 1.0→**3.4**% · 40→**26** hits | 1.3→**4.3** s · 2.8→**15.6**% | 1.9→**7.6** s · 4.5→**33.1**% | 3.1→**11.8** s · 7.8→**57.5**% | 1.4→**4.2** s · 3.1→**13.3**% |
| 2 | nightmare | 0.6→**1.4** s · 2.4→**6.6**% · 22→**18** hits | 1.7→**5.7** s · 6.5→**31.7**% | 2.5→**10.4** s · 10.4→**63.0**% | 4.0→**15.6** s · 17.9→**113.5**% | 1.8→**5.5** s · 7.2→**25.5**% |
| 2 | nightmare+5 | 0.7→**1.6** s · 3.3→**8.7**% · 18→**15** hits | 1.9→**6.6** s · 8.9→**40.1**% | 2.9→**12.1** s · 14.2→**80.5**% | 4.7→**18.0** s · 24.2→**148.2**% | 2.1→**6.4** s · 9.9→**34.0**% |
| 2 | nightmare+10 | 0.8→**1.9** s · 4.6→**11.6**% · 15→**13** hits | 2.2→**7.6** s · 12.4→**53.2**% | 3.4→**14.1** s · 19.8→**105.8**% | 5.4→**20.7** s · 33.5→**190.2**% | 2.5→**7.3** s · 13.7→**45.4**% |
| 3 | easy | 0.4→**0.6** s · 0.1→**0.5**% · 229→**62** hits | 0.9→**3.0** s · 0.3→**3.5**% | 1.4→**5.3** s · 0.6→**7.5**% | 2.1→**7.3** s · 1.2→**12.6**% | 1.1→**2.8** s · 0.3→**2.2**% |
| 3 | normal | 0.5→**0.9** s · 0.3→**1.7**% · 108→**31** hits | 1.4→**4.3** s · 0.9→**11.3**% | 1.9→**7.7** s · 1.8→**21.8**% | 3.0→**10.6** s · 3.3→**37.1**% | 1.5→**3.9** s · 0.9→**7.4**% |
| 3 | hard | 0.7→**1.2** s · 1.1→**3.4**% · 38→**20** hits | 1.8→**5.7** s · 3.2→**22.1**% | 2.6→**10.0** s · 5.4→**45.4**% | 4.0→**14.1** s · 8.7→**71.2**% | 2.0→**5.1** s · 3.4→**15.0**% |
| 3 | nightmare | 0.9→**1.5** s · 3.1→**7.0**% · 19→**14** hits | 2.3→**7.5** s · 8.6→**45.0**% | 3.4→**13.2** s · 13.5→**89.1**% | 5.2→**18.8** s · 22.0→**136.7**% | 2.6→**6.7** s · 9.3→**30.6**% |
| 3 | nightmare+5 | 1.0→**1.8** s · 4.1→**9.2**% · 16→**12** hits | 2.6→**8.7** s · 11.5→**57.9**% | 3.8→**15.3** s · 18.4→**116.2**% | 6.0→**21.6** s · 29.3→**176.2**% | 3.0→**7.7** s · 12.4→**39.8**% |
| 3 | nightmare+10 | 1.1→**2.0** s · 5.5→**12.0**% · 14→**11** hits | 3.0→**10.0** s · 15.7→**76.4**% | 4.4→**17.7** s · 24.9→**146.9**% | 6.9→**25.0** s · 39.8→**233.2**% | 3.4→**8.9** s · 16.6→**52.4**% |
| 4 | easy | 0.5→**0.8** s · 0.1→**0.8**% · 285→**72** hits | 1.3→**4.9** s · 0.4→**6.0**% | 1.9→**8.4** s · 0.8→**12.5**% | 2.7→**11.0** s · 1.7→**19.4**% | 1.4→**3.9** s · 0.3→**3.9**% |
| 4 | normal | 0.7→**1.1** s · 0.4→**2.7**% · 123→**34** hits | 1.8→**7.0** s · 1.3→**18.8**% | 2.7→**12.1** s · 2.3→**38.1**% | 3.9→**15.9** s · 3.6→**62.1**% | 2.0→**5.5** s · 1.3→**13.0**% |
| 4 | hard | 0.9→**1.5** s · 1.7→**5.4**% · 41→**22** hits | 2.4→**9.1** s · 4.8→**38.2**% | 3.6→**15.6** s · 7.5→**76.3**% | 5.2→**21.1** s · 12.4→**121.9**% | 2.6→**7.2** s · 5.0→**25.7**% |
| 4 | nightmare | 1.1→**2.0** s · 4.8→**10.8**% · 20→**15** hits | 3.1→**11.8** s · 12.8→**76.1**% | 4.6→**20.4** s · 20.8→**149.3**% | 6.8→**28.7** s · 33.6→**240.0**% | 3.4→**9.4** s · 14.4→**51.9**% |
| 4 | nightmare+5 | 1.3→**2.3** s · 6.6→**14.2**% · 17→**13** hits | 3.6→**13.7** s · 17.8→**99.6**% | 5.3→**23.6** s · 29.2→**195.1**% | 8.0→**33.5** s · 46.5→**313.0**% | 3.9→**10.8** s · 19.8→**68.1**% |
| 4 | nightmare+10 | 1.5→**2.6** s · 9.1→**18.9**% · 14→**12** hits | 4.1→**15.9** s · 25.0→**131.6**% | 6.1→**27.4** s · 41.1→**261.8**% | 9.2→**39.1** s · 64.4→**408.8**% | 4.5→**12.4** s · 27.2→**90.5**% |

Engine (pack mode, merged final data, Normal and Hard, seed 1, medians), baseline -> final:

| Act | Ranked + 2 commons, face-tank: Elite / Epic / Legendary / Shiny TTK | Rooms, expected build, kite: Health lost / clear | Face-tank |
|---|---|---|---|
| I Normal | 0.8 -> **1.1** / 1.8 -> **3.2** / 3.6 -> **5.0** / 0.8 -> **1.1** s | 0% -> 0% / 2.1 -> 2.3 s | 2% -> 2% |
| II Normal | 0.6 -> **2.5** / 0.1 -> **4.0** / 1.2 -> **5.1** / 0.9 -> **2.7** s | 0% -> 0% / 4.6 -> 5.1 s | 0% -> 0% |
| III Normal | 1.5 -> **5.2** / 1.8 -> **7.4** / 3.0 -> **8.9** / 2.2 -> **4.9** s | 0% -> 0% / 14.9 -> 11.1 s | 0% -> 2% |
| IV Normal | 1.8 -> **6.0** / 1.8 -> **9.0** / 3.0 -> **12.0** / 1.2 -> **5.4** s | 0% -> 0% / 9.3 -> 18.9 s | 1% -> 8% |
| III Hard | 0.2 -> **6.3** / 4.1 -> **14.1** / 4.1 -> **16.2** / 0.4 -> **6.0** s | 0% -> 0% / 24.7 -> 13.3 s | 1% -> 14% |
| IV Hard | 0.3 -> **6.9** / 3.1 -> **9.6** / 3.6 -> **13.8** / 0.9 -> **5.7** s | 0% -> 3% / 17.4 -> 22.2 s | 8% -> 24% |

Rooms are not too deadly after the merge: the kite bot loses 0-3% a room, the face-tank bot
2-8% on Normal and 14-24% on Hard (target <= 35% with the kite bot, every room clears in <= 23 s).
Ranked rooms face-tanked cost 0-27% on Normal, up to 49% (act III Hard Legendary). Pack flags:
monster TTK 31 -> 21, Elite 23 -> 16, Epic 3 -> 3, Legendary 3 -> 1, Shiny 2 -> 2 (the engine's
"time from first hurt" is noisy: a 0.1 s value is a monster slain by the hit that first hurt it).
Act IV with the kite bot and the slow Greatsword still drags on ranked rooms (22-38 s or the
timeout): watch it in play; `hp_multiplier_per_depth` is the knob.

After the merge, the balance suite's "duel: expected_a1 kite wins" **passes** again (King Slime:
kite win in 56 s, hero min 76%, with 2A's bot and armor); Giant Frog's kite fight is identical to
2A's own measure (loss, boss 22%), so the adds' new Health doesn't decide it. One new balance-suite
failure outside this pass's scope: "marginal: too weak: perk vampirism x3 (act 2) 0.02x median"
(phase 2C's area; vampirism heals on kills, and the lab's rooms now take longer to clear).
Regular suites on the merged branch: unit,title 4756 checks, game 901, tutorial 273: 0 failed.

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
