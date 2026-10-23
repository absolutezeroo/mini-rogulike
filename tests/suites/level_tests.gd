class_name LevelTests
extends TestSuite
## The floors' identity (docs/design/dungeon.md, "Room shapes", "Ceilings", "Signature rooms"):
## the shapes' geometry and every biome's generated floors (run_unit), then built floors in the
## game: what stands where, the ceiling over the hero, the minimap (run_game).


func run_unit() -> void:
	_test_shape_geometry()
	_test_shaped_floors()


## Outlines, cores, bridges and pillars, on paper.
func _test_shape_geometry() -> void:
	var oval := RoomShapeDef.new()
	oval.outline = RoomShapeDef.Outline.OVAL
	var size := Vector2i(13, 13)
	check(oval.has_cell(Vector2i(6, 6), size) and oval.has_cell(Vector2i(6, 0), size) and oval.has_cell(Vector2i(0, 6), size), "a round hall: its middle and the middle of each side are floor")
	check(not oval.has_cell(Vector2i(0, 0), size) and not oval.has_cell(Vector2i(12, 12), size), "a round hall: its corners are rock")
	var cross := RoomShapeDef.new()
	cross.outline = RoomShapeDef.Outline.CROSS
	check(cross.has_cell(Vector2i(6, 0), size) and cross.has_cell(Vector2i(0, 6), size) and not cross.has_cell(Vector2i(1, 1), size), "a cross: arms to every side, corners rock")
	var bent := RoomShapeDef.new()
	bent.outline = RoomShapeDef.Outline.L_SHAPE
	bent.arm = 0.55
	check(not bent.has_cell(Vector2i(12, 0), size) and bent.has_cell(Vector2i(0, 0), size) and bent.has_cell(Vector2i(12, 12), size) and bent.has_cell(Vector2i(6, 6), size), "an L: one corner left out, its middle kept")
	check(not bent.has_cell(Vector2i(0, 12), size, Vector2i(-1, -1)) and bent.has_cell(Vector2i(12, 0), size, Vector2i(-1, -1)), "an L turned: the opposite corner left out")
	var chasm := RoomShapeDef.new()
	chasm.core = RoomShapeDef.Core.CHASM
	chasm.core_outline = RoomShapeDef.Outline.RECT
	chasm.core_margin = 2
	chasm.bridges = 4
	chasm.bridge_width = 2
	var room := Vector2i(15, 13)
	check(chasm.core_at(Vector2i(4, 3), room) == RoomShapeDef.Core.CHASM and chasm.core_at(Vector2i(1, 6), room) == RoomShapeDef.Core.NONE, "a chasm room: the chasm inside, a ledge all round")
	check(chasm.core_at(Vector2i(7, 3), room) == RoomShapeDef.Core.NONE and chasm.core_at(Vector2i(3, 6), room) == RoomShapeDef.Core.NONE, "...crossed by walkways both ways through the middle")
	var hall := RoomShapeDef.new()
	hall.pillars = RoomShapeDef.Pillars.ROWS
	var pillars := hall.pillar_cells(Vector2i(15, 11))
	check(pillars.size() >= 6, "a pillared hall has two rows of pillars (%d)" % pillars.size())
	check(pillars.all(func(c: Vector2i) -> bool: return absi(c.x - 7) > 1 and absi(c.y - 5) > 1), "no pillar on the lanes through the middle (where corridors come in)")
	var ring := RoomShapeDef.new()
	ring.outline = RoomShapeDef.Outline.OVAL
	ring.pillars = RoomShapeDef.Pillars.RING
	var circle := ring.pillar_cells(Vector2i(15, 15))
	check(circle.size() >= 4 and circle.all(func(c: Vector2i) -> bool: return ring.has_cell(c, Vector2i(15, 15))), "a ring of pillars stands inside its round hall (%d)" % circle.size())


