class_name FloorPopulator
## Fills a freshly generated floor: lights, props and hazards first (they claim their cells),
## then the ambush room, chests, monsters and items on the free cells.
## The first room is where the player starts: no monsters or hazards there.


static func populate(world: World, content: ContentDB, depth: int) -> void:
	var map := world.map
	var rng := world.rng
	var config := content.dungeon
	var taken := {}  # cells used by props and hazards
	_reserve_around(taken, map.start_cell, 2)
	_reserve_around(taken, map.stairs_cell, 1)
	for room in map.rooms:
		place_lights(world, config, room, taken)
	if map.rooms.size() < 2:
		return

	# The merchant waits in a quiet room (no monsters, no hazards, no props around).
	var event := world.floor_event
	var merchant_index := -1
	if config.merchant and (rng.randf() < config.merchant_chance or (event and event.merchant)):
		merchant_index = _pick_quiet_room(map, rng, -1)
		if merchant_index >= 0:
			var cell := map.rooms[merchant_index].get_center()
			world.spawn_merchant(config.merchant, cell)
			_reserve_rect(taken, map.rooms[merchant_index])

	# Springs, altars, statues: in the middle of a room, before anything else claims it.
	var encounter_count := rng.randi_range(config.encounters_min, config.encounters_max)
	if event and config.encounters_max > 0:
		encounter_count += event.extra_encounters
	for n in encounter_count:
		var encounter := ContentDB.pick_from(content.encounters, depth, rng) as EncounterDef
		var index := rng.randi_range(1, map.rooms.size() - 1)
		var cell := map.rooms[index].get_center()
		if encounter and index != merchant_index and not taken.has(cell):
			world.spawn_encounter(encounter, cell)
			_reserve_around(taken, cell, 1)

	if event and event.zone:
		place_zone(world, event, taken)

	for i in map.rooms.size():
		_place_props(world, content, depth, map.rooms[i], taken)
	var act := config.act_for_depth(depth)
	if act:
		var hazard_groups := rng.randi_range(config.hazard_groups_min, config.hazard_groups_max)
		if event:
			hazard_groups += event.extra_hazards
		for n in hazard_groups:
			var hazard := act.pick_hazard(depth, rng)
			if hazard:
				hazard.place(world, map.rooms[rng.randi_range(1, map.rooms.size() - 1)], taken)

	# One quiet room may be an ambush: no monsters in it until the hero walks in.
	var ambush_index := -1
	if rng.randf() < config.ambush_chance:
		ambush_index = _pick_quiet_room(map, rng, merchant_index)
		if ambush_index >= 0:
			world.spawn_ambush(map.rooms[ambush_index])

	if config.chest:
		var chest_count := rng.randi_range(config.chests_min, config.chests_max)
		if event:
			chest_count += event.extra_chests
		for n in chest_count:
			# A few tries: some rooms have no free spot along their walls.
			for attempt in 6:
				var room := map.rooms[rng.randi_range(1, map.rooms.size() - 1)]
				var cells := _shuffled(_edge_cells(map, room, taken), rng)
				if not cells.is_empty():
					world.spawn_chest(config.chest, cells[0], rng.randf() < config.chest.trapped_chance)
					_reserve_around(taken, cells[0], 1)
					break

	var extra := floori(config.extra_monsters_per_depth * (depth - 1))
	var max_per_room := config.max_monsters_per_room
	if world.difficulty:
		extra += world.difficulty.extra_monsters
		max_per_room += world.difficulty.extra_monsters
	for i in range(1, map.rooms.size()):
		if i == ambush_index or i == merchant_index:
			continue
		var room := map.rooms[i]
		var count := mini(rng.randi_range(config.monsters_per_room_min, config.monsters_per_room_max) + extra, max_per_room)
		if event:
			count = roundi(count * event.monster_count)
		for n in count:
			var def := content.pick_monster(depth, rng)
			if def:
				var monster := world.spawn_monster(def, _free_point_in(map, room, rng, taken))
				world.roll_elite(monster)

	for n in config.items_per_floor:
		var room := map.rooms[rng.randi_range(1, map.rooms.size() - 1)]
		var item := content.pick_item(depth, rng)
		if item:
			world.spawn_loot(item, _free_point_in(map, room, rng, taken))


