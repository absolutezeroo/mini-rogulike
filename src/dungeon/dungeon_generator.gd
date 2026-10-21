class_name DungeonGenerator
## Builds a DungeonMap: random non-overlapping rooms chained by wide corridors.
## Each room connects to the previous one, so every room is reachable.


## `size_scale`, `room_scale`: the difficulty's (DifficultyDef.floor_size, rooms).
static func generate(config: DungeonConfig, rng: RandomNumberGenerator, size_scale: float = 1.0, room_scale: float = 1.0) -> DungeonMap:
	var width := roundi(config.width * size_scale)
	var height := roundi(config.height * size_scale)
	var max_rooms := maxi(roundi(config.max_rooms * room_scale), 2)
	var map := DungeonMap.new(width, height, config.tile_size)

	for attempt in max_rooms * 12:
		if map.rooms.size() >= max_rooms:
			break
		var size := Vector2i(
			rng.randi_range(config.room_min_size, config.room_max_size),
			rng.randi_range(config.room_min_size, config.room_max_size))
		var room := Rect2i(
			Vector2i(rng.randi_range(2, width - size.x - 2), rng.randi_range(2, height - size.y - 2)),
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
	map.second_stairs_cell = _second_exit(map)
	map.secrets = SecretRoomPlan.plan_all(map, config, secret_rng(rng))
	return map


## The floor's own stream for its secrets, drawn from the floor's seed without touching `rng`:
## the rest of the floor (monsters, chests...) comes out the same with or without them.
static func secret_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var secret := RandomNumberGenerator.new()
	secret.seed = hash("secrets-%d" % rng.seed)
	return secret


## Boss floor: a small start room and one big arena, joined by a single corridor
## (so the arena has only one entrance to close). The stairs appear in the arena later.
## `plan`: the arena's size and shape (ArenaDef); without one, a plain room of config.arena_size.
static func generate_arena(config: DungeonConfig, rng: RandomNumberGenerator, plan: ArenaDef = null) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)
	var arena_size := plan.size if plan else config.arena_size
	arena_size = Vector2i(mini(arena_size.x, config.width - 22), mini(arena_size.y, config.height - 8))
	var arena := Rect2i(
		Vector2i(config.width - arena_size.x - rng.randi_range(4, 8), (config.height - arena_size.y) / 2 + rng.randi_range(-4, 4)),
		arena_size)
	var start := Rect2i(Vector2i(rng.randi_range(4, 8), arena.get_center().y - 3 + rng.randi_range(-8, 8)), Vector2i(7, 7))
	_carve_rect(map, start)
	if plan:
		for cell in plan.cells(arena.position):
			map.set_floor(cell)
	else:
		_carve_rect(map, arena)
	_carve_corridor(map, start.get_center(), arena.get_center(), config.corridor_width, rng)
	smooth(map)
	map.rooms.append(start)
	map.rooms.append(arena)
	map.boss_room = arena
	map.start_cell = start.get_center()
	map.stairs_cell = arena.get_center()
	# The second way down, beside the first once the boss falls.
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		if map.is_floor(map.stairs_cell + offset) and arena.has_point(map.stairs_cell + offset):
			map.second_stairs_cell = map.stairs_cell + offset
			break
	return map


## The hidden floor (HiddenFloorDef): a start room and `room_count` rooms in a row on the left,
## then one arena on the right, joined by a single corridor (one entrance to close, like a boss
## floor; a way through the dark first). `plan`: the arena's size and shape.
static func generate_hidden(config: DungeonConfig, rng: RandomNumberGenerator, plan: ArenaDef, room_count: int) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)
	var arena_size := plan.size if plan else config.arena_size
	arena_size = Vector2i(mini(arena_size.x, config.width / 2 - 4), mini(arena_size.y, config.height - 12))
	var arena := Rect2i(
		Vector2i(config.width - arena_size.x - 4, (config.height - arena_size.y) / 2 + rng.randi_range(-6, 6)),
		arena_size)
	var right := arena.position.x - 6  # the rooms keep to the left of this
	var rooms: Array[Rect2i] = [Rect2i(Vector2i(4, config.height / 2 - 3 + rng.randi_range(-12, 12)), Vector2i(7, 7))]
	for attempt in room_count * 40:
		if rooms.size() > room_count:
			break
		var size := Vector2i(
			rng.randi_range(config.room_min_size, mini(config.room_max_size, 11)),
			rng.randi_range(config.room_min_size, mini(config.room_max_size, 11)))
		if right - size.x <= 12:
			continue
		var room := Rect2i(Vector2i(rng.randi_range(12, right - size.x), rng.randi_range(3, config.height - size.y - 3)), size)
		if not _overlaps_any(room, rooms):
			rooms.append(room)
	# Left to right, so the way leads on toward the arena.
	var ahead := rooms.slice(1)
	ahead.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	var ordered: Array[Rect2i] = [rooms[0]]
	ordered.append_array(ahead)
	rooms = ordered
	for i in rooms.size():
		_carve_rect(map, rooms[i])
		if i > 0:
			_carve_corridor(map, rooms[i - 1].get_center(), rooms[i].get_center(), config.corridor_width, rng)
	if plan:
		for cell in plan.cells(arena.position):
			map.set_floor(cell)
	else:
		_carve_rect(map, arena)
	_carve_corridor(map, rooms[rooms.size() - 1].get_center(), arena.get_center(), config.corridor_width, rng)
	smooth(map)
	map.rooms = rooms
	map.rooms.append(arena)
	map.boss_room = arena
	map.start_cell = rooms[0].get_center()
	map.stairs_cell = arena.get_center()
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		if map.is_floor(map.stairs_cell + offset) and arena.has_point(map.stairs_cell + offset):
			map.second_stairs_cell = map.stairs_cell + offset
			break
	return map


