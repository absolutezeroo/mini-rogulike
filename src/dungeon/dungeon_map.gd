class_name DungeonMap
extends RefCounted
## Pure data for one floor: which cells are floor, the rooms, start and stairs.
## No nodes here, so it can be generated and tested on its own.

enum Tile { WALL, FLOOR }
## What lies on a floor cell of a shaped room's core (RoomShapeDef): a chasm (a hole, PitDef) or
## deep water (a pool). The cell stays FLOOR in `tiles`; the World lays the hole or the water.
enum Feature { NONE, CHASM, POOL }

const NO_CELL := Vector2i(-1, -1)

var width: int
var height: int
var tile_size: int
var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var start_cell := Vector2i.ZERO
var stairs_cell := Vector2i.ZERO
## Where the second way down goes when the floor offers two (FloorRoute); NO_CELL if none fits.
var second_stairs_cell := NO_CELL
## Boss floors only: the arena (empty rect on normal floors).
var boss_room := Rect2i()
## Rooms hidden behind a cracked wall (SecretRoomPlan). Their cells stay wall until one opens.
var secrets: Array[SecretRoomPlan] = []
## Each room's plan (shape, heart), in the order of `rooms`. A map made without plans (tests,
## the Threshold) gets plain ones on demand (plan()).
var plans: Array[RoomPlan] = []
## Floor cells under a chasm or a pool (Feature), from the rooms' cores.
var features := {}
## Floor cells where a room's pillars stand (cell -> room index): a prop the World puts up.
var pillars := {}


func _init(map_width: int, map_height: int, cell_size: int) -> void:
	width = map_width
	height = map_height
	tile_size = cell_size
	tiles.resize(width * height)
	tiles.fill(Tile.WALL)


## The stairs' cells: the first, and the second when there is one.
func exit_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [stairs_cell]
	if second_stairs_cell != NO_CELL:
		cells.append(second_stairs_cell)
	return cells


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_floor(cell: Vector2i) -> bool:
	return in_bounds(cell) and tiles[cell.y * width + cell.x] == Tile.FLOOR


func set_floor(cell: Vector2i) -> void:
	if in_bounds(cell):
		tiles[cell.y * width + cell.x] = Tile.FLOOR


## Floor nobody stands on from the start: no chasm, no pool, no pillar. (Holes and props laid
## later by hazards are the World's: World.is_free_cell().)
func is_ground(cell: Vector2i) -> bool:
	return is_floor(cell) and not features.has(cell) and not pillars.has(cell)


func feature_at(cell: Vector2i) -> Feature:
	return features.get(cell, Feature.NONE)


## The plan of room `index` (a plain one for a map made without plans).
func plan(index: int) -> RoomPlan:
	while plans.size() < rooms.size():
		plans.append(RoomPlan.new(rooms[plans.size()]))
	return plans[index]


## The walkable cell nearest the middle of room `index` (its middle may be rock, a chasm, a
## pool): where its stairs, its merchant, its encounter go.
func heart(index: int) -> Vector2i:
	return plan(index).heart


## The room `cell` is in (its rectangle), or -1.
func room_at(cell: Vector2i) -> int:
	for i in rooms.size():
		if rooms[i].has_point(cell):
			return i
	return -1


## A wall cell that touches at least one floor cell (the only walls we draw and collide with).
func is_wall_edge(cell: Vector2i) -> bool:
	if is_floor(cell):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor(cell + Vector2i(dx, dy)):
				return true
	return false


## Centre of a cell, in world pixels.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i((position / tile_size).floor())


func random_cell_in(room: Rect2i, rng: RandomNumberGenerator, margin: int = 1) -> Vector2i:
	var inner := room.grow(-margin)
	if inner.size.x <= 0 or inner.size.y <= 0:
		inner = room
	return Vector2i(
		rng.randi_range(inner.position.x, inner.end.x - 1),
		rng.randi_range(inner.position.y, inner.end.y - 1))
