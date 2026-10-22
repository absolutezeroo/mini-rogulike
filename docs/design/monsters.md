# Acts, monsters and bosses

## Acts and their monsters

A run is **4 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its biomes, its own monsters and a boss on its last floor. Beating the last boss **wins the run**
the first time; once the profile has won a run, the last act's boss leads down to **the Bottom
of the Well** instead (below, and dungeon.md), whose last form wins it. You can then keep going in
endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. The Well's Maw | 1-3 | Gnawer, Gloom Bat, Slime, Blood Spider, Deathcap, Viper, Acid Larva, Burrower, Giant Slime, Shell Guard, Thief Racoon | Bloated King |
| II. Ossuary of Kagari | 4-6 | Skeleton, Hexer, Lost Soul, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull, Thief Racoon, Brood Mother | Gorr the One-Eyed |
| III. The Pyre Temple | 7-9 | Fire Shaman, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus, Bomber, Brood Mother, Shell Guard | Crimson Tengu |
| IV. Kingdom of Dust | 10-12 | Dune Behemoth, Gold Racoon, Crimson Viper, Ash Lizard, Bone Lizard, Stone Mole, Bomber | Gilded Hoarder |

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
- **WeakPointTrait** (the Maw): only its weak point can be hurt, and only while it opens. Closed,
  every blow glances off whole (no damage, no status, no streak toward the shockwave: a clang off
  its mask, sparks, "No effect") and it uses its skills; every `closed_times` seconds (shorter in
  each phase) it opens (`open_animation`, then `open_pose` held) for `open_times` seconds, its
  skills put away: hits land, it draws the hero toward its mouth (`pull_speed`, a third of his
  pace) and bites him if he comes too close (a warning circle, then the bite, thrown back). It
  can be rooted (never walks), carry its own light (`glow_level`, brighter open) and stand in a
  pool drawn on the ground under it. Hooks it added to `MonsterTrait`: `deflects()` (a hit turned
  away before anything happens) and `can_cast()`.
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
| bottom (after a first win) | Master Tôma, then the Maw | the hero's own blade and lantern; then a jaw that must open to be hurt |

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

## The bottom of the Well: Master Tôma and the Maw

The final fight (dungeon.md, "The bottom of the Well"; the canon in docs/lore.md, section 3).
One arena, two forms (`BossDef.next_boss`): `data/monsters/bosses/master_toma.tres`, then
`the_maw.tres`. Art: PixelLab sheets made for the game (`assets/characters/bosses/master_toma/`,
64x64 cells; `the_maw/`, 128x136: the 128x128 frames padded 4 pixels top and bottom).

**Maître Tôma, le Gardien Parjure / Master Tôma, the Oathbreaker.** Kneels below the arena's
middle (`arena_anchor` 0.5, 0.62); walking in, he opens his eyes and draws (intro): « Tu es venu,
mon élève. » / "You came, my pupil." (his `waking_line`, a banner after his name). He waits
his waking out (`waits_intro`: 1.3 s, no step, no blow) before the duel starts. A duelist with
the hero's techniques, every one telegraphed:

| Skill | What | Warning |
|---|---|---|
| Keeper's Step / Pas du Gardien (`toma_dash`) | a dash strike, the hero's iaido cut along it (230 units) | 0.55 s: he draws (`windup`), the line of the dash |
| Severing Arc / Arc Tranchant (`toma_wide_slash`, from two thirds) | a wide cleave in front (96 radius, x1.4) | 1.25 s: he draws and holds his guard, the circle of the cut |
| The Lantern Turned / La Lanterne Retournée (`toma_lantern`) | he raises the unlit lantern, it flares violet: a circle on the ground under the hero fills for 1 s, then a violet flame (shadow) closes on it | the cast (0.8 s), then the circle (1 s) |

His katana (Keeper's Katana: 13, reach 52, a 150° arc) between them, its own wind-up animation.
At two thirds "HE TAKES THE HIGH GUARD" (the wide cut joins); at one third "THE LANTERN BURNS
VIOLET" (the fierce step, cutting twice; three flames in a row). 1300 base Health, 5 Armor, speed
95; shockwave after 8 / 7 / 5 hits as for the others. **No relic** (`relic_choices` 0).
When he falls, his body stays, kneeling (`body_stays`): « Ta garde est juste, mon élève. » /
"Your guard is true, my pupil." Then the arena darkens and shakes (`rise_time` 2.6 s: nothing to
do but watch), **the Maw** rises out of a pool of tar at the top of the arena (`arena_anchor`
0.5, 0.24), his body is drawn into its mouth, and the boss bar passes to it with its name's
banner. The arena stays shut, no stairs, no relic between the two.

**La Gueule, la Faim du Puits / The Maw, the Well's Hunger.** Rooted, never pushed, its own
golden light in the dark; the view leans toward it (`camera_lean` 0.45) so it and the hero both
stay on a phone's screen. Hana's voice wakes with it: « Papa... reste. » / "Papa... stay."
Its jaw is a **WeakPointTrait**: closed 6.5 s (5 s from 60%, 3.8 s from 30%), open 3.6 s (3.2 s
at the end). Open, Tôma is seen standing in its mouth: every hit lands; it draws the hero in (55
a second, he runs 170) and bites him within 72 of its mouth (0.55 s warning, x1.5 its power,
thrown back hard, every 1.3 s at most). No shockwave for hitting it (`shockwave_after_hits` 0):
the bite is the price of standing in its mouth. Closed, its skills:

| Skill | What |
|---|---|
| Tar Lash / Fouet de Goudron | three (fierce: five) circles fill on the ground around the hero, one after the other, and tentacles of tar slam them (earth: the ground bursts) |
| Call the Damned / L'Appel des Damnés | 2 (fierce: 3) of the Deeps' demons crawl out (Horned Carcass, Shade Stalker, Cinder Wraith; 4-5 at most) |
| False Dawn / Fausse Aube (from 60%) | four columns of false sunlight (holy) fall on circles around the hero |
| Dead Sun's Gaze / Regard du Soleil Mort (from 30%) | a fan of seven sun rays (fire), the Dead Sun's echo |

"THE FALSE SUN RISES" at 60%, "THE HUNGER WAKES" at 30%. 1300 base Health, 3 Armor. Its death:
the golden mask cracks and crumbles (its dead animation), "The sun sets." / « Le soleil se
couche. », and only Tôma is left, standing, set down on the ground. The run is won, and the hero
chooses an ending (progression.md, "The two endings"). Then its relic, if he keeps going.

Both are in the bestiary after the hidden floor's boss, "???" (their floor's heading too) until
met. Numbers: docs/balance-log.md.

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
