class_name ImpactVfx
extends Node2D
## The flash of a hit: a sharp star, long along the blow, white at heart and edged with the
## hit's color, popping then shrinking away in a blink. Bigger on critical hits.

const LIFETIME := 0.13

var _color := Color.WHITE
var _size := 1.0
var _age := 0.0


static func create(at: Vector2, direction: Vector2, color: Color, big: bool = false) -> ImpactVfx:
	var vfx := ImpactVfx.new()
	vfx.position = at
	vfx.rotation = direction.angle() if direction != Vector2.ZERO else randf() * TAU
	vfx.z_index = 6
	vfx._color = color
	vfx._size = 1.6 if big else 1.0
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var grow := _size * (0.7 + 0.6 * sin(minf(t * 1.6, 1.0) * PI * 0.5)) * (1.0 - t * 0.5)
	var edge := Color(_color, 1.0 - t)
	var heart := Color(1, 1, 1, 1.0 - t * t)
	_star(14.0 * grow, 4.0 * grow, edge)
	_star(9.0 * grow, 2.0 * grow, heart)


## Four spikes: long along the blow (x), shorter across it.
func _star(length: float, width: float, color: Color) -> void:
	var long_side := PackedVector2Array([Vector2(length, 0), Vector2(0, width), Vector2(-length * 0.55, 0), Vector2(0, -width)])
	var short_side := PackedVector2Array([Vector2(0, length * 0.6), Vector2(width, 0), Vector2(0, -length * 0.6), Vector2(-width, 0)])
	draw_colored_polygon(long_side, color)
	draw_colored_polygon(short_side, color)
