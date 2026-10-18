class_name LootTable
extends Resource
## What a monster can drop when it dies.

## Chance for each roll to drop something.
@export_range(0.0, 1.0) var drop_chance: float = 0.3
@export_range(1, 10) var rolls: int = 1
@export var entries: Array[LootEntry] = []


func roll(rng: RandomNumberGenerator) -> Array[ItemDef]:
	var drops: Array[ItemDef] = []
	for i in rolls:
		if rng.randf() < drop_chance:
			var item := pick(rng)
			if item:
				drops.append(item)
	return drops


## One item from the table, ignoring the drop chance (null if the table is empty).
func pick(rng: RandomNumberGenerator) -> ItemDef:
	var weights := PackedInt32Array()
	for entry in entries:
		weights.append(entry.weight if entry.item else 0)
	var entry: LootEntry = RandomUtils.pick_weighted(entries, weights, rng)
	return entry.item if entry else null
