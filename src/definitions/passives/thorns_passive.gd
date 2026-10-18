class_name ThornsPassive
extends Passive
## Hurts whoever hits the owner up close.

@export var damage_per_stack: int = 4
## Attackers further away than this (shooters) are not affected.
@export var max_distance: float = 110.0


func on_damaged(owner: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	var attacker := hit.source
	if hit.is_secondary or not is_instance_valid(attacker) or attacker.is_dead or not owner.is_hostile_to(attacker):
		return
	if owner.global_position.distance_to(attacker.global_position) > max_distance:
		return
	attacker.take_hit(Combat.make_secondary_hit(owner, damage_per_stack * perk.stacks))
	Vfx.hit(owner.world, attacker.global_position, owner.global_position.direction_to(attacker.global_position), Color("c9a227"))
