class_name DungeonView
extends Node2D
## Draws a DungeonMap with the tiles of a DungeonTheme.
##   - floor cells: floor tiles plus a little decor
##   - walls with floor right below: cliff face
##   - walls touching the floor otherwise: plateau edge tiles, picked from which sides touch the floor
##   - every other wall: flat plateau color

const OUTSIDE_MARGIN := 24  # tiles of plateau color drawn around the map

var _map: DungeonMap
var _theme: DungeonTheme


func show_map(map: DungeonMap, theme: DungeonTheme) -> void:
	_map = map
	_theme = theme
	queue_redraw()


func _draw() -> void:
	if _map == null or _theme == null:
		return
	var ts := float(_map.tile_size)
	var tint := _theme.tint
	var outside := Rect2(Vector2.ONE * -OUTSIDE_MARGIN * ts, Vector2(_map.width + OUTSIDE_MARGIN * 2, _map.height + OUTSIDE_MARGIN * 2) * ts)
	draw_rect(outside, _theme.wall_top_color * tint)

	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * ts, Vector2(ts, ts))
			if _map.is_floor(cell):
				_draw_floor(cell, rect, tint)
			elif _is_face(cell):
				_draw_face(cell, rect, tint)
			elif _map.is_wall_edge(cell):
				_draw_tile(_theme.wall_atlas, _wall_top_tile(cell), rect, tint)


func _is_face(cell: Vector2i) -> bool:
	return not _map.is_floor(cell) and _map.is_floor(cell + Vector2i.DOWN)


## Floor or cliff face: the plateau looks down on it.
func _is_low(cell: Vector2i) -> bool:
	return _map.is_floor(cell) or _is_face(cell)


func _wall_top_tile(cell: Vector2i) -> int:
	var left := _is_low(cell + Vector2i.LEFT)
	var right := _is_low(cell + Vector2i.RIGHT)
	if _is_face(cell + Vector2i.DOWN):
		return _theme.wall_bottom_left if left else (_theme.wall_bottom_right if right else _theme.wall_bottom)
	if _map.is_floor(cell + Vector2i.UP):
		return _theme.wall_top_left if left else (_theme.wall_top_right if right else _theme.wall_top)
	if left:
		return _theme.wall_left
	if right:
		return _theme.wall_right
	return _theme.wall_center


func _draw_floor(cell: Vector2i, rect: Rect2, tint: Color) -> void:
	_draw_tile(_theme.floor_atlas, DungeonTheme.pick(_theme.floor_tiles, cell), rect, tint)
	if _theme.decor_atlas and DungeonTheme.chance(cell, _theme.decor_chance, 1):
		_draw_tile(_theme.decor_atlas, DungeonTheme.pick(_theme.decor_tiles, cell, 2), rect, tint)
	# Soft shadow at the foot of the cliffs.
	if _is_face(cell + Vector2i.UP):
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), Color(0, 0, 0, 0.22))


func _draw_face(cell: Vector2i, rect: Rect2, tint: Color) -> void:
	var tile := _theme.face
	if not _is_face(cell + Vector2i.LEFT):
		tile = _theme.face_left
	elif not _is_face(cell + Vector2i.RIGHT):
		tile = _theme.face_right
	_draw_tile(_theme.wall_atlas, tile, rect, tint)


func _draw_tile(atlas: Texture2D, index: int, rect: Rect2, tint: Color) -> void:
	if atlas and index >= 0:
		draw_texture_rect_region(atlas, rect, DungeonTheme.region(atlas, index), tint)
