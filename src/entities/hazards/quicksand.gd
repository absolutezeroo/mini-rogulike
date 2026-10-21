class_name Quicksand
extends Node2D
## A pool of quicksand built from a QuicksandDef: slows whoever wades in, then hurts them
## if they stay. Checked every frame against every actor (a handful of pools, a few actors).

var def: QuicksandDef
var world: World
var radius := 30.0

var _anim_time := 0.0
## Actor instance id -> seconds spent in the pool.
var _time_in := {}
var _next_tick := {}


func setup(sand_def: QuicksandDef, floor_world: World, rect: Rect2i) -> void:
	def = sand_def
	world = floor_world
	var ts := float(world.map.tile_size)
	position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * ts
	radius = minf(rect.size.x, rect.size.y) * ts * 0.5 - 4.0
	z_index = -9
	add_to_group("quicksand")


## True if `actor` stands in the pool.
func contains(actor: Actor) -> bool:
	return actor.global_position.distance_to(global_position) <= radius


func _physics_process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()
	for actor in world.get_actors():
		var id := actor.get_instance_id()
		if not actor.is_grounded() or not contains(actor):
			_time_in.erase(id)
			_next_tick.erase(id)
			continue
		actor.statuses.apply_slow(def.slow, 0.2, StatusSet.GROUND_SLOW)
		var time: float = _time_in.get(id, 0.0) + delta
		_time_in[id] = time
		if time < def.sink_delay:
			continue
		var tick: float = _next_tick.get(id, 0.0) - delta
		if tick <= 0.0:
			tick = def.tick_interval
			actor.take_hit(Combat.make_tick(null, world.rules.dungeon_damage(def.damage, 0.5)))
			Sfx.play_world(def.sink_sound, actor.global_position, -6.0)
			Vfx.dust(world, actor.global_position, 0.7)
		_next_tick[id] = tick


func _draw() -> void:
	if def.sheet == null:
		draw_circle(Vector2.ZERO, radius, Color("c8a165"))
		return
	var frame_size := def.sheet.get_height()
	var frames := maxi(def.sheet.get_width() / frame_size, 1)
	var frame := int(_anim_time * def.fps) % frames
	var size := Vector2.ONE * frame_size * 2.0
	draw_texture_rect_region(def.sheet, Rect2(-size * 0.5, size), Rect2(frame * frame_size, 0, frame_size, frame_size), def.icon_tint)
