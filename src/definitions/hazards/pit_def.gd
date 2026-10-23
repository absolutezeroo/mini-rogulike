class_name PitDef
extends HazardDef
## A hole in the floor. Whatever walks or gets knocked into it falls: monsters are gone for good
## (the hero gets the XP if they pushed them), the hero climbs back out where they last stood
## safely, hurt. Rolling carries you over. Flying monsters don't care.
## With `crumble_time` above 0 it is cracked floor instead: it gives way under whoever stands
## on it, and becomes a hole.

## Holes in a 4x4 grid of 16x16 tiles: columns = left end, middle, right end, alone;
## rows = top, middle, bottom, alone.
@export var tileset: Texture2D
## Part of the hero's max HP lost in a fall.
@export_range(0.0, 1.0, 0.01) var fall_damage: float = 0.15
## Size of a group of holes, in cells (random between the two).
@export var size_min: Vector2i = Vector2i(2, 2)
@export var size_max: Vector2i = Vector2i(3, 3)

@export_group("Crumbling floor")
## Seconds the floor holds once someone stands on it. 0 = an open hole from the start.
@export var crumble_time: float = 0.0
## Cracks drawn over the floor (16x16), so a careful eye can spot it.
@export var crack_texture: Texture2D
@export var crack_sound: AudioStream
@export var crumble_sound: AudioStream
@export var debris_color: Color = Color(0.45, 0.38, 0.32)


func is_crumbling() -> bool:
	return crumble_time > 0.0


func place(world: World, room: Rect2i, taken: Dictionary) -> void:
	var size := Vector2i(
		world.rng.randi_range(size_min.x, size_max.x),
		world.rng.randi_range(size_min.y, size_max.y))
	var rect := find_free_rect(world, room, taken, size)
	if rect.size == Vector2i.ZERO:
		return
	var cells: Array[Vector2i] = []
	var blocked := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
			blocked[Vector2i(x, y)] = true
	# Never cut the room in two (a ring round a rock, a ledge round a chasm: RoomShapeDef).
	if not RoomSpace.stays_open(world, room, blocked):
		return
	# Never cut the stairs off (even once cracked floor has given way).
	for cell in cells:
		world.set_cell_blocked(cell, true)
	var blocks_the_way := world.map.exit_cells().any(func(exit: Vector2i) -> bool:
		return world.find_path(world.map.cell_to_world(world.map.start_cell), world.map.cell_to_world(exit)).is_empty())
	for cell in cells:
		world.set_cell_blocked(cell, false)
	if blocks_the_way:
		return
	take_rect(taken, rect)
	for cell in cells:
		if is_crumbling():
			world.spawn_crumbling_floor(self, cell)
		else:
			world.add_pit(cell, self)
