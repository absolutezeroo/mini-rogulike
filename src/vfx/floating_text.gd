class_name FloatingText
extends Node2D
## Rising, fading text: damage numbers, heals, level ups.

const LIFETIME := 0.75
const RISE := 28.0
const FONT_SIZE := 16

var _text := ""
var _color := Color.WHITE
var _age := 0.0


static func create(at: Vector2, text: String, color: Color) -> FloatingText:
	var vfx := FloatingText.new()
	vfx.position = at + Vector2(randf_range(-6.0, 6.0), 0.0)
	vfx._text = text
	vfx._color = color
	vfx.z_index = 10
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := Vector2(-width * 0.5, -RISE * ease(t, 0.5))
	var color := _color
	color.a = 1.0 - maxf(t - 0.5, 0.0) * 2.0
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, color.a))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
