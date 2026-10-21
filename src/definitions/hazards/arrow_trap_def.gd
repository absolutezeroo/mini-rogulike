class_name ArrowTrapDef
extends TrapDef
## A pressure plate wired to an arrow slit in a wall: step on it and arrows fly across the room
## along the plate's line. They hit anyone in the way, monsters included.
## Uses the TrapDef timing (warning_time = the click before the shots) and damage.

## The slit in the wall the arrows come out of (16x16, drawn at 2x).
@export var launcher_texture: Texture2D
@export var arrow_texture: Texture2D
@export_range(1, 10) var arrows: int = 3
## Seconds between two arrows of a volley.
@export var arrow_interval: float = 0.14
@export var arrow_speed: float = 430.0
## The slit is at most this many cells away from the plate.
@export_range(2, 20) var max_range: int = 9

## Walls an arrow slit can be in: up (its face looks at the room) and the sides.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]


func on_fire(trap: Trap) -> void:
	var world := trap.world
	var spec := ProjectileSpec.new()
	spec.damage = damage_on(world)
	spec.speed = arrow_speed
	spec.radius = 5.0
	spec.max_distance = (max_range + 4) * world.map.tile_size
	spec.knockback = knockback
	spec.texture = arrow_texture
	spec.texture_frames = 1  # one arrow, not a strip
	spec.color = Color("d9d3c7")
	spec.glow = 0.0
	var from := trap.get_launcher_position()
	for i in arrows:
		if i > 0:
			await world.get_tree().create_timer(arrow_interval, false).timeout
			if not is_instance_valid(trap):
				return
		Sfx.play_at(sound, from, -2.0)
		world.fire_trap_projectile(from, trap.launcher_direction, spec)


## Nothing happens on the plate itself: the danger comes from the wall.
func while_active(_trap: Trap) -> void:
	pass


func place(world: World, room: Rect2i, taken: Dictionary) -> void:
	var cells := inner_cells(world, room, taken)
	for attempt in 8:
		if cells.is_empty():
			return
		var plate: Vector2i = cells[world.rng.randi_range(0, cells.size() - 1)]
		for direction in DIRECTIONS:
			var wall := _find_wall(world.map, plate, direction)
			if wall != Vector2i(-1, -1):
				var trap := world.spawn_trap(self, plate)
				trap.set_launcher(wall, -Vector2(direction))
				taken[plate] = true
				return


## The first wall cell from `cell` going `direction`, if it is close enough. (-1, -1) otherwise.
func _find_wall(map: DungeonMap, cell: Vector2i, direction: Vector2i) -> Vector2i:
	for distance in range(1, max_range + 1):
		var next := cell + direction * distance
		if not map.is_floor(next):
			return next if distance >= 3 else Vector2i(-1, -1)
	return Vector2i(-1, -1)
