class_name PixelPortrait
extends Control
## A picture drawn at the largest whole scale that fits the control (a 38-pixel faceset at x2 in
## a 76-unit box, a 16-pixel icon at x4): pixel art never stretched between pixels. Optionally
## one cell of a sheet (`region`). A speaker's face in the DialogueBox and the codex's Voices.

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## The part of `texture` to draw (empty: all of it).
@export var region := Rect2():
	set(value):
		region = value
		queue_redraw()


func _init(side: float = 76.0) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The whole scale it is drawn at (0: nothing to draw).
func pixel_scale() -> int:
	var source := _source_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return 0
	return maxi(1, int(floorf(minf(size.x / source.x, size.y / source.y))))


func _draw() -> void:
	var factor := pixel_scale()
	if texture == null or factor <= 0:
		return
	var drawn := _source_size() * factor
	var at := ((size - drawn) * 0.5).floor()
	if region.has_area():
		draw_texture_rect_region(texture, Rect2(at, drawn), region)
	else:
		draw_texture_rect(texture, Rect2(at, drawn), false)


func _source_size() -> Vector2:
	if region.has_area():
		return region.size
	return texture.get_size() if texture else Vector2.ZERO
