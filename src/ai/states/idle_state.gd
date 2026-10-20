extends State
## Wanders around slowly until the monster notices a target. Bumping into something, it stops
## and picks another way.

const WANDER_SPEED := 0.35

var _timer := 0.0


func enter() -> void:
	actor.move_direction = Vector2.ZERO
	_timer = randf_range(0.3, 1.2)


func physics_update(delta: float) -> void:
	if actor.dormant:
		actor.move_direction = Vector2.ZERO
		return
	if actor.notice_target():
		# "!" above the head: the player knows this one is coming.
		Vfx.alert(actor.world, actor.head_position())
		Sfx.play_at(Sfx.bank.monster_alert, actor.global_position, -6.0)
		machine.transition_to(&"Chase")
		return

	_timer -= delta
	if actor.is_stuck():
		actor.move_direction = Vector2.ZERO
		_timer = minf(_timer, randf_range(0.2, 0.6))
	if _timer <= 0.0:
		_timer = randf_range(1.0, 2.5)
		actor.move_direction = Vector2.ZERO
		if randf() < 0.5:
			# Only a way its body can take (not into the wall right next to it).
			for attempt in 4:
				var way := Vector2.from_angle(randf() * TAU)
				if actor.has_clear_walk(actor.global_position + way * 48.0):
					actor.move_direction = way * WANDER_SPEED
					actor.facing = way
					break
