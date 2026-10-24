class_name AscensionDef
extends Resource
## One level of ascension: Nightmare +1, +2... Winning Nightmare unlocks +1, winning +1
## unlocks +2, and so on. Each level adds its own twist on top of all the levels below it.
## Listed in order in content_db.tres > Ascensions.

@export var title: String = ""
@export var description: String = ""

@export_group("Multipliers (1 = unchanged)")
@export var monster_hp: float = 1.0
@export var monster_damage: float = 1.0
@export var monster_speed: float = 1.0
@export var telegraph_time: float = 1.0
@export var elite_chance: float = 1.0
@export var boss_hp: float = 1.0
@export var light: float = 1.0
@export var shop_prices: float = 1.0
@export var hero_max_hp: float = 1.0
@export var souls: float = 1.1
@export_range(0, 3) var extra_monsters: int = 0


## `base` (Nightmare) with the first `level` ascensions of `levels` applied: a new DifficultyDef
## shown as "Nightmare +N" (same id and name, so its wins still count as Nightmare wins).
static func apply_levels(base: DifficultyDef, levels: Array[AscensionDef], level: int) -> DifficultyDef:
	var result := base.duplicate() as DifficultyDef
	result.ascension = mini(level, levels.size())
	for i in result.ascension:
		var a := levels[i]
		result.monster_hp *= a.monster_hp
		result.monster_damage *= a.monster_damage
		result.monster_speed *= a.monster_speed
		result.telegraph_time *= a.telegraph_time
		result.elite_chance *= a.elite_chance
		result.boss_hp *= a.boss_hp
		result.light *= a.light
		result.shop_prices *= a.shop_prices
		result.hero_max_hp *= a.hero_max_hp
		result.souls *= a.souls
		result.extra_monsters += a.extra_monsters
	return result  # (named "Nightmare +N" where shown: DifficultyDef.shown_name())
