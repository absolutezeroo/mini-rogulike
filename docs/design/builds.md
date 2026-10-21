# Skills, perks and builds

## Skills

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
| Paladin | Templar Sword | Smite (damage + heal), Holy Shield (Armor + heal; both heal half during a boss fight) |

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

Everything on a card is spelled out for someone who never played a roguelike: "New perk (up to
level 3)" or "Level 1 > 2 (max 3)", what it does, and a box per **family** with its name, little
squares for the perks of it you hold (this one included), how many more it takes and what its
bonus does; the card that would complete a family glows and says "AWAKENS!". One line under the
title says what families are. In the bag, **Perks** opens "Your perks" (`BuildWindow`): every
family with its progress and bonus, and every perk taken with its level and effect.

A `PerkDef` (in `data/perks/`) is stat bonuses + a list of `Passive`s, both multiplied by its level:

| Passive | Hook | Used by |
|---|---|---|
| `HealOnKillPassive` | on kill (not summons) | Vampirism |
| `LifestealPassive` | on hit (direct hits only) | the Leech rune, Vampiric elites |
| `HealOnSkillPassive` | on skill | Devotion |
| `ThornsPassive` | on damaged (can leave a status) | Burning Thorns |
| `RetaliatePassive` | on damaged (cooldown, can leave a status) | Frost Armor: getting hit throws enemies back and chills them |
| `MomentumPassive` | on dash, before a hit | Swiftness: hits right after a roll deal more |
| `OpenerPassive` | before a hit | Precision: the first blow on an unhurt enemy is a crit |
| `FloorWardPassive` | on a new floor | Guardian Ring: every floor starts with a ward |
| `BurnOnHitPassive` | on hit | Ignite (burn status) |
| `CritShockwavePassive` | on hit (crits, can leave a status) | Thunderclap, the Shatter rune |
| `DashShockwavePassive` | on dash (can leave a status) | Shock Roll, Cold Snap, Blazing Roll |
| `SlowOnHitPassive` | on hit | Frostbite |
| `StatusDamagePassive` | before a hit (burning/poisoned/slowed target) | Kindling, the Frost family |
| `KillBurstPassive` | on kill (shards out of the body, a blast) | Ice Shards, the Inferno family |
| `SkillEchoPassive` | on skill (cooldown back to 0) | Echo |
| `EffectsOnSkillPassive` | on skill (any `Effect`) | the Arcane family |
| `ChainLightningPassive` | every few hits | the Storm family |
| `BloodlustPassive` | before a hit (wounded), on kill | Bloodrage, the Blood family, the Fury rune |
| `LootOnKillPassive` | on kill | Fortune |
| `ExecutePassive` | before a hit | Executioner |
| `ExtraProjectilesPassive` | every volley | Multishot |
| `CheatDeathPassive` | before dying | Phoenix Feather |

Damage caused by a passive (burn, thorns, shockwaves, chains, Ice Shards' shards, the Arcane
ring of bolts: `ProjectileSpec.secondary`) is a *secondary* hit: it never triggers other on-hit
perks (no lifesteal, no chain counter), and passive shots get no extra projectiles, so effects
can't chain forever.

**Healing from hits, kills and skills** (`SustainRules`, `data/dungeon/sustain.tres`, set in
`DungeonConfig` > Sustain; `SustainMeter`, `Actor.sustain_heal()`): Leech, Vampirism, Devotion,
the Blood family, the Fury rune and Vampiric gear all draw from one budget. It holds 20% of the
hero's max health (a pack slain at once still heals well) and refills 4% of it per second. While a
boss fight is on it holds a quarter of that (5%) and refills a tenth as fast (0.4% a second,
`boss_fight_burst`, `boss_fight_rate`): healing there forgives a mistake, it can't out-heal a boss. Healing is paid in whole
points, the fractions adding up (10% of a 7-damage hit is 0.7, not 1). Burn and poison ticks and
secondary hits heal nothing, and summoned monsters and a boss's adds feed no "on kill" heal (nor
Fortune's loot). Potions, springs, healing spells and level ups are not limited. Perks are stored per actor in a `PerkSet`,
so monsters could use them too (elites, later).

### Families (synergies)

Most perks and relics belong to a **family** (`SynergyDef`, `data/perks/synergies/`, listed in
`content_db.tres` > Synergies; a perk names its own in `PerkDef.synergies`). Holding **3 different
perks** of a family wakes its bonus for the rest of the run: a change in how you play, not a number.

| Family | Perks and relics | Awake |
|---|---|---|
| **Inferno** | Ignite, Kindling, Blazing Roll, Burning Thorns, Phoenix Feather | enemies that die burning explode and set everything around on fire |
| **Frost** | Frostbite, Cold Snap, Ice Shards, Frost Armor, Guardian Ring | slowed enemies take +50%, crits freeze them |
| **Blood** | Vampirism, Vitality, Bloodrage, Devotion, Executioner | below half Health +40% damage, every kill heals 4% max Health |
| **Storm** | Frenzy, Thunderclap, Shock Roll, Swiftness | attacks 15% faster; every 3rd hit, lightning jumps to 3 enemies |
| **Arcane** | Arcane Focus, Arcane Power, Devotion, Echo, Sage's Codex, Multishot | every skill also fires a ring of 8 bolts |

A perk sits in a family only if its effect plainly belongs to it (Inferno: fire and burning;
Frost: cold, slows, freezing; Blood: health, life drain, low-health power; Storm: lightning,
chains, speed of the strike; Arcane: skills, spells, cooldowns). Plain-number perks (Strength,
Precision, Fortune, War Banner) belong to none. Why: [balance.md](../balance.md) and the [balance log](../balance-log.md).

### Choosing: reroll, banish, families first

Under the cards, **Reroll** deals three other cards and **Banish** (then tap a card) removes that
perk for the rest of the run, another card taking its place. A run starts with
`base_rerolls` / `base_banishes` (1 each, `DungeonConfig` > Perk choices), plus the shrine's Loaded
Dice and Exile; every boss slain gives `rerolls_per_boss` more. Offers lean toward the families you
have started: a perk weighs `1 + family_bias` times more for each started, not yet awake family
it belongs to (`ContentDB.pick_perks`).

The perk cards show each family's count ("Frost 1/3") and shine "Wakes Inferno!" on the card that
would complete one. An awake family gets a banner and a framed icon at the head of the HUD's perk row.
