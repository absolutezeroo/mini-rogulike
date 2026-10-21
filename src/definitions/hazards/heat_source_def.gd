class_name HeatSourceDef
extends HazardDef
## Something that changes the hero's body temperature (BodyTemperature) while close to it:
## scorching ground that heats you up, a frozen room that chills you (`whole_room`), or a
## campfire or an oasis that brings you back to normal (`comfort`). Placed like any hazard
## (ActDef.hazards), or by a curse (CurseDef.warm_spot, CurseDef.room_look).

## Temperature change per second while standing on it (above 0 = heats up, below 0 = chills).
@export var heat: float = 35.0
## Covers a whole room (frozen rooms) instead of a patch of `size`.
@export var whole_room: bool = false
## Brings the temperature back to normal instead (campfires, oases): works within `reach` of
## its middle, or of its pond's shore.
@export var comfort: bool = false
@export var reach: float = 90.0
## Ground covered, in cells (the area for heat; the spot for a campfire; the pond of an oasis).
@export var size: Vector2i = Vector2i(3, 3)
## Bigger at random, up to this (0 = always `size`): no two oases alike.
@export var size_max: Vector2i = Vector2i.ZERO
## Patches per group (random between the two).
@export_range(1, 4) var patches_min: int = 1
@export_range(1, 4) var patches_max: int = 2

@export_group("Look")
## Drawn in the middle at 2x (a fire pit...).
@export var sprite: Texture2D
## Animated on it (flames dancing, water rippling): frames in a row.
@export var flames: Texture2D
## How many copies of the animation, side by side and out of step (3 flames, 1 ripple).
@export_range(1, 5) var flame_copies: int = 3
## Frames in a row of `flames` (0 = square frames). An 8x12 flame strip needs it, or each frame
## would cut two flames in half.
@export_range(0, 32) var flame_frames: int = 0
## World units per texel of the flames, snapped to a whole even number (2 = the art's size).
@export var flame_scale: float = 2.0
## A pond over the covered cells: 3x3 tiles of 16 px (shore corners and edges around water),
## stretched to the pond's size. Nobody walks on it (it blocks like a wall, not shots nor sight).
@export var pond: Texture2D
## The ground around the pond (the tiles' outer color: grass...), spread in a rough blob so the
## pond never looks like a box. Alpha 0 = none.
@export var pond_ground: Color = Color(0, 0, 0, 0)
## Glow of the ground, or of the reach of a campfire.
@export var glow_color: Color = Color(1.0, 0.35, 0.1, 0.25)
## Look of the ground (frozen rooms: ice). Gets the covered `area` in world space.
@export var ground_shader: Shader
## Particles over the whole area (snow falling...).
@export var particles: PackedScene
## Light given off (LightField): level 12 lights its tile 12, the next ones 11... 0 = none.
@export_range(0, 15) var light_level: int = 0
@export var light_color: Color = Color(1, 0.85, 0.6)
@export var sound: AudioStream

@export_group("Decor")
## Little things scattered around it (logs and stones by a fire, grass and flowers by water),
## a random number and places each time. 16 px images, drawn at 2x.
@export var decor: Array[Texture2D] = []
@export var decor_count: Vector2i = Vector2i.ZERO

@export_group("Camping")
## Seconds the hero can stay close before the light draws monsters in (0 = never): no camping
## by the fire. Each wave is bigger than the last.
@export var camp_limit: float = 0.0
@export var invasion: Vector2i = Vector2i(3, 4)
@export var camp_warning: String = "Things stir in the dark, drawn by the light..."
@export var invasion_message: String = "They come for the light!"


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
	var patch := size
	if size_max.x > size.x or size_max.y > size.y:
		patch = Vector2i(world.rng.randi_range(size.x, maxi(size.x, size_max.x)), world.rng.randi_range(size.y, maxi(size.y, size_max.y)))
	var rect := find_free_rect(world, room, taken, patch)
	if rect.size == Vector2i.ZERO and patch != size:
		rect = find_free_rect(world, room, taken, size)  # a small room: the smallest one
	if rect.size == Vector2i.ZERO:
		return false
	take_rect(taken, rect)
	world.spawn_heat_source(self, rect)
	return true
