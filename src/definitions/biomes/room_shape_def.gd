class_name RoomShapeDef
extends ContentDef
## The shape of a room of a floor, beyond the plain rectangle: a big round hall, a hall of
## pillars, a cross, an L, a ring around a block of rock, a pool or a chasm crossed by
## walkways, a long gallery, a small shrine... A biome lists the shapes its rooms may take
## (BiomeDef.room_shapes, each by its `spawn_weight`, from `min_depth`), and its signature rooms
## (`set_piece`: BiomeDef.set_pieces), which bring their own scenes.
##
## The generator (DungeonGenerator) asks a shape for a size, carves its `outline` (corridors then
## cut through whatever they cross), and once every corridor is dug lays its `core` (rock, a
## chasm or a pool, leaving a walkable rim and the `bridges`) and its pillars. The room keeps its
## bounding rectangle in DungeonMap.rooms; its plan (RoomPlan) says the rest. Nothing here knows
## a biome: what a pillar, a chasm or a pool looks like comes from the floor's biome.

enum Outline {
	RECT,
	## An ellipse inside the room's rectangle (a circle when `square`).
	OVAL,
	## Two halls crossing in the middle, `arm` of the room's width and height each.
	CROSS,
	## The rectangle less one corner (picked at random), `arm` thick.
	L_SHAPE,
	## The corners cut off (`arm`: how deep): a hall of eight sides.
	OCTAGON,
}

enum Core {
	NONE,
	## A block of rock in the middle (a ring room): drawn as cliffs, mist over it.
	ROCK,
	## A chasm: falling in sends the hero into the Deeps (a hole like any other, PitDef).
	CHASM,
	## Deep water nobody walks in (shots and sight go over it).
	POOL,
}

enum Pillars {
	NONE,
	## Two rows along the long sides.
	ROWS,
	## A ring around the middle.
	RING,
	## A grid over the whole floor.
	GRID,
}

@export var outline: Outline = Outline.RECT
## Cells, the smallest and biggest (picked between, within what the map can hold).
@export var size_min: Vector2i = Vector2i(9, 9)
@export var size_max: Vector2i = Vector2i(13, 13)
## As wide as high (a round hall, not an oval one).
@export var square: bool = false
## CROSS: the arms' share of the width and height. L_SHAPE: the bands' thickness. OCTAGON: how
## deep the corners are cut (0.3 a little, 0.6 a lot).
@export_range(0.2, 0.8) var arm: float = 0.5

@export_group("Core")
@export var core: Core = Core.NONE
## The core's own outline (RECT or OVAL), inside the rim.
@export var core_outline: Outline = Outline.OVAL
## Cells of floor between the room's edge and its core, all around (the way round it). A ROCK
## core needs 3 or more cells of its own each way (thinner rock is opened up by the generator).
@export_range(1, 6) var core_margin: int = 3
## CHASM and POOL: walkways straight across, through the middle: 0, 2 (along the room's long
## side, or across a square one) or 4 (both ways).
@export_range(0, 4, 2) var bridges: int = 0
@export_range(1, 4) var bridge_width: int = 2

@export_group("Pillars")
@export var pillars: Pillars = Pillars.NONE
## Cells from one pillar to the next.
@export_range(2, 6) var pillar_spacing: int = 3
## What stands there; null: one of the floor's biome's pillars (BiomeDef.pillars).
@export var pillar: PropDef

@export_group("Use")
## At most this many on a floor (0: no limit).
@export_range(0, 10) var max_per_floor: int = 0
## May hold the merchant, the forge, a pact, an ambush (false: a chasm room, a set piece).
@export var quiet_room: bool = true

@export_group("Set piece")
## A biome's signature room (BiomeDef.set_pieces): one at most on a floor, named the first time
## the hero walks in (`display_name`, in the Well's voice), dressed with `scenes` first.
@export var set_piece: bool = false
## Scenes put in it before the biome's own (each where its anchor says, if it fits).
@export var scenes: Array[SceneDef] = []
## Its ceiling is this much thicker than the biome's (CeilingDef: pieces over the room).
@export_range(0.0, 4.0) var ceiling_scale: float = 1.0


## A size for a room of this shape, no bigger than `limit`.
func pick_size(rng: RandomNumberGenerator, limit: Vector2i) -> Vector2i:
	var low := Vector2i(mini(size_min.x, limit.x), mini(size_min.y, limit.y))
	var high := Vector2i(clampi(size_max.x, low.x, limit.x), clampi(size_max.y, low.y, limit.y))
	var result := Vector2i(rng.randi_range(low.x, high.x), rng.randi_range(low.y, high.y))
	if square:
		result.y = clampi(result.x, low.y, high.y)
		result.x = result.y
	return result


## Is `local` (from the room's top-left) inside the outline of a room of `size`? `flip`: the
## corner an L leaves out (x, y: 1 or -1).
func has_cell(local: Vector2i, size: Vector2i, flip: Vector2i = Vector2i.ONE) -> bool:
	return RoomShapeDef.inside(outline, local, size, arm, flip)