## Every biome's floors (and the Deeps'), at every difficulty's size, many seeds: one piece,
## solid walls, the start, the stairs and every room's heart on open ground, the shapes used.
func _test_shaped_floors() -> void:
	var config := CONTENT.dungeon
	var rng := RandomNumberGenerator.new()
	var biomes: Array[BiomeDef] = []
	for act in config.acts:
		for biome in act.biomes:
			if biome and not biomes.has(biome):
				biomes.append(biome)
	var listed := {}  # every shape some biome lists
	var used := {}  # shape -> rooms of it made
	var floors := 0
	var cut: Array[String] = []
	var bad_walls: Array[String] = []
	var off_ground: Array[String] = []
	var plain_first := true
	var shaped := 0
	var rooms := 0
	for biome in biomes:
		check(not biome.room_shapes.is_empty(), "%s: its rooms take shapes" % biome.id)
		for shape in biome.room_shapes:
			listed[shape] = true
		for difficulty in CONTENT.difficulties:
			for i in 5:
				rng.seed = hash("%s-%s-%d" % [biome.id, difficulty.id, i])
				var depth := 2 + i * 2
				var map := DungeonGenerator.generate(config, rng, difficulty.floor_size, difficulty.rooms, biome, depth)
				floors += 1
				var name := "%s/%s/%d" % [biome.id, difficulty.id, i]
				var lost := _unreached_ground(map)
				if lost > 0:
					cut.append("%s: %d cells" % [name, lost])
				if not _bad_walls(map).is_empty():
					bad_walls.append(name)
				var spots: Array[Vector2i] = [map.start_cell, map.stairs_cell]
				if map.second_stairs_cell != DungeonMap.NO_CELL:
					spots.append(map.second_stairs_cell)
				for k in map.rooms.size():
					spots.append(map.heart(k))
				for secret in map.secrets:
					for cell in secret.crack:
						spots.append(cell - secret.direction)
				for spot in spots:
					if not map.is_ground(spot):
						off_ground.append("%s %s" % [name, spot])
				plain_first = plain_first and map.plan(0).shape == null
				rooms += map.rooms.size()
				for plan in map.plans:
					if plan.shape:
						shaped += 1
						used[plan.shape] = used.get(plan.shape, 0) + 1
	check(floors >= 180, "many floors made (%d)" % floors)
	check(cut.is_empty(), "every shaped floor is one piece: all its ground reached from the start (%s)" % ", ".join(cut.slice(0, 4)))
	check(bad_walls.is_empty(), "shaped floors keep solid walls: none thin or pinched (%s)" % ", ".join(bad_walls.slice(0, 4)))
	check(off_ground.is_empty(), "the start, the stairs, the rooms' hearts and the cracks' fronts are on open ground, never a chasm, a pool or a pillar (%s)" % ", ".join(off_ground.slice(0, 4)))
	check(plain_first, "the room where the hero arrives is always a plain one")
	check(shaped * 4 >= rooms, "a good share of the rooms take a shape (%d of %d)" % [shaped, rooms])
	var unused: Array[String] = []
	for shape: RoomShapeDef in listed:
		if not used.has(shape):
			unused.append(String(shape.id))
	check(unused.is_empty(), "every shape a biome lists comes out (%s never)" % ", ".join(unused))
	# The Deeps' maze takes its dressing's shapes too, and still leads to the door.
	var abyss := config.abyss
	if abyss and abyss.dressing:
		var deep_shapes := 0
		var lost_deep: Array[int] = []
		for seed_value in 40:
			rng.seed = 900 + seed_value
			var map := AbyssWorld.make_map(abyss, config, rng)
			deep_shapes += map.plans.filter(func(p: RoomPlan) -> bool: return p.shape != null).size()
			if _unreached_ground(map) > 0 or not map.is_ground(map.stairs_cell):
				lost_deep.append(seed_value)
		check(deep_shapes > 0 and lost_deep.is_empty(), "the Deeps' rooms take shapes, the maze in one piece (%d shaped; cut: %s)" % [deep_shapes, str(lost_deep)])


