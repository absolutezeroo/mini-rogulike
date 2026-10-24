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
	# An end on a blocked cell (the hero on a hole's edge, a bat over a pond): its open neighbour.
	var start := nearest_open(_map.world_to_cell(from))
	var goal := nearest_open(_map.world_to_cell(to))
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return PackedVector2Array()
	return _astar.get_point_path(start, goal)


## `cell` if it is open, else the nearest open cell at most 2 steps away (by distance between the
## cells' centres, the first found on a tie); (-1, -1) if none.
func nearest_open(cell: Vector2i) -> Vector2i:
	if _map.is_floor(cell) and not is_blocked(cell):
		return cell
	for radius in range(1, 3):
		var best := Vector2i(-1, -1)
		var best_distance := 1 << 30
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue  # only the ring at this radius (the inner ones were looked at)
				var near := cell + Vector2i(dx, dy)
				var distance := dx * dx + dy * dy
				if distance < best_distance and _map.is_floor(near) and not is_blocked(near):
					best = near
					best_distance = distance
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)
