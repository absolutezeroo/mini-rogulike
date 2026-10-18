class_name DungeonView
extends Node2D
## Draws a DungeonMap with plain shapes. Swap for a TileMapLayer once you have a tileset.

const PALETTES: Array[Dictionary] = [
	{ "floor": Color("2b2b3a"), "floor_alt": Color("272735"), "wall": Color("6e5a46"), "wall_top": Color("8f7759") },
	{ "floor": Color("24333a"), "floor_alt": Color("212e35"), "wall": Color("4a5d63"), "wall_top": Color("67808a") },
	{ "floor": Color("3a2626"), "floor_alt": Color("352222"), "wall": Color("6b3a35"), "wall_top": Color("8c4f47") },
	{ "floor": Color("2a2438"), "floor_alt": Color("262033"), "wall": Color("4e3f6b"), "wall_top": Color("6a578f") },
]

var _map: DungeonMap
var _palette: Dictionary = PALETTES[0]


func show_map(map: DungeonMap, depth: int) -> void:
	_map = map
	_palette = PALETTES[(depth - 1) % PALETTES.size()]
	queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	var ts := float(_map.tile_size)
	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * ts, Vector2(ts, ts))
			if _map.is_floor(cell):
				draw_rect(rect, _palette.floor if (x + y) % 2 == 0 else _palette.floor_alt)
			elif _map.is_wall_edge(cell):
				draw_rect(rect, _palette.wall)
				draw_rect(Rect2(rect.position, Vector2(ts, ts * 0.25)), _palette.wall_top)
