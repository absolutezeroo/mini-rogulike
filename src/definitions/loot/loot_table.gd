class_name LootTable
extends Resource
## What a monster can drop when it dies.

## Chance for each roll to drop something.
@export_range(0.0, 1.0) var drop_chance: float = 0.3
@export_range(1, 10) var rolls: int = 1
@export var entries: Array[LootEntry] = []


func roll(rng: RandomNumberGenerator) -> Array[ItemDef]:
	var drops: Array[ItemDef] = []
	var weights := PackedInt32Array()
	for entry in entries:
		weights.append(entry.weight if entry.item else 0)

	for i in rolls:
		if rng.randf() >= drop_chance:
			continue
		var entry: LootEntry = RandomUtils.pick_weighted(entries, weights, rng)
		if entry:
			drops.append(entry.item)
	return drops
