class_name HazardDef
extends ContentDef
## Something nasty laid out in a room: spike traps, arrow slits, pits, crumbling floor, quicksand...
## Each kind knows how to lay itself out (place()). Every act lists the hazards of its floors
## (ActDef.hazards): `min_depth` and `spawn_weight` decide which ones show up.


## Lays out one group of this hazard in `room`. `taken` holds the cells already used
## (props, other hazards...): skip them and add the ones you use.
func place(_world: World, _room: Rect2i, _taken: Dictionary) -> void:
	pass


## Free cells deep inside the room (2 cells from its walls), so the way along the walls stays open.
static func inner_cells(world: World, room: Rect2i, taken: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var inner := room.grow(-2)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var cell := Vector2i(x, y)
			if world.map.is_floor(cell) and not taken.has(cell):
				cells.append(cell)
	return cells


## A free `size` rectangle deep inside the room, or an empty rect when there is no room for it.
static func find_free_rect(world: World, room: Rect2i, taken: Dictionary, size: Vector2i) -> Rect2i:
	var inner := room.grow(-2)
	if inner.size.x < size.x or inner.size.y < size.y:
		return Rect2i()
	for attempt in 12:
		var origin := Vector2i(
			world.rng.randi_range(inner.position.x, inner.end.x - size.x),
			world.rng.randi_range(inner.position.y, inner.end.y - size.y))
		var rect := Rect2i(origin, size)
		if _is_free(world, rect, taken):
			return rect
	return Rect2i()


static func _is_free(world: World, rect: Rect2i, taken: Dictionary) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if taken.has(cell) or not world.map.is_floor(cell):
				return false
	return true


static func take_rect(taken: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			taken[Vector2i(x, y)] = true
