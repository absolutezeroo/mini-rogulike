class_name DarkRoomDef
extends HazardDef
## A whole room plunged in darkness: you only see what is right around you, and so does
## nobody else... Monsters and traps hide in it.

## How far the hero sees inside (pixels).
@export var vision_radius: float = 80.0
@export var shade: Color = Color(0.01, 0.01, 0.03, 0.96)
## Logged the first time the hero walks in.
@export var message: String = "Darkness swallows the room."


func place(world: World, room: Rect2i, _taken: Dictionary) -> void:
	if not world.is_dark_room(room):
		world.spawn_dark_room(self, room)
