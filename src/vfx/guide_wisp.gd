class_name GuideWisp
extends Node2D
## A golden light that runs ahead of the hero along a path (the way to the stairs once their
## seal breaks), then fades where it ends. Drawn unshaded so it shows in the dark.

const SPEED := 420.0
const LIFETIME := 6.0
const FADE_TIME := 0.5
const COLOR := Color(1.0, 0.85, 0.45)
const TRAIL_LENGTH := 10

var _path := PackedVector2Array()
var _next := 0
var _age := 0.0
## Counts down once the path is done.
var _fading := -1.0
var _trail: Array[Vector2] = []


static func create(at: Vector2, path: PackedVector2Array) -> GuideWisp:
	var wisp := GuideWisp.new()
	wisp.position = at
	wisp._path = path
	wisp.z_index = 5
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	wisp.material = glow
	return wisp


func _process(delta: float) -> void:
	_age += delta
	if _fading >= 0.0:
		_fading -= delta
		if _fading <= 0.0:
			queue_free()
	elif _age > LIFETIME or _next >= _path.size():
		_fading = FADE_TIME
	else:
		var goal := _path[_next] + Vector2(0, -14)
		var step := SPEED * minf(1.0, 0.4 + _age * 2.0) * delta
		if global_position.distance_to(goal) <= step:
			global_position = goal
			_next += 1
		else:
			global_position += global_position.direction_to(goal) * step
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 if _fading < 0.0 else _fading / FADE_TIME
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		draw_circle((_trail[i] - global_position).round(), 1.5 + 2.5 * t, Color(COLOR, 0.4 * t * alpha))
	var pulse := 0.8 + 0.2 * sin(_age * 14.0)
	draw_circle(Vector2.ZERO, 11.0 * pulse, Color(1.0, 0.7, 0.25, 0.3 * alpha))
	draw_circle(Vector2.ZERO, 5.0, Color(COLOR, alpha))
	draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, alpha))