## Frozen zone: a few rooms next to each other (never the first one), with campfires in them.
## Returns the rooms of the zone.
static func place_zone(world: World, event: FloorEventDef, taken: Dictionary) -> Array[Rect2i]:
	var map := world.map
	var zone: Array[Rect2i] = []
	if map.rooms.size() < 2 or event.zone_rooms <= 0:
		return zone
	var seed_room := map.rooms[world.rng.randi_range(1, map.rooms.size() - 1)]
	var others: Array[Rect2i] = []
	for i in range(1, map.rooms.size()):
		others.append(map.rooms[i])
	# The rooms closest to the first one: the cold spreads from there.
	others.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return Vector2(a.get_center() - seed_room.get_center()).length() < Vector2(b.get_center() - seed_room.get_center()).length())
	for room in others.slice(0, event.zone_rooms):
		zone.append(room)
		event.zone.place(world, room, taken)
	if event.warm_spot:
		var placed := 0
		var rooms := zone.duplicate()
		_shuffle_rects(rooms, world.rng)
		for room in rooms:
			if placed >= event.warm_spot_count:
				break
			if event.warm_spot.place_one(world, room, taken):
				placed += 1
	return zone


static func _shuffle_rects(list: Array[Rect2i], rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := list[i]
		list[i] = list[j]
		list[j] = swap


## A big enough room, not the first one, without the stairs and not `except` (-1 if none).
static func _pick_quiet_room(map: DungeonMap, rng: RandomNumberGenerator, except: int) -> int:
	var candidates: Array[int] = []
	for i in range(1, map.rooms.size()):
		var room := map.rooms[i]
		if i != except and room.size.x >= 7 and room.size.y >= 7 and not room.grow(1).has_point(map.stairs_cell):
			candidates.append(i)
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else -1


## Lanterns along the walls of a room (also used for boss arenas).
static func place_lights(world: World, config: DungeonConfig, room: Rect2i, taken: Dictionary) -> void:
	if config.room_light == null:
		return
	var cells := _edge_cells(world.map, room, taken)
	var placed: Array[Vector2i] = []
	for cell in _shuffled(cells, world.rng):
		if placed.size() >= config.lights_per_room:
			break
		# Spread them out.
		if placed.any(func(other: Vector2i) -> bool: return Vector2(other).distance_to(Vector2(cell)) < 5.0):
			continue
		world.spawn_prop(config.room_light, cell)
		_reserve_around(taken, cell, 1)
		placed.append(cell)


## Crates, pots and barrels in small clusters against the walls.
static func _place_props(world: World, content: ContentDB, depth: int, room: Rect2i, taken: Dictionary) -> void:
	var rng := world.rng
	var config := content.dungeon
	var clusters := rng.randi_range(config.prop_clusters_min, config.prop_clusters_max)
	var cells := _shuffled(_edge_cells(world.map, room, taken), rng)
	for n in mini(clusters, cells.size()):
		var start: Vector2i = cells[n]
		if taken.has(start):
			continue
		var size := rng.randi_range(1, 3)
		var cell := start
		for k in size:
			if taken.has(cell) or not _is_edge(world.map, room, cell):
				break
			var prop := content.pick_prop(depth, rng)
			if prop:
				world.spawn_prop(prop, cell)
			taken[cell] = true
			cell += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]


## Floor cells of the room touching a wall, away from doorways.
static func _edge_cells(map: DungeonMap, room: Rect2i, taken: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var cell := Vector2i(x, y)
			if not taken.has(cell) and _is_edge(map, room, cell):
				cells.append(cell)
	return cells


static func _is_edge(map: DungeonMap, room: Rect2i, cell: Vector2i) -> bool:
	if not room.has_point(cell) or not map.is_floor(cell):
		return false
	var touches_wall := false
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		touches_wall = touches_wall or not map.is_floor(cell + dir)
	if not touches_wall:
		return false
	# Next to a corridor mouth (floor outside the room): would block the way.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var near := cell + Vector2i(dx, dy)
			if map.is_floor(near) and not room.has_point(near):
				return false
	return true


static func _reserve_rect(taken: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			taken[Vector2i(x, y)] = true


static func _reserve_around(taken: Dictionary, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			taken[center + Vector2i(dx, dy)] = true


static func _shuffled(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result := cells.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


## A random point in the room, not on a prop or a trap.
static func _free_point_in(map: DungeonMap, room: Rect2i, rng: RandomNumberGenerator, taken: Dictionary) -> Vector2:
	var cell := map.random_cell_in(room, rng)
	for attempt in 12:
		if not taken.has(cell):
			break
		cell = map.random_cell_in(room, rng)
	var jitter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
	return map.cell_to_world(cell) + jitter
