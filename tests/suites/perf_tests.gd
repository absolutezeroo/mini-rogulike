class_name PerfTests
extends TestSuite
## The performance work's shortcuts give the answers the plain ways gave (docs/performance.md):
## a cache or a smaller loop must never change what the game decides or shows.


## No game running (from UnitTests).
func run_unit() -> void:
	# Input names by slot, as constants: one per slot, each a real action.
	check(Player.SKILL_ACTIONS.size() == Player.SKILL_COUNT, "one skill action per skill slot")
	check(Player.BELT_ACTIONS.size() == Belt.SLOTS, "one belt action per belt slot")
	var missing: Array[String] = []
	for i in Player.SKILL_ACTIONS.size():
		if Player.SKILL_ACTIONS[i] != StringName("skill_%d" % (i + 1)) or not InputMap.has_action(Player.SKILL_ACTIONS[i]):
			missing.append(String(Player.SKILL_ACTIONS[i]))
	for i in range(1, Player.BELT_ACTIONS.size()):  # (slot 1 is the quick item's own action)
		if Player.BELT_ACTIONS[i] != StringName("belt_%d" % (i + 1)) or not InputMap.has_action(Player.BELT_ACTIONS[i]):
			missing.append(String(Player.BELT_ACTIONS[i]))
	check(missing.is_empty(), "the skill and belt actions are the project's (wrong: %s)" % ", ".join(missing))
	var four: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	check(GridDirs.FOUR == four, "the grid's four steps keep their order (it decides ties: the same seed, the same floor)")
	_test_body_tops()


## The weapon at rest bobs with the body's art (ActorRig._bob): every frame of the hero measured
## on its sheet's copy, read back once, gives the top row a readback of the frame itself gives.
func _test_body_tops() -> void:
	var frames: SpriteFrames = load("res://data/visuals/hero.tres")
	ActorRig.warm_tops(frames)
	var wrong: Array[String] = []
	var measured := 0
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, i)
			var image := texture.get_image()
			if image == null:
				continue
			if image.is_compressed():
				image.decompress()
			measured += 1
			if ActorRig._top_of(texture) != image.get_used_rect().position.y:
				wrong.append("%s %d" % [animation, i])
	check(measured > 0, "the hero's frames can be measured here (%d)" % measured)
	check(wrong.is_empty(), "each body frame's top measured on its sheet's copy is its own (wrong: %s)" % ", ".join(wrong.slice(0, 5)))


## On the game's floor (from GameTests): the monsters' spacing and the free points.
## Its own rats only, freed after: the floor's monsters stay for the bot's hunt.
func run_in_game(world: World, player: Player) -> void:
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	var spawned: Array[Monster] = []
	for i in 24:
		var at := world.nearest_free_point(player.global_position + Vector2.from_angle(TAU * i / 24.0) * (60.0 + 6.0 * (i % 5)))
		spawned.append(world.spawn_monster(rat, at))
	await _frames(15)  # (they wake and crowd)
	_check_buckets(world)
	_check_nearest_free_point(world, player)
	for monster in spawned:
		if is_instance_valid(monster):
			monster.queue_free()
	await _frames(2)


## Every monster close enough to push another (Monster._keep_spacing) is among those its grid
## cells hand it, in the awake list's order: the push sums the same floats as over the whole list.
func _check_buckets(world: World) -> void:
	var awake := world.activity.awake
	check(awake.size() >= 10, "a crowd is awake for the spacing check (%d)" % awake.size())
	var missed := 0
	var unsorted := 0
	for entry: Variant in awake:
		if not is_instance_valid(entry):
			continue
		var monster := entry as Monster
		var near := world.activity.buckets.near(awake, monster.global_position, monster.radius + Monster.SPACING)
		for i in range(1, near.size()):
			if near[i] <= near[i - 1]:
				unsorted += 1
		for j in awake.size():
			var other: Variant = awake[j]
			if not is_instance_valid(other) or other == monster:
				continue
			var limit := monster.radius + (other as Monster).radius + Monster.SPACING
			if monster.global_position.distance_to((other as Monster).global_position) < limit and not near.has(j):
				missed += 1
	check(missed == 0, "the spacing grid hands every monster all those close enough to push it (%d missed)" % missed)
	check(unsorted == 0, "and in the awake list's order")


## World.nearest_free_point() walks only its rings' cells now: the same cell as the whole square's
## scan in reading order (ties included) for points all over the floor.
func _check_nearest_free_point(world: World, player: Player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bodies := world.get_actors()
	var differ := 0
	for attempt in 60:
		var point := Vector2(rng.randf() * world.map.width, rng.randf() * world.map.height) * world.map.tile_size
		var room := 10.0 if attempt % 3 == 0 else 0.0
		var clear_of: Array[Actor] = bodies if attempt % 2 == 0 else ([] as Array[Actor])
		if world.nearest_free_point(point, 12, clear_of, room, room) != _square_scan(world, point, 12, clear_of, room, room):
			differ += 1
	check(differ == 0, "the nearest free point is the square scan's (%d of 60 differ)" % differ)
	check(world.nearest_free_point(player.global_position, 0) != Vector2.INF, "a ring of radius 0 is the cell itself")


## nearest_free_point() as it was written first: the whole square at each radius, the ring kept.
func _square_scan(world: World, point: Vector2, max_radius: int, clear_of: Array[Actor], clearance: float, room: float) -> Vector2:
	var map := world.map
	var origin := map.world_to_cell(point)
	for radius in max_radius + 1:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != radius:
					continue
				var cell := Vector2i(x, y)
				var distance := map.cell_to_world(cell).distance_squared_to(point)
				if distance < best_distance and world.is_free_cell(cell) and not WorldSpace.is_under_body(map.cell_to_world(cell), clear_of, clearance) \
						and (room <= 0.0 or world.body_fits(map.cell_to_world(cell), room)):
					best = cell
					best_distance = distance
		if best != Vector2i(-1, -1):
			return map.cell_to_world(best)
	return point
