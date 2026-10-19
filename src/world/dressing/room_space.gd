class_name RoomSpace
## Questions about the free floor of a room, asked before putting something in it.


## True if blocking `cells` (Dictionary of Vector2i) cuts no part of the room off: the free
## floor in and right around it stays in as many groups as before.
static func stays_open(world: World, room: Rect2i, cells: Dictionary) -> bool:
	return _groups(world, room, {}) >= _groups(world, room, cells)


## Free floor: not a wall, nothing standing on it.
static func is_free(world: World, cell: Vector2i) -> bool:
	return world.map.is_floor(cell) and not world.nav.is_blocked(cell)


## Groups of free floor cells (not in `blocked`) in and right around the room.
static func _groups(world: World, room: Rect2i, blocked: Dictionary) -> int:
	var bounds := room.grow(1)
	var seen := {}
	var groups := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or not _open(world, bounds, blocked, start):
				continue
			groups += 1
			seen[start] = true
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next := cell + dir
					if not seen.has(next) and _open(world, bounds, blocked, next):
						seen[next] = true
						queue.append(next)
	return groups


static func _open(world: World, bounds: Rect2i, blocked: Dictionary, cell: Vector2i) -> bool:
	return bounds.has_point(cell) and not blocked.has(cell) and is_free(world, cell)
