class_name HoleField
extends RefCounted
## The floor's holes and cracked floor, owned by the World (World.holes): which cells are holes
## (drawn by the PitLayer), the cracked floor waiting to give way (CrumblingFloor, by cell: one
## lookup per actor, never a scan), holes filled in (seal_hole()) and cracks that gave way, both
## kept for the floor's save (FloorSave), and their restore on a rebuilt floor. Making a cell a
## hole or floor again also blocks or frees it for pathfinding and tells the minimap
## (World.cells_changed).

## Pixels of a hole's edge you can stand on without falling.
const PIT_EDGE := 6.0

## Draws the holes and knows them by cell (the World's Pits node).
var pits: PitLayer
## Cracked floor not given way yet: cell -> CrumblingFloor.
var cracks := {}
## Hole cells filled in on this floor (seal_hole: the hole the hero fell into the Deeps through),
## saved with the floor so a resumed run doesn't find it open again.
var sealed_cells: Array[Vector2i] = []
## Cracked floor cells that gave way on this floor (CrumblingFloor), saved with the floor so a
## resumed run finds a hole there, not the crack its seed lays again.
var collapsed_cells: Array[Vector2i] = []

var _world: World


func _init(world: World, layer: PitLayer) -> void:
	_world = world
	pits = layer


## A new map's holes are drawn at its tile size; none yet.
func setup(tile_size: int) -> void:
	pits.setup(tile_size)


## The floor is cleared: no hole, no crack (what was filled or gave way is the save's: forget()).
func clear() -> void:
	cracks.clear()
	if pits:
		pits.clear()


## A new floor: nothing filled in, nothing given way yet.
func forget() -> void:
	sealed_cells.clear()
	collapsed_cells.clear()


## Makes `cell` a hole: anyone standing on it falls, monsters path around it.
func add_pit(cell: Vector2i, def: PitDef) -> void:
	pits.add(cell, def)
	_world.set_cell_blocked(cell, true)
	_world.cells_changed.emit([cell] as Array[Vector2i])


## Makes every one of `cells` a hole of `def` at once (a shaped room's chasm): one redraw of the map.
func add_pits(cells: Array[Vector2i], def: PitDef) -> void:
	for cell in cells:
		pits.add(cell, def)
		_world.set_cell_blocked(cell, true)
	_world.cells_changed.emit(cells)


func has_pit(cell: Vector2i) -> bool:
	return pits.has(cell)


## The hole under `point`, if it is well inside one (a few pixels of edge are forgiven).
func pit_under(point: Vector2) -> PitDef:
	var map := _world.map
	var def := pits.get_def(map.world_to_cell(point))
	if def == null:
		return null
	for offset: Vector2 in [Vector2(PIT_EDGE, 0), Vector2(-PIT_EDGE, 0), Vector2(0, PIT_EDGE), Vector2(0, -PIT_EDGE)]:
		if not pits.has(map.world_to_cell(point + offset)):
			return null
	return def


## A hole, or cracked floor still standing, at `cell`: not solid ground.
func is_unsafe(cell: Vector2i) -> bool:
	if pits.has(cell):
		return true
	var crack: CrumblingFloor = cracks.get(cell)
	return crack != null and is_instance_valid(crack) and not crack.is_queued_for_deletion()


## Cracked floor laid at `cell`.
func add_crack(cell: Vector2i, tile: CrumblingFloor) -> void:
	cracks[cell] = tile


func forget_crack(cell: Vector2i) -> void:
	cracks.erase(cell)


## Cracked floor gives way under whoever walks on it: one lookup per actor, not one scan per crack.
func step_on_cracks() -> void:
	if cracks.is_empty():
		return
	var map := _world.map
	for actor in _world.actors_this_frame():
		if is_instance_valid(actor) and actor.is_grounded():
			var crack: CrumblingFloor = cracks.get(map.world_to_cell(actor.global_position))
			if crack and is_instance_valid(crack):
				crack.step_on()


## Cracked floor at `cell` gave way (CrumblingFloor.collapse()): a hole now, kept for the save.
func crack_collapsed(cell: Vector2i, def: PitDef) -> void:
	forget_crack(cell)
	add_pit(cell, def)
	if not collapsed_cells.has(cell):
		collapsed_cells.append(cell)


## Fills the hole `cell` belongs to (every hole cell joined to it): solid floor again, walkable,
## with dust where it closed. Returns the cells filled (none if `cell` is no hole). Kept in
## `sealed_cells`, for the floor's save.
func seal_hole(cell: Vector2i) -> Array[Vector2i]:
	var sealed: Array[Vector2i] = []
	if not pits.has(cell):
		return sealed
	var todo: Array[Vector2i] = [cell]
	while not todo.is_empty():
		var next: Vector2i = todo.pop_back()
		if not pits.has(next) or sealed.has(next):
			continue
		sealed.append(next)
		for step: Vector2i in GridDirs.FOUR:
			todo.append(next + step)
	fill_cells(sealed)
	for filled in sealed:
		Vfx.puff(_world, _world.map.cell_to_world(filled))
	return sealed


## Makes `cells` solid floor: their holes filled, and their cracked floor too (a hole that was
## cracked floor before it gave way: rebuilt from the seed, the floor is cracked there again).
func fill_cells(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	for cell in cells:
		pits.remove(cell)
		var crack := cracks.get(cell) as CrumblingFloor
		if crack:
			forget_crack(cell)
			crack.queue_free()
		_world.set_cell_blocked(cell, not _world.map.is_floor(cell))
		if not sealed_cells.has(cell):
			sealed_cells.append(cell)
	_world.cells_changed.emit(cells)


## Holes filled in before quitting stay filled (the save's "sealed" cells).
func restore_sealed(cells: Array[Vector2i]) -> void:
	fill_cells(cells)


## Cracked floor that gave way before quitting is a hole again, without a sound (the save's
## "collapsed" cells).
func restore_collapsed(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var crack := cracks.get(cell) as CrumblingFloor
		if crack and is_instance_valid(crack):
			crack.collapse(true)
