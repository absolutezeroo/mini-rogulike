extends State
## Wanders around slowly until the monster notices a target.

const WANDER_SPEED := 0.35

var _timer := 0.0


func enter() -> void:
	actor.move_direction = Vector2.ZERO
	_timer = randf_range(0.3, 1.2)


func physics_update(delta: float) -> void:
	if actor.notice_target():
		# "!" above the head: the player knows this one is coming.
		actor.world.spawn_floating_text(actor.head_position(), "!", Color("ffd166"))
		Sfx.play_at(Sfx.bank.monster_alert, actor.global_position, -6.0)
		machine.transition_to(&"Chase")
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.0, 2.5)
		if randf() < 0.5:
			actor.move_direction = Vector2.ZERO
		else:
			actor.move_direction = Vector2.from_angle(randf() * TAU) * WANDER_SPEED
			actor.facing = actor.move_direction.normalized()