## In the game, every biome's floors as built: chasms are holes, pools are water nobody walks
## in, pillars stand, nothing else (prop, trap, chest, monster) inside rock, a chasm or a pool,
## every open cell reachable; the minimap draws the rooms' shapes.
func run_game(game: Game) -> void:
	var depth_before := game.depth
	var dungeon := CONTENT.dungeon
	var seen_features := {}
	var seen_pillars := 0
	var problems: Array[String] = []
	var minimap_checked := false
	for a in dungeon.acts.size():
		for biome in dungeon.acts[a].biomes:
			for attempt in 2:
				game.world.forced_biome = biome
				await game.debug_enter_floor(dungeon.first_depth(a) + 1 + attempt)
				var world := game.world
				var name := "%s#%d" % [biome.id, attempt]
				await _frames(2)
				problems.append_array(_floor_problems(world, name))
				for cell: Vector2i in world.map.features:
					seen_features[world.map.features[cell]] = true
				seen_pillars += world.map.pillars.size()
				if not minimap_checked:
					minimap_checked = _check_minimap(world)
	# And floors made only of shaped rooms (chasms, pools, pillars, rings: each on every floor).
	var mixed: BiomeDef = dungeon.acts[0].biomes[0].duplicate()
	var every: Array[RoomShapeDef] = []
	for path in ["chasm_room", "pool_room", "pillared_hall", "ring_room", "pillared_round", "grid_hall"]:
		every.append(load("res://data/biomes/shapes/%s.tres" % path))
	mixed.room_shapes = every
	mixed.plain_weight = 5
	for attempt in 3:
		game.world.forced_biome = mixed
		await game.debug_enter_floor(2 + attempt * 3)
		var world := game.world
		await _frames(2)
		problems.append_array(_floor_problems(world, "all shapes#%d" % attempt))
		for cell: Vector2i in world.map.features:
			seen_features[world.map.features[cell]] = true
		seen_pillars += world.map.pillars.size()
		if not minimap_checked:
			minimap_checked = _check_minimap(world)
	check(problems.is_empty(), "shaped rooms as built: nothing in the rock, a chasm or a pool, every chasm a hole, every pool water, every pillar standing, every open cell reachable (%d: %s)" % [problems.size(), ", ".join(problems.slice(0, 5))])
	check(seen_features.has(DungeonMap.Feature.CHASM) and seen_features.has(DungeonMap.Feature.POOL) and seen_pillars > 0, "chasms, pools and pillars on the floors built (%s, %d pillars)" % [str(seen_features.keys()), seen_pillars])
	check(minimap_checked, "the minimap draws a round room round, its pool blue and its chasm black")
	await _clear_monsters(game.world)
	game.depth = depth_before


