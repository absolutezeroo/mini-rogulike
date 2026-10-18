class_name DashEffect
extends Effect
## Quick burst of movement. Goes where the user is moving, or along the aim if standing still.

@export var distance: float = 150.0
@export var duration: float = 0.16
@export var invulnerable: bool = true


func apply(user: Actor, aim: Vector2) -> void:
	var direction := user.get_move_direction()
	if direction == Vector2.ZERO:
		direction = aim
	user.start_dash(direction.normalized() * distance / duration, duration, invulnerable)
