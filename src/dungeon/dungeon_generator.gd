class_name DungeonGenerator
## Builds a DungeonMap: random non-overlapping rooms chained by wide corridors.
## Each room connects to the previous one, so every room is reachable.


static func generate(config: DungeonConfig, rng: RandomNumberGenerator) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)

	for attempt in config.max_rooms * 12:
		if map.rooms.size() >= config.max_rooms:
			break
		var size := Vector2i(
			rng.randi_range(config.room_min_size, config.room_max_size),
			rng.randi_range(config.room_min_size, config.room_max_size))
		var room := Rect2i(
			Vector2i(rng.randi_range(2, config.width - size.x - 2), rng.randi_range(2, config.height - size.y - 2)),
			size)
		if _overlaps_any(room, map.rooms):
			continue

		_carve_rect(map, room)
		if not map.rooms.is_empty():
			_carve_corridor(map, map.rooms.back().get_center(), room.get_center(), config.corridor_width, rng)
		map.rooms.append(room)

	smooth(map)
	map.start_cell = map.rooms[0].get_center()
	map.stairs_cell = _farthest_room(map).get_center()
	return map


## Boss floor: a small start room and one big arena, joined by a single corridor
## (so the arena has only one entrance to close). The stairs appear in the arena later.
static func generate_arena(config: DungeonConfig, rng: RandomNumberGenerator) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)
	var arena_size := config.arena_size
	var arena := Rect2i(
		Vector2i(config.width - arena_size.x - rng.randi_range(4, 8), (config.height - arena_size.y) / 2 + rng.randi_range(-6, 6)),
		arena_size)
	var start := Rect2i(Vector2i(rng.randi_range(4, 8), arena.get_center().y - 3 + rng.randi_range(-8, 8)), Vector2i(7, 7))
	_carve_rect(map, start)
	_carve_rect(map, arena)
	_carve_corridor(map, start.get_center(), arena.get_center(), config.corridor_width, rng)
	smooth(map)
	map.rooms.append(start)
	map.rooms.append(arena)
	map.boss_room = arena
	map.start_cell = start.get_center()
	map.stairs_cell = arena.get_center()
	return map


## Walls between two floors thinner than this (in cells, across or along) read as flimsy
## fences, not rock: they are opened up.
const MIN_WALL_THICKNESS := 3


## Removes wall shapes the cliff tiles can't draw or that look wrong: walls thinner than
## MIN_WALL_THICKNESS with floor on both sides, and walls touching each other only by a corner
## (checkerboard). They become floor. The outer border always stays solid.
static func smooth(map: DungeonMap) -> void:
	var changed := true
	while changed:
		changed = false
		for y in range(1, map.height - 1):
			for x in range(1, map.width - 1):
				var cell := Vector2i(x, y)
				if map.is_floor(cell):
					continue
				if is_thin_wall(map, cell, Vector2i.RIGHT) or is_thin_wall(map, cell, Vector2i.DOWN) or _is_pinch(map, cell):
					map.set_floor(cell)
					changed = true


## Wall cell in a run of walls (along `axis`) with floor at both ends, shorter than
## MIN_WALL_THICKNESS.
static func is_thin_wall(map: DungeonMap, cell: Vector2i, axis: Vector2i) -> bool:
	var run := 1
	for direction: Vector2i in [axis, -axis]:
		var next := cell + direction
		while not map.is_floor(next):
			if not map.in_bounds(next) or run >= MIN_WALL_THICKNESS:
				return false  # the border, or thick enough
			run += 1
			next += direction
	return run < MIN_WALL_THICKNESS


## Wall cell whose diagonal neighbour is a wall while both cells between them are floor.
static func _is_pinch(map: DungeonMap, cell: Vector2i) -> bool:
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			var diagonal := cell + Vector2i(dx, dy)
			if not map.is_floor(diagonal) and map.is_floor(cell + Vector2i(dx, 0)) and map.is_floor(cell + Vector2i(0, dy)):
				return true
	return false


static func _overlaps_any(room: Rect2i, rooms: Array[Rect2i]) -> bool:
	for other in rooms:
		if room.grow(2).intersects(other):
			return true
	return false


static func _carve_rect(map: DungeonMap, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			map.set_floor(Vector2i(x, y))


## L-shaped corridor: horizontal then vertical, or the other way round.
static func _carve_corridor(map: DungeonMap, from: Vector2i, to: Vector2i, corridor_width: int, rng: RandomNumberGenerator) -> void:
	var corner := Vector2i(to.x, from.y) if rng.randf() < 0.5 else Vector2i(from.x, to.y)
	_carve_line(map, from, corner, corridor_width)
	_carve_line(map, corner, to, corridor_width)


static func _carve_line(map: DungeonMap, from: Vector2i, to: Vector2i, corridor_width: int) -> void:
	var step := (to - from).sign()
	var low := -floori(corridor_width / 2.0)
	var high := low + corridor_width
	var cell := from
	while true:
		for dy in range(low, high):
			for dx in range(low, high):
				var c := cell + Vector2i(dx, dy)
				# Keep a solid border so the dungeon is always closed.
				if c.x >= 1 and c.y >= 1 and c.x < map.width - 1 and c.y < map.height - 1:
					map.set_floor(c)
		if cell == to:
			break
		cell += step


static func _farthest_room(map: DungeonMap) -> Rect2i:
	var best := map.rooms[0]
	var best_distance := -1.0
	for room in map.rooms:
		var distance := Vector2(room.get_center()).distance_to(Vector2(map.start_cell))
		if distance > best_distance:
			best_distance = distance
			best = room
	return best
