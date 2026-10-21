class_name FloatingText
extends Node2D
## Rising, fading text: damage numbers, heals, level ups.

const LIFETIME := 0.75
const RISE := 28.0
## The share of its life it shows at twice its size, before settling.
const POP_TIME := 0.08

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
	var color := _color
	color.a = 1.0 - maxf(t - 0.5, 0.0) * 2.0
	# Pops in at twice the size, then settles: whole sizes, so its pixels stay whole (Fonts).
	var font_size := Fonts.TITLE if t < POP_TIME else Fonts.BODY
	Fonts.draw(self, Vector2(0, -RISE * ease(t, 0.5)), _text, font_size, color, 0.5, Color(0.247, 0.149, 0.192, color.a))