## What is wrong on the floor `world` holds (empty: nothing).
func _floor_problems(world: World, name: String) -> Array[String]:
	var map := world.map
	var problems: Array[String] = []
	for cell: Vector2i in map.features:
		var kind: int = map.features[cell]
		if kind == DungeonMap.Feature.CHASM and not world.has_pit(cell):
			problems.append("%s: chasm %s not a hole" % [name, cell])
		if kind == DungeonMap.Feature.POOL and not (world.is_pool(cell) and world.nav.is_blocked(cell)):
			problems.append("%s: pool %s walkable" % [name, cell])
		# Deep inside the water a body never fits.
		if kind == DungeonMap.Feature.POOL and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(func(d: Vector2i) -> bool: return map.features.get(cell + d, 0) == DungeonMap.Feature.POOL) \
				and world.body_fits(map.cell_to_world(cell), 8.0):
			problems.append("%s: a body fits in the pool at %s" % [name, cell])
	var standing := {}
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop == null or prop.is_queued_for_deletion() or not world.is_ancestor_of(prop):
			continue
		for cell in prop.cells():
			standing[cell] = prop
			if not map.is_floor(cell) and prop.def != CONTENT.dungeon.cracked_wall:
				problems.append("%s: %s in the rock at %s" % [name, prop.def.id, cell])
			elif map.features.has(cell):
				problems.append("%s: %s in a chasm or pool at %s" % [name, prop.def.id, cell])
	for cell: Vector2i in map.pillars:
		if not standing.has(cell):
			problems.append("%s: no pillar at %s" % [name, cell])
	for group in ["chests", "traps", "encounters"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and world.is_ancestor_of(node):
				var cell := map.world_to_cell((node as Node2D).global_position)
				if not map.is_floor(cell) or map.features.has(cell):
					problems.append("%s: a %s at %s" % [name, group, cell])
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		var on_ground := world.is_solid_ground(monster.global_position) and not world.is_pool(map.world_to_cell(monster.global_position))
		var fits := world.body_fits(monster.global_position, monster.radius)
		if (monster.is_grounded() and not on_ground) or not fits:
			problems.append("%s: %s (radius %.0f) stuck at %s (ground %s, fits %s)" % [name, monster.def.id, monster.radius, monster.global_position, on_ground, fits])
	for cell in world.stairs_cells:
		if not world.is_solid_ground(map.cell_to_world(cell)) or map.features.has(cell):
			problems.append("%s: stairs off the ground at %s" % [name, cell])
	# Every open cell reachable from the start (breakable things count as open).
	var breakable := {}
	for cell: Vector2i in standing:
		if (standing[cell] as Prop).def.is_breakable():
			breakable[cell] = true
	var open := func(cell: Vector2i) -> bool:
		return map.is_floor(cell) and (not world.nav.is_blocked(cell) or breakable.has(cell))
	var seen := {map.start_cell: true}
	var queue: Array[Vector2i] = [map.start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if open.call(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var lost := 0
	for y in map.height:
		for x in map.width:
			if open.call(Vector2i(x, y)) and not seen.has(Vector2i(x, y)):
				lost += 1
	if lost > 0:
		problems.append("%s: %d open cells cut off" % [name, lost])
	return problems


## On a floor with a round room (and a pool or a chasm): the whole map revealed, the minimap
## paints the room's rock corners empty, its floor, its water and its holes. False if this floor
## has no round room to look at.
func _check_minimap(world: World) -> bool:
	var map := world.map
	var round := -1
	for i in map.rooms.size():
		var shape := map.plan(i).shape
		if shape and shape.outline == RoomShapeDef.Outline.OVAL and not map.is_floor(map.rooms[i].position):
			round = i
	if round < 0:
		return false
	var minimap := Minimap.new()
	add_child(minimap)
	minimap.bind_world(world)
	world.reveal_all()
	var image: Image = minimap._image
	var rect := map.rooms[round]
	var ok := image.get_pixelv(rect.position).a == 0.0 and _same_color(image.get_pixelv(map.heart(round)), Minimap.FLOOR_COLOR)
	for cell: Vector2i in map.features:
		var want := Minimap.WATER_COLOR if map.features[cell] == DungeonMap.Feature.POOL else Minimap.HOLE_COLOR
		ok = ok and _same_color(image.get_pixelv(cell), want)
	check(ok, "the minimap draws the round room %s as it is: rock corners empty, its floor, water and holes" % rect)
	minimap.queue_free()
	return ok


## The same color once stored in an image (8 bits a channel).
static func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


## Ground cells (no rock, chasm, pool or pillar) a walk from the start can't reach.
func _unreached_ground(map: DungeonMap) -> int:
	var seen := {map.start_cell: true}
	var queue: Array[Vector2i] = [map.start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_ground(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var lost := 0
	for y in map.height:
		for x in map.width:
			if map.is_ground(Vector2i(x, y)) and not seen.has(Vector2i(x, y)):
				lost += 1
	return lost


func _bad_walls(map: DungeonMap) -> Array[Vector2i]:
	var bad: Array[Vector2i] = []
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			var c := Vector2i(x, y)
			if map.is_floor(c):
				continue
			if DungeonGenerator.is_thin_wall(map, c, Vector2i.RIGHT) or DungeonGenerator.is_thin_wall(map, c, Vector2i.DOWN) \
					or DungeonGenerator._is_pinch(map, c):
				bad.append(c)
	for x in map.width:
		if map.is_floor(Vector2i(x, 0)) or map.is_floor(Vector2i(x, map.height - 1)):
			bad.append(Vector2i(x, 0))
	return bad
