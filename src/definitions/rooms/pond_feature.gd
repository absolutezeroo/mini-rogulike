class_name PondFeature
extends RoomFeature
## Water in the middle of the room (a HeatSourceDef with a pond, usually without heat): a flooded
## hall, a fountain... Of a random size, solid for walkers.

@export var pond: HeatSourceDef
@export var fill_min: Vector2 = Vector2(0.35, 0.35)
@export var fill_max: Vector2 = Vector2(0.6, 0.6)


func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	if pond == null:
		return
	var rng := world.rng
	var fill := Vector2(rng.randf_range(fill_min.x, fill_max.x), rng.randf_range(fill_min.y, fill_max.y))
	var cells := centered(room, fill, 2, Vector2i(2, 2), rng)
	if cells.size == Vector2i.ZERO or not HazardDef.is_free(world, cells, taken) or not stays_open(world, room, cells):
		return
	HazardDef.take_rect(taken, cells.grow(1))
	world.spawn_heat_source(pond, cells)
