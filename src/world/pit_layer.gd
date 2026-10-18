class_name PitLayer
extends Node2D
## Draws the holes of the floor (see PitDef), picking each cell's tile from its neighbours
## so a group of holes reads as one big hole with edges all around.

var _pits := {}  # Vector2i -> PitDef
var _tile_size := 32.0


func setup(tile_size: int) -> void:
	_tile_size = tile_size
	clear()


func clear() -> void:
	_pits.clear()
	queue_redraw()


func add(cell: Vector2i, def: PitDef) -> void:
	_pits[cell] = def
	queue_redraw()


func get_def(cell: Vector2i) -> PitDef:
	return _pits.get(cell)


func has(cell: Vector2i) -> bool:
	return _pits.has(cell)


func cells() -> Array:
	return _pits.keys()


func _draw() -> void:
	for cell: Vector2i in _pits:
		var def: PitDef = _pits[cell]
		if def.tileset == null:
			draw_rect(Rect2(Vector2(cell) * _tile_size, Vector2.ONE * _tile_size), Color("120d12"))
			continue
		var column := _end_index(has(cell + Vector2i.LEFT), has(cell + Vector2i.RIGHT))
		var row := _end_index(has(cell + Vector2i.UP), has(cell + Vector2i.DOWN))
		var source := Rect2(column * 16, row * 16, 16, 16)
		draw_texture_rect_region(def.tileset, Rect2(Vector2(cell) * _tile_size, Vector2.ONE * _tile_size), source)


## 0 = first of a row (nothing before), 1 = middle, 2 = last, 3 = alone.
static func _end_index(before: bool, after: bool) -> int:
	if before and after:
		return 1
	if after:
		return 0
	if before:
		return 2
	return 3
