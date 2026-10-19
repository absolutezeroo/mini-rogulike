class_name FloorPatch
extends Node2D
## A framed floor over a few cells (a carpet, a mosaic...): 3x3 tiles (corners, edges, middle)
## stretched to the size. Just a look, on the ground under everything.

var texture: Texture2D
var region := Rect2i(0, 0, 48, 48)
var rect := Rect2i()

var _area := Rect2()
var _cell_size := 32.0


func setup(tiles: Texture2D, tiles_region: Rect2i, world: World, cells: Rect2i) -> void:
	texture = tiles
	region = tiles_region
	rect = cells
	_cell_size = float(world.map.tile_size)
	position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * _cell_size
	_area = Rect2(-Vector2(rect.size) * _cell_size * 0.5, Vector2(rect.size) * _cell_size)
	z_index = -9


func _draw() -> void:
	if texture:
		NineSlice.draw(self, texture, region, _area, rect.size, _cell_size)
