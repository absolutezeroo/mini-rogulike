class_name SecretRewardDef
extends ContentDef
## What a secret room holds (DungeonConfig.secret_rewards): one is drawn per room by
## `spawn_weight` among those whose `min_depth` is reached, from the floor's seed (SecretRoom).
## Subclasses put their thing in the room when it opens: a better chest, a shrine, a rune, gold,
## a rare potion... `display_name` is what the log says was found.


## Puts the reward in the room just opened, around `cell` (its middle). Returns what it spawned,
## for is_claimed(). `rng`: the room's own stream (the same reward every time the floor is built).
func place(_world: World, _cell: Vector2i, _rng: RandomNumberGenerator) -> Array[Node]:
	return []


## The hero took it (the room then stays looted after a resume). By default: everything it
## spawned is gone (picked up).
func is_claimed(spawned: Array[Node]) -> bool:
	return spawned.all(func(node: Node) -> bool: return not is_instance_valid(node) or node.is_queued_for_deletion())


## A looted room on a floor built again (a resumed run): what is left of the reward (an open
## chest...). Nothing by default.
func place_spent(_world: World, _cell: Vector2i) -> void:
	pass
