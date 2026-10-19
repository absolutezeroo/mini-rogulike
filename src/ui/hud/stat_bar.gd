class_name StatBar
extends Control
## Pixel-art bar with a centered text (HP, XP...).

@export var fill_color := Palette.BLOOD
@export var show_text := true
@export var font_size := 16

var _value := 1.0
var _max_value := 1.0
var _text := ""
var _frame: StyleBoxTexture


func _ready() -> void:
	_frame = StyleBoxTexture.new()
	_frame.texture = preload("res://assets/ui/wood/nine_path_bg.png")
	_frame.set_texture_margin_all(9)


func set_values(value: float, max_value: float, text: String = "") -> void:
	if value == _value and maxf(max_value, 0.001) == _max_value and text == _text:
		return
	_value = value
	_max_value = maxf(max_value, 0.001)
	_text = text
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_frame, rect)
	var inner := rect.grow(-4.0)
	var ratio := clampf(_value / _max_value, 0.0, 1.0)
	if ratio > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
		draw_rect(fill, fill_color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2.0)), fill_color.lightened(0.35))
		draw_rect(Rect2(fill.position + Vector2(0, fill.size.y - 2.0), Vector2(fill.size.x, 2.0)), fill_color.darkened(0.3))
	if show_text and not _text.is_empty():
		var font := Fonts.MAIN
		var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) * 0.5, (size.y + font_size * 0.7) * 0.5)
		draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Palette.INK)
		draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
