class_name AmbushRoom
extends Node2D
## A room that looks quiet... until the hero walks in: spikes close the exits and monsters
## pour in, wave after wave (the last one led by an elite). Clear them all and the way opens,
## with a big chest as a reward. See DungeonConfig > Ambushes. PactRoom builds on it (its
## waves, its gates) through the hooks below (_wants_start(), _wave_count(), _wave_size(),
## _spawns_elite()).


enum State { WAITING, FIGHTING, CLEARED }

## Seconds between two monsters showing up, and before the next wave.
const SPAWN_INTERVAL := 0.25
const WAVE_PAUSE := 1.0
## Monsters appear at least this far from the hero.
const MIN_SPAWN_DISTANCE := 90.0

var state := State.WAITING
var room: Rect2i
var waves_left := 0

var _world: World
var _gates: RoomGates
var _to_spawn: Array[MonsterDef] = []
var _wave: Array[Monster] = []
var _spawn_timer := 0.0
var _pause_timer := 0.0
var _elite_in_wave := false
## Where its reward chest went once cleared (-1, -1: not yet). Saved with the floor (save_state).
var reward_cell := Vector2i(-1, -1)


func setup(world: World, ambush_room: Rect2i) -> void:
	_world = world
	room = ambush_room
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, room)


func is_closed() -> bool:
	return _gates.is_closed()


func get_gate_cells() -> Array[Vector2i]:
	return _gates.get_cells()


func start() -> void:
	if state != State.WAITING:
		return
	_begin_fight()
	Events.ambush_started.emit(self)


## The exits close and the first wave comes.
func _begin_fight() -> void:
	state = State.FIGHTING
	waves_left = _wave_count()
	_gates.close()
	Sfx.play_world(Sfx.bank.ambush, _world.player.global_position)
	Events.screen_shake.emit(0.6)
	_queue_wave()


func _wave_count() -> int:
	return _world.config().ambush_waves


func _wave_size() -> int:
	return _world.config().ambush_wave_size + floori(_world.depth / 3.0)


## Whether the monster about to come is an elite (the last wave is led by one).
func _spawns_elite() -> bool:
	if _elite_in_wave:
		_elite_in_wave = false
		return true
	return false


## The hero walked in: on solid ground only (a roll ending in a hole would put them back
## outside the gates).
func _wants_start() -> bool:
	var player := _world.player
	return player != null and player.is_grounded() and room.grow(-1).has_point(_world.map.world_to_cell(player.global_position))


func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			if _wants_start():
				start()
		State.FIGHTING:
			if not _to_spawn.is_empty():
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_timer = SPAWN_INTERVAL
					_spawn_one(_to_spawn.pop_back())
			elif _is_wave_dead():
				if waves_left <= 0:
					_finish()
					return
				_pause_timer -= delta
				if _pause_timer <= 0.0:
					_queue_wave()
			else:
				_pause_timer = WAVE_PAUSE


## Every monster of the wave is dead (most are already freed: they dissolve when they die).
func _is_wave_dead() -> bool:
	for monster: Variant in _wave:
		if is_instance_valid(monster) and not (monster as Monster).is_dead:
			return false
	return true


func _queue_wave() -> void:
	waves_left -= 1
	_wave.clear()
	_elite_in_wave = waves_left == 0  # the last wave is led by an elite
	for i in _wave_size():
		var def := _world.pick_monster()
		if def:
			_to_spawn.append(def)
	_spawn_timer = 0.0


func _spawn_one(def: MonsterDef) -> void:
	var monster := _world.spawn_monster(def, _spawn_point())
	if _spawns_elite():
		_world.make_elite(monster)
	monster.target = _world.player
	Vfx.puff(_world, monster.global_position)
	_wave.append(monster)


func _spawn_point() -> Vector2:
	var player_position := _world.player.global_position
	var point := _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
	for attempt in 10:
		if point.distance_to(player_position) >= MIN_SPAWN_DISTANCE and _world.is_solid_ground(point) \
				and not _world.nav.is_blocked(_world.map.world_to_cell(point)):  # furniture, water
			break
		point = _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
	# Ten misses (a round room's corners are rock): the nearest free cell, never inside the rock.
	if not _world.is_free_cell(_world.map.world_to_cell(point)):
		point = _world.nearest_free_point(point)
	return point


## Free solid ground near the middle of the room, not under the hero.
func _reward_cell() -> Vector2i:
	var center := room.get_center()
	var hero := _world.map.world_to_cell(_world.player.global_position) if _world.player else Vector2i(-99, -99)
	for radius in range(0, maxi(room.size.x, room.size.y)):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if maxi(absi(x - center.x), absi(y - center.y)) != radius or not room.grow(-1).has_point(cell):
					continue
				if (cell - hero).length_squared() > 2 and _world.is_free_cell(cell):
					return cell
	return center


func _finish() -> void:
	state = State.CLEARED
	_gates.open()
	var chest_def := _world.config().ambush_chest
	if chest_def:
		var cell := _reward_cell()
		reward_cell = cell
		Vfx.magic(_world, _world.map.cell_to_world(cell), Palette.GOLD)
		_world.spawn_chest(chest_def, cell, false)
	Events.ambush_cleared.emit(self)


## `monster` is one of the waves it is sending (an ambush under way).
func holds(monster: Monster) -> bool:
	return state == State.FIGHTING and _wave.has(monster)


## For the floor's save (World.spent_data()): cleared or not, and where its reward chest went.
## An ambush quit in the middle of its fight is saved as waiting: it starts over.
func save_state() -> Dictionary:
	if state != State.CLEARED:
		return {}
	return { "cleared": true, "reward": [reward_cell.x, reward_cell.y] }


## A resumed floor: an ambush cleared before quitting stays cleared (no waves, the exits open)
## and its reward chest is there again unless it was opened (`opened`: the floor's opened chests).
func restore_state(saved: Dictionary, opened: Array[Vector2i]) -> void:
	if not bool(saved.get("cleared", false)):
		return
	state = State.CLEARED
	waves_left = 0
	var cell: Variant = saved.get("reward")
	if not (cell is Array and (cell as Array).size() == 2):
		return
	reward_cell = Vector2i(int(cell[0]), int(cell[1]))
	var chest_def := _world.config().ambush_chest
	if chest_def and not opened.has(reward_cell):
		_world.spawn_chest(chest_def, reward_cell, false)
