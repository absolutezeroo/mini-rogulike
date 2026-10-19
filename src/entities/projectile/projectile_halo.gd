class_name ProjectileHalo
extends Node2D
## The glow around a magic shot: a pulsing halo in its color, added onto what is behind it
## (so it shines even in bright rooms), in flat pixel rings.

var color := Color.WHITE
var size := 6.0

var _time := 0.0


func _ready() -> void:
	show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = add
	_time = randf() * 3.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_time * 18.0)
	draw_circle(Vector2.ZERO, snappedf(size * 1.9 * pulse, 2.0), Color(color, 0.08))
	draw_circle(Vector2.ZERO, snappedf(size * 1.3 * pulse, 2.0), Color(color, 0.12))
	draw_circle(Vector2.ZERO, snappedf(size * 0.7, 2.0), Color(color.lightened(0.5), 0.18))
