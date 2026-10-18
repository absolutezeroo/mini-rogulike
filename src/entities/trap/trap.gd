class_name Trap
extends Area2D
## A floor trap built from a TrapDef. Hurts every actor standing on it when it fires,
## monsters included. See TrapDef for the cycle.

enum Phase { IDLE, WARNING, ACTIVE }

const SIZE := 32.0

var def: TrapDef
var world: World
var phase := Phase.IDLE
## TIMED traps: seconds into the cycle at start, so neighbours can fire in a wave.
var cycle_offset := 0.0

var _timer := 0.0
var _hit_this_time: Array[Actor] = []
var _anim_time := 0.0


func setup(trap_def: TrapDef, offset: float = 0.0) -> void:
	def = trap_def
	cycle_offset = offset
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.MONSTERS
	monitorable = false
	add_to_group("traps")


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.8
	($CollisionShape2D as CollisionShape2D).shape = shape
	_timer = def.idle_time - fmod(cycle_offset, def.idle_time + def.warning_time + def.active_time)
	if def.trigger == TrapDef.Trigger.STEP:
		_timer = 0.0
	if _timer < 0.0:
		# The offset lands after the idle part: start straight in the warning.
		_enter(Phase.WARNING)


func is_dangerous() -> bool:
	return phase == Phase.ACTIVE


func _physics_process(delta: float) -> void:
	_anim_time += delta
	match phase:
		Phase.IDLE:
			if def.trigger == TrapDef.Trigger.STEP:
				if _timer > 0.0:
					_timer -= delta  # cooling down after firing
				elif _someone_on_it():
					_enter(Phase.WARNING)
			else:
				_timer -= delta
				if _timer <= 0.0:
					_enter(Phase.WARNING)
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_enter(Phase.ACTIVE)
		Phase.ACTIVE:
			_timer -= delta
			_hurt_overlapping()
			if _timer <= 0.0:
				_enter(Phase.IDLE)
	queue_redraw()


func _enter(next: Phase) -> void:
	phase = next
	_anim_time = 0.0
	match next:
		Phase.IDLE:
			_timer = def.idle_time
		Phase.WARNING:
			_timer = def.warning_time
		Phase.ACTIVE:
			_timer = def.active_time
			_hit_this_time.clear()
			Sfx.play_at(def.sound, global_position, -4.0)


func _someone_on_it() -> bool:
	for body in get_overlapping_bodies():
		if body is Actor and not (body as Actor).is_dead:
			return true
	return false


func _hurt_overlapping() -> void:
	for body in get_overlapping_bodies():
		var actor := body as Actor
		if actor == null or actor.is_dead or _hit_this_time.has(actor):
			continue
		_hit_this_time.append(actor)
		var hit := Combat.make_secondary_hit(null, def.damage + world.depth)
		hit.knockback = global_position.direction_to(actor.global_position) * def.knockback
		actor.take_hit(hit)
		if def.burn_damage > 0:
			actor.statuses.apply_dot(&"burn", def.burn_damage, 0.5, 3.0, null, Color("ff8c42"))


func _draw() -> void:
	if def == null:
		return
	var half := SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	var base := def.base_texture
	if def.pressed_texture and phase != Phase.IDLE:
		base = def.pressed_texture
	if base:
		draw_texture_rect(base, rect, false)
	if def.active_sheet == null or phase == Phase.IDLE:
		return
	var frames := def.active_frames
	var frame_size := Vector2(def.active_sheet.get_width() / float(frames), def.active_sheet.get_height())
	if phase == Phase.WARNING:
		# The danger peeks out and rattles: its lower third, first frame.
		var peek := 0.35
		var source := Rect2(0, frame_size.y * (1.0 - peek), frame_size.x, frame_size.y * peek)
		var shake := Vector2(sin(_anim_time * 60.0), 0.0)
		draw_texture_rect_region(def.active_sheet, Rect2(Vector2(-half, half - SIZE * peek) + shake, Vector2(SIZE, SIZE * peek)), source)
	else:
		# Plays once and holds its last frames while active.
		var frame := mini(int(_anim_time * def.active_fps), frames - 1)
		var source := Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
		var size := frame_size * (SIZE / 16.0)
		draw_texture_rect_region(def.active_sheet, Rect2(Vector2(-size.x * 0.5, half - size.y), size), source)
