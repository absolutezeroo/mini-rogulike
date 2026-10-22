# Acts, monsters and bosses

## Acts and their monsters

A run is **4 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its biomes, its own monsters and a boss on its last floor. Beating the last boss **wins the run**;
you can then keep going in endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. The Well's Maw | 1-3 | Gnawer, Gloom Bat, Slime, Blood Spider, Deathcap, Viper, Acid Larva, Burrower, Giant Slime, Shell Guard, Thief Racoon | Bloated King |
| II. Ossuary of Kagari | 4-6 | Skeleton, Hexer, Lost Soul, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull, Thief Racoon, Brood Mother | Gorr the One-Eyed |
| III. The Pyre Temple | 7-9 | Fire Shaman, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus, Bomber, Brood Mother, Shell Guard | Crimson Tengu |
| IV. Kingdom of Dust | 10-12 | Dune Behemoth, Gold Racoon, Crimson Viper, Ash Lizard, Bone Lizard, Stone Mole, Bomber | Gilded Hoarder |

Monsters grow with depth (`DungeonConfig` > Difficulty: +32% Health and +1 attack a floor), and
an act can add its own threat on top, on every difficulty (`ActDef.monster_hp`,
`monster_damage`; not its bosses, which are tuned one by one): **Act II's monsters have +8%
Health and deal +8% damage, Act III's +10% and +10%**; acts I and IV keep the depth's numbers.
Without it floors 4-8 were a flat stretch between a gentle Act I and Act IV (docs/balance-log.md,
"Keeper's curve").

**Supports** fight from behind, kill them first: the **Moss Heart** (act I) and the **Ember
Heart** (act III) mend their hurt allies, the **Soul Moth** (act II) and the **Gilded Moth**
(act IV) wrap them in wards that soak up your blows, the **Sand Drummer** (act IV) beats a war
drum (allies hit harder, run faster); each shoots its own element (the Moss Heart poisoning
spores, the Soul Moth a pale wisp, the Gilded Moth a golden mote, the Sand Drummer a clod of
sand that slows; only the Ember Heart and the Ghost Lantern throw burning ghost flames); the
**Fire Shaman** now mends its allies too
(`AllyEffect`: heal, buff or ward the allies around; `SkillDef.ai_ally_need`: only when an ally
needs it). A beam of light shows who is helped; the Soul Moth's wards are spirit (each warded ally
flares in a hollow ring, the ward is a flickering shell with pale flames licking off it), and the
moth throws soul flames that slow (not fire). Venom is one look everywhere: the Deathcap's spore
clouds, the Acid Larva's and Bone Lizard's spit, the Viper's, Crimson Viper's and Brood Mother's
fangs, the Giant Frog's Poison Spit and the Jade Wyrm's Venom Spit, Toxic Bloom and Venom Fang
are globs of venom, gas and pale fangs (docs/vfx.md). Claws (the spiders, racoons, moles, the
owl) rake in blood; ghosts touch with spectral claws, blink in pale flames, wail in rings of
wisps and are called out of hollow rings; Burrowers and Stone Moles **burrow** (their own skill,
a puff of earth) rather than blink like ghosts.

Monsters are data (`MonsterDef`): stats, a weapon (its `on_hit` status poisons, burns or slows),
skills (telegraphed casts: spore clouds, dives, charges, ink rings...), and **traits**
(`MonsterDef.traits`, `src/definitions/monster_traits/`): small resources that hook into the
monster (on spawn, every frame, steering, attacking, taking a hit, hurting the hero, dying, drawing).
Every monster of a kind shares the trait; per-monster values live in `Monster.trait_state()`.
What a monster draws besides its body (warnings, elite aura and name, health bar, trait drawings)
is `MonsterOverlay`.

- **DeathBurstTrait**: bursts after a short warning (a flame spirit explodes, a frost skull
  bursts into a ring of ice crystals that slows everything around: `element`, docs/vfx.md).
- **DeathSpawnTrait**: monsters come out when it dies (a giant slime splits in two).
- **GuardTrait** (Shell Guard): the shell, the silver arc in front of it, blocks most of the damage
  and push of blows from the front. It turns slowly: roll behind it. Burns, poison and blasts
  go around the shell.
- **ThiefTrait** (Thief Racoon): each hit takes some of your gold, then it runs away. Slay it to
  get the gold back, with interest.
