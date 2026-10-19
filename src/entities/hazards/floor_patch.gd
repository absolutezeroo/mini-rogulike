class_name FloorPatch
extends Node2D
## A different floor over a few cells (PatchFeature): framed tiles, or a rough blob of color.
## Just a look, on the ground under everything.

var feature: PatchFeature
var rect := Rect2i()

var _area := Rect2()
var _cell_size := 32.0
## Blob circles: [x, y, radius].
var _blobs: Array[Vector3] = []


func setup(patch: PatchFeature, world: World, cells: Rect2i) -> void:
	feature = patch
	rect = cells
	_cell_size = float(world.map.tile_size)
	position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * _cell_size
	_area = Rect2(-Vector2(rect.size) * _cell_size * 0.5, Vector2(rect.size) * _cell_size)
	z_index = -9
	if patch.tiles == null:
		# A rough blob: circles over the cells, of random sizes, pushed out a little.
		for y in rect.size.y:
			for x in rect.size.x:
				var at := _area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell_size
				at += Vector2(world.rng.randf_range(-6.0, 6.0), world.rng.randf_range(-6.0, 6.0))
				_blobs.append(Vector3(at.x, at.y, _cell_size * world.rng.randf_range(0.6, 0.95)))


func _draw() -> void:
	if feature.tiles:
		NineSlice.draw(self, feature.tiles, feature.region, _area, rect.size, _cell_size)
		return
	for blob in _blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z, feature.color.darkened(0.2))
	for blob in _blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z - 3.0, feature.color)
