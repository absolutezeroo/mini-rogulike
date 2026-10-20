class_name FogOfWar
extends RefCounted
## What the hero has seen of the current floor (for the minimap): the room they stand in, all
## of it, and a few cells around them.

## How far around the hero corridors are revealed, in cells.
const REVEAL_RADIUS := 3

## 1 for every cell seen.
var explored := PackedByteArray()

var _map: DungeonMap
var _last := Vector2i(-1, -1)


func reset(map: DungeonMap) -> void:
	_map = map
	explored = PackedByteArray()
	explored.resize(map.width * map.height)
	_last = Vector2i(-1, -1)


func is_explored(cell: Vector2i) -> bool:
	return _map.in_bounds(cell) and explored[cell.y * _map.width + cell.x] == 1


## Everything seen at once (debug); returns the cells seen for the first time.
func reveal_all() -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	return _reveal_rect(Rect2i(0, 0, _map.width, _map.height), revealed)


## Reveals `rect`; returns the cells seen for the first time.
func reveal_rect(rect: Rect2i) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	return _reveal_rect(rect, revealed)


## Reveals around `point`; returns the cells seen for the first time.
func reveal_around(point: Vector2) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	var cell := _map.world_to_cell(point)
	if cell == _last or not _map.in_bounds(cell):
		return revealed
	_last = cell
	for room in _map.rooms:
		if room.has_point(cell):
			_reveal_rect(room.grow(1), revealed)
	_reveal_rect(Rect2i(cell - Vector2i.ONE * REVEAL_RADIUS, Vector2i.ONE * (REVEAL_RADIUS * 2 + 1)), revealed)
	return revealed


func _reveal_rect(rect: Rect2i, revealed: Array[Vector2i]) -> Array[Vector2i]:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if _map.in_bounds(cell) and explored[y * _map.width + x] == 0:
				explored[y * _map.width + x] = 1
				revealed.append(cell)
	return revealed
