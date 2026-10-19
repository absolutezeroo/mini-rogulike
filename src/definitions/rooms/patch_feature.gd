class_name PatchFeature
extends RoomFeature
## A different floor over part of the room: framed tiles (3x3 tiles of 16 px, corners, edges
## and middle, stretched to the size), or a rough blob of color (grass...). Just a look.

## The 3x3 tiles: `tiles` texture, `region` the 48x48 block in it. Empty = a blob of `color`.
@export var tiles: Texture2D
@export var region: Rect2i = Rect2i(0, 0, 48, 48)
@export var color: Color = Color(0.68, 0.74, 0.23)
## Part of the room's inner space covered (random between the two), centered or nearly.
@export var fill_min: Vector2 = Vector2(0.5, 0.5)
@export var fill_max: Vector2 = Vector2(0.8, 0.8)
@export_range(0, 3) var margin: int = 1
## Chance to be a little off-center (0: always right in the middle, around a shrine's statue).
@export_range(0.0, 1.0) var off_center_chance: float = 0.4
## Keeps hazards, chests and the like off it (a shrine's floor), not just a look.
@export var reserve: bool = false


func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	var rng := world.rng
	var fill := Vector2(rng.randf_range(fill_min.x, fill_max.x), rng.randf_range(fill_min.y, fill_max.y))
	var cells := centered(room, fill, margin, Vector2i(2, 2), rng, off_center_chance)
	if cells.size == Vector2i.ZERO:
		return
	world.spawn_floor_patch(self, cells)
	if reserve:
		HazardDef.take_rect(taken, cells)
