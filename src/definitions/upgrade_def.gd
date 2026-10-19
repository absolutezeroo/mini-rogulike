class_name UpgradeDef
extends Resource
## A permanent upgrade bought at the shrine with souls (earned at the end of every run).
## No classes: upgrades make every run a bit stronger, and unlocks add new items to the dungeon.

enum Kind {
	## `bonuses` per level, added to the hero's base stats.
	STATS,
	## `items` given at the start of every run, once per level.
	STARTING_ITEMS,
	## `perk` taken at the start of every run.
	STARTING_PERK,
	## `items` can now be found in the dungeon (one level).
	UNLOCK,
	## One more reroll of the perk cards per run, per level.
	REROLLS,
	## One more banish (a perk gone for the run) per run, per level.
	BANISHES,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var kind: Kind = Kind.STATS
@export_range(1, 10) var max_level: int = 1
## Souls for the first level; each next level costs `cost_growth` more.
@export var cost: int = 50
@export var cost_growth: int = 0

@export_group("What it gives")
@export var bonuses: StatBlock
@export var items: Array[ItemDef] = []
@export var perk: PerkDef


func cost_for_level(level: int) -> int:
	return cost + cost_growth * level
