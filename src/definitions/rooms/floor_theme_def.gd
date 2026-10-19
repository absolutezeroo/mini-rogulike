class_name FloorThemeDef
extends ContentDef
## A whole floor with one style: the Great Library, a Necropolis, Sunken Halls... Now and then
## (DungeonConfig.themed_floor_chance) a floor picks one among its act's (ActDef.floor_themes):
## most of its rooms then take one of `rooms` (those that fit), the others stay plain.
## Announced on arrival (display_name, description, color).

@export var rooms: Array[RoomTemplateDef] = []
## Chance for each room (not the first) to take one of `rooms`.
@export_range(0.0, 1.0) var room_chance: float = 0.85


## One of `rooms` that fits `room` (null if none does, or if this room stays plain).
func pick_room(room: Rect2i, depth: int, rng: RandomNumberGenerator) -> RoomTemplateDef:
	if rng.randf() >= room_chance:
		return null
	return RoomTemplateDef.pick(rooms, room, depth, rng)
