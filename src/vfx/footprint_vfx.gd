class_name FootprintVfx
extends Node2D
## A footprint left on the floor, fading away.

const LIFETIME := 3.5

var _color := Color(0, 0, 0, 0.2)
var _age := 0.0


static func create(at: Vector2, direction: Vector2, color: Color) -> FootprintVfx:
	var footprint := FootprintVfx.new()
	footprint.position = at.round()
	footprint.rotation = snappedf(direction.angle(), PI / 4.0)
	footprint._color = color
	footprint.z_index = -5
	footprint.add_to_group(&"footprints")
	return footprint


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color := _color
	color.a *= 1.0 - _age / LIFETIME
	# A small sole, 2 art pixels wide and 3 long (art pixels are 2 world pixels).
	draw_rect(Rect2(-3, -2, 6, 4), color)
	draw_rect(Rect2(3, -1, 2, 2), color)
