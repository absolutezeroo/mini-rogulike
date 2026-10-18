class_name BuffEffect
extends Effect
## Temporarily adds stats to the user.

@export var bonuses: StatBlock
@export var duration: float = 6.0
@export var color: Color = Color(1.0, 0.4, 0.3)


func apply(user: Actor, _aim: Vector2) -> void:
	if bonuses == null:
		return
	user.add_timed_bonus(bonuses, duration)
	user.world.spawn_floating_text(user.head_position(), bonuses.describe(), color)
	user.world.spawn_vfx(RingVfx.create(user.global_position, user.radius * 2.5, color))
