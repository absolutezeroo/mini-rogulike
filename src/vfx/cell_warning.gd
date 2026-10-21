class_name CellWarning
extends Node2D
## Cells about to change (a boss arena shifting): they blink red, faster and faster, then the
## warning is gone and the change happens.

var _cells: Array[Vector2i] = []
var _tile := 32.0
var _duration := 1.4
var _age := 0.0


static func create(cells: Array[Vector2i], tile_size: int, duration: float) -> CellWarning:
	var warning := CellWarning.new()
	warning._cells = cells
	warning._tile = float(tile_size)
	warning._duration = duration
	VfxLayer.apply(warning, VfxLayer.Layer.GROUND)  # on the floor, under whoever stands there
	return warning


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / _duration
	# Blinks faster as the change comes.
	var blink := 0.5 + 0.5 * sin(_age * lerpf(8.0, 30.0, t))
	var fill := Color(1.0, 0.15, 0.1, (0.18 + 0.22 * blink) * minf(1.0, _age * 6.0))
	var edge := Color(1.0, 0.4, 0.3, 0.55 * blink)
	for cell in _cells:
		var rect := Rect2(Vector2(cell) * _tile + Vector2.ONE * 2.0, Vector2.ONE * (_tile - 4.0))
		draw_rect(rect, fill)
		draw_rect(rect, edge, false, 2.0)