## The outlines' rule, shared with the core.
static func inside(kind: Outline, local: Vector2i, size: Vector2i, share: float, flip: Vector2i = Vector2i.ONE) -> bool:
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return false
	var half := Vector2(size) * 0.5
	var at := Vector2(local) + Vector2(0.5, 0.5) - half
	match kind:
		Outline.OVAL:
			var reach := half + Vector2(0.25, 0.25)  # a fuller curve: no lone cells on the axes
			return (at.x * at.x) / (reach.x * reach.x) + (at.y * at.y) / (reach.y * reach.y) <= 1.0
		Outline.CROSS:
			return absf(at.x) <= size.x * share * 0.5 or absf(at.y) <= size.y * share * 0.5
		Outline.L_SHAPE:
			# The left out corner: top right unflipped.
			var x := at.x * flip.x
			var y := at.y * flip.y
			return not (x > half.x - size.x * (1.0 - share) and y < -half.y + size.y * (1.0 - share))
		Outline.OCTAGON:
			return absf(at.x) / half.x + absf(at.y) / half.y <= 2.0 - share
	return true


## What the core makes of `local` in a room of `size`: NONE (floor kept), or the core's kind.
## Bridges stay floor.
func core_at(local: Vector2i, size: Vector2i) -> Core:
	if core == Core.NONE:
		return Core.NONE
	var inner := core_rect(size)
	if inner.size.x <= 0 or inner.size.y <= 0 or not inner.has_point(local):
		return Core.NONE
	if not RoomShapeDef.inside(core_outline, local - inner.position, inner.size, 0.5):
		return Core.NONE
	if core != Core.ROCK and on_bridge(local, size):
		return Core.NONE
	return core


## The core's rectangle (local), inside the rim; empty if the room is too small for one.
func core_rect(size: Vector2i) -> Rect2i:
	var inner := Rect2i(Vector2i(core_margin, core_margin), size - Vector2i(core_margin, core_margin) * 2)
	var least := 4 if core == Core.ROCK else 2
	if inner.size.x < least or inner.size.y < least:
		return Rect2i()
	return inner


## On a walkway across the core.
func on_bridge(local: Vector2i, size: Vector2i) -> bool:
	if bridges <= 0:
		return false
	var mid := size / 2
	var low := -bridge_width / 2
	var high := low + bridge_width
	var along_x := local.y - mid.y >= low and local.y - mid.y < high  # a walkway from left to right
	var along_y := local.x - mid.x >= low and local.x - mid.x < high  # from top to bottom
	if bridges >= 4:
		return along_x or along_y
	return along_x if size.x >= size.y else along_y


## Where the pillars stand (local cells) in a room of `size`: never on the lanes through the
## middle (where corridors come in), never in the core, every one a cell or more from the next.
func pillar_cells(size: Vector2i, flip: Vector2i = Vector2i.ONE) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if pillars == Pillars.NONE:
		return cells
	var mid := size / 2
	var step := maxi(pillar_spacing, 2)
	match pillars:
		Pillars.ROWS:
			var long_x := size.x >= size.y
			var span := size.x if long_x else size.y
			var across := size.y if long_x else size.x
			var inset := 2 if across >= 7 else 1
			for k in _around_middle(span, step):
				for side in [inset, across - 1 - inset]:
					cells.append(Vector2i(k, side) if long_x else Vector2i(side, k))
		Pillars.GRID:
			for y in _around_middle(size.y, step):
				for x in _around_middle(size.x, step):
					cells.append(Vector2i(x, y))
		Pillars.RING:
			var radius := Vector2(size) * 0.5 - Vector2(2.5, 2.5)
			if radius.x < 1.5 or radius.y < 1.5:
				return cells
			var around := TAU * sqrt((radius.x * radius.x + radius.y * radius.y) * 0.5)
			var count := maxi(roundi(around / step), 4)
			for i in count:
				var angle := TAU * (i + 0.5) / count
				var at := Vector2(size) * 0.5 + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
				var cell := Vector2i(at.floor())
				if not cells.has(cell):
					cells.append(cell)
	var result: Array[Vector2i] = []
	for cell in cells:
		if absi(cell.x - mid.x) <= 1 or absi(cell.y - mid.y) <= 1:
			continue  # the lanes through the middle stay open
		if not has_cell(cell, size, flip) or core_at(cell, size) != Core.NONE:
			continue
		if result.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < 2):
			continue
		result.append(cell)
	return result


## Places along a side of `span` cells, `step` apart, in pairs mirrored round the middle and
## leaving the lane through it (where corridors come in) open, two cells off the walls.
static func _around_middle(span: int, step: int) -> Array[int]:
	var places: Array[int] = []
	var mid := span / 2
	var offset := 2
	while true:
		var low := mid - offset
		var high := mid + offset
		if low < 2 and high > span - 3:
			break
		if low >= 2:
			places.append(low)
		if high <= span - 3:
			places.append(high)
		offset += step
	return places
