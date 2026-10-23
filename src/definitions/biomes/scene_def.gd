class_name SceneDef
extends ContentDef
## A little scene made by hand, the way level designers dress a room: a row of shelves with a
## reading table, a cold camp with bones around, graves in a row... Its plan is text, one string
## per row (easy to edit anywhere):
##   "BB.SS"   symbols: see `keys` (B = bookcase, S = shelf...)
##   "....."   "." = floor kept free (a way through, room to stand)
##   ".bTb "   " " = whatever is already there
## It is put where its `anchor` says (against the top wall, in a corner, in the middle...),
## mirrored now and then, only where everything fits and nothing gets walled off.

enum Anchor {
	ANYWHERE,  ## anywhere inside, off the walls
	CENTER,  ## in the middle of the room
	TOP_WALL,  ## its top row against the room's top wall (shelves, banners...)
	SIDE_WALL,  ## its left column against the left wall (mirrored: the right one)
	CORNER,  ## in the top-left corner (mirrored: the top-right one)
}
enum RoomSize { ANY, BIG, SMALL }

@export var rows: PackedStringArray = []
@export var keys: Array[SceneKey] = []
@export var anchor: Anchor = Anchor.ANYWHERE
@export var room_size: RoomSize = RoomSize.ANY
## Flipped left-right half of the time.
@export var can_mirror: bool = true
## At most this many on a floor (0: no limit).
@export_range(0, 10) var max_per_floor: int = 0


func size() -> Vector2i:
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	return Vector2i(width, rows.size())


func key(symbol: String) -> SceneKey:
	for k in keys:
		if k and k.symbol == symbol:
			return k
	return null


## The plan as cell offset -> symbol ("." included, " " left out), flipped if `mirrored`.
func plan(mirrored: bool) -> Dictionary:
	var cells := {}
	var width := size().x
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var symbol := row[x]
			if symbol == " ":
				continue
			cells[Vector2i(width - 1 - x if mirrored else x, y)] = symbol
	return cells


## Puts it somewhere in `room` (a few tries along its anchor). False if it fits nowhere.
## `standing` gets the cells of what it put up (decor may gather around them).
func try_place(world: World, room: Rect2i, taken: Dictionary, rng: RandomNumberGenerator, standing: Dictionary = {}) -> bool:
	var mirrored := can_mirror and rng.randf() < 0.5
	var cells := plan(mirrored)
	for origin in _origins(room, mirrored, rng):
		if _fits(world, room, taken, origin, cells):
			_build(world, taken, origin, cells, rng, standing)
			return true
	return false


