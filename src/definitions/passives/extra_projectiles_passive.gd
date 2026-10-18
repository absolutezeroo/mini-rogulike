class_name ExtraProjectilesPassive
extends Passive
## Everything the owner shoots (weapons and skills) fires extra projectiles in a fan.

@export var count_per_stack: int = 1
## Degrees between projectiles when the volley had no spread.
@export var spread_per_projectile: float = 12.0


func modify_projectiles(_owner: Actor, spec: ProjectileSpec, perk: PerkSet.Entry) -> void:
	spec.count += count_per_stack * perk.stacks
	if spec.spread_degrees < 360.0:
		spec.spread_degrees = maxf(spec.spread_degrees, spread_per_projectile * (spec.count - 1))
