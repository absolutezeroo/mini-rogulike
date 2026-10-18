class_name CrumblingFloor
extends Node2D
## A cracked floor cell (PitDef with a crumble time). Holds until someone walks on it,
## shakes for a moment, then gives way and becomes a hole.

enum State { SOLID, CRACKING }

var def: PitDef
var world: World
var cell: Vector2i
var state := State.SOLID

var _time_left := 0.0


func setup(pit_def: PitDef, floor_world: World, at_cell: Vector2i) -> void:
	def = pit_def
	world = floor_world
	cell = at_cell
	position = world.map.cell_to_world(cell)
	z_index = -9
	add_to_group("crumbling_floors")


func _physics_process(delta: float) -> void:
	match state:
		State.SOLID:
			if _someone_on_it():
				state = State.CRACKING
				_time_left = def.crumble_time
				Sfx.play_at(def.crack_sound, global_position, -4.0)
				Vfx.dust(world, global_position, 0.8)
		State.CRACKING:
			_time_left -= delta
			queue_redraw()
			if _time_left <= 0.0:
				collapse()


## Gives way now: the cell becomes a hole (whoever stands on it falls).
func collapse() -> void:
	if not is_inside_tree():
		return
	world.add_pit(cell, def)
	Sfx.play_at(def.crumble_sound, global_position)
	Vfx.burst(world, Vfx.DEATH_CHUNKS, global_position, def.debris_color)
	Vfx.dust(world, global_position, 1.5)
	queue_free()


func _someone_on_it() -> bool:
	for actor in world.get_actors():
		if actor.is_grounded() and world.map.world_to_cell(actor.global_position) == cell:
			return true
	return false


func _draw() -> void:
	if def.crack_texture == null:
		return
	var half := world.map.tile_size * 0.5
	var color := Color(1, 1, 1, 0.55)
	var offset := Vector2.ZERO
	if state == State.CRACKING:
		var t := 1.0 - _time_left / maxf(def.crumble_time, 0.01)
		color.a = 0.7 + 0.3 * t
		offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)) * (1.0 + 2.0 * t)
		# The edges darken as the floor sinks.
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0, 0, 0, 0.35 * t))
	draw_texture_rect(def.crack_texture, Rect2(Vector2(-half, -half) + offset, Vector2(half, half) * 2.0), false, color)
