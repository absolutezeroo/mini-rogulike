extends State
## Goes after the target: straight line when it can see it, pathfinding around walls otherwise.
## Uses skills when their conditions match (through Cast when they have a cast time)
## and switches to Attack when in range.

const REPATH_INTERVAL := 0.4
const GIVE_UP_AFTER := 4.0       ## Seconds without seeing the target before going back to Idle.
const SIGHT_MULTIPLIER := 1.6    ## Chasing monsters see further than idle ones.
const WAYPOINT_REACHED := 8.0

var _path := PackedVector2Array()
var _repath_timer := 0.0
var _unseen_time := 0.0


func enter() -> void:
	_path.clear()
	_repath_timer = 0.0
	_unseen_time = 0.0


func physics_update(delta: float) -> void:
	if not actor.notice_target():
		machine.transition_to(&"Idle")
		return

	var target := actor.target
	var to_target := target.global_position - actor.global_position
	var distance := to_target.length()
	var aim := to_target.normalized()
	var sees := actor.can_see(target, actor.def.detect_radius * SIGHT_MULTIPLIER)

	_unseen_time = 0.0 if sees else _unseen_time + delta
	if _unseen_time > GIVE_UP_AFTER:
		actor.target = null
		machine.transition_to(&"Idle")
		return

	if sees:
		var skill_index := actor.pick_skill(distance)
		if skill_index >= 0:
			_use_skill(skill_index, aim)
			return
		if distance <= actor.attack_range(target) and actor.can_attack():
			machine.transition_to(&"Attack")
			return
		_move_in_sight(distance, aim)
	else:
		_follow_path(delta, target)


## Telegraphed skills go through the Cast state, instant ones fire right away.
func _use_skill(index: int, aim: Vector2) -> void:
	actor.facing = aim
	actor.move_direction = Vector2.ZERO
	if actor.skills.skills[index].cast_time > 0.0:
		actor.casting_index = index
		machine.transition_to(&"Cast")
	else:
		actor.skills.try_use(index, actor, aim)


func _move_in_sight(distance: float, aim: Vector2) -> void:
	actor.facing = aim
	var keep := actor.def.keep_distance
	if keep > 0.0 and distance < keep:
		actor.move_direction = -aim                  # too close: back off
	elif keep > 0.0 and distance <= actor.attack_range(actor.target):
		actor.move_direction = aim.orthogonal() * 0.4  # in range: strafe while reloading
	else:
		actor.move_direction = aim


func _follow_path(delta: float, target: Actor) -> void:
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		_path = actor.world.find_path(actor.global_position, target.global_position)
	while not _path.is_empty() and actor.global_position.distance_to(_path[0]) < WAYPOINT_REACHED:
		_path.remove_at(0)
	if _path.is_empty():
		actor.move_direction = Vector2.ZERO
	else:
		actor.move_direction = actor.global_position.direction_to(_path[0])
		actor.facing = actor.move_direction
