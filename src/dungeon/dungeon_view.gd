class_name DungeonView
extends Node2D
## Draws a DungeonMap with the tiles of a DungeonTheme.
##   - floor cells: floor tiles plus a little decor
##   - walls with floor right below: cliff face
##   - walls next to the floor or a cliff face (8 neighbours): plateau edge tiles, picked from
##     which sides are lower, with inner corners for diagonals
##   - every other wall: flat plateau color
## The map is drawn in square chunks, each its own canvas item: the ones off screen are skipped
## by the renderer (a single item for the whole map was drawn whole every frame). Inside a chunk,
## tiles go by texture (floor, decor, shadows, walls) so they batch into a few draw calls.
## Over it all, the plateau's mist (PlateauMist).

const OUTSIDE_MARGIN := 24  # tiles of plateau color drawn around the map
## Cells on a chunk's side.
const CHUNK := 8

var _map: DungeonMap
var _theme: DungeonTheme
var _chunks: Array[Chunk] = []
## Over the chunks: the mist on the plateau.
var mist := PlateauMist.new()


## One square of the map, drawn by the view.
class Chunk:
	extends Node2D
	var view: DungeonView
	var cells: Rect2i

	func _draw() -> void:
		view.draw_cells(self, cells)


func show_map(map: DungeonMap, theme: DungeonTheme) -> void:
	_map = map
	_theme = theme
	for chunk in _chunks:
		remove_child(chunk)
		chunk.queue_free()
	_chunks.clear()
	for y in range(0, map.height, CHUNK):
		for x in range(0, map.width, CHUNK):
			var chunk := Chunk.new()
			chunk.view = self
			chunk.cells = Rect2i(x, y, mini(CHUNK, map.width - x), mini(CHUNK, map.height - y))
			chunk.name = "Chunk_%d_%d" % [x / CHUNK, y / CHUNK]
			add_child(chunk)
			_chunks.append(chunk)
	if mist.get_parent() == null:
		mist.name = "Mist"
		add_child(mist)
	move_child(mist, -1)
	mist.setup(map, theme, OUTSIDE_MARGIN)
	queue_redraw()


## Cells of `area` changed (a secret room opened): their chunks and the mist are drawn again.
func refresh(area: Rect2i) -> void:
	var around := area.grow(2)
	for chunk in _chunks:
		if chunk.cells.intersects(around):
			chunk.queue_redraw()
	mist.setup(_map, _theme, OUTSIDE_MARGIN)


func chunk_count() -> int:
	return _chunks.size()


## The plateau color all around (under the chunks).
func _draw() -> void:
	if _map == null or _theme == null:
		return
	var ts := float(_map.tile_size)
	var outside := Rect2(Vector2.ONE * -OUTSIDE_MARGIN * ts, Vector2(_map.width + OUTSIDE_MARGIN * 2, _map.height + OUTSIDE_MARGIN * 2) * ts)
	draw_rect(outside, _theme.wall_top_color * _theme.tint)


## Draws the cells of `area` on `canvas` (a chunk): one pass per texture.
func draw_cells(canvas: CanvasItem, area: Rect2i) -> void:
	if _map == null or _theme == null:
		return
	var ts := float(_map.tile_size)
	var tint := _theme.tint
	for pass_index in 4:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				var rect := Rect2(Vector2(cell) * ts, Vector2(ts, ts))
				var is_floor := _map.is_floor(cell)
				match pass_index:
					0:
						if is_floor:
							_draw_tile(canvas, _theme.floor_atlas, DungeonTheme.pick(_theme.floor_tiles, cell), rect, tint)
					1:
						if is_floor and _theme.decor_atlas and DungeonTheme.chance(cell, _theme.decor_chance, 1):
							_draw_tile(canvas, _theme.decor_atlas, DungeonTheme.pick(_theme.decor_tiles, cell, 2), rect, tint)
					2:
						# Soft shadow at the foot of the cliffs.
						if is_floor and _is_face(cell + Vector2i.UP):
							canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), Color(0, 0, 0, 0.22))
					3:
						if is_floor:
							continue
						if _is_face(cell):
							_draw_face(canvas, cell, rect, tint)
						elif _touches_low(cell):
							_draw_tile(canvas, _theme.wall_atlas, _wall_top_tile(cell), rect, tint)


func _is_face(cell: Vector2i) -> bool:
	return not _map.is_floor(cell) and _map.is_floor(cell + Vector2i.DOWN)


## Floor or cliff face: the plateau looks down on it.
func _is_low(cell: Vector2i) -> bool:
	return _map.is_floor(cell) or _is_face(cell)


func _touches_low(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _is_low(cell + Vector2i(dx, dy)):
				return true
	return false


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
	return _inner_corner_tile(cell)


## Plateau cell whose only lower neighbours are diagonal: a small rim in that corner.
func _inner_corner_tile(cell: Vector2i) -> int:
	var up_left := _is_low(cell + Vector2i(-1, -1))
	var up_right := _is_low(cell + Vector2i(1, -1))
	var down_left := _is_low(cell + Vector2i(-1, 1))
	var down_right := _is_low(cell + Vector2i(1, 1))
	if up_left and up_right:
		return _theme.inner_top
	if down_left and down_right:
		return _theme.inner_bottom
	if up_left:
		return _theme.inner_top_left
	if up_right:
		return _theme.inner_top_right
	if down_left:
		return _theme.inner_bottom_left
	if down_right:
		return _theme.inner_bottom_right
	return _theme.wall_center


func _draw_face(canvas: CanvasItem, cell: Vector2i, rect: Rect2, tint: Color) -> void:
	var left_open := not _is_face(cell + Vector2i.LEFT)
	var right_open := not _is_face(cell + Vector2i.RIGHT)
	var tile := _theme.face
	if left_open and right_open:
		tile = _theme.face_single
	elif left_open:
		tile = _theme.face_left
	elif right_open:
		tile = _theme.face_right
	_draw_tile(canvas, _theme.wall_atlas, tile, rect, tint)


func _draw_tile(canvas: CanvasItem, atlas: Texture2D, index: int, rect: Rect2, tint: Color) -> void:
	if atlas and index >= 0:
		canvas.draw_texture_rect_region(atlas, rect, DungeonTheme.region(atlas, index), tint)