- **Brood Mother**: keeps her distance and lays red spiders (a `SummonEffect` skill). Kill her first.
- **Bomber**: keeps away and lobs bombs that blow up where they land (a projectile skill with an
  `explosion_radius`).
- The **Fire Shaman** heals the monsters around it.

## Monster ranks: Elite, Fell, Legendary, Celestial

Any monster can come at a rank (`MonsterRankDef`, `data/monster_ranks/`; `DungeonConfig.elite_rank`
and `rare_ranks`, rarest first, each with its own chance from its depth, times the difficulty):

| Rank | Affixes | Health (depth 1 / 5 / 11) | Damage | Look | Rewards |
|---|---|---|---|---|---|
| **Elite** | 1 ("Vampiric Skeleton") | x2.5 / x3.7 / x5.5 | x1.15 | a ring of the affix's color | x3 XP, better loot, 1 extra drop |
| **Fell** (from depth 3) | 2, listed over its name | - / x6.3 / x9 | x1.2 | two purple rings | x6 XP, 2 extra drops, x8 gold |
| **Legendary** (from depth 5) | 3 | - / x8.5 / x11.5 | x1.3 | golden rings and a crown of rays | x10 XP, 3 extra drops of high quality, x15 gold |
| **Celestial** (1 in 400, any depth) | none | x3.3 / x3.9 / x4.8 | x1 | other colors (hue shift), a gleam sweeping its body, sparkles | x8 XP, 3 extra drops, x25 gold; joins the bestiary's Celestial collection |

A rank's Health grows with depth (`hp_multiplier` + `hp_multiplier_per_depth` per floor): the
hero's power grows faster than the monsters' own depth scaling, so a deeper Elite needs more
Health to stay a short duel. Its affixes' Health on top (Ironclad x1.3, Bursting x0.85...).
Ranked bosses use `boss_hp_multiplier` and keep their own damage.

Bosses roll the rare ranks too (`boss_chance`): a **Legendary Bloated King (Swift, Vampiric,
Ironclad)** has its affixes' perks, more HP, better loot and one more relic to choose; a Celestial boss
other colors and one more relic. The boss bar shows the rank's color and the affixes. The debug
panel spawns any rank and can make the next boss one.

## Bosses

The last floor of each act is a start room and one big arena. The boss sleeps
in the middle; walking in closes the exits with spikes and wakes it up (boss music, health bar
with its portrait). A `BossDef` is a `MonsterDef` plus:

- **phases**: three per boss, full life, two thirds (`hp_ratio` 0.66) and one third (0.33). Each
  phase adds stats, swaps in new attack patterns, shortens the wind-up and the cooldowns
  (`cooldown_multiplier`) and tints the boss; the last one uses fierce versions of its skills
  (`<skill>_fierce`: a second wave, rings shifted into the gaps of the first, more summons).
  Entering a phase, the boss **roars**: untouchable for a moment (`phase_roar_time`) and a
  shockwave throws the hero off. Notches on the boss bar show where the next phases start;
- **no face-tanking**: hit it too many times in a row (`shockwave_after_hits`, fewer in later
  phases) and it answers with the same shockwave (`Combat.shockwave`), which hits as hard as its
  blows (`shockwave_power`, a share of its power): roll through the red ring or stop hitting;
- **cast skills**: rings of projectiles, ground quakes (red circle), summons (`SummonEffect`), dashes;
- **relic_choices**: when it dies the spikes go down, the stairs appear and you pick a relic.

| Floor | Boss | Style |
|---|---|---|
| 3 | Bloated King | 360° slams, slime rain, splits into slimes at half HP |
| 6 | Gorr the One-Eyed | heavy club, fire eye beam (a fan of long rays of fire), quake (the ground bursts), calls skeletons, berserk at 20% |
| 9 | Crimson Tengu | fast blade, dashes, feather storms, calls spirits |
| 12 | Gilded Hoarder | crushing leaps, storms of gold coins, calls its thieves (Gold Racoons) when half dead |
| 6 (hidden) | The Nameless Effigy | twin cold blades, dashes, wailing rings, calls the dead; only on the hidden floor |

