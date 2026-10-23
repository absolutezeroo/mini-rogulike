class_name SecretItemReward
extends SecretRewardDef
## Items lying in the secret room: `count` of `items` (by their spawn weight), or runes from the
## content's runes when `runes` is on.

@export var items: Array[ItemDef] = []
## Runes (ContentDB.runes, by depth and weight) instead of `items`.
@export var runes := false
@export_range(1, 5) var count: int = 1
## How good the equipment among them may come out (LootRoller), like a chest's.
@export var loot_quality: float = 2.0


func place(world: World, cell: Vector2i, rng: RandomNumberGenerator) -> Array[Node]:
	var result: Array[Node] = []
	var pool: Array = items
	if runes:
		pool = world.content_db().runes
	for i in count:
		var item := ContentDB.pick_from(pool, world.depth, rng) as ItemDef
		if item == null:
			continue
		var at := world.map.cell_to_world(cell) + Vector2((i - (count - 1) * 0.5) * 22.0, 0.0)
		var pickup := world.spawn_item(item, at) if item is RuneDef else world.spawn_loot(item, at, loot_quality)
		if pickup:
			result.append(pickup)
	return result
