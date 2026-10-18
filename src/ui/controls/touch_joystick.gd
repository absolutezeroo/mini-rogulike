class_name TouchJoystick
extends Control
## Floating joystick: touch anywhere in the left part of the screen and drag.
## Feeds the regular move_* input actions, so gameplay code never knows it exists.

## Fraction of the screen width (from the left) that starts the joystick.
@export_range(0.1, 1.0) var zone_width := 0.45
## Top fraction of the screen ignored (leaves room for the HUD).
@export_range(0.0, 0.9) var zone_top := 0.2
## Default reach of the knob (Options can make the joystick bigger or smaller).
const BASE_DISTANCE := 80.0

@export var max_distance := BASE_DISTANCE
@export_range(0.0, 0.9) var dead_zone := 0.15

const BASE: Texture2D = preload("res://assets/ui/sphere/backgroundwood.png")
const KNOB: Texture2D = preload("res://assets/ui/sphere/backgroundmetal.png")

var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _pressed_actions := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local := (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed and _finger == -1 and _in_zone(local):
			_finger = event.index
			_origin = local
			_knob = local
			_apply(Vector2.ZERO)
		elif not event.pressed and event.index == _finger:
			_finger = -1
			_apply(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _finger:
		var local := (make_input_local(event) as InputEventScreenDrag).position
		var offset := (local - _origin).limit_length(max_distance)
		_knob = _origin + offset
		_apply(offset / max_distance)


func _in_zone(local: Vector2) -> bool:
	return local.x < size.x * zone_width and local.y > size.y * zone_top


func _apply(value: Vector2) -> void:
	if value.length() < dead_zone:
		value = Vector2.ZERO
	_set_action(&"move_left", maxf(-value.x, 0.0))
	_set_action(&"move_right", maxf(value.x, 0.0))
	_set_action(&"move_up", maxf(-value.y, 0.0))
	_set_action(&"move_down", maxf(value.y, 0.0))
	queue_redraw()


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_pressed_actions[action] = true
	elif _pressed_actions.has(action):
		# Only release what we pressed, so a keyboard held at the same time keeps working.
		Input.action_release(action)
		_pressed_actions.erase(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_finger = -1
		_apply(Vector2.ZERO)


func _draw() -> void:
	var base := _origin if _finger != -1 else Vector2(60.0 + max_distance, size.y - 60.0 - max_distance)
	var knob := _knob if _finger != -1 else base
	var alpha := 0.85 if _finger != -1 else 0.4
	var base_size := Vector2.ONE * max_distance * 2.0
	draw_texture_rect(BASE, Rect2(base - base_size * 0.5, base_size), false, Color(1, 1, 1, alpha * 0.7))
	var knob_size := Vector2.ONE * max_distance * 0.9
	draw_texture_rect(KNOB, Rect2(knob - knob_size * 0.5, knob_size), false, Color(1, 1, 1, alpha))
