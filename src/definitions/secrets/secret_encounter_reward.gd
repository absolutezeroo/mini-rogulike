class_name SecretEncounterReward
extends SecretRewardDef
## A shrine or an altar alone in the secret room: one of `encounters` (EncounterDef, by their
## spawn weight), answered once like any other.

@export var encounters: Array[EncounterDef] = []


func place(world: World, cell: Vector2i, rng: RandomNumberGenerator) -> Array[Node]:
	var encounter := ContentDB.pick_from(encounters, world.depth, rng) as EncounterDef
	if encounter == null:
		return []
	return [world.spawn_encounter(encounter, cell)]


func is_claimed(spawned: Array[Node]) -> bool:
	return spawned.all(func(node: Node) -> bool: return not is_instance_valid(node) or (node as Encounter).used)
