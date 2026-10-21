# Balance log

Dated entries, newest first: what was measured, what changed and why, before/after numbers, open
questions. How to measure: [balance.md](balance.md).

## 2026-10-21 - Second lives go through the trial of the Threshold

**Design (from the player's request):** a revive (Phoenix Feather, Death Denied) no longer heals
in place: the killing blow sends the hero to a limbo where he must slay spectres before a
countdown ends; won, he comes back where he fell with the feather's old heal (half Health, a
quarter in a boss fight, unchanged) and its blast; lost, he dies. See design/builds.md.

**Numbers** (`data/threshold/threshold.tres`): 8 spectres in 25 s in act I, +2 spectres and +6 s
per act (10 in 31 s, 12 in 37 s, 14 in 43 s); 4 up at once, the next 0.7 s after a gap; spectres
at 70% of the same monster's Health (damage unchanged); the hero inside at 60% of his max Health;
1 s of grace when he is back.

**Measured** (a probe bot, not the balance tools: walks at the nearest spectre, holds attack,
rolls and casts every half second, drinks under a third of Health, no dodging; the level of the
depth, a floor-level Katana, Chain Mail and Iron Helm, no perks; 4 trials per depth):

| Depth (act) | Won | Seconds used (of the limit) | Lost by |
|---|---|---|---|
| 1, 3 (I) | 8/8 | 6-17 of 25 | - |
| 4, 6 (II) | 8/8 | 11-18 of 31 | - |
| 7, 9 (III) | 6/8 | 18-30 of 37 | death (9-11 of 12 slain) |
| 10, 12 (IV) | 5/8 | 27-39 of 43 | death (12-13 of 14 slain) |

A first draft (6 in 30 s, +2 and +4 s per act) was won in 6-9 s in act I: no pressure at all.
The bot only dies to damage, never to the clock: a hero with perks who dodges should win most
trials in acts I-II and have to fight for them in III-IV, which is the point (a second life,
not a free one). The balance tools' arena has no Threshold, so a revive still heals in place
there and the measured revive value (+100% / +50%) is unchanged; it is now an upper bound.

## 2026-10-21 - Secret rooms and the hidden floor's boss (new content, not yet measured in the arena)

**Secret rooms** (`dungeon_config.tres` > Secret rooms): 50% a normal floor, one room (two on
floors of 20+ rooms). The generator finds a place on 81% of Pilgrim floors, 93% on Keeper, 97% on
Martyr and Nightmare (300 seeds each, chance forced to 1), so about 40-48% of floors hide one, a
bit more on the big ones. Rewards by weight: Hidden Coffer 30 (2-3 items at quality 3.5, never
trapped: between a chest's 1.5 and the ambush's Big Chest 3.0, for a room the player had to find),
Forgotten Shrine 20, Buried Rune 20, Hoarder's Cache 20 (30-50 gold +6 a floor, after the floor's
gold rules), Sealed Draughts 15 (two rare consumables). Expected extra per floor is small (about
half a chest); no other number moved.

**The Nameless Effigy** (the hidden floor's boss, after Act II's boss, at depth 6): base 1500
Health, 6 Armor, 85 speed, 5% crit, the Ember Ronin's blade (12) and dash, the Mother of Tears'
wailing ring, the skeletons' call from two thirds, fierce versions at one third (wind-up x0.85 /
x0.7, cooldowns x0.85 / x0.7, +2 / +3 Attack, like the other bosses). Scaled by
`boss_hp_scale_per_depth` (0.33) at its floor, on Keeper:

| Boss | Floor | Health | Armor | Model TTK, expected build of its act |
|---|---|---|---|---|
| Azure Wyrm / Mother of Tears / Gorr | 6 | 2650 / 2783 / 3048 | 5 | 36.1 / 37.8 / 41.2 s (expected_a2, 78.6 DPS) |
| **The Nameless Effigy** | 6 | **3975** | 6 | about 52 s (by hand: 3975 / ~77 DPS after its armor) |
| Jade Wyrm / Crimson Tengu / Ember Ronin | 9 | 5278 / 5460 / 5642 | 5 | 37.8 / 39.0 / 40.2 s (expected_a3, 149 DPS) |

