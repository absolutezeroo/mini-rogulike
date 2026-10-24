class_name WorldSpace
extends RefCounted
## Questions about the floor's space, owned by the World (World.space) and asked through it (the
## World's methods of the same names): solid ground and free cells, where a body fits or can be
## put down, line of sight, and the per-frame answers many ask for (the actors, the part of the
## world on screen), worked out once per frame for everyone.

## Room a body put down on the floor needs around it (find_open_point_near()): the usual
## monsters' bodies, an elite's grown one included. A bigger one asks for its own radius.
const BODY_ROOM := 14.0

var _world: World
var _actors_frame := -1
var _actors_cache: Array[Actor] = []
var _actors_step := -1
var _actors_in_step: Array[Actor] = []
## body_fits()'s query, kept between calls.
var _fit_query: PhysicsShapeQueryParameters2D
var _view_frame := -1
var _view_cache := Rect2()


func _init(world: World) -> void:
	_world = world


## Room for the body of a monster of `def`, put down by find_open_point_near().
static func room_for(def: MonsterDef) -> float:
	return maxf(BODY_ROOM, def.radius) if def else BODY_ROOM


## Whether `point` lies within one of `bodies` (its radius + `clearance`).
static func is_under_body(point: Vector2, bodies: Array[Actor], clearance: float) -> bool:
	for body in bodies:
		if is_instance_valid(body) and not body.is_dead and point.distance_to(body.global_position) < body.radius + clearance:
			return true
	return false


## Floor that can't give way: no wall, no hole, no cracked floor.
func is_solid_ground(point: Vector2) -> bool:
	var cell := _world.map.world_to_cell(point)
	return _world.map.is_floor(cell) and not _world.holes.is_unsafe(cell)


## Solid ground nothing stands on (no wall, hole, crack, chest, encounter, prop...).
func is_free_cell(cell: Vector2i) -> bool:
	return is_solid_ground(_world.map.cell_to_world(cell)) and not _world.nav.is_blocked(cell)


## The centre of the free cell nearest to `point` (itself if free; `point` if none is found).
## `clear_of`: bodies the cell must also be clear of (by their radius + `clearance`). `room`: a
## body of that radius must fit at the centre (body_fits(); 0: any free cell).
func nearest_free_point(point: Vector2, max_radius: int = 12, clear_of: Array[Actor] = [], clearance: float = 0.0, room: float = 0.0) -> Vector2:
	var map := _world.map
	var origin := map.world_to_cell(point)
	for radius in max_radius + 1:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(origin.y - radius, origin.y + radius + 1):
			# Only the ring at this radius (its top and bottom rows whole, its sides' two cells
			# between), in the square's reading order: ties go to the same cell.
			var edge_row := absi(y - origin.y) == radius
			var x := origin.x - radius
			while x <= origin.x + radius:
				var cell := Vector2i(x, y)
				x = x + 1 if edge_row or radius == 0 else x + 2 * radius
				var at := map.cell_to_world(cell)
				var distance := at.distance_squared_to(point)
				if distance < best_distance and is_free_cell(cell) and not is_under_body(at, clear_of, clearance) \
						and (room <= 0.0 or body_fits(at, room)):
					best = cell
					best_distance = distance
		if best != Vector2i(-1, -1):
			return map.cell_to_world(best)
	return point


## A walkable point about `distance` away from `center`, in sight of it, where a body of
## `room` px fits: never over a hole or cracked floor, never into a wall's, a prop's or a pond's
## shape (a body put down inside one may never get out), nor into another living body (the
## physics would shove the two apart on the first frame, maybe into a wall). Else `center` if a
## body fits there, else the nearest free cell's centre where it fits clear of the others (then
## where it fits, then any free cell). Rolls on the floor's dice.
func find_open_point_near(center: Vector2, distance: float, room: float = BODY_ROOM) -> Vector2:
	var bodies := _world.get_actors()
	for attempt in 10:
		var point := center + Vector2.from_angle(_world.rng.randf() * TAU) * distance
		if is_solid_ground(point) and has_line_of_sight(center, point) and body_fits(point, room) and not is_under_body(point, bodies, room):
			return point
	if is_solid_ground(center) and body_fits(center, room) and not is_under_body(center, bodies, room):
		return center
	for clear_of: Array[Actor] in [bodies, [] as Array[Actor]]:
		var fitting := nearest_free_point(center, 12, clear_of, room, room)
		if fitting != center or (is_free_cell(_world.map.world_to_cell(center)) and body_fits(center, room)):
			return fitting
	return nearest_free_point(center)


## Nothing that stops a body (walls, props, chests, ponds...) within `radius` of `point`.
## (One shape and one query, kept: it runs for every candidate while a floor is laid.)
func body_fits(point: Vector2, radius: float = BODY_ROOM) -> bool:
	if _fit_query == null:
		_fit_query = PhysicsShapeQueryParameters2D.new()
		_fit_query.shape = CircleShape2D.new()
		_fit_query.collision_mask = Layers.WORLD | Layers.WATER
	(_fit_query.shape as CircleShape2D).radius = radius
	_fit_query.transform = Transform2D(0.0, point)
	return _world.get_world_2d().direct_space_state.intersect_shape(_fit_query, 1).is_empty()


## `exclude`: bodies the ray goes through (the thing looked at, solid itself: the merchant...).
func has_line_of_sight(from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD, exclude)
	return _world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## World.get_actors(), worked out once per frame for everyone who asks (plants, quicksand, cracked
## floor...). Read only: the same array is handed to everyone. One list per physics step and
## one per drawn frame (the bodies freed after a physics step are gone from the next list).
func actors_this_frame() -> Array[Actor]:
	if Engine.is_in_physics_frame():
		var step := Engine.get_physics_frames()
		if step != _actors_step:
			_actors_step = step
			_actors_in_step = _world.get_actors()
		return _actors_in_step
	var frame := Engine.get_process_frames()
	if frame != _actors_frame:
		_actors_frame = frame
		_actors_cache = _world.get_actors()
	return _actors_cache


## The part of the world on screen (with a margin), once per frame: what lies outside needn't
## be redrawn.
func view_rect(margin: float = 96.0) -> Rect2:
	var frame := Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var camera := _world.get_viewport().get_camera_2d() if _world.is_inside_tree() else null
		if camera:
			var half := _world.get_viewport().get_visible_rect().size / camera.zoom * 0.5
			_view_cache = Rect2(camera.get_screen_center_position() - half, half * 2.0)
		else:
			_view_cache = Rect2(-1e6, -1e6, 2e6, 2e6)
	return _view_cache.grow(margin)
