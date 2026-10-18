class_name SlashVfx
extends Node2D
## Short arc showing a melee swing.

const LIFETIME := 0.16

var _direction := Vector2.RIGHT
var _reach := 40.0
var _arc := 1.5
var _color := Color.WHITE
var _age := 0.0


static func create(at: Vector2, direction: Vector2, reach: float, arc_degrees: float, color: Color) -> SlashVfx:
	var vfx := SlashVfx.new()
	vfx.position = at
	vfx._direction = direction
	vfx._reach = reach
	vfx._arc = deg_to_rad(arc_degrees)
	vfx._color = color
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var angle := _direction.angle()
	var color := _color
	color.a = 0.8 * (1.0 - t)
	# The swing sweeps across the arc as it fades.
	var sweep := lerpf(-_arc * 0.5, _arc * 0.5, minf(t * 1.6, 1.0))
	draw_arc(Vector2.ZERO, _reach * 0.85, angle - _arc * 0.5, angle + sweep, 16, color, _reach * 0.3)