**The Nameless Effigy** / *Le Gisant Sans Nom*, "He Who Does Not Rest" / *Celui qui ne repose
pas* (`data/monsters/bosses/nameless_effigy.tres`): the boss of the hidden floor between Act II
and Act III (dungeon.md, The hidden floor), the stone knight of a nameless tomb, risen. Its look is
the Ember Ronin's sheet recolored in bone and ash with cold blue light
(`assets/characters/bosses/nameless_effigy/`, from the CC0 Ninja Adventure art). Built from
existing attacks: the Ronin's blade (`tengu_blade`) and dash, the Mother of Tears' wailing ring;
at two thirds "THE DEAD ANSWER!" (it calls skeletons too), at one third "IT WILL NOT REST!" (the
fierce dash, ring and call, faster wind-ups and cooldowns). 1500 base Health, 6 Armor, speed 85:
on floor 6 that is 3975 Health on Keeper, between Act II's bosses (2650-3048) and Act III's on
floor 9 (5278-5642). Its challenge: shatter it with a Pickaxe. In the bestiary it comes after the
acts, a "???" card under a "???" heading until it was met.

## Dragons

- **Sand Drake** (Act IV): breathes slowing sand, whips up a sandstorm ring.
- **The Wyrms** (`WyrmTrait`, `WyrmBody`): long dragons. The boss is the head; a body of
  segments follows the path the head took, wings flap on its sides, a pointed tail ends it.
  The body burns at a touch (and throws you back); only the head can be hurt. They fly.
  **Azure Wyrm** (Act II, frost: Frost Breath and Hailstorm throw ice shards, Glacial Dive leaves
  a line of crystals that shatter, its Frost Fang strikes with claws of ice) and **Jade Wyrm**
  (Act III, venom: Venom Spit, Coil Rush, Toxic Bloom), with their three phases and fiercer
  forms, and their own bestiary challenge (a Hammer, an Axe).

## The Deeps' demons

They live under every floor, in the Deeps a fall takes the hero to (dungeon.md, "The Deeps"),
and in no act (`AbyssDef.monsters`, `data/monsters/abyss/`; `ContentDB.abyss_monsters()`): they
come in its waves and wait in its rooms, each from its `min_depth`, and scale with the depth and
the difficulty like any monster (`FloorRules`). Art: Ninja Adventure (CC0), sheets the floors
don't use. The bestiary lists them under their own heading after the acts ("The Deeps"), with the
usual hunter ranks and challenges (the hole challenge too: the Deeps have holes).

| Demon (FR / EN) | Art | Health / Armor / Speed | Weapon | How it fights | From |
|---|---|---|---|---|---|
| Démon Écarlate / Scarlet Fiend | DemonRed | 64 / 2 / 78 | Demon Club (13, heavy push) | a slow brute, hard to push (40%), long wind-up | Act I |
| Carcasse Cornue / Horned Carcass | SkeletonDemon | 30 / 1 / 150 | Scimitar (7) | fast, quick blows | Act I |
| Buveur de Sang / Blood Drinker | Vampire | 46 / 1 / 108 | Claws (6, blood) | drinks 60% of the damage it deals (`PerkTrait`: a lifesteal perk, `thirst.tres`) | Act I |
| Œil des Tréfonds / Eye of the Deeps | Eye2 | 34 / 1 / 45 | Evil Eye (6, shots) | floats, keeps away (220), flies over holes | Act I |
| Âme de Braise / Cinder Wraith | Spirit2 | 28 / 0 / 110 | Ghost Flame (5, burns) | flies, keeps away (160), spits embers | Act I |
| Rôdeur d'Ombre / Shade Stalker | NinjaDark | 36 / 1 / 115 | Scimitar (7) | blinks at you (Blink) | Act II (depth 4) |
| Augure Cornu / Horned Augur | DemonGreen | 38 / 0 / 75 | Hex Staff (6, shadow bolts) | keeps away (170), a volley of shadow bolts | Act II (depth 4) |
| Gardien de la Brèche / Breach Warden | DemonCyclop2 (50x50) | 170 / 4 / 58 | Maul (13) | stands before the Dawn Breach, War Cry, hardly pushed (85%); never in the waves | Act III |

`PerkTrait` (`src/definitions/monster_traits/perk_trait.gd`) is the one new trait: a kind born
with perks, working as they do on the hero or on an elite. XP: 8 to 13 (the Warden 40).
