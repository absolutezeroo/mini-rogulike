class_name SoulWisp
extends Node2D
## A soul set free by a kill: it rises out of the body, then flies into the hero's lantern
## (Events.soul_gathered when it gets there). Drawn unshaded so it shows in the dark.

const RISE_TIME := 0.35
const SPEED := 520.0
const LIFETIME := 3.0
const COLOR := Color(0.65, 0.95, 1.0)
const TRAIL_LENGTH := 7

var _target: Node2D
var _velocity := Vector2.ZERO
var _age := 0.0
var _trail: Array[Vector2] = []


static func create(at: Vector2, target: Node2D) -> SoulWisp:
	var wisp := SoulWisp.new()
	wisp.position = at
	wisp._target = target
	wisp._velocity = Vector2(randf_range(-70.0, 70.0), randf_range(-150.0, -90.0))
	wisp.z_index = 5
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	wisp.material = glow
	return wisp


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(_target) or _age > LIFETIME:
		queue_free()
		return
	var goal := _target.global_position + Vector2(0, -18)
	if _age < RISE_TIME:
		_velocity = _velocity.move_toward(Vector2.ZERO, 260.0 * delta)
	else:
		var speed := SPEED * minf(1.0, 0.3 + (_age - RISE_TIME) * 2.5)
		_velocity = _velocity.lerp(global_position.direction_to(goal) * speed, minf(1.0, 8.0 * delta))
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	global_position += _velocity * delta
	queue_redraw()
	if _age > RISE_TIME and global_position.distance_to(goal) < 14.0:
		Sfx.play_at(Sfx.bank.soul, global_position, -12.0)
		Events.soul_gathered.emit()
		queue_free()


func _draw() -> void:
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		var color := COLOR
		color.a = 0.35 * t
		draw_circle((_trail[i] - global_position).round(), 1.5 + 2.0 * t, color)
	var pulse := 0.8 + 0.2 * sin(_age * 20.0)
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(0.25, 0.75, 1.0, 0.3))
	draw_circle(Vector2.ZERO, 5.0, COLOR)
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
