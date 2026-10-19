class_name BossArena
extends Node2D
## The boss room of a boss floor. The boss sleeps in the middle; when the player walks in,
## spikes close the exits (RoomGates) and the fight starts. When the boss dies the spikes go down
## and the stairs appear where it stood.

signal started(boss: Monster)
signal defeated(boss: Monster)

var boss: Monster
var is_started := false
var is_defeated := false

var _world: World
var _room: Rect2i
var _gates: RoomGates


func setup(world: World, boss_def: BossDef) -> void:
	_world = world
	_room = world.map.boss_room
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, _room)

	boss = world.spawn_monster(boss_def, world.map.cell_to_world(_room.get_center()))
	boss.dormant = true
	boss.facing = Vector2.DOWN
	boss.died.connect(_on_boss_died)


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
	started.emit(boss)
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
	_world.spawn_stairs(_room.get_center())
	Vfx.magic(_world, _world.map.cell_to_world(_room.get_center()), Color("ffd166"))
	defeated.emit(boss)
	Events.boss_defeated.emit(boss)
