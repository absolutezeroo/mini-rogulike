class_name BossArena
extends Node2D
## The boss room of a boss floor. The boss sleeps in the middle; when the player walks in,
## spikes close the exits (RoomGates) and the fight starts. When the boss dies the spikes go down
## and the stairs appear where it stood.
## Its plan (ArenaDef) gives it a shape and pillars, and changes it as the boss enters its next
## phases (ArenaShiftDef): the cells blink red, then crumble, open into pits or grow spikes.

## How far from the hero and the boss a change keeps clear (cells).
const KEEP_CLEAR := 1

var boss: Monster
var is_started := false
var is_defeated := false
## Changes already made (one per phase).
var shifts_done := 0

var _world: World
var _room: Rect2i
var _gates: RoomGates
var _plan: ArenaDef


func setup(world: World, boss_def: BossDef, plan: ArenaDef = null) -> void:
	_world = world
	_plan = plan
	_room = world.map.boss_room
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, _room)

	boss = world.spawn_monster(boss_def, world.map.cell_to_world(_room.get_center()))
	world.roll_boss_rank(boss)
	boss.dormant = true
	boss.facing = Vector2.DOWN
	boss.died.connect(_on_boss_died)
	boss.phase_entered.connect(_on_phase_entered)
	_place_pillars()


## The plan's pillars, where the floor is (never in the middle, where the boss stands).
func _place_pillars() -> void:
	if _plan == null or _plan.pillar == null:
		return
	var center := _room.get_center()
	for at in _plan.pillars:
		var cell := _room.position + Vector2i(roundi(at.x * (_room.size.x - 1)), roundi(at.y * (_room.size.y - 1)))
		if _world.map.is_floor(cell) and (cell - center).length() > 3.5:
			_world.spawn_prop(_plan.pillar, cell)


## The arena's floor cells (no pillar, no hole), for its changes.
func floor_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(_room.position.y, _room.end.y):
		for x in range(_room.position.x, _room.end.x):
			var cell := Vector2i(x, y)
			if _world.map.is_floor(cell) and not _world.nav.is_blocked(cell) and not _world.has_pit(cell):
				result.append(cell)
	return result


func _on_phase_entered(index: int) -> void:
	if _plan == null or index - 1 >= _plan.shifts.size() or index <= shifts_done:
		return
	shifts_done = index
	shift(_plan.shifts[index - 1])


## Changes the arena: a warning on the cells, then they become what the change says.
func shift(change: ArenaShiftDef) -> void:
	var keep: Array[Vector2i] = [_room.get_center()]
	for actor: Actor in [_world.player, boss]:
		if actor and is_instance_valid(actor):
			keep.append(_world.map.world_to_cell(actor.global_position))
	var ground := {}
	for y in range(_room.position.y, _room.end.y):
		for x in range(_room.position.x, _room.end.x):
			if _world.map.is_floor(Vector2i(x, y)):
				ground[Vector2i(x, y)] = true
	var cells := change.pick_cells(floor_cells(), _room, keep, KEEP_CLEAR, _world.rng, ground)
	if cells.is_empty():
		return
	if not change.message.is_empty():
		Events.log_message(tr(change.message), Palette.DANGER)
		_world.spawn_floating_text(boss.head_position() + Vector2(0, -28), tr(change.message).to_upper(), Palette.DANGER)
	var warning := CellWarning.create(cells, _world.map.tile_size, change.warning_time)
	_world.spawn_vfx(warning)
	var floor_id := _world.floor_id
	await get_tree().create_timer(change.warning_time, false).timeout
	if not is_instance_valid(_world) or _world.floor_id != floor_id:
		return
	Events.screen_shake.emit(0.5)
	Sfx.play_at(Sfx.bank.explosion if change.becomes != ArenaShiftDef.Becomes.SPIKES else Sfx.bank.ambush, _world.map.cell_to_world(_room.get_center()), -6.0)
	var cycle := 0.0
	for cell in cells:
		match change.becomes:
			ArenaShiftDef.Becomes.PIT:
				if change.pit:
					_world.add_pit(cell, change.pit)
			ArenaShiftDef.Becomes.CRUMBLE:
				if change.pit:
					_world.spawn_crumbling_floor(change.pit, cell)
			ArenaShiftDef.Becomes.SPIKES:
				if change.trap:
					_world.spawn_trap(change.trap, cell, cycle)
					cycle += 0.08


## Cells just outside the room that are floor: the openings to close.
func get_gate_cells() -> Array[Vector2i]:
	return _gates.get_cells()


func is_closed() -> bool:
	return _gates.is_closed()


func start() -> void:
	if is_started or boss == null or boss.is_dead:
		return
	is_started = true
	# Shut in together only: a boss woken from the doorway (a bow shot...) and lured out
	# must not end up locked outside its own room.
	if _is_inside(boss.global_position) and _is_inside(_world.player.global_position):
		_gates.close()
	boss.wake_up(_world.player)
	Sfx.play_at(Sfx.bank.boss_roar, boss.global_position)
	Events.screen_shake.emit(0.8)
	Events.boss_started.emit(boss)


## The fight starts once the player is well inside the room (checked every frame: simple and exact).
func _physics_process(_delta: float) -> void:
	if is_started or _world == null:
		return
	var player := _world.player
	if player == null or player.is_dead:
		return
	if _is_inside(player.global_position) or (boss and not boss.dormant):
		start()


func _is_inside(point: Vector2) -> bool:
	return _room.grow(-1).has_point(_world.map.world_to_cell(point))


func _on_boss_died(_actor: Actor) -> void:
	is_defeated = true
	_finish.call_deferred()


func _finish() -> void:
	_gates.open()
	_world.spawn_exits()
	_world.reward_clear()
	Vfx.magic(_world, _world.map.cell_to_world(_room.get_center()), Palette.GOLD)
	Events.boss_defeated.emit(boss)
