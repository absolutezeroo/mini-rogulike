class_name RoomGates
extends Node2D
## Spikes that rise across the exits of a room to lock fights in (boss arenas, ambushes)
## and go back down once it is over.

const GATE_TIME := 0.25

var _world: World
var _cells: Array[Vector2i] = []
var _body: StaticBody2D
var _texture: Texture2D
## 0 = spikes down, 1 = spikes up.
var _amount := 0.0


func setup(world: World, room: Rect2i) -> void:
	_world = world
	_texture = world.theme.gate_texture() if world.theme else null
	_cells = _find_exits(room)


## Cells just outside the room that are floor: the openings to close.
func get_cells() -> Array[Vector2i]:
	return _cells


func is_closed() -> bool:
	return _body != null


## `quiet`: at once, without a sound (a door sealed from the start: PactRoom).
func close(quiet: bool = false) -> void:
	if _body:
		return
	_body = StaticBody2D.new()
	_body.collision_layer = Layers.WORLD
	_body.collision_mask = 0
	var ts := float(_world.map.tile_size)
	for cell in _cells:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(ts, ts)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = _world.map.cell_to_world(cell)
		_body.add_child(collision)
		_world.set_cell_blocked(cell, true)
	add_child.call_deferred(_body)  # may happen inside a physics callback
	if quiet:
		_amount = 1.0
		queue_redraw()
		return
	Sfx.play_world(Sfx.bank.gate, _world.player.global_position if _world.player else global_position)
	create_tween().tween_property(self, "_amount", 1.0, GATE_TIME)


func open(quiet: bool = false) -> void:
	if _body == null:
		return
	_body.queue_free()
	_body = null
	for cell in _cells:
		_world.set_cell_blocked(cell, false)
	if quiet:
		_amount = 0.0
		queue_redraw()
		return
	Sfx.play_world(Sfx.bank.gate, _world.player.global_position if _world.player else global_position)
	create_tween().tween_property(self, "_amount", 0.0, GATE_TIME)


func _find_exits(room: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ring := room.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var cell := Vector2i(x, y)
			if not room.has_point(cell) and _world.map.is_floor(cell):
				cells.append(cell)
	return cells


func _process(_delta: float) -> void:
	if _amount > 0.0:
		queue_redraw()


func _draw() -> void:
	if _amount <= 0.0 or _texture == null:
		return
	var ts := float(_world.map.tile_size)
	var rise := (1.0 - _amount) * ts * 0.5
	for cell in _cells:
		var rect := Rect2(Vector2(cell) * ts + Vector2(0, rise), Vector2(ts, ts))
		draw_texture_rect(_texture, rect, false, Color(1, 1, 1, _amount))
