class_name PropsFeature
extends RoomFeature
## Furniture and other props (PropDef, footprint included): bookshelves along the top wall,
## tombstones in rows, a statue in the middle, a few stools scattered... A random number,
## random kinds among `props`, random places within the rule.

enum Placement {
	TOP_WALL,  ## against the top wall (bookshelves...)
	WALLS,  ## against any wall
	CENTER,  ## in the middle of the room
	SCATTER,  ## anywhere inside, away from the walls
	ROWS,  ## in rows across the room, every other cell (tombstones...)
	CORNERS,  ## in the room's inner corners
}

@export var props: Array[PropDef] = []
@export var placement: Placement = Placement.SCATTER
@export var count: Vector2i = Vector2i(1, 3)


func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	if props.is_empty():
		return
	var rng := world.rng
	var wanted := rng.randi_range(count.x, count.y)
	var spots := _spots(world, room, taken)
	if placement != Placement.ROWS and placement != Placement.CENTER:
		RandomUtils.shuffle(spots, rng)
	var placed: Array[Rect2i] = []
	for cell in spots:
		if wanted <= 0:
			break
		var prop: PropDef = props[rng.randi() % props.size()]
		# In the middle: centered on the spot, whatever its size.
		var at := cell - prop.footprint / 2 if placement == Placement.CENTER else cell
		var area := Rect2i(at, prop.footprint)
		if not _is_free(world, room, taken, area):
			continue
		world.spawn_prop(prop, at)
		HazardDef.take_rect(taken, area.grow(1) if placement == Placement.SCATTER else area)
		placed.append(area)
		wanted -= 1
	# Side by side among themselves (a row of shelves), but nothing else right against them
	# (a chest, a lantern), which could close a gap.
	for area in placed:
		HazardDef.take_rect(taken, area.grow(1))


func _spots(world: World, room: Rect2i, taken: Dictionary) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	match placement:
		Placement.TOP_WALL:
			for x in range(room.position.x, room.end.x):
				spots.append(Vector2i(x, room.position.y))
		Placement.WALLS:
			for cell in FloorPopulator.edge_cells(world.map, room, taken):
				spots.append(cell)
		Placement.CENTER:
			# The very middle first, then around it.
			var middle := room.get_center()
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
					Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				spots.append(middle + offset)
		Placement.SCATTER:
			var space := inner(room, 2)
			for y in range(space.position.y, space.end.y):
				for x in range(space.position.x, space.end.x):
					spots.append(Vector2i(x, y))
		Placement.ROWS:
			var space := inner(room, 2)
			for y in range(space.position.y, space.end.y, 2):
				for x in range(space.position.x, space.end.x, 2):
					spots.append(Vector2i(x, y))
		Placement.CORNERS:
			var space := inner(room, 1)
			spots.append_array([space.position, Vector2i(space.end.x - 1, space.position.y),
				Vector2i(space.position.x, space.end.y - 1), space.end - Vector2i.ONE])
	return spots


## Free floor for the whole footprint, inside the room, off corridor mouths (along the walls).
static func _is_free(world: World, room: Rect2i, taken: Dictionary, area: Rect2i) -> bool:
	if not room.encloses(area):
		return false
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if taken.has(cell) or not world.map.is_floor(cell) or world.nav.is_blocked(cell):
				return false
			if FloorPopulator.near_doorway(world.map, room, cell):
				return false
	return stays_open(world, room, area)
