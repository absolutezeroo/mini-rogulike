class_name DecorFeature
extends RoomFeature
## Little things on the floor nobody bumps into (bones, books, grass, flowers...): a random
## number, random kinds, random places on free floor. 16 px images, drawn at 2x.

@export var pieces: Array[Texture2D] = []
@export var count: Vector2i = Vector2i(3, 6)


func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	if pieces.is_empty():
		return
	var rng := world.rng
	var layer := DecorLayer.new()
	layer.z_index = -8
	var wanted := rng.randi_range(count.x, count.y)
	for attempt in wanted * 4:
		if layer.pieces.size() >= wanted:
			break
		var cell := world.map.random_cell_in(room, rng)
		if taken.has(cell) or world.nav.is_blocked(cell):
			continue
		var at := world.map.cell_to_world(cell) + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		layer.pieces.append([pieces[rng.randi() % pieces.size()], at.snapped(Vector2(2, 2))])
	world.spawn_vfx(layer)