## Walls between two floors thinner than this (in cells, across or along) read as flimsy
## fences, not rock: they are opened up.
const MIN_WALL_THICKNESS := 3


## Removes wall shapes the cliff tiles can't draw or that look wrong: walls thinner than
## MIN_WALL_THICKNESS with floor on both sides, and walls touching each other only by a corner
## (checkerboard). They become floor. The outer border always stays solid.
static func smooth(map: DungeonMap) -> void:
	# A work list instead of whole-map passes: only the walls near a cell just opened are looked
	# at again (a thin run is at most MIN_WALL_THICKNESS long). Same rules, a fraction of the time.
	var w := map.width
	var h := map.height
	var tiles := map.tiles
	var floor_tile := DungeonMap.Tile.FLOOR
	var queued := PackedByteArray()
	queued.resize(w * h)
	var queue := PackedInt32Array()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if tiles[i] != floor_tile and _floor_in_reach(tiles, w, h, x, y):
				queue.append(i)
				queued[i] = 1
	var reach := MIN_WALL_THICKNESS
	while not queue.is_empty():
		var i := queue[queue.size() - 1]
		queue.resize(queue.size() - 1)
		queued[i] = 0
		if tiles[i] == floor_tile:
			continue
		var x := i % w
		var y := i / w
		if not (_thin(tiles, w, h, x, y, 1, 0) or _thin(tiles, w, h, x, y, 0, 1) or _pinched(tiles, w, h, x, y)):
			continue
		tiles[i] = floor_tile
		for ny in range(maxi(y - reach, 1), mini(y + reach + 1, h - 1)):
			for nx in range(maxi(x - reach, 1), mini(x + reach + 1, w - 1)):
				var n := ny * w + nx
				if tiles[n] != floor_tile and queued[n] == 0:
					queue.append(n)
					queued[n] = 1
	map.tiles = tiles


## A floor cell 1 or 2 steps away along an axis (or diagonal): the only walls smooth() may open.
static func _floor_in_reach(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		var ny := y + dy
		if ny < 0 or ny >= h:
			continue
		for dx in range(-2, 3):
			var nx := x + dx
			if nx >= 0 and nx < w and tiles[ny * w + nx] == DungeonMap.Tile.FLOOR:
				return true
	return false


## is_thin_wall() on the raw tiles (smooth() calls it thousands of times).
static func _thin(tiles: PackedByteArray, w: int, h: int, x: int, y: int, ax: int, ay: int) -> bool:
	var run := 1
	for sign in [1, -1]:
		var nx: int = x + ax * sign
		var ny: int = y + ay * sign
		while true:
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				return false  # the border
			if tiles[ny * w + nx] == DungeonMap.Tile.FLOOR:
				break
			if run >= MIN_WALL_THICKNESS:
				return false  # thick enough
			run += 1
			nx += ax * sign
			ny += ay * sign
	return run < MIN_WALL_THICKNESS


## _is_pinch() on the raw tiles (outside the map counts as wall).
static func _pinched(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			var cx: int = x + dx
			var cy: int = y + dy
			var diagonal_wall := cx < 0 or cy < 0 or cx >= w or cy >= h or tiles[cy * w + cx] != DungeonMap.Tile.FLOOR
			if diagonal_wall and _is_open(tiles, w, h, cx, y) and _is_open(tiles, w, h, x, cy):
				return true
	return false


static func _is_open(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and tiles[y * w + x] == DungeonMap.Tile.FLOOR


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


## The second way down: the room farthest from both the start and the first stairs (no rng:
## the rest of the floor comes out the same). NO_CELL if no room is far enough from both.
static func _second_exit(map: DungeonMap) -> Vector2i:
	var best := DungeonMap.NO_CELL
	var best_distance := 12.0  # cells, at least, from the start and from the first stairs
	for i in range(1, map.rooms.size()):
		var center := map.rooms[i].get_center()
		if map.rooms[i].has_point(map.stairs_cell) or not map.is_floor(center):
			continue
		var distance := minf(Vector2(center).distance_to(Vector2(map.start_cell)), Vector2(center).distance_to(Vector2(map.stairs_cell)))
		if distance > best_distance:
			best_distance = distance
			best = center
	return best


static func _farthest_room(map: DungeonMap) -> Rect2i:
	var best := map.rooms[0]
	var best_distance := -1.0
	for room in map.rooms:
		var distance := Vector2(room.get_center()).distance_to(Vector2(map.start_cell))
		if distance > best_distance:
			best_distance = distance
			best = room
	return best
