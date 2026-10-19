class_name DecorLayer
extends Node2D
## Little pieces of decor drawn at 2x (grass, flowers, logs, stones...): [texture, offset] each.
## Nothing to collide with, nothing to animate: drawn once.

var pieces: Array = []


func _draw() -> void:
	for piece: Array in pieces:
		var texture: Texture2D = piece[0]
		var size := texture.get_size() * 2.0
		draw_texture_rect(texture, Rect2(piece[1] - size * 0.5, size), false)
