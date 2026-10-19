class_name NavGrid
extends RefCounted
## Where walking monsters can go on the current floor: an A* grid over the map's cells.
## Walls are solid; props, chests, encounters, the merchant and holes block their cell too.

var _astar := AStarGrid2D.new()
var _map: DungeonMap


func build(map: DungeonMap) -> void:
	_map = map
	_astar.region = Rect2i(0, 0, map.width, map.height)
	_astar.cell_size = Vector2(map.tile_size, map.tile_size)
	_astar.offset = Vector2(map.tile_size, map.tile_size) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	# The grid keeps its solid cells from the previous floor when its size does not change.
	_astar.fill_solid_region(_astar.region, false)
	for y in map.height:
		for x in map.width:
			if not map.is_floor(Vector2i(x, y)):
				_astar.set_point_solid(Vector2i(x, y))


## Marks a floor cell as an obstacle (or free again).
func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if _map.in_bounds(cell) and _map.is_floor(cell):
		_astar.set_point_solid(cell, blocked)


func is_blocked(cell: Vector2i) -> bool:
	return not _map.in_bounds(cell) or _astar.is_point_solid(cell)


## Path between two world positions, as a list of cell centres (empty if unreachable).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _map.world_to_cell(from)
	var goal := _map.world_to_cell(to)
	if not _map.is_floor(start) or not _map.is_floor(goal):
		return PackedVector2Array()
	return _astar.get_point_path(start, goal)
