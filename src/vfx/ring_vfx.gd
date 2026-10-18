class_name RingVfx
extends Node2D
## Expanding ring: explosions, area attacks, heals, level ups.

const LIFETIME := 0.3

var _radius := 40.0
var _color := Color.WHITE
var _age := 0.0


static func create(at: Vector2, radius: float, color: Color) -> RingVfx:
	var vfx := RingVfx.new()
	vfx.position = at
	vfx._radius = radius
	vfx._color = color
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var radius := _radius * lerpf(0.4, 1.0, ease(t, 0.4))
	var fill := _color
	fill.a = 0.18 * (1.0 - t)
	var line := _color
	line.a = 0.9 * (1.0 - t)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, line, 3.0)
