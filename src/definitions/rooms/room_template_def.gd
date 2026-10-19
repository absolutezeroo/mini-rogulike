class_name RoomTemplateDef
extends ContentDef
## A themed room: a pillared hall, a ruined library, a garden, a flooded hall, a crypt, a shrine...
## Some rooms of a floor get one (DungeonConfig.themed_room_chance), picked among the act's
## (ActDef.room_templates) that fit the room. Its features (RoomFeature) furnish it (columns,
## floors, ponds, furniture, decor). Every one has random parts: no two alike.

## Smallest and largest room (in cells) it fits in.
@export var min_size: Vector2i = Vector2i(7, 7)
@export var max_size: Vector2i = Vector2i(99, 99)
@export var features: Array[RoomFeature] = []
## Keep the usual crates and pots along the walls.
@export var keep_props: bool = false


## One of `templates` that fits `room`, by spawn weight (null if none does).
static func pick(templates: Array[RoomTemplateDef], room: Rect2i, depth: int, rng: RandomNumberGenerator) -> RoomTemplateDef:
	var fitting := templates.filter(func(template: RoomTemplateDef) -> bool: return template and template.fits(room))
	return ContentDB.pick_from(fitting, depth, rng) as RoomTemplateDef


func fits(room: Rect2i) -> bool:
	return room.size.x >= min_size.x and room.size.y >= min_size.y \
		and room.size.x <= max_size.x and room.size.y <= max_size.y


## Lays the rest out once the floor is built (`taken`: cells already used, see HazardDef).
func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	for feature in features:
		if feature:
			feature.furnish(world, room, taken)
