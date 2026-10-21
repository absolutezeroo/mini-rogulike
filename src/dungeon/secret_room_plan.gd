class_name SecretRoomPlan
extends RefCounted
## Where a secret room hides on a floor: a small room behind a wall of an existing room, joined
## to it by a short passage through the rock. The generator only plans it (the cells stay wall in
## the DungeonMap, so nothing else sees it, draws it or walks into it); the cracked wall at the
## passage's mouth (`crack`) is the way in, and breaking it opens `cells()` (SecretRoom).
## Always behind rock at least DungeonGenerator.MIN_WALL_THICKNESS thick, so it never touches
## the main path, and the main path never needs it. Behind a cliff face (above a room) when it
## can, where the crack shows best; else behind a side or the bottom wall.

## Tried in this order for every room: up first (the crack on a cliff face).
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

## The hidden room.
var room: Rect2i
## The rock between the host room and the hidden one: the crack is its first row.
var passage: Array[Vector2i] = []
## The wall cells that show the crack (the passage's mouth, on the host room's side).
var crack: Array[Vector2i] = []
## The room it opens from (index in DungeonMap.rooms).
var host := -1
## From the host room into the rock (Vector2i.UP: behind a cliff face).
var direction := Vector2i.UP


## Every cell that becomes floor when it opens: the passage and the room.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = passage.duplicate()
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			result.append(Vector2i(x, y))
	return result


## The passage, as a rectangle (from the crack to the room).
func passage_rect() -> Rect2i:
	var rect := Rect2i(passage[0], Vector2i.ONE)
	for cell in passage:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect


## Where the crack is, between its cells (world pixels).
func crack_position(map: DungeonMap) -> Vector2:
	var sum := Vector2.ZERO
	for cell in crack:
		sum += map.cell_to_world(cell)
	return sum / maxf(crack.size(), 1.0)


## The secret rooms of a normal floor, after the rest of it is made (DungeonGenerator).
## `config.secret_room_chance` each, `secret_rooms_max` at most (`secret_rooms_big` on floors of
## `secret_big_floor_rooms` rooms or more). `rng` is the floor's own secret stream, so the rest
## of the floor comes out the same with or without them.
static func plan_all(map: DungeonMap, config: DungeonConfig, rng: RandomNumberGenerator) -> Array[SecretRoomPlan]:
	var result: Array[SecretRoomPlan] = []
	var tries := config.secret_rooms_max
	if config.secret_big_floor_rooms > 0 and map.rooms.size() >= config.secret_big_floor_rooms:
		tries = maxi(tries, config.secret_rooms_big)
	for n in tries:
		if rng.randf() >= config.secret_room_chance:
			continue
		var plan := _find(map, config, rng, result)
		if plan:
			result.append(plan)
	return result


## A place for one more secret room, or null. Hosts: any room but the first (where the hero
## arrives) and those holding the stairs. Every host above itself first, then its sides.
static func _find(map: DungeonMap, config: DungeonConfig, rng: RandomNumberGenerator, others: Array[SecretRoomPlan]) -> SecretRoomPlan:
	var hosts: Array[int] = []
	for i in range(1, map.rooms.size()):
		var room := map.rooms[i]
		if map.exit_cells().any(func(cell: Vector2i) -> bool: return room.grow(1).has_point(cell)):
			continue
		if others.any(func(other: SecretRoomPlan) -> bool: return other.host == i):
			continue
		hosts.append(i)
	RandomUtils.shuffle(hosts, rng)
	for direction in DIRECTIONS:
		for i in hosts:
			var plan := _try_side(map, config, rng, i, direction, others)
			if plan:
				return plan
	return null


