class_name DashShockwavePassive
extends Passive
## Dashing releases a shockwave around the owner.

@export var radius: float = 75.0
## Damage = owner's power x this, per stack.
@export var damage_multiplier: float = 0.6
@export var knockback: float = 240.0
@export var color: Color = Color("9ad1d4")
## Left on the enemies hit (a chill, flames...).
@export var status: OnHitStatus


func on_dash(owner: Actor, perk: PerkSet.Entry) -> void:
	var amount := roundi(owner.get_power() * damage_multiplier * perk.stacks)
	Combat.damage_area(owner.world, owner, owner.global_position, radius, amount, knockback, true, status)
	owner.world.spawn_vfx(RingVfx.create(owner.global_position, radius, color))
