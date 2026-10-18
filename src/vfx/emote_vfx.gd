class_name EmoteVfx
extends Node2D
## Speech-bubble emote that pops above a character, then fades (e.g. "!" when a monster spots you).

const LIFETIME := 0.9

var _texture: Texture2D
var _age := 0.0


static func create(texture: Texture2D, at: Vector2) -> EmoteVfx:
	var vfx := EmoteVfx.new()
	vfx._texture = texture
	vfx.position = at
	vfx.z_index = 10
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var pop := 1.0 + 0.4 * maxf(1.0 - t * 8.0, 0.0)
	var size := _texture.get_size() * 2.0 * pop
	var color := Color(1, 1, 1, 1.0 - maxf(t - 0.7, 0.0) / 0.3)
	draw_texture_rect(_texture, Rect2(Vector2(-size.x * 0.5, -size.y - 4.0 * ease(t, 0.3)), size), false, color)
