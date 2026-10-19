class_name BeamVfx
extends Node2D
## A thin beam of light between two points (a mender healing an ally...), in art pixels,
## thinning out as it fades.

const LIFETIME := 0.35

var _to := Vector2.ZERO
var _color := Color.WHITE
var _age := 0.0


static func create(from: Vector2, to: Vector2, color: Color) -> BeamVfx:
	var vfx := BeamVfx.new()
	vfx.position = from
	vfx._to = to - from
	vfx._color = color
	vfx.z_index = 6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	vfx.material = add
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var steps := maxi(int(_to.length() / 4.0), 1)
	for i in steps + 1:
		var at := (_to * float(i) / steps).snapped(Vector2(2, 2))
		var wobble := Vector2(0, roundf(sin(i * 0.9 + _age * 30.0) * 1.0) * 2.0)
		var size := 4.0 if t < 0.5 else 2.0
		draw_rect(Rect2(at + wobble - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(_color, 0.85 * (1.0 - t)))
