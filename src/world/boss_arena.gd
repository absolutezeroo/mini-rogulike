class_name BossArena
extends Node2D
## The boss room of a boss floor. The boss sleeps in the middle; when the player walks in,
## spikes close the exits and the fight starts. When the boss dies the spikes go down
## and the stairs appear where it stood.

signal started(boss: Monster)
signal defeated(boss: Monster)

const GATE_TIME := 0.25

var boss: Monster
var is_started := false
var is_defeated := false

var _world: World
var _room: Rect2i
var _gate_cells: Array[Vector2i] = []
var _gate_body: StaticBody2D
var _gate_texture: Texture2D
## 0 = spikes down, 1 = spikes up.
var _gate_amount := 0.0

@onready var _trigger: Area2D = $Trigger


func setup(world: World, boss_def: BossDef) -> void:
	_world = world
	_room = world.map.boss_room
	_gate_texture = world.theme.gate_texture() if world.theme else null
	_gate_cells = _find_exits()

	boss = world.spawn_monster(boss_def, world.map.cell_to_world(_room.get_center()))
	boss.dormant = true
	boss.facing = Vector2.DOWN
	boss.died.connect(_on_boss_died)

	# The fight starts once the player is well inside the room.
	var ts := float(world.map.tile_size)
	var inner := _room.grow(-1)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(inner.size) * ts
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = (Vector2(inner.position) + Vector2(inner.size) * 0.5) * ts
	_trigger.add_child(collision)
	_trigger.collision_layer = 0
	_trigger.collision_mask = Layers.PLAYER
	_trigger.body_entered.connect(_on_body_entered)


## Cells just outside the room that are floor: the openings to close.
func get_gate_cells() -> Array[Vector2i]:
	return _gate_cells


func is_closed() -> bool:
	return _gate_body != null


func start() -> void:
	if is_started or boss == null or boss.is_dead:
		return
	is_started = true
	_close_gates()
	boss.wake_up(_world.player)
	Sfx.play_at(Sfx.bank.boss_roar, boss.global_position)
	if _world.player:
		_world.player.camera.shake(0.8)
	started.emit(boss)
	Events.boss_started.emit(boss)


func _find_exits() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ring := _room.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var cell := Vector2i(x, y)
			if not _room.has_point(cell) and _world.map.is_floor(cell):
				cells.append(cell)
	return cells


func _close_gates() -> void:
	_gate_body = StaticBody2D.new()
	_gate_body.collision_layer = Layers.WORLD
	_gate_body.collision_mask = 0
	var ts := float(_world.map.tile_size)
	for cell in _gate_cells:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(ts, ts)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = _world.map.cell_to_world(cell)
		_gate_body.add_child(collision)
	add_child.call_deferred(_gate_body)  # may happen inside a physics callback
	Sfx.play_at(Sfx.bank.gate, _world.player.global_position if _world.player else global_position)
	create_tween().tween_property(self, "_gate_amount", 1.0, GATE_TIME)


func _open_gates() -> void:
	if _gate_body:
		_gate_body.queue_free()
		_gate_body = null
	Sfx.play_at(Sfx.bank.gate, global_position)
	create_tween().tween_property(self, "_gate_amount", 0.0, GATE_TIME)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		start.call_deferred()


func _on_boss_died(_actor: Actor) -> void:
	is_defeated = true
	_finish.call_deferred()


func _finish() -> void:
	_open_gates()
	_world.spawn_stairs(_room.get_center())
	Vfx.magic(_world, _world.map.cell_to_world(_room.get_center()), Color("ffd166"))
	defeated.emit(boss)
	Events.boss_defeated.emit(boss)


func _process(_delta: float) -> void:
	if is_started:
		queue_redraw()


func _draw() -> void:
	if _gate_amount <= 0.0 or _gate_texture == null:
		return
	var ts := float(_world.map.tile_size)
	var rise := (1.0 - _gate_amount) * ts * 0.5
	for cell in _gate_cells:
		var rect := Rect2(Vector2(cell) * ts + Vector2(0, rise), Vector2(ts, ts))
		draw_texture_rect(_gate_texture, rect, false, Color(1, 1, 1, _gate_amount))
