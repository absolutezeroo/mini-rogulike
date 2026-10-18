class_name DungeonView
extends Node2D
## Draws a DungeonMap with the tiles of a DungeonTheme.
##   - floor cells: floor tiles, with some decor
##   - walls with floor just below: brick "face" tiles (we see them from the front)
##   - every other wall: flat top color, with a stone rim where it meets the floor

const RIM := 6.0       # light stone rim thickness, in pixels
const OUTLINE := 2.0   # dark outline thickness
const OUTSIDE_MARGIN := 24  # tiles of wall color drawn around the map

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
				_draw_wall_top(cell, rect, tint)


func _is_face(cell: Vector2i) -> bool:
	return not _map.is_floor(cell) and _map.is_floor(cell + Vector2i.DOWN)


func _draw_floor(cell: Vector2i, rect: Rect2, tint: Color) -> void:
	var tile := DungeonTheme.pick(_theme.floor_tiles, cell)
	if DungeonTheme.chance(cell, _theme.floor_decor_chance):
		tile = DungeonTheme.pick(_theme.floor_decor_tiles, cell, 1)
	_draw_tile(tile, rect, tint)
	# Soft shadow under the walls above.
	if not _map.is_floor(cell + Vector2i.UP):
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color(0, 0, 0, 0.18))


func _draw_face(cell: Vector2i, rect: Rect2, tint: Color) -> void:
	var tile := DungeonTheme.pick(_theme.wall_face_tiles, cell)
	if DungeonTheme.chance(cell, _theme.wall_face_decor_chance, 2):
		tile = DungeonTheme.pick(_theme.wall_face_decor_tiles, cell, 3)
	_draw_tile(tile, rect, tint)
	var outline := _theme.wall_outline_color * tint
	if _map.is_floor(cell + Vector2i.LEFT):
		draw_rect(Rect2(rect.position, Vector2(OUTLINE, rect.size.y)), outline)
	if _map.is_floor(cell + Vector2i.RIGHT):
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - OUTLINE, 0), Vector2(OUTLINE, rect.size.y)), outline)
	# A wall face standing alone (nothing above): give it a rim on top.
	if not _is_wall_top(cell + Vector2i.UP):
		_draw_rim(rect, Vector2i.UP, tint)


func _draw_wall_top(cell: Vector2i, rect: Rect2, tint: Color) -> void:
	if DungeonTheme.chance(cell, _theme.wall_top_decor_chance, 4):
		_draw_tile(DungeonTheme.pick(_theme.wall_top_decor_tiles, cell, 5), rect, tint)
	# Rim on every side that looks down onto the floor or onto a wall face.
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell + side
		if _map.is_floor(neighbor) or _is_face(neighbor):
			_draw_rim(rect, side, tint)


func _is_wall_top(cell: Vector2i) -> bool:
	return _map.in_bounds(cell) and not _map.is_floor(cell) and not _is_face(cell)


## Light stone band along one side of a cell, with a dark outline on the outer edge.
func _draw_rim(rect: Rect2, side: Vector2i, tint: Color) -> void:
	var rim := _theme.wall_rim_color * tint
	var outline := _theme.wall_outline_color * tint
	var p := rect.position
	var s := rect.size
	match side:
		Vector2i.DOWN:
			draw_rect(Rect2(p + Vector2(0, s.y - RIM - OUTLINE), Vector2(s.x, RIM)), rim)
			draw_rect(Rect2(p + Vector2(0, s.y - OUTLINE), Vector2(s.x, OUTLINE)), outline)
		Vector2i.UP:
			draw_rect(Rect2(p + Vector2(0, OUTLINE), Vector2(s.x, RIM)), rim)
			draw_rect(Rect2(p, Vector2(s.x, OUTLINE)), outline)
		Vector2i.LEFT:
			draw_rect(Rect2(p + Vector2(OUTLINE, 0), Vector2(RIM, s.y)), rim)
			draw_rect(Rect2(p, Vector2(OUTLINE, s.y)), outline)
		Vector2i.RIGHT:
			draw_rect(Rect2(p + Vector2(s.x - RIM - OUTLINE, 0), Vector2(RIM, s.y)), rim)
			draw_rect(Rect2(p + Vector2(s.x - OUTLINE, 0), Vector2(OUTLINE, s.y)), outline)


func _draw_tile(index: int, rect: Rect2, tint: Color) -> void:
	if index >= 0:
		draw_texture_rect_region(_theme.atlas, rect, _theme.region(index), tint)
