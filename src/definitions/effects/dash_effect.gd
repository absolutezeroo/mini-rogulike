class_name DashEffect
extends Effect
## Quick burst of movement.

enum Direction {
	## Where the user is moving, or along the aim when standing still (a roll).
	MOVE,
	## Toward the aim (gap closer).
	AIM,
	## Away from the aim (back step).
	AWAY,
}

@export var direction: Direction = Direction.MOVE
@export var distance: float = 150.0
@export var duration: float = 0.16
@export var invulnerable: bool = true


func apply(user: Actor, aim: Vector2) -> void:
	var dir := aim
	match direction:
		Direction.MOVE:
			if user.get_move_direction() != Vector2.ZERO:
				dir = user.get_move_direction()
		Direction.AWAY:
			dir = -aim
	user.start_dash(dir.normalized() * distance / duration, duration, invulnerable)
