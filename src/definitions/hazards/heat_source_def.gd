class_name HeatSourceDef
extends HazardDef
## Something that changes the hero's body temperature (BodyTemperature) while close to it:
## scorching ground that heats you up, a frozen room that chills you (`whole_room`), or a
## campfire that warms you back to normal (`comfort`). Placed like any hazard (ActDef.hazards),
## or by a floor event (FloorEventDef > Climate).

## Temperature change per second while standing on it (above 0 = heats up, below 0 = chills).
@export var heat: float = 35.0
## Covers a whole room (frozen rooms) instead of a patch of `size`.
@export var whole_room: bool = false
## Brings the temperature back to normal instead (campfires): works within `reach`.
@export var comfort: bool = false
@export var reach: float = 90.0
## Ground covered, in cells (the area for heat; the spot for a campfire).
@export var size: Vector2i = Vector2i(3, 3)
## Patches per group (random between the two).
@export_range(1, 4) var patches_min: int = 1
@export_range(1, 4) var patches_max: int = 2

@export_group("Look")
## Drawn in the middle at 2x (a fire pit...).
@export var sprite: Texture2D
## Flames dancing on it: square frames in a row.
@export var flames: Texture2D
## Glow of the ground, or of the reach of a campfire.
@export var glow_color: Color = Color(1.0, 0.35, 0.1, 0.25)
## Look of the ground (frozen rooms: ice). Gets the covered `area` in world space.
@export var ground_shader: Shader
## Particles over the whole area (snow falling...).
@export var particles: PackedScene
## Light given off (alpha = strength, 0 = none).
@export var light_color: Color = Color(1, 1, 1, 0)
@export var light_radius: float = 200.0
@export var sound: AudioStream


func place(world: World, room: Rect2i, taken: Dictionary) -> void:
	if whole_room:
		if not world.has_heat_source_in(self, room):
			world.spawn_heat_source(self, room)
		return
	for i in world.rng.randi_range(patches_min, patches_max):
		if not place_one(world, room, taken):
			return


## One patch somewhere free in `room`; false if there is no room left.
func place_one(world: World, room: Rect2i, taken: Dictionary) -> bool:
	var rect := find_free_rect(world, room, taken, size)
	if rect.size == Vector2i.ZERO:
		return false
	take_rect(taken, rect)
	world.spawn_heat_source(self, rect)
	return true
