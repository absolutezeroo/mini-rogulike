class_name ContentDB
extends Resource
## Index of all game content. To add a monster or an item, create its .tres
## and add it to the matching list in res://data/content_db.tres.

@export var player: PlayerDef
@export var dungeon: DungeonConfig
@export var monsters: Array[MonsterDef] = []
## Items that can be found lying on the floor. Loot tables can also reference items not listed here.
@export var items: Array[ItemDef] = []


func pick_monster(depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	return _pick(monsters, depth, rng)


func pick_item(depth: int, rng: RandomNumberGenerator) -> ItemDef:
	return _pick(items, depth, rng)


static func _pick(pool: Array, depth: int, rng: RandomNumberGenerator) -> ContentDef:
	var candidates: Array = []
	var weights := PackedInt32Array()
	for def: ContentDef in pool:
		if def != null and def.min_depth <= depth and def.spawn_weight > 0:
			candidates.append(def)
			weights.append(def.spawn_weight)
	return RandomUtils.pick_weighted(candidates, weights, rng)
