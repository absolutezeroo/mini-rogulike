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
	## Changes the run's rules (the "Run rules" group below; RunBoons reads them).
	RULES,
	## One of `items` (the ones the dungeon holds), at random, at the start of every run.
	RANDOM_STARTING_ITEM,
	## Opens an oath (SoulNodeDef.oath): nothing else.
	OATH,
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

@export_group("Run rules")
## Multiplies the hero's starting max Health (RULES). Once, whatever the level: an upgrade that
## sets it has one level.
@export var max_hp_scale: float = 1.0
## Multiplies every heal the hero gets. Once, whatever the level, like max_hp_scale.
@export var healing_scale: float = 1.0
## Share of max Health healed when a floor's stairs open (or its boss falls), per level.
@export_range(0.0, 0.5) var heal_on_clear: float = 0.0
## Multiplies the merchant's prices; and more items in his stock, per level.
@export var shop_price_scale: float = 1.0
@export_range(0, 4) var shop_extra_items: int = 0
## Elites and up always drop a Magic (or better) piece of equipment.
@export var elite_magic_drop: bool = false
## The minimap shows the floor's stairs, merchant and forge from the start.
@export var cartographer: bool = false
## The run starts with the weapon picked before it, among those its level opened
## (`armory_weapons`).
@export var armory: bool = false
## The Armory's weapons, in the order its levels open them: one per way to fight first, the rare
## and strong ones last. Level 1 opens the first `armory_first`, each next level
## `armory_per_level` more. A weapon locked in ContentDB (Locked Items) is only offered once the
## tree unlocked it; an oath's weapon comes with its oath, not from here.
@export var armory_weapons: Array[WeaponDef] = []
@export_range(1, 10) var armory_first: int = 3
@export_range(1, 5) var armory_per_level: int = 2


func cost_for_level(level: int) -> int:
	return cost + cost_growth * level


## How many of `armory_weapons` the Armory offers at `level` (0 when not bought).
func armory_count(level: int) -> int:
	if level <= 0:
		return 0
	return mini(armory_first + armory_per_level * (level - 1), armory_weapons.size())


## The weapons `level` opens on top of the level below it, in data order.
func armory_added(level: int) -> Array[WeaponDef]:
	return armory_weapons.slice(armory_count(level - 1), armory_count(level))
