class_name DeathBurstPassive
extends Passive
## The owner blows up a moment after dying, hurting everyone around (its friends too).

@export var radius: float = 70.0
## Grows with depth and the difficulty, like the dungeon's other damage.
@export var damage: int = 10
@export var fuse: float = 0.6


func on_died(owner: Actor, perk: PerkSet.Entry) -> void:
	if owner.is_falling:
		return  # down a hole: the blast goes off out of reach
	var world := owner.world
	var amount := roundi((damage * perk.stacks + world.depth) * world.damage_scale())
	Combat.delayed_blast(world, owner.global_position, radius, amount, fuse)