## Along the side of room `host` facing `direction`: every spot for a passage, shuffled.
static func _try_side(map: DungeonMap, config: DungeonConfig, rng: RandomNumberGenerator, host: int, direction: Vector2i, others: Array[SecretRoomPlan]) -> SecretRoomPlan:
	var room := map.rooms[host]
	var along := Vector2i(absi(direction.y), absi(direction.x))  # across the passage
	var width := config.secret_passage_width
	# The first wall cell past the room's side, at its first corner.
	var corner := Vector2i(
		room.position.x - 1 if direction.x < 0 else (room.end.x if direction.x > 0 else room.position.x),
		room.position.y - 1 if direction.y < 0 else (room.end.y if direction.y > 0 else room.position.y))
	var side := room.size.x if along.x != 0 else room.size.y
	var spots: Array[int] = []
	for k in range(2, side - 1 - width):
		spots.append(k)
	RandomUtils.shuffle(spots, rng)
	for k in spots:
		var plan := _try(map, config, rng, host, corner + along * k, direction, others)
		if plan:
			return plan
	return null


## A secret room past wall cell `mouth` of room `host`, its passage going `direction`.
static func _try(map: DungeonMap, config: DungeonConfig, rng: RandomNumberGenerator, host: int, mouth: Vector2i, direction: Vector2i, others: Array[SecretRoomPlan]) -> SecretRoomPlan:
	var along := Vector2i(absi(direction.y), absi(direction.x))
	var width := config.secret_passage_width
	var length := maxi(config.secret_passage_length, DungeonGenerator.MIN_WALL_THICKNESS)
	# The crack sits on a plain stretch of wall: floor on the room's side of it and one cell beyond
	# each end, rock behind, no corridor coming in next to it.
	for k in range(-1, width + 1):
		var cell := mouth + along * k
		if not map.is_floor(cell - direction) or map.is_floor(cell):
			return null
	# The passage, then the room past it: `size.x` across the passage, `size.y` deep.
	var across := config.secret_room_size.x
	var deep := config.secret_room_size.y
	var room_size := Vector2i(across, deep) if along.x != 0 else Vector2i(deep, across)
	var shift := rng.randi_range(-(across - width) / 2, (across - width) / 2)
	var start := mouth + along * (width / 2 - across / 2 + shift)  # the room's first cell across
	var near := mouth + direction * length  # the room's first cell along the passage
	var corner := Vector2i(
		start.x if along.x != 0 else (near.x if direction.x > 0 else near.x - deep + 1),
		start.y if along.y != 0 else (near.y if direction.y > 0 else near.y - deep + 1))
	var hidden := Rect2i(corner, room_size)
	var passage: Array[Vector2i] = []
	var crack: Array[Vector2i] = []
	for j in length:
		for k in width:
			var cell := mouth + along * k + direction * j
			passage.append(cell)
			if j == 0:
				crack.append(cell)
			if hidden.has_point(cell):
				return null
	# The passage must come out under the room, not under its walls.
	for k in width:
		if not hidden.has_point(mouth + along * k + direction * length):
			return null
	# Rock all around, thick enough that opening it never thins a wall nor joins another floor.
	var margin := DungeonGenerator.MIN_WALL_THICKNESS
	var area := hidden.grow(margin)
	if area.position.x < 1 or area.position.y < 1 or area.end.x > map.width - 1 or area.end.y > map.height - 1:
		return null
	for other in others:
		if other.room.grow(margin * 2).intersects(hidden) or other.passage_rect().grow(margin).intersects(area):
			return null
	if not _all_rock(map, area):
		return null
	# And on both sides of the passage, back to the host room's wall.
	var tunnel := Rect2i(passage[0], Vector2i.ONE)
	for cell in passage:
		tunnel = tunnel.expand(cell).expand(cell + Vector2i.ONE)
	if not _all_rock(map, tunnel.grow_individual(margin * along.x, margin * along.y, margin * along.x, margin * along.y)):
		return null
	var plan := SecretRoomPlan.new()
	plan.room = hidden
	plan.host = host
	plan.direction = direction
	plan.passage = passage
	plan.crack = crack
	return plan


static func _all_rock(map: DungeonMap, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if map.is_floor(Vector2i(x, y)):
				return false
	return true
