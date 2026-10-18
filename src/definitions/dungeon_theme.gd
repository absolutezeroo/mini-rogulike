class_name DungeonTheme
extends Resource
## Look of a floor: which tiles of the tileset to use, plus an overall tint.
## Tiles are referenced by index in the atlas (left to right, top to bottom, starting at 0).

@export var atlas: Texture2D
@export var tile_pixels: int = 16
@export var columns: int = 12
## Multiplies every tile: cheap way to make several themes from one tileset.
@export var tint: Color = Color.WHITE

@export_group("Floor")
@export var floor_tiles: PackedInt32Array = [48]
@export var floor_decor_tiles: PackedInt32Array = [49, 42]
@export_range(0.0, 1.0) var floor_decor_chance: float = 0.08

@export_group("Walls")
## Brick face of a wall seen from the south (a wall with floor right below it).
@export var wall_face_tiles: PackedInt32Array = [40]
@export var wall_face_decor_tiles: PackedInt32Array = [28, 14]
@export_range(0.0, 1.0) var wall_face_decor_chance: float = 0.1
## Flat color of the top of the walls (and of everything outside the rooms).
@export var wall_top_color: Color = Color(0.4627, 0.2314, 0.2118)
@export var wall_top_decor_tiles: PackedInt32Array = [12, 24]
@export_range(0.0, 1.0) var wall_top_decor_chance: float = 0.03
@export var wall_rim_color: Color = Color(0.7529, 0.7961, 0.8627)
@export var wall_outline_color: Color = Color(0.2471, 0.149, 0.1922)

@export_group("Objects")
@export var stairs_tile: int = 37


func region(index: int) -> Rect2:
	var x := index % columns
	var y := index / columns
	return Rect2(x * tile_pixels, y * tile_pixels, tile_pixels, tile_pixels)


func tile_texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region(index)
	return texture


## Stable pseudo-random pick for a cell, so redraws never shuffle the decor.
static func pick(tiles: PackedInt32Array, cell: Vector2i, salt: int = 0) -> int:
	if tiles.is_empty():
		return -1
	return tiles[absi(hash(Vector3i(cell.x, cell.y, salt))) % tiles.size()]


static func chance(cell: Vector2i, probability: float, salt: int = 0) -> bool:
	return float(absi(hash(Vector3i(cell.x, cell.y, salt + 7))) % 10000) / 10000.0 < probability
