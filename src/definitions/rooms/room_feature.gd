class_name RoomFeature
extends Resource
## One part of a themed room (RoomTemplateDef): pillars, a floor pattern, a pond, furniture,
## decor. Never block the way: keep the room's ring along its walls free, and corridor mouths.


## Once the floor is built: spawns what it needs. Skip the cells in `taken`, add the ones used.
func furnish(_world: World, _room: Rect2i, _taken: Dictionary) -> void:
	pass


## True if blocking `area` cuts no part of the room off (no pocket of floor nobody can reach):
## the free cells around stay in as many groups as before.
static func stays_open(world: World, room: Rect2i, area: Rect2i) -> bool:
	return _groups(world, room, Rect2i()) >= _groups(world, room, area)


## Groups of free floor cells (not blocked, not in `area`) in and right around the room.
static func _groups(world: World, room: Rect2i, area: Rect2i) -> int:
	var bounds := room.grow(1)
	var seen := {}
	var groups := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or not _free(world, bounds, area, start):
				continue
			groups += 1
			seen[start] = true
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next := cell + dir
					if not seen.has(next) and _free(world, bounds, area, next):
						seen[next] = true
						queue.append(next)
	return groups


static func _free(world: World, bounds: Rect2i, area: Rect2i, cell: Vector2i) -> bool:
	return bounds.has_point(cell) and not area.has_point(cell) and world.map.is_floor(cell) and not world.nav.is_blocked(cell)


## Cells of the room at least `margin` cells from its walls.
static func inner(room: Rect2i, margin: int) -> Rect2i:
	return room.grow(-margin)


## A rect of `fill` of the room's inner part, centered (at least `minimum` cells), a little
## off-center now and then (`off_center_chance`).
static func centered(room: Rect2i, fill: Vector2, margin: int, minimum: Vector2i, rng: RandomNumberGenerator, off_center_chance := 0.4) -> Rect2i:
	var space := room.grow(-margin)
	var size := Vector2i(maxi(minimum.x, roundi(space.size.x * fill.x)), maxi(minimum.y, roundi(space.size.y * fill.y)))
	size = size.min(space.size)
	if size.x <= 0 or size.y <= 0:
		return Rect2i()
	var slack := space.size - size
	var shift := Vector2i(rng.randi_range(0, slack.x), rng.randi_range(0, slack.y)) if rng.randf() < off_center_chance else slack / 2
	return Rect2i(space.position + shift, size)
