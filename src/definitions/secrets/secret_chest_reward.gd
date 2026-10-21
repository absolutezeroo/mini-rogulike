class_name SecretChestReward
extends SecretRewardDef
## A chest in the middle of the secret room, better than the ones lying around (its ChestDef).
## Never trapped: finding the room was the test.

@export var chest: ChestDef


func place(world: World, cell: Vector2i, _rng: RandomNumberGenerator) -> Array[Node]:
	if chest == null:
		return []
	return [world.spawn_chest(chest, cell, false)]


func is_claimed(spawned: Array[Node]) -> bool:
	return spawned.all(func(node: Node) -> bool: return not is_instance_valid(node) or (node as Chest).is_open)


func place_spent(world: World, cell: Vector2i) -> void:
	if chest:
		world.spawn_chest(chest, cell, false).set_spent()
