class_name FloorDresser
## Dresses a floor in its biome (World.biome), the way the hand-made parts of Dead Cells or the
## "flavor machines" of Brogue do: never anything thrown about at random.
##   1. Grounds (GroundLayerDef): sand, moss... in organic patches shaped by noise, pushed toward
##      or away from the walls.
##   2. Scenes (SceneDef): little scenes made by hand, a few per room depending on its size,
##      each where its anchor says, never walling anything off.
##   3. Decor (DecorRuleDef): small things gathered in clusters, near the walls or on a ground.
## The first room (where the hero arrives) gets no scene.

## The scenes put on the last floor dressed (SceneDef -> how many): for tests and the debug panel.
static var last_scenes := {}


## `taken`: cells already used (see HazardDef). `with_scenes`: false in a boss arena.
static func dress(world: World, taken: Dictionary, with_scenes: bool = true) -> void:
	var biome := world.biome
	if biome == null:
		return
	var walls := wall_distance(world.map)
	for layer in biome.grounds:
		if layer:
			_lay_ground(world, layer, walls)
	if with_scenes:
		_place_scenes(world, biome, taken)
	for rule in biome.decor:
		if rule and not rule.pieces.is_empty():
			_scatter(world, rule, walls, taken)


## Cells from each floor cell to the nearest wall (1 = touching one).
static func wall_distance(map: DungeonMap) -> Dictionary:
	var distance := {}
	var queue: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if not map.is_floor(cell):
				continue
			for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not map.is_floor(cell + dir):
					distance[cell] = 1
					queue.append(cell)
					break
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_floor(next) and not distance.has(next):
				distance[next] = distance[cell] + 1
				queue.append(next)
	return distance


## Noise plus the pull toward (or away from) the walls: higher = more likely there.
static func _score(noise: FastNoiseLite, cell: Vector2i, walls: Dictionary, wall_bias: float) -> float:
	var near_wall := 1.0 - clampf((float(walls.get(cell, 4)) - 1.0) / 3.0, 0.0, 1.0)
	return noise.get_noise_2d(cell.x, cell.y) + wall_bias * (near_wall - 0.5) * 1.2


static func _noise(rng: RandomNumberGenerator, scale: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = scale
	noise.fractal_octaves = 2
	return noise


static func _lay_ground(world: World, layer: GroundLayerDef, walls: Dictionary) -> void:
	var noise := _noise(world.rng, layer.noise_scale)
	var scored: Array = []
	for cell: Vector2i in walls:
		scored.append([_score(noise, cell, walls, layer.wall_bias), cell])
	if scored.is_empty():
		return
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var cells := {}
	for i in roundi(scored.size() * layer.coverage):
		cells[scored[i][1]] = true
	# Smooth it out: no lone cells, no pinholes.
	for pass_index in 2:
		var smoothed := {}
		for cell: Vector2i in walls:
			var around := 0
			for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if cells.has(cell + dir):
					around += 1
			if (cells.has(cell) and around >= 2) or around >= 3:
				smoothed[cell] = true
		cells = smoothed
	if cells.is_empty():
		return
	world.grounds[layer] = cells
	var view := GroundLayer.new()
	view.setup(layer, world.map, cells)
	world.spawn_vfx(view)


static func _place_scenes(world: World, biome: BiomeDef, taken: Dictionary) -> void:
	if biome.scenes.is_empty():
		return
	var map := world.map
	var rng := world.rng
	var placed := {}  # SceneDef -> count on this floor
	last_scenes = placed
	var rooms := range(1, map.rooms.size())
	RandomUtils.shuffle(rooms, rng)
	for i: int in rooms:
		var room := map.rooms[i]
		var big := room.get_area() >= biome.big_room_area
		var wanted := rng.randi_range(biome.scenes_big_room.x, biome.scenes_big_room.y) if big \
			else rng.randi_range(biome.scenes_small_room.x, biome.scenes_small_room.y)
		var tries := wanted * 4
		while wanted > 0 and tries > 0:
			tries -= 1
			var scene := _pick_scene(biome, room, big, placed, world.depth, rng)
			if scene == null:
				break
			if scene.try_place(world, room, taken, rng):
				placed[scene] = placed.get(scene, 0) + 1
				wanted -= 1


static func _pick_scene(biome: BiomeDef, room: Rect2i, big: bool, placed: Dictionary, depth: int, rng: RandomNumberGenerator) -> SceneDef:
	var fitting := biome.scenes.filter(func(scene: SceneDef) -> bool:
		if scene == null or (scene.max_per_floor > 0 and placed.get(scene, 0) >= scene.max_per_floor):
			return false
		if (scene.room_size == SceneDef.RoomSize.BIG and not big) or (scene.room_size == SceneDef.RoomSize.SMALL and big):
			return false
		var span := scene.size()
		return span.x <= room.size.x and span.y <= room.size.y)
	return ContentDB.pick_from(fitting, depth, rng) as SceneDef


static func _scatter(world: World, rule: DecorRuleDef, walls: Dictionary, taken: Dictionary) -> void:
	var rng := world.rng
	var noise := _noise(rng, rule.noise_scale)
	var on: Dictionary = world.grounds.get(rule.only_on, {}) if rule.only_on else {}
	if rule.only_on and on.is_empty():
		return
	var layer := DecorLayer.new()
	layer.z_index = -8
	for cell: Vector2i in walls:
		if rule.only_on and not on.has(cell):
			continue
		if world.nav.is_blocked(cell) or cell == world.map.start_cell or cell == world.map.stairs_cell:
			continue
		# Clustered: the noise says where; `clumping` how strictly.
		var cluster := (_score(noise, cell, walls, rule.wall_bias) + 1.0) * 0.5
		var chance := rule.density * lerpf(1.0, clampf((cluster - 0.45) * 4.0, 0.0, 2.5), rule.clumping)
		if rng.randf() >= chance:
			continue
		var at := world.map.cell_to_world(cell) + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		layer.pieces.append([rule.pieces[rng.randi() % rule.pieces.size()], at.snapped(Vector2(2, 2))])
	if not layer.pieces.is_empty():
		world.spawn_vfx(layer)
