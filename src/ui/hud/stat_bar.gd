class_name StatBar
extends Control
## Simple rounded bar with a centered text (HP, XP...).

@export var fill_color := Color("ef476f")
@export var back_color := Color(0, 0, 0, 0.55)
@export var show_text := true

var _value := 1.0
var _max_value := 1.0
var _text := ""


func set_values(value: float, max_value: float, text: String = "") -> void:
	_value = value
	_max_value = maxf(max_value, 0.001)
	_text = text
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ratio := clampf(_value / _max_value, 0.0, 1.0)
	_draw_rounded(rect, back_color)
	if ratio > 0.0:
		_draw_rounded(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill_color)
	if show_text and not _text.is_empty():
		var font := get_theme_default_font()
		var font_size := roundi(size.y * 0.7)
		var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) * 0.5, (size.y + font_size * 0.7) * 0.5)
		draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
		draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_rounded(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(minf(rect.size.y * 0.5, 8.0)))
	draw_style_box(style, rect)
