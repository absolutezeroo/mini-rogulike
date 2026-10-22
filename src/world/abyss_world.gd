class_name AbyssWorld
extends PocketWorld
## The Deeps (AbyssDef), built beside the floor while the floor waits out of the tree: a small dark
## maze of the generator's rooms (DungeonGenerator.generate_small), in its own look and very low
## light, a few holes, and the Dawn Breach (AbyssDoor) in the room farthest from where the hero
## lands. Demons crawl out of the dark around him in waves while `waves_on`, more and more
## (AbyssDef's pacing, by act); from a deep act a warden stands by the door. The rules (the way
## in and out, the gift) are the Abyss'.

## The hero stepped into the Dawn Breach.
signal door_reached
## A wave crawled out of the dark (for the tests and the look).
signal wave_risen(index: int, monsters: Array[Monster])

var def: AbyssDef
var door: AbyssDoor
## Demons keep coming while this is on (the veil lifted, the hero searching).
var waves_on := false
## Waves risen so far.
var waves := 0
var warden: Monster

var _next_wave := 0.0
## The waves' demons (untyped: some are freed).
var _risen: Array = []


## The Deeps for a hero who fell on `fell_depth`, from `abyss`. The floor's difficulty and boons
## must be set before (the demons scale with them like the floor's monsters).
func build_depths(fell_depth: int, content: ContentDB, abyss: AbyssDef, seed_value: int) -> void:
	clear_floor()
	floor_id += 1
	def = abyss
	depth = fell_depth
	warden = null
	rng.seed = seed_value
	show_place(make_map(def, content.dungeon, rng), def.theme, def.lighting, def.light_tint, content)
	biome = def.dressing
	# Nothing where the hero lands nor around the door.
	var taken := {}
	for spot in [map.start_cell, map.stairs_cell]:
		for y in range(-2, 3):
			for x in range(-2, 3):
				taken[spot + Vector2i(x, y)] = true
	FloorDresser.dress(self, taken, false)
	_place_holes(taken)
	door = AbyssDoor.new()
	door.name = "DawnBreach"
	door.light_level = def.door_light
	door.position = map.cell_to_world(map.stairs_cell) + Vector2(0, map.tile_size * 0.25)
	door.reached.connect(func() -> void: door_reached.emit())
	_entities.add_child(door)
	_place_residents()
	if def.has_warden(depth, content.dungeon):
		_place_warden()
	waves = 0
	waves_on = false
	_risen.clear()
	map_reset.emit()


## The maze for `abyss` (its size, rooms and corridors); the door stands at its `stairs_cell`.
static func make_map(abyss: AbyssDef, config: DungeonConfig, random: RandomNumberGenerator) -> DungeonMap:
	return DungeonGenerator.generate_small(abyss.size, abyss.rooms, abyss.room_size, abyss.corridor_width, config.tile_size, random)


## The way from where the hero lands to the door (cell centres; empty: none).
func way_to_door(from: Vector2 = Vector2.INF) -> PackedVector2Array:
	var start := map.cell_to_world(map.start_cell) if from == Vector2.INF else from
	return find_path(start, map.cell_to_world(map.stairs_cell))


## A few groups of holes, never in the first room nor the door's, never cutting the way off
## (PitDef.place checks the way to the "stairs": the door).
func _place_holes(taken: Dictionary) -> void:
	if def.hazards.is_empty() or map.rooms.size() < 3:
		return
	var door_room := -1
	for i in map.rooms.size():
		if map.rooms[i].has_point(map.stairs_cell):
			door_room = i
	for n in def.hazard_groups:
		var index := rng.randi_range(1, map.rooms.size() - 1)
		if index == door_room:
			continue
		var hazard := ContentDB.pick_from(def.hazards, depth, rng) as HazardDef
		if hazard:
			hazard.place(self, map.rooms[index], taken)


## A few demons waiting in every room but the first (AbyssDef.room_demons), asleep until they
## see the hero.
func _place_residents() -> void:
	for i in range(1, map.rooms.size()):
		var room := map.rooms[i]
		for n in rng.randi_range(def.room_demons.x, def.room_demons.y):
			var kind := def.pick_monster(depth, rng)
			if kind == null:
				continue
			for attempt in 12:
				var cell := map.random_cell_in(room, rng, 1)
				if is_free_cell(cell) and Vector2(cell - map.stairs_cell).length() > 2.5:
					spawn_monster(kind, map.cell_to_world(cell))
					break


