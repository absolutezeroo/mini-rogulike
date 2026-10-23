class_name RoomPlan
extends RefCounted
## One room of a DungeonMap as the generator made it: its rectangle, its shape (null: a plain
## rectangle), the corner an L leaves out, and its heart (the walkable cell nearest its middle:
## where the start, the stairs, the merchant or an encounter go; the middle itself may be rock,
## a chasm or a pool).

var rect: Rect2i
var shape: RoomShapeDef
## L_SHAPE: which corner is left out (1 or -1 on each axis).
var flip := Vector2i.ONE
var heart := Vector2i.ZERO


func _init(room: Rect2i = Rect2i(), room_shape: RoomShapeDef = null, corner: Vector2i = Vector2i.ONE) -> void:
	rect = room
	shape = room_shape
	flip = corner
	heart = room.get_center()


## A biome's signature room.
func is_set_piece() -> bool:
	return shape != null and shape.set_piece


## Fit for the merchant, the forge, a pact or an ambush (not a chasm room, not a set piece).
func is_quiet() -> bool:
	return shape == null or (shape.quiet_room and not shape.set_piece)


## Is `cell` (map coordinates) inside the room's outline?
func has_cell(cell: Vector2i) -> bool:
	if not rect.has_point(cell):
		return false
	return shape == null or shape.has_cell(cell - rect.position, rect.size, flip)
