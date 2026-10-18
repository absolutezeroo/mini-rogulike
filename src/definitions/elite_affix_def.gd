class_name EliteAffixDef
extends ContentDef
## What makes an elite monster special: "Swift", "Vampiric", "Explosive"...
## `display_name` goes before the monster's name ("Vampiric Skeleton"), `color` is its glow.
## Every elite is also tougher, bigger and worth more (DungeonConfig > Elites).

## Stats and passives the monster gets: a perk, just like the hero's.
@export var perk: PerkDef
## On top of the elite HP bonus every elite gets.
@export var hp_multiplier: float = 1.0