## Where its top-left cell may go, by anchor, shuffled.
func _origins(room: Rect2i, mirrored: bool, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var origins: Array[Vector2i] = []
	var span := size()
	var last := room.end - span  # the furthest top-left that still fits
	if last.x < room.position.x or last.y < room.position.y:
		return origins
	match anchor:
		Anchor.TOP_WALL:
			for x in range(room.position.x, last.x + 1):
				origins.append(Vector2i(x, room.position.y))
		Anchor.SIDE_WALL:
			var x := last.x if mirrored else room.position.x
			for y in range(room.position.y, last.y + 1):
				origins.append(Vector2i(x, y))
		Anchor.CORNER:
			origins.append(Vector2i(last.x if mirrored else room.position.x, room.position.y))
		Anchor.CENTER:
			var middle := room.position + (room.size - span) / 2
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				origins.append(middle + offset)
			return origins  # the very middle first
		Anchor.ANYWHERE:
			for y in range(room.position.y + 1, last.y):
				for x in range(room.position.x + 1, last.x):
					origins.append(Vector2i(x, y))
	RandomUtils.shuffle(origins, rng)
	return origins.slice(0, 24)


func _fits(world: World, room: Rect2i, taken: Dictionary, origin: Vector2i, cells: Dictionary) -> bool:
	var blocking := {}
	var span := size()
	var cells_to_check := cells.duplicate()
	# Water covers the whole rectangle around its symbol's cells: check all of it.
	for k in keys:
		if k and k.kind == SceneKey.Kind.POND:
			var rect := _span_of(cells, k.symbol)
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					cells_to_check[Vector2i(x, y)] = k.symbol
	for offset: Vector2i in cells_to_check:
		var cell := origin + offset
		if not room.has_point(cell) or taken.has(cell) or not RoomSpace.is_free(world, cell):
			return false
		var k := key(cells_to_check[offset])
		if k and k.blocks():
			if _at_doorway(world.map, room, cell):
				return false
			blocking[cell] = true
	# What leans on its wall really has one behind it (a room's edge may open on a corridor).
	var against_right := origin.x + span.x == room.end.x and origin.x != room.position.x
	for offset: Vector2i in cells:
		if cells[offset] == ".":
			continue
		var cell := origin + offset
		if (anchor == Anchor.TOP_WALL or anchor == Anchor.CORNER) and offset.y == 0 \
				and world.map.is_floor(cell + Vector2i.UP):
			return false
		if (anchor == Anchor.SIDE_WALL or anchor == Anchor.CORNER) \
				and offset.x == (span.x - 1 if against_right else 0) \
				and world.map.is_floor(cell + (Vector2i.RIGHT if against_right else Vector2i.LEFT)):
			return false
	return blocking.is_empty() or RoomSpace.stays_open(world, room, blocking)


## The rectangle around the plan cells of `symbol`.
static func _span_of(cells: Dictionary, symbol: String) -> Rect2i:
	var rect := Rect2i()
	var first := true
	for offset: Vector2i in cells:
		if cells[offset] == symbol:
			rect = Rect2i(offset, Vector2i.ONE) if first else rect.merge(Rect2i(offset, Vector2i.ONE))
			first = false
	return rect


## Right at a corridor mouth (floor outside the room next to it): nothing may stand there.
static func _at_doorway(map: DungeonMap, room: Rect2i, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			if map.is_floor(near) and not room.has_point(near):
				return true
	return false


func _build(world: World, taken: Dictionary, origin: Vector2i, cells: Dictionary, rng: RandomNumberGenerator, standing: Dictionary) -> void:
	var done := {}
	var decor := DecorLayer.new()  # bones, books...
	decor.z_index = -8
	var plants := DecorLayer.new()  # what sways
	plants.z_index = -8
	plants.sway = true
	plants.world = world
	var spans := {}  # symbol -> Rect2i of its cells (carpets, ponds)
	var ordered := cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for offset: Vector2i in ordered:
		var cell := origin + offset
		taken[cell] = true
		var k := key(cells[offset])
		if k == null or done.has(cell):
			continue
		match k.kind:
			SceneKey.Kind.PROP:
				if k.props.is_empty():
					continue
				var prop: PropDef = k.props[rng.randi() % k.props.size()]
				for y in prop.footprint.y:
					for x in prop.footprint.x:
						done[cell + Vector2i(x, y)] = true
				if rng.randf() < k.chance:
					world.spawn_prop(prop, cell)
			SceneKey.Kind.DECOR:
				if not k.pieces.is_empty() and rng.randf() < k.chance:
					var at := world.map.cell_to_world(cell) + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
					var piece := k.pieces[rng.randi() % k.pieces.size()]
					at = FloorDresser.fit_on_floor(world.map, at.snapped(Vector2(2, 2)), piece)  # never over a wall
					if at != Vector2.INF:
						(plants if k.sway else decor).pieces.append([piece, at])
			_:
				var span: Rect2i = spans.get(k.symbol, Rect2i(cell, Vector2i.ONE))
				spans[k.symbol] = span.merge(Rect2i(cell, Vector2i.ONE))
	for symbol: String in spans:
		var k := key(symbol)
		if rng.randf() >= k.chance:
			continue
		if k.kind == SceneKey.Kind.CARPET and k.carpet:
			world.spawn_floor_patch(k.carpet, k.carpet_region, spans[symbol])
		elif k.kind == SceneKey.Kind.POND and k.pond:
			world.spawn_heat_source(k.pond, spans[symbol])
	for layer in [decor, plants]:
		if not layer.pieces.is_empty():
			world.spawn_vfx(layer)
		else:
			layer.free()
	# Nothing else right against what stands here (a chest, a lantern could close a gap).
	for offset: Vector2i in cells:
		var k := key(cells[offset])
		if k and k.blocks():
			HazardDef.take_rect(taken, Rect2i(origin + offset, Vector2i.ONE).grow(1))
			standing[origin + offset] = true