## The watchman, two cells in front of the door, waiting for whoever comes near.
func _place_warden() -> void:
	var at := nearest_free_point(map.cell_to_world(map.stairs_cell + Vector2i(0, 2)))
	warden = spawn_monster(def.warden, at)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not waves_on or player == null or player.is_dead:
		return
	_next_wave -= delta
	if _next_wave <= 0.0:
		_next_wave = def.wave_every_for(depth, config())
		raise_wave()


## The waves start: the first one after `AbyssDef.first_wave` seconds.
func start_waves() -> void:
	waves_on = true
	_next_wave = def.first_wave


## A wave crawls out of the dark around the hero: as many demons as the wave asks, as long as
## fewer than the most allowed are up. Returns them.
func raise_wave() -> Array[Monster]:
	var risen: Array[Monster] = []
	if player == null:
		return risen
	var room := def.max_alive_for(depth, config()) - _risen_alive()
	var count := mini(def.wave_size_for(waves, depth, config()), room)
	var ahead := roundi(count * def.ahead_share)
	for i in count:
		var demon := raise_demon(i < ahead)
		if demon:
			risen.append(demon)
	waves += 1
	if not risen.is_empty():
		Sfx.play_at(Sfx.bank.monster_alert, player.global_position, -6.0, 0.6)
	wave_risen.emit(waves - 1, risen)
	return risen


## Demons of the waves still up (those waiting in the rooms and the warden don't count: the
## waves' cap is for what hunts him).
func _risen_alive() -> int:
	var count := 0
	for demon in _risen:
		if is_instance_valid(demon) and not demon.is_dead:
			count += 1
	return count


## One demon out of the dark, away from the hero (`ahead`: on his way to the door), coming for
## him. Null if none could rise.
func raise_demon(ahead: bool = false) -> Monster:
	var kind := def.pick_monster(depth, rng)
	if kind == null or player == null:
		return null
	var at := _spawn_point(ahead)
	if at == Vector2.INF:
		return null
	var demon := spawn_monster(kind, at)
	_risen.append(demon)
	if rng.randf() < def.elite_chance:
		make_elite(demon)
	demon.wake_up(player)
	# It crawls out of the dark: shadow pulled together, then a lick of fire.
	Vfx.pop(self, at + Vector2(0, -10), VfxElementDef.named(&"shadow"), 16.0, Vector2.UP)
	Vfx.nova(self, at, 18.0, VfxElementDef.named(&"shadow"))
	return demon


## A free cell the hero can be reached from, between `spawn_cells` away from him; INF if none.
## `ahead`: on the way from him to the door, if it can.
func _spawn_point(ahead: bool = false) -> Vector2:
	var hero := map.world_to_cell(player.global_position)
	var near := def.spawn_cells.x
	var far := maxi(def.spawn_cells.y, near + 1)
	if ahead:
		var way := way_to_door(player.global_position)
		var spots: Array[Vector2i] = []
		for i in range(near, mini(far + 1, way.size() - 3)):
			spots.append(map.world_to_cell(way[i]))
		for attempt in 12:
			if spots.is_empty():
				break
			var cell := spots[rng.randi_range(0, spots.size() - 1)] + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			if map.in_bounds(cell) and is_free_cell(cell) and Vector2(cell - hero).length() >= near:
				return map.cell_to_world(cell)
	for attempt in 60:
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(near, far)
		var at := _spawn_cell_point(hero + Vector2i(roundi(offset.x), roundi(offset.y)), far)
		if at != Vector2.INF:
			return at
	# In a cramped maze the random tries may all miss (a wave came out short): every cell of the
	# ring then, in a random order, so a demon rises whenever there is room for one.
	var ring: Array[Vector2i] = []
	for y in range(hero.y - far, hero.y + far + 1):
		for x in range(hero.x - far, hero.x + far + 1):
			var length := Vector2(x - hero.x, y - hero.y).length()
			if length >= near and length <= far:
				ring.append(Vector2i(x, y))
	while not ring.is_empty():
		var at := _spawn_cell_point(ring.pop_at(rng.randi_range(0, ring.size() - 1)), far)
		if at != Vector2.INF:
			return at
	return Vector2.INF


## `cell`'s point if a demon may rise there (free, not by the door, a short walk from the hero);
## INF otherwise.
func _spawn_cell_point(cell: Vector2i, far: int) -> Vector2:
	if not map.in_bounds(cell) or not is_free_cell(cell) or (map.cell_to_world(cell) - door.global_position).length() < map.tile_size * 2.5:
		return Vector2.INF
	var at := map.cell_to_world(cell)
	var path := find_path(at, player.global_position)
	if not path.is_empty() and path.size() <= far * 2:
		return at
	return Vector2.INF
