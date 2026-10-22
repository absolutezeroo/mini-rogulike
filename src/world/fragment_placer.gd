class_name FragmentPlacer
## Lays a fragment of the past on a floor (NarrativeDef: its chance, when they start to appear):
## at most one a floor, on the floors of an act before its arena, about the warden waiting at
## its end this run (World.run_bosses), or about the hidden floor's warden on the acts that hide
## its way. Never one already found while that warden has others to find (Narrative.
## fragments_to_place()). On a free cell of a room, away from the start, never in a wall.
## Drawn from its own random numbers, so the rest of the floor stays as it was.


## Called by FloorPopulator once the floor is filled. Returns the fragment, or null.
static func place(world: World, content: ContentDB, depth: int, taken: Dictionary) -> Fragment:
	var narrative := content.narrative
	var config := content.dungeon
	if narrative == null or world.hidden_floor != null or world.arena != null or world.map.rooms.size() < 2:
		return null
	if config.boss_for_depth(depth) != null or not ProgressCondition.all_met(narrative.fragments_open):
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d-fragment-%d" % [world.rng.seed, depth])
	if rng.randf() >= narrative.fragment_chance:
		return null
	var choices: Array[Dictionary] = []  # { boss, fragment }
	for boss in wardens_ahead(world, config, depth):
		for fragment in Narrative.fragments_to_place(boss):
			choices.append({ "boss": boss, "fragment": fragment })
	if choices.is_empty():
		return null
	var pick: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
	var cell := _free_cell(world, rng, taken)
	if cell == DungeonMap.NO_CELL:
		return null
	taken[cell] = true
	return world.spawn_fragment(pick.fragment, pick.boss, cell)


## The wardens whose past may lie on floor `depth`: its act's warden this run, and the hidden
## floor's on the acts that hide its way.
static func wardens_ahead(world: World, config: DungeonConfig, depth: int) -> Array[BossDef]:
	var result: Array[BossDef] = []
	var index := config.act_index(depth)
	if index < 0:
		return result
	var boss := config.acts[index].boss
	if index < world.run_bosses.size() and world.run_bosses[index] != null:
		boss = world.run_bosses[index]
	if boss:
		result.append(boss)
	var hidden := config.hidden_floor
	if hidden and hidden.boss and hidden.key_acts.has(index) and not result.has(hidden.boss):
		result.append(hidden.boss)
	return result


## A free floor cell in a room other than the first (where the hero starts), not claimed.
static func _free_cell(world: World, rng: RandomNumberGenerator, taken: Dictionary) -> Vector2i:
	var map := world.map
	for attempt in 40:
		var room := map.rooms[rng.randi_range(1, map.rooms.size() - 1)]
		var cell := map.random_cell_in(room, rng)
		if taken.has(cell) or not world.is_free_cell(cell) or world.has_pit(cell):
			continue
		return cell
	return DungeonMap.NO_CELL
