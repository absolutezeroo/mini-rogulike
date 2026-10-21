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
## What the user turns into for the dash (Shadow Step: shadow): it bursts where they leave and
## leaves the element's pieces along the way (smoke drawn back in).
@export var element: VfxElementDef


func apply(user: Actor, aim: Vector2) -> void:
	var dir := aim
	match direction:
		Direction.MOVE:
			if user.get_move_direction() != Vector2.ZERO:
				dir = user.get_move_direction()
		Direction.AWAY:
			dir = -aim
	user.start_dash(dir.normalized() * distance / duration, duration, invulnerable)
	if element:
		var world := user.world
		var start := user.global_position
		Vfx.pop(world, start, element, 14.0, -dir)
		# Along the way it really went (walls stop a dash), once it is over.
		user.get_tree().create_timer(duration, false).timeout.connect(func() -> void:
			if is_instance_valid(user) and is_instance_valid(world):
				Vfx.trail(world, start, user.global_position, element, 0.08))