Its Health sits between the two acts' bosses (x1.3 Gorr's, x0.73 the Tengu's); against the hero of
floor 6 it is the longest boss fight so far (about 52 s against 36-41 s), on purpose: the floor is
optional, found by a secret, and pays a relic choice, a Big Chest and 60 souls (x the difficulty)
besides the usual boss souls. Its damage is the Ember Ronin's kit at depth 6 instead of 9 (Attack
+5 instead of +8). A unit check keeps its Health between the bosses around it.

**Open:** the balance model only measures the acts' bosses (it lists `nameless_effigy` as
unlisted content); the arena and the model should take the hidden boss at its floor with the act II
expected build (game-balancer pass), and the hidden floor's monsters (Act II's mix plus Cyclops,
3-5 per room in 3 rooms) at depth 6.

## 2026-10-20 - Item level: gear as strong as the floor it came from

**Design (from the player's request):** a floor-1 weapon must be worse than a floor-2 one, and
gear must not grow on its own: to get stronger, loot. Every weapon and armor now carries an item
level, the floor it was found or bought on (`EquipmentDef.item_level`, `ItemLevelRules`,
`data/items/item_levels.tres`). Rarity and affixes come on top.

- **Weapons:** +2 damage per second per level above 1, turned into damage per hit by the weapon's
  speed (`weapon_dps_per_level x cooldown`, divided by the shot share for ranged weapons). The same
  gain for every weapon, so the weapon band measured in phase 2C holds (it narrows toward 1).
- **Armor:** +1.5 Health per level on a body armor, +1 on a helm.
- **Compensation:** monsters and bosses grow at the same pace: `monster_hp_scale_per_depth`
  0.22 -> 0.32, `boss_hp_scale_per_depth` 0.22 -> 0.33. The act IV bosses lost more than the
  rest (the slow Greatsword gains most per hit, and the hero has a little more Health): Gilded
  Hoarder 1750 -> 1925 Health, Sun Wraith 1650 -> 1820, both Attack 2 -> 4.
- **Tools:** `BalanceBuildDef.item_level` (0 = the floor before its act's boss, the default), so
  every build carries gear of its depth.

**Measured (model, seed 1, Normal), phase 2C final -> item level:**

| | Before | Item level, no compensation | Final |
|---|---|---|---|
| Expected build DPS, acts I-IV | 49.5 / 66.3 / 119 / 134 | 53.3 / 78.6 / 149 / 191 | 53.3 / 78.6 / 149 / 191 |
| Boss TTK, act I-IV main boss | 27.1 / 38.8 / 37.2 / 47.2 s | - | 28.9 / 41.2 / 39.0 / 49.1 s |
| Boss threat (face-tank cost), acts I-IV | 170 / 195 / 234 / 210% | 157 / 159 / 176 / 138% | 178 / 197 / 227 / 219% |
| Act step, act IV vs III | x0.90 (target edge) | x0.79 | x0.96 |
| Commons, acts I-IV: time to kill | 0.6 / 0.8 / 1.0 / 1.2 s | 0.5 / 0.7 / 0.8 / 0.8 s | 0.6 / 0.9 / 1.0 / 1.1 s |
| Model flags | 58 | 73 | 51 |

So at the expected gear the game plays as tuned in phase 2, while a hero who keeps floor-1 gear
falls behind: at depth 11 a level-11 common Katana hits for 5 + 8 = 13, a level-1 one for 5.

**Full matrix after everything (phase 2A + 2B + 2C + item level, `--mode=all`, seed 1, 52 min),
vs the phase 2 baseline:** 677 flags (136 errors) -> 296 (28 errors). Face-tank wins in the
arena 29 -> 3, heal-share errors 107 -> 25, weapon flags (model) 35 -> 0, model monster/rank
flags 170 -> 38. The 3 face-tank wins were degenerate stacks living on two Phoenix Feathers
(shrine + relic), each bringing back half Health in a boss fight.

**Phoenix Feather in a boss fight:** back to a quarter of max Health instead of half
(`CheatDeathPassive.boss_fight_heal_ratio`, 0.25 on the feather; texts updated). Arena re-run on
the three builds (Normal and Hard): errors 19 -> 5. Left: `degenerate_max_health_a4` (411 Health,
29 Armor, Leech, two feathers) still wins face to face against the Sun Wraith at 0% health and
loses to the Gilded Hoarder with the boss at 5%; 4 heal-share errors just over 50% (51-56%) on
kite fights of the same degenerate builds.

**Still open:** the expected build's heal share on kite fights (26-59% vs a 25% target) comes from
the Leech rune within the boss-fight cap (0.4%/s): kite fights take little damage, so the share
of a small number reads high. The target may want to apply to face-tank fights only.

## 2026-10-20 - Phase 2C: perks, runes, affixes, weapons, economy

Merged with phases 2A and 2B before the final measures (the tables below say which). Domain:
perks, relics and the five families, runes, item affixes, weapons, shrine upgrades, shop
prices, gold. Not touched (other balancers): monsters, bosses, ranks, elites, difficulties,
the armor formula, the sustain rules. Measured on seed 1, Normal (model on Normal and Hard),
against the phase 2 baseline; each change re-measured with the same seed: `--mode=model`,
`--mode=compound`, `--mode=economy --difficulty=normal,nightmare`, `--mode=marginal --acts=2,3`.

### Rules fixed (code, with game tests in combat_tests.gd)

| Rule | Before | After | Why |
|---|---|---|---|
| Crit shockwaves (Thunderclap, Shatter rune) | the wave caught the enemy struck too (a second hit on every crit, itself able to crit) | the wave hurts the enemies *around* the target, never the one struck (`CritShockwavePassive.hits_target`, off) | crit chance x crit damage x the wave multiplied on a single boss: the crit build (Rapier, 82% crit, 3 Shatter runes) did 6.3x the expected build's damage and face-tanked act II bosses in 7-10 s. The descriptions already said "around" |
| Echoes (Echo perk, Echo runes, of Echoes) | every source rolled on every cast, echoes chained (68% with all of them: a skill cast ~3x per cooldown) | an echo can't echo: the cast an echo made ready rolls nothing; a skill is used at most twice per cooldown | bounded at x2 whatever the stack; each source still rolls on its own |
| Extra projectiles (Multishot, Prism runes) | each added a full shot, no limit (Multishot 2 + 2 Prism: 5 full shots, x5.2 on the Spark Wand at close range) | 2 extra projectiles at most from every source together, and the volley shares its damage: each extra shot adds 65% of a shot | a Prism rune was a free Multishot level; stacking them made every ranged weapon a shotgun |
| Skill recharge cap | 60% | 50% (`SkillSet.MAX_COOLDOWN_REDUCTION`) | with the echo bound, the cap was what left the skills build at 2.9x; only cooldown-stacking builds reach it |

The model (`balance_model.gd`) follows the three rules (the wave off the target, uses per
cooldown = 1 + the chance an echo fires, the cap and the damage share of extra projectiles).

### Data changed

| What | Before | After | Why |
|---|---|---|---|
| Rapier | 3 damage, 0.19 s | 2 damage, 0.31 s (15% crit kept) | 1.6-2.2x the median weapon: speed multiplies every flat Damage bonus |
| Sai | 0.22 s | 0.34 s | 1.4-2.0x the median |
| Ninjaku | 0.30 s | 0.34 s | 1.4x in acts III-IV |
| Pickaxe | 8 damage | 7 | 1.3x in acts I-II (it ignores armor already) |
| Shuriken | 2 damage | 8 (0.45 a star kept: a fan never hits 3x as hard) | 0.33x in act I: three stars of 4 damage did nothing against armor |
| Book | 0.6 s, 0.5 a shot | 0.55 s, 0.6 a shot | 0.6x |
| Frost Staff (stick) | 8 damage, 0.95 a shot | 10, 1.05 | 0.75x everywhere |
| Bow | 0.85 a shot | 0.9 | Epic bow at 0.75x in act I |
| Storm family | every 4th hit, chain to 3 | +15% attack speed, and every 3rd hit chains to 3 | +0-5% marginal value (chains do nothing on a boss); speed of the strike is Storm's theme |
| Arcane family | ring of 8 bolts at 0.5x power | 0.4x | Arcane 1.6x the expected build's DPS, top family pick in acts III-IV |
| Arcane Power | +15% skill damage per level | +12% | the skills build (2.9x after the echo rule) |
| Ignite | 2 per level a tick | 3 | -6% to +3% from act II: flat ticks against armor |
| Bloodrage | +15% per level below half Health | +20% | 4-12% |
| Blazing Roll | 0.4x power | 0.7x | 0-9% |
| Executioner | +60% per level | +75% | 8-18% (0.3x-0.9x the relic median) |
| Guardian Ring | +3 Armor | +2 (25 Health and the ward kept) | 2-13x the relic median, mostly from flat Armor |
| Fortified (affix) | +4 Armor | +3 | +301% in act III (21x the median): as much Armor as a Plate Armor from one affix |
| Ember rune | 35% chance, 2 a tick | 50%, 3 | -6% to +5% |
| Spark rune | every 4th hit, 0.5x | every 3rd hit, 0.6x | -3% to +5% |
| Burning (affix) | 2 a tick | 3 | -2% to +10% |
| Shocking (affix) | every 5th hit, 0.4x | every 4th hit, 0.5x | -5% to +6% |
| of Echoes | 10% | 12% | the echo rule makes stacking safe |
| Vampirism | 2 Health a kill per level | 3 | 0.15x the median in act II once 2A's boss-fight budget stopped paying it: buffed where it works, in packs (boss adds feed nothing) |
| Holy Light, Holy Shield, Smite (`HealEffect.boss_fight_ratio`, new) | full heal everywhere; Holy Light 35%, Holy Shield 10% | half during a boss fight; Holy Light 30%, Holy Shield 8% | the Templar Sword's spells (75-300 Health a fight) carried the face-tank wins of the act IV degenerate builds (phase 2A); out of boss fights they still forgive mistakes. Descriptions now say Health and Armor (were HP, DEF) |
| Gold | 45% drop chance, +0.6 a kill per floor, boss x15, crates +0.5 per floor | 30%, +0 per floor, boss x10, crates +0.25 | gold grew x6-x10 from floor 1 to 10 while prices grew x1.7 |
| Merchant | prices x1, +8% per floor, sells back 35% | x1.5, +20% per floor, sells back 25% (about the same gold back) | a visit's gold bought 4-23 average items |
| Shrine | 3150 souls in all | 4505 (stat levels' growth, Second Chance 400 -> 700, unlocks +20) | ~13 runs on Normal to buy it all (target 15-60) |
| Target: weapon DPS vs the median | 0.6x-1.6x | 0.75x-1.4x | every weapon fits the tighter band now; the old one allowed a 2.7x spread |

Not changed, on purpose:
- **Armor picks** (Frost Armor +252%, Sturdy, Toughness +119% in act III) came from the flat
  armor formula, which phase 2A replaced: only the outliers that were armor *on top of*
  something else moved (Fortified, Guardian Ring). Re-measured after the merge: Frost Armor
  +16-18%, Toughness +12-13%, Fortified +12-13% (tables below): no more outliers.
- **Leech rune** (+85% in act II = 8x the median) and Devotion: their whole value was the
  sustain budget, which phase 2A cut in boss fights (Leech now -1% / +3%).
- **Blood family's DPS** (1.06x the expected build): its power is sustain and low-health damage,
  which the DPS ratio can't see; as a marginal value it is the top family (act II 3.8x).
- **Slows, thorns, control** (Frostbite, Cold Snap, Rime, Frozen, of Thorns, Frost family) read
  +0% on dummies (Limits): left alone.

### Before / after

Weapons (model, after merging 2A; Common weapon on each act's expected hero, DPS vs the act boss
/ median weapon; every rarity now within 0.75-1.4x, Normal and Hard):

| Weapon | Before (act I / II / III / IV) | After |
|---|---|---|
| axe | 1.00x / 0.98x / 0.93x / 0.87x | 0.98x / 0.95x / 0.86x / 0.82x |
| big_sword | 1.04x / 1.02x / 0.93x / 0.88x | 1.02x / 0.98x / 0.87x / 0.82x |
| book | 0.59x / 0.60x / 0.83x / 0.81x | 0.89x / 0.99x / 0.99x / 1.00x |
| bow | 0.80x / 0.85x / 1.00x / 1.00x | 0.89x / 0.94x / 1.01x / 1.00x |
| hammer | 1.08x / 1.04x / 0.92x / 0.86x | 1.05x / 1.01x / 0.86x / 0.79x |
| katana | 1.00x / 1.04x / 1.18x / 1.16x | 1.02x / 1.05x / 1.12x / 1.11x |
| lance | 1.07x / 1.08x / 1.12x / 1.08x | 1.07x / 1.07x / 1.05x / 1.02x |
| magic_wand | 0.80x / 0.86x / 1.00x / 1.01x | 0.84x / 0.90x / 0.96x / 0.95x |
| ninjaku | 1.09x / 1.20x / 1.40x / 1.41x | 1.04x / 1.11x / 1.21x / 1.21x |
| pickaxe | 1.29x / 1.28x / 1.22x / 1.16x | 1.20x / 1.18x / 1.09x / 1.04x |
| rapier | 1.62x / 1.79x / 2.23x / 2.24x | 0.95x / 1.05x / 1.22x / 1.26x |
| sai | 1.44x / 1.58x / 1.97x / 1.97x | 1.05x / 1.13x / 1.27x / 1.28x |
| shuriken | 0.33x / 0.35x / 0.80x / 0.85x | 1.08x / 1.13x / 1.15x / 1.14x |
| stick | 0.76x / 0.75x / 0.77x / 0.74x | 0.94x / 0.94x / 0.85x / 0.81x |
| templar_sword | 0.92x / 0.93x / 0.99x / 0.96x | 0.93x / 0.92x / 0.93x / 0.91x |
| whip | 0.84x / 0.89x / 1.02x / 1.00x | 0.87x / 0.89x / 0.96x / 0.96x |

Degenerate and family builds (model, DPS vs the act's expected build on its boss, Normal):

| Build | Before | After |
|---|---|---|
| degenerate_crit_a2 (Rapier, 3 Shatter) | 6.28x | 1.67x |
| degenerate_skills_a3 (3 Echo runes, Echo, Codex) | 4.77x | 2.50x |
| degenerate_attack_speed_a1 (Sai) | 2.25x | 1.55x |
| degenerate_burn_a3 | 1.43x | 1.60x |
| family_arcane_a3 | 1.60x | 1.28x |
| family_frost_a3 | 1.38x | 1.39x |
| family_inferno_a3 | 1.25x | 1.35x |
| family_storm_a3 | 1.11x | 1.08x |
| family_blood_a3 | 0.98x | 1.06x |

(After merging phase 2A's armor formula. expected_a3 itself lost its Thunderclap hits on the
boss: 124 -> 119 DPS.)

Compound (engine, before merging 2A; dummy DPS vs the plain weapon / the expected build):

| Stack | Before | After |
|---|---|---|
| Spark Wand + Multishot 2 + 2 Prism, 64 px | x5.21 | x1.97 |
| Spark Wand + Multishot 2, 64 px | x3.10 | x1.97 |
| Bow + Multishot 2 + 2 Prism, 64 px | x3.78 | x1.48 |
| Frost Staff + Multishot 2 + 2 Prism, 64 px | x3.59 | x1.68 |
| A Prism rune on the Spark Wand | x1.78 | x1.61 |
| All echoes (act II) | x2.29 | x2.17 |
| Attack speed x crit x damage (act II) | x2.27 | x2.32 |
| Burns all together (act II) | x2.04 | x1.98 |

Economy (engine, seed 1, after merging 2A and 2B (rarer, tougher elites); items an average
merchant visit's gold buys, target 0.8-3):

| | Before | After |
|---|---|---|
| Normal, depths 1-2 | 4.7 / 4.4 | 2.4 / 1.8 |
| Normal, depths 4-5 | 8.4 / 11.5 | 2.6 / 3.2 |
| Normal, depths 7-8 | 22.7 / 14.5 | 3.3 / 2.1 |
| Normal, depths 10-11 | 19.0 / 17.4 | 2.5 / 1.8 |
| Easy, depths 1-11 | 2.5-10 | 1.1-2.2 |
| Hard, depths 1-11 | 5.9-35.5 | 2.2-5.2 |
| Nightmare, depths 1-11 | 11-44 | 4.0-5.4 |
| First reroll / a floor's gold (Normal) | 2-11% | 8-15% |
| Rune removal / a floor's gold (Normal) | 6-28% | 17-36% |
| Shrine, runs to buy it all: Normal dying at act II / III | 16.3 / 9.3 | 23.3 / 13.2 |
| Shrine, runs: Nightmare dying at act II / III | 3.4 / 2.4 | 4.9 / 3.4 |
| First run (dies at the act I boss, 61 souls) | buys a level | buys a level (30-40) |

Hard and Nightmare stay above 3 and their souls fill the shrine in 3-10 runs: the difficulties'
gold and soul multipliers belong to the difficulties (other balancer); proposal: Hard gold x0.7,
Nightmare x0.6 of today's. Normal depths 5 and 7 are just over 3 (3.2, 3.3).

Marginal values (engine, acts II and III, Normal, after merging 2A and 2B; value at max level,
x = vs the category's median). The medians fell a lot (2A's armor and boss-fight budget took
away most of the defensive and healing values; 2B's tougher monsters), so read the values, not
only the ratios. Picks over 2x / under 0.5x their median: act II 11 / 35 -> 11 / 36, act III
11 / 23 -> 8 / 26; most of the "under" are the blind spot (slows, thorns, kill heals, rolls: +0%
on dummies).

| Pick | Act II before | Act II after | Act III before | Act III after |
|---|---|---|---|---|
| Frost Armor x4 | +51% (1.4x) | +18% (1.7x) | +252% (12.3x) | +16% (0.9x) |
| Burning Thorns x3 | +38% (1.1x) | +13% (1.2x) | +188% (9.2x) | +12% (0.7x) |
| Thunderclap x3 | +84% (2.3x) | +3% (0.3x) | +71% (3.5x) | +24% (1.4x) |
| Vitality x5 | +50% (1.4x) | +45% (4.3x) | +87% (4.2x) | +53% (3.1x) |
| Frenzy x4 | +22% (0.6x) | +30% (2.8x) | +29% (1.4x) | +30% (1.7x) |
| Ignite x3 | -6% | +7% (0.7x) | +3% (0.1x) | +8% (0.5x) |
| Bloodrage x3 | +9% (0.3x) | +9% (0.8x) | +6% (0.3x) | +6% (0.3x) |
| Echo x3 | +24% (0.7x) | +3% (0.3x) | +30% (1.5x) | +7% (0.4x) |
| Devotion x3 | +72% (2.0x) | +2% (0.2x) | +4% (0.2x) | -2% |
| Vampirism x3 | +19% (0.5x) | +1% (0.1x) | +3% (0.1x) | -12% |
| Guardian Ring | +63% (1.9x) | +41% (2.0x) | +114% (5.7x) | +31% (1.3x) |
| Phoenix Feather | +100% (3.0x) | +100% (4.8x) | +100% (5.0x) | +100% (4.3x) |
| Executioner x2 | +11% (0.3x) | +11% (0.6x) | +18% (0.9x) | +16% (0.7x) |
| Storm family | -3% | +7% (1.5x) | +5% (0.7x) | +17% (1.6x) |
| Arcane family | +6% (1.0x) | +2% (0.5x) | +17% (2.1x) | +8% (0.8x) |
| Blood family (awake) | +24% (3.8x) | +15% (3.4x) | +0% | +12% (1.1x) |
| Leech rune | +85% (8.3x) | -1% | +10% (1.2x) | +3% (0.4x) |
| Fury rune | +23% (2.2x) | +5% (1.5x) | +19% (2.4x) | +9% (1.0x) |
| Spark rune | -3% | +0% | -1% | +9% (1.1x) |
| Ember rune | -6% | +0% | +2% (0.3x) | -7% |
| Echo rune | +1% (0.1x) | +0% | +6% (0.7x) | +10% (1.1x) |
| Fortified | +58% (16.8x) | +13% (1.6x) | +301% (21.3x) | +12% (2.3x) |
| Sturdy | +22% (6.5x) | +8% (1.0x) | +80% (5.6x) | +8% (1.5x) |
| Brutal | +30% (8.6x) | +19% (2.4x) | +23% (1.6x) | +12% (2.4x) |
| of Echoes | +1% (0.4x) | +0% | +6% (0.4x) | +10% (2.0x) |
| Shrine Toughness x3 | +34% (1.0x) | +13% (0.6x) | +119% (3.2x) | +12% (0.7x) |
| Shrine Might x5 | +39% (1.2x) | +21% (1.0x) | +21% (0.6x) | +21% (1.3x) |

- Phoenix Feather and Second Chance read +100% / +50% by construction (a revive doubles the time
  to die); Vitality is the remaining stat outlier on paper (+45-53%): health is worth more now
  that armor is weaker. Watch it, no change yet (one more measure after the monsters settle).
- Echo, Devotion, Leech, Vampirism fell with 2A's boss-fight budget and the echo rule; Leech is
  where it should be for a rune that the budget now limits. Brutal (+4 Damage on a weapon) is the
  top affix at 2.4x: flat damage on a single affix; next pass.

### Guards

- Game tests (`combat_tests.gd`): Multishot 2 + two Prism runes fire 3 shots sharing the damage;
  a Thunderclap crit doesn't hurt the enemy struck but hurts those around; a 100% echo gives one
  free cast, not a loop; the three healing spells heal in full outside a boss fight and carry a
  boss-fight share of at most half.
- Balance suite: `model: weapon DPS`, `model: degenerate DPS` and `economy: shop` (quick, two
  Normal floors) pass now (removed from KNOWN); new `family: <id> DPS` checks (each family
  1.0-1.5x the expected act III build: pass). `marginal: too weak` (Vampirism x3 in act II,
  0.05x) added to KNOWN as a measuring blind spot: kills heal nothing in a boss fight since 2A
  and the dummy rooms don't hurt, so a kill heal shows nothing in the lab; its value is pack
  sustain, buffed to 3 a kill. Suite after the merges: 73 checks, 9 failures, all KNOWN but
  `model: act curve` (act IV vs act III x0.90, at the edge of x0.9-1.6: the expected act III
  build lost its Thunderclap hits on the boss, so act III got a little longer).

### Open

- `model: act curve` act IV vs act III at x0.90 (edge): bosses' side.
- Weapon arena (kite bot, Common weapons) not re-run: it depends on the bosses and the kite bot
  being reworked in parallel; fast melee weapons lost 9 of 10 bosses mostly by taking hits in
  melee, not by damage. Re-run `--mode=arena` after merging.
- Armor picks and Leech after the armor formula and sustain changes (see above).
- Normal depths 5 and 7 a little over 3 items per visit; Nightmare's gold.
- Encounters: the Grinning Spirit's gold choices read +0% (gold isn't valued by the lab).

## 2026-10-20 - Phase 2B: common monsters, ranks, elite affixes, difficulties, depth scaling

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

### After merging phase 2A (percentage armor): re-measured, two damage changes reverted

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

## 2026-10-20 - Phase 2A: bosses, sustain, armor, the kite bot

Measured with the arena (`--mode=arena --plain --no-weapons`, seed 1, Normal and Hard, every
boss x the builds of its act x both bots) and the model, against the phase 2 baseline above.
The other two phase 2 passes (B: monsters, ranks, elites, difficulties; C: perks, runes,
affixes, weapons, shrine, economy) ran in parallel: their data is not in these numbers.

### What was wrong (root causes)

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

### What changed and why

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

### Results

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

### For the other passes

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

### Open

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

## 2026-10-20 - Phase 2 baseline measured (tools only, no game data changed)

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

## 2026-10-20 - Phase 1: rules and themes (no simulator yet)

Everything here was done by reading the code and the data; nothing was measured on the arena yet
(tools/balance is being built). Phase 2 measures and tunes the numbers below.

### Sustain rules changed (code, unit and game tests)

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

### Families: what moved and why

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

### Static sanity pass

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

### Open questions for phase 2 (to measure with the arena)

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
