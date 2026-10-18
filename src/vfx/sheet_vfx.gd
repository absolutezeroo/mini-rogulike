class_name SheetVfx
extends Node2D
## Plays a sprite sheet once (frames side by side, square by default) and frees itself.
## Used for slashes, explosions, smoke, magic circles...

const DEFAULT_FPS := 16.0

var _texture: Texture2D
var _frame_size := Vector2.ZERO
var _frame_count := 1
var _fps := DEFAULT_FPS
var _age := 0.0
var _modulate_color := Color.WHITE


## `rotation_angle` in radians; `size` multiplies the art (pixel art is drawn at 2x by default).
static func create(texture: Texture2D, at: Vector2, rotation_angle: float = 0.0, size: float = 2.0, fps: float = DEFAULT_FPS, frame_width: int = 0) -> SheetVfx:
	var vfx := SheetVfx.new()
	vfx._texture = texture
	var height := texture.get_height()
	var width := frame_width if frame_width > 0 else height
	vfx._frame_size = Vector2(width, height)
	vfx._frame_count = maxi(1, texture.get_width() / width)
	vfx._fps = fps
	vfx.position = at
	vfx.rotation = rotation_angle
	vfx.scale = Vector2(size, size)
	vfx.z_index = 5
	return vfx


func with_color(color: Color) -> SheetVfx:
	_modulate_color = color
	return self


func _process(delta: float) -> void:
	_age += delta
	if _age * _fps >= _frame_count:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var frame := mini(int(_age * _fps), _frame_count - 1)
	var source := Rect2(Vector2(frame * _frame_size.x, 0), _frame_size)
	draw_texture_rect_region(_texture, Rect2(-_frame_size * 0.5, _frame_size), source, _modulate_color)
