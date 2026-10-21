class_name ThresholdWorld
extends World
## The limbo of the Threshold (ThresholdDef), built beside the floor while the floor waits out of
## the tree: one bare arena in the mist, its own light, no stairs, no seal, no loot. Every monster
## in it is a spectre (pale, see-through, worth nothing: no XP, gold or loot), and new ones keep
## rising around the hero while `spectres_wanted` is above zero. The trial's rules (kills, time)
## are the Threshold's.

## A spectre rose (for the tests and the look).
signal spectre_risen(monster: Monster)

## How many spectres should stand at once (0: none rise any more).
var spectres_wanted := 0
var trial: ThresholdDef

var _spawn_timer := 0.0


## The limbo for a hero who fell on `fell_depth`: `trial`'s arena, theme and light. The floor's
## difficulty and boons must be set before (the spectres scale with them like the floor's monsters).
func build_trial(fell_depth: int, content: ContentDB, threshold: ThresholdDef, seed_value: int) -> void:
	clear_floor()
	floor_id += 1
	trial = threshold
	depth = fell_depth
	_content = content
	rng.seed = seed_value
	floor_event = null
	curse = null
	biome = null
	route = null
	arena_plan = null
	next_routes.clear()
	opened_chests.clear()
	bought.clear()
	theme = trial.theme
	map = make_map(trial, content.dungeon)
	rules = FloorRules.make(content.dungeon, difficulty, null, depth)
	_view.show_map(map, theme)
	lights.setup(map, trial.lighting if trial.lighting else (theme.lighting if theme else null), trial.light_tint)
	_view.mist.bind_light(lights)
	_pits.setup(map.tile_size)
	fog.reset(map)
	stairs_cells.clear()
	WallBuilder.build(map, _walls)
	nav.build(map)
	seal.clear()
	_place_pillars()
	map_reset.emit()


## The hero arrives in the middle of the limbo. Not place_player(): he has not left his floor,
## so no "new floor" perk wakes up (Guardian Ring's ward...).
func take_in(hero: Player) -> void:
	player = hero
	hero.world = self
	if hero.get_parent():
		hero.get_parent().remove_child(hero)
	_entities.add_child(hero)
	hero.global_position = map.cell_to_world(map.start_cell)
	hero.reset_safe_position()
	hero.camera.reset_smoothing()


## The hero leaves (back to his floor): out of the tree here, nothing else changed.
func let_go(hero: Player) -> void:
	spectres_wanted = 0
	if hero.get_parent() == _entities:
		_entities.remove_child(hero)
	player = null


## One arena (the trial's plan) in the middle of `margin` cells of mist; the hero starts in its
## middle.
static func make_map(threshold: ThresholdDef, config: DungeonConfig) -> DungeonMap:
	var plan := threshold.arena
	var size := plan.size if plan else Vector2i(19, 13)
	var margin := threshold.margin
	var result := DungeonMap.new(size.x + margin * 2, size.y + margin * 2, config.tile_size)
	var room := Rect2i(Vector2i(margin, margin), size)
	if plan:
		for cell in plan.cells(room.position):
			result.set_floor(cell)
	else:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				result.set_floor(Vector2i(x, y))
	DungeonGenerator.smooth(result)
	result.rooms.append(room)
	result.boss_room = room
	result.start_cell = room.get_center()
	result.stairs_cell = room.get_center()
	return result


## The plan's pillars (the limbo's pale lamps), never in the middle where the hero stands.
func _place_pillars() -> void:
	var plan := trial.arena
	if plan == null or plan.pillar == null:
		return
	var room := map.boss_room
	for at in plan.pillars:
		var cell := room.position + Vector2i(roundi(at.x * (room.size.x - 1)), roundi(at.y * (room.size.y - 1)))
		if map.is_floor(cell) and (cell - room.get_center()).length() > 2.5:
			spawn_prop(plan.pillar, cell)


## Everything that appears here is a spectre (summons too): pale, weaker, worth nothing.
func spawn_monster(def: MonsterDef, at: Vector2) -> Monster:
	var monster := super.spawn_monster(def, at)
	make_spectral(monster)
	return monster


func make_spectral(monster: Monster) -> void:
	monster.summoned = true  # no XP, gold, loot, bestiary kill or "on kill" heal
	if trial == null:
		return
	monster.base_stats = monster.base_stats.duplicate()
	monster.base_stats.max_hp = maxi(1, roundi(monster.base_stats.max_hp * trial.monster_health))
	monster.invalidate_stats()
	monster.hp = monster.get_max_hp()
	monster.body_color = monster.body_color.lerp(trial.spectral_color, trial.spectral_pallor)
	monster.modulate = Color(1, 1, 1, trial.spectral_alpha)
	if monster.rig:
		monster.rig.pallor = trial.spectral_pallor
		monster.rig.pallor_color = trial.spectral_color


## Spectres alive here.
func spectre_count() -> int:
	return monster_count()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if spectres_wanted <= 0 or player == null or player.is_dead:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and spectre_count() < spectres_wanted:
		_spawn_timer = trial.spawn_every
		raise_spectre()


## A spectre rises from the mist somewhere in the arena, away from the hero, and comes for him.
func raise_spectre() -> Monster:
	var def := trial.pick_monster(_content, depth, rng)
	if def == null or player == null:
		return null
	var at := _spawn_point()
	var monster := spawn_monster(def, at)
	monster.wake_up(player)
	Vfx.puff(self, at)
	Vfx.sparkles(self, at, trial.spectral_color)
	Sfx.play_at(Sfx.bank.monster_alert, at, -8.0, 0.7)
	spectre_risen.emit(monster)
	return monster


func _spawn_point() -> Vector2:
	var room := map.boss_room
	var hero := map.world_to_cell(player.global_position)
	var fallback := map.cell_to_world(room.get_center())
	for attempt in 40:
		var cell := map.random_cell_in(room, rng, 1)
		if Vector2(cell - hero).length() >= trial.spawn_distance and is_free_cell(cell):
			return map.cell_to_world(cell)
		if is_free_cell(cell):
			fallback = map.cell_to_world(cell)
	return fallback
