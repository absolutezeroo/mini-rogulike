class_name AfterimageVfx
extends Node2D
## Fading copy of a sprite, left behind while dashing.

const LIFETIME := 0.22

var _texture: Texture2D
var _rect: Rect2
var _flip := 1.0
var _color := Color.WHITE
var _age := 0.0


static func create(at: Vector2, texture: Texture2D, rect: Rect2, flip: float, color: Color) -> AfterimageVfx:
	var vfx := AfterimageVfx.new()
	vfx.position = at
	vfx._texture = texture
	vfx._rect = rect
	vfx._flip = flip
	vfx._color = color
	vfx.z_index = -1
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var color := _color
	color.a *= 0.55 * (1.0 - _age / LIFETIME)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_flip, 1.0))
	draw_texture_rect(_texture, _rect, false, color)
