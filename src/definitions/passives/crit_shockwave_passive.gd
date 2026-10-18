class_name CritShockwavePassive
extends Passive
## Critical hits release a shockwave that damages enemies around the target.

@export var radius: float = 70.0
@export var radius_per_stack: float = 10.0
## Damage = owner's power x this, per stack.
@export var damage_multiplier: float = 0.5
@export var color: Color = Color("8ecae6")


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if not hit.is_crit:
		return
	var size := radius + radius_per_stack * (perk.stacks - 1)
	var amount := roundi(owner.get_power() * damage_multiplier * perk.stacks)
	Combat.damage_area(owner.world, owner, target.global_position, size, amount, 120.0, true)
	owner.world.spawn_vfx(RingVfx.create(target.global_position, size, color))
