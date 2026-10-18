class_name HealEffect
extends Effect
## Restores health to the user.

@export var amount: int = 20
## Extra healing as a fraction of max HP.
@export_range(0.0, 1.0) var max_hp_ratio: float = 0.0


func apply(user: Actor, _aim: Vector2) -> void:
	var healed := user.heal(amount + roundi(user.get_max_hp() * max_hp_ratio))
	if healed > 0:
		user.world.spawn_floating_text(user.head_position(), "+%d" % healed, Color("6ee787"))
	user.world.spawn_vfx(RingVfx.create(user.global_position, user.radius * 2.5, Color("6ee787")))
	Vfx.sparkles(user.world, user.global_position, Color("6ee787"))
