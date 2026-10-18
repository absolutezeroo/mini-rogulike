class_name DungeonTheme
extends Resource
## Look and music of a floor. Tiles are referenced by index in their atlas
## (left to right, top to bottom, starting at 0; 16x16 tiles).
##
## Walls use a "cliff" tileset: the top of the walls is a plateau with a rim,
## and walls that have floor right below them show a cliff face.

@export var tint: Color = Color.WHITE
@export var music: AudioStream

@export_group("Floor")
@export var floor_atlas: Texture2D
@export var floor_tiles: PackedInt32Array = []
@export var decor_atlas: Texture2D
@export var decor_tiles: PackedInt32Array = []
@export_range(0.0, 1.0) var decor_chance: float = 0.05

@export_group("Walls")
@export var wall_atlas: Texture2D
## Flat color of the plateau (wall tops far from the floor and everything outside the map).
@export var wall_top_color: Color = Color(1.0, 0.8, 0.55)
## Plateau edges, by side that touches the floor.
@export var wall_top_left: int = 101
@export var wall_top: int = 102
@export var wall_top_right: int = 103
@export var wall_left: int = 121
@export var wall_center: int = 122
@export var wall_right: int = 123
## Plateau edge above a cliff face (rim + top of the cliff).
@export var wall_bottom_left: int = 141
@export var wall_bottom: int = 142
@export var wall_bottom_right: int = 143
## Cliff face seen from the front (wall with floor right below it).
@export var face_left: int = 144
@export var face: int = 145
@export var face_right: int = 146

@export_group("Objects")
@export var stairs_atlas: Texture2D
@export var stairs_tile: int = 17


static func region(atlas: Texture2D, index: int) -> Rect2:
	var columns := int(atlas.get_width()) / 16
	return Rect2((index % columns) * 16, (index / columns) * 16, 16, 16)


func stairs_texture() -> AtlasTexture:
	if stairs_atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = stairs_atlas
	texture.region = region(stairs_atlas, stairs_tile)
	return texture


## Stable pseudo-random pick for a cell, so redraws never shuffle the decor.
static func pick(tiles: PackedInt32Array, cell: Vector2i, salt: int = 0) -> int:
	if tiles.is_empty():
		return -1
	return tiles[absi(hash(Vector3i(cell.x, cell.y, salt))) % tiles.size()]


static func chance(cell: Vector2i, probability: float, salt: int = 0) -> bool:
	return float(absi(hash(Vector3i(cell.x, cell.y, salt + 7))) % 10000) / 10000.0 < probability
