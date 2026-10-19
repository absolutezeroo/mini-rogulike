class_name AmbushRoom
extends Node2D
## A room that looks quiet... until the hero walks in: spikes close the exits and monsters
## pour in, wave after wave (the last one led by an elite). Clear them all and the way opens,
## with a big chest as a reward. See DungeonConfig > Ambushes.

signal triggered
signal cleared

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
	state = State.FIGHTING
	waves_left = _world.config().ambush_waves
	_gates.close()
	Sfx.play_at(Sfx.bank.ambush, _world.player.global_position)
	_world.player.camera.shake(0.6)
	_queue_wave()
	triggered.emit()
	Events.ambush_started.emit(self)


func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			var player := _world.player
			# On solid ground only: a roll ending in a hole would put the hero back outside the gates.
			if player and player.is_grounded() and room.grow(-1).has_point(_world.map.world_to_cell(player.global_position)):
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
	var count := _world.config().ambush_wave_size + floori(_world.depth / 3.0)
	for i in count:
		var def := _world.pick_monster()
		if def:
			_to_spawn.append(def)
	_spawn_timer = 0.0


func _spawn_one(def: MonsterDef) -> void:
	var monster := _world.spawn_monster(def, _spawn_point())
	if _elite_in_wave:
		_elite_in_wave = false
		_world.make_elite(monster)
	monster.target = _world.player
	Vfx.puff(_world, monster.global_position)
	_wave.append(monster)


func _spawn_point() -> Vector2:
	var player_position := _world.player.global_position
	var point := _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
	for attempt in 10:
		if point.distance_to(player_position) >= MIN_SPAWN_DISTANCE and _world.is_solid_ground(point):
			break
		point = _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
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
		Vfx.magic(_world, _world.map.cell_to_world(cell), Color("ffd166"))
		_world.spawn_chest(chest_def, cell, false)
	cleared.emit()
	Events.ambush_cleared.emit(self)
